#!/usr/bin/env bash
# In-process timing runner for the ecs-store suite — a DIFFERENT PROTOCOL from
# the repo-root bench.sh, not a different filter. The reference numbers in
# baseline/ are criterion medians of per-iteration nanoseconds; at that scale
# (a 10k-row pass is microseconds) whole-process hyperfine timing sees only
# startup. So each Koru port times itself with std/time around N in-process
# passes and prints total_ns + timed_iters; this runner divides, repeats the
# process, and reports the median and min across runs.
#
# Discipline (same as bench.sh): a binary whose checksum line does not match
# its expected_*.txt oracle is EXCLUDED from timing — a wrong answer is not a
# result. A port that fails to compile is reported BLOCKED with the live
# diagnostic, never estimated. Baseline numbers are criterion medians (their
# instrument); ours is an in-process Koru std/time loop (our instrument) —
# same machine, different instruments, and the table names both. No
# comparative claim is made or implied by adjacency.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"                   # suites/ecs-store
KORUC="${KORUC:-/usr/local/bin/koruc}"
[ -x "$KORUC" ] || KORUC="$ROOT/../../../koru/zig-out/bin/koruc"
[ -x "$KORUC" ] || { echo "koruc not found (set KORUC)" >&2; exit 2; }
RUNS="${KORU_BENCH_RUNS:-5}"
BASELINE="$ROOT/baseline/2026-07-05-m2pro.json"
FILTER="${1:-}"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

echo "Machine: $(uname -sm) · koruc: $KORUC · runs per port: $RUNS"
echo "Protocol: in-process std/time around the timed passes; per-iter ns = total_ns / timed_iters; median of $RUNS process runs."
echo

# measure <name> <src.k> <oracle.txt> — prints one report block; appends a JSON
# fragment to $TMP/frags on success/blocked.
measure() {
  local name="$1" src="$2" oracle="$3"
  local w="$TMP/$name"; rm -rf "$w"; mkdir -p "$w"; cp "$src" "$w/prog.k"
  # koruc clobbers its CWD (backend.zig, a.out, ...) — always build in the tmp dir.
  if ! ( cd "$w" && "$KORUC" build prog.k >compile.log 2>&1 ) || [ ! -x "$w/a.out" ]; then
    local diag; diag="$(grep -m1 -E 'error\[' "$w/compile.log" || tail -1 "$w/compile.log")"
    printf '%-22s BLOCKED — %s\n' "$name" "$diag"
    printf '"%s": {"status": "blocked", "diagnostic": %s},\n' \
      "$name" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$diag")" >> "$TMP/frags"
    return 1
  fi
  local expected; expected="$(sed 's/[[:space:]]*$//' "$oracle")"
  local iters=() total ns_list=()
  for _ in $(seq 1 "$RUNS"); do
    local out; out="$("$w/a.out" 2>/dev/null)"
    local chk; chk="$(printf '%s\n' "$out" | grep '^checksum ')"
    if [ "$chk" != "$expected" ]; then
      printf '%-22s WRONG ANSWER — got "%s", oracle "%s" — excluded from timing\n' "$name" "$chk" "$expected"
      printf '"%s": {"status": "wrong-answer"},\n' "$name" >> "$TMP/frags"
      return 1
    fi
    # A port with several separately-timed blocks prints one total_ns line per
    # block (a sweep has no completion branch, so multi-store / multi-phase
    # passes cannot share one loop); the block totals sum to the per-iteration
    # figure's numerator.
    total="$(printf '%s\n' "$out" | awk '/^total_ns /{s+=$2; n++} END{if (n) print s}')"
    local n; n="$(printf '%s\n' "$out" | awk '/^timed_iters /{print $2}')"
    [ -n "$total" ] && [ -n "$n" ] && [ "$n" -gt 0 ] || { echo "$name: malformed output" >&2; return 1; }
    ns_list+=("$(( total / n ))"); iters+=("$n")
  done
  local stats; stats="$(printf '%s\n' "${ns_list[@]}" | python3 -c '
import sys, statistics
xs = [int(l) for l in sys.stdin]
print(f"{statistics.median(xs):.0f} {min(xs)} {xs}")' )"
  local med rest mn all
  med="${stats%% *}"; rest="${stats#* }"; mn="${rest%% *}"; all="${rest#* }"
  printf '%-22s median %s ns/iter · min %s ns/iter · runs %s (timed_iters %s per run)\n' \
    "$name" "$med" "$mn" "$all" "${iters[0]}"
  printf '"%s": {"status": "measured", "median_ns_per_iter": %s, "min_ns_per_iter": %s, "runs_ns_per_iter": %s, "timed_iters_per_run": %s, "process_runs": %s},\n' \
    "$name" "$med" "$mn" "$(printf '%s' "$all" | tr -d ' ')" "${iters[0]}" "$RUNS" >> "$TMP/frags"
}

: > "$TMP/frags"
ran=0
for dir in "$ROOT"/koru/*/; do
  entry="$(basename "$dir")"
  [ -n "$FILTER" ] && [[ "$entry" != *"$FILTER"* ]] && continue
  for src in "$dir"*.k; do
    [ -f "$src" ] || continue
    base="$(basename "$src" .k)"
    oracle="$dir/expected.txt"
    [[ "$base" == *_1col ]] && oracle="$dir/expected_1col.txt"
    measure "$base" "$src" "$oracle" || true
    ran=$((ran+1))
  done
done
[ "$ran" -gt 0 ] || { echo "no ports matched" >&2; exit 1; }

echo
echo "Reference baselines (criterion medians, ns/iter, $(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["machine"]["cpu"], "·", d["generated_at"][:10])' "$BASELINE")):"
python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
for eng, ns in sorted(d["results"]["simple_iter"].items(), key=lambda kv: kv[1]):
    print(f"  {eng:<18} {ns:>10.1f} ns/iter  (criterion median, full pos += vel)")' "$BASELINE"
echo
echo "Category-boundary entries — the operations differ, not just the engines (see MODEL.md)."
echo "fragmented_iter: reference = one query walking 26 fragmented archetype tables;"
echo "koru = 26 independent store sweeps. add_remove_component: reference = per-entity"
echo "row migration between archetype tables, twice; koru = one i64 presence-column"
echo "write per row, twice. Numbers are printed side by side and left uncompared."
python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
for entry in ("fragmented_iter", "add_remove_component"):
    if entry not in d["results"]:
        continue
    print(f"  {entry}:")
    for eng, ns in sorted(d["results"][entry].items(), key=lambda kv: kv[1]):
        print(f"    {eng:<18} {ns:>12.1f} ns/iter  (criterion median, their operation)")' "$BASELINE"
echo
echo "Instruments: reference = criterion 0.3 median via cargo bench (upstream harness);"
echo "koru = in-process std/time total over the timed passes, divided by pass count."
echo "Same machine, different instruments. simple_iter_1col advances ONE f64 column"
echo "per row; the reference workload advances a full f32 vec3 position per entity."

# Persist a full (unfiltered) board only.
if [ -z "$FILTER" ]; then
  mkdir -p "$ROOT/results"
  koruc_real="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$KORUC")"
  koru_commit="$(git -C "$(dirname "$koruc_real")/../.." rev-parse --short HEAD 2>/dev/null || echo unknown)"
  FRAGS="$TMP/frags" OUT="$ROOT/results/latest-inprocess.json" \
  KORU_COMMIT="$koru_commit" GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  CPU="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -m)" \
  LOADAVG="$(sysctl -n vm.loadavg 2>/dev/null | tr -d '{}' | sed 's/^ *//;s/ *$//' || true)" \
  RUNS="$RUNS" python3 - <<'PYEOF'
import json, os
frags = "{" + open(os.environ["FRAGS"]).read().rstrip().rstrip(",") + "}"
out = {
    "suite": "ecs-store",
    "kind": "koru-inprocess",
    "generated_at": os.environ["GENERATED_AT"],
    "machine": {"os": os.uname().sysname, "arch": os.uname().machine,
                "cpu": os.environ["CPU"], "load_avg": os.environ.get("LOADAVG", "")},
    "koru": {"commit": os.environ["KORU_COMMIT"]},
    "protocol": {
        "instrument": "in-process std/time (std.time.nanoTimestamp) around the timed passes; per-iter ns = total_ns / timed_iters; median across process runs",
        "process_runs": int(os.environ["RUNS"]),
        "warmup": "100 untimed passes in-process before the timed block",
        "flags": "koruc build (final binary ReleaseFast)",
        "note": "Baseline numbers in baseline/ are criterion medians — a different instrument on the same machine. Adjacency is not a comparison. simple_iter_1col writes ONE f64 column per row; the reference workload writes a full f32 vec3 position per entity. A port may print several total_ns lines (one per separately-timed block); they are summed before dividing by timed_iters.",
        "category_boundary": "fragmented_iter and add_remove_component measure a DIFFERENT OPERATION than the reference engines: no archetypes exist, so iteration is 26 independent sweeps and add/remove is a presence-column write, not a row migration. These entries are never comparative claims; see MODEL.md.",
    },
    "results": json.loads(frags),
}
with open(os.environ["OUT"], "w") as f:
    json.dump(out, f, indent=2); f.write("\n")
print(f"\nPersisted: {os.environ['OUT']}")
PYEOF
fi
