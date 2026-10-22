# Wave 3 — commissioned 2026-10-22

Common rules (all briefs):
- Read PERF.md first — recipes + falsified hypotheses are the standards.
- Edit ONLY your task's .k file. No koru_std/compiler edits — toolchain
  proposals go in your report for the judge (PARKED candidates).
- Verify checksum == expected.txt BEFORE timing. Min-of-5 whole-process,
  /usr/bin/time -p. Report baseline->final + ratio vs the rust_min.txt
  number quoted in your brief.
- Faithfulness differences + falsified hypotheses go in the kernel
  header comment — including every approach you measured and rejected.
- Leave verification artifacts (patched dumps, disasm captures, probe
  sources) under /tmp/<task>_* and NAME them in your report — the
  judge re-runs the deepest receipt on every claim.
- Do NOT delete build artifacts (output_emitted.zig, a.out, bin/,
  compiler_env.json) — the judge cleans. Do NOT commit.
- Prefer pure .k. .kz only for genuine host integration (never yet).

## sort_self (flagship) — was 1.21s vs Rust 0.257s = 4.71x
The last >2x deficit. Current: i32 lanes + std.mem.sort -> Zig pdq
(the stdlib swap already landed in koru_std). The gap is pdq vs
driftsort — Rust ships driftsort (~4.8ms/400k vs pdq's ~20ms).
Challenge: write a driftsort-class sort IN PURE .K inside
sort_self.k — pattern-defeating quicksort with the driftsort
optimism heuristic (sorted-run detection on small partitions,
eager merge when beneficial). References: Zig's
lib/std/sort/pdq.zig and block.zig, Rust's driftsort paper/
implementation. This tests whether Koru can express a serious
adaptive sort at all — a yes is a flagship artifact. Fallback:
document the moat precisely (which driftsort primitive doesn't
fit, measured, in the header). Oracle 61757772. Note the
shared-harness quirk: quick/merge/self share the same data prep.

## etc_text_raytracer — 0.646s vs 0.459s = 1.41x
## graph_dfs — 0.978s vs 0.719s = 1.36x
## brainfuck_array — 1.407s vs 1.123s = 1.25x
  Explicit permission for the disclosed run-fold route (the
  goose-race kernel's proven shape: fold +- and <> runs to net
  deltas at parse, rebuild jumps on the folded stream — identical
  output, ~4x fewer dispatches there). The reference dispatches
  per-char; folding is a real interpreter technique — disclose it
  in the header and preserve per-op semantics.
## compress_arith_encode — 1.089s vs 0.896s = 1.22x
  Sibling of the arith_decode win — the fused param-carried loop +
  recipes that landed 0.85x there are the starting map.
