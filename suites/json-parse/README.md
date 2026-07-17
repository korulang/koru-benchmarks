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

Known instrument constraints (each names a std/parser gap, AoC-pattern):

- **Right-recursive lists**: recursion depth tracks array length. The
  generator bounds arrays at 16 elements; a million-element array would
  exhaust the stack. Gap named: repetition (`many`/`sep-by`) compiled as a
  loop.
- **Backtracking PEG, no memoization**: worst-case inputs are super-linear.
  Gap named: chain-commit / packrat under the same surface.
- **Spans only (cut 1)**: the recognizer lane exists because typed capture
  is cut 2 (the regex named-groups story). When trees land, this suite
  grows a full-tree Koru lane against zig_tree/py_loads.
