# HANDOFF.md —— 接力开发文档

> 新会话 / 新 Agent 接手本仓库时，除 README、CHANGELOG 外请**优先读本文件**，可快速建立对当前代码真实进展与未竟任务的心智，无需全盘探索。

## 1. 项目概况与当前状态

- **定位**：ZCode 桌面版（AI 编码工具）的跨机器配置同步仓库，chezmoi 管理，三平台单命令部署。
- **当前版本**：本地 `main` 已包含 **v2.2.0（T1–T3）、v2.3.0（T4–T7 + T10）与 v2.4.0（T8，灰度）** 的全部内容（2026-10-26 完成，`sh tests/acceptance.sh` 全程 PASS），**尚未打 tag、尚未推送**——发布动作与命令清单见 §5 待办 7；GitHub 上最新发布仍为 v2.1.3
- **部署地址**：https://github.com/wjf1/zcode-dotfiles（默认分支 `main`）
- **同步范围**：`~/.zcode` 中的默认指令、40 个技能、`commands/usage.md`、`cli/config.json`（MCP + 插件开关）、插件市场与插件来源记录。
- **不做的事**：不同步凭证与缓存（L4）；不 vendor 上游独立项目；不保留旧 PowerShell 脚本可执行性。

## 2. 技术栈与运行基线

- **核心工具**：chezmoi **v2.73.0**（实测基线；升级前请重跑验收，见 §6 避坑）
- **运行时**：Python 3（仅状态栏 MCP 需要；v2.4.0 起 `config.json` 合并已去 Python 化）；Node.js 18+（黄色级 MCP 经 `npx` 启动）；PowerShell（Windows 侧 `run_once`）
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
│   ├── cli/modify_config.json                # config.json 深合并（chezmoi:modify-template，stdin → stdout）
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
- `v2.2.0`（2026-10-26，批次 A = T1–T3，本地待发布）：
  - **T1（P0-1）**：`modify_config.json.py.tmpl` 的 5 个 MCP 条目在对象首键补显式 `"type": "stdio"`，摆脱"缺 type 自动归一化"兼容逻辑；刻意**不加** `enabled`（避免 apply 强行重新启用用户手动禁用的 server，默认值语义归 T4）。验收 R1 断言同步新增 type 检查。
  - **T2（P0-2）**：README 双语 §4 补「ZCode ≥3.16 起个人模型配置在 `~/.zcode/v2/provider_config.json`（含明文 API Key），本仓库不纳管该文件与整个 `~/.zcode/v2/`」；`dot_zcode/AGENTS.md` 工具调用避坑补「ZCode 运行时网络走自己的配置」（`network.httpProxy` / `ZCODE_HTTP_PROXY` / `ZCODE_NO_PROXY` / `ZCODE_AGENT_CA_CERT`）。
  - **T3（P2-2）**：验收漂移检查升级为「名字 + 锁定版本」双向比对（`pkg@x.y.z` 级、含 scoped 包，失败列出差异项）；红/绿双测验证（篡改 yaml 版本 → 退出码 1 并列出两侧差异 → 还原 → PASS）。
- `v2.3.0`（2026-10-26，批次 B = T4–T7 + T10，本地待发布）：
  - **T4（P1-1）**：`merge()` 从"整体覆盖"改为"覆盖但继承目标机 `enabled`/`enable` 布尔开关"，用户在设置页禁用的 server 不再被 apply 还原；新增 R1b 用例；README 双语说明。
  - **T5（P1-2）**：run_once 双脚本新增插件幂等安装段（`zcode plugins list --json` 查询 → `zcode plugins install github@zcode-plugins-official --scope user`；任何失败仅 `[plugins] WARN` 不阻塞；`ZCODE_TEST_NO_SIDE_EFFECTS=1` 整段跳过）；`installed_plugins.json.tmpl` 保留为无 CLI 兜底。
  - **T6（P1-3）**：adopt 助手识别软链/junction（sh `[ -L ]` / ps1 `LinkType`），`--add` 对链接实体化复制、不再 `chezmoi add`；README 双语 §6 新增「ZCode 设置页技能导入」。
  - **T7**：验收技能计数断言参数化（`SKILL_DIRS` / `SKILL_FILES` 按源侧动态生成，去 40/191 硬编码；R2b 冗余计数断言删除）；探针验证计数自动跟随（40/191 → 41/192）。
  - **T10**：README 双语 §5 新增「当你在 ZCode 设置页改了东西」四类操作对照表；VERIFY.md 增补 2026-10-26 批次验收实录；本文件版本状态与待办同步更新。
- `v2.4.0`（2026-10-26，批次 C = T8，本地待发布，灰度）：
  - **Phase A 探测（PROBES.md D11）**：`chezmoi:modify-template` 在 v2.73.0 **真实可用**，但文件名必须带 `modify_` 前缀且不能带 `.tmpl` 后缀——D2 探测 1 当年的失败根因确认为 `.tmpl` 后缀（先按普通模板渲染，stdin 尚未注入）；无 `modify_` 前缀的魔法注释不生效（被当普通文件原样部署）。
  - **实现**：新增 `dot_zcode/cli/modify_config.json`（首行 `{{- /* chezmoi:modify-template */ -}}`），用 `index` 导航目标数据（规避 `missingkey=error`）、`setValueAtPath` 整对象替换 5 个 MCP 条目（继承目标机 `enabled`/`enable`，T4 语义）、逐键设置 `plugins.enabledPlugins`、条件渲染 `codebase-memory-mcp`；旧 Python 实现整体移入 `legacy/modify_config.json.py.tmpl`。
  - **灰度验证**：三组 fixture（空文件 / 含自定义 server / 含 enabled=false）上新旧实现输出**语义等价**（JSON 结构相等）；全量验收 PASS 且产物为合法 JSON。
  - **有意降级**：目标 `config.json` 损坏时 apply 快速失败（Go 模板无 try/catch），相对旧版"留档 `.broken-backup` 后按空对象合并"为明确取舍，已在 README「已知限制」与 CHANGELOG 声明。
  - **依赖变化**：部署不再需要 Python 3（`.chezmoi.toml.tmpl` 保留 `[interpreters.py]` 兜底并注明仅状态栏 MCP 需要 Python）。

## 5. 接力开发指引与待办（Next Steps / Backlog）

按优先级：

1. **macOS / Linux 真机实测（P0，阻塞"三平台可用"的对外声明）**：跑一遍单命令部署，确认 `~/.zcode` 路径、`/usr/bin/python3` 存在性、`exact_` 权限语义、`npx` 三包可启动；结果补进 VERIFY.md。
2. ~~**ZCode 读取 `installed_plugins.json` 的行为（P1）**~~ **已由 T5 替代处理（2026-10-26）**：插件安装改由 run_once 调 `zcode plugins install` 幂等执行——不再猜测 ZCode 对 installPath 的读取行为，让 ZCode 自己装；`installed_plugins.json.tmpl` 保留为无 CLI 环境兜底。真机上 run_once 的 `[plugins]` 实际行为仍值得观察一轮（并入待办 7 的真机走查）。
3. ~~**存量机（主力 Windows 机）切换（P1）**~~ **已完成（2026-10-08），并于 2026-10-12 复核后重新接管**：主力机装好 chezmoi v2.73.0 并接入源仓库（`~/.local/share/chezmoi`）。切换前已把本机技能补齐到与仓库一致的 40 个（`agent-reach`、`apk-reverse` 手工落位，含 `literal_` 前缀还原），故 `exact_` 无删除动作。
   - **2026-10-12 复核结论**：本机 `~/.local/share/chezmoi` 与 `~/.config/chezmoi/chezmoi.toml` 均不存在（`chezmoi doctor` 报 source-dir error），即上一轮记录的"接管"在本机并未真正生效。**教训**：`chezmoi init --apply` 是否落地必须用 `chezmoi doctor` / `chezmoi status` 复核，不能只看命令退出码。
   - **本轮接管路径**（避开已知的代理坑）：先 `git clone <repo> ~/.local/share/chezmoi` 手动落源目录，再 `chezmoi init --promptDefaults --apply`——源目录已是 git 仓库时 chezmoi 跳过克隆，`--promptDefaults` 让两个 `promptStringOnce` 直接取默认值，全程免交互（否则 agent 会话里会卡在交互提示）。
   - 实际踩到的坑（已记入第 6 节）：`chezmoi init` 的克隆会被系统代理坑住（改用手动 clone 到源目录）；`core.autocrlf=true` 使工作区为 CRLF，直接编辑源文件时须先做行尾归一化。
   - **2026-10-12 二次复核（v2.1.3 发布时）**：接管本次确认生效——`chezmoi status` 空输出、`chezmoi apply` 幂等、`~/.zcode/AGENTS.md` 与 `cli/config.json` 对源逐字节一致。另实测当日代理链路抖动：git 经 `127.0.0.1:7900` 访问 GitHub 握手失败、直连正常，`git -c http.proxy=` 仍是最可靠绕行。
4. **`exact_` 与 `npx skills add` 的摩擦（P2）**：目前靠 adopt 助手 + README 纪律兜底。若嫌麻烦，可去掉 `exact_` 前缀（代价：仓库下线技能会在本机残留）。决策前建议先实测一两周的日常手感。
5. ~~**MCP 版本升级流程（P2）**~~ **2026-10-26 部分解决（T3）**：验收漂移检查已升级为「名字 + 锁定版本」双向比对，`mcp-deps.yaml` ↔ 模板漏改任意一处即红且列出差异项。升级 MCP 仍需改 yaml + 模板两处，是否进一步收敛为 yaml 单源渲染见待办 8（T9）评估。
6. **chezmoi 版本升级（P3）**：升到含 `chezmoi:modify-template` + `.chezmoi.stdin` 的版本后，可评估把 `config.json` 合并改回纯模板实现（省掉 Python 依赖）。届时需重跑验收。
7. **本批次（v2.2.0 / v2.3.0）的发布动作——需人工确认后才执行**：本地 `main` 已全部就绪且验收 PASS。确认后依次执行：
   - `git tag -a v2.2.0 -m "v2.2.0: MCP 条目显式传输类型、文档边界与版本级漂移检查"`
   - `git tag -a v2.3.0 -m "v2.3.0: 设置页开关继承、CLI 幂等插件安装与 adopt 链接实体化"`
   - `git tag -a v2.4.0 -m "v2.4.0: config.json 合并去 Python 化（chezmoi modify-template 灰度）"`
   - `git push origin main --tags`
   - 核验/创建两个 GitHub Release，标题与上述 tag 注释逐字一致，正文与 CHANGELOG 对应版本段落对齐。
   真机走查建议：一台装有 ZCode ≥3.16 的机器重跑 run_once 观察 `[plugins]` 行为；设置页改一次 MCP 开关 → `chezmoi apply` → 重开设置页确认开关仍在。
8. **T8 已完成（2026-10-26，v2.4.0 本地待发布）**：modify-template 实现落地，全量验收 PASS + 三组 fixture 新旧实现语义等价。**灰度观察项**——在真机（主力机）跑一轮 `chezmoi apply`，确认 `~/.zcode/cli/config.json` 与语义预期一致、损坏文件场景报错清晰。**T9（mcp-deps.yaml 单源渲染）**：待 v2.4.0 稳定一个发布周期后评估；执行前须先写 1 页设计说明交人工确认，若评估为负收益则把 3 段结论存档 PROBES.md 后关闭。

## 6. 关键避坑与运行约束

以下均为 2026-10-06 实测结论（原始记录见 PROBES.md），**改动相关文件前务必先读**：

1. **`modify_` 的目标名推导**：chezmoi 依次剥掉 `.tmpl` 与**已注册的脚本扩展名**。Python 脚本时代文件必须叫 `modify_config.json.py.tmpl`（`.py` 剥掉后目标名还原为 `config.json`）；**不要把 `.json` 注册进 `[interpreters]`**——那会把目标名剥成 `config`。v2.4.0 起合并改用 modify-template：文件名必须带 `modify_` 前缀且**不带任何后缀**（`dot_zcode/cli/modify_config.json`），带 `.tmpl` 会先按普通模板渲染、stdin 未注入即报 `map has no entry for key "stdin"`（D2 探测 1 的根因，见 D11）。
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
