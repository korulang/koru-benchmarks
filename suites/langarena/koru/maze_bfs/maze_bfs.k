// maze_bfs — LangArena Maze::BFS, run.js scored parameters
// (w=1400, h=1400, iterations=70, warmup=14 -> 84 BFS runs over one
// generated maze; checksum = sum(path.size) + mid.x*mid.y of the last
// path's middle cell = 2906799).
//
// FAITHFULNESS DIFFS vs the original port (all checksum-exact):
//
// * cells {k: u8 kind, p: i32 packed state}. p merges the reference's
//   visited flag and came-from link into ONE i32 per cell:
//     -2           = not walkable (wall 0 / border 4 — never touched)
//     -1           = carved open, not yet visited
//     e*2^21 + q+1 = visited in run epoch e (et = st.epoch*2097152),
//                    parent cell q = @rem(p, 2097152) - 1
//   The BSL test `p != -2 and p < et` is exactly `kind in 1..3 and
//   vis != epoch`: p == -2 <=> kind wall/border (every carve writes
//   p := -1 alongside k := 1; start/finish seeded -1), and p >= et
//   <=> already pushed this run. -1 and -2 can never read as
//   "visited" since any visited encoding is >= 2^21. plen/pback
//   decode the parent with @rem(p, 2097152) - 1 — the reference's
//   pt[..].p chain, node-identical, with the start cell's stored
//   e*2^21 decoding to -1 to end the chain.
// * nb.n is `0[cells]` — a certified index (u21): the write pays the
//   bounds check, reads `cells[nb[..].n].*` re-collect no floor.
//   q.c is u32; qs/ck/cp are borrowed slices so the hot reads/writes
//   emit raw indexed accesses. nb itself keeps dynamic indexing
//   (mswap needs it) and stays a grid — see compiler note below.
// * The BFS queue holds CELL ids, not path-record ids: the reference's
//   path-id->record->cell indirection is p[] indexed by cell directly.
//   Same traversal order; st.fin is now the scanning CELL (was the
//   record id) — plen/pback chains are node-identical.
// * bwalk carries (qh, qt, et) in tor params — registers, no store
//   round-trips (st.qh/qt/pn/pv2 gone). Each pop scans the four
//   neighbor slots as straight-line bsl calls at static nb offsets
//   cc*4+k; a negative qt propagates the found sentinel through the
//   remaining slots of the same pop.
// * Construction is a register-carried self-loop mkg(cc, x, last):
//   `last` rides a param (not st.last memory) and is stored back at
//   the end. Each draw is integer `@divTrunc(l * 4, 139968)` — EXACTLY
//   equal to the reference's `trunc(l/139968.0 * 4.0)` for l in
//   [0,139968): the f64 computation can only err < 2^-53 relative,
//   while the exact value is either an integer or >= 4/139968 away
//   from one, so trunc agrees on all 15.6M draws.
// * digw carries qn in a param and counts walkable neighbors with a
//   select chain (if-exprs) instead of st.cnt RMW — the reference
//   evaluates all four neighbors (filter().count()) too. Each carve
//   stamps p := -1, which IS the visited-init of the packed encoding.
// * Walkable test `k -% 1 <= 2`: exact for k in {0,1,2,3,4} (u8
//   wrapping: 0->255, 4->3), one compare instead of two.
// * fr narrowed {c: 0[cells], k: u8} — cold (ensure_open_finish depth
//   is 0 at these seeds) but free.
//
// FALSIFIED / MEASURED — min-of-5 whole-process /usr/bin/time, same
// build flags, checksum 2906799 green on every step:
// * 0.50s port -> 0.40 v2 row-layout {k,e,p} + register params ->
//   0.36 v3 column layout + u32 queue — AoS travel-together falsified:
//   BFS scans fields one at a time, column wins.
// * 0.36 -> 0.32 v4: four statically-spelled bsl slots beat the
//   tail-lowered k<4 slot recursion (static nb offsets, no loop arm).
// * 0.32 -> 0.30 v5: borrowed slices on the hot ordinary columns beat
//   grid reads (raw indexed access, no bounds path).
// * 0.30 -> 0.24 v6: merging kind-walkable + visit-epoch + parent
//   into ONE i32 column halves BFS (phase timing ~258 -> ~156ms).
// * `std/grid:slice` on a `0[cells]` certified field FAILS to emit —
//   "use of undeclared identifier '__koru_idx_cells'". Compiler bug,
//   reported not fixed; nb stayed a certified grid.
// * Reasoned, not benched: nb as plain u32 would lose certification
//   and re-floor every cells[nb[..].n] read — the same `and` it saves.
// * Grammar note: `|>` continuations are column-scoped; sequential
//   conditionals are call steps (pushw2/gdig/geof) keeping the chain
//   flat. Grid reads in produce exprs go through call args (idv).

import std/io
import std/grid
import std/store

std/grid:new(cells, size: 1960000) { k: 0[u8], p: -2[i32] }
std/grid:new(nb, size: 7840000) { n: 0[cells] }
std/grid:new(q, size: 2000000) { c: 0[u32] }
std/grid:new(fr, size: 2000000) { c: 0[cells], k: 0[u8] }

std/grid:slice(ck) { cells.k }
std/grid:slice(cp) { cells.p }
std/grid:slice(qs) { q.c }
std/store:new(st) { last: 42[i64], acc: 0[i64], fnz: 0[i64], c: 0[i64], cnt: 0[i64], t1: 0[i64], epoch: 0[i64], fin: 0[i64], mid: 0[i64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// idv — produce a computed value (routes the expression through a call
// arg so grid reads lower; also hosts recipe-3 select steps).
pub tor idv { v: i64 } -> i64
idv = ret0(): _ -> v

pub tor fpp { } -> i64
fpp = std/store:stored { st.fnz: st.fnz + 1 }: _ -> 0

// wone — increment st.cnt if cell c is walkable (kind 1..3).
// (ensure_open_finish path only — cold at these seeds.)
pub tor wone { c: i64 } -> i64
wone = if(ck[@as(usize, @intCast(c))] -% 1 <= 2)
| then |> std/store:stored { st.cnt: st.cnt + 1 }: _ -> 0
| else -> 0

// wcount — walkable-neighbor count of cell c into st.cnt
pub tor wcount { c: i64 } -> i64
wcount = std/store:stored { st.cnt: 0 }
    |> wone(c: nb[c * 4].n): _
    |> wone(c: nb[c * 4 + 1].n): _
    |> wone(c: nb[c * 4 + 2].n): _
    |> wone(c: nb[c * 4 + 3].n): _
    |> ret0(): r -> r

// pushw2 — push neighbor at nb slot b onto the dig stack if still a
// wall. b is the nb index (cell*4+k) so the pushed value stays a
// literal certified cell read (bare write, no re-check).
pub tor pushw2 { b: i64, qn: i64 } -> i64
pushw2 = if(ck[nb[b].n] == 0)
| then |> std/grid:stored { qs[qn]: nb[b].n }
    |> idv(v: qn + 1): r -> r
| else -> qn

// digw — LIFO carve loop, qn register-carried: pop; count walkable
// neighbors as a select chain; iff exactly one, carve and push walls.
pub tor digw { qn: i64 } -> i64
digw = if(qn > 0)
| then |> idv(v: @as(i64, qs[@as(usize, @intCast(qn - 1))])): cc
    |> idv(v: if (ck[nb[cc * 4].n] -% 1 <= 2) 1 else 0): n0
    |> idv(v: if (ck[nb[cc * 4 + 1].n] -% 1 <= 2) n0 + 1 else n0): n1
    |> idv(v: if (ck[nb[cc * 4 + 2].n] -% 1 <= 2) n1 + 1 else n1): n2
    |> idv(v: if (ck[nb[cc * 4 + 3].n] -% 1 <= 2) n2 + 1 else n2): n3
    |> if(n3 == 1)
        | then |> std/grid:stored { ck[@as(usize, @intCast(cc))]: 1 }
            |> std/grid:stored { cp[@as(usize, @intCast(cc))]: -1 }
            |> pushw2(b: cc * 4, qn: qn - 1): q1
            |> pushw2(b: cc * 4 + 1, qn: q1): q2
            |> pushw2(b: cc * 4 + 2, qn: q2): q3
            |> pushw2(b: cc * 4 + 3, qn: q3): q4
            |> digw(qn: q4): r -> r
        | else |> digw(qn: qn - 1): r -> r
| else -> 0

// gdig — the reference's `dig(n) if n.kind.wall?`
pub tor gdig { c: i64 } -> i64
gdig = if(ck[@as(usize, @intCast(c))] == 0)
| then |> std/grid:stored { qs[0]: @as(u32, @intCast(c)) }
    |> digw(qn: 1): r -> r
| else -> 0

// echild — one slot of a frame's neighbor scan (frame stack retained;
// depth is 0 at these seeds).
pub tor echild { c: i64, k: i64 } -> i64
echild = std/grid:stored { fr[st.fnz - 1].k: @as(u8, @intCast(k + 1)) }
    |> if(ck[nb[c * 4 + k].n] == 0)
        | then |> std/grid:stored { ck[nb[c * 4 + k].n]: 1 }
            |> std/grid:stored { cp[nb[c * 4 + k].n]: -1 }
            |> wcount(c: nb[c * 4 + k].n): _
            |> if(st.cnt <= 1)
                | then |> std/grid:stored { fr[st.fnz].c: nb[c * 4 + k].n }
                    |> std/grid:stored { fr[st.fnz].k: 0 }
                    |> fpp(): r -> r
                | else -> 0
        | else -> 0

// eofw — ensure_open_finish as an explicit frame stack (tail-lowered)
pub tor eofw { } -> i64
eofw = if(st.fnz > 0)
| then |> std/store:stored { st.c: @as(i64, fr[st.fnz - 1].c) }
    |> std/store:stored { st.cnt: @as(i64, fr[st.fnz - 1].k) }
    |> if(st.cnt == 4)
        | then |> std/store:stored { st.fnz: st.fnz - 1 }
            |> eofw(): r -> r
        | else |> echild(st.c, k: st.cnt): _
            |> eofw(): r -> r
| else -> 0

// geof — the reference's `ensure_open_finish(n) if n.kind.wall?`
pub tor geof { c: i64 } -> i64
geof = if(ck[@as(usize, @intCast(c))] == 0)
| then |> std/grid:stored { ck[@as(usize, @intCast(c))]: 1 }
    |> std/grid:stored { cp[@as(usize, @intCast(c))]: -1 }
    |> wcount(st.c): _
    |> if(st.cnt <= 1)
        | then |> std/grid:stored { fr[st.fnz].c: c }
            |> std/grid:stored { fr[st.fnz].k: 0 }
            |> std/store:stored { st.fnz: st.fnz + 1 }
            |> eofw(): r -> r
        | else -> 0
| else -> 0

// plen — count cells on the came-from chain from cur to -1.
pub tor plen { cur: i64, n: i64 } -> i64
plen = if(cur >= 0)
| then |> plen(cur: @rem(@as(i64, cp[@as(usize, @intCast(cur))]), 2097152) - 1, n: n + 1): r -> r
| else -> n

// pback — walk k came-from hops from cur, produce the cell landed on.
pub tor pback { cur: i64, k: i64 } -> i64
pback = if(k > 0)
| then |> pback(cur: @rem(@as(i64, cp[@as(usize, @intCast(cur))]), 2097152) - 1, k: k - 1): r -> r
| else |> idv(v: cur): r -> r

// bsl — one neighbor slot of the popped cell (b = nb index cc*4+k,
// cc = scanning cell, qt = fifo tail). Returns qt, or -1 when the
// target-as-neighbor ends the search (st.fin set; the reference never
// pushes finish). The qt<0 guard passes the found sentinel through
// the remaining slots of the same pop.
pub tor bsl { b: i64, cc: i64, qt: i64, et: i64 } -> i64
bsl = if(qt < 0)
| then -> qt
| else |> if(nb[b].n == 1958598)
    | then |> std/store:stored { st.fin: cc }
        |> ret0(): _ -> -1
    | else |> if(cp[nb[b].n] != -2 and @as(i64, cp[nb[b].n]) < et)
        | then |> std/grid:stored { cp[nb[b].n]: @as(i32, @intCast(et + cc + 1)) }
            |> std/grid:stored { qs[qt]: nb[b].n }
            |> idv(v: qt + 1): r -> r
        | else -> qt

// bwalk — fused scan/pop loop (tail-lowered): each iteration pops one
// cell and scans all four neighbor slots as straight-line bsl calls —
// static nb offsets, and the found sentinel rides qt out. All cursors
// and the epoch stride ride params (registers, no store round-trips).
pub tor bwalk { qh: i64, qt: i64, et: i64 } -> i64
bwalk = if(qh < qt)
| then |> idv(v: @as(i64, qs[@as(usize, @intCast(qh))])): cc
    |> bsl(b: cc * 4, cc, qt, et): t0
    |> bsl(b: cc * 4 + 1, cc, qt: t0, et): t1
    |> bsl(b: cc * 4 + 2, cc, qt: t1, et): t2
    |> bsl(b: cc * 4 + 3, cc, qt: t2, et): t3
    |> if(t3 >= 0)
        | then |> bwalk(qh: qh + 1, qt: t3, et): r -> r
        | else |> ret0(): r -> r
| else -> -1

// mswap — one update_neighbors shuffle round: swap nb slots i,j of
// cell c when the draws differ.
pub tor mswap { c: i64, i: i64, j: i64 } -> i64
mswap = if(i != j)
| then |> std/store:stored { st.t1: @as(i64, nb[c * 4 + i].n) }
    |> std/grid:stored { nb[c * 4 + i].n: nb[c * 4 + j].n }
    |> std/grid:stored { nb[c * 4 + j].n: st.t1 }: _ -> 0
| else -> 0

// mkg — interior cells 1401..1958598 (x in 1..1398, wrapping +3 over
// the two border cells): neighbors [up,down,right,left], then 4 rounds
// of next_int(4) pair swaps. `last` rides the param; draws are the
// exact integer form (header). Final RNG state is stored back.
pub tor mkg { cc: i64, x: i64, last: i64 } -> i64
mkg = if(cc <= 1958598)
| then |> std/grid:stored { nb[cc * 4].n: cc - 1400 }
    |> std/grid:stored { nb[cc * 4 + 1].n: cc + 1400 }
    |> std/grid:stored { nb[cc * 4 + 2].n: cc + 1 }
    |> std/grid:stored { nb[cc * 4 + 3].n: cc - 1 }
    |> idv(v: @rem(last *% 3877 +% 29573, 139968)): l1
    |> idv(v: @divTrunc(l1 * 4, 139968)): i0
    |> idv(v: @rem(l1 *% 3877 +% 29573, 139968)): l2
    |> idv(v: @divTrunc(l2 * 4, 139968)): j0
    |> mswap(c: cc, i: i0, j: j0): _
    |> idv(v: @rem(l2 *% 3877 +% 29573, 139968)): l3
    |> idv(v: @divTrunc(l3 * 4, 139968)): i1
    |> idv(v: @rem(l3 *% 3877 +% 29573, 139968)): l4
    |> idv(v: @divTrunc(l4 * 4, 139968)): j1
    |> mswap(c: cc, i: i1, j: j1): _
    |> idv(v: @rem(l4 *% 3877 +% 29573, 139968)): l5
    |> idv(v: @divTrunc(l5 * 4, 139968)): i2
    |> idv(v: @rem(l5 *% 3877 +% 29573, 139968)): l6
    |> idv(v: @divTrunc(l6 * 4, 139968)): j2
    |> mswap(c: cc, i: i2, j: j2): _
    |> idv(v: @rem(l6 *% 3877 +% 29573, 139968)): l7
    |> idv(v: @divTrunc(l7 * 4, 139968)): i3
    |> idv(v: @rem(l7 *% 3877 +% 29573, 139968)): l8
    |> idv(v: @divTrunc(l8 * 4, 139968)): j3
    |> mswap(c: cc, i: i3, j: j3): _
    |> if(x == 1398)
        | then |> mkg(cc: cc + 3, x: 1, last: l8): r -> r
        | else |> mkg(cc: cc + 1, x: x + 1, last: l8): r -> r
| else |> std/store:stored { st.last: last }: _ -> 0

// ---- construction: border ring, then interior as a self-loop -------

for(0..1400)
! each x |> std/grid:stored { ck[x]: 4 }
    |> std/grid:stored { ck[@as(usize, @intCast(1958600 + @as(i64, @intCast(x))))]: 4 }
for(1..1399)
! each y |> std/grid:stored { ck[@as(usize, @intCast(@as(i64, @intCast(y)) * 1400))]: 4 }
    |> std/grid:stored { ck[@as(usize, @intCast(@as(i64, @intCast(y)) * 1400 + 1399))]: 4 }

// start/finish
std/grid:stored { ck[1401]: 2 }
std/grid:stored { cp[1401]: -1 }
std/grid:stored { ck[1958598]: 3 }
std/grid:stored { cp[1958598]: -1 }


mkg(cc: 1401, x: 1, st.last): _

// prepare: one generate over the RNG-built maze (deterministic —
// dig/eof consume no draws).
std/store:stored { st.fnz: 0 }
gdig(c: nb[5604].n): _
gdig(c: nb[5605].n): _
gdig(c: nb[5606].n): _
gdig(c: nb[5607].n): _
geof(c: nb[7834392].n): _
geof(c: nb[7834393].n): _
geof(c: nb[7834394].n): _
geof(c: nb[7834395].n): _

// runs: 84 = 70 measured + 14 warmup. Per run: epoch bump (fresh
// packed marks — no clearing pass), seed start cell visited with the
// epoch-only encoding (decodes to parent -1), then bwalk — the
// reference's seed-record push+pop is scaffolding; traversal order is
// identical.
for(0..84)
! each _ |> std/store:stored { st.epoch: st.epoch + 1 }
    |> std/grid:stored { cp[1401]: @as(i32, @intCast(st.epoch * 2097152)) }
    |> std/grid:stored { qs[0]: 1401 }
    |> bwalk(qh: 0, qt: 1, et: st.epoch * 2097152): found
    |> plen(cur: st.fin, n: 0): m
    |> pback(cur: st.fin, k: m - @divTrunc(m + 1, 2) - 1): midc
    |> std/store:stored { st.mid: midc }
    |> std/store:stored { st.acc: @rem(st.acc + m + 1, 4294967296) }

// checksum: result + mid.x * mid.y of the last path's middle cell
std/io:print.ln("{{ @rem(st.acc + @rem(st.mid, 1400) * @divTrunc(st.mid, 1400), 4294967296):d }}")
