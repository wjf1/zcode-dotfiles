#!/bin/sh
# apply 前技能纳管审计（chezmoi run_before_，每次 apply 都跑，类 Unix 版）。
#
# 背景：dot_zcode/exact_skills 带 exact_ 语义——目标 ~/.zcode/skills 里任何未被仓库
# 纳管、且未被 .chezmoiignore 显式排除的技能，都会在本次 apply 时被删除。
# 本脚本只读、只警告、永不阻塞 apply：在删除发生前给出最后一道提示。
# 处置办法：tools/adopt-local-skills.sh --add 纳管，或在 .chezmoiignore 加排除项（README §6）。
#
# 输出标记全部为 ASCII：验收脚本按标记断言（PowerShell 5.1 中文输出走系统代码页，不可靠）。
set -u

# Windows 兜底：.chezmoiignore 已在 Windows 排除本脚本，这里再守一道。
# ZCODE_SKIP_OS_GUARD=1 可绕过该守卫，供验收脚本在任意平台验证脚本主体逻辑。
if [ "${ZCODE_SKIP_OS_GUARD:-}" != "1" ]; then
  case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*) echo "[skills-audit] platform=windows skipped-by-unix-script"; exit 0 ;;
  esac
fi

SKILLS_DIR="${ZCODE_SKILLS_DIR:-${HOME}/.zcode/skills}"
SRC="${CHEZMOI_SOURCE_DIR:-}"
if [ -z "${SRC}" ] && command -v chezmoi >/dev/null 2>&1; then
  SRC=$(chezmoi source-path 2>/dev/null || true)
fi
EXACT="${SRC}/dot_zcode/exact_skills"

if [ -z "${SRC}" ] || [ ! -d "${EXACT}" ]; then
  echo "[skills-audit] SKIP source dir unknown (${SRC})"
  exit 0
fi
if [ ! -d "${SKILLS_DIR}" ]; then
  echo "[skills-audit] OK no skills dir: ${SKILLS_DIR}"
  exit 0
fi

# .chezmoiignore 里字面量排除的技能（如 ppt-master）不算未纳管：
# 只认 ".zcode/skills/<name>" 形式的非模板、非注释行；模板写法的排除项解析不到，
# 此时宁可多警告也不漏报（警告无副作用）。
IGNORED=""
IGNORE_FILE="${SRC}/.chezmoiignore"
if [ -f "${IGNORE_FILE}" ]; then
  IGNORED=$(grep -oE '^\.zcode/skills/[A-Za-z0-9._-]+' "${IGNORE_FILE}" 2>/dev/null | sed 's|^\.zcode/skills/||' || true)
fi

managed=0
unmanaged=0
for d in "${SKILLS_DIR}"/*/; do
  [ -d "${d}" ] || continue
  name=$(basename "${d}")
  if [ -d "${EXACT}/${name}" ]; then
    managed=$((managed + 1))
    continue
  fi
  if printf '%s\n' "${IGNORED}" | grep -qx -- "${name}"; then
    continue
  fi
  unmanaged=$((unmanaged + 1))
  if [ -L "${d%/}" ]; then
    echo "[skills-audit] UNMANAGED (symlink -> $(readlink "${d%/}")): ${name}"
  else
    echo "[skills-audit] UNMANAGED: ${name}"
  fi
done

if [ "${unmanaged}" -gt 0 ]; then
  echo "[skills-audit] WARNING ${unmanaged} unmanaged skill(s) in ${SKILLS_DIR}; they will be DELETED by this apply (exact_ semantics)."
  echo "[skills-audit] Fix: run tools/adopt-local-skills.sh --add, or add a '.zcode/skills/<name>' line to .chezmoiignore (README section 6)."
else
  echo "[skills-audit] OK all skills managed (${managed} managed; .chezmoiignore excludes honored)"
fi
exit 0
