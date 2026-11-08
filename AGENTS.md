# AGENTS.md — zcode-dotfiles

## 项目概览

ZCode 桌面版跨机器配置同步仓库：以 chezmoi（实测基线 v2.73.0）管理 `~/.zcode/` 全套配置——
AGENTS.md、技能（exact_skills/）、commands、MCP 依赖（mcp-deps.yaml）、run_ 前后置脚本与 CLI 合并模板。
本仓库是 chezmoi source state，`dot_zcode/` 目录 1:1 映射目标机 `~/.zcode/`（`dot_` 前缀解码为点号目录）。
当前版本 **v2.5.0**（2026-11-01，版本以 CHANGELOG 头部为准，无版本常量文件）。

## 构建与测试命令

无包管理器构建；验证以 chezmoi 渲染 + 验收脚本为准。以下命令均来自 `.github/workflows/acceptance.yml` 与 HANDOFF：

| 命令 | 作用 |
|---|---|
| `sh tests/acceptance.sh` | 全量验收（CI 矩阵多 OS 运行；含 R2b 按 dot_/literal_ 解码规则比对 191 个文件） |
| `chezmoi apply` | 部署配置（apply 前自动跑技能纳管审计守卫 run_before_00-skills-audit，只读不阻塞） |
| `chezmoi diff --exclude=scripts` | 查看待部署差异（必须 `--exclude=scripts`，否则 run_ 脚本永远显示新增） |
| `chezmoi doctor` + `chezmoi status` | 复核接管是否真实生效（只信退出码会漏判） |
| `chezmoi init --promptDefaults` | 非交互环境初始化（无 TTY 时 promptStringOnce 会阻塞，必配） |

CI 另含 gitleaks secret scan；本仓库纳管 AGENTS.md 等配置，不纳管 `~/.zcode/v2/`（内含明文 API Key）。

## 代码风格约定

- chezmoi 命名规则即风格：`dot_` 前缀（点号目录/文件）、`exact_`（精确镜像）、`literal_`（转义 run_ 脚本误判）、`modify_`（合并模板）、`run_before_`/`run_once_after_`（生命周期脚本）。
- Shell 脚本 POSIX 兼容（CI 在类 Unix 上跑 sh）；PowerShell 脚本必须带 UTF-8 BOM，输出只用 ASCII 标记（`platform=windows|unix` 等），断言不匹配中文。
- 文档四件套：README（双语）、CHANGELOG、HANDOFF（六模块）、ARCHITECTURE.md；探测结论沉淀进 PROBES.md。
- 探测先行：改 chezmoi 行为相关的文件前，先在 PROBES.md 查/补探测记录，不凭文档想当然。

## 提交与发布规范

- Conventional Commits + 中文描述，近期实例：`feat: ...`、`fix: ...`、`refactor: ...`、`docs(handoff): ...`、`docs(release): v2.5.0 定版——...`；云端回推线用 merge commit 标注。
- 发布走 annotated tag：`git tag -a vX.Y.Z -m "vX.Y.Z: <中文核心摘要>"`，GitHub Release 标题同格式、正文对齐 CHANGELOG；升级 chezmoi 前必须重跑 `sh tests/acceptance.sh`。

## 项目专属注意

1. **`exact_skills/` 有删除语义**：目标目录多出来的东西会在下次 apply 被删；新增/删除技能必须同步纳管或入 `.chezmoiignore`，并更新 tests/acceptance.sh 的 R2b 断言。
2. **`modify_` 目标名推导是历史事故区**：合并模板文件必须带 `modify_` 前缀且**不带任何后缀**（现名 `dot_zcode/cli/modify_config.json`）；带 `.tmpl` 会按普通模板渲染报 stdin 错误；不要把 `.json` 注册进 `[interpreters]`。
3. **`.chezmoiignore` 匹配「派生后的目标名」**（排除 run 脚本写 `10-install-mcp-deps.sh` 而非源文件名）；技能源码内 `run_` 开头文件必须 `literal_` 转义；含点号目录需 `dot_` 编码。
4. **云端与本机配置双向演进必须并集合并**，单向 apply/chezmoi add 会静默丢另一侧独有章节；判定差异先剥离行尾/时间戳噪音。测试隔离用 `--destination` / `-c` / `--persistent-state` 三件套（Windows 上 `HOME=` 不生效，chezmoi 走 `USERPROFILE`）。

根级约定到此为止；部署为用户级配置的 `dot_zcode/AGENTS.md`（= 用户全局指令全文）由 chezmoi 纳管，本文件不重复其内容，代理行为约束以它为准。接力开发优先阅读 `HANDOFF.md`（§6 避坑 14 条 + PROBES.md 探测记录）。
