# Two models — archetypes, and what std/store does instead

The seven `ecs_bench_suite` workloads were designed against archetype ECS
engines. Three of them are ballpark-comparable. Two measure a cost `std/store`
is designed not to have, and quoting those as wins would be dishonest. Two name
capabilities that do not exist yet.

This document says what the two models actually are, so the board's categories
are a consequence of the architecture rather than a convenient sorting.

Everything below is stamped. **MEASURED** — read out of emitted Zig or source,
with a citation. **RULED** — decided, in `690_STORE/DESIGN.md`. **DESIGNED** —
ruled but not built. **OPEN** — undecided.

## The archetype model

An archetype ECS groups entities by their exact component *set*. All entities
with `{Position, Velocity}` live in one contiguous table; add `Health` to one of
them and it no longer belongs — its row is copied, field by field, into the
`{Position, Velocity, Health}` table and deleted from the old one.

What that buys is real: iteration over a query is a scan of the tables whose
component set is a superset of the query, and inside a table the columns are
dense with no holes and no per-row test. This is why `legion (packed)` sits at
3314ns on `simple_iter` — it is close to the floor for the operation.

What it costs is two things, and the benchmark suite measures both on purpose:

- **Fragmentation.** With 26 component types over 20 entities each,
  `fragmented_iter` produces many tiny tables. A query walks all of them, and
  the per-table overhead stops amortising. Engine spread on this entry is
  40.5ns (shipyard) to 1626.6ns (bevy) — a 40× spread on the *same* workload,
  which is the signature of a structural cost rather than a constant factor.
- **Migration.** `add_remove_component` adds then removes one component on 10k
  entities, forcing every one of them through a full row copy twice. legion pays
  1467220ns for it; planck_ecs, which is not archetype-based, pays 40361.6ns.
  A 36× spread, again on identical work.

Those two entries are not incidental. They are the archetype tax, isolated.

## The std/store model

A store is declared with a fixed schema and instantiated at a runtime moment
(`DESIGN.md`, "What std/store is"). Columns are typed and stored as
struct-of-arrays — **MEASURED**: a four-column store emits four independent
arrays and writes them individually.

```zig
__koru_store_ents.px[__koru_new_row] = px;
__koru_store_ents.vx[__koru_new_row] = vx;
__koru_store_ents.py[__koru_new_row] = py;
__koru_store_ents.vy[__koru_new_row] = vy;
```

There is no component set, so there is nothing to belong to and nothing to
migrate between. **O13 (RULED 2026-07-04): capability is DATA, never schema
membership.** The ruling dissolves the archetype's two jobs by replacing them
with two different mechanisms — and this is the part that matters for reading
the board honestly, because **only one of the two is built.**

### Job one — presence. BUILT, because it needed nothing built.

O13 rules that component-presence becomes a predicate column: the query planner
chooses per-query between an in-loop branch (when the predicate is
selective-high) and a maintained sparse view (when selective-low). The archetype
is described as a coarser, global, always-on version of that same trade, paid
for with migration and fragmentation.

There is no presence mechanism in `koru_std/store.kz` — no alive-bit, no
predicate-column feature, nothing named for the job. **That is the ruling
working, not the ruling missing.** "Capability is DATA, never schema membership"
means a predicate column is an *ordinary column*, and membership is an ordinary
guard. Nothing needs to be added because nothing is special.

**MEASURED** — `add_remove_component` runs today, as a whole workload,
`690_122_presence_column_add_remove`:

```koru
std/store:new(ents, capacity: 8) { hp: i64, frozen: i64 }

std/store:sweep(ents)
! sweep a |> std/store:stored { a.frozen: 1 }

std/store:sweep(ents)
! sweep b when b.frozen == 1 |> std/io:print.ln("frozen {{ b.hp:d }}")

std/store:sweep(ents)
! sweep c |> std/store:stored { c.frozen: 0 }
```

Set the bit, the guarded sweep matches; clear it, the guarded sweep matches
nothing; the rows never move. In an archetype engine both of those writes are
O(C) row migrations between tables. Here they are one integer store each.

`fragmented_iter` runs too — `690_121_twenty_six_component_stores` declares 26
stores in one program, sweeps and reads back every one.

**What is genuinely absent is the planner half.** Today presence is *always* the
in-loop branch: a `when` guard evaluated per row. The maintained sparse view —
the alternative the planner is supposed to choose when the predicate is
selective-low — does not exist, and neither does the planner that would choose
between them. That is rung 3.

So the honest form is narrower than "O13 is unbuilt" and more interesting: the
part of O13 that dissolves the archetype is real and running; the part that
*optimises the dissolved form* is not. Both category-boundary entries are
falsifiable right now.

### Job two — fusion. BUILT.

The second half of O13 is the one neither ECS camp has. Because subscriptions
are compiled rather than registered at runtime, all the standing rules over a
store can be served by **one** pass over the corpus. S archetype systems are S
bandwidth-bound passes over overlapping columns; one fused stripe is one corpus
read regardless of how many queries there are.

**MEASURED: this exists.** `koru_std/store.kz:3165` emits a `__store_stripe_<s>`
unit that fires the standing rules, and `:1477` builds a `stripe_order` so the
rules run in dependency order within the single pass.

The honest caveat is that `simple_iter` — the entry we are closest to being able
to run — is the **single-query base case, where fusion gives no edge at all**.
The README already says this: it is the baseline we must match, and the falsifier
for the iteration contract. Fusion's advantage, if it is real, shows up on
`schedule` (three systems, overlapping on a component), which is rung 4.

`690_123_overlapping_systems_compose_sequentially` pins how far that gets today:
three sweeps overlapping on a column compose in order, and later systems see
earlier writes. What has no spelling to even ask for is the outer parallelism —
the disjointness-proof scheduling that is the no-threads bet itself.

## What the iteration path actually emits today

For `stored { e.px: e.px + e.vx }` inside a sweep — the single-column half of
`simple_iter` — the emitted loop is:

```zig
var __koru_si: usize = 0;
while (__koru_si < __koru_store_ents.len) : (__koru_si += 1) {
    handler(.{ .__koru_srow_e_L11 = __koru_store_ents.__koru_handle_of(__koru_si) });
}
```

**MEASURED**, three things, all in that one loop:

1. **It is a `while`.** This is the sweep loop — the hottest loop the language
   has — and `CLAUDE.md` names it directly: `for (0..n) |i|` hands the optimizer
   a known trip count, `while (i < len) : (i += 1)` hands it a mutable induction
   variable and a loop-carried condition.

2. **The loop converts its dense index to a generational handle, and the body
   converts it straight back — three times.** `__koru_handle_of(si)` packs
   slot+generation out of `__koru_row_hslot[si]` and `__koru_hslot_gen[slot]`;
   then `__koru_resolve` runs twice in the read expression (once per column
   read) and once more inside the write handler. Each resolve walks
   `__koru_hslot_gen[slot]` → compare → `__koru_hslot_row[slot]`, and carries
   two `@panic` sites for the stale-handle trap.

   It is provably the identity. The loop built the handle out of `si` on the
   line above, and a sweep iterates rows it can see, so staleness is impossible
   by construction. The read-only sweep path already skips all of it and emits
   `x[si]` directly.

3. **The read-only path is already clean.** Whatever this costs, it is the
   *write* path specifically.

**The measurement disagreed with this section, and it was right to.**

The previous revision said we were not claiming the round-trip blocks
vectorization — the body is all `pub inline fn`, so LLVM might fold it. That was
the correct caution and it was aimed at the wrong thing. The cost is not a
missed vectorization. It is far larger and entirely mechanical.

A store's columns are fixed-size arrays held **by value** inside one global
struct. So `__koru_store_ents.px` is an 80,000-byte aggregate when capacity is
10,000 f64, and the sweep read is emitted as:

```zig
__koru_store_ents.px[__koru_store_ents.__koru_resolve(h)]
  + __koru_store_ents.vx[__koru_store_ents.__koru_resolve(h)]
```

The index is a *call on the same mutable global*, evaluated after the array
field is named. Zig must therefore materialise the whole column before applying
the index — **MEASURED**: `sample` puts ~100% of runtime in `_platform_memmove`,
and the disassembly shows two `memcpy`s of `0x13880` = 80,000 bytes **per row**.
That is ~1.6 GB moved per pass over 10,000 rows.

The store's own apply path is immune, and the contrast is the proof: it hoists
first, then indexes.

```zig
const __koru_r = __koru_store_ents.__koru_resolve(row);
__koru_store_ents.px[__koru_r] = value_0;
```

**Controlled probe:** hand-hoisting the resolve into a temporary in the emitted
Zig, changing nothing else, moved one pass from ~23,300,000 ns to ~13,333 ns —
a factor of roughly 1750, from emit shape alone. Nothing about the store's
design is implicated. The read path simply names the array before it computes
the index.

**Fixed, and re-measured on a quiet machine.** The store's write family now
takes a dense row, so a sweep arm passes its loop index straight through and
there is no resolve left to hoist. The one-column slice went from ~23,900,000
ns/iter to **4233 ns/iter**, and the full three-column `pos += vel` — which
could not be compiled at all before the envelope learned the row head — now
measures **11016 ns/iter**. Both at koru `0251b57b`, load average 7.3, five
process runs each, checksum oracle verified on every run.

The `while` in the sweep loop is still there and still worth fixing.

## Reading the board

| entry | comparable? | why |
|---|---|---|
| `simple_iter` | **yes, ballpark** | Same operation, both sides dense SoA. Single query, so fusion is neutral — the fairest entry on the board. |
| `simple_insert` | yes, once compound columns exist | vec3/mat4x4 columns are a substrate gap, not a model difference. |
| `heavy_compute` | yes, once expressible | Compute-bound; mostly Zig codegen quality, and the kernels board is already at C-parity on 4 of 6. |
| `fragmented_iter` | **no — category boundary** | Measures a cost the model refuses to have. Runnable today (690_121); never quoted as a win. |
| `add_remove_component` | **no — category boundary** | Their operation is an O(C) row migration; ours is one integer write per row. Same name, categorically different operation. Runnable today (690_122). |
| `schedule` | not yet | Rung 4. Also the fusion stress case — the three systems overlap on a component, so naive fusion is illegal and it forces stratified firing. |
| `serialize` | not yet | The whole-store serialization hole; no save/load verb exists. |

## The claims rule, restated

Their numbers are criterion medians. Ours are an in-process Koru timing loop.
Same machine, same workload, **different instrument**. Both are per-iteration
nanoseconds, which makes them dimensionally comparable and nothing more.

No comparative word — beats, matches, on par, competitive — leaves this repo
until the instruments are reconciled. Until then the board publishes numbers
with their instruments named, side by side, and lets the reader do the
comparing. The two category-boundary entries never get a win-quote at all,
whatever they measure.
