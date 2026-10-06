# PROBES.md —— 开工前探测记录

- 探测日期：2026-10-06
- 探测环境：Windows 10.0.26200（主力机，`MINGW64` / Git Bash）、chezmoi **v2.73.0**（commit 24b71e4cf9d98cce0801cfc68e7553355efeaff7）、Python 3.12.10（`python`）、Node.js 22.23.2
- 探测方式：全部在 `.test-home/` 沙箱内用 `chezmoi -c <cfg> -S <repo> -D <dest> --persistent-state <file> --no-tty` 完成，未触碰真实 `~/.zcode`

> 说明：本文件是"探测 → 结论 → 采用方案"的记录。凡与规格 v2.0 预设不符处，均在下方显式标注为**偏差**。

---

## D1 ZCode 在 macOS/Linux 的配置目录是否为 `~/.zcode`

- 方法：核查仓库既有快照（Windows 侧确认为 `%USERPROFILE%\.zcode`）；macOS/Linux 无真机可用。
- 结果：**未实测**。源目录命名沿用 `dot_zcode/`（chezmoi 规则 `dot_<name>` → `~/.zcode`）。
- 采用方案：架构不依赖该结论——若某平台实际目录不同，只需改 source 目录名，其余不变。
- 状态：**待人工验证**（见 HANDOFF.md 待办）。

## D2 config.json 合并方案（本次最关键的探测，含两处偏差）

规格 v2.0 默认方案 B（`modify_` 深合并脚本），并期望"免 Python、用 chezmoi 自带模板机制"。实测如下：

**探测 1：`chezmoi:modify-template` + `.chezmoi.stdin`**
- 方法：写 `modify_config.json.tmpl`，首行放 `chezmoi:modify-template` 标记，模板内引用 `.chezmoi.stdin`。
- 结果：**失败**。`template: ... at <.chezmoi.stdin>: map has no entry for key "stdin"`。
- 结论：官网文档（跟踪 master）描述的该机制在 **2.73.0 稳定版中不存在**（`chezmoi execute-template` 的变量转储里也没有 `stdin` 字段）。
- **偏差 1**：规格设想的"模板级深合并、零外部运行时"在可用版本上不成立。

**探测 2：`[interpreters.json]` 挂载解释器（试图让 `.json` 扩展名可执行）**
- 结果：**失败**。脚本确实被执行了，但产出落到了目标 `config/`（而不是 `config.json`）——**把 `.json` 注册为脚本扩展名会被 chezmoi 从目标名里剥掉**，目标名因此错误。
- 结论：该路径不仅无用，还会破坏目标名，弃用。

**探测 3：`.tmpl` + shebang**
- 结果：**失败**。`fork/exec <temp>.config.json: %1 is not a valid Win32 application`。
- 结论：Windows 上 chezmoi **不读 shebang**，按扩展名选解释器；`.json` 没有解释器，直接 exec 失败（文档原文：脚本与 hook 的执行在 Windows 上取决于文件扩展名；`.tmpl` 被剥掉后用"下一个"扩展名）。

**探测 4（采用方案）：`modify_config.json.py.tmpl` + `[interpreters.py]`**
- 原理：chezmoi 依次剥掉 `.tmpl` 与**已注册的脚本扩展名**；`.py` 是内置脚本扩展名，剥掉后目标名正好还原为 `config.json`，同时用 `[interpreters.py] command = <采集到的 python>` 指定解释器。
- 结果：**全部通过**。目标名 `config.json` 正确；stdin 收到目标当前内容；stdout 成为新内容；目标机独有 server 与顶层键保留；模板条目更新为渲染值；连续两次 apply 零变更。
- 采用方案：**方案 B 的 .py 形态**（`dot_zcode/cli/modify_config.json.py.tmpl`），解释器由 `.chezmoi.toml.tmpl` 采集的 `zcodePythonPath` 注入。
- **偏差 2**：config.json 合并**需要 Python 3**（对规格"免 Python"设想的偏差）。理由：规格已允许 Python 3 作为运行时依赖（C6），且 token 用量状态栏 MCP 本身就需要 Python，因此未引入新的依赖类别；换来的是唯一可行的跨平台合并实现。缺 Python 时该目标 apply 失败、其余目标不受影响，已在 README 声明为已知限制。

**探测 5：主力机 `python3` 可用性**
- 结果：`python3 --version` 返回 rc=49 —— 本机 `python3` 是微软商店跳转桩（符号链接到 `AppInstallerPythonRedirector.exe`），**不可用**；只有 `python`（3.12.10）可用。
- 结论：任何依赖"命令名为 `python3`"的方案在真实机器上都会失败；解释器必须来自 chezmoi 采集的**绝对路径**（`.chezmoi.toml.tmpl` 的 `promptStringOnce`）。`tests/acceptance.sh` 也已改为"能真正跑起来才认"的探测。

**探测 6：损坏的目标文件**
- 方法：向目标写入非法 JSON 后再 apply。
- 结果：脚本把原内容留档到 `~/.zcode/cli/config.json.broken-backup` 并 WARN 到 stderr，随后按空对象合并，产出仍是合法 JSON。
- 采用方案：留档 + 继续（不静默丢弃用户数据）。

## D3 三个黄色级 MCP 的跨平台发行版

- 方法：读取主力机 `E:\OpenCode\node_modules` 内实际安装版本；核查 `.cmd` 包装器内容。
- 结果：`E:\OpenCode\*.cmd` **不是手写脚本，而是 npm 本地安装生成的 bin 包装器**，指向 `node_modules/**`，即**锁定版本**：`@upstash/context7-mcp@4.1.0`、`@modelcontextprotocol/server-sequential-thinking@2026.8.31`、`chrome-devtools-mcp@1.9.0`。
- 结论：规格把它改写成裸 `npx -y <pkg>` 会**静默浮动到 latest**（chrome-devtools 会从 1.9.0 跳到当时最新），且首次运行必须联网。
- 采用方案：保留 `npx`（去掉机器私有目录 `E:\OpenCode` 依赖），但**固定版本**，把上述三个版本写入模板与 `mcp-deps.yaml`。
- 状态：非 Windows 实跑 `npx -y <pkg> --help` **待人工验证**（本机只有 Windows）。

## D4 usage_mcp.py 的获取方式（偏差 3）

- 方法：核查上游来源。
- 结果：`~/.zcode/zcode-token-usage-statusbar` 本身是一个 **Git 仓库**，remote 为 `https://github.com/wjf1/zcode-token-usage-statusbar.git`（公开仓库，自带 CHANGELOG 与一键部署能力）。
- 结论：规格 D4 的"从现役 Windows 机复制（唯一途径）"**不成立**；把该文件 vendor 进本仓库会造成与上游长期漂移。
- 采用方案：**不 vendor**。新增 `tools/install-statusbar.sh|.ps1`（clone / pull 上游仓库），`run_once` 检测并在缺失时给出克隆指引；`config.json` 的 statusbar 条目仍指向 `~/.zcode/zcode-token-usage-statusbar/usage_mcp.py`（路径与旧体系一致）。

## D5 chezmoi 在 Windows 的脚本解释器行为

- 方法：分别用 `.sh` / `.ps1` / `.py` 形态的 `run_` 与 `modify_` 脚本做 apply，观察实际执行。
- 结果：
  - **不读 shebang**，按文件扩展名选择解释器；`.tmpl` 先被剥掉，再用剩余扩展名找解释器。
  - `.ps1` 有内置解释器（`powershell`），Windows 上可直接执行，实测通过。
  - `.sh` 在本机（Git Bash 提供 `sh`）也被识别为 script，但不能假定目标机存在 `sh`。
  - `[interpreters.py]` 可直接指向采集到的绝对路径，是唯一可靠方式。
- 采用方案：`.chezmoi.toml.tmpl` 输出 `[interpreters.py]`；`run_once` 双脚本按 OS 由 `.chezmoiignore` 选择，且两侧各自带 OS 早退兜底。

## D6（新增）`chezmoi diff` 会把 `run_` 脚本当作"新增文件"

- 结果：只要仓库里存在 `run_` 脚本，`chezmoi diff` 就非空（把脚本列为 `new file mode 100755`）。
- 采用方案：幂等断言必须用 `chezmoi diff --exclude=scripts`；`--exclude=scripts` 下 diff 为空，实测确认。

## D7（新增）`.chezmoiignore` 匹配的是"派生后的目标名"

- 结果：写源文件名 `run_once_after_10-install-mcp-deps.sh` **不生效**；改写成派生名 `10-install-mcp-deps.sh`（脚本会剥掉 `run_`/`once_`/`after_` 前缀）后立即生效。
- 采用方案：`.chezmoiignore` 用派生名排除另一平台的 run_once 脚本。

## D8（新增）source 中以 `.` 开头的目录会被 chezmoi 忽略

- 结果：`dot_zcode/exact_skills/humanizer/.claude-plugin/` 与 `.../.github/` 未被部署，skills 文件数 68 → 65。
- 采用方案：源侧改名 `dot_claude-plugin` / `dot_github`（`dot_` 编码 → 目标侧还原为 `.claude-plugin` / `.github`）。修复后 68 个文件逐字节一致（由 acceptance 的 R2b 断言守住）。

## D9（新增）PowerShell 5.1 需要 UTF-8 BOM

- 结果：含中文的 `.ps1` 若无 BOM，Windows PowerShell 5.1 按系统代码页（GBK）解码，直接语法报错（`字符串缺少终止符`）。
- 采用方案：本仓库所有 `.ps1` 一律带 UTF-8 BOM（`legacy/deploy.ps1` 原本就有）。

## D10（新增）断言不要匹配 PowerShell 的本地化输出

- 结果：PowerShell 5.1 的 stdout 走系统代码页，与 UTF-8 断言字符串不匹配。
- 采用方案：两个 run_once 脚本输出 ASCII 平台标记（`platform=windows` / `platform=unix` / `skipped-by-unix-script`），acceptance 只断言 ASCII 标记，同时可判定"是否错误执行了另一平台的脚本"。
