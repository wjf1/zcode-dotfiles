# VERIFY.md —— 验收记录

- 验收日期：2026-10-07（v2.1.0 验收）
- 执行人：ZCode（本机会话，自动化）
- 环境：Windows 10.0.26200（`MINGW64_NT-10.0-26200`）、chezmoi v2.73.0、Python 3.12.10（经 `python` 调用）、Node.js 22.23.2、PowerShell 5.1
- 命令：`sh tests/acceptance.sh`（仓库根，全部在 `.test-home/` 沙箱内执行）

## 结论

```
ACCEPTANCE PASS      # 退出码 0（40 技能 / 196 文件，全部用例通过）
```

## CI 三平台矩阵结果（v2.0.1，run 37487600824）

| Job | 结果 | 证据 |
|---|---|---|
| acceptance (ubuntu-latest) | ✓ | `[mcp-deps] platform=unix` → `ACCEPTANCE PASS` |
| acceptance (macos-latest) | ✓ | `[mcp-deps] platform=unix` → `ACCEPTANCE PASS` |
| acceptance (windows-latest) | ✓ | `[mcp-deps] platform=windows` → `ACCEPTANCE PASS` |
| secret scan (gitleaks) | ✓ | 工作区与全量历史均无命中 |

CI 同时验证了 `run_once` 的跨平台调度：Windows 只执行 `.ps1`，macOS/Linux 只执行 `.sh`。

> 首轮 CI（v2.0.0，run 37486623308）在 macOS 与 Windows 上失败并暴露了三个真实缺陷
> （macOS bash 3.2 的 `$VAR` 多字节吞噬、Windows cp1252 编码、gitleaks 资源名变更），
> 已在 v2.0.1 修复——这正是引入三平台矩阵的价值。

## 逐步结果（acceptance 实际输出，非手工整理）

| 步骤 | 覆盖 | 结果 |
|---|---|---|
| T2.1 隔离全量部署 | 4 个托管目标齐备、skills 40 目录 / 196 文件 | OK |
| T2.1b `.chezmoiignore` | 仓库自有文件全部未落到目标目录；`known_marketplaces.json` 不再部署 | OK |
| R2 verbatim 逐字节 | AGENTS.md / usage.md 两个 sha256 一致 | OK |
| R2b skills 逐字节 | 196 个技能文件逐字节一致、`dot_` 与 `literal_` 编码正确还原 | OK |
| R1 自定义 server | 自定义 server 保留、模板条目更新为渲染值、顶层自定义键保留、npx 版本已锁定 | OK |
| R4 幂等 | 目标树 diff 为空、`chezmoi diff --exclude=scripts` 为空、无备份堆叠 | OK |
| R3 skills 原子性 | 只读障碍下 apply 报 `Access is denied`，技能树仍为 40 目录 / 196 文件；障碍清除后完全恢复 | OK |
| R3b 局部缺失收敛 | 删除 3 个技能文件后 apply 收敛一致 | OK |
| R5 installed_plugins 渲染 | 无 `__ZCODE_HOME__` 残留、installPath 前缀 == homeDir、2 条记录结构正确 | OK |
| 漂移检查 | `mcp-deps.yaml` ↔ 模板 ↔ 两个 run_once 脚本一致（5 个 server） | OK |
| R0 静态 | `legacy/deploy.ps1` 合并分支已改用 `$escHome` | OK |
| R0b 动态 | 沙箱内真跑修复后的归档件，产出合法 JSON 且路径按转义形式注入 | OK |
| run_once 语法/自检 | `.sh` 语法通过；`.sh` 在 Windows 正确早退；`.ps1` 渲染自检能检出缺失命令 | OK |
| run_once 跨平台调度 | Windows 上只执行 `.ps1`（输出 `platform=windows`），未执行 `.sh` | OK |

## 关键证据摘录

R1（合并语义，模板条目整体覆盖、目标独有保留、顶层自定义键保留）：

```
自定义 server 保留 / 模板条目更新 / 渲染值 / npx 版本已锁定
```

R3（中途失败不破坏技能树，障碍为只读文件）：

```
注：apply 已按预期在该文件上失败：chezmoi: .zcode/skills/humanizer/SKILL.md:
    open .../SKILL.md: Access is denied.
障碍存在时：目录 40 / 文件 196
OK  R3 通过：失败时技能树保持 40 目录 / 196 文件，障碍清除后完全恢复
```

R0b（归档脚本动态复验，USERPROFILE 故意用反斜杠形式以真正触发转义）：

```
修复后归档脚本产出合法 JSON，路径按转义形式注入：
F:\AI\Qdor\work\zcode-dotfiles\.test-home\r0\home\AppData\Local\Programs\Python\Python312\python.exe
```

run_once 跨平台调度（Windows 上的实际输出）：

```
[mcp-deps] platform=windows
== ZCode MCP 依赖检测（Windows）==          <- 以下 PowerShell 段为系统代码页(GBK)输出，此处按原样留档
[deps] OK   node 22.23.2.0 / npx 可用
[deps] OK   token 用量状态栏脚本已就位：C:\Users\admin\.zcode\zcode-token-usage-statusbar\usage_mcp.py
[deps] OK   codebase-memory-mcp.exe 已就位
== 渲染产物自检：C:\Users\admin\.zcode\cli\config.json ==
[mcp-check] OK   context7: E:\OpenCode\context7-mcp.cmd
[mcp-check] OK   sequential-thinking: E:\OpenCode\mcp-server-sequential-thinking.cmd
[mcp-check] OK   zcode-token-usage-statusbar: C:\Users\admin\AppData\Local\Programs\Python\Python312\python.exe
[mcp-check] OK   chrome-devtools: cmd
[mcp-check] OK   codebase-memory-mcp: C:\Users\admin\AppData\Local\Programs\codebase-memory-mcp\codebase-memory-mcp.exe
OK  run_once 只在本平台执行（.chezmoiignore 生效）
```

> 注：上面自检读到的是**本机尚未迁移的真实** `~/.zcode/cli/config.json`（仍含 `E:\OpenCode\*.cmd`），因此显示的是旧路径。这是预期行为：沙箱 apply 不会改动真实配置。

## 未覆盖 / 待人工验证（诚实声明）

1. **真实机器上的首次部署**：CI 与本地验收都在沙箱目标目录（`--destination`）里跑，**这不等于**存量机可以直接 apply。macOS / Linux 的真实安装路径、`/usr/bin/python3` 存在性、`exact_` 的权限语义仍需在真机上跑一次单命令部署确认；Windows 侧切换前必须先按 README 走 adopt 流程。
2. **`npx -y <pkg>@<ver>` 在非 Windows 的实际启动**（D3）：仅核对了版本与包名，CI 只检测依赖存在性，未实跑启动这些 MCP。
3. **ZCode 是否信任 `installed_plugins.json` 的 `installPath`**：文件已正确渲染为本机真实路径，但 ZCode 读取行为需在真机观察（见 HANDOFF.md 待办）。
4. **存量机保护**：本机现有 39 个技能目录，仓库侧 38 个（多出 `agent-reach`），未纳管技能会在首次 apply 时被 `exact_` 删除。

## 复现方法

```sh
git clone https://github.com/wjf1/zcode-dotfiles.git
cd zcode-dotfiles
sh tests/acceptance.sh      # 需要 chezmoi 与 Python 3
```

---

## 2026-10-26（v2.2.0 / v2.3.0 批次验收：T1–T7、T10）

- 验收日期：2026-10-26；执行人：ZCode（本机会话，自动化）
- 环境：Windows 10.0.26200（`MINGW64_NT-10.0-26200`）、chezmoi v2.73.0、Python 3.12.10（经 `python` 调用）、Node.js v22.23.2、Git 2.54.0
- 基线：全新克隆 https://github.com/wjf1/zcode-dotfiles（ccfbb05，v2.1.3）；**基线 `sh tests/acceptance.sh` 先行 PASS** 后才开工

### 结论

```
ACCEPTANCE PASS      # 退出码 0（脚本开头输出 skills: 40 dirs / 191 files）
```

### 关键用例实录（命令 + 关键行 + 退出码，非手工整理）

- **基线自检**：`sh tests/acceptance.sh` → 退出码 0，`ACCEPTANCE PASS`。
- **T1**：`grep -o '"type": "stdio"' .test-home/dest/.zcode/cli/config.json | wc -l` → `5`（≥ 4 达标）；R1 输出新增 `type=stdio 已显式声明`。
- **T3 红测试**：`sed -i 's/context7-mcp@4.1.0/context7-mcp@9.9.9/' mcp-deps.yaml && sh tests/acceptance.sh` → **退出码 1**，并输出两侧差异：
  `以下版本只在 mcp-deps.yaml 中声明，模板未渲染： ['@upstash/context7-mcp@9.9.9']`
  `以下版本只在模板中出现，未登记到 mcp-deps.yaml： ['@upstash/context7-mcp@4.1.0']`
  `git checkout mcp-deps.yaml` 还原后重跑 → 退出码 0。
- **T4（R1b）**：向沙箱 `config.json` 写入 `context7 = {"enabled": false, "command": "stale", "args": [], "timeoutMs": 1000}` 后 re-apply，实际产物：
  `{"type": "stdio", "command": "npx.cmd", "args": ["-y", "@upstash/context7-mcp@4.1.0"], "timeoutMs": 60000, "enabled": false}`
  ——`enabled: false` 被继承保留，command / args / timeoutMs / type 全部恢复模板值。
- **T5**：跨平台调度步骤（真实 apply）输出含 `[plugins] SKIP test-mode`；`.test-home/` 内未产生任何插件缓存目录；`.ps1` 的 BOM（`ef bb bf`）完好。
- **T6**：junction 夹具（PowerShell `New-Item -ItemType Junction`）+ 普通目录对照——sh 输出 `unmanaged (symlink -> /tmp/sk-src/demo): demo` 与 `unmanaged: plain`，ps1 输出 `unmanaged (symlink -> C:\...\sk-src\demo): demo`；`--add` 在隔离假源（`USERPROFILE` + `sourceDir` 均指向临时目录，不碰真实 `~/.local/share/chezmoi`）中把 junction **实体化**为普通文件副本（内容 `x`、非链接、含点号目录路径走 `cp -R dir/.` 语义），sh / ps1 均未执行 `chezmoi add`。
- **T7 探针**：`mkdir dot_zcode/exact_skills/_probe && echo p > _probe/SKILL.md` 后 acceptance → 退出码 0，计数自动跟随输出 `skills: 41 dirs / 192 files`；探针删除后 `git status --short` 干净。
  （首轮实现曾把 `$SKILL_DIRS` 直接写在全角括号前，被脚本内置的「shell 可移植性」闸门拦下，改为 `${SKILL_DIRS}` 后通过——该闸门有效。）
- **提交纪律**：一任务一提交（d9e6609 → 收口提交共 8 个），每次提交前该轮验收 PASS。

### 未覆盖 / 待人工验证（诚实声明）

1. **`zcode plugins install --scope user` 的真实安装路径**：本会话验收全部走 `ZCODE_TEST_NO_SIDE_EFFECTS=1` 跳过路径，未真实安装；需在装有 ZCode ≥3.16 的机器上重跑 run_once 观察实际安装行为后回填本文件。
2. **adopt 实体化的端到端**：本会话用隔离假源验证语义；真实 `~/.local/share/chezmoi` 源目录上的完整导入 → adopt → apply 链路待真机走查。
3. **`enabled` 继承的真实 UI 往返**：设置页改开关 → `chezmoi apply` → 重开设置页确认，建议人工走查一次。
4. **macOS / Linux 真机仍未实测**（沿用上文 2026-10-07 声明，由 CI 三平台矩阵覆盖）。

---

## 2026-10-26（v2.4.0 批次验收：T8 合并逻辑去 Python 化）

- 环境：同上（Windows 10.0.26200 / chezmoi v2.73.0 / Python 3.12.10）。

### Phase A 探测实录（PROBES.md D11）

- 变体 1 `dot_x/config.json`（无 `modify_` 前缀，仅魔法注释）→ 被当普通文件原样部署，模板未执行。
- 变体 2 `plainy/modify_config.json` → 目标 `plainy/config.json` 内容 `{"a": {"b": "NEW"}}`；预置 `{"a":{"b":"OLD"},"keep":true}` 再 apply → `a.b=NEW` 且 `keep:true` 保留；第二次 apply 树与内容零变化（幂等）；写入 `{broken json` 时 apply 报
  `error calling fromJson: invalid character 'b' looking for beginning of object key string`（快速失败）。

### 新旧实现等价对比（三组 fixture，JSON 结构相等）

```
fixture 1: 语义等价 OK     # 空输入（目标不存在）
fixture 2: 语义等价 OK     # 含自定义 server my-local-server + 顶层 myTopLevel
fixture 3: 语义等价 OK     # context7 enabled=false + 篡改 command/args/timeoutMs
三组 fixture 全部语义等价（JSON 结构相等）
```

### 全量验收

```
sh tests/acceptance.sh  →  ACCEPTANCE PASS（退出码 0）
python -c "import json;json.load(open('.test-home/dest/.zcode/cli/config.json'))"  →  产物合法 JSON
```

R1（自定义 server 保留）、R1b（enabled 继承）、R4（幂等）等核心用例在新实现下全部通过。

### 未覆盖 / 待人工验证

1. **真机灰度**：主力机 `chezmoi apply` 一轮，确认真实 `~/.zcode/cli/config.json` 与语义预期一致；损坏文件场景的人工恢复路径（修复或删除后 apply）未在真机演练。
2. **chezmoi 升级兼容**：modify-template 依赖的行为在更高版本 chezmoi 上的兼容性未测（当前基线 v2.73.0）。
