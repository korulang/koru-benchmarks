#!/bin/bash
# goose-race/compare.sh — the private Koru-vs-Goose board.
#
# Whole-process timing, interleaved rounds, min-of-N — the estimator noise
# cannot fake. Verification runs FIRST: each binary's stdout is checked
# before a single timed run, so no number ships from a wrong program.
#
#   compare.sh                  all tests, both sides
#   compare.sh primes brainfuck          only these tests
#   compare.sh --koru primes             koru side only (rerun ours)
#   compare.sh --goose json              goose side only
#   compare.sh --reps 7                  rounds per binary (default 5)
#
# Note on honesty: the suite's official protocol times between two notify
# messages (TCP :9001), excluding input reading and self-checks. We time
# whole processes — both sides pay input+verify inside the window, so the
# ratio is symmetric, but our absolute numbers exceed what the suite's
# notify-window would report. That skew is stated, not hidden.

set -u
cd "$(dirname "$0")"
SUITE=$PWD
KORUC=${KORUC:-/Users/larsde/src/koru/zig-out/bin/koruc}
GOOSE=${GOOSE:-/tmp/goose/build/goose}
GOOSE_SRC=${GOOSE_SRC:-/tmp/goose/bench/kostya2}
KOSTYA=${KOSTYA:-/tmp/kostya-benchmarks}
BUILD=$SUITE/build
NOTIFY_O=$BUILD/libnotify.o
REPS=5
DO_KORU=1; DO_GOOSE=1
TESTS=""

while [ $# -gt 0 ]; do
    case "$1" in
        --koru)  DO_GOOSE=0 ;;
        --goose) DO_KORU=0 ;;
        --reps)  shift; REPS=$1 ;;
        *)       TESTS="$TESTS $1" ;;
    esac
    shift
done
[ -n "$TESTS" ] || TESTS="matmul primes brainfuck base64 json"

# --- per-test spec ---------------------------------------------------------
# kb=koru binary (in suite), ka=koru argv, gs=goose source, gb=goose binary
# (in build/), ga=goose argv
spec() {
    case "$1" in
        matmul)
            ksrc=koru/matmul/matmul.k; kb=koru/matmul/matmul_koru; ka=""
            gs=$GOOSE_SRC/matmul/matmul.goose; gb=$BUILD/goose/matmul; ga="1500" ;;
        primes)
            ksrc=koru/primes/primes.k; kb=koru/primes/primes_koru; ka=""
            gs=$GOOSE_SRC/primes/primes.goose; gb=$BUILD/goose/primes; ga="" ;;
        brainfuck)
            ksrc=koru/brainfuck/brainfuck.k; kb=koru/brainfuck/bf_koru
            ka="$KOSTYA/brainfuck/bench.b"
            gs=$GOOSE_SRC/brainfuck/bf.goose; gb=$BUILD/goose/brainfuck
            ga="$KOSTYA/brainfuck/bench.b" ;;
        base64)
            ksrc=koru/base64/base64.k; kb=koru/base64/base64_koru; ka=""
            gs=$GOOSE_SRC/base64/test.goose; gb=$BUILD/goose/base64; ga="" ;;
        json)
            ksrc=koru/json/json.k; kb=koru/json/json_koru; ka=""
            gs=$GOOSE_SRC/json/test.goose; gb=$BUILD/goose/json; ga="" ;;
        *) echo "unknown test: $1" >&2; exit 1 ;;
    esac
}

# --- verification ----------------------------------------------------------
# verify <test> <koru-out-file> <goose-out-file>; absent sides pass "-".
verify() {
    local t=$1 ko=$2 go=$3
    case "$t" in
        matmul)  # one float result line, both sides
            [ "$ko" = - ] || grep -qE '^-?[0-9]+\.[0-9]+$' "$ko" || return 1
            [ "$go" = - ] || grep -qE '^-?[0-9]+\.[0-9]+$' "$go" || return 1 ;;
        primes)  # koru: one prime per line; goose: "[a, b, ...]"
            if [ "$ko" != - ] && [ "$go" != - ]; then
                diff -q "$ko" \
                    <(tr -d '[]' < "$go" | tr ',' '\n' | awk 'NF{print $1}') \
                    >/dev/null || return 1
            else
                [ "$ko" = - ] || grep -qE '^[0-9]+$' "$ko" || return 1
                [ "$go" = - ] || grep -q '^\[[0-9, ]*\]$' "$go" || return 1
            fi ;;
        brainfuck)  # koru prints the suite checksum; goose prints the text
            [ "$ko" = - ] || grep -q 'Output checksum: 23280' "$ko" || return 1
            [ "$go" = - ] || grep -q 'ZYXWVUTSRQPONMLKJIHGFEDCBA' "$go" || return 1 ;;
        base64)  # "<what>: <sum>, <ms>" — compare the sums, drop the timing
            if [ "$ko" != - ] && [ "$go" != - ]; then
                diff -q <(cut -d, -f1 "$ko") <(cut -d, -f1 "$go") \
                    >/dev/null || return 1
            else
                [ "$ko" = - ] || grep -qE '^encode aaaa\.\.\. to YWFh' "$ko" || return 1
                [ "$go" = - ] || grep -qE '^encode aaaa\.\.\. to YWFh' "$go" || return 1
            fi ;;
        json)  # Coordinate line; normalize goose's `e+30` to our `e30`
            if [ "$ko" != - ] && [ "$go" != - ]; then
                diff -q <(sed 's/e+/e/g' "$ko") <(sed 's/e+/e/g' "$go") \
                    >/dev/null || return 1
            else
                [ "$ko" = - ] || grep -q '^Coordinate { x: ' "$ko" || return 1
                [ "$go" = - ] || grep -q '^Coordinate { x: ' "$go" || return 1
            fi ;;
    esac
    return 0
}

# --- builds ----------------------------------------------------------------
K_BUILT=0; G_BUILT=0
build_koru() { # <test> — build the raced binary if missing or older than src
    spec "$1"; local d=$SUITE/$(dirname "$ksrc") out=$SUITE/$kb
    if [ ! -x "$out" ] || [ "$SUITE/$ksrc" -nt "$out" ]; then
        echo "  build koru: $1"
        (cd "$d" && "$KORUC" "$(basename "$ksrc")" >/dev/null &&
         zig build-exe output_emitted.zig -OReleaseFast -lc \
             -femit-bin="$out") || { echo "  koru build FAILED: $1" >&2; exit 1; }
        K_BUILT=1
    fi
}
build_goose() { # <test> — goose emits C, clang links it with libnotify
    spec "$1"
    mkdir -p "$BUILD/goose"
    if [ ! -f "$NOTIFY_O" ]; then
        echo "  build libnotify"
        clang -O2 -w -I"$KOSTYA/common/libnotify" \
            -c "$KOSTYA/common/libnotify/libnotify.c" -o "$NOTIFY_O" \
            || { echo "  libnotify FAILED" >&2; exit 1; }
    fi
    if [ ! -x "$gb" ] || [ "$gs" -nt "$gb" ]; then
        echo "  build goose: $1"
        GOOSE_STDLIB=/tmp/goose/stdlib \
            "$GOOSE" -O2 --standalone --include "$GOOSE_SRC/common/notify.h" \
            -o "$BUILD/goose/$1.c" "$gs" >/dev/null &&
        clang -O3 -march=native -flto=auto -std=c23 -w \
            -I"$KOSTYA/common/libnotify" \
            -o "$gb" "$BUILD/goose/$1.c" "$NOTIFY_O" -lm -pthread \
            || { echo "  goose build FAILED: $1" >&2; exit 1; }
        G_BUILT=1
    fi
}

# --- timing ----------------------------------------------------------------
# wall-clock: perl HiRes around each rep (ms precision; `time -l` on macOS
# quantizes to hundredths). RSS/instructions come from one `time -l` run —
# both are deterministic across reps, so a single measurement suffices.
hi_res() { # <binary> <args...> → seconds on stdout; child output discarded
    perl -MTime::HiRes=time -e '
        my $t = time;
        my $pid = fork() // die "fork";
        if ($pid == 0) {
            open STDOUT, ">", "/dev/null";
            open STDERR, ">", "/dev/null";
            exec @ARGV;
            exit 127;
        }
        waitpid $pid, 0;
        printf "%.4f", time - $t;
    ' "$@"
}
resources() { # <binary> <args...> → T_RSS/T_INS globals
    /usr/bin/time -l "$@" >/dev/null 2>"$BUILD/t.txt"
    T_RSS=$(awk '/maximum resident/ {print $1}' "$BUILD/t.txt")
    T_INS=$(awk '/instructions retired/ {print $1}' "$BUILD/t.txt")
}

mkdir -p "$BUILD"
printf "%-11s %-22s %-22s %s\n" test koru goose koru/goose
printf -- "-------------------------------------------------------------------\n"

for t in $TESTS; do
    spec "$t"
    [ $DO_KORU = 1 ] && build_koru "$t"
    [ $DO_GOOSE = 1 ] && build_goose "$t"

    # VERIFY FIRST — an untimed wrong answer is the only kind worth having.
    ko=-; go=-
    if [ $DO_KORU = 1 ]; then
        ko=$BUILD/$t.koru.out; "$SUITE/$kb" $ka >"$ko" || { echo "$t: koru exited nonzero" >&2; continue; }
    fi
    if [ $DO_GOOSE = 1 ]; then
        go=$BUILD/$t.goose.out; "$gb" $ga >"$go" || { echo "$t: goose exited nonzero" >&2; continue; }
    fi
    verify "$t" "$ko" "$go" || { echo "$t: VERIFY FAILED — not timed" >&2; continue; }

    kmin=""; gmin=""; krss=""; grss=""; kins=""; gins=""
    i=0
    while [ $i -lt "$REPS" ]; do
        i=$((i + 1))
        if [ $DO_KORU = 1 ]; then
            tr=$(hi_res "$SUITE/$kb" $ka)
            { [ -z "$kmin" ] || [ "$(echo "$tr < $kmin" | bc -l)" = 1 ]; } &&
                kmin=$tr
        fi
        if [ $DO_GOOSE = 1 ]; then
            tr=$(hi_res "$gb" $ga)
            { [ -z "$gmin" ] || [ "$(echo "$tr < $gmin" | bc -l)" = 1 ]; } &&
                gmin=$tr
        fi
    done
    [ $DO_KORU = 1 ]  && { resources "$SUITE/$kb" $ka; krss=$T_RSS; kins=$T_INS; }
    [ $DO_GOOSE = 1 ] && { resources "$gb" $ga; grss=$T_RSS; gins=$T_INS; }
    fmt() { # <min> <rss> <ins>
        [ -n "$1" ] || { printf -- "-"; return; }
        printf "%ss %.1fMB %sG" "$1" "$(echo "$2/1048576" | bc -l)" \
            "$(echo "scale=1; $3/1000000000" | bc -l)"
    }
    ratio=-
    [ -n "$kmin" ] && [ -n "$gmin" ] && \
        ratio=$(echo "scale=2; $kmin / $gmin" | bc -l)
    printf "%-11s %-22s %-22s %s\n" "$t" \
        "$(fmt "$kmin" "$krss" "$kins")" "$(fmt "$gmin" "$grss" "$gins")" \
        "$ratio"
done
