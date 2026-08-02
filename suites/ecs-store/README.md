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
