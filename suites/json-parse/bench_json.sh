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
CONTENDERS="$ROOT/contenders"
DOC="$ROOT/data/doc.json"

[ -x "$KORUC" ] || { echo "koruc not found at $KORUC" >&2; exit 2; }
if pgrep -f 'run_regression.sh --no-cache' >/dev/null 2>&1; then
  echo "REFUSING to time: a koru full-suite sweep is running (numbers would be noise)." >&2
  exit 3
fi

echo "== build (koruc, sibling checkout) =="
( cd "$ROOT/koru" && "$KORUC" build bench.k >/dev/null 2>&1 ) || { echo "koruc build FAILED" >&2; exit 1; }
( cd "$ROOT/baseline" && zig build-exe -O ReleaseFast zig_scan.zig >/dev/null 2>&1 && zig build-exe -O ReleaseFast zig_tree.zig >/dev/null 2>&1 && zig build-exe -O ReleaseFast zig_recognize.zig >/dev/null 2>&1 ) || { echo "zig baseline build FAILED" >&2; exit 1; }

echo "== build contenders (general-library peers) =="
# Haskell parsec — the canonical parser-combinator library; koru's truest peer.
if command -v ghc >/dev/null 2>&1; then
  ( cd "$CONTENDERS/parsec" && ghc -O2 -package parsec -package time -package deepseq -package bytestring json_parsec.hs -o json_parsec >/dev/null 2>&1 ) || { echo "haskell parsec build FAILED" >&2; exit 1; }
  HAVE_PARSEC=1
else
  echo "  (skip parsec: ghc not found)"; HAVE_PARSEC=0
fi
# Rust: nom (general-library combinator peer, recognizer lane) + serde_json
# (specialized deserializer, full-tree lane) — one crate, two bins.
if command -v cargo >/dev/null 2>&1; then
  ( cd "$CONTENDERS/rust" && cargo build --release >/dev/null 2>&1 ) || { echo "rust contenders build FAILED" >&2; exit 1; }
  HAVE_RUST=1
else
  echo "  (skip nom/serde: cargo not found)"; HAVE_RUST=0
fi
# Haskell megaparsec — parsec's modern successor; built via nix-shell (the GHC
# here is nix-managed and megaparsec isn't in the global pkg db).
if command -v nix-shell >/dev/null 2>&1; then
  ( cd "$CONTENDERS/megaparsec" && nix-shell -p "haskellPackages.ghcWithPackages (p: [p.megaparsec])" --run 'ghc -O2 json_megaparsec.hs -o json_megaparsec' >/dev/null 2>&1 ) || { echo "haskell megaparsec build FAILED" >&2; exit 1; }
  HAVE_MEGA=1
else
  echo "  (skip megaparsec: nix-shell not found)"; HAVE_MEGA=0
fi
# FParsec (F#/.NET) — Release config = optimizations on (the .NET -O2 equiv).
# Probe that the runtime actually RUNS, not just that the binary is on PATH — a
# broken/outdated .NET SDK must SKIP the contender, not abort the whole board.
if command -v dotnet >/dev/null 2>&1 && dotnet --version >/dev/null 2>&1; then
  ( cd "$CONTENDERS/fparsec" && dotnet build -c Release >/dev/null 2>&1 ) || { echo "fparsec build FAILED" >&2; exit 1; }
  HAVE_FPARSEC=1
else
  echo "  (skip fparsec: dotnet not found)"; HAVE_FPARSEC=0
fi
FPARSEC_DLL="$CONTENDERS/fparsec/bin/Release/net8.0/fparsec_bench.dll"
# Runtime smoke test: a present SDK (dotnet build succeeds) does NOT guarantee the
# net8.0 RUNTIME is installed. If the built DLL can't actually launch, skip
# fparsec rather than aborting the whole board on its reject gate.
if [ "${HAVE_FPARSEC:-0}" = "1" ] && ! dotnet "$FPARSEC_DLL" "$DOC" >/dev/null 2>&1; then
  echo "  (skip fparsec: .NET runtime cannot launch the built app)"; HAVE_FPARSEC=0
fi
# koru std/parser -> C backend: lower the SAME grammar as the koru entry
# (contenders/koru_c/json.k == koru/bench.k's grammar) to a standalone C parser
# via `koruc json.k parser:generate c`, then cc it with the in-process bench
# harness. Capability-probed: skipped unless this koruc knows the
# `parser:generate` command (it lives on the parser-generate-c branch until
# merged to main). Same lane + category as the koru entry — Zig-vs-C codegen of
# one library's output.
if ( cd "$CONTENDERS/koru_c" && rm -f json.c && "$KORUC" json.k parser:generate c >/dev/null 2>&1 && [ -f json.c ] && cc -O2 -Wall bench_main.c -o json_c_recognize >/dev/null 2>&1 ); then
  HAVE_KORU_C=1
else
  echo "  (skip koru_c: koruc lacks parser:generate, or cc failed)"; HAVE_KORU_C=0
fi

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
if [ "${HAVE_PARSEC:-0}" = "1" ]; then
  # Both parsec lanes must reject the corrupt doc.
  for lane in recognize build; do
    pfirst="$( "$CONTENDERS/parsec/json_parsec" "$lane" "$ROOT/data/corrupt.json" 2>&1 | head -1 )"
    case "$pfirst" in
      INVALID*) echo "  reject gate (parsec/$lane): OK";;
      *) echo "  reject gate (parsec/$lane) FAILED: got '$pfirst'" >&2; exit 1;;
    esac
  done
fi
if [ "${HAVE_RUST:-0}" = "1" ]; then
  for b in nom_recognize serde_build; do
    bfirst="$( "$CONTENDERS/rust/target/release/$b" "$ROOT/data/corrupt.json" 2>&1 | head -1 )"
    case "$bfirst" in
      INVALID*) echo "  reject gate ($b): OK";;
      *) echo "  reject gate ($b) FAILED: got '$bfirst'" >&2; exit 1;;
    esac
  done
fi
if [ "${HAVE_MEGA:-0}" = "1" ]; then
  mfirst="$( "$CONTENDERS/megaparsec/json_megaparsec" "$ROOT/data/corrupt.json" 2>&1 | head -1 )"
  case "$mfirst" in
    INVALID*) echo "  reject gate (megaparsec): OK";;
    *) echo "  reject gate (megaparsec) FAILED: got '$mfirst'" >&2; exit 1;;
  esac
fi
if [ "${HAVE_FPARSEC:-0}" = "1" ]; then
  ffirst="$( dotnet "$FPARSEC_DLL" "$ROOT/data/corrupt.json" 2>&1 | head -1 )"
  case "$ffirst" in
    INVALID*) echo "  reject gate (fparsec): OK";;
    *) echo "  reject gate (fparsec) FAILED: got '$ffirst'" >&2; exit 1;;
  esac
fi
if [ "${HAVE_KORU_C:-0}" = "1" ]; then
  cfirst="$( "$CONTENDERS/koru_c/json_c_recognize" "$ROOT/data/corrupt.json" 2>&1 | head -1 )"
  case "$cfirst" in
    INVALID*) echo "  reject gate (koru_c): OK";;
    *) echo "  reject gate (koru_c) FAILED: got '$cfirst'" >&2; exit 1;;
  esac
fi
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
# run_one <label> <lane> <category> <cmd...>. Two discipline axes are printed:
#   lane     = WORK DONE (recognizer < validate-tokens < full-tree)
#   category = general-library (a reusable parser lib: koru, parsec, nom,
#              FParsec) vs specialized (a bespoke/JSON-specific deserializer:
#              the zig rivals, python, serde). A fair peer story is
#              general-vs-general in the SAME lane; never a naked cross-category
#              "we beat X".
run_one() {
  local label="$1" lane="$2" cat="$3"; shift 3
  local best_mbs="0" best_passes="" best_secs="" all=""
  for rep in 1 2 3; do
    local out; out="$("$@" "$DOC" 2>&1 | grep -E "^passes=" | head -1)"
    local passes secs; passes="${out#passes=}"; passes="${passes%% *}"
    secs="$(echo "$out" | sed 's/.*seconds=\([0-9.]*\).*/\1/')"
    local mbs; mbs="$(python3 -c "print(f'{$passes * $bytes / $secs / 1e6:.1f}')")"
    all="$all $mbs"
    if python3 -c "exit(0 if $mbs > $best_mbs else 1)"; then best_mbs="$mbs"; best_passes="$passes"; best_secs="$secs"; fi
  done
  printf "  %-22s %-17s %-13s passes=%-8s best %8s MB/s  (reps:%s)\n" "$label" "[$lane]" "$cat" "$best_passes" "$best_mbs" "$all"
}
echo "-- recognizer lane --"
run_one "koru std/parser"      "recognizer"      "general-lib" "$ROOT/koru/a.out"
[ "${HAVE_KORU_C:-0}" = "1" ] && \
run_one "koru std/parser -> C" "recognizer"      "general-lib" "$CONTENDERS/koru_c/json_c_recognize"
[ "${HAVE_PARSEC:-0}" = "1" ] && \
run_one "haskell parsec"       "recognizer"      "general-lib" "$CONTENDERS/parsec/json_parsec" recognize
[ "${HAVE_RUST:-0}" = "1" ] && \
run_one "rust nom"             "recognizer"      "general-lib" "$CONTENDERS/rust/target/release/nom_recognize"
[ "${HAVE_FPARSEC:-0}" = "1" ] && \
run_one "fparsec (F#/.NET)"    "recognizer"      "general-lib" dotnet "$FPARSEC_DLL"
[ "${HAVE_MEGA:-0}" = "1" ] && \
run_one "haskell megaparsec"   "recognizer"      "general-lib" "$CONTENDERS/megaparsec/json_megaparsec"
run_one "zig hand-rolled"      "recognizer"      "specialized" "$ROOT/baseline/zig_recognize"
echo "-- validate-tokens lane --"
run_one "zig std.json.Scanner" "validate-tokens" "specialized" "$ROOT/baseline/zig_scan"
echo "-- full-tree lane --"
[ "${HAVE_PARSEC:-0}" = "1" ] && \
run_one "haskell parsec"       "full-tree"       "general-lib" "$CONTENDERS/parsec/json_parsec" build
[ "${HAVE_RUST:-0}" = "1" ] && \
run_one "rust serde_json"      "full-tree"       "specialized" "$CONTENDERS/rust/target/release/serde_build"
run_one "zig std.json Value"   "full-tree"       "specialized" "$ROOT/baseline/zig_tree"
run_one "python json.loads"    "full-tree"       "specialized" python3 "$ROOT/baseline/py_loads.py"
echo
echo "Lanes are work done, not a ranking: recognizer < validate-tokens < full-tree."
echo "Category (general-lib vs specialized) is the peer axis: koru's true peers are the"
echo "general-library parser combinators (parsec, nom, FParsec), matched within a lane."
echo "Numbers are MEASURED on this machine under this suite's own protocol only."
