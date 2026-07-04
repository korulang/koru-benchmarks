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
ROWS="$TMP/rows.tsv"; : > "$ROWS"               # kernel<TAB>lang<TAB>status<TAB>mean_ms<TAB>stddev_ms — feeds results/latest.json

have() { command -v "$1" >/dev/null 2>&1; }
OSPREY="${OSPREY:-$(command -v osprey || true)}"
echo "Machine: $(uname -sm) · koruc: $KORUC"
printf 'Toolchains: koru=present  c=%s  rust=%s  haskell=%s  ocaml=%s  osprey=%s\n\n' \
  "$(have cc && echo present || echo ABSENT)" "$(have rustc && echo present || echo ABSENT)" \
  "$(have ghc && echo present || echo ABSENT)" "$(have ocamlopt && echo present || echo ABSENT)" \
  "$([ -n "$OSPREY" ] && [ -x "$OSPREY" ] && echo present || echo ABSENT)"

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
    # ocaml/osprey build commands mirror the vendored reference/osprey_run.sh
    # exactly (their own harness's flags), compiled from a copy because both
    # litter artifacts beside the source.
    ocaml)
      have ocamlopt && [ -f "$cdir/$name.ml" ] || return 1
      local mw="$TMP/ml_$name"; rm -rf "$mw"; mkdir -p "$mw"; cp "$cdir/$name.ml" "$mw/"
      ( cd "$mw" && ocamlopt -O3 -unsafe -o "$out" "$name.ml" >/dev/null 2>&1 ) ;;
    osprey)
      [ -n "$OSPREY" ] && [ -x "$OSPREY" ] && [ -f "$cdir/$name.osp" ] || return 1
      local ow="$TMP/osp_$name"; rm -rf "$ow"; mkdir -p "$ow"; cp "$cdir/$name.osp" "$ow/"
      ( cd "$ow" && "$OSPREY" "$name.osp" --compile >/dev/null 2>&1 ) && [ -x "$ow/$name" ] && mv -f "$ow/$name" "$out" ;;
    *) return 1 ;;
  esac
}

LANGS=(koru c rust haskell ocaml osprey)
printf '%-12s %10s %10s %10s %10s %10s %10s\n' kernel koru c rust haskell ocaml osprey
printf '%-12s %10s %10s %10s %10s %10s %10s\n' "------" "----" "-" "----" "-------" "-----" "------"

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
        if hyperfine -N --input "$STDIN0" --warmup "$WARMUP" --min-runs "$MINRUNS" \
             --export-json "$TMP/hf.json" "$bin" >/dev/null 2>&1; then
          mean_ms=""; std_ms=""
          read -r mean_ms std_ms < <(python3 -c 'import json,sys; r=json.load(open(sys.argv[1]))["results"][0]; print("%.2f %.2f" % (r["mean"]*1000, r["stddev"]*1000))' "$TMP/hf.json" 2>/dev/null) || true
          if [ -n "${mean_ms:-}" ]; then
            ms[$lang]="$(printf '%.1f' "$mean_ms")"
            printf '%s\t%s\tmeasured\t%s\t%s\n' "$name" "$lang" "$mean_ms" "$std_ms" >> "$ROWS"
          else
            ms[$lang]="hf-err"; printf '%s\t%s\therror\t\t\n' "$name" "$lang" >> "$ROWS"
          fi
        else
          ms[$lang]="hf-err"; printf '%s\t%s\therror\t\t\n' "$name" "$lang" >> "$ROWS"
        fi
      else
        ms[$lang]="WRONG"   # built but wrong answer — excluded from timing
        printf '%s\t%s\twrong\t\t\n' "$name" "$lang" >> "$ROWS"
      fi
    else
      ms[$lang]="—"          # toolchain/source absent or build failed
      printf '%s\t%s\tabsent\t\t\n' "$name" "$lang" >> "$ROWS"
    fi
  done
  printf '%-12s %10s %10s %10s %10s %10s %10s\n' "$name" \
    "${ms[koru]:-—}" "${ms[c]:-—}" "${ms[rust]:-—}" "${ms[haskell]:-—}" "${ms[ocaml]:-—}" "${ms[osprey]:-—}"
  unset ms
done

echo
echo "Values are mean wall-clock milliseconds (hyperfine -N, warmup $WARMUP, min-runs $MINRUNS) on this machine."
echo "'—' = toolchain/source absent or build failed · 'WRONG' = built but failed the oracle (excluded)."

# Persist the board as a provenance-carrying artifact (results/latest.json).
# Only a FULL run writes it — a filtered run is a partial board and must never
# masquerade as the whole one.
if [ -z "$FILTER" ]; then
  cpu=""
  case "$(uname -s)" in
    Darwin) cpu="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || true)" ;;
    Linux)  cpu="$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ //' || true)" ;;
  esac
  koru_repo="$(cd "$(dirname "$KORUC")/../.." 2>/dev/null && pwd)"
  koru_commit="$(git -C "$koru_repo" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  koru_dirty="$(git -C "$koru_repo" status --porcelain 2>/dev/null | grep -q . && echo true || echo false)"
  mkdir -p "$ROOT/results"
  ROWS_FILE="$ROWS" OUT_FILE="$ROOT/results/latest.json" \
  GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)" OS="$(uname -s)" ARCH="$(uname -m)" CPU="$cpu" \
  KORU_COMMIT="$koru_commit" KORU_DIRTY="$koru_dirty" WARMUP="$WARMUP" MINRUNS="$MINRUNS" \
  CC_VERSION="$(cc --version 2>/dev/null | head -1 || echo ABSENT)" \
  RUSTC_VERSION="$(rustc --version 2>/dev/null || echo ABSENT)" \
  GHC_VERSION="$(ghc --numeric-version 2>/dev/null | sed 's/^/ghc /' || echo ABSENT)" \
  OCAML_VERSION="$(ocamlopt -version 2>/dev/null | sed 's/^/ocamlopt /' || echo ABSENT)" \
  OSPREY_VERSION="$([ -n "$OSPREY" ] && [ -x "$OSPREY" ] && ("$OSPREY" --version 2>/dev/null | head -1 || echo "osprey (version unknown)") || echo ABSENT)" \
  python3 - <<'PYEOF'
import json, os

rows = {}
langs_seen = []
for line in open(os.environ["ROWS_FILE"]):
    parts = line.rstrip("\n").split("\t")
    kernel, lang, status, mean, std = (parts + ["", ""])[:5]
    cell = {"status": status}
    if status == "measured":
        cell["mean_ms"] = float(mean)
        cell["stddev_ms"] = float(std)
    rows.setdefault(kernel, {})[lang] = cell
    if lang not in langs_seen:
        langs_seen.append(lang)

out = {
    "suite": "osprey-compute-kernels",
    "generated_at": os.environ["GENERATED_AT"],
    "machine": {"os": os.environ["OS"], "arch": os.environ["ARCH"], "cpu": os.environ["CPU"]},
    "koru": {"commit": os.environ["KORU_COMMIT"], "dirty": os.environ["KORU_DIRTY"] == "true"},
    "protocol": {
        "tool": "hyperfine -N",
        "warmup": int(os.environ["WARMUP"]),
        "min_runs": int(os.environ["MINRUNS"]),
        "flags": {
            "koru": "koruc build (ReleaseFast)",
            "c": "cc -O2",
            "rust": "rustc -C opt-level=3 -C overflow-checks=off",
            "haskell": "ghc -O2",
            "ocaml": "ocamlopt -O3 -unsafe",
            "osprey": "osprey --compile (release)",
        },
    },
    "toolchains": {
        "c": os.environ["CC_VERSION"],
        "rust": os.environ["RUSTC_VERSION"],
        "haskell": os.environ["GHC_VERSION"],
        "ocaml": os.environ["OCAML_VERSION"],
        "osprey": os.environ["OSPREY_VERSION"],
    },
    "discipline": "MEASURED on the machine named above, not a quiesced rig. Wrong-answer binaries are excluded from timing. Absent toolchains are reported absent, never estimated. No cross-language claim leaves this board unless re-verified under the target's exact rules.",
    "langs": langs_seen,
    "kernels": rows,
}
with open(os.environ["OUT_FILE"], "w") as f:
    json.dump(out, f, indent=2)
    f.write("\n")
print(f"\nBoard persisted: {os.environ['OUT_FILE']}")
PYEOF
fi
