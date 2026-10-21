// graph_astar — LangArena Graph::AStar, run.js scored parameters
// (vertices=500000, jumps=20, jump_len=1000, iterations=1000,
// warmup=200 -> 1200 runs x dist = 1406400; dist = 1172).
//
// Same generated graph as Graph::BFS/DFS (identical CSR build — see
// graph_bfs.k). The search is A* with heuristic h(v) = target - v
// over g_score + best_f sentinels, and a binary min-heap keyed on f.
//
// Fidelity note: the reference PriorityQueue#pop sift-down compares
// children against the STALE value at the hole (heap[smallest] with
// smallest==i), not against the reinserted last element — the loop
// exits after at most one swap and the array is only re-ordered by
// push's sift-up. hdn replicates that exact comparator; the checksum
// depends on the resulting pop order.
//
// awalk fuses pop+scan into ONE self-recursive tor (mutual recursion
// does not tail-lower — see graph_bfs.k). Phase encoding: k < 0 =
// pop min; k >= 0 = scanning neighbors of v at cursor k. Stale
// (superseded-f) entries stay in the heap and expand on pop, exactly
// like the reference — g_score pruning absorbs them.
//
import std/io
import std/grid
import std/store

std/grid:new(deg, size: 500000) { c: 0[i64] }
std/grid:new(off, size: 500001) { s: 0[i64] }
std/grid:new(cur, size: 500000) { p: 0[i64] }
std/grid:new(adj, size: 21000000) { t: 0[i64] }
std/grid:new(gs, size: 500000) { g: 0[i64] }
std/grid:new(bf, size: 500000) { f: 0[i64] }
std/grid:new(hp, size: 500000) { v: 0[i64], f: 0[i64] }
std/store:new(st) { last: 42[i64], acc: 0[i64], hsz: 0[i64], sm: 0[i64], pv: 0[i64], u: 0[i64] }

// nxt — one Helper.next_int draw (advances st.last, returns the value)
pub tor nxt { max: f64 } -> i64
nxt = std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }: _ -> @as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * max))

// jwalk — a vertex's jump draws. mode 0 = count degrees, 1 = place edges.
pub tor jwalk { v: i64, cnt: i64, mode: i64 } -> i64
jwalk = if(cnt > 0)
| then |> nxt(max: 1000.0): o
    |> std/store:stored { st.u: v + o - 500 }
    |> if(st.u >= 0 and st.u < 500000 and st.u != v)
        | then |> if(mode == 0)
            | then |> std/grid:stored { deg[st.u].c: deg[st.u].c + 1 }
                |> std/grid:stored { deg[v].c: deg[v].c + 1 }
            | else |> std/grid:stored { adj[cur[st.u].p].t: v }
                |> std/grid:stored { cur[st.u].p: cur[st.u].p + 1 }
                |> std/grid:stored { adj[cur[v].p].t: st.u }
                |> std/grid:stored { cur[v].p: cur[v].p + 1 }
        |> jwalk(v, cnt: cnt - 1, mode): r -> r
    | else |> jwalk(v, cnt: cnt - 1, mode): r -> r
| else -> 0

// gpass — vertex loop for both passes (tail-lowered)
pub tor gpass { v: i64, mode: i64 } -> i64
gpass = if(v < 500000)
| then |> nxt(max: 20.0): c
    |> jwalk(v, cnt: c, mode): _
    |> gpass(v: v + 1, mode): r -> r
| else -> 0

// hup — heap sift-up from index i, carrying (v,f) toward the root.
// Strict comparator: parents with f <= ours stop the climb (ref:
// `break if @heap[parent][1] <= priority`).
pub tor hup { i: i64, v: i64, f: i64 } -> i64
hup = if(i > 0 and hp[@divTrunc(i - 1, 2)].f > f)
| then |> std/grid:stored { hp[i].v: hp[@divTrunc(i - 1, 2)].v }
    |> std/grid:stored { hp[i].f: hp[@divTrunc(i - 1, 2)].f }
    |> hup(i: @divTrunc(i - 1, 2), v, f): r -> r
| else |> std/grid:stored { hp[i].v: v }
    |> std/grid:stored { hp[i].f: f }: _ -> 0

// hdn — heap pop sift-down from index i, verbatim reference shape:
// smallest-child selection compares against hp[i] (the stale hole
// value), NOT against the reinserted last element — so the loop
// exits after at most one move. Termination writes hp[st.hsz]
// (the last element) into slot i.
pub tor hdn { i: i64 } -> i64
hdn = if(2 * i + 1 < st.hsz and hp[2 * i + 1].f < hp[i].f)
| then |> std/store:stored { st.sm: 2 * i + 1 }
| else |> std/store:stored { st.sm: i }
|> if(2 * i + 2 < st.hsz and hp[2 * i + 2].f < hp[st.sm].f)
    | then |> std/store:stored { st.sm: 2 * i + 2 }
|> if(st.sm == i)
    | then |> std/grid:stored { hp[i].v: hp[st.hsz].v }
        |> std/grid:stored { hp[i].f: hp[st.hsz].f }: _ -> 0
    | else |> std/grid:stored { hp[i].v: hp[st.sm].v }
        |> std/grid:stored { hp[i].f: hp[st.sm].f }
        |> hdn(i: st.sm): r -> r

// awalk — pop+scan fused (k < 0 = pop min; k >= 0 = scanning
// neighbors of v at cursor k). Popped vertex saved to st.pv BEFORE
// the sift-down rewrites hp[0]. target = 499999; sentinel = INT32_MAX.
pub tor awalk { v: i64, k: i64 } -> i64
awalk = if(k < 0)
| then |> if(st.hsz == 0)
    | then -> -1
    | else |> std/store:stored { st.pv: hp[0].v }
        |> if(st.pv == 499999)
            | then -> gs[499999].g
            | else |> std/store:stored { st.hsz: st.hsz - 1 }
                |> if(st.hsz > 0)
                    | then |> hdn(i: 0): _
                        |> awalk(v: st.pv, k: off[st.pv].s): r -> r
                    | else |> awalk(v: st.pv, k: off[st.pv].s): r -> r
| else |> if(k < off[v].s + deg[v].c)
    | then |> if(gs[v].g + 1 < gs[adj[k].t].g)
        | then |> std/grid:stored { gs[adj[k].t].g: gs[v].g + 1 }
            |> if(gs[v].g + 1 + 499999 - adj[k].t < bf[adj[k].t].f)
                | then |> std/grid:stored { bf[adj[k].t].f: gs[v].g + 1 + 499999 - adj[k].t }
                    |> hup(i: st.hsz, v: adj[k].t, f: gs[v].g + 1 + 499999 - adj[k].t): _
                    |> std/store:stored { st.hsz: st.hsz + 1 }
                    |> awalk(v, k: k + 1): r -> r
                | else |> awalk(v, k: k + 1): r -> r
        | else |> awalk(v, k: k + 1): r -> r
    | else |> awalk(v: 0, k: -1): r -> r

// pass A: count degrees. Chain edges first (no RNG), then jump draws
// consuming the real LCG stream.
for(1..500000)
! each i |> std/grid:stored { deg[i].c: deg[i].c + 1 }
    |> std/grid:stored { deg[@as(i64, @intCast(i)) - 1].c: deg[@as(i64, @intCast(i)) - 1].c + 1 }

gpass(v: 0, mode: 0): _

// prefix offsets + cursors
for(1..500001)
! each i |> std/grid:stored { off[i].s: off[@as(i64, @intCast(i)) - 1].s + deg[@as(i64, @intCast(i)) - 1].c }
for(0..500000)
! each i |> std/grid:stored { cur[i].p: off[i].s }

// pass B: replay the LCG stream, place edges in identical order.
std/store:stored { st.last: 42 }

for(1..500000)
! each i |> std/grid:stored { adj[cur[i].p].t: @as(i64, @intCast(i)) - 1 }
    |> std/grid:stored { cur[i].p: cur[i].p + 1 }
    |> std/grid:stored { adj[cur[@as(i64, @intCast(i)) - 1].p].t: @as(i64, @intCast(i)) }
    |> std/grid:stored { cur[@as(i64, @intCast(i)) - 1].p: cur[@as(i64, @intCast(i)) - 1].p + 1 }

gpass(v: 0, mode: 1): _

// runs: 1200 = 1000 measured + 200 warmup — every run is test()
// (warmup calls run() in this harness). Fresh g_score/best_f/heap
// per run, exactly like the reference's fresh Arrays.
for(0..1200)
! each _ |> for(0..500000)
    ! each i |> std/grid:stored { gs[i].g: 2147483647 }
        |> std/grid:stored { bf[i].f: 2147483647 }
    | done |> std/grid:stored { gs[0].g: 0 }
        |> std/grid:stored { bf[0].f: 499999 }
        |> std/grid:stored { hp[0].v: 0 }
        |> std/grid:stored { hp[0].f: 499999 }
        |> std/store:stored { st.hsz: 1 }
        |> awalk(v: 0, k: -1): r
        |> if(r == -1)
            | then |> std/store:stored { st.acc: @rem(st.acc + 4294967295, 4294967296) }
            | else |> std/store:stored { st.acc: @rem(st.acc + r, 4294967296) }

std/io:print.ln("{{ st.acc:d }}")
