#!/bin/sh
# 列出（或纳管）~/.zcode/skills 中尚未被 chezmoi source 跟踪的技能目录。
#
# 背景：dot_zcode/exact_skills 带 exact_ 语义——目标目录里任何"未纳管"的技能
# 都会在下一次 apply 时被删除。用 npx skills add 装的技能默认就落在
# ~/.zcode/skills/ 且未纳管，因此装完技能后请先跑本脚本。
#
# 用法：
#   tools/adopt-local-skills.sh          # 只列出未纳管技能
#   tools/adopt-local-skills.sh --add    # 逐个纳管到 dot_zcode/exact_skills/
set -eu

SKILLS_DIR="${ZCODE_SKILLS_DIR:-$HOME/.zcode/skills}"
ADD=0
[ "${1:-}" = "--add" ] && ADD=1

command -v chezmoi >/dev/null 2>&1 || { echo "未找到 chezmoi" >&2; exit 1; }
[ -d "$SKILLS_DIR" ] || { echo "技能目录不存在：$SKILLS_DIR" >&2; exit 0; }

SRC=$(chezmoi source-path)
EXACT="$SRC/dot_zcode/exact_skills"
PLAIN="$SRC/dot_zcode/skills"

found=0
for d in "$SKILLS_DIR"/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  if [ -d "$EXACT/$name" ]; then
    continue
  fi
  found=1
  echo "unmanaged: $name"
  if [ "$ADD" = "1" ]; then
    # 先按目标路径纳管，再整体挪进 exact_skills/，避免 source 里出现
    # dot_zcode/skills 与 dot_zcode/exact_skills 两个目录同指一个目标。
    chezmoi add "$SKILLS_DIR/$name"
    if [ -d "$PLAIN/$name" ]; then
      mkdir -p "$EXACT"
      mv "$PLAIN/$name" "$EXACT/$name"
      rmdir "$PLAIN" 2>/dev/null || true
      echo "  added -> dot_zcode/exact_skills/$name"
    else
      echo "  WARN: 未在 source 中找到 ${name}，请手动核对" >&2
    fi
  fi
done

if [ "$found" = "0" ]; then
  echo "全部技能均已纳管（$(find "$EXACT" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ') 个）"
else
  [ "$ADD" = "1" ] || echo "提示：加 --add 参数可逐个纳管；未纳管的技能会在下次 apply 时被删除。"
fi
