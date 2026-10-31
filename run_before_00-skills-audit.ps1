# apply 前技能纳管审计（chezmoi run_before_，Windows 版；每次 apply 都跑）。
# 只读、只警告、永不阻塞 apply。语义与 run_before_00-skills-audit.sh 对齐；
# 输出标记全部为 ASCII（验收脚本按标记断言；PS 5.1 中文输出走系统代码页不可靠）。
$ErrorActionPreference = "Continue"

$skillsDir = if ($env:ZCODE_SKILLS_DIR) { $env:ZCODE_SKILLS_DIR } else { Join-Path $env:USERPROFILE ".zcode\skills" }
$src = $env:CHEZMOI_SOURCE_DIR
if (-not $src -and (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
  $src = (chezmoi source-path 2>$null)
}
if ($src) { $src = "$src".Trim() }
$exact = if ($src) { Join-Path $src "dot_zcode\exact_skills" } else { $null }

if (-not $exact -or -not (Test-Path $exact)) {
  Write-Output "[skills-audit] SKIP source dir unknown ($src)"
  exit 0
}
if (-not (Test-Path $skillsDir)) {
  Write-Output "[skills-audit] OK no skills dir: $skillsDir"
  exit 0
}

# .chezmoiignore 里字面量排除的技能（如 ppt-master）不算未纳管；
# 模板写法的排除项解析不到，此时宁可多警告也不漏报（警告无副作用）。
$ignored = @()
$ignoreFile = Join-Path $src ".chezmoiignore"
if (Test-Path $ignoreFile) {
  foreach ($line in (Get-Content $ignoreFile)) {
    if ($line -match '^\.zcode/skills/([A-Za-z0-9._-]+)$') { $ignored += $Matches[1] }
  }
}

$managed = 0
$unmanaged = 0
foreach ($d in (Get-ChildItem -Directory -Path $skillsDir)) {
  if (Test-Path (Join-Path $exact $d.Name)) { $managed++; continue }
  if ($ignored -contains $d.Name) { continue }
  $unmanaged++
  if ($d.LinkType) {
    Write-Output ("[skills-audit] UNMANAGED (link -> {0}): {1}" -f ($d.Target -join ','), $d.Name)
  } else {
    Write-Output ("[skills-audit] UNMANAGED: {0}" -f $d.Name)
  }
}

if ($unmanaged -gt 0) {
  Write-Output "[skills-audit] WARNING $unmanaged unmanaged skill(s) in $skillsDir; they will be DELETED by this apply (exact_ semantics)."
  Write-Output "[skills-audit] Fix: run tools/adopt-local-skills.ps1 -Add, or add a '.zcode/skills/<name>' line to .chezmoiignore (README section 6)."
} else {
  Write-Output "[skills-audit] OK all skills managed ($managed managed; .chezmoiignore excludes honored)"
}
exit 0
