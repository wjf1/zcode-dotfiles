# legacy/ —— 历史归档（不可执行）

本目录保存 chezmoi 迁移之前的两个 PowerShell 实现，**仅作行为参照与历史留档**：

| 文件 | 原作用 |
|---|---|
| `deploy.ps1` | 仓库 `files/` → 本机 `~/.zcode`（含 `__ZCODE_HOME__` 占位符替换与 config.json 合并） |
| `export.ps1` | 本机 `~/.zcode` → 仓库 `files/`（把本机路径回写成占位符） |

## 为什么不可执行

两个脚本都硬依赖仓库里的 `files/` 目录（`$files = Join-Path $repo "files"`）。迁移完成后
`files/` 已被 `dot_zcode/` 取代并删除，因此这两个脚本**一次都跑不起来**。
它们是参照物，不是 fallback——请勿在部署流程中依赖。

日常使用请走 chezmoi：

```sh
chezmoi apply     # 仓库 → 本机
chezmoi update    # 拉取远端并应用
```

## 归档件自身的修复

`deploy.ps1` 的合并分支原先直接把本机路径写进 JSON：

```powershell
$tplText = (Get-Content $tplCfg -Raw).Replace($ph, $home_)   # 未转义
```

在 Windows 上 `$home_` 含反斜杠，写进 JSON 后会形成非法转义（如 `\A`），产出的
`config.json` 无法解析。归档前已修复为与 `Restore-File` 一致的转义形式，并把 `$escHome`
提升为脚本级变量以避免重复计算漏转义：

```powershell
$escHome = $home_.Replace('\', '\\')
$tplText = (Get-Content $tplCfg -Raw).Replace($ph, $escHome)
```

`tests/acceptance.sh` 的 R0/R0b 会静态检查该修复，并在沙箱里真跑一遍归档脚本、断言产出的
JSON 合法。

## 已知遗留问题（不影响新架构，仅留档）

`export.ps1` 第 25 行先替换转义形式再替换裸路径：

```powershell
$text = $text.Replace($esc, $ph).Replace($env:USERPROFILE, $ph)
```

对 JSON 文件这是正确顺序；但对含裸反斜杠路径的非 JSON 文件（如 Markdown 说明），
第二步会把裸路径替换成占位符，语义上边界模糊。新架构下所有文件都是 verbatim 或模板渲染，
不存在字符串替换环节，该问题自然消失。
