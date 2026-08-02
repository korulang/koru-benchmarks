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

### The read ladder (2026-08-02) — writing LESS data costs MORE time

`probes/read_ladder.py`, results in `results/read-ladder-2026-08-02.json`.
Writes held fixed at k=3 per row; reads varied 0 / k / 2k over the same store.
Run at f32/f64 **and** i32/i64, because "is this a float property?" deserved
an answer rather than an assumption.

| shape | reads/row | f64 | f32 | f64/f32 | i64 | i32 | i64/i32 |
|---|---|---|---|---|---|---|---|
| `write` `e.p_i: 1.0` | 0 | 48750 | 14997 | **3.25x** | 48679 | 14959 | **3.25x** |
| `copy` `e.p_i: e.v_i` | 3 | 49005 | 19318 | 2.54x | 48951 | 19387 | 2.52x |
| `rmw` `e.p_i: e.p_i + e.v_i` | 6 | 32432 | 21774 | **1.49x** | 32287 | 21716 | **1.49x** |

**Answer to the question asked: yes, the width dividend is governed by the
READ count.** It falls monotonically, 3.25x at zero reads to 1.49x at six.
And **float and integer are identical to two decimal places at every rung**,
so the f32/f64 asymmetry that three probes chased was never a float property
at all — it is width and access shape, nothing else. That retires the last
framing of it as an FP question.

**But the absolute numbers say something louder, and it is the session's
strangest result: `rmw` is FASTER than `write`.** 32432 ns against 48750,
while moving three times the bytes. `write` and `copy` cost the same as each
other (48750 vs 49005) despite `copy` moving twice what `write` does — the
signature of a fixed per-row cost rather than bandwidth. Every explanation
that would have been comfortable is ruled out: the emitted Zig is
structurally IDENTICAL across the three shapes (same envelope, same three
`__store_envwrite` calls, only the value expression differs), and all six
loops are vectorized — no scalar fallback anywhere.

**The mechanism shows itself when the store fits in L1:**

| shape | L1 (N=2000, 93 KB store) | L2 (N=50000) | degradation |
|---|---|---|---|
| `write` | **0.223** ns/row | 0.975 | **4.38x** |
| `copy` | 0.282 | 0.980 | 3.47x |
| `rmw` | **0.346** ns/row | 0.649 | **1.87x** |

**In L1 the ordering is sane and bytes-ordered — write cheapest, rmw dearest.
Out of L1 it INVERTS.** A store-only stream degrades 4.38x where a
read-modify-write degrades 1.87x.

> **RETRACTED, same day, by the next probe.** This section first attributed
> the inversion to *store streams going unprefetched* — prefetchers train on
> loads, so an RMW's reads warm the lines its writes land on. That mechanism
> is **wrong**. Adding explicit `@prefetch` to the write stream makes it
> SLOWER (0.392 → 0.60 ns/row), and plain Zig writing the same three columns
> shows no inversion at all. The real cause is below, and it is not in the
> compiler.

### What the inversion actually is (2026-08-02) — column placement

`probes/zig/`, three small Zig programs, because the way to test whether the
compiler is at fault is to hand-write the same loops and compare.

| shape | hand-written Zig | std/store | verdict |
|---|---|---|---|
| rmw | 0.620 ns/row | 0.649 | **parity — the store's codegen is exonerated** |
| write-only | 0.392 ns/row | 0.975 | 2.5x apart, and NOT the compiler |

Everything plausible was ruled out by reproducing it in Zig rather than by
argument. **The write envelope is free** — `envelope_vs_direct.zig` shows the
six-slot `__store_envwrite` with its runtime `field` switch costs 0.395
against a direct store's 0.393; LLVM folds the switch and the five dead slots
completely. **`announce` is free** — the watch-notification read-back
(`__store_peek` returning a union whose every arm is empty) does not cost
anything either. **Hoisting the `len` bound out of the loop changes nothing.**

**What reproduces it is the layout, exactly.** `contiguous_columns.zig` puts
the six columns in ONE struct with `len`, the way the store emits them, and
lands on 0.961–0.978 write / 0.645–0.661 rmw — koru measures 0.975 / 0.649.
The identical loops over columns allocated as SEPARATE globals give 0.39 /
0.62. So the whole write-only penalty is where two columns sit relative to
each other, and nothing else.

**And the stride LOOKED like a tunable — but that claim did not survive the
end-to-end test, and is retracted here.** `column_stride_isolated.zig` sweeps
22 column strides with each shape measured in its OWN PROCESS (an earlier
in-process sweep showed perfect anti-correlation with a conserved sum, which
is what benchmark interference looks like; process isolation was the control).
The effect is real:

| column stride | write ns/row | rmw ns/row |
|---|---|---|
| 400000 B | 0.940 | **0.621** |
| 400016 B | **0.579** | 0.840 |
| 400032 B | 0.940 | **0.609** |
| 400048 B | **0.580** | 0.837 |
| 400128 B | 0.951 | 0.654 |

Across all 22 strides the two shapes correlate at **r = -0.976**. Write spread
1.65x, rmw spread 1.46x, and **no stride is good for both** — it is a pure
trade, not a win.

> **RETRACTED: "the declared capacity picks the regime".** The previous
> revision of this section claimed a store's `capacity` silently selects which
> regime every query runs in, since a column stride is `capacity x width`.
> Tested end to end in real Koru — the same program at `capacity: 50000` and
> `capacity: 50002`, both loops still visiting 50000 rows — and it is **false**:
> write 0.958 -> 0.953, rmw 0.637 -> 0.632. No flip. The mock predicted 1.62x.
> The mock put `len` at offset 0 so its columns began at offset 8; koru's
> struct puts the six columns first at offset 0 and then FIVE handle arrays
> (`__koru_hslot_row`, `__koru_hslot_gen`, `__koru_row_hslot`,
> `__koru_hslot_free`, ~1.4 MB) in the same `.auto`-layout allocation. Same
> stride, different phase — and the effect tracks the absolute base addresses
> of the columns, not the stride between them.

**So the answer to "does stride padding pay off immediately" is NO**, for
three measured reasons:

- The two shapes anti-correlate at r = -0.976. Any padding that helps
  write-heavy passes hurts read-modify-write by a comparable factor.
- `simple_iter`, the board's flagship entry and its declared falsifier, is
  pure read-modify-write. Write-favourable padding would make the headline
  number ~37% worse.
- The cheap lever does not work anyway. Capacity does not move it; a real
  attempt needs explicit padding fields plus an `extern` layout so Zig cannot
  reorder, and that has not been tested end to end.

**Methodology note, earned FOUR times now.** Every extrapolation from a
hand-written mock to the real store was WRONG (the prefetch mechanism, the
capacity lever, and — hours after this paragraph was written — the 3.91x
projection retracted below). Every claim measured against the real store held
(codegen parity on rmw, the contiguity penalty, the fold latency bound). Mocks
were excellent for KILLING hypotheses — envelope, announce, prefetch,
len-hoisting all died cheaply in Zig — and unreliable for establishing them.
Kill in the mock; confirm in the compiler.

The fourth instance sharpened it, because "unreliable for establishing" was too
weak: a mock does not merely fail to find a real cost, it can **invent** one. A
mock reproduces the emitted code's shape, never its inlining structure, so work
the optimizer deletes in the real binary stays live in the mock and gets timed
honestly. **Before a mock number becomes a scheduled rung, diff the codegen it
claims to be about** — `probes/ab_codegen.py`, two compiles, no quiet machine
required.

### The standing-rule row tax, DECOMPOSED (2026-08-02)

`probes/zig/row_tax_decomposition.zig`, one variant per process. `rf_stripe_1`
and `rf_sweeps_1` run the SAME rule body over the same 10k-row 9-column store
and sit **6.31x** apart. Three things differ in the emitted code at once, so
the mock separates them:

| variant | ns/pass | vs query path |
|---|---|---|
| A `for` + projected read set (the QUERY path) | 3782 | 1.00x |
| B `while` + len re-read + projected | 5488 | **1.45x** |
| C `for` + full nine-column row | 14769 | **3.91x** |
| E `for` + full row + handle resolve | 17970 | 4.75x |
| D `while` + full row + handle (the RULE path) | 22745 | **6.01x** |

The mock reproduces the real 6.31x at 6.01x, so the decomposition was trusted.
**It should not have been. Variant C is an artifact — see the retraction
below.** The rows are kept verbatim because the correction is the finding.

**Every one of the three is the rule path not using a mechanism the query path
already has.** That part survives, and it means none of this is new invention:

- **Projection.** `koru_std/store.kz:1495` projects every user column
  unconditionally; the query path at `store.kz:7165` derives *"every column the
  arm named, in declaration order"* from a `used_cols` array that
  `SRewrite.walkCont` fills while it rewrites the body.
- **Loop form.** `store.kz:3228` emits, for rules, a `while (i < s.len)` that
  re-reads `len`, saves `len_before`, and increments conditionally — row
  removal tolerance, so a `take` under a rule re-checks the swapped-in row
  (690_031). The query path emits `for (0..s.len)` and tolerates no removal.
- **Handle.** `store.kz:3122` passes `__koru_handle_of(__koru_r)` as the
  body's row cursor on every row, whether or not the body addresses the row
  by handle.

**Step 2 of three is LANDED** (koru `8b0dcd4a`). A rule that cannot remove a
row now gets the query path's `for (0..len)`. The condition is WHOLE-PROGRAM,
not per-arm, because a `take` reached through a called flow is invisible to a
scan of the rule's own body: if the program never mentions take, no row can be
removed from anywhere by construction. Deliberately blunt — one mention
anywhere keeps every rule in that program on the tolerant form.

Its codegen change is real and its number survives re-measurement on the
interleaved instrument described below — `rf_stripe_1` at koru `9388426a` vs
koru `91410fdb`, 15 alternating pairs in one loop: **13549 → 12450 ns/iter
median (1.088x), 13378 → 12212 min (1.095x)**. The board's original
sequential figures (13597 → 12275, 1.11x) are consistent with that and are
left standing.

### RETRACTION (2026-08-02): the 3.91x projection did not exist

**Step 1 was implemented and it is worth nothing.** koru `986aee0f` derives the
rule projection from the body exactly as planned — the emitted `qrow` for
`rf_stripe_1` drops from nine column loads and a nine-field call to zero and a
bare cursor. Then:

| port | asm before | asm after |
|---|---|---|
| `rf_stripe_1` / `_2` / `_4` / `_8` | — | **byte-identical** |
| `rf_sweeps_1`, `rf_fused_8` | — | **byte-identical** |

All six rule ports compile to the same optimized machine code with and without
the projection. The `qrow` handler is `inline`; after inlining, nine loads that
nothing consumes are dead, and LLVM had been deleting them the whole time.
Compile time moves 1.003x on `rf_stripe_8`; emitted source shrinks 2–13%.

**Variant C of the mock measured a cost the real compiler does not pay.** The
mock reproduced the emitted code's SHAPE without its INLINING STRUCTURE, so its
dead loads stayed live and were honestly timed. The board's standing methodology
note said mocks are unreliable for *establishing* a cost; this is the sharper
case it did not cover — a mock can **manufacture** one, and a manufactured cost
survives review, because it is reproducible and it points at real code that
really does look wasteful. It sat at the top of the work list for a day.

**How the drift nearly hid it.** Two full board passes four minutes apart said
the change was worth 1.12x. It was not: `rf_sweeps_*`, the query-path control
that shares nothing with the rule path, moved 1.12x in the same direction. A
control that moves with the treatment condemns the run.

**The instrument that settled it, and the one to reach for first:**
`probes/ab_codegen.py <port> --a <rev> --b <rev>`. It builds the port against
two stdlib revisions, diffs the disassembly, and only times when the codegen
actually differs. Identical assembly cannot run at different speeds — that is a
proof, it costs two compiles, and it needs no quiet machine. When timing IS
warranted it alternates the two binaries inside one loop; measured noise floor
on byte-identical binaries **1.000x**, against **1.088x** for the
three-instruction loop-form change. The board's own protocol cannot see either.

### What the row tax actually is: the handle round-trip

With the projection gone the two loops can be read side by side, and the answer
is in the disassembly, not in a mock. Same body, same store, 10k rows.

`rf_sweeps_1` — the query path — is four instructions doing two rows at a time:

```
ldr   q0, [x14, x10]      ; p1[i..i+1]
ldr   q1, [x13], #0x10    ; vx[i..i+1]
fadd.2d v0, v0, v1
str   q0, [x14, x10]
```

`rf_stripe_1` — the rule path — is twenty instructions doing one row, with four
conditional panic branches and a four-deep chain of dependent loads before the
first useful byte arrives: `handles[i]` → generation table → generation table
again → dense-row table → column. The `fadd` is scalar. Nothing in that chain
can be vectorised, unrolled, or hoisted, because every address depends on the
previous load and every step can panic.

That chain is `__koru_handle_of(__koru_r)` at `store.kz:3122` followed by
`__koru_resolve(__koru_qrow)` at each access — the rung the mock priced at
**1.22x**. It is not 1.22x. It is, as far as the emitted code can show,
essentially the entire remaining 5.68x, and the mock understated it as badly as
it overstated the projection. The decomposition's ORDERING was backwards.

**LANDED, and it is the whole tax** (koru `94ae27eb`). The predicate was the
same whole-program `may_remove` question that chose the loop form: a program
that cannot remove a row cannot invalidate a dense index, so the rule pass now
carries the dense cursor the query path already had (`__koru_sdix_`, the O10.iv
elision) instead of a handle it resolves per access. Twenty scalar instructions
become four:

```
ldr   q0, [x12, x10]      ; p1[i..i+1]
ldr   q1, [x13], #0x10    ; vx[i..i+1]
fadd.2d v0, v0, v1
str   q0, [x12, x10]
```

Byte-for-byte the query path's loop. Sized on `probes/ab_codegen.py`, 21
interleaved pairs against a 1.000x noise floor:

| port | before | after | speedup |
|---|---|---|---|
| `rf_stripe_1` | 30489 | **5354** | **5.70x** |
| `rf_stripe_8` | 236475 | **40985** | **5.77x** |

(Absolute figures are from a loaded machine and are not board numbers; the
RATIO is what the interleaved instrument protects, and both ports agree.)

Falsifiers held: `rf_sweeps_1`, `rf_sweeps_8` and `simple_iter_f32` compile to
BYTE-IDENTICAL machine code before and after, as query-path ports must.
`690/695/670` unchanged at their known reds; `--check` 24/24.

**So the decomposition was inverted, not imprecise.** The mock priced this rung
at 1.22x and the projection — worth nothing — at 3.91x. Its smallest term was
the entire prize and its largest did not exist. The two errors have one root:
a mock reproduces the shape of emitted code and never its context, so it kept
loads the optimizer deletes and modelled a four-deep dependent-load chain
behind four panic branches as though it were arithmetic. The chain does not
merely cost cycles — it makes the loop unvectorisable, which is a property of
the surrounding code that a mock does not have.

**The tell was free and available before any timing**: four instructions of
`fadd.2d` against twenty scalar ones. Instruction SHAPE ranked the three terms
correctly where the mock's timings ranked them backwards. Read the two loops
before modelling either.

What made it SAFE rather than merely fast is two rulings landed the same day.
`store[cell]` names a row by handle, so no surface accepts a raw row index and
the dense cursor is internal to the lowering; and brand 0 is reserved, so a
dense index in a handle position traps loudly instead of addressing an
unrelated slot. A taking pass still carries the handle — a swap-remove can move
the row out from under a dense index mid-pass (690_031).

### The store-op vocabulary, sized (2026-08-02) — its headline member is worth nothing

A vocabulary of declared column operations was sketched on 2026-07-31, ordered
by expected payoff: `swapped { a <-> b }` (exchange, O(1) when total),
**elementwise combine** (`pos += vel`), fill/splat, copy, fold, and masked
forms. The criterion for admitting a member was sharp and is worth keeping:
*does it let the compiler do something it provably cannot recover from the
general form?*

Elementwise combine was named the biggest prize on the grounds that
`for (0..n) |i|` cannot reach the non-aliasing slice form
`for (px, vx) |*p, v| p.* += v`. **It reaches it today.** Read straight off the
binary, no timing needed:

| port | emitted inner loop |
|---|---|
| `simple_iter_f32` | `fadd.4s` — **4 rows/iteration**, three fused columns in one body, scalar epilogue |
| `simple_iter` (f64) | `fadd.2d` — **2 rows/iteration** |

Full SIMD width for the element type, with the three-column fusion intact. The
columns are separate SoA arrays, so there is no aliasing to prove away and LLVM
vectorises the index form unaided. **The gap the verb existed to close is not
there.** That retires the vocabulary's headline and takes the probe designed for
it off the list — the probe was going to hand-write the slice form and race it;
the disassembly answered first, for the cost of one `grep`.

What survives is the genuinely asymptotic tail, which is a smaller and sharper
list than the one we started with:

- **`swapped`** — O(1) base-pointer exchange vs O(n) copy. Real, and the use
  case is double buffering, not swapping.
- **fill / copy** — memset / memcpy vs an element loop.
- **fold** — the only member with a measured number behind it: a declared
  reduction breaks the serial accumulator chain that costs 3.16 cycles/element
  (one FP-add latency) and 8–12x an update over the same columns.

And the constraint that gates all of them is not a property of any member:
**an operation is fusible exactly when its notification granularity matches its
data granularity.** A column op with row-granular watchers attached has its O(1)
eaten by O(n) notifications, so the vocabulary needs column-granular
subscription before any member pays. Because Koru's subscriptions are compiled
rather than registered, the compiler knows statically which watchers are
attached to which column — so the mismatch is a COMPILE ERROR, never a silent
fall back to the element loop. That rule was derived independently twice, here
and from the reduction side.

One invariant here is pinnable and would be GREEN, not another aspirational red:
**an unwatched store column op should emit the same code as the equivalent
kernel op on the same data.** The store's distinguishing feature is switched off
on that path, so any difference is pure store overhead. `probes/ab_codegen.py`
is the instrument.

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
