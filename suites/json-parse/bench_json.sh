#!/usr/bin/env bash
# json-parse suite driver. Protocol symmetry is the whole game: every
# contender reads the SAME file and runs the SAME in-process 3-second
# timed-pass loop, printing "passes=<n> seconds=<s>". Categories differ and
# are labeled — recognizer (Koru), token validation (zig_scan), full tree
# (zig_tree, py_loads) — so lanes are visible in the output, and no
# cross-category verdict is ever printed by this script.
#
# The Koru entry is compiled THROUGH koruc (sibling checkout convention).
# Timing refuses to run while a koru full-suite sweep is active machine-wide.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
KORUC="${KORUC:-$ROOT/../../../koru/zig-out/bin/koruc}"
DOC="$ROOT/data/doc.json"

[ -x "$KORUC" ] || { echo "koruc not found at $KORUC" >&2; exit 2; }
if pgrep -f 'run_regression.sh --no-cache' >/dev/null 2>&1; then
  echo "REFUSING to time: a koru full-suite sweep is running (numbers would be noise)." >&2
  exit 3
fi

echo "== build (koruc, sibling checkout) =="
( cd "$ROOT/koru" && "$KORUC" build bench.k >/dev/null 2>&1 ) || { echo "koruc build FAILED" >&2; exit 1; }
( cd "$ROOT/baseline" && zig build-exe -O ReleaseFast zig_scan.zig >/dev/null 2>&1 && zig build-exe -O ReleaseFast zig_tree.zig >/dev/null 2>&1 ) || { echo "zig baseline build FAILED" >&2; exit 1; }

echo "== correctness gates =="
# Reject gate: a corrupted doc must produce PARSE-ERROR from the recognizer.
sed 's/}$/,/' "$DOC" > "$ROOT/data/corrupt.json"
first="$( (timeout 5 "$ROOT/koru/a.out" "$ROOT/data/corrupt.json" 2>/dev/null || true) | head -1 )"
case "$first" in
  PARSE-ERROR*) echo "  reject gate: OK ($first)";;
  *) echo "  reject gate FAILED: got '$first'" >&2; exit 1;;
esac
# Accept gate: the doc is valid by construction (json.dumps); python re-checks.
python3 -c "import json,sys; json.load(open('$DOC')); print('  accept gate: OK (python cross-check)')" || exit 1

echo "== timed passes (3s each, same doc: $(wc -c < "$DOC") bytes) =="
bytes=$(wc -c < "$DOC")
run_one() {
  local label="$1" category="$2"; shift 2
  local out; out="$("$@" "$DOC" 2>&1 | grep -E "^passes=" | head -1)"
  local passes secs; passes="${out#passes=}"; passes="${passes%% *}"
  secs="$(echo "$out" | sed 's/.*seconds=\([0-9.]*\).*/\1/')"
  local mbs; mbs="$(python3 -c "print(f'{$passes * $bytes / $secs / 1e6:.1f}')")"
  printf "  %-22s %-18s passes=%-8s %.6ss  %s MB/s\n" "$label" "[$category]" "$passes" "$secs" "$mbs"
}
run_one "koru std/parser" "recognizer" "$ROOT/koru/a.out"
run_one "zig std.json.Scanner" "validate-tokens" "$ROOT/baseline/zig_scan"
run_one "zig std.json Value" "full-tree" "$ROOT/baseline/zig_tree"
run_one "python json.loads" "full-tree" python3 "$ROOT/baseline/py_loads.py"
echo
echo "Categories are lanes, not a ranking: recognizer < validate-tokens < full-tree in work done."
echo "Numbers are MEASURED on this machine under this suite's own protocol only."
