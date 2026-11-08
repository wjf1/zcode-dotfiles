# ARCHITECTURE.md

> matklad 惯例：只写不常变的内容，不与代码逐次同步，回答「X 在哪 / 这个模块干嘛的」。
> 滚动状态（最近变更、待办、避坑实录）见 HANDOFF.md；发布记录见 CHANGELOG.md；验收实录见 VERIFY.md；chezmoi 行为探测见 PROBES.md。

## 1. 鸟瞰问题

ZCode 桌面版把用户级配置（默认指令、技能、命令、MCP server、插件）存在 `~/.zcode/`，这些内容在多台机器（macOS / Linux / Windows）之间无法天然一致。本仓库用 chezmoi 做跨机器同步：**仓库根目录即 chezmoi source state（唯一事实来源）**，目标机一条命令完成部署，之后 `chezmoi update` 跟进：

```sh
git clone <repo> ~/.local/share/chezmoi    # 手动落源目录（避开 chezmoi init 克隆的代理坑）
chezmoi init --promptDefaults --apply      # 非交互渲染 + 落位 + 跑脚本
```

核心张力不在「复制文件」，而在三件事：

1. **部分合并**：`cli/config.json` 是 ZCode 与用户共同持有的运行时文件，不能整文件覆盖——模板声明的 MCP server 要落下去，用户自己的 server、顶层键与手动禁用开关要保住。
2. **删除语义**：`exact_skills/` 镜像整个技能目录，目标侧任何未纳管技能都会在 apply 时被删。仓库用「apply 前只读审计 + adopt 助手 + ignore 显式排除」三道防线守住这条边界。
3. **机器差异**：解释器路径、平台命令名、OS 专属脚本，全部由 chezmoi 模板机制（`.chezmoi.toml.tmpl` 采集 + `.tmpl` 条件渲染 + `.chezmoiignore` 按 OS 排除）消化，不硬编码任何本机路径。

同步范围：默认指令（`dot_zcode/AGENTS.md`）、全部技能（`exact_skills/`，40 个）、`commands/` 命令、`cli/config.json` 的 MCP 与插件开关声明、插件安装记录。

明确不同步（L4，需本机重建）：凭证与登录态、会话、`~/.zcode/v2/` 运行时目录（含明文 API Key 的 provider_config）、插件与市场缓存、状态栏 MCP 脚本本体（由 tools/install-statusbar 克隆上游获取）。

## 2. codemap

仓库根（除文档外）全部是 chezmoi source；源文件名到目标路径的映射遵循 chezmoi 前缀规则（`dot_` → `.`、`exact_` → 精确镜像、`run_`/`once_`/`before_`/`after_` → 执行脚本、`literal_` → 剥前缀还原、`modify_` → modify-template）。

```
仓库根 = chezmoi source state
├── .chezmoi.toml.tmpl        # init 时 promptStringOnce 采集 zcodePythonPath / zcodeCodebaseMemoryPath
│                             #   （机器特定路径的唯一入口）；[interpreters.py] 仅为 statusbar MCP 兜底
├── .chezmoiignore            # 仓库自有文档不部署；按 OS 排除对侧脚本（写派生目标名！）；
│                             #   ppt-master 与 known_marketplaces.json 显式排除
├── mcp-deps.yaml             # MCP 分级清单（green/yellow/red），CI 漂移检查的对照基准
├── dot_zcode/                # → ~/.zcode/
│   ├── AGENTS.md             # 用户全局指令（verbatim 部署，双向合并场景的常客）
│   ├── commands/             # usage.md（token 用量查询命令）、enhance.md（✨ 浮层失效兜底命令）
│   ├── cli/modify_config.json   # config.json 深合并：chezmoi:modify-template（无 .tmpl 后缀）
│   ├── cli/plugins/installed_plugins.json.tmpl  # 插件安装记录，installPath 按 homeDir 渲染
│   └── exact_skills/         # → ~/.zcode/skills/（40 个技能镜像，唯一带删除语义的目录；
│                             #   点号目录用 dot_ 编码，技能内 run_ 文件用 literal_ 转义）
├── run_before_00-skills-audit.{sh,ps1}   # apply 前只读审计：UNMANAGED 技能打标，永不阻塞
├── run_once_after_10-install-mcp-deps.{sh,ps1}  # 依赖检测 + config.json 渲染自检 + 幂等插件安装
├── tests/acceptance.sh       # R0–R5 + T2.x 验收（本地与 CI 共用），沙箱 .test-home/
├── tools/adopt-local-skills.{sh,ps1}     # 列出未纳管技能；--add 纳管（软链/junction 实体化）
├── tools/install-statusbar.{sh,ps1}      # 克隆上游 zcode-token-usage-statusbar（不 vendor）
├── .github/workflows/acceptance.yml      # 三平台矩阵跑 acceptance.sh + gitleaks 密钥扫描
└── legacy/                   # 迁移前 PowerShell 实现（deploy/export），归档不可执行
```

技能（`exact_skills/` 下 40 个，约 197 文件）按来源两类：一是方法论/流程类（`spec-driven-development`、`test-driven-development`、`ponytail` 族、`security-and-hardening` 等），二是工具/逆向类（`apk-reverse`、`agent-reach`、`mcp-builder`、`enhance` 等）。增删技能不改验收断言——`tests/acceptance.sh` 的技能计数按源侧目录动态生成。

文档侧：README.md（双语使用手册）、CHANGELOG.md（变更记录）、HANDOFF.md（滚动状态与待办，静态模块 1/2/3 引用本文件）、PROBES.md（chezmoi 行为探测结论）、VERIFY.md（真机验收实录）。

`tests/acceptance.sh` 的验收编号速查（回答「R0–R5 各验什么」）：

| 编号 | 验什么 |
|---|---|
| T2.1 | 隔离全量部署 + `~/.zcode` 结构断言（含「known_marketplaces.json 不得被部署」反向断言） |
| R1/R1b | 自定义 MCP server 保留；模板条目继承目标机 `enabled` 开关 |
| R2/R2b | verbatim 文件与技能树逐字节一致（按 `dot_`/`literal_` 解码规则比对） |
| R3 | 技能树原子性：apply 失败时技能树既不被清空、也不残留半套 |
| R4 | 幂等：二次 apply 无漂移（`diff --exclude=scripts`） |
| R5 | `installed_plugins.json` 渲染正确（installPath 按 homeDir） |
| R0 | legacy 归档件的 P0 路径注入缺陷（静态 + 沙箱动态复验） |
| 附加 | `mcp-deps.yaml` ↔ 模板版本级双向漂移检查、run_before/run_once 语法与三态夹具、shell 可移植性静态闸门 |

## 3. 架构不变量

- **config.json 合并语义**：从目标现状（stdin）出发，只写模板声明路径。MCP 条目整对象替换（模板为准），但目标机已有的 `enabled`/`enable` 布尔开关被继承——用户在设置页禁用的 server 不被 apply 还原。未声明条目与顶层键天然保留。实现一律用 `index` 导航目标数据（`missingkey=error` 下 `.field` 会炸），模板自有键才用 `.field`。
- **exact_skills 删除语义是刻意的**：保证技能树跨机精确一致。它同时是本仓库最大的事故源（`run_` 前缀误判、点号目录、软链、未纳管技能被删共四次），因此改动该目录必须同步 `tests/acceptance.sh` 的 R2b 断言，且新增技能前先跑 `tools/adopt-local-skills.sh` 或确认 `.chezmoiignore` 有排除项。
- **凭证与 L4 内容不同步（红线）**：`~/.zcode/v2/`（`provider_config.json` 含明文 API Key）、登录态、会话、插件缓存一律不纳管，需本机重建。gitleaks 扫描工作区与全量历史兜底；`installed_plugins.json` 只含 URL 与 sha256，不含凭证。
- **不 vendor 上游独立项目**：`usage_mcp.py` 等脚本本体不随仓库走，由 `tools/install-statusbar` 克隆上游；本仓库只管引用与配置。
- **legacy/ 不可执行**：旧 PowerShell 脚本硬依赖已删除的 `files/` 目录，一次都跑不起来；仅作行为参照，不作为 fallback。
- **验收断言只用 ASCII 标记**：PowerShell 5.1 中文输出走系统代码页不可靠，脚本输出统一 `platform=windows|unix`、`[skills-audit] OK|WARNING|SKIP` 这类 ASCII 标记。
- **`.chezmoiignore` 匹配「派生后的目标名」**：排除 run 脚本要写 `10-install-mcp-deps.sh` 这类剥掉前缀后的名字，写源文件名无效；同目录以 `.` 开头的源文件会被 chezmoi 忽略，点号目录须先 `dot_` 编码。
- **`.test-home/` 是验收沙箱产物**（gitignore，不入库）：验收脚本每次在沙箱里重建整个 `~/.zcode` 镜像，绝不复用本机真实状态。
- **MCP 条目显式声明 `"type": "stdio"`**：摆脱 chezmoi/ZCode「缺 type 自动归一化」的兼容逻辑；同时刻意不写 `enabled`（继承语义归合并逻辑管）。
- **刻意不做**：
  - 目标 `config.json` 损坏时 apply **快速失败**（Go 模板无 try/catch），不留档后按空对象合并——相对旧 Python 版是有意降级，逼用户先修复再 apply。
  - `known_marketplaces.json` 不纳管：`pluginCount`/`lastUpdated` 由 ZCode 刷新时自写，纳管只产生周期性伪差异。
  - `ppt-master` 不入库（62MB / 13149 文件），用 `.chezmoiignore` 显式隔离，作为「本机自装、可选同步」类技能的原型（长程方向是引入 `dot_zcode/skills/` 非 exact 承载）。
  - 双向演进后的 AGENTS.md 合并只做**并集**，不做单向覆盖（apply 或 add 都会静默丢另一侧独有章节）。
  - NPM 依赖不追 latest，全部锁版本；升级走「改两处 + CI 漂移检查兜底」流程。

## 4. 层与系统边界

```
chezmoi source（本仓库）
   │  verbatim / .tmpl 渲染 / exact_ 镜像
   ▼
目标机 ~/.zcode/ ←── apply（run_before 审计 → 内容落位 → run_once_after 检测）
   ▲
   └── modify_config.json 反向通道：stdin 读目标 config.json 现状 → 合并 → stdout 写回
```

- **仓库管声明层，ZCode 管运行时态**：`config.json` 的 enabledPlugins 实际状态、`known_marketplaces.json`、`v2/provider_config.json` 由 ZCode 运行时自己读写，仓库只维护初始声明与「用户手动禁用不被还原」这一条继承规则。
- **机器特定路径只从 `.chezmoi.toml.tmpl` 进入**：`zcodePythonPath`、`zcodeCodebaseMemoryPath` 经 `promptStringOnce` 采集，非交互部署用 `--promptDefaults`；不依赖命令名 `python3`（部分机器上是商店跳转桩）。
- **脚本与内容分层**：`run_` 脚本负责副作用（依赖检测、插件安装）与守卫（审计），从不携带配置数据；配置数据全部走文件部署路径。插件安装优先 `zcode plugins install`（CLI 幂等），`installed_plugins.json.tmpl` 只是无 CLI 环境的兜底记录。
- **测试边界**：`tests/acceptance.sh` 用 `--destination` / `-c` / `--persistent-state` 三件套把一切指向 `.test-home/` 沙箱，绝不触碰真实 `~/.zcode`；CI 矩阵跑同一脚本，本仓库真机验收目前仅在 Windows 完成。
- **一次 apply 的完整时序**（便于定位问题发生在哪一环）：
  1. 渲染 `.chezmoi.toml.tmpl` 得到本机配置（首次 init 走 `promptStringOnce` 交互）；
  2. `run_before_00-skills-audit` 执行：只读扫描技能目录，未纳管技能打 `UNMANAGED`（不阻塞）；
  3. 内容落位：verbatim 直拷、`.tmpl` 模板渲染、`exact_skills` 镜像（多余即删）、`modify_config.json` 以 stdin/stdout 完成 config.json 合并；
  4. `run_once_after_10-install-mcp-deps` 执行（内容变更时才跑）：Node/Python 依赖检测 → config.json 渲染产物自检 → zcode CLI 幂等装插件（失败仅 WARN）；
  5. 部署完成后新开的 ZCode 进程读取 `~/.zcode` 生效；运行时态（插件缓存、市场缓存）从此归 ZCode 自己维护。

## 5. 横切关注点

- **幂等性**：apply 可重复执行不产生漂移；核验必须 `chezmoi diff --exclude=scripts`（否则 run_ 脚本永远显示为新增）。`run_once_` 内容不变不执行——所以「装完技能几天后才 apply」的场景只能靠 `run_before_` 审计守卫覆盖。
- **版本级漂移检查**：MCP 依赖在 `mcp-deps.yaml` 登记（含 `pkg@x.y.z` 锁定版本，含 scoped 包），CI 双向比对 yaml ↔ `modify_config.json`，升级漏改一处即红；README 不登记版本号、不纳入检查。
- **平台差异**：Windows 不读 shebang、按扩展名选解释器；`.ps1` 必须带 UTF-8 BOM（否则 PowerShell 5.1 按系统代码页解码直接语法报错）；`npx` 在 Windows 为 `npx.cmd`；POSIX 脚本中 `$VAR` 紧跟中日韩字符写 `${VAR}`（macOS bash 3.2 + `set -u` 的坑）；测试隔离不能只设 `HOME=`（Windows 走 `USERPROFILE`）。`.sh`/`.ps1` 成对提供、按 OS 经 `.chezmoiignore` 互斥部署。
- **命名编码即语义**：chezmoi 前缀（`dot_`、`literal_`、`modify_`、`run_before_`/`run_once_after_`）携带部署行为，技能内新增文件前先确认不触发这些前缀。
- **伪差异与实质差异**：双向同步前先分类——行尾（CRLF/LF）、时间戳、`lastUpdated` 类缓存字段是噪音；章节增删是实质。判定后再合并，避免误并或漏并。
- **密钥/令牌处理**：全仓库无凭证；CI gitleaks 扫全量历史；代理地址等易变环境信息以「会漂移、以实际监听为准」的措辞记录，不写死敏感值。
- **两条升级路径**（各改哪里，升级前重跑验收）：
  - MCP 依赖升级：改 `mcp-deps.yaml` 与 `dot_zcode/cli/modify_config.json` 两处的 `pkg@x.y.z`，CI 漂移检查兜底漏改；
  - chezmoi 升级：本仓库在 v2.73.0 实测基线上，`modify-template` 的属性声明、扩展名剥离、`.chezmoiignore` 模板化是关键依赖，升级前必须重跑 `tests/acceptance.sh` 并更新 PROBES.md 探测结论。
