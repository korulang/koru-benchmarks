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

Known instrument constraints (each names a std/parser gap, AoC-pattern):

- **Right-recursive lists**: recursion depth tracks array length. The
  generator bounds arrays at 16 elements; a million-element array would
  exhaust the stack. Gap named: repetition (`many`/`sep-by`) compiled as a
  loop.
- **Backtracking PEG on non-factorable overlaps**: common-HEAD alternatives
  factor (head parses once, koru a50bf973); alternatives sharing a head but
  diverging mid-chain still backtrack and reparse. Gap named: chain-commit /
  packrat under the same surface.
- **The same-lane gap** (was 341 vs 866, now 375 vs ~866 MB/s): the
  hand-rolled recognizer dispatches on one byte-switch and consumes inline;
  the generated one still pays a DFA-table function call per terminal *that
  the first-byte gate admits*, accept-state tracking per byte (`last_end`),
  and a call per rule. The ladder: **[DONE, rung 1]** first-byte dispatch
  across group heads (pattern heads gated by prefix-DFA first set); **[next,
  rung 2]** single-char `lit` inlined to a byte compare (`input[p] == ','`
  instead of a slice-eq call); **[rung 3]** accept-tracking elided for
  patterns whose accept set is a suffix condition. Each rung is codegen-only
  — the surface never moves.
- **Spans only (cut 1)**: the recognizer lane exists because typed capture
  is cut 2 (the regex named-groups story). When trees land, this suite
  grows a full-tree Koru lane against zig_tree/py_loads.
