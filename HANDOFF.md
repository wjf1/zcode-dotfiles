# HANDOFF.md —— 接力开发文档

> 新会话 / 新 Agent 接手本仓库时，除 README、CHANGELOG 外请**优先读本文件**，可快速建立对当前代码真实进展与未竟任务的心智，无需全盘探索。

## 1. 项目概况与当前状态

- **定位**：ZCode 桌面版（AI 编码工具）的跨机器配置同步仓库，chezmoi 管理，三平台单命令部署。
- **当前版本**：`v2.1.3`（2026-10-12）——补并 v2.1.2 遗漏的「任务清单同步」章节（18886 → 19666 字节）；本机（主力 Windows 机）`chezmoi apply` 后与源逐字节一致
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
- `v2.1.1`（2026-10-08）：
  - **输出语言规则强化**：`AGENTS.md` 该章节改为覆盖客户端全部透传字段（TodoWrite `content`、任务卡片标题、进度描述等），并明确「例外清单」与中英混排语序。
  - **代理条目按实测重写**：记录 Windows 系统代理指向 Clash Verge 混合端口 `127.0.0.1:7900`（会漂移）、npm 需单独配置代理、`chezmoi init` 克隆时把系统代理误解析为无端口 `127.0.0.1` 的已知坑与绕行方式。
  - **主力机完成 chezmoi 接管**：见第 5 节第 3 条（已结项）。
- `v2.1.2`（2026-10-12）：
  - **`AGENTS.md` 双向合并**：以主力机 2026-10-11 版为基线，吸收仓库 v2.1.1 的增量，形成两侧超集（15227 → 18886 字节）。新增 `## 前端 DOM 变更验收规范`（id 唯一性硬门禁 / DOM 断言校验祖先链 / UI 真实点击走查 / 遮挡排查顺序 / 同 URL 资源 no-cache）、「全文优先级索引」、「Tag 与项目版本常量的映射」、Token 效率「不豁免质量门禁」、README 规范「同分支同步提交」；保留 v2.1.1 的输出语言强化与代理条目（合并为「CLI 与 npm 不读 Windows 系统代理」）。
  - **纠正上一轮的接管状态记录**：本轮复核发现本机 `~/.local/share/chezmoi` 源目录与 chezmoi 配置均缺失（v2.1.1 记录的接管实际未生效 / 已丢失），已按「先手动 clone 到源目录、再 `chezmoi init --promptDefaults --apply`」路径重新完成接管。详见第 5 节第 3 条。
  - **顺带成为「双向同步」这一新场景的首个样本**：云端与某台已部署机的 `AGENTS.md` 各自演进后，需按「并集合并」而非「单向覆盖」处理——单向 apply 会静默丢掉本地独有的规范章节。合并时先用文件级 diff 判定差异是「行尾 / 时间戳噪音」还是「实质内容」，避免误合并。
- `v2.1.3`（2026-10-12）：
  - **补并 v2.1.2 遗漏的本地增量**：`AGENTS.md` 补入 2026-10-10 加入本机但 v2.1.1 / v2.1.2 均未收录的 `## 任务清单同步（TodoWrite / 会话卡片）` 章节（18886 → 19666 字节），并同步更新「全文优先级索引」；`chezmoi apply` 后本机 `~/.zcode/AGENTS.md`、`cli/config.json` 与源逐字节一致（config.json 顺势补上落后的 `zcode-token-usage-statusbar.timeoutMs`）。
  - **「双向同步」场景的第二个样本**：与 v2.1.2 的"云端 vs 主力机"合并相比，本次是"两次合并都漏掉了本机存量节"——处理路径固定为「先拉齐云端（`git -c http.proxy= pull` 绕开故障代理）→ 源文件做并集编辑 → `chezmoi apply` 落地 → 文档四件套 + tag + 推送」，全程不做单向覆盖。

- `v2.2.0`（2026-10-29）：
  - **`AGENTS.md` 三节新规范入库（本机领先版本回推）**：本机 2026-10-28 完成的规范整编未回推云端，本次以本机为准入库（21745 → 26760 字节 / 168 行）。新增 `### 社区健康文件规范`（CONTRIBUTING / SECURITY 触发条件、`.github/` 内聚）、`### 项目级 AGENTS.md 规范`（项目级 agents.md 分层）、`### ARCHITECTURE.md 规范`（超 1 万行项目必维护，五要素 + 半年复审）；并按四分区（环境硬约束 / 行为与验收规范 / 仓库工程规范 / 专用环境附录）重排全文加编号。**逐行反向核对确认：仓库版无任何一条有效规则被本机版丢失**，仓库侧那些"独有行"均为被改写升级的旧表述。
  - **`humanizer` 升级 3.1.0**：新增 `CHANGELOG.md`、`.cursor-plugin/plugin.json`、`.github/ISSUE_TEMPLATE/` 三模板 + `validate.yml`；`SKILL.md` 补第 6 类痕迹「Wrong reader」；`validate-package.py` 增加对 CHANGELOG 与 cursor 插件的校验。经 `dot_` 前缀编码纳管，上游自带的 `.git` 刻意排除（跨机同步无意义且会冲突）。
  - **`known_marketplaces.json` 解除纳管**：其 `pluginCount` / `lastUpdated` / `cacheTransactionId` 由 ZCode 刷新市场时自行改写，纳管只会产生周期性伪差异（本机 56/315 vs 快照 40/291）。已加入 `.chezmoiignore`，本机文件原地保留。
  - **`ppt-master` 误删风险处置**：本机 62MB / 13149 文件的 `ppt-master`（12193 个 SVG 模板 + 131 个 `__pycache__/*.pyc`）从未入库，`exact_` 语义会在 apply 时删除它（`chezmoi status` 已显示 ` D`）。因体量不适合入库，改为 `.chezmoiignore` 显式排除。**这是 `exact_` 语义第 3 次绊人**（前两次为 v2.1.0 apk-reverse 前缀冲突、v2.1.3 的 static 技能漏并）。
  - **验收脚本随之校准**：`tests/acceptance.sh` 技能文件数 191 → 196、托管目标 5 → 4、移除 `known_marketplaces.json` 的 verbatim 哈希比对并反向断言其「不得被部署」；`VERIFY.md` 同步数字与描述。
  - **「双向同步」场景的第三个样本**：本次与前两次的区别是**差异全部来自本机、云端零改动**（`git log HEAD..origin/main` 为空），确认方向为「本机 → 云端回推」而非拉取；仍按「先 diff 判定实质差异 → 源文件覆盖 → apply 收敛 → 文档四件套」路径执行。

## 5. 接力开发指引与待办（Next Steps / Backlog）

按优先级：

1. **macOS / Linux 真机实测（P0，阻塞"三平台可用"的对外声明）**：跑一遍单命令部署，确认 `~/.zcode` 路径、`/usr/bin/python3` 存在性、`exact_` 权限语义、`npx` 三包可启动；结果补进 VERIFY.md。
2. **ZCode 读取 `installed_plugins.json` 的行为（P1）**：在新机上观察 `installPath` 指向空缓存目录时，ZCode 是提示安装还是误认为已装。若为后者，考虑把该文件改为不渲染 `plugins`，或干脆不同步。
3. ~~**存量机（主力 Windows 机）切换（P1）**~~ **已完成（2026-10-08），并于 2026-10-12 复核后重新接管**：主力机装好 chezmoi v2.73.0 并接入源仓库（`~/.local/share/chezmoi`）。切换前已把本机技能补齐到与仓库一致的 40 个（`agent-reach`、`apk-reverse` 手工落位，含 `literal_` 前缀还原），故 `exact_` 无删除动作。
   - **2026-10-12 复核结论**：本机 `~/.local/share/chezmoi` 与 `~/.config/chezmoi/chezmoi.toml` 均不存在（`chezmoi doctor` 报 source-dir error），即上一轮记录的"接管"在本机并未真正生效。**教训**：`chezmoi init --apply` 是否落地必须用 `chezmoi doctor` / `chezmoi status` 复核，不能只看命令退出码。
   - **本轮接管路径**（避开已知的代理坑）：先 `git clone <repo> ~/.local/share/chezmoi` 手动落源目录，再 `chezmoi init --promptDefaults --apply`——源目录已是 git 仓库时 chezmoi 跳过克隆，`--promptDefaults` 让两个 `promptStringOnce` 直接取默认值，全程免交互（否则 agent 会话里会卡在交互提示）。
   - 实际踩到的坑（已记入第 6 节）：`chezmoi init` 的克隆会被系统代理坑住（改用手动 clone 到源目录）；`core.autocrlf=true` 使工作区为 CRLF，直接编辑源文件时须先做行尾归一化。
   - **2026-10-12 二次复核（v2.1.3 发布时）**：接管本次确认生效——`chezmoi status` 空输出、`chezmoi apply` 幂等、`~/.zcode/AGENTS.md` 与 `cli/config.json` 对源逐字节一致。另实测当日代理链路抖动：git 经 `127.0.0.1:7900` 访问 GitHub 握手失败、直连正常，`git -c http.proxy=` 仍是最可靠绕行。
4. **`exact_` 与 `npx skills add` 的摩擦（P1）**：目前靠 adopt 助手 + README 纪律兜底。**v2.2.0 记入第 3 次同类事故**（`ppt-master` 因未纳管而面临 apply 删除，靠 `.chezmoiignore` 兜住）。反复出现的根因是「装技能」与「纳管」是两个动作、中间无强约束。可选方向：
   - 短程：把 `tools/adopt-local-skills.sh` 的检查嵌进 `run_once` 或 pretool 钩子，装完必查；
   - 长程：去掉 `exact_` 前缀（代价：仓库下线技能会在本机残留），或用 `dot_zcode/skills/`（非 exact）承载「本机自装、可选同步」类技能——**`ppt-master` 已按后者思路用 ignore 隔离，可作为该方向的原型**。
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
12. **agent / 非交互会话里 `chezmoi init` 必须配 `--promptDefaults`（或预写配置）**：`.chezmoi.toml.tmpl` 的 `promptStringOnce` 在无 TTY 环境会阻塞或失败。默认值在本机均可用（Python312 解释器、codebase-memory-mcp.exe 都已安装），故 `--promptDefaults` 是安全选择；若要显式指定可用 `--promptString <var>=<value>`。
13. **接管是否真的生效，用 `chezmoi doctor`（source-dir / working-tree 行）+ `chezmoi status` 复核**：本机就出现过"记录为已接管、实际源目录缺失"的情况——只信命令退出码会漏判。
14. **双向演进后必须并集合并，不能单向覆盖**：云端与已部署机的 `AGENTS.md` 可能各自新增章节（如本机新增「前端 DOM 变更验收规范」而云端新增输出语言强化）。直接 `apply`（云端 → 本地）或 `chezmoi add`（本地 → 云端）都会静默丢掉另一侧的独有内容。判定差异时要先区分「行尾 / 时间戳噪音」（如 skills 的 CRLF vs LF、`known_marketplaces.json` 的 `lastUpdated`）与「实质内容」，再决定是否合并。
