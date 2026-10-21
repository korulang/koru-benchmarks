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
// instead call steps (wone/pushw/gdig/geof), keeping the chain flat.
// BFS adds st.pv2 for the popped record id and reuses the dig stack
// grid q as the fifo — it is empty after generate.
//
import std/io
import std/grid
import std/store

std/grid:new(kind, size: 1960000) { k: 0[u8] }
std/grid:new(nb, size: 7840000) { n: 0[i64] }
std/grid:new(q, size: 2000000) { c: 0[i64] }
std/grid:new(fr, size: 2000000) { c: 0[i64], k: 0[i64] }
std/grid:new(cf, size: 1960000) { p: -1[i64] }
std/grid:new(gs, size: 1960000) { g: 2147483647[i64] }
std/grid:new(bf, size: 1960000) { f: 2147483647[i64] }
std/grid:new(hp, size: 2000000) { p: 0[i64], v: 0[i64] }
std/store:new(st) { last: 42[i64], acc: 0[i64], qn: 0[i64], fnz: 0[i64], c: 0[i64], cnt: 0[i64], t1: 0[i64], h: 0[i64], hsz: 0[i64], pv: 0[i64], lp: 0[i64], lv: 0[i64], sm: 0[i64], mid: 0[i64] }

// nxt — one Helper.next_int draw (advances st.last, returns the value)
pub tor nxt { max: f64 } -> i64
nxt = std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }: _ -> @as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * max))

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

pub tor qpp { } -> i64
qpp = std/store:stored { st.qn: st.qn + 1 }: _ -> 0

pub tor fpp { } -> i64
fpp = std/store:stored { st.fnz: st.fnz + 1 }: _ -> 0

// wone — increment st.cnt if cell c is walkable (kind 1..3)
pub tor wone { c: i64 } -> i64
wone = if(kind[c].k >= 1 and kind[c].k <= 3)
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

// pushw — push c onto the dig stack if it is still a wall
pub tor pushw { c: i64 } -> i64
pushw = if(kind[c].k == 0)
| then |> std/grid:stored { q[st.qn].c: c }
    |> std/store:stored { st.qn: st.qn + 1 }: _ -> 0
| else -> 0

// digw — LIFO carve loop (tail-lowered): pop; if exactly one
// neighbor is walkable, carve to space and push wall neighbors.
pub tor digw { } -> i64
digw = if(st.qn > 0)
| then |> std/store:stored { st.qn: st.qn - 1 }
    |> std/store:stored { st.c: q[st.qn].c }
    |> wcount(st.c): _
    |> if(st.cnt == 1)
        | then |> std/grid:stored { kind[st.c].k: 1 }
            |> pushw(c: nb[st.c * 4].n): _
            |> pushw(c: nb[st.c * 4 + 1].n): _
            |> pushw(c: nb[st.c * 4 + 2].n): _
            |> pushw(c: nb[st.c * 4 + 3].n): _
            |> digw(): r -> r
        | else |> digw(): r -> r
| else -> 0

// gdig — the reference's `dig(n) if n.kind.wall?`
pub tor gdig { c: i64 } -> i64
gdig = if(kind[c].k == 0)
| then |> std/grid:stored { q[st.qn].c: c }
    |> std/store:stored { st.qn: st.qn + 1 }
    |> digw(): r -> r
| else -> 0

// echild — one slot of a frame's neighbor scan: mark wall children
// space, then push a frame iff the child still has <=1 walkable
// neighbor (the reference's early return).
pub tor echild { c: i64, k: i64 } -> i64
echild = std/grid:stored { fr[st.fnz - 1].k: k + 1 }
    |> if(kind[nb[c * 4 + k].n].k == 0)
        | then |> std/grid:stored { kind[nb[c * 4 + k].n].k: 1 }
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
    |> wcount(c): _
    |> if(st.cnt <= 1)
        | then |> std/grid:stored { fr[st.fnz].c: c }
            |> std/grid:stored { fr[st.fnz].k: 0 }
            |> std/store:stored { st.fnz: st.fnz + 1 }
            |> eofw(): r -> r
        | else -> 0
| else -> 0

// plen — path length = came_from chain from finish to -1.
pub tor plen { cur: i64, n: i64 } -> i64
plen = if(cur >= 0)
| then |> plen(cur: cf[cur].p, n: n + 1): r -> r
| else -> n

// pback — walk k came_from hops from cur, produce the cell index.
pub tor pback { cur: i64, k: i64 } -> i64
pback = if(k > 0)
| then |> pback(cur: cf[cur].p, k: k - 1): r -> r
| else -> cur

// hup — priority-queue sift-up: copy parents down while their
// priority strictly exceeds the new entry's (stable on ties).
pub tor hup { i: i64, v: i64, p: i64 } -> i64
hup = if(i > 0)
| then |> if(hp[@divTrunc(i - 1, 2)].p > p)
    | then |> std/grid:stored { hp[i].p: hp[@divTrunc(i - 1, 2)].p }
        |> std/grid:stored { hp[i].v: hp[@divTrunc(i - 1, 2)].v }
        |> hup(i: @divTrunc(i - 1, 2), v, p): r -> r
    | else |> std/grid:stored { hp[i].p: p }
        |> std/grid:stored { hp[i].v: v }: _ -> 0
| else |> std/grid:stored { hp[0].p: p }
    |> std/grid:stored { hp[0].v: v }: _ -> 0

// hdnl/hdnr/hdnc — the reference pop()'s sift-down, quirk included:
// children are compared against the STALE hole value at i (not the
// parked `last`), so the loop can move at most one level before the
// moved child's own value wins and `last` lands in its slot.
pub tor hdnl { i: i64 } -> i64
hdnl = if(2 * i + 1 < st.hsz and hp[2 * i + 1].p < hp[i].p)
| then |> std/store:stored { st.sm: 2 * i + 1 }: _ -> 0
| else -> 0

pub tor hdnr { i: i64 } -> i64
hdnr = if(2 * i + 2 < st.hsz and hp[2 * i + 2].p < hp[st.sm].p)
| then |> std/store:stored { st.sm: 2 * i + 2 }: _ -> 0
| else -> 0

pub tor hdnc { i: i64 } -> i64
hdnc = if(st.sm == i)
| then |> std/grid:stored { hp[i].p: st.lp }
    |> std/grid:stored { hp[i].v: st.lv }: _ -> 0
| else |> std/grid:stored { hp[i].p: hp[st.sm].p }
    |> std/grid:stored { hp[i].v: hp[st.sm].v }
    |> hdn(i: st.sm): r -> r

pub tor hdn { i: i64 } -> i64
hdn = std/store:stored { st.sm: i }
    |> hdnl(i): _
    |> hdnr(i): _
    |> hdnc(i): r -> r

// apush — came_from/g_score/best_f update + conditional push for
// neighbor n of current cell v. Returns to awalk rather than
// continuing it — mutual tail calls do not lower, so apush must be a
// leaf or the walk nests one real frame per push.
pub tor apush { v: i64, n: i64 } -> i64
apush = if(gs[v].g + 1 < gs[n].g)
| then |> std/grid:stored { cf[n].p: v }
    |> std/grid:stored { gs[n].g: gs[v].g + 1 }
    |> if(gs[v].g + 1 + 2796 - @rem(n, 1400) - @divTrunc(n, 1400) < bf[n].f)
        | then |> std/grid:stored { bf[n].f: gs[v].g + 1 + 2796 - @rem(n, 1400) - @divTrunc(n, 1400) }
            |> hup(i: st.hsz, v: n, p: gs[v].g + 1 + 2796 - @rem(n, 1400) - @divTrunc(n, 1400)): _
            |> std/store:stored { st.hsz: st.hsz + 1 }: _ -> 0
        | else -> 0
| else -> 0

// awalk — fused pop/scan state machine (tail-lowered). k < 0 pops the
// heap (stale-hole pop preserved); k >= 0 scans neighbor slot k of
// current cell st.pv in the shuffled neighbor order. Popping finish
// ends the search — it is never pushed.
pub tor awalk { v: i64, k: i64 } -> i64
awalk = if(k < 0)
| then |> if(st.hsz == 0)
    | then -> -1
    | else |> std/store:stored { st.pv: hp[0].v }
        |> std/store:stored { st.hsz: st.hsz - 1 }
        |> if(st.pv == 1958598)
            | then -> 1
            | else |> if(st.hsz > 0)
                | then |> std/store:stored { st.lp: hp[st.hsz].p }
                    |> std/store:stored { st.lv: hp[st.hsz].v }
                    |> hdn(i: 0): _
                    |> awalk(v: st.pv, k: 0): r -> r
                | else |> awalk(v: st.pv, k: 0): r -> r
| else |> if(k < 4)
    | then |> if(kind[nb[st.pv * 4 + k].n].k >= 1 and kind[nb[st.pv * 4 + k].n].k <= 3)
        | then |> apush(v: st.pv, n: nb[st.pv * 4 + k].n): _
            |> awalk(v: st.pv, k: k + 1): r -> r
        | else |> awalk(v: st.pv, k: k + 1): r -> r
    | else |> awalk(v: 0, k: -1): r -> r

// mswap — one update_neighbors shuffle round: swap nb slots i,j of
// cell c when the draws differ.
pub tor mswap { c: i64, i: i64, j: i64 } -> i64
mswap = if(i != j)
| then |> std/store:stored { st.t1: nb[c * 4 + i].n }
    |> std/grid:stored { nb[c * 4 + i].n: nb[c * 4 + j].n }
    |> std/grid:stored { nb[c * 4 + j].n: st.t1 }: _ -> 0
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
    ! each x |> std/store:stored { st.c: @as(i64, @intCast(y)) * 1400 + @as(i64, @intCast(x)) }
        |> std/grid:stored { nb[st.c * 4].n: st.c - 1400 }
        |> std/grid:stored { nb[st.c * 4 + 1].n: st.c + 1400 }
        |> std/grid:stored { nb[st.c * 4 + 2].n: st.c + 1 }
        |> std/grid:stored { nb[st.c * 4 + 3].n: st.c - 1 }
        |> nxt(max: 4.0): i0
        |> nxt(max: 4.0): j0
        |> mswap(st.c, i: i0, j: j0): _
        |> nxt(max: 4.0): i1
        |> nxt(max: 4.0): j1
        |> mswap(st.c, i: i1, j: j1): _
        |> nxt(max: 4.0): i2
        |> nxt(max: 4.0): j2
        |> mswap(st.c, i: i2, j: j2): _
        |> nxt(max: 4.0): i3
        |> nxt(max: 4.0): j3
        |> mswap(st.c, i: i3, j: j3): _

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

// runs: 84 = 70 measured + 14 warmup. Per run the reference
// allocates fresh g_score/best_f sentinels — here reset loops —
// pushes start with f = h(start) = 2794, and walks. cf needs no
// reset: stale entries are unreachable behind fresh g_score gates.
for(0..84)
! each _ |> for(0..1960000)
    ! each i |> std/grid:stored { gs[i].g: 2147483647 }
        |> std/grid:stored { bf[i].f: 2147483647 }
    | done |> std/store:stored { st.hsz: 1 }
        |> std/grid:stored { hp[0].p: 2794 }
        |> std/grid:stored { hp[0].v: 1401 }
        |> std/grid:stored { gs[1401].g: 0 }
        |> std/grid:stored { bf[1401].f: 2794 }
        |> awalk(v: 0, k: -1): _
        |> plen(cur: 1958598, n: 0): m
        |> pback(cur: 1958598, k: m - @divTrunc(m, 2) - 1): midc
        |> std/store:stored { st.mid: midc }
        |> std/store:stored { st.acc: @rem(st.acc + m, 4294967296) }

// checksum: result + mid.x * mid.y of the last path's middle cell
std/io:print.ln("{{ @rem(st.acc + @rem(st.mid, 1400) * @divTrunc(st.mid, 1400), 4294967296):d }}")
