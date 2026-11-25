# Where Koru is behind Bend — findings (tak, mutual)

Written 2026-11-25, after the recursion-war night. These are the two cells
the certified Hetzner boards (three runs, three datacenters) show Koru
losing: `tak` everywhere (~-48%), `mutual` rotating with josephus (~-27%).
Everything below is measured or source-verified tonight; nothing is
speculation.

## tak — the stable loss

**What it is:** the Takeuchi function — self-recursive with a non-constant
decrease and inner recursion feeding outer args (`tak(x,y,z)` recurs on
`tak(x-1,y,z)` etc. and then tak of the three results). No closed form
exists in the literature; it is used as a benchmark precisely because it
resists the standard tricks.

**What we measured tonight:**
- Koru does NOT lower dependent recursion to native calls — it uses a
  segment machine (`__koru_seg_eval`, explicit control stack). Measured at
  ReleaseFast: LLVM devirtualizes the dispatch well; a native-call lowering
  experiment was ~18% WORSE. "Trampoline bad" is falsified — the segment
  machine is good.
- Peel/unroll depth-1 ceiling for tak: parity to 0-5% at best. Deprioritized
  deliberately — the recursion structure does not reward peeling because the
  decrease is not constant.
- Collapse families v1 (hanoi, fib, binom, powmod, loop-k) do NOT cover tak.
  It is a named negative-control cousin of ackermann, which is the pinned
  refusal case.

**What attacking it requires:** compile-time evaluation of literal inputs
(design complete at /tmp/peelwar-comptime.md — extend Folder.fold fixpoint
with .peel) plus deeper/wider peeling with body-cost-driven depth
(/tmp/peelwar-costmodel.md). Neither is a mystery; both are construction.

## mutual — the rotating loss

**What it is:** mutual recursion — two procedures calling each other
(is-even/is-odd shape). Bend handles it because its compilation model does
not care about call-graph shape; both sides become the same jumpy lambda
soup, and Bend's parallel runtime wins on width.

**Why Koru loses:** the passes landed tonight recognize SINGLE-flow
self-recurrence. Mutual recursion is a multi-flow cycle — the hygiene
gates, the family solvers, and the peel eligibility all assume one flow
calling itself. Extending recognition to multi-flow SCCs (strongly
connected components in the call graph) is unbuilt. No measurement tonight
suggests the raw emitter is slow — koru serial is within noise of C serial
on simple recursion elsewhere — so the Bend gap here is its parallel row
(par) beating our sequential-clean shape.

**What attacking it requires:** (1) call-graph SCC detection in the
elaborate pipeline; (2) mutual-shape family recognition (even/odd collapses
to parity arithmetic — trivially closed-form for the benchmark shape);
(3) or the parallel annotation applied to the koru port where legal.

## Honesty note

Both losses are structural, not noise — the boards were right to publish
them. The construction items above are scoped, designed, and measured-
against. This document should be updated when either leg lands.
