# HANDOFF.md —— 接力开发文档

> 新会话 / 新 Agent 接手本仓库时，除 README、CHANGELOG 外请**优先读本文件**，可快速建立对当前代码真实进展与未竟任务的心智，无需全盘探索。

## 1. 项目概况与当前状态

- **定位**：ZCode 桌面版（AI 编码工具）的跨机器配置同步仓库，chezmoi 管理，三平台单命令部署。
- **当前版本**：`v2.1.0`（2026-10-07）——同步 AGENTS.md 治理规范与代理端口，纳管 agent-reach 与 apk-reverse 技能（40 技能 / 191 文件）
- **部署地址**：https://github.com/wjf1/zcode-dotfiles（默认分支 `main`）
- **同步范围**：`~/.zcode` 中的默认指令、40 个技能、`commands/usage.md`、`cli/config.json`（MCP + 插件开关）、插件市场与插件来源记录。
- **不做的事**：不同步凭证与缓存（L4）；不 vendor 上游独立项目；不保留旧 PowerShell 脚本可执行性。

## 2. 技术栈与运行基线

- **核心工具**：chezmoi **v2.73.0**（实测基线；升级前请重跑验收，见 §6 避坑）
- **运行时**：Python 3（`config.json` 合并脚本 + 状态栏 MCP）；Node.js 18+（黄色级 MCP 经 `npx` 启动）；PowerShell（Windows 侧 `run_once`）
- **验证语言**：验收脚本为 POSIX `sh`，JSON/字节比对用 Python 3；`.ps1` 一律带 UTF-8 BOM
- **常用命令**：

```sh
sh tests/acceptance.sh          # 全量验收（R0–R5），沙箱在 .test-home/
sh -n run_once_after_10-install-mcp-deps.sh   # 脚本语法检查
tests/../tools/adopt-local-skills.sh          # 列出未纳管技能（--add 纳管）
chezmoi diff --exclude=scripts  # 幂等性人工核验（必须排除 scripts）
```

## 3. 核心架构与文件拓扑

```
zcode-dotfiles/                       # 仓库根 = chezmoi source state（SSOT）
├── .chezmoi.toml.tmpl                # 采集 zcodePythonPath / zcodeCodebaseMemoryPath + [interpreters.py]
├── .chezmoiignore                    # 排除仓库自有文件；按 OS 排除另一侧 run_once（用"派生名"！）
├── mcp-deps.yaml                     # MCP 分级清单（唯一事实源，CI 漂移检查对照它）
├── dot_zcode/                        # → ~/.zcode/
│   ├── AGENTS.md / commands/usage.md / cli/plugins/known_marketplaces.json   # verbatim
│   ├── cli/modify_config.json.py.tmpl        # config.json 深合并（stdin → stdout）
│   ├── cli/plugins/installed_plugins.json.tmpl  # installPath 按 homeDir 渲染
│   └── exact_skills/                 # → ~/.zcode/skills/（exact_ 镜像；点号目录用 dot_ 编码）
├── run_once_after_10-install-mcp-deps.{sh,ps1}
├── tests/acceptance.sh               # 本地与 CI 共用
├── tools/{adopt-local-skills,install-statusbar}.{sh,ps1}
└── legacy/                           # 归档件（不可执行）
```

**数据流**：`chezmoi init --apply` → 渲染模板 → 写 `~/.zcode/` → 执行 `run_once`（依赖检测 + 渲染自检）。
**关键边界**：`config.json` 的合并语义是"模板声明的 server 整体覆盖同名条目，未声明的条目与顶层键保留"；`exact_skills` 是唯一带删除语义的目录。

## 4. 最近一轮变更与交付成果

- 完成 chezmoi 化迁移，全部构建任务落地，**`sh tests/acceptance.sh` 在 Windows 上退出码 0（ACCEPTANCE PASS）**，覆盖 R0–R5 与结构断言。
- 修复旧体系全部已确认缺陷：R0（归档件 P0 路径注入，静态+沙箱动态复验）、R1（静默清 MCP）、R2（逐字节一致）、R3（技能树原子性）、R4（幂等、无备份堆叠）、R5（占位符渲染）。
- 新增 CI 三平台矩阵与 gitleaks 扫描；新增 5 份文档（README 双语、CHANGELOG、HANDOFF、PROBES、VERIFY）。
- 相对迁移规格 v2.0 的**偏差 3 处**（详见 PROBES.md）：合并改用 `.py` 形态的 `modify_` 脚本（需 Python 3）；`usage_mcp.py` 改为克隆上游而非 vendor；MCP 保留 `npx` 但**锁定版本**。
- `v2.0.1`：修复 macOS 上 `.sh` 的 `$VAR` 紧跟中日韩字符导致 `unbound variable`、Windows 上内联 Python 中文编码崩溃、CI gitleaks 下载地址 404；并新增两道闸门（`.sh` 变量名可移植性静态扫描、`ZCODE_SKIP_OS_GUARD=1` 让 Windows 也能跑到 `.sh` 主体）。
- `v2.1.0`（2026-10-07）：
  - **纳管两大核心开发与逆向技能**：纳管 `agent-reach`（16 平台全网调研路由）与 `apk-reverse`（Android APK 逆向工程与分析），全库技能增至 40 个（191 文件）。
  - **同步全局指令与发布规范（AGENTS.md）**：引入 GitHub 发行版与版本发布规范（Release 标题与 tag 注释严格对齐 `v<X.Y.Z>: <中文核心摘要>`）、README 维护规范、接力开发文档规范（HANDOFF.md 强制六大核心模块模板）与四文档齐备门禁；修正 Windows 代理端口为 7900。
  - **解决 chezmoi 保留前缀冲突**：`apk-reverse/scripts/run_probe.py` 命中 `run_` 脚本前缀，使用 `literal_run_probe.py` 转义；更新验收套件 `tests/acceptance.sh` 的 `decode()` 函数支持 `literal_` 还原校验。
  - **验收沙箱加固**：修复 `winpath_backslash` 在 Git Bash 子 shell 中反斜杠转义丢失，修复 R0b 步骤 PowerShell 未深度隔离沙箱环境变量的问题。全量验收测试通过（ACCEPTANCE PASS）。

## 5. 接力开发指引与待办（Next Steps / Backlog）

按优先级：

1. **macOS / Linux 真机实测（P0，阻塞"三平台可用"的对外声明）**：跑一遍单命令部署，确认 `~/.zcode` 路径、`/usr/bin/python3` 存在性、`exact_` 权限语义、`npx` 三包可启动；结果补进 VERIFY.md。
2. **ZCode 读取 `installed_plugins.json` 的行为（P1）**：在新机上观察 `installPath` 指向空缓存目录时，ZCode 是提示安装还是误认为已装。若为后者，考虑把该文件改为不渲染 `plugins`，或干脆不同步。
3. **存量机（主力 Windows 机）切换（P1）**：切之前必须 `tools/adopt-local-skills.ps1 -Add` 纳管本机未跟踪技能——本机现有 **39** 个技能目录而仓库侧 38 个（多出的是 `agent-reach`），直接 apply 会被 `exact_` 删除。建议流程：备份 `~/.zcode` → `chezmoi diff` 全量审阅 → adopt → apply → 与备份比对差异清单。
4. **`exact_` 与 `npx skills add` 的摩擦（P2）**：目前靠 adopt 助手 + README 纪律兜底。若嫌麻烦，可去掉 `exact_` 前缀（代价：仓库下线技能会在本机残留）。决策前建议先实测一两周的日常手感。
5. **MCP 版本升级流程（P2）**：升级时需**同时**改 `modify_config.json.py.tmpl`、`mcp-deps.yaml`、README 三处（CI 漂移检查只校验名字一致性，不校验版本号一致性——可考虑把版本号也纳入漂移检查）。
6. **chezmoi 版本升级（P3）**：升到含 `chezmoi:modify-template` + `.chezmoi.stdin` 的版本后，可评估把 `config.json` 合并改回纯模板实现（省掉 Python 依赖）。届时需重跑验收。

## 6. 关键避坑与运行约束

以下均为 2026-10-06 实测结论（原始记录见 PROBES.md），**改动相关文件前务必先读**：

1. **`modify_` 脚本的目标名与解释器**：chezmoi 依次剥掉 `.tmpl` 与**已注册的脚本扩展名**。因此文件必须叫 `modify_config.json.py.tmpl`（`.py` 是内置脚本扩展名，剥掉后目标名才是 `config.json`）。**不要把 `.json` 注册进 `[interpreters]`**——那会把目标名剥成 `config`。
2. **Windows 不读 shebang**，按扩展名选解释器。解释器必须由 `.chezmoi.toml.tmpl` 的 `[interpreters.py]` 指向采集到的绝对路径；不要依赖命令名 `python3`（主力机上是失效的商店跳转桩）。
3. **`.chezmoiignore` 匹配"派生后的目标名"**：排除 run_once 脚本要写 `10-install-mcp-deps.sh`，写源文件名无效。
4. **`chezmoi diff` 会把 `run_` 脚本列为新增文件**：任何幂等断言都必须加 `--exclude=scripts`，否则 diff 永远非空。
5. **source 中以 `.` 开头的目录会被忽略**：`humanizer/.claude-plugin`、`humanizer/.github` 已改名为 `dot_claude-plugin`、`dot_github`，目标侧仍还原为点号目录。新增技能若含点号目录，同样需要 `dot_` 编码。
6. **`.ps1` 必须带 UTF-8 BOM**：Windows PowerShell 5.1 会把无 BOM 的 UTF-8 按系统代码页解码，直接语法报错。
7. **断言不要匹配 PowerShell 的中文输出**：其 stdout 走系统代码页。两个 run_once 脚本已输出 ASCII 标记 `platform=windows|unix` / `skipped-by-unix-script`，验收只匹配 ASCII。
8. **测试隔离用 `--destination` / `-c` / `--persistent-state` 三件套**，不要用 `HOME=` 覆盖（Windows 上 chezmoi 走 `USERPROFILE`，`HOME` 不生效）。
9. **`exact_skills` 有删除语义**：任何"目标目录多出来的东西"都会在下一次 apply 被删。改动该目录结构时，同步更新 `tests/acceptance.sh` 的 R2b 断言（它按 `dot_` / `literal_` 解码规则比对 191 个文件）。
10. **CI 的 `tests/acceptance.sh` 不做真机改动**：R3 的只读障碍在 Windows 上会让 apply 失败、在类 Unix 上可能被 rename 语义绕过，脚本对两种结果都接受，只对"技能树被清空/半套"零容忍。
11. **技能源码中以 `run_` 开头的文件必须使用 `literal_` 转义**：chezmoi 会将 `run_` 开头的文件误判为执行脚本，导致排除脚本时无法部署为普通文件；必须重命名为 `literal_run_*.py`，chezmoi 部署时会自动剥离 `literal_` 前缀恢复文件名。
