// maze_astar — LangArena Maze::AStar, run.js scored parameters
// (w=1400, h=1400, iterations=70, warmup=14 -> 84 A* runs over one
// generated maze; checksum = sum(path.size) + mid.x*mid.y of the last
// path's middle cell = 2906799).
//
// Heuristic is Manhattan to finish (1398,1398): every walkable cell
// has x,y <= 1398, so h(n) = 2796 - x - y with no abs needed.
//
// The maze is RNG-driven once at construction: each interior cell's
// neighbor list [up,down,right,left] is shuffled by 4 rounds of
// next_int(4) pair swaps — ~15.6M draws at this size, and the
// resulting per-cell order is what shapes dig()'s carving. Koru
// shape: cells are a kind grid indexed y*w+x; nb[cell*4+k] holds the
// shuffled neighbor index (the reference's per-cell neighbor array).
//
// dig is the reference's LIFO stack verbatim — pop, carve to space
// iff exactly one neighbor is walkable, push wall neighbors
// (duplicates allowed, they skip on pop). ensure_open_finish is
// recursive in the reference; here it's an explicit frame stack
// (fr: {cell, next neighbor slot}) replaying the same descent —
// depth is 0 at these seeds but the frame form is faithful anyway.
//
// Grammar note: `|>` continuations are column-scoped — a step after
// an `if`'s arms must align with the `| then`/`| else` column, not the
// `|> if` column (misaligned => KORU010). Sequential conditionals are
// instead call steps (pushw/gdig/geof), keeping the chain flat.
//
// OPTIMIZATION HISTORY — all timings whole-process /usr/bin/time -p,
// min-of-5, same box; checksum 2906799 at every stage.
//  baseline (straight port): ~0.67s.  Rust ref ~0.543s.
//  phase split (std/time probes, /tmp/ma_probe3.k): construction
//    ~90ms, per-run gs/bf resets 56ms, A* walk ~523ms — walk first.
//  stage A (storage + register carries): ~0.46-0.48s.
//   - nb.n -> u32; q.c, fr.c, hp.v -> 0[kind]; fr.k -> 0[u8];
//     cf.p -> -1[i32]; hp.p/gs.g/bf.f -> u32/i32-class widths.
//     Halved footprint on every random-access array.
//   - awalk carries popped cell in param v; lp/lv hole values ride
//     hdn params; digw binds popped cell via idu (not st.c).
//   - hdn fused to ONE self-loop tor (mutual hdn/hdnl/hdnr/hdnc
//     tails did not lower — one real frame per sift level; the
//     stale-hole pop quirk is preserved verbatim).
//   - wcount's st.cnt accumulator -> wcnt pure register sum.
//   - nxt: floor(last*4/139968) as integer @divTrunc — exact for
//     last in [0,139968) (correctly-rounded f64 division cannot
//     cross an integer boundary on this range).
//  stage B (epoch encoding): ~0.44s.  gs/bf store enc(x)=epo-x
//    with epo stepping 2^22 per run — stale reads compare low
//    without any reset pass.  Disclosed faithfulness diff: the
//    reference's per-run vec![MAX] is semantics, not mechanism;
//    reachable behavior is identical (see apush).
//  stage C (borrowed slices): ~0.41-0.43s.  std/grid:slice raw
//    columns on every hot array; bounds obligations carried by
//    the program (kind-certified writes, hs-bounded heap).
//  stage D (walkability bit): ~0.39-0.40s.  kind is frozen after
//    generate, so the bake pass folds walkable(n) into nb.n bit 31;
//    the scan arm is one load + tbnz (verified in emitted asm:
//    the 4-neighbor scan unrolls to raw ldr/tbnz sequences).
//  stage E (u32 heap machinery + hs register carry): neutral-to-
//    noise (~0.39-0.40s under load).  Kept: hup/hdn sift indices
//    u32, heap size rides awalk's hs param through apush returns.
//
//  WORKLOAD measured (/tmp/ma_probe5.k): 84 runs pop/push/
//  g-update 13,618,584 / 13,619,844 / 13,619,844 — ~162K heap ops
//  per run; the walk is heap-churn-bound, not bounds-check-bound.
//
//  FALSIFIED hypotheses (tested, measured, reverted):
//   - packed u64 heap word (priority<<32|vertex, one column):
//     first attempt also mis-tied on the vertex — corrected to
//     compare the priority high word only, still 0.42-0.43s vs
//     0.39s for two columns; the single 8-byte load per heap node
//     lost to two independent 4-byte columns.  Reverted.
//   - best_f elimination: bf is PROVABLY a no-op gate here —
//     pushes == gs-updates exactly (13,619,844 both) because
//     bf[n] == gs[n]+h(n) always (pushes and g-writes are 1:1 and
//     strictly decreasing, f = g+h(n) with fixed h).  Removing
//     the load+compare+store still measured 0.42s vs 0.39s: the
//     extra branch shaped LLVM's layout of the hot arm for the
//     better.  Kept as a redundant-but-profitable gate.
//   - moving heuristic h inside the gs-gate: h's div/rem latency
//     was being hidden behind the gate load when computed
//     speculatively; sinking it serialized it onto the push path
//     (0.41-0.44s).  Reverted — compute h unconditionally.
//   - construction-slice tightening: no measurable gain.
//   - a no-walk probe showing ~0.11s "construction" was invalid:
//     with the walk removed LLVM dead-coded the reset writes;
//     std/time phase instrumentation is the honest split above.
//
//  Compiler/toolchain notes (proposals only — no toolchain edits):
//   - mutual tail calls between tors do not lower; only self-loop
//     tails do.  Fusing sifts into self-loops is manual work the
//     backend could in principle do.
//   - std/grid:slice of a certified-index column (0[kind]) emits
//     an undeclared __koru_idx_kind element type; the workaround
//     here is declaring sliced columns u32 with explicit casts.
//   - redundant explicit labels (`c: c`) parse as PARSE005; the
//     punning form must be used.
//
import std/io
import std/grid
import std/store

std/grid:new(kind, size: 1960000) { k: 0[u8] }
std/grid:new(nb, size: 7840000) { n: 0[u32] }
std/grid:new(q, size: 2000000) { c: 0[u32] }
std/grid:new(fr, size: 2000000) { c: 0[kind], k: 0[u8] }
std/grid:new(cf, size: 1960000) { p: -1[i32] }
std/grid:new(gs, size: 1960000) { g: 0[u32] }
std/grid:new(bf, size: 1960000) { f: 0[u32] }
std/grid:new(hp, size: 2000000) { p: 0[u32], v: 0[u32] }
std/store:new(st) { last: 42[i64], acc: 0[i64], qn: 0[i64], fnz: 0[i64], c: 0[i64], cnt: 0[i64], mid: 0[i64], epo: 2097152[i64] }

// borrowed columns — the walk's access patterns are all provably
// in-range (cell indices are interior/border-validated at their
// writes; heap indices are bounded by awalk's hs param), so the
// per-access floor is declined here and carried by the program.
std/grid:slice(ks) { kind.k }
std/grid:slice(nbs) { nb.n }
std/grid:slice(qs) { q.c }
std/grid:slice(cfs) { cf.p }
std/grid:slice(gss) { gs.g }
std/grid:slice(bfs) { bf.f }
std/grid:slice(hps) { hp.p }
std/grid:slice(hvs) { hp.v }

pub tor idv { v: i64 } -> i64
idv -> v

pub tor idu { v: u32 } -> u32
idu -> v

pub tor idz { v: usize } -> usize
idz -> v

// nxt — one Helper.next_int(4) draw (advances st.last, returns the
// value; integer form of trunc(last*4/139968), exact on last's range)
pub tor nxt { } -> u32
nxt = std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }: _ -> @as(u32, @intCast(@divTrunc(st.last * 4, 139968)))

pub tor fpp { } -> i64
fpp = std/store:stored { st.fnz: st.fnz + 1 }: _ -> 0

// wcnt — walkable-neighbor count of cell c (kind 1..3), raw slice
// reads throughout
pub tor wcnt { c: u32 } -> u32
wcnt = idu(v: if(ks[nbs[c * 4]] >= 1 and ks[nbs[c * 4]] <= 3) @as(u32, 1) else 0): a
    |> idu(v: if(ks[nbs[c * 4 + 1]] >= 1 and ks[nbs[c * 4 + 1]] <= 3) @as(u32, 1) else 0): b
    |> idu(v: if(ks[nbs[c * 4 + 2]] >= 1 and ks[nbs[c * 4 + 2]] <= 3) @as(u32, 1) else 0): d
    |> idu(v: if(ks[nbs[c * 4 + 3]] >= 1 and ks[nbs[c * 4 + 3]] <= 3) @as(u32, 1) else 0): e
    |> idu(v: a + b + d + e): r -> r

// pushw — push c onto the dig stack if it is still a wall
pub tor pushw { c: u32 } -> i64
pushw = if(ks[c] == 0)
| then |> std/grid:stored { qs[st.qn]: c }
    |> std/store:stored { st.qn: st.qn + 1 }: _ -> 0
| else -> 0

// digw — LIFO carve loop (tail-lowered): pop; if exactly one
// neighbor is walkable, carve to space and push wall neighbors.
// The popped cell rides the idv-bound c, not a store field.
pub tor digw { } -> i64
digw = if(st.qn > 0)
| then |> std/store:stored { st.qn: st.qn - 1 }
    |> idu(v: qs[@intCast(st.qn)]): c
    |> wcnt(c): cnt
    |> if(cnt == 1)
        | then |> std/grid:stored { ks[c]: 1 }
            |> pushw(c: nbs[c * 4]): _
            |> pushw(c: nbs[c * 4 + 1]): _
            |> pushw(c: nbs[c * 4 + 2]): _
            |> pushw(c: nbs[c * 4 + 3]): _
            |> digw(): r -> r
        | else |> digw(): r -> r
| else -> 0

// gdig — the reference's `dig(n) if n.kind.wall?`
pub tor gdig { c: u32 } -> i64
gdig = if(ks[c] == 0)
| then |> std/grid:stored { qs[st.qn]: c }
    |> std/store:stored { st.qn: st.qn + 1 }
    |> digw(): r -> r
| else -> 0

// echild — one slot of a frame's neighbor scan: mark wall children
// space, then push a frame iff the child still has <=1 walkable
// neighbor (the reference's early return).
pub tor echild { c: i64, k: i64 } -> i64
echild = std/grid:stored { fr[st.fnz - 1].k: @as(u8, @intCast(k + 1)) }
    |> if(kind[nb[c * 4 + k].n].k == 0)
        | then |> std/grid:stored { kind[nb[c * 4 + k].n].k: 1 }
            |> wcnt(c: nb[c * 4 + k].n): cnt
            |> if(cnt <= 1)
                | then |> std/grid:stored { fr[st.fnz].c: nb[c * 4 + k].n }
                    |> std/grid:stored { fr[st.fnz].k: 0 }
                    |> fpp(): r -> r
                | else -> 0
        | else -> 0

// eofw — ensure_open_finish as an explicit frame stack (tail-lowered)
pub tor eofw { } -> i64
eofw = if(st.fnz > 0)
| then |> std/store:stored { st.c: fr[st.fnz - 1].c }
    |> std/store:stored { st.cnt: fr[st.fnz - 1].k }
    |> if(st.cnt == 4)
        | then |> std/store:stored { st.fnz: st.fnz - 1 }
            |> eofw(): r -> r
        | else |> echild(st.c, k: st.cnt): _
            |> eofw(): r -> r
| else -> 0

// geof — the reference's `ensure_open_finish(n) if n.kind.wall?`:
// mark space, then push a scan frame iff the cell has <=1 walkable
// neighbor (else the call returns without scanning).
pub tor geof { c: i64 } -> i64
geof = if(kind[c].k == 0)
| then |> std/grid:stored { kind[c].k: 1 }
    |> wcnt(c: @as(u32, @intCast(c))): cnt
    |> if(cnt <= 1)
        | then |> std/grid:stored { fr[st.fnz].c: c }
            |> std/grid:stored { fr[st.fnz].k: 0 }
            |> std/store:stored { st.fnz: st.fnz + 1 }
            |> eofw(): r -> r
        | else -> 0
| else -> 0

// plen — path length = came_from chain from finish to -1.
pub tor plen { cur: i64, n: i64 } -> i64
plen = if(cur >= 0)
| then |> plen(cur: cfs[@intCast(cur)], n: n + 1): r -> r
| else -> n

// pback — walk k came_from hops from cur, produce the cell index.
pub tor pback { cur: i64, k: i64 } -> i64
pback = if(k > 0)
| then |> pback(cur: cfs[@intCast(cur)], k: k - 1): r -> r
| else -> cur

// hup — priority-queue sift-up: copy parents down while their
// priority strictly exceeds the new entry's (stable on ties).
pub tor hup { i: u32, v: u32, p: i64 } -> i64
hup = if(i > 0)
| then |> if(hps[@divTrunc(i - 1, 2)] > p)
    | then |> std/grid:stored { hps[i]: hps[@divTrunc(i - 1, 2)] }
        |> std/grid:stored { hvs[i]: hvs[@divTrunc(i - 1, 2)] }
        |> hup(i: @divTrunc(i - 1, 2), v, p): r -> r
    | else |> std/grid:stored { hps[i]: @as(u32, @intCast(p)) }
        |> std/grid:stored { hvs[i]: v }: _ -> 0
| else |> std/grid:stored { hps[0]: @as(u32, @intCast(p)) }
    |> std/grid:stored { hvs[0]: v }: _ -> 0

// hdn — the reference pop()'s sift-down as ONE self-loop, quirk
// included: children are compared against the STALE hole value at i
// (not the parked lp), so the loop can move at most one level before
// the moved child's own value wins and lp lands in its slot. lp/lv
// ride params; s1/s2 are the level's smallest-child picks.
pub tor hdn { i: u32, hs: u32, lp: i64, lv: u32 } -> i64
hdn = idu(v: if(2 * i + 1 < hs and hps[2 * i + 1] < hps[i]) 2 * i + 1 else i): s1
    |> idu(v: if(2 * i + 2 < hs and hps[2 * i + 2] < hps[s1]) 2 * i + 2 else s1): s2
    |> if(s2 == i)
        | then |> std/grid:stored { hps[i]: @as(u32, @intCast(lp)) }
            |> std/grid:stored { hvs[i]: lv }: _ -> 0
        | else |> std/grid:stored { hps[i]: hps[s2] }
            |> std/grid:stored { hvs[i]: hvs[s2] }
            |> hdn(i: s2, hs, lp, lv): r -> r

// apush — came_from/g_score/best_f update + conditional push for
// neighbor n of current cell v. Returns to awalk rather than
// continuing it — mutual tail calls do not lower, so apush must be a
// leaf or the walk nests one real frame per push.
//
// gs/bf hold EPOCH-INVERTED encodings, not raw scores: enc(x) =
// st.epo - x with st.epo = run*2^22 + 2^21 (epo advances 2^22 per
// run, g < 1.96M < 2^21 so enc stays positive and strictly
// anti-ordered inside a run). A stale cell from an earlier run reads
// <= (run-1)*2^22 + 2^21 < any fresh enc, so `gs[n].g + 1 < eg` is
// exactly `g_v+1 < g_n` for fresh n AND always true for stale n —
// the i32::MAX sentinel is absorbed into the encoding and the 84
// 2M-cell reset loops disappear (a disclosed faithfulness diff; the
// reference's per-run `vec![MAX]` is semantics, not mechanism).
pub tor apush { v: usize, n: u32, eg: u32, hs: u32 } -> i64
apush = idu(v: 2796 - @rem(n, 1400) - @divTrunc(n, 1400)): h
    |> if(gss[n] + 1 < eg)
        | then |> std/grid:stored { cfs[n]: @as(i32, @intCast(v)) }
            |> std/grid:stored { gss[n]: eg - 1 }
            |> if(bfs[n] < eg - 1 - h)
                | then |> std/grid:stored { bfs[n]: eg - 1 - h }
                    |> hup(i: hs, v: n, p: st.epo - @as(i64, eg) + 1 + @as(i64, h)): _
                    |> idu(v: hs + 1): r -> @as(i64, r)
                | else -> @as(i64, hs)
        | else -> @as(i64, hs)

// awalk — fused pop/scan state machine (tail-lowered). k < 0 pops the
// heap (stale-hole pop preserved); k >= 0 scans neighbor slot k of
// the popped cell, which rides param v — no store round-trip.
// Popping finish ends the search — it is never pushed.
// awalk { v, k, eg, hs } — v popped cell, k neighbor slot (99 = pop
// arm), eg = gss[v] bound once per pop, hs = live heap size (register
// carried instead of the old st.hsz round-trips; it stays honest —
// it indexes hps/hvs writes on every push and sift).
pub tor awalk { v: usize, k: u32, eg: u32, hs: u32 } -> i64
awalk = if(k == 99)
| then |> if(hs == 0)
    | then -> -1
    | else |> idu(v: hvs[0]): pv
        |> if(pv == 1958598)
            | then -> 1
            | else |> if(hs > 1)
                | then |> hdn(i: 0, hs: hs - 1, lp: hps[hs - 1], lv: hvs[hs - 1]): _
                    |> awalk(v: pv, k: 0, eg: gss[pv], hs: hs - 1): r -> r
                | else |> awalk(v: pv, k: 0, eg: gss[pv], hs: 0): r -> r
| else |> if(k < 4)
    | then |> idu(v: nbs[v * 4 + @as(usize, k)]): nn
        |> if(nn >= 2147483648)
            | then |> apush(v, n: nn - 2147483648, eg, hs): nh
                |> awalk(v, k: k + 1, eg, hs: @as(u32, @intCast(nh))): r -> r
            | else |> awalk(v, k: k + 1, eg, hs): r -> r
    | else |> awalk(v: 0, k: 99, eg: 0, hs): r -> r

// mswap — one update_neighbors shuffle round: swap nb slots i,j of
// cell c when the draws differ. The temporary rides a bind, not a
// store field.
pub tor mswap { c: usize, i: u32, j: u32 } -> i64
mswap = if(i != j)
| then |> idu(v: nbs[c * 4 + @as(usize, i)]): t
    |> std/grid:stored { nbs[c * 4 + @as(usize, i)]: nbs[c * 4 + @as(usize, j)] }
    |> std/grid:stored { nbs[c * 4 + @as(usize, j)]: t }: _ -> 0
| else -> 0

// ---- construction: interior neighbor lists + shuffle draws -----------

// border ring
for(0..1400)
! each x |> std/grid:stored { kind[x].k: 4 }
    |> std/grid:stored { kind[1958600 + @as(i64, @intCast(x))].k: 4 }
for(1..1399)
! each y |> std/grid:stored { kind[@as(i64, @intCast(y)) * 1400].k: 4 }
    |> std/grid:stored { kind[@as(i64, @intCast(y)) * 1400 + 1399].k: 4 }

// start/finish
std/grid:stored { kind[1401].k: 2 }
std/grid:stored { kind[1958598].k: 3 }

// interior: neighbors [up,down,right,left], then 4 rounds of
// next_int(4) pair swaps — same draw stream as the reference's
// update_neighbors (cell order y-outer x-inner).
for(1..1399)
! each y |> for(1..1399)
    ! each x |> idz(v: y * 1400 + x): c
        |> std/grid:stored { nbs[c * 4]: @as(u32, @intCast(c - 1400)) }
        |> std/grid:stored { nbs[c * 4 + 1]: @as(u32, @intCast(c + 1400)) }
        |> std/grid:stored { nbs[c * 4 + 2]: @as(u32, @intCast(c + 1)) }
        |> std/grid:stored { nbs[c * 4 + 3]: @as(u32, @intCast(c - 1)) }
        |> nxt(): i0
        |> nxt(): j0
        |> mswap(c, i: i0, j: j0): _
        |> nxt(): i1
        |> nxt(): j1
        |> mswap(c, i: i1, j: j1): _
        |> nxt(): i2
        |> nxt(): j2
        |> mswap(c, i: i2, j: j2): _
        |> nxt(): i3
        |> nxt(): j3
        |> mswap(c, i: i3, j: j3): _

// prepare: one generate over the RNG-built maze (deterministic —
// dig/eof consume no draws).
std/store:stored { st.qn: 0 }
std/store:stored { st.fnz: 0 }
gdig(c: nb[5604].n): _
gdig(c: nb[5605].n): _
gdig(c: nb[5606].n): _
gdig(c: nb[5607].n): _
geof(c: nb[7834392].n): _
geof(c: nb[7834393].n): _
geof(c: nb[7834394].n): _
geof(c: nb[7834395].n): _

// bake: kind is frozen after generate, so fold walkable(n) into the
// nb entry's high bit — one u32 load per scanned neighbor instead of
// a nb load + a kind load. nb.n is 0[u32] (declared above, not a
// certified index, so the high bit carries no contract); the walk
// extracts n = entry - 2^31 when the bit is set.
for(0..7840000)
! each i |> std/grid:stored { nbs[i]: nbs[i] + (if(ks[nbs[i]] >= 1 and ks[nbs[i]] <= 3) @as(u32, 2147483648) else 0) }

// runs: 84 = 70 measured + 14 warmup. Per run: advance the epoch
// base (the gs/bf "reset" is the +2^22 step — see apush), push start
// with f = h(start) = 2794, and walk. cf needs no reset: stale
// entries are unreachable behind fresh g_score gates.
for(0..84)
! each _ |> std/store:stored { st.epo: st.epo + 4194304 }
    |> std/grid:stored { hps[0]: 2794 }
    |> std/grid:stored { hvs[0]: 1401 }
    |> std/grid:stored { gss[1401]: @as(u32, @intCast(st.epo)) }
    |> std/grid:stored { bfs[1401]: @as(u32, @intCast(st.epo - 2794)) }
    |> awalk(v: 0, k: 99, eg: 0, hs: 1): _
    |> plen(cur: 1958598, n: 0): m
    |> pback(cur: 1958598, k: m - @divTrunc(m, 2) - 1): midc
    |> std/store:stored { st.mid: midc }
    |> std/store:stored { st.acc: @rem(st.acc + m, 4294967296) }

// checksum: result + mid.x * mid.y of the last path's middle cell
std/io:print.ln("{{ @rem(st.acc + @rem(st.mid, 1400) * @divTrunc(st.mid, 1400), 4294967296):d }}")
