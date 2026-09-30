#!/usr/bin/env bash
# channels suite perf harness — times each kernel against its reference
# implementations. Same protocol as the osprey board: hyperfine -N
# --warmup 3 --min-runs 10, release flags, oracle-verified before timing
# (a binary that answers wrong is excluded, never timed).
#
# Rows are labelled by threading substrate, not just language:
#   koru      — pump participants, one thread, nothing parked
#   go        — goroutines, GOMAXPROCS default
#   go1t      — same Go binary under GOMAXPROCS=1 (single OS thread)
# `go1t` is the honest control: it isolates "channel machinery" from
# "thread scheduling" so the koru number isn't silently beating a
# cross-thread implementation it doesn't yet do.
set -uo pipefail

SUITE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$(dirname "$SUITE")")"
KORUC="${KORUC:-$ROOT/../koru/zig-out/bin/koruc}"
WARMUP="${KORU_BENCH_WARMUP:-3}"
MINRUNS="${KORU_BENCH_MINRUNS:-10}"
FILTER="${1:-}"

command -v hyperfine >/dev/null 2>&1 || { echo "hyperfine not installed." >&2; exit 2; }
[ -x "$KORUC" ] || { echo "koruc not found at $KORUC" >&2; exit 2; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
have() { command -v "$1" >/dev/null 2>&1; }

printf '%-16s %10s %10s %10s %10s %10s %10s\n' kernel koru zig-ring crossbeam go go1t gonb
printf '%-16s %10s %10s %10s %10s %10s %10s\n' "------" "----" "--------" "---------" "--" "----" "----"

for casedir in "$SUITE"/reference/cases/*/; do
  name="$(basename "$casedir")"
  [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]] && continue
  expected="$(cat "$casedir/expected.txt" 2>/dev/null || true)"
  declare -a cmds=()

  # koru — build through koruc, verify output, time
  kdir="$SUITE/koru/$name"
  if [ -f "$kdir/$name.k" ]; then
    w="$TMP/k_$name"; mkdir -p "$w"; cp "$kdir/$name.k" "$w/"
    if ( cd "$w" && timeout 600 "$KORUC" build --release=fast "$name.k" >build.log 2>&1 ) && [ -x "$w/a.out" ]; then
      out="$(cd "$w" && timeout 120 ./a.out 2>/dev/null)"
      if [ "$out" = "$expected" ]; then
        cmds+=("$w/a.out")
      else
        cmds+=("echo WRONG-ANSWER")
      fi
    else
      cmds+=("echo BUILD-FAIL")
    fi
  fi

  # zig-ring — the same-substrate control: SAME MpmcRing, same schedule
  if have zig && [ -f "$casedir/$name.zig" ]; then
    ( cd "$TMP" && zig build-exe -OReleaseFast "$casedir/$name.zig" -femit-bin="zig_$name" >/dev/null 2>&1 )
    if [ -x "$TMP/zig_$name" ]; then
      out="$(timeout 120 "$TMP/zig_$name" 2>/dev/null)"
      if [ "$out" = "$expected" ]; then
        cmds+=("$TMP/zig_$name")
      else
        cmds+=("echo WRONG-ANSWER")
      fi
    else
      cmds+=("echo BUILD-FAIL")
    fi
  fi

  # crossbeam — the semantic peer: bounded MPMC, try_send/try_recv, one thread
  if have cargo && [ -f "$casedir/crossbeam/Cargo.toml" ]; then
    ( cd "$casedir/crossbeam" && cargo build --release --offline >/dev/null 2>&1 )
    rsbin="$casedir/crossbeam/target/release/$name"
    if [ -x "$rsbin" ]; then
      out="$(timeout 120 "$rsbin")"
      if [ "$out" = "$expected" ]; then
        cmds+=("$rsbin")
      else
        cmds+=("echo WRONG-ANSWER")
      fi
    else
      cmds+=("echo BUILD-FAIL")
    fi
  fi

  # go — build, verify, time; and again pinned to one thread
  if have go && [ -f "$casedir/$name.go" ]; then
    ( cd "$TMP" && go build -o "go_$name" "$casedir/$name.go" 2>/dev/null )
    if [ -x "$TMP/go_$name" ]; then
      out="$(timeout 120 "$TMP/go_$name")"
      if [ "$out" = "$expected" ]; then
        cmds+=("$TMP/go_$name")
        cmds+=("env GOMAXPROCS=1 $TMP/go_$name")
      else
        cmds+=("echo WRONG-ANSWER" "echo -")
      fi
    else
      cmds+=("echo BUILD-FAIL" "echo -")
    fi
  fi

  # gonb — same Go channel, non-blocking select/default, one goroutine
  if have go && [ -f "$casedir/${name}_nb.go" ]; then
    ( cd "$TMP" && go build -o "gonb_$name" "$casedir/${name}_nb.go" 2>/dev/null )
    if [ -x "$TMP/gonb_$name" ]; then
      out="$(timeout 120 "$TMP/gonb_$name")"
      if [ "$out" = "$expected" ]; then
        cmds+=("$TMP/gonb_$name")
      else
        cmds+=("echo WRONG-ANSWER")
      fi
    else
      cmds+=("echo BUILD-FAIL")
    fi
  fi

  # pad/absent handling: run hyperfine for whichever binaries we got
  cells=()
  for c in "${cmds[@]:-}"; do
    [ -z "$c" ] && continue
    if [[ "$c" == echo* ]]; then
      cells+=("$(echo "$c" | awk '{print $2}')")
      continue
    fi
    ms="$(hyperfine -N --warmup "$WARMUP" --min-runs "$MINRUNS" --style none --export-json "$TMP/hf.json" "$c" >/dev/null 2>&1 \
          && awk '/"mean"/ {gsub(/[^0-9.]/,"",$2); printf "%.1f", $2*1000; exit}' "$TMP/hf.json")"
    cells+=("${ms:-ERR}")
  done
  printf '%-16s %10s %10s %10s %10s %10s %10s\n' "$name" "${cells[0]:--}" "${cells[1]:--}" "${cells[2]:--}" "${cells[3]:--}" "${cells[4]:--}" "${cells[5]:--}"
done
