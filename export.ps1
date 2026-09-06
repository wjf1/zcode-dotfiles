# 将本机 ZCode 配置导出到本仓库 files/ 目录（路径统一替换为占位符）
# 用法: powershell -ExecutionPolicy Bypass -File export.ps1
$ErrorActionPreference = "Stop"
$repo    = $PSScriptRoot
$zcode   = Join-Path $env:USERPROFILE ".zcode"
$files   = Join-Path $repo "files"
$ph      = "__ZCODE_HOME__"

# 需要同步的文件清单（源路径相对于 ~/.zcode）
$items = @(
  "AGENTS.md",
  "cli\config.json",
  "cli\plugins\installed_plugins.json",
  "cli\plugins\known_marketplaces.json",
  "commands\usage.md"
)

New-Item -ItemType Directory -Force -Path (Join-Path $files "cli\plugins"),(Join-Path $files "commands") | Out-Null

foreach ($rel in $items) {
  $src = Join-Path $zcode $rel
  if (-not (Test-Path $src)) { Write-Warning "跳过（不存在）: $rel"; continue }
  $text = Get-Content $src -Raw -Encoding UTF8
  $esc = $env:USERPROFILE.Replace('\', '\\')  # JSON 转义形式的本机路径
  $text = $text.Replace($esc, $ph).Replace($env:USERPROFILE, $ph)
  $dst = Join-Path $files $rel
  [System.IO.File]::WriteAllText($dst, $text, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "导出: $rel"
}
Write-Host "`n完成。请检查 files/ 后自行 git add -A && git commit && git push"
