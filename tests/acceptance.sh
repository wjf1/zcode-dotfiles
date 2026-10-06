#!/bin/sh
# ZCode dotfiles 验收脚本：覆盖 R0–R5 与 T2.1–T2.6
#
# 用法（仓库根）：
#   sh tests/acceptance.sh
#
# 全部在 .test-home/ 隔离执行，通过 chezmoi 的 --destination / -c / --persistent-state
# 三个开关把目标目录、配置与运行状态都指向测试沙箱，**不碰真实 ~/.zcode**。
# 退出码：0 = 全部通过；非 0 = 有断言失败。
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
WORK="$ROOT/.test-home"
DEST="$WORK/dest"
FAILED=0

fail() { echo "FAIL: $*"; exit 1; }
step() { echo; echo "== $*"; }
ok() { echo "   OK  $*"; }

# ---------- 路径与运行时准备 ----------
case "$(uname -s 2>/dev/null || echo unknown)" in
  MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=1 ;;
  *) IS_WINDOWS=0 ;;
esac

winpath() {
  # 用正斜杠形式（-m）：chezmoi 在 Windows 上同样接受，且能安全嵌入 TOML 字符串
  if [ "$IS_WINDOWS" = 1 ] && command -v cygpath >/dev/null 2>&1; then
    cygpath -m "$1"
  else
    printf '%s' "$1"
  fi
}

winpath_backslash() {
  # 反斜杠形式：用于真正触发"JSON 转义"路径（R0 动态复验）
  if [ "$IS_WINDOWS" = 1 ] && command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1" | sed 's|/|\\|g'
  else
    printf '%s' "$1"
  fi
}

command -v chezmoi >/dev/null 2>&1 || fail "未找到 chezmoi（先安装：sh -c \"\$(curl -fsLS https://get.chezmoi.io)\"）"

PY=""
for cand in python3 python; do
  if command -v "$cand" >/dev/null 2>&1 && "$cand" -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; then
    PY=$(command -v "$cand")
    break
  fi
done
[ -n "$PY" ] || fail "需要可用的 Python 3：config.json 合并脚本与若干断言依赖它"
PY_W=$(winpath "$PY")

rm -rf "$WORK"
mkdir -p "$WORK" "$DEST"
cat > "$WORK/chezmoi.toml" <<EOF
[interpreters.py]
    command = "$PY_W"

[data]
    zcodePythonPath = "$PY_W"
    zcodeCodebaseMemoryPath = "C:/nonexistent/codebase-memory-mcp.exe"
EOF

ROOT_W=$(winpath "$ROOT")
CFG_W=$(winpath "$WORK/chezmoi.toml")
DEST_W=$(winpath "$DEST")
STATE_W=$(winpath "$WORK/state.boltdb")

c() { chezmoi -c "$CFG_W" -S "$ROOT_W" -D "$DEST_W" --persistent-state "$STATE_W" --no-tty --force "$@"; }
py() { "$PY" "$@"; }

echo "ZCode dotfiles 验收开始（platform: $(uname -s 2>/dev/null || echo unknown)）"

# ---------- T2.1 隔离全量部署 + 结构断言 ----------
step "T2.1 隔离全量部署"
c apply --exclude=scripts
[ -f "$DEST/.zcode/AGENTS.md" ] || fail "AGENTS.md 未部署"
[ -f "$DEST/.zcode/commands/usage.md" ] || fail "commands/usage.md 未部署"
[ -f "$DEST/.zcode/cli/plugins/known_marketplaces.json" ] || fail "known_marketplaces.json 未部署"
[ -f "$DEST/.zcode/cli/plugins/installed_plugins.json" ] || fail "installed_plugins.json 未部署"
[ -f "$DEST/.zcode/cli/config.json" ] || fail "config.json 未渲染"
[ "$(find "$DEST/.zcode/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" = "38" ] || fail "skills 目录数不是 38"
[ "$(find "$DEST/.zcode/skills" -type f | wc -l | tr -d ' ')" = "68" ] || fail "skills 文件数不是 68"
ok "五个托管目标齐备，skills 38 目录 / 68 文件"

step "T2.1b .chezmoiignore：仓库自有文件不得落到目标目录"
for f in README.md CHANGELOG.md HANDOFF.md mcp-deps.yaml tests tools legacy .github PROBES.md VERIFY.md; do
  [ -e "$DEST/$f" ] && fail "仓库自有文件被部署到目标目录：$f"
done
ok "仓库自有文件全部被正确排除"

# ---------- R2 verbatim 逐字节 ----------
step "R2 verbatim 文件逐字节一致"
py - "$ROOT" "$DEST" <<'PY'
import hashlib, sys, os
root, dest = sys.argv[1], sys.argv[2]
pairs = [
    ("dot_zcode/AGENTS.md", ".zcode/AGENTS.md"),
    ("dot_zcode/commands/usage.md", ".zcode/commands/usage.md"),
    ("dot_zcode/cli/plugins/known_marketplaces.json", ".zcode/cli/plugins/known_marketplaces.json"),
]
bad = []
for src, tgt in pairs:
    with open(os.path.join(root, src), "rb") as fh:
        a = hashlib.sha256(fh.read()).hexdigest()
    with open(os.path.join(dest, tgt), "rb") as fh:
        b = hashlib.sha256(fh.read()).hexdigest()
    if a != b:
        bad.append("%s != %s" % (src, tgt))
if bad:
    print("哈希不一致：", bad)
    sys.exit(1)
print("3 个 verbatim 文件 sha256 全部一致")
PY
ok "verbatim 文件逐字节一致"

step "R2b skills 逐字节一致（source 名 dot_ 前缀需解码为 . 前缀）"
py - "$ROOT" "$DEST" <<'PY'
import os, sys, hashlib
root, dest = sys.argv[1], sys.argv[2]
src_skills = os.path.join(root, "dot_zcode", "exact_skills")
dst_skills = os.path.join(dest, ".zcode", "skills")

def decode(name):
    # chezmoi source 中 dot_ 前缀表示目标名以 . 开头
    return "." + name[4:] if name.startswith("dot_") else name

expected = {}
for dirpath, dirnames, filenames in os.walk(src_skills):
    rel = os.path.relpath(dirpath, src_skills)
    parts = [] if rel == "." else [decode(p) for p in rel.split(os.sep)]
    for fn in filenames:
        expected[os.sep.join(parts + [decode(fn)])] = os.path.join(dirpath, fn)

missing, mismatch, extra = [], [], []
for rel_target, src_path in expected.items():
    dst_path = os.path.join(dst_skills, rel_target)
    if not os.path.exists(dst_path):
        missing.append(rel_target)
        continue
    with open(src_path, "rb") as fh:
        a = hashlib.sha256(fh.read()).hexdigest()
    with open(dst_path, "rb") as fh:
        b = hashlib.sha256(fh.read()).hexdigest()
    if a != b:
        mismatch.append(rel_target)
for dirpath, dirnames, filenames in os.walk(dst_skills):
    for fn in filenames:
        rel = os.path.relpath(os.path.join(dirpath, fn), dst_skills)
        if rel not in expected:
            extra.append(rel)
    for dn in dirnames:
        if dn.startswith("dot_"):
            extra.append("未解码目录: " + os.path.relpath(os.path.join(dirpath, dn), dst_skills))
if missing or mismatch or extra:
    print("缺失:", missing[:5], "内容不符:", mismatch[:5], "多余/未解码:", extra[:5])
    sys.exit(1)
if len(expected) != 68:
    print("期望 68 个技能文件，实际", len(expected))
    sys.exit(1)
print("68 个技能文件逐字节一致，dot_ 编码已正确还原")
PY
ok "skills 逐字节一致"

# ---------- R1 自定义 server 保留 ----------
step "R1 目标机自定义 MCP server 不得被静默清除"
c apply --exclude=scripts
py - "$DEST/.zcode/cli/config.json" "$(winpath "$DEST")" <<'PY'
import json, sys
path = sys.argv[1]
cfg = json.load(open(path, encoding="utf-8"))
cfg["mcp"]["servers"]["my-local-server"] = {"command": "echo", "args": ["hello"]}
cfg["mcp"]["servers"]["context7"] = {"command": "E:\\OpenCode\\context7-mcp.cmd", "args": [], "timeoutMs": 1000}
cfg["myTopLevel"] = {"keep": True}
json.dump(cfg, open(path, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
PY
c apply --exclude=scripts
py - "$DEST/.zcode/cli/config.json" <<'PY'
import json, sys, os
cfg = json.load(open(sys.argv[1], encoding="utf-8"))
s = cfg["mcp"]["servers"]
assert "my-local-server" in s, "自定义 server 被清除"
assert s["my-local-server"]["command"] == "echo", "自定义 server 内容被改写"
assert cfg.get("myTopLevel", {}).get("keep") is True, "顶层自定义键被丢弃"
npx = "npx.cmd" if os.name == "nt" else "npx"
assert s["context7"]["command"] == npx, "模板内条目未更新为渲染值：%r" % s["context7"]["command"]
assert s["context7"]["args"] == ["-y", "@upstash/context7-mcp@4.1.0"], "npx 版本未锁定"
print("自定义 server 保留 / 模板条目更新 / 顶层自定义键保留 / npx 版本已锁定")
PY
ok "R1 通过"

# ---------- R4 幂等 ----------
step "R4 幂等：连续 apply 零变更、无备份堆叠"
find "$DEST" | sort > "$WORK/snap1"
c apply --exclude=scripts
find "$DEST" | sort > "$WORK/snap2"
diff "$WORK/snap1" "$WORK/snap2" >/dev/null || fail "两次 apply 之间目标树发生变化（非幂等）"
# 注意：chezmoi diff 会把 run_ 脚本条目列为"新增文件"，做幂等断言时必须排除 scripts
if c diff --exclude=scripts | grep -q .; then c diff --exclude=scripts; fail "chezmoi diff 非空（非幂等）"; fi
find "$WORK" -maxdepth 1 -name '.zcode-backup-*' | grep -q . && fail "出现备份目录堆叠"
[ -e "$DEST/.zcode/cli/config.json.broken-backup" ] && fail "不应出现损坏留档文件"
ok "幂等：目标树与 chezmoi diff 均为空，无备份堆叠"

# ---------- R3 skills 原子性 ----------
step "R3 skills 原子性：中途失败不得留下空/半套技能树"
# 障碍：把目标技能文件改成只读并写入篡改内容，迫使 apply 不得不重写它。
# Windows 上这会真正阻断写入（Access denied）；类 Unix 上 rename 可能仍能覆盖，
# 因此两种结果都接受，但对"技能树被清空/写坏成半套"零容忍。
OBSTACLE="$DEST/.zcode/skills/humanizer/SKILL.md"
printf 'tampered\n' > "$OBSTACLE"
chmod 444 "$OBSTACLE" 2>/dev/null || true
if c apply --exclude=scripts >"$WORK/r3.log" 2>&1; then
  echo "   注：本平台 apply 未被只读障碍阻断（rename 语义），继续断言恢复性"
else
  echo "   注：apply 已按预期在该文件上失败：$(grep -m1 -i 'denied\|被拒绝\|permission' "$WORK/r3.log" || echo '见 .test-home/r3.log')"
fi
n_dirs=$(find "$DEST/.zcode/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
n_files=$(find "$DEST/.zcode/skills" -type f | wc -l | tr -d ' ')
echo "   障碍存在时：目录 $n_dirs / 文件 $n_files"
[ "$n_dirs" = "38" ] || fail "失败后 skills 目录树被破坏（目录数 $n_dirs）"
[ "$n_files" = "68" ] || fail "失败后 skills 被清空或半套（文件数 $n_files）"
chmod 644 "$OBSTACLE" 2>/dev/null || true
c apply --exclude=scripts
[ "$(find "$DEST/.zcode/skills" -type f | wc -l | tr -d ' ')" = "68" ] || fail "障碍清除后未恢复 68 个技能文件"
if c diff --exclude=scripts | grep -q .; then c diff --exclude=scripts; fail "障碍清除后 diff 仍非空"; fi
grep -q 'tampered' "$OBSTACLE" && fail "被篡改的技能文件未恢复为仓库内容"
ok "R3 通过：失败时技能树保持 38 目录 / 68 文件，障碍清除后完全恢复"

step "R3b 局部缺失可收敛（模拟上一次中断留下的半套状态）"
rm -f "$DEST/.zcode/skills/humanizer/SKILL.md" \
      "$DEST/.zcode/skills/doc-coauthoring/SKILL.md" \
      "$DEST/.zcode/skills/pdf/SKILL.md" 2>/dev/null || true
c apply --exclude=scripts
[ "$(find "$DEST/.zcode/skills" -type f | wc -l | tr -d ' ')" = "68" ] || fail "局部缺失未被补齐"
if c diff --exclude=scripts | grep -q .; then fail "补齐后 diff 非空"; fi
ok "R3b 通过：删除部分技能后 apply 收敛一致"

# ---------- R5 installed_plugins 渲染 ----------
step "R5 installed_plugins.json 渲染正确性"
TARGET_PLUGINS="$DEST/.zcode/cli/plugins/installed_plugins.json"
grep -q '__ZCODE_HOME__' "$TARGET_PLUGINS" && fail "残留 __ZCODE_HOME__ 占位符"
py - "$TARGET_PLUGINS" <<'PY'
import json, os, sys
home = os.path.expanduser("~")
doc = json.load(open(sys.argv[1], encoding="utf-8"))
assert doc["plugins"], "plugins 为空"
for p in doc["plugins"]:
    ip = p["installPath"]
    assert ip.startswith(home), "installPath 前缀不是本机 homeDir：%s" % ip
    assert ".zcode" in ip and "plugins" in ip and "cache" in ip, "installPath 结构不符：%s" % ip
    assert "\\" in ip or "/" in ip, "installPath 无路径分隔符：%s" % ip
print("installPath 前缀 == homeDir，%d 条记录结构正确" % len(doc["plugins"]))
PY
ok "R5 通过"

# ---------- 漂移检查 ----------
step "漂移检查：mcp-deps.yaml ↔ 模板 ↔ run_once 脚本"
py - "$ROOT" <<'PY'
import re, sys, os, glob
root = sys.argv[1]
names = re.findall(r'^\s*-\s*name:\s*(\S+)', open(os.path.join(root, "mcp-deps.yaml"), encoding="utf-8").read(), re.M)
assert names, "mcp-deps.yaml 未解析到任何 server"
tpl = open(glob.glob(os.path.join(root, "dot_zcode/cli/modify_config.json*.tmpl"))[0], encoding="utf-8").read()
sh = open(os.path.join(root, "run_once_after_10-install-mcp-deps.sh"), encoding="utf-8").read()
ps = open(os.path.join(root, "run_once_after_10-install-mcp-deps.ps1"), encoding="utf-8").read()
problems = []
for n in names:
    if n not in tpl:
        problems.append("%s 未在 config.json 模板中声明" % n)
    if n == "codebase-memory-mcp":
        continue
    if n not in sh:
        problems.append("%s 未出现在 run_once .sh" % n)
    if n not in ps:
        problems.append("%s 未出现在 run_once .ps1" % n)
if problems:
    print("漂移：", problems)
    sys.exit(1)
print("mcp-deps.yaml ↔ 模板 ↔ 两个 run_once 脚本一致（%d 个 server）" % len(names))
PY
ok "无漂移"

# ---------- R0 legacy 归档质量 ----------
step "R0 legacy/deploy.ps1 不得携带已知 P0（未转义路径注入 JSON）"
[ -f "$ROOT/legacy/deploy.ps1" ] || fail "legacy/deploy.ps1 不存在"
if grep -n 'Replace($ph, $home_)' "$ROOT/legacy/deploy.ps1" | grep -v 'escHome' | grep -q .; then
  grep -n 'Replace($ph' "$ROOT/legacy/deploy.ps1"
  fail "R0 未修复：仍把未转义的本机路径写入 JSON"
fi
grep -q 'escHome' "$ROOT/legacy/deploy.ps1" || fail "R0 修复形式不符合预期（缺少 escHome）"
ok "R0 通过：合并分支已改用转义形式"

step "R0b legacy/deploy.ps1 动态复验：沙箱内真跑一遍修复后的归档件"
PS=""
for cand in powershell pwsh; do
  if command -v "$cand" >/dev/null 2>&1; then PS=$cand; break; fi
done
if [ -z "$PS" ]; then
  echo "   跳过：本机无 PowerShell，动态复验留给 CI（三平台矩阵）"
else
  R0="$WORK/r0"; RHOME="$R0/home"
  rm -rf "$R0"; mkdir -p "$R0/repo/files/cli" "$RHOME"
  cp "$ROOT/legacy/deploy.ps1" "$R0/repo/deploy.ps1"
  cat > "$R0/repo/files/cli/config.json" <<'EOF'
{
  "mcp": {
    "servers": {
      "zcode-token-usage-statusbar": {
        "command": "__ZCODE_HOME__\\AppData\\Local\\Programs\\Python\\Python312\\python.exe",
        "args": ["__ZCODE_HOME__\\.zcode\\zcode-token-usage-statusbar\\usage_mcp.py"]
      }
    }
  }
}
EOF
  # 故意用反斜杠形式的 USERPROFILE，才能真正触发"路径转义"这条修复
  RHOME_W=$(winpath_backslash "$RHOME")
  if USERPROFILE="$RHOME_W" "$PS" -NoProfile -ExecutionPolicy Bypass -File "$(winpath "$R0/repo/deploy.ps1")" > "$WORK/r0.log" 2>&1; then
    py - "$RHOME" "$RHOME_W" <<'PY'
import json, os, sys
home_posix, home_win = sys.argv[1], sys.argv[2]
path = os.path.join(home_posix.replace("\\", "/"), ".zcode", "cli", "config.json")
cfg = json.load(open(path, encoding="utf-8"))
cmd = cfg["mcp"]["servers"]["zcode-token-usage-statusbar"]["command"]
assert "__ZCODE_HOME__" not in cmd, "占位符未被替换"
expected = home_win + r"\AppData\Local\Programs\Python\Python312\python.exe"
assert cmd == expected, "路径注入结果不符：%r != %r" % (cmd, expected)
print("修复后归档脚本产出合法 JSON，路径按转义形式注入：", cmd)
PY
    ok "R0b 通过：修复后的归档件产出合法 JSON"
  else
    cat "$WORK/r0.log"
    fail "修复后的归档脚本在沙箱内执行失败"
  fi
  rm -rf "$R0"
fi
[ -e "$ROOT/files" ] && fail "files/ 目录应已删除（legacy 定位为不可执行的归档）"
[ -e "$ROOT/deploy.ps1" ] && fail "仓库根不应再有 deploy.ps1"
ok "旧脚本已归档，仓库根无 deploy/export/files"

# ---------- run_once 脚本：语法 + 渲染自检 ----------
step "run_once 脚本语法与渲染产物自检"
sh -n "$ROOT/run_once_after_10-install-mcp-deps.sh" || fail ".sh 语法错误"
ok ".sh 语法通过"

FAKEHOME="$WORK/fakehome"
mkdir -p "$FAKEHOME/.zcode/cli"
cat > "$FAKEHOME/.zcode/cli/config.json" <<'EOF'
{
  "mcp": {
    "servers": {
      "bogus-server": { "command": "definitely-not-a-real-command-xyz", "args": [] }
    }
  }
}
EOF
if [ "$IS_WINDOWS" = 1 ]; then
  # Windows：.sh 应自身早退，.ps1 应真正执行自检
  # 断言一律用 ASCII 标记：Windows PowerShell 5.1 的输出走系统代码页，中文匹配不可靠
  out_sh=$(HOME="$FAKEHOME" sh "$ROOT/run_once_after_10-install-mcp-deps.sh" 2>&1 || true)
  echo "$out_sh" | grep -q 'skipped-by-unix-script' || fail ".sh 在 Windows 未按预期早退：$out_sh"
  ok ".sh 在 Windows 正确早退"
  out_ps=$(USERPROFILE="$FAKEHOME" powershell -NoProfile -ExecutionPolicy Bypass -File "$ROOT/run_once_after_10-install-mcp-deps.ps1" 2>&1 || true)
  echo "$out_ps" | grep -q 'platform=windows' || fail ".ps1 未按预期运行：$out_ps"
  echo "$out_ps" | grep -q 'mcp-check' || fail ".ps1 渲染自检未输出：$out_ps"
  echo "$out_ps" | grep -qi 'definitely-not-a-real-command-xyz' || fail ".ps1 未检出缺失命令"
  ok ".ps1 渲染自检能检出缺失命令"
else
  out_sh=$(HOME="$FAKEHOME" sh "$ROOT/run_once_after_10-install-mcp-deps.sh" 2>&1 || true)
  echo "$out_sh" | grep -q 'platform=unix' || fail ".sh 未按预期运行：$out_sh"
  echo "$out_sh" | grep -q 'mcp-check' || fail ".sh 渲染自检未输出：$out_sh"
  echo "$out_sh" | grep -qi 'definitely-not-a-real-command-xyz' || fail ".sh 未检出缺失命令"
  ok ".sh 渲染自检能检出缺失命令"
fi

# ---------- run_once 的跨平台调度（真实 apply，验证 .chezmoiignore + 脚本执行）----------
step "run_once 跨平台调度：只执行本平台脚本"
DEST2="$WORK/dest-scripts"
mkdir -p "$DEST2"
DEST2_W=$(winpath "$DEST2")
out=$(chezmoi -c "$CFG_W" -S "$ROOT_W" -D "$DEST2_W" --persistent-state "$(winpath "$WORK/state2.boltdb")" --no-tty --force apply 2>&1 || true)
echo "$out" | sed 's/^/   /'
# 断言用 ASCII 平台标记（PowerShell 5.1 的输出走系统代码页，中文匹配不可靠）
if [ "$IS_WINDOWS" = 1 ]; then
  echo "$out" | grep -q 'platform=windows' || fail "Windows 上未执行 run_once .ps1"
  echo "$out" | grep -q 'platform=unix' && fail "Windows 上错误执行了 run_once .sh（.chezmoiignore 未生效）"
else
  echo "$out" | grep -q 'platform=unix' || fail "类 Unix 上未执行 run_once .sh"
  echo "$out" | grep -q 'platform=windows' && fail "类 Unix 上错误执行了 run_once .ps1（.chezmoiignore 未生效）"
fi
ok "run_once 只在本平台执行（.chezmoiignore 生效）"

# ---------- 收尾 ----------
step "清理"
rm -rf "$DEST2" "$FAKEHOME"
ok "临时目录已清理"

echo
echo "ACCEPTANCE PASS"
