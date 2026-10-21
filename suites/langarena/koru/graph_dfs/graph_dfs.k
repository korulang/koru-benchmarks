// graph_dfs — LangArena Graph::DFS, run.js scored parameters
// (vertices=500000, jumps=20, jump_len=1000, iterations=15,
// warmup=3 -> 18 runs x dist = 22194; dist = 1233).
//
// Same generated graph as Graph::BFS (identical CSR build — see
// graph_bfs.k). The search differs: dfs_shortest_path is a LIFO STACK
// walk — pop (v,d), skip if visited or d >= best, else mark visited
// and push unvisited neighbors; a target neighbor only lowers best.
// Exploration order matters (visited/best pruning), so the CSR build
// preserves exact append order — chain edges i-ascending first, then
// per-vertex jump draws in order — matching the reference streams.
//
// dwalk fuses pop+scan into ONE self-recursive tor (mutual recursion
// does not tail-lower — see graph_bfs.k). Phase encoding: k < 0 =
// pop next stack entry; k >= 0 = scanning neighbors of (v,d) at
// cursor k. A node may be pushed several times before its first pop
// marks it visited — the reference has the same duplicate-push shape.
//
import std/io
import std/grid
import std/store

std/grid:new(deg, size: 500000) { c: 0[i64] }
std/grid:new(off, size: 500001) { s: 0[i64] }
std/grid:new(cur, size: 500000) { p: 0[i64] }
std/grid:new(adj, size: 21000000) { t: 0[i64] }
std/grid:new(vis, size: 500000) { f: 0[u8] }
std/grid:new(sv, size: 500000) { v: 0[i64], d: 0[i64] }
std/store:new(st) { last: 42[i64], acc: 0[i64], sp: 0[i64], u: 0[i64], best: 0[i64] }

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

// dwalk — pop+scan fused (k < 0 = pop; k >= 0 = scanning (v,d) at k).
// Skip rule on pop: visited or d >= best. Target neighbor only lowers
// best; unvisited neighbors push {n, d+1}.
pub tor dwalk { sp: i64, v: i64, d: i64, k: i64 } -> i64
dwalk = if(k < 0)
| then |> if(sp > 0)
    | then |> if(vis[sv[sp - 1].v].f == 1 or sv[sp - 1].d >= st.best)
        | then |> dwalk(sp: sp - 1, v: 0, d: 0, k: -1): r -> r
        | else |> std/grid:stored { vis[sv[sp - 1].v].f: 1 }
            |> dwalk(sp: sp - 1, v: sv[sp - 1].v, d: sv[sp - 1].d, k: off[sv[sp - 1].v].s): r -> r
    | else -> 0
| else |> if(k < off[v].s + deg[v].c)
    | then |> if(adj[k].t == 499999)
        | then |> if(d + 1 < st.best)
            | then |> std/store:stored { st.best: d + 1 }
                |> dwalk(sp, v, d, k: k + 1): r -> r
            | else |> dwalk(sp, v, d, k: k + 1): r -> r
        | else |> if(vis[adj[k].t].f == 0)
            | then |> std/grid:stored { sv[sp].v: adj[k].t }
                |> std/grid:stored { sv[sp].d: d + 1 }
                |> dwalk(sp: sp + 1, v, d, k: k + 1): r -> r
            | else |> dwalk(sp, v, d, k: k + 1): r -> r
    | else |> dwalk(sp, v: 0, d: 0, k: -1): r -> r

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

// runs: 18 = 15 measured + 3 warmup — every run is test() (warmup calls
// run() in this harness). Fresh visited + stack per run.
for(0..18)
! each _ |> for(0..500000)
    ! each i |> std/grid:stored { vis[i].f: 0 }
    | done |> std/store:stored { st.sp: 1 }
        |> std/grid:stored { sv[0].v: 0 }
        |> std/grid:stored { sv[0].d: 0 }
        |> std/store:stored { st.best: 2147483647 }
        |> dwalk(sp: 1, v: 0, d: 0, k: -1): _
        |> if(st.best == 2147483647)
            | then |> std/store:stored { st.acc: @rem(st.acc + 4294967295, 4294967296) }
            | else |> std/store:stored { st.acc: @rem(st.acc + st.best, 4294967296) }

std/io:print.ln("{{ st.acc:d }}")
