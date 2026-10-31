# 变更日志（CHANGELOG）

本仓库遵循语义化版本；每次发布在 `main` 上打 annotated tag，并同步 GitHub Release。

## Unreleased

### 新增

- **apply 前技能纳管审计守卫（`exact_` 误删防线，HANDOFF 待办 4 短程方案）**：新增 `run_before_00-skills-audit.{sh,ps1}`，每次 `chezmoi apply` 前自动扫描 `~/.zcode/skills/`，把「未纳管且未被 `.chezmoiignore` 排除」的技能以 `UNMANAGED`/`WARNING`（ASCII 标记）列出并给出处置命令；只读、永不阻塞 apply。`.chezmoiignore` 按既有模式双向排除对侧脚本；`tests/acceptance.sh` 新增三态夹具（已纳管 / ignore / 未纳管）与真实 apply 执行断言。待办 5（版本号纳入漂移检查）经核对已由 v2.2.0 的 P2-2 覆盖（`mcp-deps.yaml` ↔ 模板版本级双向校验，README 不登记版本号），本次在 HANDOFF 中关闭该条。
- **纳管 `enhance` 兜底技能与命令**（来自 zcode-prompt-enhance 的 P4 交付物）：`dot_zcode/commands/enhance.md` + `dot_zcode/exact_skills/enhance/SKILL.md`，避免 `exact_` 语义误删。SKILL 正文引用本机部署路径 `F:\AI\Zcode\zcode-prompt-enhance`（单机部署语义；换机需同步调整）。

## v2.4.0 — 2026-10-26

### 变更

- **合并逻辑去 Python 化：`config.json` 改由 chezmoi 原生 `modify-template` 深合并（P2-1，灰度）**：
  - **Phase A 探测（新增 PROBES.md D11）**：`chezmoi:modify-template` 在 v2.73.0 真实可用，但**文件名必须带 `modify_` 前缀且不能带 `.tmpl` 后缀**——带 `.tmpl` 会先按普通模板渲染（stdin 未注入，报 `map has no entry for key "stdin"`），无 `modify_` 前缀的魔法注释不生效（被当普通文件原样部署）。D2 探测 1 的失败根因就此定案。
  - **实现**：新增 `dot_zcode/cli/modify_config.json`（无后缀），语义逐条对齐 Python 版——顶层未声明键天然保留、5 个 MCP 条目整对象替换并继承目标机 `enabled`/`enable` 开关（T4 语义）、`plugins.enabledPlugins` 逐键设置、`codebase-memory-mcp` 保持 Windows + 路径非空条件渲染；对目标数据一律用 `index` 导航以规避模板 `missingkey=error`。旧实现整体移入 `legacy/modify_config.json.py.tmpl`（已被 `.chezmoiignore` 排除）。
  - **灰度验证**：三组 fixture（空文件 / 含自定义 server / 含 enabled=false）上新旧实现输出**语义等价**（JSON 结构相等）；`sh tests/acceptance.sh` 全量 PASS，渲染产物为合法 JSON。
  - **依赖变化**：**部署不再需要 Python 3**（首次部署采集项相应减少）；`.chezmoi.toml.tmpl` 保留 `[interpreters.py]` 与 `zcodePythonPath`（statusbar MCP 仍需要），注释改为"仅 statusbar MCP 使用"。

### 已知限制

- **`config.json` 损坏时 apply 会失败**：Go 模板无 try/catch，目标文件为非法 JSON 或顶层不是对象时 apply 快速失败并给出明确报错——相对旧版"留档 `.broken-backup` 后按空对象合并"是**有意降级**；请先修复或删除该文件再 apply（README「已知限制」同步声明）。

## v2.3.0 — 2026-10-26

### 变更

- **合并脚本保留 per-machine `enabled` 开关（P1-1）**：`merge()` 对模板声明的 MCP 条目从"整体覆盖"改为"覆盖但继承运行态开关"——目标机已有条目的 `enabled` / `enable` 布尔值会被继承（schema 用 `enabled`，设置页实测可能写 `enable`，两者都认）。用户在 ZCode 设置页禁用的 server 不再被 `chezmoi apply` 静默还原；条目内 command / args / timeoutMs / type 仍以模板为准。验收新增 R1b 用例（改 `enabled:false` + 篡改 command 后 re-apply，断言开关保留、其余字段恢复模板值、其余 server 不受影响），README 双语同步说明。
- **插件安装改由 `zcode plugins install` 幂等执行（P1-2）**：两个 run_once 脚本在渲染产物自检后新增插件安装段——先 `zcode plugins list --json` 查询、已装即跳过（幂等）；未装则 `zcode plugins install github@zcode-plugins-official --scope user`；`zcode` CLI 缺失 / 子命令不支持 / 网络失败一律只输出 `[plugins] WARN`，**绝不非零退出**阻塞部署。`ZCODE_TEST_NO_SIDE_EFFECTS=1` 时整段跳过（验收沙箱输出 `[plugins] SKIP test-mode`，绝不真实安装插件）。`installed_plugins.json.tmpl` 保留为无 CLI 环境的兜底。验收对 .sh 主体、Windows 早退分支、.ps1、跨平台调度（真实 apply）四处全部注入测试模式变量并断言 SKIP。
- **adopt 工具识别软链 / junction 并实体化（P1-3）**：ZCode 3.16 起设置页技能导入默认以软链（Windows 为 junction）写入 `~/.zcode/skills/`，`exact_` 语义会在下次 apply 删除它们。adopt 助手现在能识别链接（sh 用 `[ -L ]` / ps1 用 `LinkType` 判定 `SymbolicLink` / `Junction`），列表输出 `unmanaged (symlink -> <target>)`；`--add` 对链接**不再 `chezmoi add`**（会把链接语义带进 source），改为实体化复制为普通目录（sh `cp -R`，ps1 `Get-ChildItem -Force | Copy-Item -Recurse`，均含点号目录），输出 `materialized -> ...`。两个脚本末尾新增行为提示；README 双语 §6 新增「ZCode 设置页技能导入」小节（导入 → 立即 adopt；要跟随上游则走 `npx skills` + adopt，并说明两种方式代价）。
- **验收计数断言参数化，去掉 40 / 191 硬编码**：`tests/acceptance.sh` 顶部按源侧 `dot_zcode/exact_skills` 的实际目录 / 文件数生成 `SKILL_DIRS` / `SKILL_FILES`（源与目标 1:1 映射，`dot_` / `literal_` 只改前缀不改数量，故直接以源侧为准），T2.1、R3、R3b 的计数断言全部改引动态值并在脚本开头输出实际计数；R2b 内联 Python 中冗余的 191 硬编码断言删除（集合比对已覆盖计数语义）。此后技能增删不再需要手改验收脚本。
- **README 新增「当你在 ZCode 设置页改了东西」+ 文档收口**：README 双语 §5 新增四类 UI 操作对照表（MCP 启停开关**保留**、command / args 修改**还原**、设置页技能导入**被删需先 adopt 实体化**、插件安装记录按模板对齐），把「UI 操作与 apply 的冲突边界」讲清；`HANDOFF.md` 版本状态与待办同步收口（T5 已替代 installPath 观察项、T3 已覆盖版本漂移、新增发布动作待办清单）；`VERIFY.md` 增补 2026-10-26 批次验收实录（T1–T7、T10 的命令 + 关键行 + 退出码 + 诚实声明）。

## v2.2.0 — 2026-10-26（2026-10-29 追补云端回推）

### 变更

- **MCP server 条目补显式 `"type": "stdio"`（P0-1）**：`modify_config.json.py.tmpl` 的 5 个声明条目（context7、sequential-thinking、chrome-devtools、zcode-token-usage-statusbar、codebase-memory-mcp）全部在对象首键显式声明传输类型，符合 ZCode ≥3.16 的配置规范，不再依赖"缺 type 自动归一化"的兼容逻辑；刻意**不加** `enabled` 字段（默认值语义归 T4/后续版本处理，避免 apply 强行重新启用用户在设置页手动禁用的 server）。验收脚本 R1 断言同步新增"四个无条件渲染的 server 必须带 `type: stdio`"检查。
- **文档补齐 ZCode 新版边界（P0-2）**：README 中英双语 §4 补明「ZCode ≥3.16 起个人模型配置独立存放于 `~/.zcode/v2/provider_config.json`（含明文 API Key），本仓库**不纳管该文件与整个 `~/.zcode/v2/` 目录**，模型与供应商在本机自行配置」，消除"该不该同步 `~/.zcode/v2/`"的模糊地带；`dot_zcode/AGENTS.md` 工具调用避坑章节在代理条目后补「ZCode 运行时网络走自己的配置」（`network.httpProxy` / `ZCODE_HTTP_PROXY` / `ZCODE_NO_PROXY` / `ZCODE_AGENT_CA_CERT`，不继承系统代理，勿把系统代理结论直接套到 ZCode 上）。
- **漂移检查升级为"名字 + 锁定版本"双向校验（P2-2）**：验收脚本的 `mcp-deps.yaml ↔ 模板` 漂移检查从"只查名字出现"升级为**版本级双向比对**——yaml 登记的每个锁定版本（`pkg@x.y.z`，含 `@scope/pkg@x.y.z`）必须被模板渲染，模板中出现的版本也必须登记在 yaml；断言失败时列出差异项，可直接定位漏改处。升级一个 MCP 不再是"改三处、查一处"。

### 新增（2026-10-29 追补）

- **`AGENTS.md` 三个新规范章节入库（本机领先版本回推）**：本机（主力 Windows 机）于 2026-10-28 完成的规范整编此前未回推云端，本次以本机版为准入库（21745 → 26760 字节，168 行）。新增三节：
  - `### 社区健康文件规范`：公开仓库标配 LICENSE + README；开始接受外部贡献（首个外部 issue / PR）时必须补齐 `CONTRIBUTING.md` 与 `SECURITY.md`；`.github/` 目录内聚维护 workflows / ISSUE_TEMPLATE / PR 模板，README 与 LICENSE 必须留根级且全大写。
  - `### 项目级 AGENTS.md 规范`：活跃项目在仓库根目录维护项目级 `AGENTS.md`（构建 / 测试 / 风格 / PR 规范），monorepo 子包可嵌套、最近者优先；与用户级全局、`HANDOFF.md` 三者分层职责明确。
  - `### ARCHITECTURE.md 规范`：代码量超 1 万行的项目在根目录维护 `ARCHITECTURE.md`（鸟瞰问题 → codemap → 架构不变量 → 层与系统边界 → 横切关注点），并规定半年复审与「HANDOFF 静态模块引用 ARCHITECTURE 不重复维护」。
  - 同时按「环境硬约束 / 行为与验收规范 / 仓库工程规范 / 专用环境附录」四分区重排全文并加分区编号，把 `技能安装规范` 归入仓库工程规范、`Command Code 代理` 归入第四分区附录。

### 变更（2026-10-29 追补）

- **`humanizer` 技能升级至 3.1.0（上游同步）**：由 3.0.0 升至 3.1.0，新增 `CHANGELOG.md`、`.cursor-plugin/plugin.json`（Cursor 插件清单）、`.github/ISSUE_TEMPLATE/` 三个模板与 `workflows/validate.yml`；`SKILL.md` 新增第 6 类写作痕迹「Wrong reader」（回复重复解释对方已知背景、结论被推到最后），`README.md` 重写为含 before/after 示例的版本，`scripts/validate-package.py` 增加对 `CHANGELOG.md` 与 `.cursor-plugin` 的校验。全部经 `dot_` 前缀编码纳管，本机 `.git` 目录已刻意排除（由上游仓库自带，跨机同步无意义且会冲突）。
- **`known_marketplaces.json` 解除纳管（改为运行时缓存，不入库）**：该文件的 `pluginCount` / `lastUpdated` / `cacheTransactionId` 由 ZCode 每次刷新插件市场时自行改写（本机 56 / 315、仓库快照 40 / 291），纳管只会让每次刷新都产生一次伪差异。现从 `dot_zcode/cli/plugins/` 移除源文件并加入 `.chezmoiignore`，本机文件保持原地不动。

### 修复（2026-10-29 追补）

- **`ppt-master` 误删风险（`exact_` 语义副作用）**：本机 `~/.zcode/skills/ppt-master`（62MB / 13149 文件，含 12193 个 SVG 模板与 131 个 `__pycache__/*.pyc`）从未入库，而 `dot_zcode/exact_skills` 的 `exact_` 镜像语义会在 `apply` 时删除任何未纳管技能——`chezmoi status` 已实际显示 ` D .zcode/skills/ppt-master`。因体量与构成不适合入库，改为在 `.chezmoiignore` 显式排除，既保住本机技能又杜绝 `apply` 误删。**这是 `exact_` 语义第 3 次绊人（前两次见 v2.1.0 / v2.1.3），`tools/adopt-local-skills.sh` 的「装完技能先跑一次」纪律仍是最优解。**

### 验证（2026-10-29 追补）

- `chezmoi status` 空输出；`~/.zcode/AGENTS.md` 与源逐字节一致；`~/.zcode/skills/ppt-master` 与 `~/.zcode/cli/plugins/known_marketplaces.json` 均在本机原地保留。
- `chezmoi apply --dry-run` 不再产生 `ppt-master` 删除动作。
- `sh tests/acceptance.sh` 退出码 0（ACCEPTANCE PASS），技能树 40 目录 / 196 文件（原 191，`humanizer` 升级带来 +5 文件）。

## v2.1.3 — 2026-10-12

### 变更

- **补并 v2.1.2 遗漏的本地增量：「任务清单同步」章节正式入库（18886 → 19666 字节，工作区 CRLF 口径）**。2026-10-10 加入本机（主力 Windows 机）`~/.zcode/AGENTS.md` 的 `## 任务清单同步（TodoWrite / 会话卡片，所有任务强制生效）` 章节未被 v2.1.1 / v2.1.2 收录，属"单向 apply 会静默丢失"的本地独有内容（HANDOFF §6 第 14 条场景的又一次出现）：
  - `AGENTS.md` 在「服务启停确认」与「Token 效率规则」之间补入该节（TodoWrite 清单为会话待办卡片唯一数据源；完成一项立即回写、禁止攒批；受阻解除立即回写；按全量清单提交、禁止漏项），并同步把「全文优先级索引」第 ② 类的规范列表补上该章节。
  - 本机（主力 Windows 机）随之完成配置对齐：`chezmoi apply` 后 `~/.zcode/AGENTS.md` 与 `cli/config.json` 与源逐字节一致；`config.json` 此前落后于模板（缺 `zcode-token-usage-statusbar.timeoutMs`），已一并补齐。

### 验证

- 本机 `chezmoi status` 空输出；`~/.zcode/AGENTS.md`、`~/.zcode/cli/config.json` 对源 diff 为空（工作区 CRLF 逐字节一致）。
- `sh tests/acceptance.sh` 在 Windows 上退出码 0（ACCEPTANCE PASS）。

## v2.1.2 — 2026-10-12

### 变更

- **`AGENTS.md` 双向合并：把主力机的本地增量并入仓库（15227 → 18886 字节）**。此前云端 `main`（v2.1.1，10-08）与主力机 `~/.zcode/AGENTS.md`（10-11）各自演进、互有对方没有的内容，本次以主力机版为基线并吸收仓库增量，形成两侧的超集：
  - **新增 `## 前端 DOM 变更验收规范`**：源自 2026-10-11 workbuddy2api-panel 事故——导出弹窗新增 `id` 与页面既有隐藏元素重名，`getElementById` 恒取文档序第一个，账号行被渲染进被遮罩的旧容器，而计数/全选逻辑"正常"、三层自动化断言全绿假阳性，连烧 1.13.1~1.13.3 三版才靠真实鼠标点击 + 祖先链定位。沉淀为：`id` 全局唯一硬门禁（含 CI 唯一性自动检测）、DOM 断言必须校验祖先链（`closest` / `contains`）、UI 交付前真实点击走查、「元素在但不显示」按祖先链 → 遮挡 → CSS 顺序排查、同 URL 的 html+js 同版本资源必须发 `no-cache`。
  - 新增「全文优先级索引」（按使用频率给全文分级）；`## GitHub 发行版与版本发布规范` 补「Tag 与项目版本常量的映射」（tag 取项目版本标识的主 `X.Y.Z`，防止两套版本号脱节）；Token 效率补「效率取向不豁免质量门禁」；README 维护规范补「任何功能新增 / 界面重构 / 配置变更 / 架构调整的提交，README 须在同一分支同步修订并随代码提交」。
  - 保留 v2.1.1 的输出语言强化措辞（覆盖客户端全部透传字段 + 例外清单 + 中英混排语序），并把代理条目合并为「CLI 与 npm 不读 Windows 系统代理」（含 7900 端口会漂移、npm 需单独配置代理、`chezmoi init` 克隆时把系统代理误解析为无端口 `127.0.0.1` 的已知坑与绕行方式）。

### 验证

- `sh tests/acceptance.sh` 在 Windows 上退出码 0（ACCEPTANCE PASS），覆盖 R0–R5 与结构断言，其中沙箱内全量 `apply` 已把合并版 `AGENTS.md` 与 MCP 模板渲染一并跑通。

## v2.1.1 — 2026-10-08

### 变更

- **`AGENTS.md` 输出语言规则强化**：由简版改为覆盖客户端全部透传字段（TodoWrite `content`、任务卡片标题、进度描述、中间状态说明），新增「例外清单」（代码标识符、命令与命令行参数、文件路径、第三方库 / API 名、工具报错原文、英文引文不翻译）与中英混排语序要求。
- **工具调用避坑：代理条目按实测重写**：补入 Windows 系统代理启用并指向 Clash Verge 混合端口 `127.0.0.1:7900`（端口会漂移，以实际监听为准）、npm 不读系统代理需单独 `npm config set proxy` / `https-proxy`、以及 `chezmoi init` 克隆时把系统代理误解析为无端口 `http://127.0.0.1` 导致失败的已知坑与绕行方式（`git -c http.proxy= clone`）。
- **主力 Windows 机完成 chezmoi 接管**：安装 chezmoi v2.73.0 并接入源仓库；切换前本机 40 个技能已与仓库对齐，`exact_` 无删除动作。详见 `HANDOFF.md` 第 5 节。

## v2.1.0 — 2026-10-07

### 新增

- **纳管两大核心开发与逆向技能（40 技能 / 191 文件）**：
  - `agent-reach`：跨 16 个内容平台（小红书、推特、B站、Reddit、YouTube 等）的全网调研、搜索与多后端智能路由。
  - `apk-reverse`：Android APK 逆向工程、静态反编译、Frida 动态插桩、去除广告与 SDK、dex 补丁与重打包分析。
- **收录新版项目治理与发布规范（AGENTS.md）**：
  - `## GitHub 发行版与版本发布规范`：强制统一 Release 标题规范 `v<X.Y.Z>: <中文核心摘要>`、四文档（版本/CHANGELOG/README/HANDOFF）齐备核验硬门禁、annotated tag 标题注释对齐。
  - `## README 维护规范`：强制中英双语维护、配图可视化说明、代码提交推送前阻塞型同步门禁。
  - `## 接力开发文档规范（HANDOFF.md）`：全项目强制统一维护六大核心模块模板、新会话接入第一步必读机制。
  - `## 代码变更发布流程`：强化功能/安全验证测试、文档更新齐备、Tag 与 Release 规范核验流程。

### 修复

- **网络代理端口配置纠偏**：将 `AGENTS.md` 中 CLI 代理说明从旧端口 `7897` 更新为当前 Clash Verge 混合端口 `7900`（2026-10-06 变更），并修正 `NO_PROXY` 环境变量描述。
- **chezmoi 特殊保留前缀兼容（apk-reverse）**：
  - `apk-reverse/scripts/run_probe.py` 命中 chezmoi 的 `run_` 脚本保留前缀，使用 `literal_run_probe.py` 进行转义，确保排除脚本时仍能作为普通文件正确部署。
  - 更新验收脚本 `tests/acceptance.sh`，增强 `decode()` 支持 `literal_` 前缀还原比对。
- **验收套件沙箱环境隔离与断言修复（tests/acceptance.sh）**：
  - 修复 `winpath_backslash` 在 Git Bash 子 shell 中反斜杠转义丢失的问题。
  - 修复 R0b 步骤中 PowerShell 进程未正确隔离用户目录导致尝试备份宿主机真实 `~/.zcode` 的缺陷，改用显式沙箱参数启动。
  - 同步调整技能目录数断言为 40，文件总数断言为 191。

## v2.0.1 — 2026-10-06

v2.0.0 推送后，CI 的三平台矩阵在 **macOS** 与 **Windows** 上暴露了三个真实缺陷，本版修复。Linux 平台自 v2.0.0 起即通过。

### 修复

- **macOS 上 run_once 脚本会崩溃（产品缺陷）**：`run_once_after_10-install-mcp-deps.sh` 中 `$STATUSBAR（`、`$CFG，` 这类"变量名紧跟中日韩字符"的写法，在 macOS 自带的 bash 3.2 下会把多字节字符吞进变量名，配合 `set -u` 直接报 `unbound variable` 并使脚本失败。已改为 `${VAR}` 花括号形式。
- **Windows 上验收脚本崩溃（测试缺陷）**：内联 Python 打印中文时，Windows runner 的 stdout 默认为 cp1252，抛 `UnicodeEncodeError`。已在验收脚本中强制 `PYTHONIOENCODING=utf-8`。
- **CI 安装 gitleaks 失败（CI 缺陷）**：资源名从 `gitleaks_<ver>_linux_amd64.tar.gz` 改成了 `linux_x64`，写死的下载地址 404。已改为从 release API 动态解析资源地址，并按可用子命令在 `dir`/`git`（8.19+）与 `detect`（旧版）之间自动选择。

### 变更

- **验收新增两道闸门，堵住上述两类缺口**：
  - **shell 可移植性静态检查**：扫描全部 `.sh`，禁止 `$VAR` 直接紧跟非 ASCII 字符（用 Python 实现，避免依赖 BSD grep 缺失的 `-P`）。
  - **`run_once` 主体覆盖**：新增 `ZCODE_SKIP_OS_GUARD=1` 测试开关，使 Windows 上也能实际执行 `.sh` 的主体逻辑——v2.0.0 的验收只在 macOS 上才第一次跑到这段代码，本版起不再有该盲区。
- `run_once` 脚本的 Windows/MSYS 早退分支改用 ASCII 标记 `platform=windows skipped-by-unix-script`，便于断言。

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
