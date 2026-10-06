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

# skills 整目录镜像（skills 内部无绝对路径，直接复制；仓库侧删除本地已删的 skill）
$skillsSrc = Join-Path $zcode "skills"
$skillsDst = Join-Path $files "skills"
if (Test-Path $skillsSrc) {
  New-Item -ItemType Directory -Force -Path $skillsDst | Out-Null
  Copy-Item (Join-Path $skillsSrc "*") $skillsDst -Recurse -Force -Exclude ".git"
  Get-ChildItem $skillsDst -Directory | ForEach-Object {
    if (-not (Test-Path (Join-Path $skillsSrc $_.Name))) {
      Remove-Item $_.FullName -Recurse -Force
      Write-Host "删除已移除的 skill: $($_.Name)"
    }
  }
  $n = (Get-ChildItem $skillsDst -Directory).Count
  Write-Host "导出: skills\ ($n 个)"
} else {
  Write-Warning "跳过（不存在）: skills\"
}
Write-Host "`n完成。请检查 files/ 后自行 git add -A && git commit && git push"
