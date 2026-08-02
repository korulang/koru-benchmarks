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
at koru `9388426a`. The timing tables below were taken at `d49f3e31`, BEFORE
the rename; they are not re-measured here. This pass is correctness only.
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
  **Status 2026-07-31, third measurement — MEASURED, both widths.** Runner
  `bench-inprocess.sh`, ports in `koru/simple_iter/`, results in
  `results/latest-inprocess.json` (koru `d49f3e31`, load avg 6.2–15.7,
  interleaved controls at their quiet-machine minima: 6408 vs 6390,
  2161 vs 2143).

  | port | median | min | runs |
  |---|---|---|---|
  | `simple_iter_f32` (full `pos += vel`) | **4438 ns/iter** | 4411 | 4411–4471 |
  | `simple_iter` (full `pos += vel`, f64) | **6614 ns/iter** | 6408 | 6408–7324 |
  | `simple_iter_1col_f32` (`px += vx`) | **818 ns/iter** | 796 | 796–851 |
  | `simple_iter_1col` (`px += vx`, f64) | **2193 ns/iter** | 2161 | 2161–2277 |

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
  **Status 2026-07-31 — MEASURED, both widths.** Ports in
  `koru/simple_insert/`, same run and controls as above. One timed pass =
  10k inserts into a store no insert has touched — one store per timed pass,
  because the reference makes a fresh world per criterion iteration and
  because a Koru store cannot be drained and reused today (defect list
  below). Their world is heap-allocated inside the iteration; our stores are
  static, so the timed region holds first-touch page faults but no
  allocation.

  | port | median | min | runs |
  |---|---|---|---|
  | `simple_insert_f32` | **120800 ns/iter** | 112200 | 112200–122600 |
  | `simple_insert` (f64) | **184000 ns/iter** | 177000 | 177000–193600 |

- `heavy_compute` — 1k entities, mat4x4 inverted 100× per entity per
  iteration, in place. Expressible through 690_126–690_129: the stored block
  computes the determinant ONCE into a column and divides sixteen cofactor
  entries into it (690_128 — one determinant expansion per row per inversion
  where the naive 690_127 form pays seventeen), then copies the staging
  columns back over the matrix in the SAME block, legal because a plural
  block's entries land in written order (690_126).
  **Status 2026-07-31 — MEASURED, both widths.** Ports in
  `koru/heavy_compute/`, same run and controls as above. One iteration = 100
  sweeps; the checksum sums the matrix, staging and det columns, so a run
  whose sweeps did nothing cannot pass the oracle. An earlier scratch probe
  of the naive 17-expansion form measured ~20 ms per iteration; the
  det-factored form below is that same workload at one expansion per row.

  | port | median | min | runs |
  |---|---|---|---|
  | `heavy_compute_f32` | **551500 ns/iter** | 547400 | 547400–560000 |
  | `heavy_compute` (f64) | **1070800 ns/iter** | 1050500 | 1050500–1077400 |

  Two protocol differences beyond the instrument, stated: the reference
  iterates rayon-parallel batches of 64 where ours is single-threaded, and
  the reference ends each entity with one `transform_vector` (9 mul + 6 add,
  ~0.2% of the inversion arithmetic) that the port omits.

### The fusion curve — ours vs ours (rule_fusion, 2026-07-31)

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
one sweep's multi-column stored block (koru 690_118/125) — is the schedule
the fusion claim describes: one `for (0..len)` pass, N envelope writes per
row. `rf_sweeps_N` is the same work as N separate sweep passes.

**Status 2026-07-31 — MEASURED, stamped measured-under-load** (load avg
21.8 before, 26.2 after; koruc `3385cdb8`; 5 interleaved process runs;
checksum oracle green on every run; controls at min: simple_iter 9384 vs
quiet-machine 6390 = 1.47x contention, simple_iter_1col 2283 vs 2143 =
1.07x). ns per frame, median (min); full runs in
`results/rule-fusion-2026-07-31.json`.

| N | rf_stripe_N (N standing-rule passes) | rf_sweeps_N (N sweep passes) | rf_fused_N (1 sweep pass) |
|---|---|---|---|
| 1 | 20982 (17472) | 5607 (2703) | 3865 (3100) |
| 2 | 39727 (34766) | 7151 (4840) | 8084 (4650) |
| 4 | 73996 (71492) | 14990 (9862) | 11407 (6507) |
| 8 | 168190 (145401) | 27045 (25412) | 16048 (12829) |

What the curve says, at the mins (the load-robust end; `rf_fused_1` and
`rf_sweeps_1` are the same program text, so their spread — 3100 vs 2703 —
is the noise band, and every trend below exceeds it):

- **The stripe is linear in N to two digits:** 17.5k → 34.8k → 71.5k →
  145.4k, ratio per doubling 1.99 / 2.06 / 2.03. "One corpus read
  regardless of query count" is not what the machinery does today; it does
  N reads.
- **The standing-rule tax, per pass:** rf_stripe_N / rf_sweeps_N = 6.5x
  (N=1), 7.2x (N=2), 7.2x (N=4), 5.7x (N=8) — identical rule bodies,
  identical pass count, different row machinery (full-row load + double
  handle-resolve + centralized write vs direct envelope write).
- **The fusion dividend, isolated on the sweep machinery:** rf_sweeps_N /
  rf_fused_N = 1.04x (N=2), 1.52x (N=4), 1.98x (N=8) — it widens with N,
  exactly the fusion signature.
- **Fused is not flat:** 3100 → 12829 across 8x rules (4.1x), because the
  per-row rule work (N envelope writes + N announces) rides along; only
  the traversal and the shared vx read are shared. One corpus *read* is
  not one corpus *cost*, and at 10k rows the columns are cache-resident —
  the bandwidth-bound regime the O13 napkin describes (1M+ rows) would
  need a bigger corpus to enter.

Verdict in this board's own terms: the direction is validated — one pass
in place of eight returns 2.0x on this rule family, growing with N — and
the headline is embarrassed twice: the stripe O13 says fuses runs N passes
today, and each of those passes costs 6–7x its imperative twin before
fusion enters the picture. The deferred scheduling change at
store.kz:3371 is worth 2x at N=8; retiring the standing-rule row tax is
worth 6–7x at every N.

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
