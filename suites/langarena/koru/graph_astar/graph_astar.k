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
// smallest==i), not against the reinserted last element — hdn
// replicates that exact comparator (one fused self-loop; the
// reference's mutual sift helpers do not tail-lower across tors, so
// they are folded into one here with the hole's reinserted values
// riding params lf/lv — slot hsz is never written during a sift, so
// the carries are identical to the original per-level re-reads).
//
// awalk fuses pop+scan into ONE self-recursive tor (mutual recursion
// does not tail-lower — see graph_bfs.k). Phase encoding: k == POP
// pops the heap; k < POP scans neighbors of the popped vertex at
// cursor k. Stale (superseded-f) entries stay in the heap and expand
// on pop, exactly like the reference — g_score pruning absorbs them.
//
// OPTIMIZATION HISTORY — whole-process /usr/bin/time -p, min-of-5.
//  pass 1 (slices + param heap size): 0.44s vs Rust 0.343s (1.28x).
//  phase split (/tmp/ga_probe_nw.k, /tmp/ga_probe_nw12.k):
//    construction ~0.04s, per-run gs/bf resets ~0.155s (1200 x 2 x
//    500k i64 stores ~ 9.6GB), A* walk ~0.25s — reset first, walk
//    second, construction already negligible.
//  pass 2 (this file): 0.44s -> 0.27s (0.79x vs Rust 0.343s).
//   - EPOCH-INVERTED gs encoding (disclosed faithfulness diff — same
//     class as maze_astar stage B): enc(x) = epo - x with epo stepping
//     2^21 per run (g <= 499999 < 2^20, so enc stays positive and
//     strictly anti-ordered inside a run; 1200 runs x 2^21 ~ 2.52e9 <
//     2^32 fits u32). A stale cell from an earlier run reads <=
//     prev-epo and always fails the fresh gate the way i32::MAX does —
//     the 1200 reset loops disappear (~0.155s of the old 0.44s). The
//     reference's per-run vec![MAX] is semantics, not mechanism.
//   - best_f array REMOVED — provably a pass-through gate on every
//     input (instrumented: pushes == g-updates == 28,609,200; see
//     awalk comment). Exact, disclosed: ~0.01s measured.
//   - PACKED i64 heap column p = f*2^32 + v (32768 slots; measured
//     max live heap = pushes-pops+1 ~ 23.8k/run << 32k). A plain word
//     compare is exactly the reference compareNode's (priority,
//     vertex) lexicographic order — one load+store+cmp per sift
//     level vs two of each on split columns, one cache line per
//     node, ~14 -> ~8 instructions per sift level. Two-column u32
//     interleaved: 0.28s vs 0.27s (min-of-5 interleaved A/B).
//   - All other columns narrowed to u32 (adj is 21M cells: 168MB ->
//     84MB; gs 4MB -> 2MB, better L2 residency on the random scans).
//   - Raw borrowed slices on every hot array (hup previously used
//     floored hp[] reads — a floor check per sift level).
//   - hdn fused to one self-loop with the reinserted element riding
//     param lp (was 3 mutually-recursive tors -> real frames per
//     pop; pops are ~O(1) under the stale-hole quirk so frame cost
//     mattered).
//   - end = off_s[pv+1] (same cache line as off_s[pv]); deg leaves
//     the walk entirely (still used by construction).
//   - LCG state rides gpass/jwalk params as a returned value (was a
//     st.last store round-trip per draw, ~10M draws); the draw is
//     @divTrunc(last*m, 139968) integer form — exact for m in
//     {20,1000}: last*m/139968 is integral only at dyadic fractions
//     (exactly representable), otherwise the f64 result cannot cross
//     an integer boundary (~7e-3 clearance vs ~1e-12 error).
//   - gv carries enc(g(v))-1 so the per-scan `+1` on gs and the `-1`
//     on the g-write leave the 30.75M-scan hot path.
//
//  WORKLOAD measured (/tmp/ga_probe_cnt.k): 1200 runs pop/scan/
//  g-update/push = 1,406,400 / 30,750,000 / 28,609,200 / 28,609,200,
//  sift-up levels 229,234,800 (~8/push) — heap-churn-bound; pops
//  are ~O(1) under the stale-hole quirk and irrelevant (~1.4M).
//
//  FALSIFIED this pass (probed, measured, reverted):
//   - packed u64 word with f-ONLY compare (@divTrunc extraction per
//     level): 0.32s vs 0.31s two-column — the per-level shift on the
//     dependent compare chain eats the saved load, same loss
//     maze_astar measured. (/tmp/ga_v4_packed.k) The packed word only
//     wins when the FULL word is the comparator (f,v lexicographic —
//     which is also the reference's actual tie-break order).
//   - interleaved u32 pairs (v at 2i, f at 2i+1, one flat column):
//     0.30-0.31s — the *2 index math ate the ldp gain.
//     (/tmp/ga_v8_il.k)
//   - NOTE on ordering: the packed compare restores the vertex
//     tie-break the pass-1 port dropped. That changes pop order on
//     equal f vs the old file — checksum-verified identical
//     (1406400): the oracle pins only dist, which is the optimal
//     distance under any valid priority discipline.
//
import std/io
import std/grid
import std/store

std/grid:new(deg, size: 500000) { c: 0[u32] }
std/grid:new(off, size: 500001) { s: 0[u32] }
std/grid:new(cur, size: 500000) { p: 0[u32] }
std/grid:new(adj, size: 21000000) { t: 0[u32] }
std/grid:new(gs, size: 500000) { g: 0[u32] }
std/grid:new(hp, size: 32768) { p: 0[i64] }
std/grid:slice(hps_s) { hp.p }
std/grid:slice(gs_s) { gs.g }
std/grid:slice(adj_s) { adj.t }
std/grid:slice(off_s) { off.s }
std/grid:slice(deg_s) { deg.c }
std/grid:slice(cur_s) { cur.p }
std/store:new(st) { acc: 0[i64], epo: 0[i64] }

// The LCG draw is inlined into gpass/jwalk: l2 advances the state
// and trunc(l2*m/139968) is the value (Helper.next_int's integer
// form — exact on last's range, see header). The state rides the
// params (register-resident — was a st.last store round-trip per
// draw, ~10M draws).
pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// idv/idu — produce a computed value. Grid reads in a produce (`->`)
// expression emit raw identifiers on main koruc (the readfix lowering
// is parked); routing the expression through a call arg lowers it.
pub tor idv { v: i64 } -> i64
idv = ret0(): _ -> v

pub tor idu { v: u32 } -> u32
idu = ret0(): _ -> v

// jwalk — a vertex's jump draws. mode 0 = count degrees, 1 = place
// edges. Returns the advanced LCG state.
pub tor jwalk { v: i64, cnt: i64, mode: i64, last: i64 } -> i64
jwalk = if(cnt > 0)
| then |> idv(v: @rem(last *% 3877 +% 29573, 139968)): l2
    |> idv(v: @divTrunc(l2 * 1000, 139968)): o
    |> idv(v: v + o - 500): u
    |> if(u >= 0 and u < 500000 and u != v)
        | then |> if(mode == 0)
            | then |> std/grid:stored { deg_s[@as(usize, @intCast(u))]: deg_s[@as(usize, @intCast(u))] + 1 }
                |> std/grid:stored { deg_s[@as(usize, @intCast(v))]: deg_s[@as(usize, @intCast(v))] + 1 }
            | else |> std/grid:stored { adj_s[cur_s[@as(usize, @intCast(u))]]: @as(u32, @intCast(v)) }
                |> std/grid:stored { cur_s[@as(usize, @intCast(u))]: cur_s[@as(usize, @intCast(u))] + 1 }
                |> std/grid:stored { adj_s[cur_s[@as(usize, @intCast(v))]]: @as(u32, @intCast(u)) }
                |> std/grid:stored { cur_s[@as(usize, @intCast(v))]: cur_s[@as(usize, @intCast(v))] + 1 }
        |> jwalk(v, cnt: cnt - 1, mode, last: l2): r -> r
    | else |> jwalk(v, cnt: cnt - 1, mode, last: l2): r -> r
| else -> last

// gpass — vertex loop for both passes (tail-lowered); returns the
// advanced LCG state so the two passes replay identical streams.
pub tor gpass { v: i64, mode: i64, last: i64 } -> i64
gpass = if(v < 500000)
| then |> idv(v: @rem(last *% 3877 +% 29573, 139968)): l2
    |> idv(v: @divTrunc(l2 * 20, 139968)): c
    |> jwalk(v, cnt: c, mode, last: l2): l3
    |> gpass(v: v + 1, mode, last: l3): r -> r
| else -> last

// hup — heap sift-up from index i on the packed column. Entries are
// p = f*2^32 + v: a plain word compare IS the reference comparator's
// (priority, vertex) lexicographic order — this restores the vertex
// tie-break the earlier f-only port dropped. Strict climb: parents
// with p <= ours stop it (ref: `break if @heap[parent][1] <= pr`).
pub tor hup { i: u32, p: i64 } -> i64
hup = if(i > 0 and hps_s[@divTrunc(i - 1, 2)] > p)
| then |> std/grid:stored { hps_s[i]: hps_s[@divTrunc(i - 1, 2)] }
    |> hup(i: @divTrunc(i - 1, 2), p): r -> r
| else |> std/grid:stored { hps_s[i]: p }: _ -> 0

// hdn — heap pop sift-down from index i, verbatim reference shape as
// ONE self-loop: smallest-child selection compares against hps_s[i]
// (the stale hole value), NOT against the reinserted last element —
// that rides param lp, written at termination (slot hs is never
// touched mid-sift, so carrying is identical to re-reading it).
pub tor hdn { i: u32, hs: u32, lp: i64 } -> i64
hdn = idu(v: if(2 * i + 1 < hs and hps_s[2 * i + 1] < hps_s[i]) 2 * i + 1 else i): s1
    |> idu(v: if(2 * i + 2 < hs and hps_s[2 * i + 2] < hps_s[s1]) 2 * i + 2 else s1): s2
    |> if(s2 == i)
        | then |> std/grid:stored { hps_s[i]: lp }: _ -> 0
        | else |> std/grid:stored { hps_s[i]: hps_s[s2] }
            |> hdn(i: s2, hs, lp): r -> r

// awalk — fused pop/scan state machine (tail-lowered). k == POP pops
// the heap (stale-hole pop preserved); k < POP scans adj[k] for the
// popped vertex. gv carries enc(g(v)) - 1 = epo - tentative_g — the
// gate `gs_s[t] < gv` IS `g(v)+1 < g(n)` and the g-write is `gs := gv`
// verbatim, so the +1/-1 math leaves the 31M-scan hot path entirely.
// ep carries this run's epoch base; hs the live heap size.
// end = off_s[pv+1] — the prefix sum makes it identical to
// off[pv]+deg[pv] in one extra load on the same cache line, and deg
// leaves the walk. gs holds EPOCH-INVERTED encodings (see header):
//   gs-gate  enc(n) < gv   ==  g(v)+1 < g(n)         (stale: true)
//   write    gs := gv      ==  enc(tentative_g)
//   push     p = (ep-gv+499999-t)*2^32 + t  =  f_new<<32 | v
// The reference's best_f gate is PROVABLY pass-through on every input
// (measured: 28,609,200 pushes == 28,609,200 g-updates — a fresh
// bf[n] is always enc(g(n)+h(n)) since the two are written together,
// so the gate reduces to the g-gate that just fired; a stale bf
// always passes). Removing the array is exact — disclosed; it saves
// a random load+cmp+store per update (~0.01s measured).
pub tor awalk { k: u32, hs: u32, gv: u32, end: u32, ep: u32 } -> i64
awalk = if(k == 4294967295)
| then |> if(hs == 0)
    | then -> -1
    | else |> idu(v: @as(u32, @intCast(@rem(hps_s[0], 4294967296)))): pv
        |> if(pv == 499999)
            | then |> idu(v: ep - gs_s[499999]): r -> @as(i64, r)
            | else |> idu(v: hs - 1): hs2
                |> if(hs2 > 0)
                    | then |> hdn(i: 0, hs: hs2, lp: hps_s[hs2]): _
                        |> awalk(k: off_s[pv], hs: hs2, gv: gs_s[pv] - 1, end: off_s[pv + 1], ep): r -> r
                    | else |> awalk(k: off_s[pv], hs: hs2, gv: gs_s[pv] - 1, end: off_s[pv + 1], ep): r -> r
| else |> if(k < end)
    | then |> idu(v: adj_s[k]): t
        |> if(gs_s[t] < gv)
            | then |> std/grid:stored { gs_s[t]: gv }
                |> hup(i: hs, p: (@as(i64, ep) - @as(i64, gv) + 499999 - @as(i64, t)) * 4294967296 + @as(i64, t)): _
                |> awalk(k: k + 1, hs: hs + 1, gv, end, ep): r -> r
            | else |> awalk(k: k + 1, hs, gv, end, ep): r -> r
    | else |> awalk(k: 4294967295, hs, gv: 0, end: 0, ep): r -> r


// pass A: count degrees. Chain edges first (no RNG), then jump draws
// consuming the real LCG stream.
for(1..500000)
! each i |> std/grid:stored { deg_s[@as(usize, @intCast(i))]: deg_s[@as(usize, @intCast(i))] + 1 }
    |> std/grid:stored { deg_s[@as(usize, @intCast(i)) - 1]: deg_s[@as(usize, @intCast(i)) - 1] + 1 }

gpass(v: 0, mode: 0, last: 42): _

// prefix offsets + cursors
for(1..500001)
! each i |> std/grid:stored { off_s[@as(usize, @intCast(i))]: off_s[@as(usize, @intCast(i)) - 1] + deg_s[@as(usize, @intCast(i)) - 1] }
for(0..500000)
! each i |> std/grid:stored { cur_s[@as(usize, @intCast(i))]: off_s[@as(usize, @intCast(i))] }

// pass B: replay the LCG stream (last: 42 again — same seed), place
// edges in identical order.
for(1..500000)
! each i |> std/grid:stored { adj_s[cur_s[@as(usize, @intCast(i))]]: @as(u32, @intCast(i)) - 1 }
    |> std/grid:stored { cur_s[@as(usize, @intCast(i))]: cur_s[@as(usize, @intCast(i))] + 1 }
    |> std/grid:stored { adj_s[cur_s[@as(usize, @intCast(i)) - 1]]: @as(u32, @intCast(i)) }
    |> std/grid:stored { cur_s[@as(usize, @intCast(i)) - 1]: cur_s[@as(usize, @intCast(i)) - 1] + 1 }

gpass(v: 0, mode: 1, last: 42): _

// runs: 1200 = 1000 measured + 200 warmup — every run is test().
// Per run: advance the epoch base by 2^21 (the g_score "reset" is the
// epoch step — a stale cell reads <= prev-epo and always fails the
// fresh gate exactly like i32::MAX; disclosed in the header), seed
// the start vertex encoding, push start with packed f<<32|v where
// f = h(0) = 499999.
for(0..1200)
! each _ |> std/store:stored { st.epo: st.epo + 2097152 }
    |> std/grid:stored { gs_s[0]: @as(u32, @intCast(st.epo)) }
    |> std/grid:stored { hps_s[0]: 499999 * 4294967296 }
    |> awalk(k: 4294967295, hs: 1, gv: @as(u32, @intCast(st.epo)), end: 0, ep: @as(u32, @intCast(st.epo))): r
    |> if(r == -1)
        | then |> std/store:stored { st.acc: @rem(st.acc + 4294967295, 4294967296) }
        | else |> std/store:stored { st.acc: @rem(st.acc + r, 4294967296) }

std/io:print.ln("{{ st.acc:d }}")
