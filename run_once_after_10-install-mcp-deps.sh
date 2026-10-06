#!/bin/sh
# 部署后一次性依赖检测 + 渲染产物自检（chezmoi run_once_after_，macOS/Linux 版）
# 依赖清单的唯一事实源是仓库根目录的 mcp-deps.yaml。
set -u

# Windows 兜底：若 .chezmoiignore 未拦住本脚本，这里直接空跑退出
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*) echo "[mcp-deps] platform=windows skipped-by-unix-script"; exit 0 ;;
esac

echo "[mcp-deps] platform=unix"
echo "== ZCode MCP 依赖检测（macOS/Linux）=="

have() { command -v "$1" >/dev/null 2>&1; }

if have node && have npx; then
  echo "[deps] OK   node $(node --version) / npx 可用（context7、sequential-thinking、chrome-devtools 需要）"
else
  echo "[deps] WARN 未找到 node/npx —— 黄色级 MCP（context7、sequential-thinking、chrome-devtools）将无法启动。"
  echo "       安装 Node.js 18+ 后重启 ZCode 即可，无需重新 apply。"
fi

if have python3; then
  echo "[deps] OK   python3 $(python3 --version 2>&1 | awk '{print $2}') 可用（token 用量状态栏 MCP）"
else
  echo "[deps] WARN 未找到 python3 —— 按 mcp-deps.yaml，该 MCP 属绿色级但依赖 Python 3。"
fi

STATUSBAR="$HOME/.zcode/zcode-token-usage-statusbar/usage_mcp.py"
if [ -f "$STATUSBAR" ]; then
  echo "[deps] OK   token 用量状态栏脚本已就位：$STATUSBAR"
else
  echo "[deps] WARN 缺少 $STATUSBAR（脚本本体不随本仓库同步）"
  echo "       执行：git clone https://github.com/wjf1/zcode-token-usage-statusbar.git \"$HOME/.zcode/zcode-token-usage-statusbar\""
fi

# ---- 渲染产物自检：逐个校验 config.json 里声明的 command 在本机是否存在 ----
CFG="$HOME/.zcode/cli/config.json"
if [ -f "$CFG" ]; then
  echo "== 渲染产物自检：$CFG =="
  grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' "$CFG" \
    | sed 's/.*:[[:space:]]*"//; s/"$//' | sort -u | while IFS= read -r cmd; do
      [ -n "$cmd" ] || continue
      if have "$cmd" || [ -f "$cmd" ]; then
        echo "[mcp-check] OK   $cmd"
      else
        echo "[mcp-check] WARN 命令不存在：$cmd  <- 该 MCP 将启动失败，请按 mcp-deps.yaml 处理"
      fi
    done
else
  echo "[mcp-check] WARN 未找到 $CFG，渲染产物自检未执行"
fi

echo "== 检测结束：以上 WARN 项按 mcp-deps.yaml 处理；若你重新克隆了状态栏仓库，重启 ZCode 即可生效 =="
