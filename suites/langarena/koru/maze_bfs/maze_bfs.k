// maze_bfs — LangArena Maze::BFS, run.js scored parameters
// (w=1400, h=1400, iterations=70, warmup=14 -> 84 BFS runs over one
// generated maze; checksum = sum(path.size) + mid.x*mid.y of the last
// path's middle cell = 2906799).
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
// Grammar note: a `|> if` step is terminal in a tor-body chain —
// nothing may follow its arms, so sequential conditionals are call
// steps (wone/pushw/gdig/geof) and continuations live inside arms.
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
std/grid:new(vis, size: 1960000) { e: 0[i64] }
std/grid:new(pt, size: 2000000) { c: 0[i64], p: 0[i64] }
std/store:new(st) { last: 42[i64], acc: 0[i64], qn: 0[i64], fnz: 0[i64], c: 0[i64], cnt: 0[i64], t1: 0[i64], h: 0[i64], qh: 0[i64], qt: 0[i64], pn: 0[i64], epoch: 0[i64], fin: 0[i64], mid: 0[i64], pv2: 0[i64] }

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

// plen — count path records on the prev chain from cur to -1.
pub tor plen { cur: i64, n: i64 } -> i64
plen = if(cur >= 0)
| then |> plen(cur: pt[cur].p, n: n + 1): r -> r
| else -> n

// pback — walk k prev-hops from cur, produce the cell index landed on.
pub tor pback { cur: i64, k: i64 } -> i64
pback = if(k > 0)
| then |> pback(cur: pt[cur].p, k: k - 1): r -> r
| else -> pt[cur].c

// bwalk — fused pop/scan state machine (tail-lowered). pid < 0 pops
// the fifo; pid >= 0 scans neighbor slot k of record pid, in the
// reference's shuffled neighbor order. Target-as-neighbor ends the
// search immediately (the reference never pushes finish).
pub tor bwalk { pid: i64, k: i64 } -> i64
bwalk = if(pid < 0)
| then |> if(st.qh < st.qt)
    | then |> std/store:stored { st.pv2: q[st.qh].c }
        |> std/store:stored { st.qh: st.qh + 1 }
        |> bwalk(pid: st.pv2, k: 0): r -> r
    | else -> -1
| else |> if(k < 4)
    | then |> if(nb[pt[pid].c * 4 + k].n == 1958598)
        | then |> std/store:stored { st.fin: pid }
            |> ret0(): r -> r
        | else |> if(kind[nb[pt[pid].c * 4 + k].n].k >= 1 and kind[nb[pt[pid].c * 4 + k].n].k <= 3 and vis[nb[pt[pid].c * 4 + k].n].e != st.epoch)
            | then |> std/grid:stored { vis[nb[pt[pid].c * 4 + k].n].e: st.epoch }
                |> std/grid:stored { pt[st.pn].c: nb[pt[pid].c * 4 + k].n }
                |> std/grid:stored { pt[st.pn].p: pid }
                |> std/grid:stored { q[st.qt].c: st.pn }
                |> std/store:stored { st.qt: st.qt + 1 }
                |> std/store:stored { st.pn: st.pn + 1 }
                |> bwalk(pid, k: k + 1): r -> r
            | else |> bwalk(pid, k: k + 1): r -> r
    | else |> bwalk(pid: -1, k: 0): r -> r

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

// runs: 84 = 70 measured + 14 warmup. Per run: fresh visited marks
// (epoch bump), fifo of path-record ids seeded with start, and the
// fused bwalk. Path length lands in acc; the last path's middle cell
// is stashed for the checksum.
for(0..84)
! each _ |> std/store:stored { st.epoch: st.epoch + 1 }
    |> std/store:stored { st.qh: 0 }
    |> std/store:stored { st.qt: 1 }
    |> std/store:stored { st.pn: 1 }
    |> std/grid:stored { pt[0].c: 1401 }
    |> std/grid:stored { pt[0].p: -1 }
    |> std/grid:stored { q[0].c: 0 }
    |> std/grid:stored { vis[1401].e: st.epoch }
    |> bwalk(pid: -1, k: 0): found
    |> plen(cur: st.fin, n: 0): m
    |> pback(cur: st.fin, k: m - @divTrunc(m + 1, 2) - 1): midc
    |> std/store:stored { st.mid: midc }
    |> std/store:stored { st.acc: @rem(st.acc + m + 1, 4294967296) }

// checksum: result + mid.x * mid.y of the last path's middle cell
std/io:print.ln("{{ @rem(st.acc + @rem(st.mid, 1400) * @divTrunc(st.mid, 1400), 4294967296):d }}")
