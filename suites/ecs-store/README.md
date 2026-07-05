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

## Board (all ABSENT — projected classification, a work list, not a result)

### One-to-one (ballpark entries — same workload, meetable protocol)

- `simple_insert` — 10k entities × 4 components (`Transform(mat4x4)`,
  `Position/Rotation/Velocity(vec3)`). **Store gaps:** rung-2 insert path
  (690_005), declared capacity + `| full` (690_011), batch insert + fused
  cascade (690_019), and **compound field types** — vec3/mat4x4 fields where
  rung one walls at non-i64 (mat4x4 substrate candidate: 2-D cells, 320_057).
- `simple_iter` — `pos += vel` over 10k rows. **Store gaps:** standing
  query + the stripe sweep (690_014, (l)/O13). The SINGLE-query base case
  where fusion gives no edge — this is the baseline std/store must MATCH,
  and the falsifier for the iteration contract. If we lose here, O13's
  "one corpus read" story is decoration.
- `heavy_compute` — 1k × mat4x4 inverted 100×. **Store gaps:** compute-bound
  stripe; mostly Zig codegen quality (kernels board context: C-parity on
  4/6 osprey-class kernels) plus the expression-layer A gap (raw-Zig `.k`
  bodies, pin 010_063).

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
