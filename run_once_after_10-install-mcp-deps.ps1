# 部署后一次性依赖检测 + 渲染产物自检（chezmoi run_once_after_，Windows 版）
# 依赖清单的唯一事实源是仓库根目录的 mcp-deps.yaml。
$ErrorActionPreference = "Continue"

if ($env:OS -ne "Windows_NT") {
  Write-Host "[mcp-deps] platform=unix skipped-by-windows-script"
  exit 0
}

Write-Host "[mcp-deps] platform=windows"
Write-Host "== ZCode MCP 依赖检测（Windows）=="

function Test-CommandExists([string]$Name) {
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

if (Test-CommandExists "node" -and (Test-CommandExists "npx.cmd" -or Test-CommandExists "npx")) {
  Write-Host "[deps] OK   node $((Get-Command node).Version) / npx 可用（context7、sequential-thinking、chrome-devtools 需要）"
} else {
  Write-Host "[deps] WARN 未找到 node/npx —— 黄色级 MCP（context7、sequential-thinking、chrome-devtools）将无法启动。"
  Write-Host "       安装 Node.js 18+ 后重启 ZCode 即可，无需重新 apply。"
}

$cfgPath = Join-Path $env:USERPROFILE ".zcode\cli\config.json"
$statusbar = Join-Path $env:USERPROFILE ".zcode\zcode-token-usage-statusbar\usage_mcp.py"
if (Test-Path $statusbar) {
  Write-Host "[deps] OK   token 用量状态栏脚本已就位：$statusbar"
} else {
  Write-Host "[deps] WARN 缺少 $statusbar（脚本本体不随本仓库同步）"
  Write-Host "       执行：git clone https://github.com/wjf1/zcode-token-usage-statusbar.git `"$env:USERPROFILE\.zcode\zcode-token-usage-statusbar`""
}

$memoryExe = Join-Path $env:USERPROFILE "AppData\Local\Programs\codebase-memory-mcp\codebase-memory-mcp.exe"
if (Test-Path $memoryExe) {
  Write-Host "[deps] OK   codebase-memory-mcp.exe 已就位"
} else {
  Write-Host "[deps] WARN 未找到 codebase-memory-mcp.exe（红色级，仅 Windows）；未安装时 config.json 不渲染该条目。"
}

# ---- 渲染产物自检：逐个校验 config.json 里声明的 command 在本机是否存在 ----
if (Test-Path $cfgPath) {
  Write-Host "== 渲染产物自检：$cfgPath =="
  try {
    $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
    foreach ($p in $cfg.mcp.servers.PSObject.Properties) {
      $cmd = $p.Value.command
      if ((Test-CommandExists $cmd) -or (Test-Path -LiteralPath $cmd)) {
        Write-Host "[mcp-check] OK   $($p.Name): $cmd"
      } else {
        Write-Warning "[mcp-check] $($p.Name): $cmd 不存在 <- 该 MCP 将启动失败，请按 mcp-deps.yaml 处理"
      }
    }
  } catch {
    Write-Warning "[mcp-check] config.json 解析失败：$_"
  }
} else {
  Write-Warning "[mcp-check] 未找到 $cfgPath，渲染产物自检未执行"
}

# ---- 插件安装：优先用 zcode CLI 幂等执行（非致命；测试模式整段跳过）----
if ($env:ZCODE_TEST_NO_SIDE_EFFECTS -eq "1") {
  Write-Host "[plugins] SKIP test-mode"
} elseif (Test-CommandExists "zcode") {
  $listed = (& zcode plugins list --json 2>$null) -join "`n"
  if ($listed -match '"github@zcode-plugins-official"') {
    Write-Host "[plugins] OK   github@zcode-plugins-official 已安装"
  } else {
    & zcode plugins install github@zcode-plugins-official --scope user *> $null
    if ($LASTEXITCODE -eq 0) {
      Write-Host "[plugins] OK   已安装 github@zcode-plugins-official"
    } else {
      Write-Host "[plugins] WARN 自动安装失败；请到 Settings -> Plugin Management 手动点一次安装"
    }
  }
} else {
  Write-Host "[plugins] WARN 未找到 zcode CLI；已按 installed_plugins.json 同步安装记录，请在 ZCode 内点一次安装"
}

Write-Host "== 检测结束：以上 WARN 项按 mcp-deps.yaml 处理；若你重新克隆了状态栏仓库，重启 ZCode 即可生效 =="
