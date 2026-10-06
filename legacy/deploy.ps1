# ZCode 配置一键部署（历史归档实现，详见 legacy/README.md，迁移完成后不可执行）
# 用法: powershell -ExecutionPolicy Bypass -File deploy.ps1
$ErrorActionPreference = "Stop"
$repo    = $PSScriptRoot
$zcode   = Join-Path $env:USERPROFILE ".zcode"
$files   = Join-Path $repo "files"
$ph      = "__ZCODE_HOME__"
$home_   = $env:USERPROFILE
# R0 修复：JSON 里的路径必须用转义形式。脚本级统一定义，避免各处重复计算漏转义。
$escHome = $home_.Replace('\', '\\')

if (-not (Test-Path $files)) { Write-Error "找不到 files/ 目录，请在仓库根目录运行"; exit 1 }

# 备份现有配置
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
if (Test-Path $zcode) {
  $bak = Join-Path $env:USERPROFILE ".zcode-backup-$stamp"
  Copy-Item $zcode $bak -Recurse -Force
  Write-Host "已备份原配置到 $bak"
}

# 通用还原函数：读模板 -> 替换占位符 -> 写目标
function Restore-File([string]$rel) {
  $tpl = Join-Path $files $rel
  if (-not (Test-Path $tpl)) { Write-Warning "模板缺失，跳过: $rel"; return }
  $dst = Join-Path $zcode $rel
  New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
  $text = [System.IO.File]::ReadAllText($tpl)
  $text = $text.Replace($ph, $escHome)
  [System.IO.File]::WriteAllText($dst, $text, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "已恢复: $rel"
}

# 1. 简单文件直接还原
Restore-File "AGENTS.md"
Restore-File "cli\plugins\installed_plugins.json"
Restore-File "cli\plugins\known_marketplaces.json"
Restore-File "commands\usage.md"

# 1b. skills 整目录还原（先清空目标再复制，避免残留旧版 skill）
$tplSkills = Join-Path $files "skills"
$dstSkills = Join-Path $zcode "skills"
if (Test-Path $tplSkills) {
  if (Test-Path $dstSkills) { Remove-Item $dstSkills -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $dstSkills | Out-Null
  Copy-Item (Join-Path $tplSkills "*") $dstSkills -Recurse -Force
  $n = (Get-ChildItem $dstSkills -Directory).Count
  Write-Host "已恢复: skills\ ($n 个)"
} else {
  Write-Warning "模板缺失，跳过: skills\"
}

# 2. config.json 做合并（不覆盖目标机器上已有其它设置）
$tplCfg = Join-Path $files "cli\config.json"
$dstCfg = Join-Path $zcode "cli\config.json"
if (Test-Path $dstCfg) {
  $cur = Get-Content $dstCfg -Raw | ConvertFrom-Json
  $tplText = (Get-Content $tplCfg -Raw).Replace($ph, $escHome)
  $tpl = $tplText | ConvertFrom-Json
  foreach ($p in $tpl.PSObject.Properties) {
    $cur | Add-Member -MemberType NoteProperty -Name $p.Name -Value $p.Value -Force
  }
  $cur | ConvertTo-Json -Depth 20 | Set-Content $dstCfg -Encoding UTF8
  Write-Host "已合并: cli\config.json"
} else {
  Restore-File "cli\config.json"
}

Write-Host "`n部署完成！请重启 ZCode。"
Write-Host "- 插件若未自动下载：Settings -> Plugin Management 中可见，点击安装即可（来源与版本已恢复）。"
Write-Host "- OAuth 登录和 API 密钥出于安全不随配置同步，需重新登录一次。"
