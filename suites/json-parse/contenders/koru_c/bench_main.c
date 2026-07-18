/* Contender: koru std/parser -> C backend. The SAME grammar as the koru entry
 * (json.k == koru/bench.k's grammar block), lowered to a standalone C parser by
 * `koruc json.k generate c` instead of to Zig by the parse transform. Same LANE
 * (recognizer: validate + return the root span, build NO tree — koru_parse_json
 * returns accept + value span) and same CATEGORY (general-library: a grammar
 * authored, a parser from the reusable std/parser). This row is the Zig-vs-C
 * codegen comparison of ONE library's output, and a general-lib peer to
 * nom/parsec/FParsec.
 *
 * Protocol identical to every contender: read the doc from argv[1], recognize
 * once (print INVALID + exit 1 on reject — the suite's reject gate), then a 3s
 * in-process timed-pass loop printing passes=<n> seconds=<s> sink=<n>. The
 * generated parser is #included with KORU_PARSER_NO_MAIN so its demo main is
 * suppressed and this harness owns main(). */
#define KORU_PARSER_NO_MAIN
#include "json.c"

#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static double now_secs(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (double)t.tv_sec + (double)t.tv_nsec / 1e9;
}

int main(int argc, char** argv) {
    if (argc < 2) { fprintf(stderr, "usage: %s <doc.json>\n", argv[0]); return 2; }
    FILE* f = fopen(argv[1], "rb");
    if (!f) { fprintf(stderr, "cannot open %s\n", argv[1]); return 2; }
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    uint8_t* buf = (uint8_t*)malloc(sz > 0 ? (size_t)sz : 1);
    if (fread(buf, 1, (size_t)sz, f) != (size_t)sz) { fprintf(stderr, "read failed\n"); return 2; }
    fclose(f);
    size_t len = (size_t)sz;

    /* Reject gate: recognize once; an invalid doc prints INVALID and exits 1,
     * matching the nom / zig_recognize contenders. */
    koru_parse_result r0 = koru_parse_json(buf, len);
    if (!r0.ok) { printf("INVALID\n"); return 1; }

    /* 3s in-process timed-pass loop; fold r.ok into a sink so the optimizer
     * cannot elide the parse (same guard as the nom contender). */
    double t0 = now_secs();
    unsigned long long passes = 0, sink = 0;
    double elapsed;
    do {
        koru_parse_result r = koru_parse_json(buf, len);
        sink += (unsigned long long)r.ok;
        passes++;
        elapsed = now_secs() - t0;
    } while (elapsed < 3.0);

    printf("passes=%llu seconds=%.6f sink=%llu\n", passes, elapsed, sink);
    free(buf);
    return 0;
}
