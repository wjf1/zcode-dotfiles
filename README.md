# ZCode dotfiles

ZCode 桌面版（AI 编码工具）的跨机器配置同步仓库，由 [chezmoi](https://www.chezmoi.io/) 管理。
把 `~/.zcode` 里可复用的部分（默认指令、技能、命令、MCP 配置、插件来源）版本化，在 macOS / Linux / Windows 上一条命令拉取即用。

[English](#zcode-dotfiles-english) | [中文](#中文)

- 迁移前的两个 PowerShell 脚本已归档到 [`legacy/`](legacy/README.md)（**历史参照，不可执行**）
- 验收与回归：`sh tests/acceptance.sh`（本地与 CI 共用，覆盖 R0–R5）
- 探测结论：[`PROBES.md`](PROBES.md)　验收记录：[`VERIFY.md`](VERIFY.md)　接力开发：[`HANDOFF.md`](HANDOFF.md)

---

<a id="中文"></a>
## 中文

### 1. 一键部署（新机器）

```sh
# macOS / Linux
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply https://github.com/wjf1/zcode-dotfiles.git
```

```powershell
# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -c "iwr -useb https://get.chezmoi.io | iex; chezmoi init --apply https://github.com/wjf1/zcode-dotfiles.git"
```

首次执行依次完成：安装 chezmoi → 克隆到 `~/.local/share/chezmoi` → 交互采集两个本机路径 → 渲染并落盘 `~/.zcode/` → 运行一次依赖检测与渲染自检。

**首次只问两个问题**（每台机器只问一次，写入 chezmoi 配置）：

| 问题 | 默认值 | 说明 |
|---|---|---|
| `zcodePythonPath` | Windows：`%USERPROFILE%\AppData\Local\Programs\Python\Python312\python.exe`；macOS/Linux：`/usr/bin/python3` | token 用量状态栏 MCP 与 `config.json` 合并脚本使用 |
| `zcodeCodebaseMemoryPath` | Windows：`%USERPROFILE%\AppData\Local\Programs\codebase-memory-mcp\codebase-memory-mcp.exe` | 仅 Windows；未安装直接回车留空，则不渲染该 MCP |

### 2. 部署后需要手动做的事

1. **重启 ZCode**，让新配置与 MCP 生效。
2. **重新登录**：OAuth token、API 密钥、会话、日志、插件缓存**刻意不同步**（属 L4），需在本机重新登录一次。
3. **补装缺失依赖**：按 `run_once` 输出的 WARN 清单处理，逐项对照 [`mcp-deps.yaml`](mcp-deps.yaml)。
4. **token 用量状态栏 MCP**：脚本本体是独立仓库，不随本仓库同步。缺失时执行
   `sh tools/install-statusbar.sh`（Windows：`powershell -File tools\install-statusbar.ps1`）。
5. **插件**：`github` / `mimosa` 的来源与版本已同步，在 Settings → Plugin Management 中可见，点一次安装即可；插件缓存本体由 ZCode 自行下载。
6. **codebase-memory-mcp 属红色级**：仅 Windows 且路径非空时渲染。其他平台请用替代方案（如 `memory-server`、`mem0-mcp`）。

### 3. 目录结构

```
zcode-dotfiles/                          # 仓库根 = chezmoi source state
├── .chezmoi.toml.tmpl                   # init 时交互采集本机路径 + 配置 [interpreters.py]
├── .chezmoiignore                       # 排除仓库自有文件 + 另一平台的 run_once 脚本
├── mcp-deps.yaml                        # MCP 依赖分级清单（唯一事实源，CI 漂移检查对照它）
├── dot_zcode/                           # → ~/.zcode/
│   ├── AGENTS.md                        # verbatim
│   ├── commands/usage.md                # verbatim
│   ├── cli/
│   │   ├── modify_config.json.py.tmpl   # config.json 深合并源（stdin → 合并 → stdout）
│   │   └── plugins/
│   │       ├── installed_plugins.json.tmpl   # installPath 按本机 homeDir 渲染
│   │       └── known_marketplaces.json       # verbatim
│   └── exact_skills/                    # → ~/.zcode/skills/（38 个技能，exact_ 镜像语义）
├── run_once_after_10-install-mcp-deps.{sh,ps1}   # 每机一次：依赖检测 + 渲染产物自检
├── tests/acceptance.sh                  # R0–R5 验收（本地与 CI 共用）
├── tools/adopt-local-skills.{sh,ps1}    # 纳管本机未跟踪技能
├── tools/install-statusbar.{sh,ps1}     # 克隆 token 用量状态栏仓库
├── legacy/                              # 旧 PowerShell 实现归档（不可执行）
└── .github/workflows/acceptance.yml     # 三平台验收矩阵 + gitleaks 密钥扫描
```

### 4. 同步什么、不同步什么

| 层 | 内容 | 存储 | 部署方式 |
|---|---|---|---|
| L1 平台无关 | `AGENTS.md`、`commands/usage.md`、`known_marketplaces.json`、38 个 skills | verbatim | 直接复制；skills 用 `exact_` 镜像 |
| L2 路径相关 | `cli/config.json`、`cli/plugins/installed_plugins.json` | Go 模板 | 按 OS 与本机 homeDir 渲染 |
| L3 机器依赖 | 5 个 MCP 的外部可执行文件 | `mcp-deps.yaml` | `run_once` 检测 + 指引 |
| L4 凭证与缓存 | OAuth token、API 密钥、会话、日志、插件缓存 | **刻意不同步** | 部署后手动登录 / 由 ZCode 自行下载 |

MCP 分级：`context7`、`sequential-thinking`、`chrome-devtools` 为黄色（需 Node.js/npx，**版本已锁定**）；`zcode-token-usage-statusbar` 绿色；`codebase-memory-mcp` 红色（仅 Windows）。

### 5. 日常使用与回写矩阵 ⚠️

```sh
chezmoi update        # 拉取远端并应用（日常命令）
chezmoi diff          # 预览将要发生的改动
chezmoi apply         # 仅应用本地 source 状态
```

**改配置后怎么回写，取决于该文件是 verbatim 还是模板：**

| 目标文件 | 回写方式 |
|---|---|
| `~/.zcode/AGENTS.md`、`commands/usage.md`、`cli/plugins/known_marketplaces.json` | `chezmoi add <目标路径>`（verbatim，直接收录本机内容） |
| `~/.zcode/skills/<新技能>` | 先跑 `tools/adopt-local-skills.sh --add`（见下节） |
| `~/.zcode/cli/config.json` | **禁止 `chezmoi add`**。用 `chezmoi edit ~/.zcode/cli/config.json` 打开模板源改，或直接编辑 `dot_zcode/cli/modify_config.json.py.tmpl` |
| `~/.zcode/cli/plugins/installed_plugins.json` | **禁止 `chezmoi add`**。同上，改 `dot_zcode/cli/plugins/installed_plugins.json.tmpl` |

> ⚠️ 对**模板文件**执行 `chezmoi add` 会用本机渲染后的字面量覆盖模板：OS 分支与本机路径会被写死，之后在别的机器上 apply 就会写坏。这是破坏性操作。

机器独有的 MCP server 可以直接加进 `config.json`，**不会被清除**：`apply` 时模板声明的条目会整体覆盖同名条目，模板未声明的条目（包括顶层自定义键）原样保留。

### 6. 技能：`exact_` 语义与 adopt 助手 ⚠️

`dot_zcode/exact_skills/` 带 `exact_` 语义：**目标 `~/.zcode/skills/` 里任何未被仓库纳管的技能，会在下一次 `apply` 时被删除。**

而用 `npx skills add <repo> -s <skill> -a zcode -g`（本仓库用户的常规工作流）装的技能，默认就落在 `~/.zcode/skills/` 且**未纳管**。因此：

```sh
tools/adopt-local-skills.sh          # 列出未纳管技能
tools/adopt-local-skills.sh --add    # 逐个纳管到 dot_zcode/exact_skills/
```

Windows 用 `powershell -ExecutionPolicy Bypass -File tools\adopt-local-skills.ps1 [-Add]`。

**装完新技能请立刻 adopt**，否则下次 `chezmoi update` 会静默删掉它。若你不想承担这个纪律，可直接给 `dot_zcode/exact_skills` 去掉 `exact_` 前缀——代价是仓库里已下线的技能会在本机残留。

### 7. 更新与回滚

main 上每个发布点都打 tag。出问题时把 source 切回上一个 tag 再 apply：

```sh
chezmoi git -- fetch --tags
chezmoi git -- checkout v2.0.0        # 切到指定发布点
chezmoi apply                          # 目标机回滚到该版本
chezmoi git -- checkout main           # 恢复跟踪 main
```

### 8. 环境要求与已知限制

- **chezmoi**：本仓库在 **v2.73.0** 上实测通过（见 PROBES.md 的 D2/D5/D6/D7）。建议使用 v2.73.0 或更新版本；更低版本未验证——`modify_` 的扩展名剥离行为与模板化 `.chezmoiignore` 是关键依赖。
- **Python 3 必需**：`config.json` 的深合并脚本以 Python 3 执行（解释器由 init 采集，不依赖命令名 `python3`——主力机上 `python3` 是微软商店跳转桩，不可用）。缺 Python 时该目标 apply 会报错但**其余目标不受影响**，`config.json` 需手动维护。
- **首次部署需要网络**：安装 chezmoi + 克隆 source state；黄色级 MCP 首次运行也需联网（之后走 npm 缓存）。
- **L4 内容不同步**：登录态、密钥、会话、插件缓存需在本机重建。
- **macOS / Linux 真机未实测**：本仓库的验收在 Windows 上完成，三平台矩阵由 CI 覆盖（`.github/workflows/acceptance.yml`）。
- **`installed_plugins.json` 的 `installPath`** 已按本机 homeDir 正确渲染，但 ZCode 是否读取该字段需在真机观察（见 HANDOFF.md）。

### 9. 验收与 CI

```sh
sh tests/acceptance.sh     # 需要 chezmoi 与 Python 3；全部在 .test-home/ 沙箱执行，不碰真实 ~/.zcode
```

覆盖：T2.1 隔离部署与结构断言、R1 自定义 MCP server 保留、R2/R2b verbatim 与 skills 逐字节一致、R3 技能树原子性与收敛、R4 幂等、R5 `installed_plugins.json` 渲染、R0 归档脚本缺陷（静态 + 沙箱内动态复验）、`mcp-deps.yaml` ↔ 模板 ↔ `run_once` 漂移检查、`run_once` 跨平台调度。

CI 在 ubuntu / macos / windows 三平台跑同一脚本，并附加 gitleaks 密钥扫描（对应"凭证不同步"红线）。

---

<a id="zcode-dotfiles-english"></a>
## English

Cross-machine config sync for the ZCode desktop app (an AI coding tool), managed by [chezmoi](https://www.chezmoi.io/).
It versions the reusable parts of `~/.zcode` (default instructions, skills, commands, MCP config, plugin sources) so that macOS, Linux and Windows machines can be provisioned with a single command.

The two pre-migration PowerShell scripts are archived under [`legacy/`](legacy/README.md) — **historical reference only, not executable**. Acceptance tests live in `tests/acceptance.sh` (shared by local runs and CI, covering R0–R5); see [`PROBES.md`](PROBES.md), [`VERIFY.md`](VERIFY.md) and [`HANDOFF.md`](HANDOFF.md).

### 1. One-command setup (new machine)

```sh
# macOS / Linux
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply https://github.com/wjf1/zcode-dotfiles.git
```

```powershell
# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -c "iwr -useb https://get.chezmoi.io | iex; chezmoi init --apply https://github.com/wjf1/zcode-dotfiles.git"
```

The first run installs chezmoi, clones into `~/.local/share/chezmoi`, asks two machine-specific questions, renders `~/.zcode/`, then runs a one-time dependency check and render self-test.

**Only two prompts, asked once per machine:** `zcodePythonPath` (default `%USERPROFILE%\AppData\Local\Programs\Python\Python312\python.exe` on Windows, `/usr/bin/python3` elsewhere) and `zcodeCodebaseMemoryPath` (Windows only; press Enter to leave it empty and skip that MCP).

### 2. Manual steps after applying

1. **Restart ZCode** so the new config and MCP servers take effect.
2. **Sign in again**: OAuth tokens, API keys, sessions, logs and the plugin cache are deliberately **not** synced (layer L4).
3. **Install missing dependencies** listed by the `run_once` output — cross-check with [`mcp-deps.yaml`](mcp-deps.yaml).
4. **Token usage statusbar MCP**: its script lives in a separate repository. Run `sh tools/install-statusbar.sh` (`powershell -File tools\install-statusbar.ps1` on Windows) if missing.
5. **Plugins**: sources and versions for `github` / `mimosa` are synced and show up in Settings → Plugin Management; one click reinstalls them. The plugin cache itself is downloaded by ZCode.
6. **`codebase-memory-mcp` is red-tier**: rendered only on Windows with a non-empty path. Other platforms should use an alternative such as `memory-server` or `mem0-mcp`.

### 3. Layout

The repository root *is* the chezmoi source state: `dot_zcode/` maps to `~/.zcode/`, and `dot_zcode/exact_skills/` maps to `~/.zcode/skills/` with `exact_` mirror semantics. `cli/config.json` is generated by a merging script (`modify_config.json.py.tmpl`) that receives the current file on stdin and writes the merged result to stdout. Repo-only files (this README, `legacy/`, `tests/`, `tools/`, `mcp-deps.yaml`, `PROBES.md`, `VERIFY.md`, `.github/`) are excluded by `.chezmoiignore` so they are never deployed into `~/`.

### 4. What is and is not synced

| Layer | Content | Storage | Deployment |
|---|---|---|---|
| L1 platform-agnostic | `AGENTS.md`, `commands/usage.md`, `known_marketplaces.json`, 38 skills | verbatim | plain copy; skills use `exact_` |
| L2 path-dependent | `cli/config.json`, `cli/plugins/installed_plugins.json` | Go template | rendered per OS and per `homeDir` |
| L3 machine deps | the 5 MCP executables | `mcp-deps.yaml` | detected by `run_once`, with guidance |
| L4 credentials & cache | OAuth tokens, API keys, sessions, logs, plugin cache | **not synced** | sign in again / let ZCode re-download |

MCP tiers: `context7`, `sequential-thinking` and `chrome-devtools` are yellow (need Node.js/npx, **with pinned versions**); `zcode-token-usage-statusbar` is green; `codebase-memory-mcp` is red (Windows only).

### 5. Daily use and the write-back matrix ⚠️

```sh
chezmoi update        # pull from remote and apply (the everyday command)
chezmoi diff          # preview pending changes
chezmoi apply         # apply the local source state only
```

| Target file | How to write changes back |
|---|---|
| `~/.zcode/AGENTS.md`, `commands/usage.md`, `cli/plugins/known_marketplaces.json` | `chezmoi add <target>` (verbatim files) |
| `~/.zcode/skills/<new skill>` | run `tools/adopt-local-skills.sh --add` first (next section) |
| `~/.zcode/cli/config.json` | **never `chezmoi add`** — edit the template via `chezmoi edit ~/.zcode/cli/config.json` or directly edit `dot_zcode/cli/modify_config.json.py.tmpl` |
| `~/.zcode/cli/plugins/installed_plugins.json` | **never `chezmoi add`** — edit `dot_zcode/cli/plugins/installed_plugins.json.tmpl` |

> ⚠️ Running `chezmoi add` on a **template** file overwrites the template with machine-rendered literals: OS branches and local paths get hard-coded and break every other machine on the next apply. That is a destructive operation.

Machine-local MCP servers you add to `config.json` are **not** wiped: entries declared by the template replace same-named entries wholesale, while undeclared entries (including custom top-level keys) are preserved.

### 6. Skills: `exact_` semantics and the adopt helper ⚠️

`dot_zcode/exact_skills/` carries `exact_` semantics: **any skill present in `~/.zcode/skills/` but not tracked in this repo is deleted on the next `apply`.**

Skills installed with `npx skills add <repo> -s <skill> -a zcode -g` land exactly there and are untracked, so run:

```sh
tools/adopt-local-skills.sh          # list untracked skills
tools/adopt-local-skills.sh --add    # adopt them into dot_zcode/exact_skills/
```

**Adopt right after installing a skill**, otherwise the next `chezmoi update` silently removes it. If you would rather not keep that discipline, drop the `exact_` prefix from `dot_zcode/exact_skills` — the trade-off is that skills removed from the repo linger on the machine.

### 7. Updating and rolling back

Every release point on `main` is tagged. To roll a machine back:

```sh
chezmoi git -- fetch --tags
chezmoi git -- checkout v2.0.0        # check out a release point
chezmoi apply                          # roll the machine back to it
chezmoi git -- checkout main           # resume tracking main
```

### 8. Requirements and known limitations

- **chezmoi**: verified on **v2.73.0** (see PROBES.md D2/D5/D6/D7). Use v2.73.0 or newer; older versions are untested, and the `modify_` extension-stripping behaviour plus templated `.chezmoiignore` are load-bearing here.
- **Python 3 is required**: the `config.json` merge script runs on Python 3, using the interpreter collected at init (never the command name `python3`, which is a broken Microsoft Store stub on the primary machine). Without Python that one target fails to apply while everything else succeeds, and `config.json` must be maintained by hand.
- **Network needed on first run**: to install chezmoi, clone the source state, and let the yellow-tier MCPs download their packages (npm cache afterwards).
- **L4 content is not synced**: credentials, sessions and the plugin cache must be rebuilt locally.
- **macOS / Linux not tested on real hardware**: acceptance was run on Windows; the three-OS matrix is covered by CI (`.github/workflows/acceptance.yml`).
- **`installed_plugins.json`**: `installPath` is rendered to the real local path, but whether ZCode reads that field needs to be confirmed on a real machine (see HANDOFF.md).

### 9. Acceptance and CI

```sh
sh tests/acceptance.sh     # needs chezmoi and Python 3; runs entirely inside .test-home/, never touching the real ~/.zcode
```

It covers: isolated deployment and structural assertions, R1 (machine-local MCP servers survive), R2/R2b (verbatim and skills byte-for-byte equality), R3 (skills tree atomicity and convergence), R4 (idempotency), R5 (`installed_plugins.json` rendering), R0 (archived script defect, static plus dynamic in-sandbox), drift between `mcp-deps.yaml`, the template and the `run_once` scripts, and cross-platform `run_once` dispatch.

CI runs the same script on ubuntu, macos and windows, plus a gitleaks secret scan (enforcing the "no credentials in the repo" red line).
