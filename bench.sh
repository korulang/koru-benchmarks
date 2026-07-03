#!/usr/bin/env bash
# Perf harness — times each Koru kernel that has a port, against the faithful
# reference implementations, under the SAME protocol Osprey's own harness uses:
#   * CPU: hyperfine -N --warmup 3 --min-runs 10 (statistical mean ± stddev)
#   * release flags: koruc build / cc -O2 / rustc -C opt-level=3 -C overflow-checks=off / ghc -O2
# Koru is compiled THROUGH koruc — this is the benchmark axis (run.sh is the
# correctness gate). Discipline: numbers are MEASURED on THIS machine only; a
# missing toolchain is reported ABSENT, never faked; a binary whose output does
# not match the oracle is EXCLUDED from timing (a wrong answer is not a result).
# No "beats/matches X" claim leaves this board unless re-verified under the
# target's exact rules on the same machine.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
KORUC="${KORUC:-$ROOT/../koru/zig-out/bin/koruc}"
SUITE="$ROOT/suites/osprey-compute-kernels"
WARMUP="${KORU_BENCH_WARMUP:-3}"
MINRUNS="${KORU_BENCH_MINRUNS:-10}"
FILTER="${1:-}"

command -v hyperfine >/dev/null 2>&1 || { echo "hyperfine not installed — required for timing." >&2; exit 2; }
[ -x "$KORUC" ] || { echo "koruc not found at $KORUC (build: cd ../koru && zig build)." >&2; exit 2; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
STDIN0="$TMP/mode0"; printf '0\n' > "$STDIN0"   # Osprey feeds a constant seed line; harmless for self-contained kernels

have() { command -v "$1" >/dev/null 2>&1; }
echo "Machine: $(uname -sm) · koruc: $KORUC"
printf 'Toolchains: koru=present  c=%s  rust=%s  haskell=%s  ocaml=%s  osprey=%s\n\n' \
  "$(have cc && echo present || echo ABSENT)" "$(have rustc && echo present || echo ABSENT)" \
  "$(have ghc && echo present || echo ABSENT)" "$(have ocamlopt && echo present || echo ABSENT)" "ABSENT"

# build_lang <lang> <name> <out>  -> 0 on success (binary at <out>), 1 otherwise
build_lang() {
  local lang="$1" name="$2" out="$3"
  local cdir="$SUITE/reference/cases/$name"
  case "$lang" in
    koru)
      local kdir="$SUITE/koru/$name"; [ -f "$kdir/$name.k" ] || return 1
      local w="$TMP/k_$name"; rm -rf "$w"; mkdir -p "$w"; cp "$kdir/$name.k" "$w/"
      ( cd "$w" && "$KORUC" build "$name.k" >/dev/null 2>&1 ) && [ -x "$w/a.out" ] && mv -f "$w/a.out" "$out" ;;
    c)       have cc     && [ -f "$cdir/$name.c" ]  && cc -O2 -o "$out" "$cdir/$name.c" 2>/dev/null ;;
    rust)    have rustc  && [ -f "$cdir/$name.rs" ] && rustc -C opt-level=3 -C overflow-checks=off -o "$out" "$cdir/$name.rs" 2>/dev/null ;;
    haskell) have ghc    && [ -f "$cdir/$name.hs" ] && ghc -O2 -outputdir "$TMP/hs_$name" -o "$out" "$cdir/$name.hs" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

LANGS=(koru c rust haskell)
printf '%-12s %10s %10s %10s %10s\n' kernel koru c rust haskell
printf '%-12s %10s %10s %10s %10s\n' "------" "----" "-" "----" "-------"

for kdir in "$SUITE"/koru/*/; do
  name="$(basename "$kdir")"
  [ -f "$kdir/$name.k" ] || continue
  [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]] && continue
  oracle="$(sed 's/[[:space:]]*$//' "$kdir/expected.txt")"

  declare -A ms=()
  for lang in "${LANGS[@]}"; do
    bin="$TMP/$name.$lang"
    if build_lang "$lang" "$name" "$bin"; then
      actual="$("$bin" <"$STDIN0" 2>/dev/null | tr -d '[:space:]')"
      if [ "$actual" = "$oracle" ]; then
        hyperfine -N --input "$STDIN0" --warmup "$WARMUP" --min-runs "$MINRUNS" \
          --export-json "$TMP/hf.json" "$bin" >/dev/null 2>&1 \
          && ms[$lang]="$(python3 -c 'import json,sys; print(f"{json.load(open(sys.argv[1]))[\"results\"][0][\"mean\"]*1000:.1f}")' "$TMP/hf.json" 2>/dev/null)" \
          || ms[$lang]="hf-err"
      else
        ms[$lang]="WRONG"   # built but wrong answer — excluded from timing
      fi
    else
      ms[$lang]="—"          # toolchain/source absent or build failed
    fi
  done
  printf '%-12s %10s %10s %10s %10s\n' "$name" \
    "${ms[koru]:-—}" "${ms[c]:-—}" "${ms[rust]:-—}" "${ms[haskell]:-—}"
  unset ms
done

echo
echo "Values are mean wall-clock milliseconds (hyperfine -N, warmup $WARMUP, min-runs $MINRUNS) on this machine."
echo "'—' = toolchain/source absent or build failed · 'WRONG' = built but failed the oracle (excluded)."
