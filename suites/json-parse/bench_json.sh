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
( cd "$ROOT/baseline" && zig build-exe -O ReleaseFast zig_scan.zig >/dev/null 2>&1 && zig build-exe -O ReleaseFast zig_tree.zig >/dev/null 2>&1 && zig build-exe -O ReleaseFast zig_recognize.zig >/dev/null 2>&1 ) || { echo "zig baseline build FAILED" >&2; exit 1; }

echo "== correctness gates =="
# Reject gate: a corrupted doc must produce PARSE-ERROR from the recognizer.
sed 's/}$/,/' "$DOC" > "$ROOT/data/corrupt.json"
first="$( (timeout 5 "$ROOT/koru/a.out" "$ROOT/data/corrupt.json" 2>/dev/null || true) | head -1 )"
case "$first" in
  PARSE-ERROR*) echo "  reject gate: OK ($first)";;
  *) echo "  reject gate FAILED: got '$first'" >&2; exit 1;;
esac
rfirst="$( "$ROOT/baseline/zig_recognize" "$ROOT/data/corrupt.json" 2>&1 | head -1 )"
case "$rfirst" in
  INVALID*) echo "  reject gate (zig_recognize): OK";;
  *) echo "  reject gate (zig_recognize) FAILED: got '$rfirst'" >&2; exit 1;;
esac
# Accept gate: the doc is valid by construction (json.dumps); python re-checks.
python3 -c "import json,sys; json.load(open('$DOC')); print('  accept gate: OK (python cross-check)')" || exit 1
# Cliff gate: right-nested and left-nested twins (111 bytes, depth 24) must
# parse within 10x of each other. Before common-head factoring the right
# twin was ~450,000x slower (exponential last-element reparse); this gate
# pins that cliff closed.
rp="$( "$ROOT/koru/a.out" "$ROOT/data/right24.json" | head -1 | sed 's/passes=\([0-9]*\).*/\1/' )"
lp="$( "$ROOT/koru/a.out" "$ROOT/data/left24.json"  | head -1 | sed 's/passes=\([0-9]*\).*/\1/' )"
if python3 -c "exit(0 if $rp * 10 >= $lp else 1)"; then
  echo "  cliff gate: OK (right=$rp left=$lp passes)"
else
  echo "  cliff gate FAILED: right=$rp vs left=$lp — exponential reparse is back" >&2; exit 1
fi

echo "== timed passes (3s each, same doc: $(wc -c < "$DOC") bytes) =="
bytes=$(wc -c < "$DOC")
# 3 repetitions, report the BEST (max-throughput) rep — the standard
# microbench answer to scheduler noise — plus the spread across reps.
run_one() {
  local label="$1" category="$2"; shift 2
  local best_mbs="0" best_passes="" best_secs="" all=""
  for rep in 1 2 3; do
    local out; out="$("$@" "$DOC" 2>&1 | grep -E "^passes=" | head -1)"
    local passes secs; passes="${out#passes=}"; passes="${passes%% *}"
    secs="$(echo "$out" | sed 's/.*seconds=\([0-9.]*\).*/\1/')"
    local mbs; mbs="$(python3 -c "print(f'{$passes * $bytes / $secs / 1e6:.1f}')")"
    all="$all $mbs"
    if python3 -c "exit(0 if $mbs > $best_mbs else 1)"; then best_mbs="$mbs"; best_passes="$passes"; best_secs="$secs"; fi
  done
  printf "  %-22s %-18s passes=%-8s best %s MB/s   (reps:%s)\n" "$label" "[$category]" "$best_passes" "$best_mbs" "$all"
}
run_one "koru std/parser" "recognizer" "$ROOT/koru/a.out"
run_one "zig hand-rolled" "recognizer" "$ROOT/baseline/zig_recognize"
run_one "zig std.json.Scanner" "validate-tokens" "$ROOT/baseline/zig_scan"
run_one "zig std.json Value" "full-tree" "$ROOT/baseline/zig_tree"
run_one "python json.loads" "full-tree" python3 "$ROOT/baseline/py_loads.py"
echo
echo "Categories are lanes, not a ranking: recognizer < validate-tokens < full-tree in work done."
echo "Numbers are MEASURED on this machine under this suite's own protocol only."
