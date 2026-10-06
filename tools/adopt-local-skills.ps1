# 列出（或纳管）~/.zcode/skills 中尚未被 chezmoi source 跟踪的技能目录（Windows 版）。
#
# 背景：dot_zcode/exact_skills 带 exact_ 语义——目标目录里任何"未纳管"的技能
# 都会在下一次 apply 时被删除。用 npx skills add 装的技能默认就落在
# ~/.zcode/skills/ 且未纳管，因此装完技能后请先跑本脚本。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File tools\adopt-local-skills.ps1
#   powershell -ExecutionPolicy Bypass -File tools\adopt-local-skills.ps1 -Add
param([switch]$Add)

$ErrorActionPreference = "Stop"

$skillsDir = if ($env:ZCODE_SKILLS_DIR) { $env:ZCODE_SKILLS_DIR } else { Join-Path $env:USERPROFILE ".zcode\skills" }
if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) { Write-Error "未找到 chezmoi"; exit 1 }
if (-not (Test-Path $skillsDir)) { Write-Host "技能目录不存在：$skillsDir"; exit 0 }

$src   = (chezmoi source-path).Trim()
$exact = Join-Path $src "dot_zcode\exact_skills"
$plain = Join-Path $src "dot_zcode\skills"

$found = 0
foreach ($d in Get-ChildItem -Directory $skillsDir) {
  $name = $d.Name
  if (Test-Path (Join-Path $exact $name)) { continue }
  $found = 1
  Write-Host "unmanaged: $name"
  if ($Add) {
    # 先按目标路径纳管，再整体挪进 exact_skills/，避免 source 里出现
    # dot_zcode/skills 与 dot_zcode/exact_skills 两个目录同指一个目标。
    chezmoi add $d.FullName
    $added = Join-Path $plain $name
    if (Test-Path $added) {
      New-Item -ItemType Directory -Force -Path $exact | Out-Null
      Move-Item $added (Join-Path $exact $name)
      if ((Test-Path $plain) -and -not (Get-ChildItem $plain -Force)) { Remove-Item $plain -Force }
      Write-Host "  added -> dot_zcode/exact_skills/$name"
    } else {
      Write-Warning "  未在 source 中找到 $name，请手动核对"
    }
  }
}

if ($found -eq 0) {
  $n = (Get-ChildItem -Directory $exact).Count
  Write-Host "全部技能均已纳管（$n 个）"
} elseif (-not $Add) {
  Write-Host "提示：加 -Add 参数可逐个纳管；未纳管的技能会在下次 apply 时被删除。"
}
