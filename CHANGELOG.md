# 变更日志（CHANGELOG）

本仓库遵循语义化版本；每次发布在 `main` 上打 annotated tag，并同步 GitHub Release。

## v2.0.0 — 2026-10-06

chezmoi 化迁移：从"Windows 专用 PowerShell 脚本"改为三平台单命令部署的 chezmoi source state。

### 新增

- **chezmoi source state**：仓库根即 source state，`dot_zcode/` → `~/.zcode/`，支持 macOS / Linux / Windows 一条命令部署。
  - macOS/Linux：`sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply https://github.com/wjf1/zcode-dotfiles.git`
  - Windows：`powershell -ExecutionPolicy Bypass -c "iwr -useb https://get.chezmoi.io | iex; chezmoi init --apply https://github.com/wjf1/zcode-dotfiles.git"`
- **`.chezmoi.toml.tmpl`**：首次 init 交互采集 `zcodePythonPath` 与 `zcodeCodebaseMemoryPath`（`promptStringOnce`，每机只问一次），并据此注入 `[interpreters.py]`。
- **`dot_zcode/cli/modify_config.json.py.tmpl`**：`config.json` 深合并源，stdin 读目标当前内容、stdout 输出合并结果。模板声明的 MCP 条目整体覆盖同名条目，**目标机独有 server 与顶层自定义键原样保留**，全程非交互、幂等。
- **`dot_zcode/cli/plugins/installed_plugins.json.tmpl`**：`installPath` 按本机 `homeDir` 渲染，取代旧的 `__ZCODE_HOME__` 字符串占位符替换。
- **`mcp-deps.yaml`**：5 个 MCP 的分级清单（绿/黄/红）作为唯一事实源，CI 对照它做漂移检查。
- **`run_once_after_10-install-mcp-deps.{sh,ps1}`**：每机执行一次的依赖检测 + **渲染产物自检**（逐个校验 `config.json` 里声明的 command 是否真实存在）。
- **`tests/acceptance.sh`**：本地与 CI 共用的验收脚本，覆盖 R0–R5 与结构断言，全程在 `.test-home/` 沙箱执行。
- **`tools/adopt-local-skills.{sh,ps1}`**：纳管 `~/.zcode/skills/` 中未跟踪的技能（应对 `exact_` 语义）。
- **`tools/install-statusbar.{sh,ps1}`**：克隆 token 用量状态栏 MCP 的上游仓库。
- **`.github/workflows/acceptance.yml`**：ubuntu / macos / windows 三平台验收矩阵 + gitleaks 密钥扫描。
- **`PROBES.md` / `VERIFY.md` / `HANDOFF.md`**：探测结论（含 10 项实测）、验收记录、接力开发指引。
- **`legacy/README.md`**：旧脚本归档声明与遗留问题留档。

### 变更

- **MCP 启动方式**：由机器私有目录的包装器（`E:\OpenCode\*.cmd`，npm 本地安装生成的 bin shim）改为 `npx -y <pkg>@<version>`，去掉硬编码的 `E:\OpenCode` 依赖，**同时锁定版本**：`@upstash/context7-mcp@4.1.0`、`@modelcontextprotocol/server-sequential-thinking@2026.8.31`、`chrome-devtools-mcp@1.9.0`。裸 `npx -y <pkg>` 会静默浮动到最新版，故不采用。
- **`deploy.ps1` / `export.ps1`** 移入 `legacy/`，定位为"历史归档与行为参照"：两者都硬依赖已删除的 `files/` 目录，**迁移后不可执行**，任何文档不得称其为 fallback。
- **token 用量状态栏 MCP**：不再把 `usage_mcp.py` vendor 进本仓库（上游 `wjf1/zcode-token-usage-statusbar` 是独立发布的项目，vendor 会造成长期漂移），改为提供克隆脚本 + 部署后提示。
- **skills 目录**：`files/skills/` → `dot_zcode/exact_skills/`，38 个技能 / 68 个文件逐字节不变；其中 `humanizer` 下的两个点号目录（`.claude-plugin/`、`.github/`）按 chezmoi 规则编码为 `dot_claude-plugin/`、`dot_github/`（源侧编码，目标侧仍还原为点号目录）。
- README 重写为中英双语，补齐回写矩阵、回滚配方、`exact_` 警告、手动步骤与已知限制。

### 修复

- **R0（P0，路径注入 JSON）**：归档件 `legacy/deploy.ps1` 的合并分支原先把未转义的本机路径写入 JSON（`Replace($ph, $home_)`），在 Windows 上会产生非法转义使 `config.json` 无法解析；已统一改为 `$escHome`（转义形式）并提升为脚本级变量。验收脚本对该修复做静态检查，并在沙箱内**真跑一遍**归档脚本、断言产出 JSON 合法。
- **R1（P1，静默清除自定义 MCP）**：旧脚本用 `Add-Member -Force` 做顶层整键覆盖，会清掉目标机自定义 server；新方案改为深合并并保留目标独有内容。
- **R2（P1）**：verbatim 文件（`AGENTS.md`、`commands/usage.md`、`known_marketplaces.json`）与 skills 部署后与源逐字节一致，不再有字符串替换环节。
- **R3（P1，skills 非原子）**：旧脚本"先 `Remove-Item` 再复制"存在半套风险；chezmoi 逐文件写入，中途失败不会清空技能树，且重跑收敛。
- **R4（P1，备份堆叠）**：旧脚本按秒级时间戳无限堆叠 `.zcode-backup-*`；新方案不再产生备份目录，apply 幂等。
- **R5（P1）**：`installed_plugins.json` 不再残留 `__ZCODE_HOME__` 字面量，`installPath` 渲染为本机真实路径。

### 安全加固

- 凭证类内容（OAuth token、API 密钥、会话、日志、插件缓存）明确排除在同步范围外（L4）。
- CI 增加 gitleaks 全量历史与工作区扫描。

### 已知限制 / 待人工验证

- **Python 3 为必需依赖**：`config.json` 合并脚本以 Python 3 执行。解释器来自 init 采集的绝对路径，不依赖命令名 `python3`（主力机上 `python3` 是失效的微软商店跳转桩，rc=49）。缺 Python 时该目标 apply 报错、其余目标不受影响。
- **chezmoi 版本**：实测 v2.73.0；官网文档描述的 `chezmoi:modify-template` + `.chezmoi.stdin` 机制在该稳定版中**不存在**，故未采用。
- **macOS / Linux 真机未实测**：由 CI 三平台矩阵覆盖，本地仅在 Windows 上跑通。
- **`exact_` 语义的日常纪律**：用 `npx skills add` 装的新技能必须立刻 `tools/adopt-local-skills --add`，否则下次 apply 会被删除。
- **ZCode 是否读取 `installed_plugins.json` 的 `installPath`** 待真机观察。
