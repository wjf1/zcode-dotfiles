# zcode-dotfiles

[English](#english) | [中文](#中文)

<a id="中文"></a>
## 中文

ZCode 跨机器配置同步仓库。新电脑上两条命令完成全部部署，无需逐项重新配置。

### 新机器一键部署（Windows）

前提：装好 [Git](https://git-scm.com/) 和 ZCode 桌面版，然后：

```powershell
git clone https://github.com/wjf1/zcode-dotfiles.git
cd zcode-dotfiles
powershell -ExecutionPolicy Bypass -File deploy.ps1
```

脚本会自动：

1. 备份新机器上已有的 `~/.zcode`（如有）到 `~/.zcode-backup-<时间戳>`
2. 恢复个人默认指令 `AGENTS.md`、用户技能 `skills/`、斜杠命令 `commands/`
3. 恢复插件市场列表、插件注册信息（含下载源和版本）
4. 合并恢复 MCP 服务器配置和插件启用状态（不覆盖目标机器其它设置）

> skills 目录先清空再整体复制，保证与仓库快照完全一致，不残留旧版 skill。

完成后**重启 ZCode**。若个别插件未自动下载，到 Settings → Plugin Management 里点一下安装即可（来源、版本都已在注册表里）。

> 登录态（OAuth）和 API 密钥出于安全设计不随配置文件同步，需重新登录一次。

### 本机改了配置后更新仓库

```powershell
powershell -ExecutionPolicy Bypass -File export.ps1
git add -A; git commit -m "sync"; git push
```

export 会把 `skills/` 整目录镜像到仓库（含删除本地已删 skill 的同步）。

### 同步范围

| 内容 | 路径 |
|---|---|
| 个人默认指令 | `~/.zcode/AGENTS.md` |
| 用户技能（38+） | `~/.zcode/skills/`（整目录镜像） |
| MCP + 插件启用状态 | `~/.zcode/cli/config.json` |
| 插件注册/下载源 | `~/.zcode/cli/plugins/installed_plugins.json`、`known_marketplaces.json` |
| 自定义斜杠命令 | `~/.zcode/commands/` |

路径在本仓库中以 `__ZCODE_HOME__` 占位符存储（skills 目录内无绝对路径，直接复制），部署时自动替换为本机用户目录，跨用户名机器可用。

**占位符覆盖不到的部分**：`cli/config.json` 里除 `__ZCODE_HOME__` 之外的 MCP 依赖路径是本机专属，部署时不会被改写 —— 如 `E:\OpenCode\*.cmd`（context7 / sequential-thinking / chrome-devtools）与 `AppData\Local\Programs\codebase-memory-mcp\*.exe`。新机器需先装好这些工具，或手动改 `config.json` 里的路径。另注意 `zcode-token-usage-statusbar` 用到的 `usage_mcp.py` 位于 `~/.zcode/zcode-token-usage-statusbar/`，**不在同步范围内**，新机器上该 MCP 会启动失败，需单独补上该脚本。

**刻意不同步**：会话数据、日志、插件缓存（自动重下）、登录凭证、API 密钥。

---

<a id="english"></a>
## English

Cross-machine sync repo for ZCode configuration. Two commands on a new PC restore everything — no manual reconfiguration.

### One-click deploy on a new machine (Windows)

Prerequisites: [Git](https://git-scm.com/) and ZCode Desktop installed, then:

```powershell
git clone https://github.com/wjf1/zcode-dotfiles.git
cd zcode-dotfiles
powershell -ExecutionPolicy Bypass -File deploy.ps1
```

The script will:

1. Back up any existing `~/.zcode` on the new machine to `~/.zcode-backup-<timestamp>`
2. Restore personal default instructions `AGENTS.md`, user skills `skills/`, and slash commands `commands/`
3. Restore plugin marketplace list and plugin registry (download sources + versions)
4. Merge MCP server config and plugin enablement (without overwriting other settings on the target machine)

> The skills directory is emptied before a full copy, so it always matches the repo snapshot exactly with no stale skills left behind.

Then **restart ZCode**. If a plugin doesn't auto-download, install it once via Settings → Plugin Management (source and version are already in the registry).

> Login state (OAuth) and API keys are intentionally never synced — log in again after deploy.

### Push local changes back to the repo

```powershell
powershell -ExecutionPolicy Bypass -File export.ps1
git add -A; git commit -m "sync"; git push
```

Export mirrors the whole `skills/` directory into the repo (including removal of locally deleted skills).

### Sync scope

| Content | Path |
|---|---|
| Personal default instructions | `~/.zcode/AGENTS.md` |
| User skills (38+) | `~/.zcode/skills/` (full-directory mirror) |
| MCP + plugin enablement | `~/.zcode/cli/config.json` |
| Plugin registry / sources | `~/.zcode/cli/plugins/installed_plugins.json`, `known_marketplaces.json` |
| Custom slash commands | `~/.zcode/commands/` |

Paths are stored with a `__ZCODE_HOME__` placeholder (skills contain no absolute paths, copied verbatim) and replaced with the local home directory on deploy, so it works across machines with different usernames.

**What the placeholder doesn't cover**: MCP dependency paths in `cli/config.json` other than `__ZCODE_HOME__` are machine-specific and are not rewritten on deploy — e.g. `E:\OpenCode\*.cmd` (context7 / sequential-thinking / chrome-devtools) and `AppData\Local\Programs\codebase-memory-mcp\*.exe`. Install those tools on the new machine first, or edit the paths in `config.json` by hand. Also note that the `zcode-token-usage-statusbar` server's `usage_mcp.py` lives in `~/.zcode/zcode-token-usage-statusbar/`, which is **not in sync scope** — that MCP will fail to start on a fresh machine until you supply the script.

**Intentionally not synced**: session data, logs, plugin caches (re-downloaded automatically), login credentials, API keys.
