# VERIFY.md —— 验收记录

- 验收日期：2026-10-06
- 执行人：ZCode（本机会话，自动化）
- 环境：Windows 10.0.26200（`MINGW64_NT-10.0-26200`）、chezmoi v2.73.0、Python 3.12.10（经 `python` 调用）、Node.js 22.23.2、PowerShell 5.1
- 命令：`sh tests/acceptance.sh`（仓库根，全部在 `.test-home/` 沙箱内执行）

## 结论

```
ACCEPTANCE PASS      # 退出码 0
```

## 逐步结果（acceptance 实际输出，非手工整理）

| 步骤 | 覆盖 | 结果 |
|---|---|---|
| T2.1 隔离全量部署 | 5 个托管目标齐备、skills 38 目录 / 68 文件 | OK |
| T2.1b `.chezmoiignore` | 仓库自有文件全部未落到目标目录 | OK |
| R2 verbatim 逐字节 | AGENTS.md / usage.md / known_marketplaces.json 三个 sha256 一致 | OK |
| R2b skills 逐字节 | 68 个技能文件逐字节一致、`dot_` 编码正确还原 | OK |
| R1 自定义 server | 自定义 server 保留、模板条目更新为渲染值、顶层自定义键保留、npx 版本已锁定 | OK |
| R4 幂等 | 目标树 diff 为空、`chezmoi diff --exclude=scripts` 为空、无备份堆叠 | OK |
| R3 skills 原子性 | 只读障碍下 apply 报 `Access is denied`，技能树仍为 38 目录 / 68 文件；障碍清除后完全恢复 | OK |
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
障碍存在时：目录 38 / 文件 68
OK  R3 通过：失败时技能树保持 38 目录 / 68 文件，障碍清除后完全恢复
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

1. **macOS / Linux 真机**：本机只有 Windows，三平台矩阵由 `.github/workflows/acceptance.yml` 在 CI 上覆盖，本地未实测。相关风险点：`/usr/bin/python3` 是否存在、`exact_` 与权限语义、`chmod` 障碍在 Unix 上可能被 rename 语义绕过（R3 已做双分支断言）。
2. **`npx -y <pkg>@<ver>` 在非 Windows 的实际启动**（D3）：仅核对了版本与包名，未在 Unix 上实跑。
3. **ZCode 是否信任 `installed_plugins.json` 的 `installPath`**：文件已正确渲染为本机真实路径，但 ZCode 读取行为需在真机观察（见 HANDOFF.md 待办）。
4. **主力机的实际切换**：沙箱验收通过 ≠ 存量机可直接 apply。切换前必须按 README 的 adopt 流程先纳管本机未跟踪技能（本机现有 39 个技能目录，仓库侧 38 个）。

## 复现方法

```sh
git clone https://github.com/wjf1/zcode-dotfiles.git
cd zcode-dotfiles
sh tests/acceptance.sh      # 需要 chezmoi 与 Python 3
```
