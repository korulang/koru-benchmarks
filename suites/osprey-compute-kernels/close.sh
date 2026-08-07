#!/usr/bin/env bash
# close.sh <kernel> <bar> [rounds] — the mechanical perf closer for one kernel:
# is the Koru port within <bar>x of the C reference, on this machine, right now?
#
# Three layers, in order:
#   1. correctness gates entry — both binaries must match expected.txt, or
#      exit 1 before any clock starts (same discipline as bench.sh: a wrong
#      answer is not a result).
#   2. an identity control gates validity — scripts/perf_closer.py runs each
#      binary under two byte-identical labels, interleaved in one loop; the
#      twin spread is the noise floor of THIS run.
#   3. the ratio gate — the measured ratio's noise-honest interval against
#      the bar. Straddle -> REFUSED-TOO-NOISY (exit 3), not a guess.
#
# The bar is the claim under test and must be stated by the caller — there is
# no default, deliberately: a defaulted bar would be a hand-picked constant
# standing in for a decision nobody made.
#
# Exit: 0 PASS · 1 FAIL (or build/oracle failure) · 3 REFUSED (noise, or a
# live koru regression suite).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
KORUC="${KORUC:-$ROOT/../../../koru/zig-out/bin/koruc}"
NAME="${1:?usage: close.sh <kernel> <bar> [rounds]}"
BAR="${2:?usage: close.sh <kernel> <bar> [rounds] — the bar is the claim under test; state it}"
ROUNDS="${3:-40}"

[ -x "$KORUC" ] || { echo "koruc not found at $KORUC (build: cd ../koru && zig build)" >&2; exit 1; }
KDIR="$ROOT/koru/$NAME"
CDIR="$ROOT/reference/cases/$NAME"
[ -f "$KDIR/$NAME.k" ] || { echo "no koru port: $KDIR/$NAME.k" >&2; exit 1; }
[ -f "$CDIR/$NAME.c" ] || { echo "no C reference: $CDIR/$NAME.c" >&2; exit 1; }
ORACLE="$(tr -d '[:space:]' < "$KDIR/expected.txt")"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# -- layer 1: build + correctness, both sides, before any clock --
mkdir -p "$TMP/k"; cp "$KDIR/$NAME.k" "$TMP/k/"
# koruc clobbers its CWD — always build in the tmp dir.
( cd "$TMP/k" && "$KORUC" build "$NAME.k" >compile.log 2>&1 ) && [ -x "$TMP/k/a.out" ] \
  || { echo "koru build FAILED:"; grep -m1 -E 'error\[' "$TMP/k/compile.log" || tail -2 "$TMP/k/compile.log"; exit 1; } >&2
cc -O2 -o "$TMP/ref" "$CDIR/$NAME.c" || { echo "C reference build FAILED" >&2; exit 1; }
for side in "koru:$TMP/k/a.out" "c:$TMP/ref"; do
  got="$("${side#*:}" </dev/null 2>/dev/null | tr -d '[:space:]')"
  [ "$got" = "$ORACLE" ] || { echo "${side%%:*} WRONG ANSWER: got '$got' want '$ORACLE' — excluded from timing, closing FAILED" >&2; exit 1; }
done
echo "correctness: both match oracle '$ORACLE'"

# -- layers 2+3: the closer (identity floor + ratio gate, measured in-run) --
# no exec: the EXIT trap must still clean $TMP; the closer's exit code is ours.
python3 "$ROOT/../../scripts/perf_closer.py" \
  --candidate "$TMP/k/a.out" --reference "$TMP/ref" \
  --oracle "$ORACLE" --bar "$BAR" --rounds "$ROUNDS"
exit $?
