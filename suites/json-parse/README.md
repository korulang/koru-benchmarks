# json-parse — the std/parser perf instrument

A friendly race for the pure-Koru JSON recognizer (`koru/bench.k`): the
641_004 grammar — every JSON shape as PEG-on-two-glyphs — driven by
`std/benchmarking:run` over a fixed document. The whole entry is the
toolchain exercised end to end: `std/args` → `std/fs:read-lines` →
`std/benchmarking` timed passes → a `std/parser` grammar compiled to
anchored-prefix DFA matchers + recursive descent by the `parse` transform.

Claims discipline (drag-race scar tissue, full force): contenders run in
LANES and no cross-lane verdict exists. The lanes, by work done:

- **recognizer** — koru std/parser: validates + returns spans. Builds no tree.
- **validate-tokens** — zig std.json.Scanner: walks every token. Builds no tree.
- **full-tree** — zig std.json Value, python json.loads: allocate and build
  the document. Strictly more work than both lanes above.

The honest sentence shape is "in the recognizer lane, on this doc, on this
machine, we measured X MB/s" — never "faster than Y" across lanes.

Protocol: identical for every contender — read `data/doc.json` (27,102
bytes, seed-41 generated, minified), loop the parse for 3 wall-clock
seconds in-process, print `passes=<n> seconds=<s>`. `bench_json.sh` builds
(Koru THROUGH koruc), gates correctness (reject a corrupted doc with
PARSE-ERROR line/col; python cross-checks the accept case), refuses to time
while a koru full-suite sweep is running, and prints the lane table.

Board history (M2 Pro, best-of-3, this suite's protocol — MEASURED only):

- 2026-07-18 pre-factoring, quiet window: koru 219.1 / zig scan 306.9 /
  zig tree 98.9 / py 129.2 MB/s.
- 2026-07-18 common-head factoring lands in koru_std/parser.kz (koru
  a50bf973): koru 353.3 / zig scan 339.0 (same window). The two adjacent
  lanes now overlap within rep noise; lanes differ, so that sentence is
  the whole claim.
- 2026-07-18 the TRUE same-lane rival arrives: `zig_recognize.zig`, a
  hand-rolled full-RFC validation-only recognizer (byte-switch descent, no
  allocation, honestly tuned). Same-window board: koru 341.3 / hand-rolled
  865.9 / scanner 330.8. THE same-lane sentence: the generated recognizer
  runs at ~40% of a dedicated hand-written validator. Nuance both ways:
  the hand-rolled one is general (ws anywhere, \uXXXX), the koru grammar
  is comptime-specialized to the doc's dialect — specialization for free
  is the library's pitch, and it still trails; the gap is the codegen
  ladder, not a mystery.
- The cliff: a 111-byte depth-24 RIGHT-nested doc ran 9 passes/3s
  (exponential last-element reparse, 2^depth) vs 4.0M for its left-nested
  twin. Factoring closed it: both ~5M. The driver's cliff gate pins
  right/left within 10x forever.
- 2026-07-18 rung 1 of the codegen ladder — first-byte gate on PATTERN group
  heads (koru_std/parser.kz + regex_engine.prefixFirstBytes): a pattern
  alternative is entered only when the cursor byte is in its prefix-DFA's
  admissible first set, so the failed DFA-matcher calls for the other
  alternatives are skipped (an object value no longer probes the
  string/number/keyword matchers before reaching `object`). Same-window
  control: koru 351.3 -> 375.2 MB/s (+6.8%), reps fully separated (baseline
  max 351.3 < post min 366.2); cliff gate held. RULE heads are deliberately
  NOT gated — their descent has to reach the deepest terminal to keep
  `expected <terminal>` from coarsening to `expected <rule>`, so the reject
  message stays byte-for-byte the ungated one (the gate's cold miss path
  records the same furthest-failure pos+expected the matcher orelse would).
- 2026-07-18 rung 3 of the codegen ladder — accept-write hoist for
  suffix-terminal DFAs (regex_engine.emitPrefixMatcher, koru 2b82d322). The
  prefix matcher did `if (A[s]) last_end = i + 1;` on EVERY byte (accept-table
  load + branch + loop-carried store). For a matcher whose accepting states
  transition only to the dead sink — string, keyword — an accept happens at
  most once, right before the break, so that per-byte work is pure overhead:
  the loop is reduced to transition + break-on-dead and the single match end
  is read off the state it stopped on. Numbers keep the per-byte write (digit
  -> digit re-accepts, not suffix-terminal). Strings are the bulk of JSON
  bytes, hence the size. Same-window control vs committed rung-1: koru 366.4
  -> 548.6 MB/s (+49.7%), reps fully separated (rung-1 max 366.4 << rung-3 min
  518.8). Definitive SAME-RUN apples-to-apples: koru recognizer 537.2 MB/s
  (reps 529.0-537.2) vs the hand-rolled rival 892.0 MB/s (reps 831.4-892.0),
  both measured back-to-back in ONE run = koru at 60% of a dedicated
  hand-written validator (was ~42% before this session's ladder work).
  Diagnostic exact, cliff gate held.
- Apples-to-apples discipline: koru-vs-rival ratios are quoted only from a
  SINGLE run where both are measured back-to-back on the same machine state,
  each with its rep spread. The rival drifts run-to-run (866-899 across
  sessions); a koru number from one run over a rival number from another is
  not a comparison, so we never form the ratio that way.

Known instrument constraints (each names a std/parser gap, AoC-pattern):

- **Right-recursive lists**: recursion depth tracks array length. The
  generator bounds arrays at 16 elements; a million-element array would
  exhaust the stack. Gap named: repetition (`many`/`sep-by`) compiled as a
  loop.
- **Backtracking PEG on non-factorable overlaps**: common-HEAD alternatives
  factor (head parses once, koru a50bf973); alternatives sharing a head but
  diverging mid-chain still backtrack and reparse. Gap named: chain-commit /
  packrat under the same surface.
- **The same-lane gap** (was 341 vs 866, now 537 vs 892 MB/s same-run = 60%):
  the hand-rolled recognizer dispatches on one byte-switch and consumes
  inline; the generated one still pays a per-byte 256-wide DFA-table load and
  a call per rule. The ladder:
  - **[DONE, rung 1, +6.8%]** first-byte dispatch across group heads (pattern
    heads gated by prefix-DFA first set).
  - **[rung 2 — NULL, reverted]** single-char `lit` -> byte compare. Zig
    ReleaseFast already inlines the 1-byte `lit_eq` into the same machine
    code; no measurable delta, so not landed (honesty about the wash IS the
    result).
  - **[DONE, rung 3, +49.7%]** accept-write hoisted out of the per-byte loop
    for suffix-terminal DFAs (string, keyword — accepting states go only to
    dead). The big one: strings dominate the byte count.
  - **[next, suspect #2]** the 256-wide `T[s*256 + b]` load per byte — the
    remaining structural cost vs the rival's inline byte tests. Candidate: a
    const bitset (OR-into-bits comprehension) reducing the load to a
    shift+and for simple terminals.
  Each rung is codegen-only — the surface never moves.
- **Spans only (cut 1)**: the recognizer lane exists because typed capture
  is cut 2 (the regex named-groups story). When trees land, this suite
  grows a full-tree Koru lane against zig_tree/py_loads.
