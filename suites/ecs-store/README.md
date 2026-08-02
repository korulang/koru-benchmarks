# ecs-store — the std/store perf instrument

Seven workloads from `ecs_bench_suite` (rust-gamedev's cross-engine ECS
benchmark, see PROVENANCE.md), each mapped to the `std/store` capability it
requires. **All seven are ABSENT day one** — std/store rung one (scalar
singleton stores) can express none of them. This is the AoC pattern pointed
at performance: every entry names a store gap in the compiler's own terms,
sits honestly absent (or later, honestly slow), and goes green only as a side
effect of the rungs landing. Nobody works ON an entry; the gaps are the work
list.

Claims discipline (drag-race scar tissue, at full force): no comparative word
— beats / matches / on par — ever leaves this repo unless SHOWN under
criterion, same machine, same workload, same rules. Two entries measure a
cost the design *refuses to have*; those get category-boundary labels, never
win-quotes.

**Surface migration, 2026-08-02 — the ports had gone dark.** koru `19d9393d`
renamed the store read verbs: `sweep` became `query`, and the old `query` (a
standing statement over rows) became `rule`. Every port here was written
before that landed, so a full-board correctness check found **22/22 BLOCKED**
— `unknown tor 'std.store:sweep'` and the KORU161 cascade behind it. Nothing
in this suite had compiled for a day and the board did not know. The ports
are migrated (`std/store:sweep` / `! sweep e` → `std/store:query` /
`! query e`; `std/store:query` / `! query s` → `std/store:rule` / `! row s`)
and re-verified against their oracles: **22/22 compile and checksum exactly**
at koru `9388426a`, then RE-MEASURED end to end on a quiet machine (load avg
4.0, the calmest this board has ever had). The one-to-one tier reproduced
within 2% — the rename is measurably free. The fusion curve did not: its
2026-07-31 run was taken at load avg 21.8–26.2 and its own identity control
says so, so those numbers are corrected below rather than confirmed.
The `rf_sweeps_N` port filenames keep the old word — renaming them would
break the result JSON keys the fusion table quotes.

## Board

### One-to-one (ballpark entries — same workload, meetable protocol)

**Widths, stated once.** Every reference component is f32 (cgmath
`Matrix4<f32>`, `Vector3<f32>`). Each Koru port in this tier is therefore a
pair: an `_f32` variant matching the reference width, and an f64 variant
running the same workload at double column width. Both are published side by
side — the pair is informative, and neither half is a comparison.

All three entries below are in-process Koru `std/time` figures; the reference
baselines are criterion medians. Same machine, different instruments. No
comparative claim is made here, and none leaves this repo until the
instruments are reconciled.

- `simple_iter` — `pos += vel` over 10k rows. The SINGLE-query base case
  where fusion gives no edge — this is the baseline std/store must MATCH,
  and the falsifier for the iteration contract. If we lose here, O13's
  "one corpus read" story is decoration.
  **Status 2026-08-02, fourth measurement — RE-MEASURED post-rename, both
  widths.** Runner `bench-inprocess.sh`, ports in `koru/simple_iter/`,
  results in `results/latest-inprocess.json` (koru `9388426a`, load avg
  4.0/4.2/4.8 — the quietest machine any board here has had; 5 interleaved
  process runs across all 22 ports). The previous figures are kept in the
  right-hand column: the surface rename is measurably free.

  | port | median | min | runs | was (`d49f3e31`, load 6.2–15.7) |
  |---|---|---|---|---|
  | `simple_iter_f32` (full `pos += vel`) | **4397 ns/iter** | 4369 | 4369–4434 | 4438 |
  | `simple_iter` (full `pos += vel`, f64) | **6507 ns/iter** | 6360 | 6360–6617 | 6614 |
  | `simple_iter_1col_f32` (`px += vx`) | **799 ns/iter** | 791 | 791–815 | 818 |
  | `simple_iter_1col` (`px += vx`, f64) | **2176 ns/iter** | 2166 | 2166–2358 | 2193 |

  Every entry in this tier lands within 2% of its pre-rename figure
  (`simple_insert`'s median moves 5%, but its min moves 1.4% and it times
  only 5 iterations per run — that entry's spread has always been its own).
  Reproduced, not merely re-run: the ports were rewritten onto a renamed
  surface between the two boards.

  Three f64 measurements, same machine, same workload, one day apart at the
  ends:

  | | 1-col | full `pos += vel` |
  |---|---|---|
  | first (before any fix) | 23,900,000 ns | did not compile |
  | after the dense-row write family | 4233 ns | 11016 ns |
  | after the sweep loop became a `for` | **2234 ns** | **6517 ns** |

  The first measurement put the one-column slice at ~23.9 ms — about 5600×
  the figure above — and the full workload could not be compiled at all. Two
  koru changes closed both:

  - the multi-field `stored` envelope learned the bracket row head, so the
    three-column write compiles (koru pins 690_118, 690_125);
  - the store's write family now takes a DENSE row, so a sweep arm passes its
    loop index straight through. That removed the emitted read
    `store.px[store.__koru_resolve(h)]`, which had been making Zig copy the
    entire 80 KB column to the stack twice per row — `sample` attributed ~100%
    of runtime to `_platform_memmove`, roughly 1.6 GB moved per pass.
- `simple_insert` — 10k entities × 4 components (`Transform(mat4x4)`,
  `Position/Rotation/Velocity(vec3)`), flattened to 25 SoA scalar columns
  (koru pin 690_119 pins the row; compound column TYPES — a vec3/mat4x4-valued
  column — remain uninvented surface, 690_020's residue).
  **Status 2026-08-02 — RE-MEASURED, both widths.** Ports in
  `koru/simple_insert/`, same run and controls as above. One timed pass =
  10k inserts into a store no insert has touched — one store per timed pass,
  because the reference makes a fresh world per criterion iteration and
  because a Koru store cannot be drained and reused today (defect list
  below). Their world is heap-allocated inside the iteration; our stores are
  static, so the timed region holds first-touch page faults but no
  allocation. Five timed iterations per run makes this the noisiest entry on
  the board; quote the min beside the median.

  | port | median | min | runs | was (`d49f3e31`) |
  |---|---|---|---|---|
  | `simple_insert_f32` | **121600 ns/iter** | 111800 | 111800–131400 | 120800 |
  | `simple_insert` (f64) | **193400 ns/iter** | 179400 | 179400–195200 | 184000 |

- `heavy_compute` — 1k entities, mat4x4 inverted 100× per entity per
  iteration, in place. Expressible through 690_126–690_129: the stored block
  computes the determinant ONCE into a column and divides sixteen cofactor
  entries into it (690_128 — one determinant expansion per row per inversion
  where the naive 690_127 form pays seventeen), then copies the staging
  columns back over the matrix in the SAME block, legal because a plural
  block's entries land in written order (690_126).
  **Status 2026-08-02 — RE-MEASURED, both widths.** Ports in
  `koru/heavy_compute/`, same run and controls as above. One iteration = 100
  passes; the checksum sums the matrix, staging and det columns, so a run
  whose passes did nothing cannot pass the oracle. An earlier scratch probe
  of the naive 17-expansion form measured ~20 ms per iteration; the
  det-factored form below is that same workload at one expansion per row.

  | port | median | min | runs | was (`d49f3e31`) |
  |---|---|---|---|---|
  | `heavy_compute_f32` | **545900 ns/iter** | 532300 | 532300–554300 | 551500 |
  | `heavy_compute` (f64) | **1050100 ns/iter** | 1037900 | 1037900–1055600 | 1070800 |

  Two protocol differences beyond the instrument, stated: the reference
  iterates rayon-parallel batches of 64 where ours is single-threaded, and
  the reference ends each entity with one `transform_vector` (9 mul + 6 add,
  ~0.2% of the inversion arithmetic) that the port omits.

### The fusion curve — ours vs ours (rule_fusion, re-measured 2026-08-02)

O13's headline: compiled subscriptions mean one stripe pass serves the
entire workload — "one corpus read regardless of query count." Every entry
above is single-query, where that claim never meets a clock. `koru/rule_fusion/`
puts it on one: N standing rules (rule i: `p_i += vx` — disjoint write sets,
shared read column, legally fusible per koru 690_202/690_044) over one
10k-row f64 store, identical 9-column schema in every port, three schedules,
N in 1/2/4/8, interleaved with the simple_iter controls. This is an internal
comparison — fused vs unfused on our own machinery — not a cross-engine claim.

**Pass structure first, read from the emitted Zig before any clock.** The
stripe today is NOT one corpus read. `__store_stripe_<s>` chains N per-rule
qsweeps — koru_std/store.kz:3371 says so itself: "naive per-rule passes;
fusion is a later, semantics-preserving scheduling change" — and each
qsweep's per-row visit loads all 9 columns regardless of the rule's read
set, resolves the row handle twice, and dispatches a centralized 9-value
write envelope. So `rf_stripe_N` measures the standing-rule machinery at N
passes, not fusion. `rf_fused_N` — the same N rule bodies hand-fused into
one query's multi-column stored block (koru 690_118/125) — is the schedule
the fusion claim describes: one `for (0..len)` pass, N envelope writes per
row. `rf_sweeps_N` is the same work as N separate query passes.

**Status 2026-08-02 — RE-MEASURED on a quiet machine, and the previous
numbers do not survive it.** Load avg 4.0/4.2/4.8 (koru `9388426a`, 5
interleaved process runs across all 22 ports, checksum oracle green on every
run); full runs in `results/latest-inprocess.json`. The 2026-07-31 figures
were stamped `measured-under-load` at load avg 21.8–26.2 and are kept in the
right-hand columns as the cautionary half of the table.

**The identity control is what condemns them.** `rf_sweeps_1` and
`rf_fused_1` are the SAME PROGRAM TEXT — one rule, one pass, hand-fusing
nothing. Any gap between them is pure instrument noise. Under load they read
5607 vs 3865, a **1.45x** spread on identical programs. On the quiet machine
they read 2154 vs 2134: **1.009x**. So the old board's noise band was wider
than most of the effects it was quoting, and every ratio derived from it has
to be re-derived rather than re-stated.

ns per frame, median (min), quiet machine · previous under-load median in
the last column of each pair:

| N | rf_stripe_N (N standing-rule passes) | was | rf_sweeps_N (N query passes) | was | rf_fused_N (1 query pass) | was |
|---|---|---|---|---|---|---|
| 1 | 13597 (13449) | 20982 | 2154 (2111) | 5607 | 2134 (2113) | 3865 |
| 2 | 27563 (27400) | 39727 | 4674 (4566) | 7151 | 3479 (3458) | 8084 |
| 4 | 55617 (55194) | 73996 | 9635 (9301) | 14990 | 6252 (6207) | 11407 |
| 8 | 111486 (111397) | 168190 | 20195 (19378) | 27045 | 12689 (12477) | 16048 |

Read the medians now, not the mins — run-to-run spread on the stripe and
fused series is under 1%, so the median IS the load-robust end this time.

- **The stripe is linear in N to three digits:** 13597 → 27563 → 55617 →
  111486, ratio per doubling **2.027 / 2.018 / 2.005**. Under load this read
  1.99 / 2.06 / 2.03 and the conclusion was right for shaky reasons; it is
  now exact. "One corpus read regardless of query count" is not what the
  machinery does today. It does N reads, and it does them to the digit.
- **The standing-rule tax, per pass:** rf_stripe_N / rf_sweeps_N = **6.31x**
  (N=1), **5.90x** (N=2), **5.77x** (N=4), **5.52x** (N=8) — identical rule
  bodies, identical pass count, different row machinery (full-row load +
  double handle-resolve + centralized write vs direct envelope write). The
  old board read 6.5 / 7.2 / 7.2 / 5.7 and called it flat-ish noise; the tax
  in fact **declines monotonically with N**, because the per-pass fixed cost
  it charges is amortized against more work per frame.
- **The fusion dividend was OVERSTATED. It is 1.59x at N=8, not 2.0x.**
  rf_sweeps_N / rf_fused_N = 1.009x (N=1, the control), **1.343x** (N=2),
  **1.541x** (N=4), **1.592x** (N=8). The direction the old board reported
  survives — fusion pays, and pays more as N grows — but the magnitude was
  inflated by contention that hurt the N-pass port more than the one-pass
  port, which is exactly the bias a loaded machine has.
- **And the dividend SATURATES**, which is new and only visible at this
  resolution: `rf_fused_N` itself scales 1.630 / 1.797 / **2.030** per
  doubling. By N=8 the fused port is scaling perfectly linearly — the shared
  traversal has stopped being the cost, and each added rule is paying full
  price in envelope writes. Beyond ~4 rules on this family, fusing the
  traversal buys nothing further.

Verdict in this board's own terms, corrected: the direction is validated —
one pass in place of eight returns **1.59x** on this rule family, growing
with N but flattening by N=8 — and the headline is embarrassed twice, the
second time much harder than the first. The stripe O13 says fuses runs N
passes today, to three digits. And each of those passes costs **5.5–6.3x**
its imperative twin before fusion enters the picture at all. Ordering
follows directly: the deferred scheduling change at store.kz:3371 is worth
**1.59x** at N=8 and less below it, while retiring the standing-rule row tax
is worth **5.5–6.3x at every N**. The row tax is the bigger prize by a
factor of three, and it is the one nobody has scheduled.

### The iteration scaling probe (2026-08-02) — and a retraction

`probes/iter_scaling.py`, results in `results/iter-scaling-2026-08-02.json`.
32 generated ports: the `simple_iter` workload at N in 1250..250000, both
widths, 1 and 3 columns, so the read set sweeps 9 KB (deep L1) to 11.7 MB
(deep L2). The N=10000 points are controls and reproduce this board within
2.1%. These ports live OUTSIDE `koru/` on purpose — the published board's
interleave set stays fixed.

**Retraction first.** A ratio taken across the four published `simple_iter`
points said the f32 three-column port scaled 1.83x worse than linear, which
read as a defect worth ~26%. It was an artifact. `simple_iter_1col_f32` has
an 80 KB read set and is **L1-resident**; every other port in the family
spills to L2. Using it as the linear baseline compared two memory regimes and
manufactured a defect. At matched residency (N >= 20000, all L2) the f32
3col/1col ratio is a stable **3.58–3.64x** against a theoretical 3.0x, and
the f64 ratio is 3.02–3.22x. The probe exists so this comparison cannot be
made blind again.

**What survives, and it is the real finding: the store sustains a FLAT byte
rate across a 12.5x range of N, and the two widths sustain DIFFERENT rates.**

| series | N=20000 | 50000 | 100000 | 250000 | sustained |
|---|---|---|---|---|---|
| f32 1col | 96.9 | 99.4 | 99.3 | 99.6 | **~99 GB/s** |
| f32 3col | 81.1 | 82.9 | 81.3 | 83.6 | **~82 GB/s** |
| f64 1col | 111.6 | 110.4 | 112.9 | 110.1 | **~111 GB/s** |
| f64 3col | 106.7 | 111.1 | 105.0 | 107.5 | **~108 GB/s** |

- **No cliff.** From a 937 KB working set to 11.7 MB the rate does not move.
  The README's O13 note called the bandwidth-bound regime unentered; it is
  entered here, and the store's iteration holds its rate through it. That is
  a positive architectural result and the first one this suite has produced
  about SCALE rather than about a single size.
- **f64 sustains more bytes/s than f32, at every size, at both column
  counts.** Not a rounding effect: 108 vs 82 GB/s on the three-column form,
  stable across four sizes.
- **The loops are instruction-identical.** Disassembled both: 3 x (2 loads +
  one `fadd` + one store) per iteration, no unrolling in either, and exactly
  **96 bytes moved per iteration in both** (f32 covers 4 rows with `fadd.4s`,
  f64 covers 2 with `fadd.2d`). Per-iteration cost is nevertheless **1.72 ns
  for f32 against 1.36 ns for f64**, stable from N=20000 to N=250000. Same
  instructions, same bytes, 26% different cost.
- **The one visible asymmetry is addressing.** The f32 loop walks six
  independently post-incremented pointers (`ldr q1, [x0], #0x10`); the f64
  loop walks ONE base register with register offsets (`ldr q1, [x1, x11]`).
  That is six address-generation updates per iteration against roughly one.
  It is the only structural difference in the emitted code and it is a
  candidate, NOT a proven cause — separating it needs hardware counters.
- **So ~23% is on the table in the f32 path**, now measured against a
  properly matched baseline (f64's own achieved L2 rate) rather than the L1
  one that produced the retracted claim. At f64's byte rate the N=20000 f32
  port would be 6810 ns instead of 8881.

Three hypotheses died with evidence on the way here, which is the probe
earning its keep: the hot loop is NOT scalar (it is 4-wide NEON, and the
store's whole write envelope — field selector, five dead value slots, the
announce calls — is elided by the optimizer); the widths are NOT unrolled
differently; and the original scaling anomaly was NOT a defect.

### The column-shapes probe (2026-08-02) — a fold costs 8–12x an update

`probes/column_shapes.py`, results in `results/column-shapes-2026-08-02.json`.
Fixed N=50000 (L2-resident at every k), sweeping the number of columns a
single query touches. Two per-row shapes over the SAME columns:

- **RMW** — `e.p_i: e.p_i + e.v_i` for i in 1..k. 2k reads, k writes, and k
  **independent** add chains. This is `simple_iter`'s shape.
- **FOLD** — `check.sum: check.sum + e.p_1 + e.v_1 + ...`. 2k reads, no
  column write, and **one serial** dependency chain through the accumulator.

**Finding 1 — the f32 deficit is NOT the addressing mode, and the hypothesis
died on this table.** The scaling probe noted that f32's loop walked six
post-incremented pointers where f64's used one base register with register
offsets, and offered it as a candidate cause. Sweeping k settles it:

| k | f32 GB/s | f64 GB/s | f32/f64 | f32 addressing | f64 addressing |
|---|---|---|---|---|---|
| 1 | 99.9 | 112.6 | 88.7% | post-inc | reg-offset |
| 2 | 88.7 | 110.8 | 80.1% | post-inc | reg-offset |
| 3 | 82.7 | 111.3 | 74.3% | post-inc | reg-offset |
| 4 | 79.0 | 108.6 | **72.7%** | **reg-offset** | **reg-offset** |
| 5 | 82.2 | 106.5 | 77.2% | reg-offset | reg-offset |
| 6 | 78.6 | 105.0 | 74.9% | reg-offset | reg-offset |
| 8 | 77.2 | 102.3 | 75.5% | reg-offset | reg-offset |

From k=4 upward **both widths emit the same addressing form and the deficit is
unchanged** — it plateaus near 75% instead of growing with pointer count. So
the f32/f64 asymmetry survives its most plausible explanation and stays OPEN.
Separating it needs hardware counters. What the table does establish, and it
is useful on its own: **f64 is nearly insensitive to column count** (112.6 →
102.3 GB/s from k=1 to k=8, −9%) where **f32 degrades three times as fast**
(99.9 → 77.2, −23%). A wide query is cheap in this store; a wide NARROW query
is less cheap, and nobody knows why yet.

**Finding 2 — and this is the larger one. A fold runs at exactly one FP-add
latency per element, and costs 8–12x the update over the same columns.**

| k | width | ns/pass | dependent adds | ns/add | cycles/add | vs RMW |
|---|---|---|---|---|---|---|
| 3 | f32 | 270306 | 300000 | 0.901 | **3.15** | 12.4x |
| 3 | f64 | 271335 | 300000 | 0.904 | **3.17** | 8.4x |
| 8 | f32 | 722828 | 800000 | 0.903 | **3.16** | 11.6x |
| 8 | f64 | 723420 | 800000 | 0.904 | **3.17** | 7.7x |

3.16 cycles per add, flat across both widths and both column counts, against
an Apple M-series FP-add latency of ~3 cycles. The fold is **latency-bound on
its own accumulator**, not bandwidth-bound — which is why f32 and f64 land
within 0.4% of each other here while differing 25% on the RMW shape. Latency
does not care how wide the element is.

The FOLD series is deliberately NOT a write-free control for RMW: it also
collapses k independent chains into one. That confound **is** the finding —
it is what isolates the latency bound. It also puts a number on a lever the
design has discussed and never measured: a *declared* reduction, free to use
several accumulators or a log-depth tree, is worth up to an order of
magnitude on this shape. Today every aggregate written as a sweep accumulator
pays 3.16 cycles per element, serially, no matter how wide the machine is.

### Dissolved-by-design (category-boundary entries — label or die)

- `fragmented_iter` — 26 component types × 20 entities; measures **archetype
  fragmentation**, a cost O13's NO-ARCHETYPES ruling refuses to have
  (presence is a predicate column, not schema membership). We run the same
  workload without the disease and label it a different category — NEVER
  quoted as a win, exactly the faithful=yes/no boundary from the drag race.
- `add_remove_component` — add then remove a component on 10k entities;
  measures **archetype migration**. Ours is a presence-bit write firing
  ordinary deltas (O13) — same workload name, categorically different
  operation. Same labeling rule.

These two are where the central refusal gets validated or embarrassed.

**Width pairs for both, added 2026-08-02 — and one of them was a hole in this
board's own discipline.** The "widths, stated once" rule at the top of the
one-to-one tier was never applied down here. `fragmented_iter` was quoted at
f64 against reference fragments that hold **f32**, so part of the gap to
shipyard was our own missing port rather than anything about either design.
`add_remove_component` has no f32 question at all — its columns are `hp: i64,
b: i64` — but it has a sharper one: **O13 says presence is DATA, and that
datum currently costs eight bytes per row to say one bit.** So the pair there
is i64 against i32.

| entry | wide | narrow | dividend | ideal |
|---|---|---|---|---|
| `fragmented_iter` | 140 ns (f64) | **109 ns** (f32) | **1.29x** | 2.00x |
| `add_remove_component` | 1763 ns (i64) | **931 ns** (i32) | **1.89x** | 2.00x |

Absolute figures here are ~8% above the published board's (taken at 5-min
load 4.85 against the board's 4.0); the RATIOS are the result and they hold
across two independent runs. These entries want a quiet full-board run before
their absolutes are quoted anywhere.

- **Halving the width is worth 1.29x here and 1.89x there, and the gap
  between those two numbers is the interesting part.** `add_remove`'s timed
  loop is a pure streaming WRITE of a constant over a 160 KB working set —
  L2-resident, bandwidth-bound, and narrowing pays nearly full freight.
  `fragmented_iter`'s is a read-modify-write over 4 KB — L1-resident, so it
  was never bandwidth-bound and narrowing buys much less.
- **That is also the sharpest pointer yet at the open f32/f64 asymmetry.**
  The scaling and column-shapes probes found read-modify-write narrowing at
  only ~1.5x of the ideal 2x and could not say why. A pure streaming write
  narrows at 1.89x. Suggestive that the deficit lives on the READ path — but
  these two workloads differ in row count, working set and element type as
  well as in read-vs-write, so it is a lead, NOT a result. The clean version
  is a streaming-write against a read-modify-write at matched N, width and
  type, which nobody has run yet.
- **The shipyard gap on `fragmented_iter` shrinks but does not close:
  3.46x with our f64 port, 2.69x width-faithful.** I estimated beforehand
  that the missing port was worth about half the gap; it was worth about a
  fifth. The remainder is real and still unexplained, and shipyard's element
  rate on that entry implies it vectorizes something we do not.
- The emitted arithmetic is identical across the `fragmented_iter` pair,
  checked rather than assumed: LLVM strength-reduces the f64 port's
  `data * 2.0` to `fadd.2d v0, v0, v0` and the f32 port's `data + 1.0` is
  `fadd.4s v1, v1, v5`. Same instruction, same count, both unrolled four
  vector ops deep over paired `ldp`/`stp`. Column width is the only
  surviving difference.

### Gap-namers (honest-ABSENT until the rungs exist)

- `schedule` — 3 systems over 40k entities, outer parallelism. **Store
  gaps:** T7/O7 writer/reader phantoms + disjointness-proof scheduling
  (rung 4 — the no-threads bet itself). ALSO the fusion stress case: their
  systems overlap on component C, so naive fusion is illegal → forces
  stratified firing (h).
- `serialize` — 1k entities to RON + bincode and back. **Store gaps:** the
  whole-store serialization hole (gauntlet-2 finding, still needs its
  O-number): no save/load verb, and the T4 tension — "unprojected fields
  get no column" vs "a dump projects every field of every row."

## What the ports broke on the way (the instrument's other output)

Defects and refusals surfaced by building the one-to-one tier, in the
compiler's own terms. Dated 2026-07-31, koruc at `d49f3e31`; each is
reproducible from the shape named.

- **A literal row index is a generation-0 handle, permanently.**
  `std/store:take(items[0])` takes slot 0's row once; after the slot is
  freed — and even after a NEW row reuses slot 0 — the literal still carries
  generation 0 and resolves `| empty` forever. Probed directly: insert,
  take `[0]` (succeeds), insert again, take `[0]` → `empty`, with a live row
  sitting in slot 0. So "take the first row N times" drains exactly one row,
  and drain-by-literal-handles works only until the first slot reuse.
- **`take` with a query-bound row miscompiles.** `! query r |>
  std/store:take(items[r])` emits `handler(.{ .row = r })` with `r`
  undeclared in the emitted Zig — BACKEND_COMPILE_ERROR. The query's row
  binding does not thread into a take index (the same nesting family as koru
  690_110/112, where a row binding does not survive nesting).
- **Consequence of the two above: no drain/clear idiom exists.** A store
  cannot be emptied and reused. Benchmark passes that need a fresh store each
  iteration (simple_insert) use one store per pass; a long-lived program that
  wants to evict all rows has no spelling to ask for it.
- The insert path at 10k rows itself held: 60,000 inserts across six
  25-column stores land, sweep back, and checksum exactly, in both widths.
  `| full` fires correctly at declared capacity (it is what turned the
  first drain attempt's silent non-drain into a loud panic).

## Local baselines (reference engines, our machine)

`cargo bench` in the clone is the only legitimate source of numbers — their
protocol, unmodified. Baselines land in `baseline/` machine-stamped when a
run completes. Upstream's published `target/criterion` report is THEIR
machine; it is never quoted as a local baseline.

## Layout (grows as entries become expressible)

```
suites/ecs-store/
  PROVENANCE.md          # upstream repo + commit + not-vendored rationale
  README.md              # this board
  baseline/              # machine-stamped criterion summaries of the reference engines
  koru/<entry>/          # Koru ports, added only when std/store can express them
```
