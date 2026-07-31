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

### Job one — presence. DESIGNED, not built.

O13 rules that component-presence becomes a predicate column: the query planner
chooses per-query between an in-loop branch (when the predicate is
selective-high) and a maintained sparse view (when selective-low). The archetype
is described as a coarser, global, always-on version of that same trade, paid
for with migration and fragmentation.

**MEASURED: this machinery does not exist.** `koru_std/store.kz` contains no
presence, predicate-column, or alive-bit mechanism — the only two hits for those
words in 8000 lines are unrelated comments. A store's schema today is fixed at
declaration and every row has every column.

The consequence for this board is direct and should not be softened:
`fragmented_iter` and `add_remove_component` are the two entries whose entire
purpose is to validate or embarrass O13, and **neither can be run at all until
presence-as-data is built.** The refusal is currently unfalsifiable. That is a
statement about our progress, not about the ruling being right.

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
`schedule` (three systems, overlapping on a component), which is a rung-4 entry
and honestly absent.

So the two entries that would show O13 working are both out of reach, in
opposite directions: one needs a mechanism we have not built, the other needs a
rung we have not reached.

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

**What we are deliberately not claiming:** that this blocks vectorization. The
whole body is `pub inline fn` (**MEASURED** — four of them in the emitted file),
so LLVM sees through the call boundary and may well fold some or all of the
round-trip; the `switch (field)` in the write handler is dispatched on a literal
`0` and should fold entirely. Reading the emitted source tells us what we *asked
for*, not what the CPU *runs*. The ballpark measurement is what adjudicates it,
and it should be allowed to disagree with this section.

## Reading the board

| entry | comparable? | why |
|---|---|---|
| `simple_iter` | **yes, ballpark** | Same operation, both sides dense SoA. Single query, so fusion is neutral — the fairest entry on the board. |
| `simple_insert` | yes, once compound columns exist | vec3/mat4x4 columns are a substrate gap, not a model difference. |
| `heavy_compute` | yes, once expressible | Compute-bound; mostly Zig codegen quality, and the kernels board is already at C-parity on 4 of 6. |
| `fragmented_iter` | **no — category boundary** | Measures a cost the model refuses to have. Cannot be run either way until presence-as-data is built. |
| `add_remove_component` | **no — category boundary** | Their operation is an O(C) row migration; ours would be a presence-bit write. Same name, different operation. Also blocked on presence. |
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
