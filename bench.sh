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
# A real GCC, not Apple's clang answering to the name "gcc" — the column is
# labeled gcc, so on a machine where `gcc` is clang the honest answer is ABSENT.
gcc_ok() { have gcc && ! gcc --version 2>/dev/null | grep -qi clang; }
clang_ok() { have clang && clang --version 2>/dev/null | grep -qi clang; }
# Prefer an explicit OSPREY, then a sibling checkout (same convention as koruc),
# then PATH. Homebrew's bottle currently ships a binary that cannot link the
# C runtime outside the formula's layout — sibling `make build` is the honest path.
if [ -z "${OSPREY:-}" ]; then
  if [ -x "$ROOT/../osprey/target/release/osprey" ]; then
    OSPREY="$ROOT/../osprey/target/release/osprey"
  else
    OSPREY="$(command -v osprey || true)"
  fi
fi
# Mojo builds through the pixi env in the sibling modular checkout (same
# convention as ../koru for koruc); MOJO_MANIFEST overrides the manifest path.
PIXI="$(command -v pixi || echo "$HOME/.pixi/bin/pixi")"
MOJO_MANIFEST="${MOJO_MANIFEST:-$ROOT/../modular/Mojo/pixi.toml}"
mojo_ok() { [ -x "$PIXI" ] && [ -f "$MOJO_MANIFEST" ]; }
# Bend 2 installs a self-updating launcher under ~/.bend (its documented
# installer); BEND env overrides. BEND_NO_TELEMETRY silences its per-run ping.
if [ -z "${BEND:-}" ]; then
  if [ -x "$HOME/.bend/bin/bend" ]; then
    BEND="$HOME/.bend/bin/bend"
  else
    BEND="$(command -v bend || true)"
  fi
fi
bend_ok() { [ -n "$BEND" ] && [ -x "$BEND" ]; }
bend_version() {
  bend_ok || { echo ABSENT; return; }
  local out rc clean version
  out="$(BEND_NO_TELEMETRY=1 "$BEND" version 2>/dev/null)"; rc=$?
  if [ "$rc" -ne 0 ]; then
    out="$(BEND_NO_TELEMETRY=1 "$BEND" --version 2>/dev/null)"; rc=$?
  fi
  [ "$rc" -eq 0 ] || { echo "bend (version probe failed)"; return; }
  clean="$(printf '%s\n' "$out" | tr -d '\033' | sed 's/\[[0-9;]*m//g')"
  version="$(printf '%s\n' "$clean" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  if [ -n "$version" ]; then
    echo "bend $version"
  else
    echo "bend (version unparsed: $(printf '%s\n' "$clean" | head -1))"
  fi
}

echo "Machine: $(uname -sm) · koruc: $KORUC"
printf 'Toolchains: koru=present  c=%s  cgcc3=%s  cclang=%s  cmap=%s  carena=%s  rust=%s  haskell=%s  ocaml=%s  osprey=%s  c3=%s  odin=%s  mojo=%s  bend=%s\n\n' \
  "$(have cc && echo present || echo ABSENT)" "$(gcc_ok && echo present || echo ABSENT)" \
  "$(clang_ok && echo present || echo ABSENT)" "$(have cc && echo present || echo ABSENT)" "$(have cc && echo present || echo ABSENT)" \
  "$(have rustc && echo present || echo ABSENT)" "$(have ghc && echo present || echo ABSENT)" \
  "$(have ocamlopt && echo present || echo ABSENT)" "$([ -n "$OSPREY" ] && [ -x "$OSPREY" ] && echo present || echo ABSENT)" \
  "$(command -v c3c >/dev/null 2>&1 || [ -x "$HOME/src/c3/c3c" ] && echo present || echo ABSENT)" \
  "$(command -v odin >/dev/null 2>&1 || [ -x "$HOME/src/odin/odin" ] && echo present || echo ABSENT)" \
  "$(mojo_ok && echo present || echo ABSENT)" "$(bend_ok && echo present || echo ABSENT)"

# build_lang <lang> <name> <out>  -> 0 on success (binary at <out>), 1 otherwise
build_lang() {
  local lang="$1" name="$2" out="$3"
  local cdir="$SUITE/reference/cases/$name"
  case "$lang" in
    koru)
      local kdir="$SUITE/koru/$name"; local ksrc=""
      [ -f "$kdir/$name.kz" ] && ksrc="$name.kz"; [ -f "$kdir/$name.k" ] && ksrc="$name.k"
      [ -n "$ksrc" ] || return 1
      local w="$TMP/k_$name"; rm -rf "$w"; mkdir -p "$w"; cp "$kdir/$ksrc" "$w/"
      ( cd "$w" && "$KORUC" build --release=fast "$ksrc" >/dev/null 2>&1 ) && [ -x "$w/a.out" ] && mv -f "$w/a.out" "$out" ;;
    koru-fold)
      local kdir="$SUITE/koru-fold/$name"; [ -f "$kdir/$name.k" ] || return 1
      local w="$TMP/kf_$name"; rm -rf "$w"; mkdir -p "$w"; cp "$kdir/$name.k" "$w/"
      ( cd "$w" && "$KORUC" build --release=fast "$name.k" >/dev/null 2>&1 ) && [ -x "$w/a.out" ] && mv -f "$w/a.out" "$out" ;;
    koru-par)
      local kdir="$SUITE/koru-par/$name"; local ksrc=""
      [ -f "$kdir/$name.kz" ] && ksrc="$name.kz"; [ -f "$kdir/$name.k" ] && ksrc="$name.k"
      [ -n "$ksrc" ] || return 1
      local w="$TMP/kp_$name"; rm -rf "$w"; mkdir -p "$w"; cp "$kdir/$ksrc" "$w/"
      ( cd "$w" && "$KORUC" build --release=fast "$ksrc" >/dev/null 2>&1 ) && [ -x "$w/a.out" ] && mv -f "$w/a.out" "$out" ;;
    c)       have cc     && [ -f "$cdir/$name.c" ]  && cc -O2 -o "$out" "$cdir/$name.c" 2>/dev/null ;;
    # Max-opt columns matching koruc ReleaseFast / rustc opt-level=3 —
    # all at baseline ISA (no -march=native) to match what the rest emit.
    cgcc3)   gcc_ok      && [ -f "$cdir/$name.c" ]  && gcc -O3 -o "$out" "$cdir/$name.c" 2>/dev/null ;;
    cclang)  clang_ok    && [ -f "$cdir/$name.c" ]  && clang -O3 -o "$out" "$cdir/$name.c" 2>/dev/null ;;
    cmap)     [ -f "$cdir/$name.map.c" ] && cc -O2 -o "$out" "$cdir/$name.map.c" 2>/dev/null ;;
    carena)   [ -f "$cdir/${name}_arena.c" ] && cc -O2 -o "$out" "$cdir/${name}_arena.c" 2>/dev/null ;;
    rust)    have rustc  && [ -f "$cdir/$name.rs" ] && rustc -C opt-level=3 -C overflow-checks=off -o "$out" "$cdir/$name.rs" 2>/dev/null ;;
    haskell) have ghc    && [ -f "$cdir/$name.hs" ] && ghc -O2 -outputdir "$TMP/hs_$name" -o "$out" "$cdir/$name.hs" >/dev/null 2>&1 ;;
    # ocaml/osprey build commands mirror the vendored reference/osprey_run.sh
    # exactly (their own harness's flags), compiled from a copy because both
    # litter artifacts beside the source.
    c3)      C3C=$(command -v c3c || echo "$HOME/src/c3/c3c")
             [ -f "$cdir/$name.c3" ] && ( cd "$TMP" && "$C3C" compile "$cdir/$name.c3" -O5 -o "$out" >/dev/null 2>&1 ) ;;
    odin)    ODIN=$(command -v odin || echo "$HOME/src/odin/odin")
             [ -f "$cdir/$name.odin" ] && ( "$ODIN" build "$cdir/$name.odin" -file -o:speed -out:"$out" >/dev/null 2>&1 ) ;;
    mojo)    mojo_ok && [ -f "$cdir/$name.mojo" ] && \
             ( "$PIXI" run --manifest-path "$MOJO_MANIFEST" mojo build "$cdir/$name.mojo" -o "$out" >/dev/null 2>&1 ) ;;
    ocaml)
      have ocamlopt && [ -f "$cdir/$name.ml" ] || return 1
      local mw="$TMP/ml_$name"; rm -rf "$mw"; mkdir -p "$mw"; cp "$cdir/$name.ml" "$mw/"
      ( cd "$mw" && ocamlopt -O3 -unsafe -o "$out" "$name.ml" >/dev/null 2>&1 ) ;;
    osprey)
      [ -n "$OSPREY" ] && [ -x "$OSPREY" ] && [ -f "$cdir/$name.osp" ] || return 1
      local ow="$TMP/osp_$name"; rm -rf "$ow"; mkdir -p "$ow"; cp "$cdir/$name.osp" "$ow/"
      ( cd "$ow" && "$OSPREY" "$name.osp" --compile >/dev/null 2>&1 ) && [ -x "$ow/$name" ] && mv -f "$ow/$name" "$out" ;;
    bend)
      bend_ok && [ -f "$SUITE/bend/$name/$name.bend" ] || return 1
      local bw="$TMP/b_$name"; rm -rf "$bw"; mkdir -p "$bw"; cp "$SUITE/bend/$name/$name.bend" "$bw/"
      ( cd "$bw" && BEND_NO_TELEMETRY=1 "$BEND" "$name.bend" -o "$name" >/dev/null 2>&1 ) && [ -x "$bw/$name" ] && mv -f "$bw/$name" "$out" ;;
    bend-par)
      bend_ok && [ -f "$SUITE/bend-par/$name/$name.bend" ] || return 1
      local bw="$TMP/bp_$name"; rm -rf "$bw"; mkdir -p "$bw"; cp "$SUITE/bend-par/$name/$name.bend" "$bw/"
      ( cd "$bw" && BEND_NO_TELEMETRY=1 "$BEND" "$name.bend" -o "$name" >/dev/null 2>&1 ) && [ -x "$bw/$name" ] && mv -f "$bw/$name" "$out" ;;
    *) return 1 ;;
  esac
}

LANGS=(koru koru-fold koru-par c cgcc3 cclang cmap carena rust haskell ocaml osprey c3 odin mojo bend bend-par)
# Compiled-contender field — only these are built and timed; blowout
# languages are never invoked. Everything else in LANGS still gets a column
# but reports NOT-RUN, distinguishable from ABSENT (an in-field toolchain
# that is missing). KORU_BENCH_FIELD="a b c" overrides the field.
FIELD=( ${KORU_BENCH_FIELD:-koru koru-fold koru-par c cmap carena cgcc3 cclang rust osprey bend} )
in_field() { local f; for f in "${FIELD[@]}"; do [ "$f" = "$1" ] && return 0; done; return 1; }
printf '%-12s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s\n' kernel koru koru-f koru-p c gcc3 clang cmap c-arena rust haskell ocaml osprey c3 odin mojo bend bend-p
printf '%-12s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s\n' "------" "----" "-----" "------" "-" "----" "-----" "----" "----" "-------" "-----" "------" "--" "----" "----" "----" "------"

# The board is driven by reference/cases (the complete 22-kernel list), not by
# the koru/ ports — a kernel Koru can't express yet must still show its row so
# the other columns report what the gap costs.
for casedir in "$SUITE"/reference/cases/*/; do
  name="$(basename "$casedir")"
  [ -f "$casedir/expected.txt" ] || continue
  [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]] && continue
  oracle="$(sed 's/[[:space:]]*$//' "$casedir/expected.txt")"

  declare -A ms=()
  for lang in "${LANGS[@]}"; do
    if ! in_field "$lang"; then
      ms[$lang]="NOT-RUN"
      printf '%s\t%s\tnot-run\t\t\n' "$name" "$lang" >> "$ROWS"
      continue
    fi
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
  printf '%-12s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s\n' "$name" \
    "${ms[koru]:-—}" "${ms[koru-fold]:-—}" "${ms[koru-par]:-—}" "${ms[c]:-—}" "${ms[cgcc3]:-—}" "${ms[cclang]:-—}" "${ms[cmap]:-—}" "${ms[carena]:-—}" "${ms[rust]:-—}" "${ms[haskell]:-—}" "${ms[ocaml]:-—}" "${ms[osprey]:-—}" "${ms[c3]:-—}" "${ms[odin]:-—}" "${ms[mojo]:-—}" "${ms[bend]:-—}" "${ms[bend-par]:-—}"
  unset ms
done

echo
echo "Values are mean wall-clock milliseconds (hyperfine -N, warmup $WARMUP, min-runs $MINRUNS) on this machine."
echo "'—' = toolchain/source absent or build failed · 'WRONG' = built but failed the oracle (excluded) · 'NOT-RUN' = outside the compiled-contender field (KORU_BENCH_FIELD)."

# Persist the board as a provenance-carrying artifact (results/latest.json).
# Only a FULL run writes it — a filtered run is a partial board and must never
# masquerade as the whole one.
if [ -z "$FILTER" ]; then
  cpu=""; loadavg=""; ncpu=""
  case "$(uname -s)" in
    Darwin)
      cpu="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || true)"
      loadavg="$(sysctl -n vm.loadavg 2>/dev/null | tr -d '{}' | awk '{print $1, $2, $3}')"
      ncpu="$(sysctl -n hw.ncpu 2>/dev/null || true)" ;;
    Linux)
      cpu="$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ //' || true)"
      loadavg="$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null || true)"
      ncpu="$(nproc 2>/dev/null || true)" ;;
  esac
  koru_repo="$(cd "$(dirname "$KORUC")/../.." 2>/dev/null && pwd)"
  koru_commit="$(git -C "$koru_repo" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  koru_dirty="$(git -C "$koru_repo" status --porcelain 2>/dev/null | grep -q . && echo true || echo false)"
  mkdir -p "$ROOT/results/runs"
  # Every full run is archived immutably under results/runs/ — latest.json is
  # the pointer to the newest run, never the only copy. board_class separates
  # publishable quiet-rig boards (bench-on-hetzner.sh exports BOARD_CLASS)
  # from dev-loop workstation runs so the two can never be mistaken.
  ARCHIVE_FILE="$ROOT/results/runs/$(date -u +%Y%m%dT%H%M%SZ)_$(hostname -s)_$(uname -m)_${koru_commit}.json"
  ROWS_FILE="$ROWS" OUT_FILE="$ROOT/results/latest.json" ARCHIVE_FILE="$ARCHIVE_FILE" \
  BOARD_CLASS="${BOARD_CLASS:-local-workstation}" \
  GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)" OS="$(uname -s)" ARCH="$(uname -m)" CPU="$cpu" \
  LOADAVG="$loadavg" NCPU="$ncpu" \
  KORU_COMMIT="$koru_commit" KORU_DIRTY="$koru_dirty" WARMUP="$WARMUP" MINRUNS="$MINRUNS" \
  CC_VERSION="$(cc --version 2>/dev/null | head -1 || echo ABSENT)" \
  GCC_VERSION="$(gcc_ok && gcc --version 2>/dev/null | head -1 || echo ABSENT)" \
  CLANG_VERSION="$(clang_ok && clang --version 2>/dev/null | head -1 || echo ABSENT)" \
  RUSTC_VERSION="$(rustc --version 2>/dev/null || echo ABSENT)" \
  GHC_VERSION="$(ghc --numeric-version 2>/dev/null | sed 's/^/ghc /' || echo ABSENT)" \
  OCAML_VERSION="$(ocamlopt -version 2>/dev/null | sed 's/^/ocamlopt /' || echo ABSENT)" \
  OSPREY_VERSION="$([ -n "$OSPREY" ] && [ -x "$OSPREY" ] && ("$OSPREY" --version 2>/dev/null | head -1 || echo "osprey (version unknown)") || echo ABSENT)" \
  C3C_VERSION="$( (command -v c3c >/dev/null 2>&1 && c3c --version || "$HOME/src/c3/c3c" --version) 2>/dev/null | head -1 || echo ABSENT)" \
  ODIN_VERSION="$( (command -v odin >/dev/null 2>&1 && odin version || "$HOME/src/odin/odin" version) 2>/dev/null | head -1 || echo ABSENT)" \
  MOJO_VERSION="$(mojo_ok && ("$PIXI" run --manifest-path "$MOJO_MANIFEST" mojo --version 2>/dev/null | head -1 || echo "mojo (version unknown)") || echo ABSENT)" \
  BEND_VERSION="$(bend_version)" \
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
    # Comparator honesty labels live on the cells they qualify. A corner-cut
    # reference is still measured, but it is a memory/workload-protocol artifact,
    # not a like-for-like language comparator.
    comparator_notes = {}
    for c_lang in ("c", "cgcc3", "cclang"):
        comparator_notes[("wordfreq", c_lang)] = ("memory-protocol-artifact", "corner-cut memory protocol: counts into a fixed array by hash slot and never builds a string-keyed map; compare wordfreq with cmap, not this cell, for like-for-like C")
        comparator_notes[("binarytrees", c_lang)] = ("memory-protocol-artifact", "per-node malloc/free memory protocol; compare binarytrees with carena, not this cell, for arena-backed like-for-like C")
        comparator_notes[("exprtree", c_lang)] = ("memory-lifecycle-artifact", "heap-allocates every expression node but never frees the tree; unlike managed/reference implementations, recursive teardown cost is absent")
        comparator_notes[("listops", c_lang)] = ("data-structure-protocol-artifact", "fixed contiguous array instead of the workload's persistent List<int>; not a like-for-like list-comparator cell")
    comparator_notes[("wordfreq", "cmap")] = ("like-for-like-memory-protocol", "hand-rolled chained string-keyed map")
    comparator_notes[("binarytrees", "carena")] = ("like-for-like-memory-protocol", "allocate-once backing store with bump allocation and per-iteration reset")
    comparator_notes[("listops", "rust")] = ("data-structure-protocol-artifact", "contiguous Vec instead of the workload's persistent List<int>; not a like-for-like list-comparator cell")
    comparator_notes[("listops", "ocaml")] = ("data-structure-protocol-artifact", "contiguous Array instead of the workload's persistent List<int>; not a like-for-like list-comparator cell")
    if (kernel, lang) in comparator_notes:
        cell["comparator_class"], cell["comparator_note"] = comparator_notes[(kernel, lang)]
    rows.setdefault(kernel, {})[lang] = cell
    if lang not in langs_seen:
        langs_seen.append(lang)

if os.environ.get("BOARD_CLASS") == "quiet-rig":
    discipline = "MEASURED on the dedicated-vCPU benchmark rig named above under BOARD_CLASS=quiet-rig, with no intentional co-run workload; machine.load_avg is the 1/5/15-min load at persist time and includes the benchmark/build workload itself. Read every number as a same-machine, same-protocol measurement under the recorded toolchains. Wrong-answer binaries are excluded from timing. Absent toolchains are reported absent, never estimated. No cross-language claim leaves this board unless re-verified under the target's exact rules."
else:
    discipline = "MEASURED on the shared developer workstation named above, under live load (see machine.load_avg — the 1/5/15-min load average at run time) — NOT a quiesced benchmark rig. Read every number as a same-machine, same-protocol ballpark, not a precise cross-language ranking: run-to-run jitter on a loaded box routinely exceeds the gaps between the compiled languages. Wrong-answer binaries are excluded from timing. Absent toolchains are reported absent, never estimated. No cross-language claim leaves this board unless re-verified under the target's exact rules."

out = {
    "suite": "osprey-compute-kernels",
    "board_class": os.environ.get("BOARD_CLASS", "local-workstation"),
    "generated_at": os.environ["GENERATED_AT"],
    "machine": {
        "os": os.environ["OS"], "arch": os.environ["ARCH"], "cpu": os.environ["CPU"],
        "load_avg": os.environ.get("LOADAVG", "").strip(),   # 1/5/15-min load at persist time
        "ncpu": int(os.environ["NCPU"]) if os.environ.get("NCPU", "").strip().isdigit() else None,
    },
    "koru": {"commit": os.environ["KORU_COMMIT"], "dirty": os.environ["KORU_DIRTY"] == "true"},
    "protocol": {
        "tool": "hyperfine -N",
        "warmup": int(os.environ["WARMUP"]),
        "min_runs": int(os.environ["MINRUNS"]),
        "flags": {
            "koru": "koruc build (ReleaseFast)",
            "koru-fold": "koruc build (ReleaseFast) — flat fold/identity port",
            "koru-par": "koruc build (ReleaseFast) — [parallel]-annotated port (fold split / fork-join)",
            "c": "cc -O2",
            "cgcc3": "gcc -O3 (real GCC only — ABSENT when gcc is clang)",
            "cclang": "clang -O3",
            "rust": "rustc -C opt-level=3 -C overflow-checks=off",
            "haskell": "ghc -O2",
            "ocaml": "ocamlopt -O3 -unsafe",
            "osprey": "osprey --compile (release)",
            "cmap": "cc -O2 (hand-rolled string map — like-for-like wordfreq comparator)",
            "carena": "cc -O2 (allocate-once arena — like-for-like binarytrees comparator)",
            "c3": "c3c compile -O5",
            "odin": "odin build -o:speed",
            "mojo": "mojo build (default -O3)",
            "bend": "bend build → native via clang (BendRT)",
            "bend-par": "bend build → native via clang — parallel-fork variant",
        },
    },
    "toolchains": {
        "c": os.environ["CC_VERSION"],
        "cgcc3": os.environ["GCC_VERSION"],
        "cclang": os.environ["CLANG_VERSION"],
        "rust": os.environ["RUSTC_VERSION"],
        "haskell": os.environ["GHC_VERSION"],
        "ocaml": os.environ["OCAML_VERSION"],
        "osprey": os.environ["OSPREY_VERSION"],
        "cmap": os.environ["CC_VERSION"],
        "carena": os.environ["CC_VERSION"],
        "c3": os.environ["C3C_VERSION"],
        "odin": os.environ["ODIN_VERSION"],
        "mojo": os.environ["MOJO_VERSION"],
        "bend": os.environ["BEND_VERSION"],
        "bend-par": os.environ["BEND_VERSION"],
    },
    "discipline": discipline,
    "langs": langs_seen,
    "kernels": rows,
}
payload = json.dumps(out, indent=2) + "\n"
with open(os.environ["OUT_FILE"], "w") as f:
    f.write(payload)
archive = os.environ.get("ARCHIVE_FILE")
if archive:
    os.makedirs(os.path.dirname(archive), exist_ok=True)
    with open(archive, "w") as f:
        f.write(payload)
print(f"\nBoard persisted: {os.environ['OUT_FILE']}")
if archive:
    print(f"Board archived:  {archive}")
PYEOF
fi
