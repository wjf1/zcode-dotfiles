#!/bin/sh
# 获取 token 用量状态栏 MCP 的脚本本体（macOS/Linux）。
#
# 该组件是独立项目 wjf1/zcode-token-usage-statusbar，有自己的 CHANGELOG 与发布节奏，
# 因此本仓库不 vendor 它的源码（避免长期漂移），只在 config.json 里指向克隆后的路径。
set -eu

DST="${ZCODE_STATUSBAR_DIR:-$HOME/.zcode/zcode-token-usage-statusbar}"
REPO="https://github.com/wjf1/zcode-token-usage-statusbar.git"

if [ -d "$DST/.git" ]; then
  echo "已存在，执行 git pull --ff-only：$DST"
  git -C "$DST" pull --ff-only
else
  echo "克隆到 $DST"
  git clone "$REPO" "$DST"
fi

[ -f "$DST/usage_mcp.py" ] && echo "OK: $DST/usage_mcp.py"
echo "重启 ZCode 后 zcode-token-usage-statusbar MCP 即生效。"
