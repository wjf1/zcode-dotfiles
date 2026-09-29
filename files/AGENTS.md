## Command Code（已退役 ZCode 侧插件，现仅经本地代理）

- ZCode 侧的 Command Code 插件、MCP 工具（`commandcode_*`）、`/commandcode`、`/commandcode-panel` 命令与 `commandcode` 技能**均已退役移除**：不要尝试调用 `commandcode_*` 工具，也不要建议安装 `command-code` CLI。**旧面板 http://127.0.0.1:18400 已停用**，不要再启动它。
- **唯一入口是本机代理 http://127.0.0.1:9090**（回环、常驻，由计划任务 `CommandCodeProxy` 自启）。它同时是 OpenAI / Anthropic 兼容网关（`/v1/chat/completions`、`/v1/messages`）与管理面板（浏览器打开根路径 `/`：用量、计费周期、账号轮换、模型目录、日志、引擎开关）。
- 用量 / 额度 / 套餐 / 计费周期 → `GET /api/usage/overview`（`plan` 块含套餐名、官方额度与 5h/周上限、周期起止、剩余天数、进度）；模型目录 → `GET /v1/models`，按套餐过滤：`GET /v1/models?plan=individual-go&available=1`。
- API key 在用户级环境变量 `COMMANDCODE_API_KEY` 中（代理与 `~/.commandcode/auth.json` 均会读取）。

---

# 用户默认指令（User AGENTS.md）

## 服务启停确认（所有任务强制生效）
- **任何服务的停止 / 关闭 / 重启，都必须先征得用户书面确认，不得擅自执行。**
- 涵盖所有本地常驻服务与本机被拉起的进程，包括但不限于：Command Code 代理（端口 9090）、以及任何由脚本 / 计划任务 / MCP 管理的服务进程。
- 确认时需说明：将停止或重启哪个服务、预期停机影响（约多少秒）、以及是否会自动重新拉起。
- 同一会话内、针对同一操作已经获得用户确认的，不再重复询问；但该确认**不跨会话、不自动延伸到其它未提及的服务**。
- 若确认后仍需操作，应尽量最小化影响：能只重载相关进程 / 热加载的，不做整体停机。

## Token 效率规则（所有任务默认生效）
- 少轮数优先：相互独立的工具调用在同一轮并行批量执行，不要一步步串行试探。
- 不做冗余观察：同一状态不重复读取/截图；文件只在必要时读，避免反复读同一文件的大段内容。
- 电脑控制（computer-use）时优先走无截图的可访问性路径（compact 级别即可），仅当语义方式到不了目标才用截图/缩放；能用一次操作完成的不拆成多次。
- 输出克制：先结论后细节；不输出用户没要求的过程清单、长篇计划和重复说明。
- 大文件/长输出只引用关键片段，不整段回贴。

## Subagent 派发规则（所有任务默认生效）
- 派发判断标准：独立的多步任务（可并行推进）、预计要扫描大量文件/产生大量中间输出的调研、需要只读隔离的排查 → 派给 subagent；单点明确的事实查询、简单一次性编辑直接做，不为启动开销买单。
- 类型选择：只读调研/大范围定位用 Explore；复杂多步执行用 general-purpose；pptx/docx/xlsx/pdf 等交付物渲染后的视觉验收用 judge。
- 读密集任务尽早派发：让原始文件内容留在子代理上下文、主会话只收回结论，避免撑爆主上下文后再靠压缩兜底。
- 派发时 prompt 必须自包含（子代理看不到主会话历史），返回结果的关键内容需向用户转述。

## 技能安装规范（`npx skills`，Agent Skills 标准）
- 统一用 `npx skills` 安装：`npx skills add <owner/repo> -s <skill名> -a zcode -g -y`。agent 标识固定为 `zcode`（对应用户级 `~/.zcode/skills/`），不要装到其它目录；`skillhub` / `clawhub` 本机不存在，不再使用。
- `-s` 一次只装一个 skill，需要多个时逐个执行；先用 `-l` 列出仓库内 skill 名再精选，不整包盲装。
- 安装前检查重名：对照 `~/.zcode/skills/`、`~/.agents/skills/` 与官方插件自带技能（document-skills 的 docx/pdf/pptx/xlsx、skill-creator 等）——用户技能会遮蔽同名插件技能，同名即降级，必须跳过。
- 安装前先汇总技能的来源、版本、风险，交用户确认后再装。

## 代码变更发布流程（所有本地代码变更默认生效）
- 所有本地代码变更/更新，必须先完成**功能测试**与**安全验证测试**，确认无功能缺陷、安全风险后方可交付。
- 测试验收通过后，将代码推送至 GitHub 仓库。
- 同步开展版本管理操作（如打 tag、更新版本号）。
- 更新对应的变更记录文档（如 CHANGELOG / 变更日志）。

## README 维护规范（所有 GitHub 仓库默认生效）
- 所有 GitHub 仓库强制维护**中英双语版 README**，并结合配图对项目功能、使用方式进行可视化说明。
- 当代码版本迭代、功能发生变更后，README 必须**同步更新**，对内容进行修订与润色完善。
- 文档更新作为代码合入的**检查项**：确保 README 描述、配图信息与仓库当前实际能力匹配，避免文档与代码脱节。

## Bash 命令硬约束（所有工作区强制生效）

背景：ZCode 在 agent runtime 重启时会执行 `taskkill /PID <旧runtime> /T` 回收旧进程树。若 Bash 起过脱离父进程的常驻进程（adb server、gradle daemon、后台 probe、nohup 进程），该 PID 会被回收或对不上号，`taskkill /T` 失败并连带杀掉 `zcode-host-local-1`，会话陷入静默（无输出、无报错，只能托盘退出重启）。日志证据：`~/.zcode/v2/logs/2026-09-1{5,6}.log`，两天内复现 7 次，累计静默超 2.5 小时。

- **禁止裸 `&`、`nohup`、`setsid` 起后台常驻进程。** 需要后台执行一律用工具的 `run_in_background: true`。
- **常驻/守护类命令必须走后台模式**：`adb` 相关（server 是 daemon）、`gradle`/`build.sh`（留 daemon）、模拟器、`logcat` 跟随、WebSocket 长连、`python tools/probe.py sub` 这类订阅探测。
- **阻塞式探测必须包硬超时**：`timeout 20 <cmd>`，且不依赖工具自带 timeout（实测会出现远超设定值仍不返回的情况）。
- **单条 Bash 前台等待控制在 60 秒内。** 不要写 `build.sh && sleep 25 && logcat` 这种把编译、等待、抓日志串在一条里的命令，拆成独立调用并各自设短超时。
- **超过 2 分钟无返回立即停（stop），不要继续等。** 继续等大概率就是 host 被杀，只能重启 ZCode 恢复。

## 工具调用避坑（2026-09-18 会话实测，均未落日志）

背景：当天会话出现多次「执行失败 / 工具调用失败」，`~/.zcode/v2/logs/2026-09-18.log` 里却没有任何 error 级记录（24 条告警全是 `web-remote-control dropped buffered outbound payloads`）——说明这类失败发生在工具与环境边界上，只能靠调用方式规避。

- **Bash 的 cwd 每条命令后都会重置回会话主工作目录**（每条结果都带 `Shell cwd was reset to ...`）。不要依赖上一条命令的 `cd`，每条命令内联 `cd <dir> && ...`。
- **不要把手写的 POSIX 路径交给 Windows 原生程序**：`node -e "require('/c/Users/...')"` 必报 `MODULE_NOT_FOUND`（`/c/...` 是 Git Bash 的写法，Node 不认）。先 `cd` 再传相对路径，或用 `cygpath -w` 转换。
- **不要猜文件后缀**：本机项目源码常是 TypeScript（`src/utils/plans.ts`，不存在 `.js`）。先 `ls` / `find` 确认再读；链式命令里放错一个路径，整条 `wc -l a b c` 都会返回 exit 1，看起来像"执行失败"。
- **MCP 工具往会话工作区写文件会被拒**：chrome-devtools 截图传 `filePath` 会报 `Access denied: ... is not within any of the configured workspace roots`——连工作目录本身也被拒。做法是**不传 `filePath`**，让工具把产物落到 artifacts 目录并返回绝对路径，再用 `cp` 搬到目标位置。
- **大图不要在会话里读**：超过 200KiB 的 MCP 图片不会内联，`Read` 只能拿到被截断的 `data:image/...;base64,` 前缀，无法判读内容。视觉验收改用**可编程断言**（`getComputedStyle` / `getBoundingClientRect` / 元素数量与文本），截图只作留档产物，不作为判读依据。
- **CLI 不读 Windows 系统代理**：浏览器能打开 github.com 不代表 git / curl 能——它们只看自己的配置和环境变量（git 侧已固化 `http.proxy = http://127.0.0.1:7897`，另有用户级 `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY=localhost,127.0.0.1,::1`）。代理未启动时用 `git -c http.proxy= <cmd>` 临时直连。
- **单条命令的输出保持克制**：整段 `cat` 大文件、base64 图片这类大 payload，与日志里唯一的告警 `dropped buffered outbound payloads`（当天 24 次）在时间上聚集，疑似相关。大文件只取关键片段。

## 输出语言（所有任务强制生效）

- 会话内**所有由模型生成的自然语言内容一律使用简体中文**，包括但不限于：**思考 / 推理过程**、**任务清单**（TodoWrite 的 `content`、任务卡片标题、进度描述）、中间状态说明、最终回复。
- 不要因为任务标题、URL、仓库名、日志、工具输出、报错信息是英文，就把思考过程或任务清单切成英文。语言由本条规则决定，不由上下文语言决定。
- 例外（保持原样、不翻译）：代码与代码标识符、命令与命令行参数、文件路径、第三方库 / API / 产品名、工具返回的报错原文、引用他人英文原文、用户以英文给出的专有名词。
- 中英混排时按中文语序组织句子，只在上述例外范围内夹用英文词，不要整句英文。
