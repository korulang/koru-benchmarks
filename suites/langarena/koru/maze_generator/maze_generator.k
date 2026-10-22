// maze_generator — LangArena Maze::Generator, run.js scored parameters
// (w=1400, h=1400, iterations=10, warmup=2 -> 12 runs; checksum
// = sum(middle_cell.kind) + FNV-1a(space cells) = 3738188563).
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
// ---------------- wave-4 optimization notes ----------------
// Baseline port (mg_base.k): 0.54-0.61s across box states.
// This kernel: 0.20s min whole-process vs Rust reference 0.566s.
// Interleaved same-box mins: base 0.54 / opt 0.20 (~2.7x).
// All changes are representation/structure; the computation is
// step-for-step the reference's.
//
// FAITHFULNESS DIFFS (structure changed, semantics identical):
//  * digw carries `qn` (stack depth) as a tor parameter — the
//    `continue :__koru_self_loop` keeps it register-resident. The
//    baseline round-tripped st.qn through memory every pop (~3 ops).
//    st.c/st.cnt are likewise register bindings now, not store cells.
//  * digw reads each neighbor's kind ONCE per pop into k0..k3, and
//    the same reads feed BOTH the walkable count (wc4) and the push
//    wall-checks (pushk's k param). The baseline re-read
//    kind[nb[c*4+k].n] inside pushw AFTER storing kind[c]=1. Identical
//    because a cell is never its own neighbor (slots are a
//    permutation of {c-1400, c+1400, c+1, c-1}), so the store cannot
//    alias the four reads. Verified by checksum.
//  * gdig pushes its seed at q[0] and calls digw(qn:1); geof seeds
//    fr[0] similarly. The baseline read st.qn/st.fnz — always 0 at
//    those boundaries because digw/eofw drain to empty. Same trace.
//  * nx4 replaces the f64 next_int path: floor(last*4/139968) ==
//    floor(last/34992) exactly for last in [0,139968) (all draws are
//    next_int(4)), i.e. integer div-by-constant instead of
//    int->f64->mul->f64->int.
//  * Reset pass is a select-store `kind[i] = (kind[i]==1) ? 0 :
//    kind[i]` — emits cmeq+bic vectors instead of a branchy store;
//    still "Space -> Wall, everything else untouched".
//  * Field narrowing: nb 7.84M x i64 -> u32 (62.7MB -> 31.4MB);
//    q i64 -> u32; fr {i64,i64} -> {u32,u8}. kind stays u8.
//  * `| done` column note: the reset+dig chain must be bound to the
//    INNER for (indent 4, matching `! each i`) so it runs 12x; at
//    indent 0 it binds the outer for and digs once — this was a real
//    mid-development bug caught by acc=1 vs expected acc=12 (FNV
//    matched anyway since the dig is deterministic).
//
// [unsafe(bounds)] WAIVERS — disclosed, each justified:
//  * kind: every index is provably < 1960000 — cell indices originate
//    as constructor literals/arithmetic in [1,1958598] and only ever
//    travel nb->q->c unchanged; remaining indices are literals and
//    bounded loop vars. Saves ~26M floor checks (reset/FNV sweeps).
//  * nb: every index is c*4+k with k in [0,4) and c < 1960000
//    (constructor loop bound or a value that entered through the
//    constructor/mswap/dig chain), or literals 5604+k / 7834392+k.
//  * q: qn < 2000000 is not statically provable — it is MEASURED
//    (maxqn = 1958597 over all 12 runs; the program is deterministic
//    for this fixed input/seed). Waiver disclosed here.
//  fr keeps its floor (cold path; no reason to waive).
//
// FALSIFIED HYPOTHESES this wave (measured, kept out):
//  * nb as i16 DELTAS (n_k = c + d_k, d in {+-1400,+-1}; 15.7MB):
//    0.20s — identical to u32 indices. The sxtw+add per read ate the
//    footprint win; dig is not miss-bound at either size.
//  * Multi-line `+`-continued tor expressions: refused by KORU010 —
//    continuations must be one line.
//  * `| done` at column 0 binds the OUTER for (dig once, acc=1) —
//    must align under the inner `! each`.
//
// Verification artifacts under /tmp/mg_work/: mg_v4.k (this kernel
// pre-header), mg_base.k + mg_base.out + mg_baseline.txt (baseline
// port, min 0.54s), mg_maxqn.k (stack-depth probe -> 1958597),
// mg_pops.k (pops/run probe -> 5,384,888), mg_v5.k (falsified
// i16-delta variant), mg_final_verify.txt (checksum + timings).
//
import std/io
import std/grid
import std/store

[unsafe(bounds)]std/grid:new(kind, size: 1960000) { k: 0[u8] }
[unsafe(bounds)]std/grid:new(nb, size: 7840000) { n: 0[u32] }
[unsafe(bounds)]std/grid:new(q, size: 2000000) { c: 0[u32] }
std/grid:new(fr, size: 2000000) { c: 0[u32], k: 0[u8] }
std/store:new(st) { last: 42[i64], acc: 0[i64], t1: 0[i64], h: 0[i64] }

pub tor idv { v: i64 } -> i64
idv -> v

// nx4 — one Helper.next_int(4) draw as integer math:
// floor(last * 4 / 139968) == floor(last / 34992), exact for last < 139968.
pub tor nx4 { } -> i64
nx4 = std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }: _ -> @divTrunc(st.last * 4, 139968)

// wc4 — walkable-neighbor count (kind 1..3) from four preloaded kinds.
pub tor wc4 { k0: i64, k1: i64, k2: i64, k3: i64 } -> i64
wc4 -> (if (k0 >= 1 and k0 <= 3) @as(i64, 1) else 0) + (if (k1 >= 1 and k1 <= 3) @as(i64, 1) else 0) + (if (k2 >= 1 and k2 <= 3) @as(i64, 1) else 0) + (if (k3 >= 1 and k3 <= 3) @as(i64, 1) else 0)

// wcnt — walkable-neighbor count of cell c (eof path).
pub tor wcnt { c: i64 } -> i64
wcnt = wc4(k0: @as(i64, kind[nb[c * 4].n].k), k1: @as(i64, kind[nb[c * 4 + 1].n].k), k2: @as(i64, kind[nb[c * 4 + 2].n].k), k3: @as(i64, kind[nb[c * 4 + 3].n].k)): r -> r

// pushk — push c onto the dig stack iff its (pre-read) kind k is wall.
pub tor pushk { c: i64, k: i64, qn: i64 } -> i64
pushk = if(k == 0)
| then |> std/grid:stored { q[qn].c: @as(u32, @intCast(c)) }
    |> idv(v: qn + 1): r -> r
| else -> qn

// digw — LIFO carve loop; qn is register-carried across the self-loop.
// The four neighbor kinds are read once before the carve store and the
// same reads feed both the walkable count and the wall checks
// (neighbors of c are never c itself, so the reads stay current).
pub tor digw { qn: i64 } -> i64
digw = if(qn > 0)
| then |> idv(v: qn - 1): q1
    |> idv(v: @as(i64, q[q1].c)): c
    |> idv(v: c * 4): b
    |> idv(v: @as(i64, kind[nb[b].n].k)): k0
    |> idv(v: @as(i64, kind[nb[b + 1].n].k)): k1
    |> idv(v: @as(i64, kind[nb[b + 2].n].k)): k2
    |> idv(v: @as(i64, kind[nb[b + 3].n].k)): k3
    |> wc4(k0, k1, k2, k3): cnt
    |> if(cnt == 1)
        | then |> std/grid:stored { kind[c].k: 1 }
            |> pushk(c: @as(i64, nb[b].n), k: k0, qn: q1): q2
            |> pushk(c: @as(i64, nb[b + 1].n), k: k1, qn: q2): q3
            |> pushk(c: @as(i64, nb[b + 2].n), k: k2, qn: q3): q4
            |> pushk(c: @as(i64, nb[b + 3].n), k: k3, qn: q4): q5
            |> digw(qn: q5): r -> r
        | else |> digw(qn: q1): r -> r
| else -> 0

// gdig — the reference's `dig(n) if n.kind.wall?` ; the stack is empty
// at each call boundary (digw drains it), so the seed push is q[0].
pub tor gdig { c: i64 } -> i64
gdig = if(kind[c].k == 0)
| then |> std/grid:stored { q[0].c: @as(u32, @intCast(c)) }
    |> digw(qn: 1): r -> r
| else -> 0

// echild — one slot of a frame's neighbor scan: mark wall children
// space, then push a frame iff the child still has <=1 walkable
// neighbor (the reference's early return). Returns the frame count.
pub tor echild { c: i64, k: i64, fnz: i64 } -> i64
echild = std/grid:stored { fr[fnz - 1].k: @as(u8, @intCast(k + 1)) }
    |> if(kind[nb[c * 4 + k].n].k == 0)
        | then |> std/grid:stored { kind[nb[c * 4 + k].n].k: 1 }
            |> wcnt(c: @as(i64, nb[c * 4 + k].n)): cnt
            |> if(cnt <= 1)
                | then |> std/grid:stored { fr[fnz].c: nb[c * 4 + k].n }
                    |> std/grid:stored { fr[fnz].k: 0 }
                    |> idv(v: fnz + 1): r -> r
                | else -> fnz
        | else -> fnz

// eofw — ensure_open_finish as an explicit frame stack (tail-lowered).
pub tor eofw { fnz: i64 } -> i64
eofw = if(fnz > 0)
| then |> idv(v: @as(i64, fr[fnz - 1].c)): c
    |> idv(v: @as(i64, fr[fnz - 1].k)): k
    |> if(k == 4)
        | then |> eofw(fnz: fnz - 1): r -> r
        | else |> echild(c, k, fnz): f2
            |> eofw(fnz: f2): r -> r
| else -> 0

// geof — the reference's `ensure_open_finish(n) if n.kind.wall?`:
// mark space, then push a scan frame iff the cell has <=1 walkable
// neighbor (else the call returns without scanning). The frame stack
// is empty at each call boundary (eofw drains it), so seed is fr[0].
pub tor geof { c: i64 } -> i64
geof = if(kind[c].k == 0)
| then |> std/grid:stored { kind[c].k: 1 }
    |> wcnt(c): cnt
    |> if(cnt <= 1)
        | then |> std/grid:stored { fr[0].c: @as(u32, @intCast(c)) }
            |> std/grid:stored { fr[0].k: 0 }
            |> eofw(fnz: 1): r -> r
        | else -> 0
| else -> 0

// mswap — one update_neighbors shuffle round: swap nb slots i,j of
// cell c when the draws differ.
pub tor mswap { c: i64, i: i64, j: i64 } -> i64
mswap = if(i != j)
| then |> std/store:stored { st.t1: @as(i64, nb[c * 4 + i].n) }
    |> std/grid:stored { nb[c * 4 + i].n: nb[c * 4 + j].n }
    |> std/grid:stored { nb[c * 4 + j].n: @as(u32, @intCast(st.t1)) }: _ -> 0
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
    ! each x |> idv(v: @as(i64, @intCast(y)) * 1400 + @as(i64, @intCast(x))): c
        |> std/grid:stored { nb[c * 4].n: @as(u32, @intCast(c - 1400)) }
        |> std/grid:stored { nb[c * 4 + 1].n: @as(u32, @intCast(c + 1400)) }
        |> std/grid:stored { nb[c * 4 + 2].n: @as(u32, @intCast(c + 1)) }
        |> std/grid:stored { nb[c * 4 + 3].n: @as(u32, @intCast(c - 1)) }
        |> nx4(): i0
        |> nx4(): j0
        |> mswap(c, i: i0, j: j0): _
        |> nx4(): i1
        |> nx4(): j1
        |> mswap(c, i: i1, j: j1): _
        |> nx4(): i2
        |> nx4(): j2
        |> mswap(c, i: i2, j: j2): _
        |> nx4(): i3
        |> nx4(): j3
        |> mswap(c, i: i3, j: j3): _

// runs: 12 = 10 measured + 2 warmup — reset spaces to wall, dig from
// start's wall neighbors in order, ensure_open_finish from finish's.
// `| done` must indent under `! each i` (inner-for continuation) so the
// dig runs after every reset, not once after all twelve.
for(0..12)
! each _ |> for(0..1960000)
    ! each i |> std/grid:stored { kind[i].k: if (kind[i].k == 1) @as(u8, 0) else kind[i].k }
    | done |> gdig(c: @as(i64, nb[5604].n)): _
        |> gdig(c: @as(i64, nb[5605].n)): _
        |> gdig(c: @as(i64, nb[5606].n)): _
        |> gdig(c: @as(i64, nb[5607].n)): _
        |> geof(c: @as(i64, nb[7834392].n)): _
        |> geof(c: @as(i64, nb[7834393].n)): _
        |> geof(c: @as(i64, nb[7834394].n)): _
        |> geof(c: @as(i64, nb[7834395].n)): _
        |> std/store:stored { st.acc: @rem(st.acc + kind[980700].k, 4294967296) }

// FNV-1a over space cells: h = (h ^ (x*y)) * 16777619, u32 wrap
std/store:stored { st.h: 2166136261 }
for(0..1400)
! each y |> for(0..1400)
    ! each x |> if(kind[@as(i64, @intCast(y)) * 1400 + @as(i64, @intCast(x))].k == 1)
        | then |> std/store:stored { st.h: @rem((st.h ^ (@as(i64, @intCast(x)) * @as(i64, @intCast(y)))) * 16777619, 4294967296) }

std/io:print.ln("{{ @rem(st.acc + st.h, 4294967296):d }}")
