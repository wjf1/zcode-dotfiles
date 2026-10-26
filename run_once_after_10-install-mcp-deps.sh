#!/bin/sh
# 部署后一次性依赖检测 + 渲染产物自检（chezmoi run_once_after_，macOS/Linux 版）
# 依赖清单的唯一事实源是仓库根目录的 mcp-deps.yaml。
#
# 注意：本文件凡 "$VAR" 紧跟非 ASCII 字符处一律写成 "${VAR}"。macOS 自带的 bash 3.2
# 在多字节字符紧邻变量名时会把它吞进变量名，配合 set -u 直接报 unbound variable。
set -u

# Windows 兜底：若 .chezmoiignore 未拦住本脚本，这里直接空跑退出。
# ZCODE_SKIP_OS_GUARD=1 可绕过该守卫，供验收脚本在任意平台验证脚本主体逻辑。
if [ "${ZCODE_SKIP_OS_GUARD:-}" != "1" ]; then
  case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*) echo "[mcp-deps] platform=windows skipped-by-unix-script"; exit 0 ;;
  esac
fi

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
if [ -f "${STATUSBAR}" ]; then
  echo "[deps] OK   token 用量状态栏脚本已就位：${STATUSBAR}"
else
  echo "[deps] WARN 缺少 ${STATUSBAR}（脚本本体不随本仓库同步）"
  echo "       执行：git clone https://github.com/wjf1/zcode-token-usage-statusbar.git \"$HOME/.zcode/zcode-token-usage-statusbar\""
fi

# ---- 渲染产物自检：逐个校验 config.json 里声明的 command 在本机是否存在 ----
CFG="$HOME/.zcode/cli/config.json"
if [ -f "${CFG}" ]; then
  echo "== 渲染产物自检：${CFG} =="
  grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' "${CFG}" \
    | sed 's/.*:[[:space:]]*"//; s/"$//' | sort -u | while IFS= read -r cmd; do
      [ -n "$cmd" ] || continue
      if have "$cmd" || [ -f "$cmd" ]; then
        echo "[mcp-check] OK   $cmd"
      else
        echo "[mcp-check] WARN 命令不存在：$cmd   <- 该 MCP 将启动失败，请按 mcp-deps.yaml 处理"
      fi
    done
else
  echo "[mcp-check] WARN 未找到 ${CFG}，渲染产物自检未执行"
fi

# ---- 插件安装：优先用 zcode CLI 幂等执行（非致命；测试模式整段跳过）----
# ZCode 是否信任 installed_plugins.json 的 installPath 未定（HANDOFF 待办 2），
# 因此不再只靠同步记录：有 zcode CLI 就让 ZCode 自己装；任何失败只 WARN，不阻塞部署。
if [ "${ZCODE_TEST_NO_SIDE_EFFECTS:-}" = "1" ]; then
  echo "[plugins] SKIP test-mode"
elif command -v zcode >/dev/null 2>&1; then
  if zcode plugins list --json 2>/dev/null | grep -q '"github@zcode-plugins-official"'; then
    echo "[plugins] OK   github@zcode-plugins-official 已安装"
  elif zcode plugins install github@zcode-plugins-official --scope user >/dev/null 2>&1; then
    echo "[plugins] OK   已安装 github@zcode-plugins-official"
  else
    echo "[plugins] WARN 自动安装失败；请到 Settings → Plugin Management 手动点一次安装"
  fi
else
  echo "[plugins] WARN 未找到 zcode CLI；已按 installed_plugins.json 同步安装记录，请在 ZCode 内点一次安装"
fi

echo "== 检测结束：以上 WARN 项按 mcp-deps.yaml 处理；若你重新克隆了状态栏仓库，重启 ZCode 即可生效 =="
