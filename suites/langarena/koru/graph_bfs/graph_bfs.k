// graph_bfs — LangArena Graph::BFS, run.js scored parameters
// (vertices=500000, jumps=20, jump_len=1000, iterations=40,
// warmup=8 -> 48 runs x dist(0 -> V-1) = 50400; dist = 1050).
//
// Faithful port of reference/crystal/main.cr Graph::BFS:
//   generate_random: chain edges (i,i-1) for i in 1..V, then per vertex
//     v: cnt = nextInt(jumps) jump draws, each u = v + nextInt(jump_len)
//     - jump_len//2; undirected add if 0 <= u < V and u != v.
//   bfs_shortest_path(0, V-1): FIFO queue of {vertex, dist}; scanning
//     neighbors returns dist+1 on target hit; unvisited neighbors push.
//
// Faithfulness differences, stated:
// - adjacency is CSR (deg count pass -> prefix offsets -> place pass)
//   rather than Array(Array). Append order per vertex is preserved
//   exactly (chain edges i-ascending first, then jump draws in order) —
//   required so sibling tasks (DFS pruning, A* ties) see identical
//   neighbor iteration order.
// - The LCG stream is replayed: pass A counts degrees consuming the
//   real stream, st.last resets to 42, pass B replays the identical
//   stream to place edges. Observable output identical.
// - Queue is a flat {v,d} grid with a tail counter; visited is a u8
//   grid re-zeroed per run (reference allocates fresh Bytes/Deque).
// - The pop-while loop and the neighbor scan are mutually tail-
//   recursive tors (bfs/bfscan) lowered to while loops.
//
import std/io
import std/grid
import std/store

std/grid:new(deg, size: 500000) { c: 0[i64] }
std/grid:new(off, size: 500001) { s: 0[i64] }
std/grid:new(cur, size: 500000) { p: 0[i64] }
std/grid:new(adj, size: 21000000) { t: 0[i64] }
std/grid:new(vis, size: 500000) { f: 0[u8] }
std/grid:new(qv, size: 500000) { v: 0[i64], d: 0[i64] }
std/store:new(st) { last: 42[i64], acc: 0[i64], qh: 0[i64], u: 0[i64] }

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

// walk — dequeue+scan fused into ONE self-recursive tor. The natural
// bfs(pop)/bfscan(scan) split is mutual recursion, which does NOT
// tail-lower (only self-calls become loops) — it segfaulted at ~500K
// pops. (head, k) = (queue read cursor, adjacency cursor); when a
// vertex's neighbor range exhausts, the tail call advances head and
// reloads k from off[qv[head+1].v] — reads qv[qh] garbage once when the
// queue drains, then head < st.qh fails and the loop ends.
pub tor walk { head: i64, k: i64 } -> i64
walk = if(head < st.qh)
| then |> if(k < off[qv[head].v].s + deg[qv[head].v].c)
    | then |> if(adj[k].t == 499999)
        | then -> qv[head].d + 1
        | else |> if(vis[adj[k].t].f == 0)
            | then |> std/grid:stored { vis[adj[k].t].f: 1 }
                |> std/grid:stored { qv[st.qh].v: adj[k].t }
                |> std/grid:stored { qv[st.qh].d: qv[head].d + 1 }
                |> std/store:stored { st.qh: st.qh + 1 }
                |> walk(head, k: k + 1): r -> r
            | else |> walk(head, k: k + 1): r -> r
    | else |> walk(head: head + 1, k: off[qv[head + 1].v].s): r -> r
| else -> -1

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

// runs: 48 = 40 measured + 8 warmup — every run is test() (warmup calls
// run() in this harness). Fresh visited + queue per run.
for(0..48)
! each _ |> for(0..500000)
    ! each i |> std/grid:stored { vis[i].f: 0 }
    | done |> std/store:stored { st.qh: 0 }
        |> std/grid:stored { qv[0].v: 0 }
        |> std/grid:stored { qv[0].d: 0 }
        |> std/store:stored { st.qh: 1 }
        |> std/grid:stored { vis[0].f: 1 }
        |> walk(head: 0, k: 0): d
        |> std/store:stored { st.acc: @rem(st.acc + d, 4294967296) }

std/io:print.ln("{{ st.acc:d }}")
