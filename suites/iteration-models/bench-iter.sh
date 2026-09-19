#!/usr/bin/env bash
# iteration-models — cross-language iteration-model benchmark.
#
# Same discipline as the Osprey board, one protocol difference: timing is
# INTERNAL to each program (best-of-7, reported on a `RESULT <checksum> <ms>`
# line) because process spawn (~5-15ms on macOS) would dominate 1.5ms rows.
#   * oracle gate: RESULT checksum must equal reference/cases/<case>/expected.txt
#   * a wrong answer is excluded from timing (status=wrong-answer)
#   * a missing toolchain or absent port reports ABSENT, never faked
#   * every port takes the same opaque trip bound: N = 10_000_000 + argc
#     (except the `koru` column, which is the literal-bound control)
set -uo pipefail

SUITE="$(cd "$(dirname "$0")" && pwd)"
KORUC="${KORUC:-$SUITE/../../../koru/zig-out/bin/koruc}"
FILTER="${1:-}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

have() { command -v "$1" >/dev/null 2>&1; }
echo "Machine: $(uname -sm) · koruc: $KORUC"
printf 'Toolchains: zig=%s rust=%s clang++=%s dotnet=%s swift=%s node=%s python3=%s\n\n' \
  "$(have zig && echo present || echo ABSENT)" "$(have rustc && echo present || echo ABSENT)" \
  "$(have clang++ && echo present || echo ABSENT)" "$(have dotnet && echo present || echo ABSENT)" \
  "$(have swiftc && echo present || echo ABSENT)" "$(have node && echo present || echo ABSENT)" \
  "$(have python3 && echo present || echo ABSENT)"

# run_or_measure <lang> <case> -> prints "<status> <ms>" ; builds + runs the port
run_port() {
  local lang="$1" case="$2"
  local src bin
  case "$lang" in
    koru|koru-opaque)
      src="$SUITE/$lang/$case.k"; [ -f "$src" ] || { echo "absent"; return; }
      [ -x "$KORUC" ] || { echo "no-koruc"; return; }
      local w="$TMP/k_${lang}_$case"; mkdir -p "$w"; cp "$src" "$w/prog.k"
      ( cd "$w" && "$KORUC" build --release=fast prog.k >/dev/null 2>&1 ) || { echo "build-fail"; return; }
      bin="$w/a.out" ;;
    zig)
      src="$SUITE/zig/$case.zig"; [ -f "$src" ] || { echo "absent"; return; }
      have zig || { echo "absent"; return; }
      bin="$TMP/z_$case"
      zig build-exe "$src" -OReleaseFast -femit-bin="$bin" >/dev/null 2>&1 || { echo "build-fail"; return; } ;;
    rust|rust-iter)
      src="$SUITE/$lang/$case.rs"; [ -f "$src" ] || { echo "absent"; return; }
      have rustc || { echo "absent"; return; }
      bin="$TMP/r_${lang}_$case"
      rustc -C opt-level=3 -C overflow-checks=off -o "$bin" "$src" >/dev/null 2>&1 || { echo "build-fail"; return; } ;;
    cpp)
      src="$SUITE/cpp/$case.cpp"; [ -f "$src" ] || { echo "absent"; return; }
      have clang++ || { echo "absent"; return; }
      bin="$TMP/c_$case"
      clang++ -std=c++23 -O3 -o "$bin" "$src" >/dev/null 2>&1 || { echo "build-fail"; return; } ;;
    csharp)
      local d="$SUITE/csharp/$case"; [ -f "$d/Program.cs" ] || { echo "absent"; return; }
      have dotnet || { echo "absent"; return; }
      ( cd "$d" && dotnet build -c Release -o bin >/dev/null 2>&1 ) || { echo "build-fail"; return; }
      bin="$d/bin/iter" ;;
    fsharp)
      local d="$SUITE/fsharp/$case"; [ -f "$d/Program.fs" ] || { echo "absent"; return; }
      have dotnet || { echo "absent"; return; }
      ( cd "$d" && dotnet build -c Release -o bin >/dev/null 2>&1 ) || { echo "build-fail"; return; }
      bin="$d/bin/iterfs" ;;
    swift)
      src="$SUITE/swift/$case.swift"; [ -f "$src" ] || { echo "absent"; return; }
      have swiftc || { echo "absent"; return; }
      bin="$TMP/s_$case"
      swiftc -O -o "$bin" "$src" >/dev/null 2>&1 || { echo "build-fail"; return; } ;;
    node)
      src="$SUITE/node/$case.mjs"; [ -f "$src" ] || { echo "absent"; return; }
      have node || { echo "absent"; return; }
      run_and_parse node "$src" "$case"; return ;;
    python)
      src="$SUITE/python/$case.py"; [ -f "$src" ] || { echo "absent"; return; }
      have python3 || { echo "absent"; return; }
      run_and_parse python3 "$src" "$case"; return ;;
    *) echo "absent"; return ;;
  esac
  run_and_parse "$bin" "" "$case"
}

run_and_parse() {
  local cmd="$1" arg="$2" case="$3"
  local oracle out ck ms
  oracle="$(tr -d '[:space:]' < "$SUITE/reference/cases/$case/expected.txt")"
  out="$("$cmd" $arg 2>&1 | grep '^RESULT ' || true)"
  [ -n "$out" ] || { echo "run-fail"; return; }
  ck="$(echo "$out" | awk '{print $2}')"
  ms="$(echo "$out" | awk '{print $3}')"
  [ "$ck" = "$oracle" ] || { echo "wrong-answer"; return; }
  echo "measured $ms"
}

LANGS=(koru koru-opaque zig rust rust-iter cpp csharp fsharp swift node python)
printf '%-16s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s\n' case "${LANGS[@]}"
printf '%-16s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s %10s\n' ---- -- -- -- -- -- -- -- -- -- -- --

mkdir -p "$SUITE/../../results"
JSON="$SUITE/../../results/iteration-models-latest.json"
ROWS="$TMP/rows"; : > "$ROWS"

for casedir in "$SUITE"/reference/cases/*/; do
  case="$(basename "$casedir")"
  [ -f "$casedir/expected.txt" ] || continue
  [ -n "$FILTER" ] && [[ "$case" != *"$FILTER"* ]] && continue
  printf '%-16s' "$case"
  for lang in "${LANGS[@]}"; do
    res="$(run_port "$lang" "$case")"
    status="$(echo "$res" | awk '{print $1}')"
    ms="$(echo "$res" | awk '{print $2}')"
    if [ "$status" = "measured" ]; then
      printf ' %10s' "$ms"
      printf '  { "case": "%s", "lang": "%s", "status": "measured", "ms": %s }\n' "$case" "$lang" "$ms" >> "$ROWS"
    else
      printf ' %10s' "$status"
      printf '  { "case": "%s", "lang": "%s", "status": "%s" }\n' "$case" "$lang" "$status" >> "$ROWS"
    fi
  done
  printf '\n'
done

{
  echo '{'
  echo '  "suite": "iteration-models",'
  echo "  \"machine\": \"$(uname -sm)\","
  echo "  \"date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo '  "protocol": "internal best-of-7 ms; bound = 10_000_000 + argc (koru column literal-bound control)",'
  echo '  "rows": ['
  sed 's/$/,/' "$ROWS" | sed '$ s/,$//'
  echo '  ]'
  echo '}'
} > "$JSON"
echo
echo "wrote $JSON"
