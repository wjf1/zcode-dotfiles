# 获取 token 用量状态栏 MCP 的脚本本体（Windows）。
#
# 该组件是独立项目 wjf1/zcode-token-usage-statusbar，有自己的 CHANGELOG 与发布节奏，
# 因此本仓库不 vendor 它的源码（避免长期漂移），只在 config.json 里指向克隆后的路径。
$ErrorActionPreference = "Stop"

$dst  = if ($env:ZCODE_STATUSBAR_DIR) { $env:ZCODE_STATUSBAR_DIR } else { Join-Path $env:USERPROFILE ".zcode\zcode-token-usage-statusbar" }
$repo = "https://github.com/wjf1/zcode-token-usage-statusbar.git"

if (Test-Path (Join-Path $dst ".git")) {
  Write-Host "已存在，执行 git pull --ff-only：$dst"
  git -C $dst pull --ff-only
} else {
  Write-Host "克隆到 $dst"
  git clone $repo $dst
}

$entry = Join-Path $dst "usage_mcp.py"
if (Test-Path $entry) { Write-Host "OK: $entry" }
Write-Host "重启 ZCode 后 zcode-token-usage-statusbar MCP 即生效。"
