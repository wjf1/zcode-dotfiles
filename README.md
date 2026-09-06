# zcode-dotfiles

ZCode 跨机器配置同步仓库。新电脑上两条命令完成全部部署，无需逐项重新配置。

## 新机器一键部署（Windows）

前提：装好 [Git](https://git-scm.com/) 和 ZCode 桌面版，然后：

```powershell
git clone https://github.com/wjf1/zcode-dotfiles.git
cd zcode-dotfiles
powershell -ExecutionPolicy Bypass -File deploy.ps1
```

脚本会自动：

1. 备份新机器上已有的 `~/.zcode`（如有）到 `~/.zcode-backup-<时间戳>`
2. 恢复个人默认指令 `AGENTS.md`、斜杠命令 `commands/`
3. 恢复插件市场列表、插件注册信息（含下载源和版本）
4. 合并恢复 MCP 服务器配置和插件启用状态（不覆盖目标机器其它设置）

完成后**重启 ZCode**。若个别插件未自动下载，到 Settings → Plugin Management 里点一下安装即可（来源、版本都已在注册表里）。

> 登录态（OAuth）和 API 密钥出于安全设计不随配置文件同步，需重新登录一次。

## 本机改了配置后更新仓库

```powershell
powershell -ExecutionPolicy Bypass -File export.ps1
git add -A; git commit -m "sync"; git push
```

## 同步范围

| 内容 | 路径 |
|---|---|
| 个人默认指令 | `~/.zcode/AGENTS.md` |
| MCP + 插件启用状态 | `~/.zcode/cli/config.json` |
| 插件注册/下载源 | `~/.zcode/cli/plugins/installed_plugins.json`、`known_marketplaces.json` |
| 自定义斜杠命令 | `~/.zcode/commands/` |

路径在本仓库中以 `__ZCODE_HOME__` 占位符存储，部署时自动替换为本机用户目录，跨用户名机器可用。

**刻意不同步**：会话数据、日志、插件缓存（自动重下）、登录凭证、API 密钥。
