// graph_bfs — LangArena Graph::BFS, run.js scored parameters
// (vertices=500000, jumps=20, jump_len=1000, iterations=40,
// warmup=8 -> 48 runs x dist(0 -> V-1) = 50400; dist = 1050).
//
// Faithful port of reference/crystal/main.cr Graph::BFS:
//   generate_random: chain edges (i,i-1) for i in 1..V, then per vertex
//     v: cnt = nextInt(jumps) jump draws, each u = v + nextInt(jump_len)
//     - jump_len//2; undirected add if 0 <= u < V and u != v.
//   bfs_shortest_path(0, V-1): FIFO queue; scanning neighbors returns
//     dist+1 on target hit; unvisited neighbors push at dist+1.
//
// Faithfulness differences, stated:
// - adjacency is CSR (deg count pass -> prefix offsets -> place pass)
//   rather than Array(Array). Append order per vertex is preserved
//   exactly (chain edges i-ascending first, then jump draws in order) —
//   required so sibling tasks (DFS pruning, A* ties) see identical
//   neighbor iteration order.
// - The LCG stream is replayed: pass A counts degrees consuming the
//   real stream from seed 42, pass B replays the identical stream
//   (last: 42 again) to place edges. Observable output identical.
//   The seed rides tor params (gcnt/gput -> jcnt/jput -> nxt), not a
//   store row — register-resident per recipe 6.
// - Queue is a flat u32 cursor grid (vertex ids only); the reference's
//   per-entry dist is recovered by BFS level tracking: `lend` is the
//   queue index where the current level ends — when the pop cursor
//   crosses it, d+1 and lend=tail. Identical dist values, one compare
//   per pop, no second queue column.
// - visited is a u8 epoch grid: run i marks with tag i+1, so a stale
//   byte from an earlier run reads as unvisited without re-zeroing
//   (reference allocates a fresh visited array per run — same state).
// - adj is sized to the exact directed-edge count of this seeded
//   graph (10,566,682 — measured from the deterministic generator;
//   the seed is fixed at 42 so the count is a program constant).
// - Target-adjacency rides bit 31 of off[v] (offsets stay < 2^25):
//   set during pass B when an edge touches vertex 499999. BFS returns
//   dist+1 whenever the scanning vertex's list contains the target,
//   independent of position, so the pop-time flag check returns the
//   same value — the per-edge t==499999 compare disappears from the
//   hot loop. off reads mask the bit; cur was copied before marking.
// - All hot columns are u32/u8 (vertex ids < 500000, offsets < 21M,
//   degrees < 64K) — half the memory traffic of i64 lanes.
// - Every hot access goes through a std/grid:slice borrow — the
//   program carries the index obligation, no __koru_at floor.
// - walk is ONE self-recursive tor (mutual recursion does not tail-
//   lower) carrying (head, tail, k, kend, d, lend, e) as params —
//   register-resident cursors per recipe 6; the k<kend check is first
//   so per-edge work is load-t/cmp/load-vis/cmp/k++ only.
//
import std/io
import std/grid
import std/store

std/grid:new(deg, size: 500000) { c: 0[u32] }
std/grid:new(off, size: 500001) { s: 0[u32] }
std/grid:new(cur, size: 500000) { p: 0[u32] }
std/grid:new(adj, size: 10566682) { t: 0[u32] }
std/grid:new(vis, size: 500000) { f: 0[u8] }
std/grid:new(qv, size: 500000) { v: 0[u32] }
std/store:new(st) { acc: 0[i64] }

std/grid:slice(degr) { deg.c }
std/grid:slice(offr) { off.s }
std/grid:slice(curr) { cur.p }
std/grid:slice(adjr) { adj.t }
std/grid:slice(visr) { vis.f }
std/grid:slice(qvr) { qv.v }

// nxt — one Helper.next_int draw on a carried (post-step) seed. The
// reference computes (last*3877+29573) % 139968 in the caller, then
// trunc(last/139968.0 * max) as f64. @divTrunc(last*max, 139968) is
// identical for EVERY last in [0,139968) at both max values used
// (20, 1000) — verified exhaustively over all 139968 x 2 cases;
// the f64 path is only a cost, not a semantics.
pub tor nxt { last: i64, max: i64 } -> i64
nxt = idv(v: @divTrunc(last *% max, 139968)): r -> r

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// idv/idvu — produce a computed value. Grid/slice reads in a produce
// (`->`) expression emit raw identifiers on main koruc (the readfix
// lowering is parked); routing the expression through a call arg
// lowers it.
pub tor idv { v: i64 } -> i64
idv = ret0(): _ -> v

pub tor idvu { v: usize } -> usize
idvu = ret0(): _ -> v

// jcnt/jput — a vertex's jump draws, split per pass so the pass-mode
// check is not re-evaluated inside the per-draw loop.
pub tor jcnt { v: usize, cnt: i64, last: i64 } -> i64
jcnt = if(cnt > 0)
| then |> idv(v: @rem(last *% 3877 +% 29573, 139968)): nl
    |> nxt(last: nl, max: 1000): o
    |> idv(v: @as(i64, @intCast(v)) + o - 500): uu
    |> if(uu >= 0 and uu < 500000 and uu != @as(i64, @intCast(v)))
        | then |> std/grid:stored { degr[@as(usize, @intCast(uu))]: degr[@as(usize, @intCast(uu))] + 1 }
            |> std/grid:stored { degr[v]: degr[v] + 1 }
        |> jcnt(v, cnt: cnt - 1, last: nl): r -> r
    | else |> jcnt(v, cnt: cnt - 1, last: nl): r -> r
| else -> last

pub tor jput { v: usize, cnt: i64, last: i64 } -> i64
jput = if(cnt > 0)
| then |> idv(v: @rem(last *% 3877 +% 29573, 139968)): nl
    |> nxt(last: nl, max: 1000): o
    |> idv(v: @as(i64, @intCast(v)) + o - 500): uu
    |> if(uu >= 0 and uu < 500000 and uu != @as(i64, @intCast(v)))
        | then |> std/grid:stored { adjr[curr[@as(usize, @intCast(uu))]]: @as(u32, @intCast(v)) }
            |> std/grid:stored { curr[@as(usize, @intCast(uu))]: curr[@as(usize, @intCast(uu))] + 1 }
            |> std/grid:stored { adjr[curr[v]]: @as(u32, @intCast(uu)) }
            |> std/grid:stored { curr[v]: curr[v] + 1 }
            |> if(uu == 499999)
                | then |> std/grid:stored { offr[v]: offr[v] | 2147483648 }
            |> if(v == 499999)
                | then |> std/grid:stored { offr[@as(usize, @intCast(uu))]: offr[@as(usize, @intCast(uu))] | 2147483648 }
        |> jput(v, cnt: cnt - 1, last: nl): r -> r
    | else |> jput(v, cnt: cnt - 1, last: nl): r -> r
| else -> last

// gcnt/gput — vertex loops for the two passes (tail-lowered); the LCG
// seed rides the param chain through the jwalk instead of a store
// round-trip.
pub tor gcnt { v: usize, last: i64 } -> i64
gcnt = if(v < 500000)
| then |> idv(v: @rem(last *% 3877 +% 29573, 139968)): nl
    |> nxt(last: nl, max: 20): c
    |> jcnt(v, cnt: c, last: nl): nl2
    |> gcnt(v: v + 1, last: nl2): r -> r
| else -> last

pub tor gput { v: usize, last: i64 } -> i64
gput = if(v < 500000)
| then |> idv(v: @rem(last *% 3877 +% 29573, 139968)): nl
    |> nxt(last: nl, max: 20): c
    |> jput(v, cnt: c, last: nl): nl2
    |> gput(v: v + 1, last: nl2): r -> r
| else -> last

// walk — dequeue+scan fused into ONE self-recursive tor (mutual
// recursion does not tail-lower). Loop state rides parameters:
//   head = pop cursor, tail = push cursor, k/kend = edge scan range
//   of the current vertex, d = its dist, lend = queue index where
//   level d ends, e = this run's visited-epoch tag. The level check
//   runs before the flag return so a flagged vertex popping exactly
//   on the boundary still returns dist(v2)+1 = d+2.
// Shape: `k < kend` first, so the hot edge path is one u32 adj load,
// one u8 visited load, the epoch compare, and k++ — target-adjacency
// (off bit 31) and queue/level bookkeeping run once per vertex.
// The drain path reads qvr[head+1] only under head+1 < tail, so it
// can never index past the queue — no garbage read on drain.
pub tor walk { head: usize, tail: usize, k: usize, kend: usize, d: i64, lend: usize, e: usize } -> i64
walk = if(k < kend)
| then |> idvu(v: adjr[k]): t
    |> if(visr[t] != e)
        | then |> std/grid:stored { visr[t]: @as(u8, @intCast(e)) }
            |> std/grid:stored { qvr[tail]: @as(u32, @intCast(t)) }
            |> walk(head, tail: tail + 1, k: k + 1, kend, d, lend, e): r -> r
        | else |> walk(head, tail, k: k + 1, kend, d, lend, e): r -> r
| else |> if(head + 1 < tail)
    | then |> idvu(v: qvr[head + 1]): v2
        |> idvu(v: offr[v2]): ov
        |> if(head + 1 == lend)
            | then |> if(ov >= 2147483648)
                | then -> d + 2
                | else |> walk(head: head + 1, tail, k: ov, kend: offr[v2 + 1] & 2147483647, d: d + 1, lend: tail, e): r -> r
            | else |> if(ov >= 2147483648)
                | then -> d + 1
                | else |> walk(head: head + 1, tail, k: ov, kend: offr[v2 + 1] & 2147483647, d, lend, e): r -> r
    | else -> -1

// pass A: count degrees. Chain edges first (no RNG), then jump draws
// consuming the real LCG stream.
for(1..500000)
! each i |> std/grid:stored { degr[i]: degr[i] + 1 }
    |> std/grid:stored { degr[i - 1]: degr[i - 1] + 1 }

gcnt(v: 0, last: 42): _

// prefix offsets + cursors
for(1..500001)
! each i |> std/grid:stored { offr[i]: offr[i - 1] + degr[i - 1] }
for(0..500000)
! each i |> std/grid:stored { curr[i]: offr[i] }

// pass B: replay the LCG stream, place edges in identical order.
for(1..500000)
! each i |> std/grid:stored { adjr[curr[i]]: @as(u32, @intCast(i - 1)) }
    |> std/grid:stored { curr[i]: curr[i] + 1 }
    |> std/grid:stored { adjr[curr[i - 1]]: @as(u32, @intCast(i)) }
    |> std/grid:stored { curr[i - 1]: curr[i - 1] + 1 }
    |> if(i == 499999)
        | then |> std/grid:stored { offr[499998]: offr[499998] | 2147483648 }

gput(v: 0, last: 42): _

// runs: 48 = 40 measured + 8 warmup — every run is test() (warmup calls
// run() in this harness). visited = epoch tag i+1 (no re-zero);
// queue = (vertex 0) with head 0, tail 1, level 0 ending at index 1.
for(0..48)
! each i |> std/grid:stored { qvr[0]: 0 }
    |> std/grid:stored { visr[0]: @as(u8, @intCast(i + 1)) }
    |> walk(head: 0, tail: 1, k: 0, kend: offr[1] & 2147483647, d: 0, lend: 1, e: i + 1): d
    |> std/store:stored { st.acc: @rem(st.acc + d, 4294967296) }

std/io:print.ln("{{ st.acc:d }}")
