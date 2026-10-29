# 用户默认指令（User AGENTS.md）

> **全文优先级索引**（按使用频率四分区）：① 环境硬约束（Bash 命令硬约束 / 工具调用避坑）→ ② 行为与验收规范（输出语言 / 服务启停确认 / 任务清单同步 / Token 效率 / Subagent 派发 / 前端 DOM 变更验收）→ ③ 仓库工程规范（代码变更发布 / GitHub 发行版 / README / 仓库门面 / 社区健康文件 / HANDOFF / 项目级 AGENTS.md / ARCHITECTURE.md / 技能安装）→ ④ 专用环境与历史附录（Command Code 代理）。

## 一、环境硬约束

### Bash 命令硬约束（所有工作区强制生效）

背景：ZCode 在 agent runtime 重启时会执行 `taskkill /PID <旧runtime> /T` 回收旧进程树。若 Bash 起过脱离父进程的常驻进程（adb server、gradle daemon、后台 probe、nohup 进程），该 PID 会被回收或对不上号，`taskkill /T` 失败并连带杀掉 `zcode-host-local-1`，会话陷入静默（无输出、无报错，只能托盘退出重启）。日志证据：`~/.zcode/v2/logs/2026-09-1{5,6}.log`，两天内复现 7 次，累计静默超 2.5 小时。

- **禁止裸 `&`、`nohup`、`setsid` 起后台常驻进程。** 需要后台执行一律用工具的 `run_in_background: true`。
- **常驻/守护类命令必须走后台模式**：`adb` 相关（server 是 daemon）、`gradle`/`build.sh`（留 daemon）、模拟器、`logcat` 跟随、WebSocket 长连、`python tools/probe.py sub` 这类订阅探测。
- **阻塞式探测必须包硬超时**：`timeout 20 <cmd>`，且不依赖工具自带 timeout（实测会出现远超设定值仍不返回的情况）。
- **单条 Bash 前台等待控制在 60 秒内。** 不要写 `build.sh && sleep 25 && logcat` 这种把编译、等待、抓日志串在一条里的命令，拆成独立调用并各自设短超时。
- **超过 2 分钟无返回立即停（stop），不要继续等。** 继续等大概率就是 host 被杀，只能重启 ZCode 恢复。

### 工具调用避坑（所有工作区强制生效）

背景：2026-09-18 会话多次「执行失败 / 工具调用失败」，`~/.zcode/v2/logs/2026-09-18.log` 里却没有任何 error 级记录（24 条告警全是 `web-remote-control dropped buffered outbound payloads`）——说明这类失败发生在工具与环境边界上，只能靠调用方式规避。

- **Bash 的 cwd 每条命令后都会重置回会话主工作目录**（每条结果都带 `Shell cwd was reset to ...`）。不要依赖上一条命令的 `cd`，每条命令内联 `cd <dir> && ...`。
- **不要把手写的 POSIX 路径交给 Windows 原生程序**：`node -e "require('/c/Users/...')"` 必报 `MODULE_NOT_FOUND`（`/c/...` 是 Git Bash 的写法，Node 不认）。先 `cd` 再传相对路径，或用 `cygpath -w` 转换。
- **不要猜文件后缀**：本机项目源码常是 TypeScript（`src/utils/plans.ts`，不存在 `.js`）。先 `ls` / `find` 确认再读；链式命令里放错一个路径，整条 `wc -l a b c` 都会返回 exit 1，看起来像"执行失败"。
- **MCP 工具往会话工作区写文件会被拒**：chrome-devtools 截图传 `filePath` 会报 `Access denied: ... is not within any of the configured workspace roots`——连工作目录本身也被拒。做法是**不传 `filePath`**，让工具把产物落到 artifacts 目录并返回绝对路径，再用 `cp` 搬到目标位置。
- **大图不要在会话里读**：超过 200KiB 的 MCP 图片不会内联，`Read` 只能拿到被截断的 `data:image/...;base64,` 前缀，无法判读内容。视觉验收改用**可编程断言**（`getComputedStyle` / `getBoundingClientRect` / 元素数量与文本），截图只作留档产物，不作为判读依据。
- **CLI 与 npm 不读 Windows 系统代理**：浏览器能打开 github.com 不代表 git / curl / npm 能——它们只看自己的配置和环境变量。本机 git 侧已固化 `http.proxy = http://127.0.0.1:7900`（2026-10-06 随 Clash Verge 混合端口变更从 7897 改为 7900），另有用户级 `NO_PROXY=localhost,127.0.0.1,::1`（无 HTTP_PROXY/HTTPS_PROXY 持久化）；该端口会漂移，以实际监听为准。npm 不读系统代理，需单独 `npm config set proxy` / `https-proxy`，否则 `npx` 拉包超时。**已知坑**：`chezmoi init` 克隆仓库时会把系统代理解析成 `http://127.0.0.1`（丢失端口）导致失败，需改用 `git clone` 先手动克隆到源目录，再 `chezmoi init`（源目录已是 git 仓库时跳过克隆）。代理异常或未启动时用 `git -c http.proxy= <cmd>` 临时直连。
- **单条命令的输出保持克制**：整段 `cat` 大文件、base64 图片这类大 payload，与日志里 `dropped buffered outbound payloads` 告警在时间上聚集，疑似相关。大文件只取关键片段。

## 二、行为与验收规范

### 输出语言规则（所有任务强制生效）
- **会话内所有由模型生成的自然语言内容一律使用简体中文**，包括但不限于：**思考 / 推理过程**、**任务标题、待办（todo）内容**、**任务清单**（TodoWrite 的 `content`、任务卡片标题、进度描述）、中间状态说明、实施计划、阶段小结、**最终回复**。这些内容 ZCode 客户端会原样透传显示，不做翻译，写英文就会直接以英文出现在界面上。
- **最终回复一律使用中文**，与客户端 locale（`zh-CN`）保持一致。
- 不要因为任务标题、URL、仓库名、日志、工具输出、报错信息是英文，就把思考过程或任务清单切成英文。语言由本条规则决定，不由上下文语言决定。
- 派发给 subagent 的任务描述，以及向用户转述的子代理结论，同样使用中文。
- 例外（保持原样、不翻译）：代码与代码标识符、命令与命令行参数、文件路径、第三方库 / API / 产品名、工具返回的报错原文、引用他人英文原文、用户以英文给出的专有名词、英文技术术语。
- 中英混排时按中文语序组织句子，只在上述例外范围内夹用英文词，不要整句英文。
- 说明：这是「要求」而非「开关」（配置里没有输出语言项），模型偶发漂移无法完全杜绝；若出现连续多轮英文输出，应在下一轮显式纠偏。

### 服务启停确认（所有任务强制生效）
- **任何服务的停止 / 关闭 / 重启，都必须先征得用户书面确认，不得擅自执行。**
- 涵盖所有本地常驻服务与本机被拉起的进程，包括但不限于：Command Code 代理（端口 9090）、以及任何由脚本 / 计划任务 / MCP 管理的服务进程。
- 确认时需说明：将停止或重启哪个服务、预期停机影响（约多少秒）、以及是否会自动重新拉起。
- 同一会话内、针对同一操作已经获得用户确认的，不再重复询问；但该确认**不跨会话、不自动延伸到其它未提及的服务**。
- 若确认后仍需操作，应尽量最小化影响：能只重载相关进程 / 热加载的，不做整体停机。

### 任务清单同步（TodoWrite / 会话卡片，所有任务强制生效）
- TodoWrite 清单是会话待办卡片（会话卡片）的**唯一数据源**，卡片不会自动更新；清单必须始终与真实进度保持一致。
- **每完成一个工作项，必须在下一步工具调用之前（最迟在该轮回复发出前）调用 TodoWrite 将该项标记为 `completed`；禁止攒到收尾统一更新。**
- 受阻项一旦解除，立即回写状态；任何"已完成"的表述发出前，先确认对应项在清单里已是 `completed`——只改回复文本、不改清单，视为未完成。
- 每次调用 TodoWrite 都按**全量清单**提交，禁止漏项（漏项会导致卡片状态回退或已完成项丢失）。

### Token 效率规则（所有任务默认生效）
- 少轮数优先：相互独立的工具调用在同一轮并行批量执行，不要一步步串行试探。
- 不做冗余观察：同一状态不重复读取/截图；文件只在必要时读，避免反复读同一文件的大段内容。
- 电脑控制（computer-use）时优先走无截图的可访问性路径（compact 级别即可），仅当语义方式到不了目标才用截图/缩放；能用一次操作完成的不拆成多次。
- 输出克制：先结论后细节；不输出用户没要求的过程清单、长篇计划和重复说明。
- 大文件/长输出只引用关键片段，不整段回贴。
- 本节效率取向**不豁免质量门禁**：发布四步门禁、UI 真实点击走查、DOM 断言规范等验收要求照常执行，不为省轮次而跳过。

### Subagent 派发规则（所有任务默认生效）
- 派发判断标准：独立的多步任务（可并行推进）、预计要扫描大量文件/产生大量中间输出的调研、需要只读隔离的排查 → 派给 subagent；单点明确的事实查询、简单一次性编辑直接做，不为启动开销买单。
- 类型选择：只读调研/大范围定位用 Explore；复杂多步执行用 general-purpose；pptx/docx/xlsx/pdf 等交付物渲染后的视觉验收用 judge。
- 读密集任务尽早派发：让原始文件内容留在子代理上下文、主会话只收回结论，避免撑爆主上下文后再靠压缩兜底。
- 派发时 prompt 必须自包含（子代理看不到主会话历史），返回结果的关键内容需向用户转述。

### 前端 DOM 变更验收规范（所有含 Web 前端的项目强制生效）

背景：2026-10-11 workbuddy2api-panel 事故——导出弹窗新增 `id="expList"` 与页面既有隐藏元素重名，`getElementById` 恒取文档顺序第一个，账号行被渲染进被弹窗遮罩盖住的旧容器：用户看到空列表、点击无效，而计数/全选逻辑显示"正常"，三层自动化测试（handler 测试、JS 语法校验、DOM 内容断言）全绿假阳性，连烧三个版本（1.13.1~1.13.3）才靠真实鼠标点击 + `elementsFromPoint`/祖先链检查定位根因。完整排查记录见该仓库 `CHANGELOG.md` 的 1.13.4 条目。

- **id 全局唯一是硬门禁**：新增/修改 HTML `id` 前必须先 grep 全文档查重；含 CI 的前端项目必须落地"id 唯一性自动检测"（解析 HTML 断言所有 `id="…"` 唯一，参考 workbuddy2api-panel 的 `TestIndexHTMLUniqueIDs` 模式），未落地不得交付前端变更。
- **DOM 断言必须验证祖先链**：自动化断言"元素属于某容器 / 被某功能使用"时，必须加 `closest('#容器')` / `contains()` 类校验，禁止仅凭 `getElementById` 的存在性与内容判定通过——元素重名时这类断言必然假阳性。
- **UI 功能交付前必须真实点击走查**：触发条件 = 新增或修改用户可见交互（点击 / 输入 / 弹窗 / 下载 / 跳转）；纯样式调整（颜色、间距、文案微调）不需要。走查方式：用真实浏览器（chrome-devtools 类 MCP）以真实鼠标事件走完关键路径（打开 → 选择 → 提交 → 结果），仅脚本断言（JS `click()` / DOM 内容检查）不算验收；当脚本断言与真实点击结果矛盾时，相信真实点击并深挖（事件监听器计数 + `elementsFromPoint` + 祖先链）。
- **动态渲染"元素在但不显示"的排查顺序**：先查元素是否在预期容器里（祖先链）→ 再查是否被遮挡（`elementsFromPoint` 命中栈）→ 最后才怀疑 CSS 与脚本逻辑；不要一上来改缓存和渲染方式（本次 1.13.2 / 1.13.3 两轮修复均未命中根因，即教训）。
- **同 URL 的 html+js/css 组合资源必须发 `Cache-Control: no-cache`**（或版本指纹查询参数）：html 与 js 同版本强耦合且 URL 不带版本号时，浏览器启发式强缓存会造成"半新半旧"错乱界面。

## 三、仓库工程规范

### 代码变更发布流程（所有本地代码变更默认生效）
- 所有本地代码变更/更新，必须先完成**功能测试**与**安全验证测试**，确认无功能缺陷、安全风险后方可交付。
- 变更内容随代码同分支维护：变更记录写入 `CHANGELOG.md` 的 `[Unreleased]` 段（Keep a Changelog 结构：`[Unreleased]` / `[X.Y.Z] - ISO 日期` / 六类分类 / 文末版本对比链接，禁止用 commit log 充当变更记录）；涉及功能、界面、配置变更时 README.md 同分支修订；HANDOFF.md 动态模块按其分层规则更新。
- **日常推送（不打 Tag）**：完成功能测试与安全验证即可推送，不触发四文档齐备门禁；「README 与代码同分支修订」要求继续生效。
- **版本发布（打 Tag / 发 Release）**：进入「GitHub 发行版与版本发布规范」的四步硬门禁——四文档齐备且版本一致后，方可更新版本号、打规范 annotated tag 并推送。
- **推送后必须核验或创建/更新 GitHub Release**（`gh release view <tag>` 校验标题与正文），确保发行版在 GitHub 上完全规范可见。

### GitHub 发行版与版本发布规范（所有 GitHub 仓库强制生效）
- **每一次打 Tag / 发布 Release 时必须强制执行此检查；日常推送（不打 Tag）不触发四文档门禁。**
- **统一标题格式**：Release 标题必须严格遵循 `v<主版本.次版本.修订号>: <中文核心摘要>`（如 `v4.22.3: 出站 HTTP/HTTPS 代理集成与网络超时修复`）。注：此为个人规范——主流高星仓库 Release 标题仅有「裸 tag 名」与「产品名+版本」两种形态，本格式面向中文受众保留。
- **绝对禁止不合规标题**：
  - 严禁直接使用 Git 提交信息（如 `fix(startup): ...`、`feat(security): ...`、`chore(release): ...`）作为 Release 标题；
  - 严禁无版本号、仅有裸版本号（如仅 `v4.20.0`）、或仅有英文描述的标题；必须包含明确的版本号与清晰准确的中文功能摘要。
- **Tag 注释对齐**：本地打 tag 时必须使用带注释的 annotated tag，其 subject 必须与 Release 标题完全一致：
  `git tag -a vX.Y.Z -m "vX.Y.Z: <中文核心摘要>"`。
- **Tag 与项目版本常量的映射**：tag 版本号取项目内版本标识的主 `X.Y.Z` 部分，允许忽略项目自定义后缀（如 Go 项目版本常量 `1.13.4-panel` 对应 tag `v1.13.4`）；四文档核验时同步确认 tag 与项目内版本可对应，防止两套版本号脱节。项目版本文件以项目实际为准：`package.json` / `go.mod` / `pyproject.toml` / 代码版本常量。
- **正文（Release Notes）中文标准化**：
  - 正文必须与 `CHANGELOG.md` 中对应版本的中文记录严格对齐，不得为空，不得直接使用纯英文提交历史替代；
  - 正文排版清晰，分类对齐 Keep a Changelog 六类（`### 新增`、`### 变更`、`### 弃用`、`### 移除`、`### 修复`、`### 安全`，按需选用），**破坏性变更必须归入「变更」或「移除」，禁止留在「新增」**；去除头部重复的二级版本大标题。
- **推送执行流程（四步硬门禁，缺一不可；在打 Tag / 发 Release 时点执行）**：
  1. **四文档强制齐备核验（未齐备严禁打 Tag 与推送）**：必须同时确认并更新项目版本文件（以项目实际为准：`package.json` / `go.mod` / `pyproject.toml` / 代码版本常量）、`CHANGELOG.md`（完整中文更新记录，Keep a Changelog 结构）、`README.md`（公开仓库中英双语同步更新本次变更特性/使用说明）与 **`HANDOFF.md`（接力开发文档，记录架构、本次变更与未竟待办）**；四者齐备且版本一致后方可进入下一步；
  2. 使用规范标题打 annotated tag；
  3. 推送代码及 tags（`git push origin <branch> --tags`）；
  4. 检查 GitHub Release：若 CI 自动发布，检查其标题与正文；若无自动发布或 CI 生成的标题不符合规范，立即通过 `gh release edit/create` 同步规范化标题与正文。

### README 维护规范（所有 GitHub 仓库强制生效；双语要求限公开仓库）
- README 的**同步更新与发布阻塞门禁**统一由「GitHub 发行版与版本发布规范」的四文档核验承接（打 Tag / 发 Release 时点），本节只规定 README 自身的内容要求。任何涉及功能新增、界面重构、配置变更或架构调整的提交，README 应在同一分支中同步修订并随代码一同提交（此条适用所有仓库）。
- **公开仓库**强制维护**中英双语版 README**，并结合配图对项目功能、使用方式进行可视化说明；私有仓库与纯个人工具仓库不强制双语（单语即可）。仅有单语 README 的存量公开仓库，应在下一次功能迭代时补齐双语版（增量演进，不追溯重写）。
- **多语言命名与互链**：中文版统一命名 `README.zh-CN.md`（BCP 47 点分式，`README.md` 保留给英文）；双语两文件首行管道互链（`English | 简体中文`）；存量 `README-zh_CN.md` 等连字符变体不强制改名；双语 CHANGELOG 命名 `CHANGELOG.zh-CN.md`（参照 ant-design 的 `CHANGELOG.en-US.md` + `CHANGELOG.zh-CN.md` 模式）。
- 当代码版本迭代、功能发生变更后，README 必须**同步修订与润色**，确保描述、配图信息与仓库当前实际能力匹配，彻底杜绝文档脱节。

### GitHub 仓库门面规范（所有公开仓库强制生效）

背景：2026-10-26 全量巡检发现 13 个公开仓库中 2 个缺描述、5 个缺 topics、4 个缺 LICENSE、描述语言中/英混杂——仓库级元数据决定搜索结果、个人主页与 awesome 列表里的第一印象，与 README 正文同等重要。本节由该次巡检批量整改后固化。

- **新仓库创建即配齐「门面五件套」，缺一不视为交付完成**：
  1. **description**：`中文一句话 · English one-liner` 双语格式（参照 `zcode-remote-app`），控制在 ~100 字符避免列表页截断；
  2. **topics**：5~10 个、全小写，覆盖「生态词」（如 `zcode` / `dsh` / `codebuddy`）+「功能词」（如 `api-gateway` / `dotfiles`）+「语言/平台词」；
  3. **LICENSE**：默认 MIT，版权行统一 `Copyright (c) <年份> wjf1`；
  4. **README**：中英双语，骨架为「徽章行（紧随标题、逐行排列、左对齐；常用徽章集：CI 状态 / License / 版本 / 下载量）→ 一句话定位（独立成行；单语 ≤120 字符、与 GitHub description 语义一致；双语仓库中英各一行）→ 截图/GIF 演示 → ✨ 功能特性 → 🚀 快速开始（三步内跑通）→ ⚙️ 配置表 → FAQ → Contributing（链接 CONTRIBUTING.md 与 issues）→ License」；README 超 100 行时必须含 TOC 并链接全部二级标题；
  5. **homepage**：有 GitHub Pages / 在线 demo 时必设（`gh repo edit <repo> --homepage`）。
- **元数据用 `gh` 维护，不占用四文档门禁**：description / topics / homepage 用 `gh repo edit`，LICENSE 用 `gh api -X PUT repos/<owner>/<repo>/contents/LICENSE` 直接提交，无需走 CHANGELOG / tag 流程。
- **README 必须有实拍截图或 GIF**：无图仓库在交付 / 巡检时视为门面未完成；截图存 `docs/` 或 `assets/` 目录后在 README 引用（`static/`、`.github/` 亦可），不要外链易失效的图床；CLI 工具优先用 GIF。
- **Pinned 置顶与 Social Preview 只能网页端手动设置**：Social Preview 图尺寸 1280×640，位于仓库 Settings → General → Social preview；核心仓库上线时务必配图。个人主页 pinned 保持 4~6 个精选。
- **Profile README（`wjf1/wjf1`）是个人门面**：新增核心仓库或项目定位变化时，同步更新其「精选项目 / Featured Projects」导航表。

### 社区健康文件规范（公开仓库强制生效）
- 公开仓库创建时标配 LICENSE 与 README（由「仓库门面规范」五件套承接）。
- **开始接受外部贡献（收到首个外部 issue / PR）时，必须补齐**：`CONTRIBUTING.md`（开发环境搭建、代码风格、测试要求、PR 流程）与 `SECURITY.md`（支持版本、漏洞上报方式）；GitHub 会在 New Issue / New PR 页自动挂接 CONTRIBUTING、在 Security 标签页自动挂接 SECURITY.md。
- **`.github/` 目录内聚维护**：workflows/（CI / Release）、ISSUE_TEMPLATE/（bug_report.md、feature_request.md、config.yml）、PULL_REQUEST_TEMPLATE.md 一律进 `.github/`；README / LICENSE 等 GitHub 自动识别文件必须留在根级且全大写命名。
- CODE_OF_CONDUCT.md：接受外部贡献且多人协作的社区型项目，采用 Contributor Covenant 模板。

### 接力开发文档规范（HANDOFF.md，所有项目强制生效）
- **定位说明**：HANDOFF.md 为个人接力约定，非社区标准；社区对应物为 ARCHITECTURE.md（静态架构）+ 项目级 AGENTS.md（AI 上下文）+ CHANGELOG.md（变更记录）。
- **所有项目强制维护**：每个项目根目录下必须维护统一命名的接力开发文档 **`HANDOFF.md`**（若项目已有规范子目录则置于 `docs/HANDOFF.md` 并于根目录保持链接），用于跨会话、跨 Agent、多人协同开发时实现无缝上下文接力。
- **更新时机（静/动分层）**：
  - **动态模块（第 4/5 模块）强阻塞**：每一次代码变更、功能迭代、缺陷修复或任务结束交付时，必须同步更新「最近一轮变更与交付成果」与「接力开发指引与待办」；严禁在这两个模块与实际代码脱节的情况下交付任务；打 Tag / 发 Release 时点纳入四文档核验。
  - **静态模块（第 1/2/3 模块）低频**：仅在架构级变更（技术栈更换、目录重构、模块边界调整、SSOT 变化）时更新，日常变更不触发。
- **标准六大核心模块（模板规范）**：
  1. `## 项目概况与当前状态`：项目定位、当前版本号、线上部署地址/环境、最近提交与发布 Tag。
  2. `## 技术栈与运行基线`：核心框架、运行时版本（Node/Python/Go）、第三方依赖约束、核心 CLI 指令（安装、本地启动、测试、构建、数据校验）。
  3. `## 核心架构与文件拓扑`：关键目录职责、数据流向、单一事实来源配置（SSOT）、关键组件职责与边界。
  4. `## 最近一轮变更与交付成果`：本次会话完成了什么、修改/新增了哪些关键文件、解决的核心问题、测试与构建验证数据。
  5. `## 接力开发指引与待办（Next Steps / Backlog）`：当前遗留待办事项、后续演进路线、优先级建议、若其他会话接手应从哪一步切入。
  6. `## 关键避坑与运行约束`：环境边界（如 Windows/Linux 路径差异、超时控制）、特定依赖/常驻进程限制、已知陷阱及解法。
- **新会话接入第一步**：任何新会话或新 Agent 接手已有项目时，除了阅读 README 和 CHANGELOG 外，**必须优先阅读 `HANDOFF.md`**，快速建立对当前代码真实进展与未竟任务的准确心智，无需耗费大量 Token 盲目全盘探索。

### 项目级 AGENTS.md 规范（所有活跃项目强制生效）
- 每个活跃项目在**仓库根目录**维护 `AGENTS.md`（agents.md 开放标准，60k+ 仓库采用，与 zcode 用户级配置同体系），写入：项目概览、构建与测试命令、代码风格约定、PR/提交规范等项目级上下文。
- **分层职责**：用户级全局（本文件）只承载环境硬约束与跨项目行为规范；项目级 AGENTS.md 承载项目专属约定；monorepo 子包可再嵌套（代理自动读取目录树中最近的 AGENTS.md，最近者优先）。
- **与 HANDOFF.md 分工**：AGENTS.md 写「怎么构建 / 怎么测 / 什么风格」（指令，稳定）；HANDOFF.md 写「最近做了什么 / 接下来做什么」（状态，滚动）。

### ARCHITECTURE.md 规范（代码量超 1 万行的项目强制生效）
- 代码量超 1 万行的项目在根目录维护 `ARCHITECTURE.md`（matklad 惯例），内容五要素：鸟瞰问题 → codemap（只答「X 在哪 / 这个模块干嘛的」，不写实现细节）→ 架构不变量（含刻意不做的东西）→ 层与系统边界 → 横切关注点。
- **维护纪律**：只写不常变的内容、不与代码逐次同步；点名文件/类型但不放链接；每半年复审一次。
- **与 HANDOFF.md 的关系**：项目同时维护两者时，HANDOFF 静态模块（1/2/3）直接引用 ARCHITECTURE.md、不重复维护；未达 1 万行的项目由 HANDOFF 静态模块兼任其职责。

### 技能安装规范（`npx skills`，Agent Skills 标准）
- 统一用 `npx skills` 安装：`npx skills add <owner/repo> -s <skill名> -a zcode -g -y`。agent 标识固定为 `zcode`（对应用户级 `~/.zcode/skills/`），不要装到其它目录；`skillhub` / `clawhub` 本机不存在，不再使用。
- `-s` 一次只装一个 skill，需要多个时逐个执行；先用 `-l` 列出仓库内 skill 名再精选，不整包盲装。
- 安装前检查重名：对照 `~/.zcode/skills/`、`~/.agents/skills/` 与官方插件自带技能（document-skills 的 docx/pdf/pptx/xlsx、skill-creator 等）——用户技能会遮蔽同名插件技能，同名即降级，必须跳过。
- 安装前先汇总技能的来源、版本、风险，交用户确认后再装。

## 四、专用环境与历史附录

### Command Code 代理（已退役 ZCode 侧插件，现仅经本地代理）
- ZCode 侧的 Command Code 插件、MCP 工具（`commandcode_*`）、`/commandcode`、`/commandcode-panel` 命令与 `commandcode` 技能**均已退役移除**：不要尝试调用 `commandcode_*` 工具，也不要建议安装 `command-code` CLI。**旧面板 http://127.0.0.1:18400 已停用**，不要再启动它。
- **唯一入口是本机代理 http://127.0.0.1:9090**（回环、常驻，由计划任务 `CommandCodeProxy` 自启）。它同时是 OpenAI / Anthropic 兼容网关（`/v1/chat/completions`、`/v1/messages`）与管理面板（浏览器打开根路径 `/`：用量、计费周期、账号轮换、模型目录、日志、引擎开关）。
- 用量 / 额度 / 套餐 / 计费周期 → `GET /api/usage/overview`（`plan` 块含套餐名、官方额度与 5h/周上限、周期起止、剩余天数、进度）；模型目录 → `GET /v1/models`，按套餐过滤：`GET /v1/models?plan=individual-go&available=1`。
- API key 在用户级环境变量 `COMMANDCODE_API_KEY` 中（代理与 `~/.commandcode/auth.json` 均会读取）。
