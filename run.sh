#!/usr/bin/env bash
# koru-benchmarks runner.
#
# Builds each Koru kernel THROUGH koruc and checks its output against the
# reference oracle. It consumes the toolchain — it never fakes a result. A green
# row means the Koru compiler built the kernel and it produced the right answer;
# a red row is either a build failure (a language/toolchain gap) or a wrong
# answer (a faithfulness bug). Both are signal.
#
# Usage:
#   ./run.sh [name-filter]
#   KORUC=/path/to/koruc ./run.sh        # override compiler location
#
# koruc is located, by default, in the sibling koru checkout (../koru), the same
# convention korulang_org uses.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
KORUC="${KORUC:-$ROOT/../koru/zig-out/bin/koruc}"
TIMEOUT="${KORU_BENCH_TIMEOUT:-600}"
FILTER="${1:-}"

if [ ! -x "$KORUC" ]; then
  echo "koruc not found at: $KORUC" >&2
  echo "Build it (cd ../koru && zig build) or set KORUC=/path/to/koruc." >&2
  exit 2
fi
echo "koruc: $KORUC"
echo

pass=0; fail=0; total=0
while IFS= read -r kfile; do
  dir="$(dirname "$kfile")"
  name="$(basename "$dir")"
  suite="$(basename "$(dirname "$(dirname "$dir")")")"
  [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]] && continue
  exp_file="$dir/expected.txt"
  [ -f "$exp_file" ] || { printf '  ? SKIP  %-14s (no expected.txt)\n' "$name"; continue; }
  total=$((total+1))
  expected="$(sed 's/[[:space:]]*$//' "$exp_file")"

  # koruc clobbers its CWD, so build in a throwaway dir.
  work="$(mktemp -d)"
  cp "$kfile" "$work/$(basename "$kfile")"
  if ( cd "$work" && timeout "$TIMEOUT" "$KORUC" build "$(basename "$kfile")" >build.log 2>&1 ) \
     && [ -x "$work/a.out" ]; then
    actual="$( cd "$work" && timeout "$TIMEOUT" ./a.out 2>/dev/null | sed 's/[[:space:]]*$//' )"
    if [ "$actual" = "$expected" ]; then
      printf '  \033[32m✓ PASS\033[0m  %-14s %s\n' "$name" "$actual"
      pass=$((pass+1))
    else
      printf '  \033[31m✗ FAIL\033[0m  %-14s got=[%s] want=[%s]\n' "$name" "$actual" "$expected"
      fail=$((fail+1))
    fi
  else
    reason="$(grep -m1 -iE 'error:' "$work/build.log" 2>/dev/null | head -c 140)"
    printf '  \033[31m✗ RED \033[0m  %-14s build failed — %s\n' "$name" "${reason:-see build.log}"
    fail=$((fail+1))
  fi
  rm -rf "$work"
done < <(find "$ROOT/suites" -path '*/koru/*/*.k' | sort)

echo
echo "── ${pass}/${total} pass · ${fail} red ──"
[ "$fail" -eq 0 ]
