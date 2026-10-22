// distance_jaro — LangArena Distance::Jaro, run.js scored
// parameters (count=1000, size=50, iterations=780, warmup=156 →
// 936 runs; per run: Jaro similarity of each pair, floor(val*1000)
// saturating-added to result_val — oracle 567348912).
//
// String lens are nextInt(50)+4 → 4..53, alphabet "abcdefghij";
// m1/m2 flag grids reuse the reference's [1024]bool scratch shape.
// match_dist = max(len)/2 - 1 clamped >= 0; the transposition pass
// walks s2's matched flags with a monotone cursor k.
//
import std/io
import std/grid
import std/store
import std/fmt

std/grid:new(strb, size: 108000) { b: 0[u8] }
std/grid:new(pr, size: 1000) { o1: 0[i64], l1: 0[i64], o2: 0[i64], l2: 0[i64] }
std/grid:new(m1, size: 54) { v: 0[i64] }
std/grid:new(m2, size: 54) { v: 0[i64] }
std/grid:slice(strb_s) { strb.b }
std/grid:slice(o1_s) { pr.o1 }
std/grid:slice(l1_s) { pr.l1 }
std/grid:slice(o2_s) { pr.o2 }
std/grid:slice(l2_s) { pr.l2 }
std/grid:slice(m1_s) { m1.v }
std/grid:slice(m2_s) { m2.v }

pub tor idv { v: i64 } -> i64
idv = if(0 == 0)
| then -> v
| else -> v
std/store:new(st) { last: 42[i64], res: 0[i64], off: 0[i64], md: 0[i64], m: 0[i64], k: 0[i64], tr: 0[i64], ws: 0[i64], we: 0[i64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// nxt — nextInt(max): LCG draw, truncated scale
pub tor nxt { max: i64 } -> i64
nxt = std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }: _ -> @as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * @as(f64, @floatFromInt(max))))

// fil1 — fill pair p's first string
pub tor fil1 { p: i64, j: i64 } -> i64
fil1 = if(j < pr[p].l1)
| then |> nxt(max: 10): c
    |> std/grid:stored { strb[pr[p].o1 + j].b: @as(u8, @intCast(97 + c)) }
    |> fil1(p, j: j + 1): r -> r
| else -> 0

// fil2 — fill pair p's second string
pub tor fil2 { p: i64, j: i64 } -> i64
fil2 = if(j < pr[p].l2)
| then |> nxt(max: 10): c
    |> std/grid:stored { strb[pr[p].o2 + j].b: @as(u8, @intCast(97 + c)) }
    |> fil2(p, j: j + 1): r -> r
| else -> 0

// genp — generate count pairs (prepare)
pub tor genp { p: i64 } -> i64
genp = if(p < 1000)
| then |> nxt(max: 50): l1
    |> nxt(max: 50): l2
    |> std/grid:stored { pr[p].o1: st.off }
    |> std/grid:stored { pr[p].l1: l1 + 4 }
    |> std/store:stored { st.off: st.off + l1 + 4 }
    |> std/grid:stored { pr[p].o2: st.off }
    |> std/grid:stored { pr[p].l2: l2 + 4 }
    |> std/store:stored { st.off: st.off + l2 + 4 }
    |> fil1(p, j: 0): _
    |> fil2(p, j: 0): _
    |> genp(p: p + 1): r -> r
| else -> 0

// clrm — reset both match-flag rows
pub tor clrm { i: i64 } -> i64
clrm = if(i < 54)
| then |> std/grid:stored { m1_s[@as(usize, @intCast(i))]: 0 }
    |> std/grid:stored { m2_s[@as(usize, @intCast(i))]: 0 }
    |> clrm(i: i + 1): r -> r
| else -> 0

// jsc — scan s1[i]'s match window [j..we]; first unmatched equal
// char wins (reference breaks out of the scan). Produces running m.
pub tor jsc { a: i64, ob: i64, i: i64, j: i64, we: i64, m: i64 } -> i64
jsc = if(j <= we)
| then |> if(m2_s[@as(usize, @intCast(j))] == 0)
        | then |> if(strb_s[@as(usize, @intCast(a + i))] == strb_s[@as(usize, @intCast(ob + j))])
            | then |> std/grid:stored { m1_s[@as(usize, @intCast(i))]: 1 }
                |> std/grid:stored { m2_s[@as(usize, @intCast(j))]: 1 }
                |> ret0(): _ -> m + 1
            | else |> jsc(a, ob, i, j: j + 1, we, m): r -> r
        | else |> jsc(a, ob, i, j: j + 1, we, m): r -> r
| else -> m

// jm1 — match pass over s1 positions; ws/we bound per i, m threads
// through as a param. Produces final m.
pub tor jm1 { a: i64, ob: i64, l1: i64, l2: i64, md: i64, i: i64, m: i64 } -> i64
jm1 = if(i < l1)
| then |> idv(v: if(i > md) i - md else 0): ws
    |> idv(v: if(i + md < l2 - 1) i + md else l2 - 1): we
    |> jsc(a, ob, i, j: ws, we, m): m2
    |> jm1(a, ob, l1, l2, md, i: i + 1, m: m2): r -> r
| else -> m

// trp — transposition pass: k walks s2's matched flags; each matched
// s1[i] is compared against s2[k] in match order. Produces tr.
pub tor trp { a: i64, ob: i64, l1: i64, l2: i64, i: i64, k: i64, tr: i64 } -> i64
trp = if(i < l1)
| then |> if(m1_s[@as(usize, @intCast(i))] == 1)
        | then |> kadv(l2, k): k2
            |> if(k2 < l2)
                | then |> if(strb_s[@as(usize, @intCast(a + i))] == strb_s[@as(usize, @intCast(ob + k2))])
                    | then |> trp(a, ob, l1, l2, i: i + 1, k: k2 + 1, tr): r -> r
                    | else |> trp(a, ob, l1, l2, i: i + 1, k: k2 + 1, tr: tr + 1): r -> r
                | else |> trp(a, ob, l1, l2, i: i + 1, k: k2, tr): r -> r
        | else |> trp(a, ob, l1, l2, i: i + 1, k, tr): r -> r
| else -> tr

// kadv — advance k past unmatched s2 flags; produces k
pub tor kadv { l2: i64, k: i64 } -> i64
kadv = if(k < l2)
| then |> if(m2_s[@as(usize, @intCast(k))] == 0)
    | then |> kadv(l2, k: k + 1): r -> r
    | else |> ret0(): _ -> k
| else -> k

// jpair — one pair's Jaro score: match pass, transposition pass,
// (m/l1 + m/l2 + (m-tr)/m)/3 * 1000 floored into st.res
pub tor jpair { p: i64 } -> i64
jpair = if(p < 1000)
| then |> clrm(i: 0): _
    |> idv(v: l1_s[@as(usize, @intCast(p))]): l1
    |> idv(v: l2_s[@as(usize, @intCast(p))]): l2
    |> idv(v: o1_s[@as(usize, @intCast(p))]): a
    |> idv(v: o2_s[@as(usize, @intCast(p))]): ob
    |> idv(v: if(l1 > l2) @divTrunc(l1, 2) - 1 else @divTrunc(l2, 2) - 1): md0
    |> idv(v: if(md0 < 0) 0 else md0): md
    |> jm1(a, ob, l1, l2, md, i: 0, m: 0): m
    |> if(m > 0)
        | then |> trp(a, ob, l1, l2, i: 0, k: 0, tr: 0): tr
            |> std/store:stored { st.res: st.res + @as(i64, @intFromFloat(@floor((@as(f64, @floatFromInt(m)) / @as(f64, @floatFromInt(l1)) + @as(f64, @floatFromInt(m)) / @as(f64, @floatFromInt(l2)) + (@as(f64, @floatFromInt(m)) - @as(f64, @floatFromInt(@divTrunc(tr, 2)))) / @as(f64, @floatFromInt(m))) / 3.0 * 1000.0))) }
        | else |> ret0(): _
    |> jpair(p: p + 1): r -> r
| else -> 0

// runl — 936 runs (780 measured + 156 warmup)
pub tor runl { k: i64 } -> i64
runl = if(k < 936)
| then |> jpair(p: 0): _
    |> runl(k: k + 1): r -> r
| else -> 0

// ---- driver ----
genp(p: 0): _
|> runl(k: 0): _
|> std/io:print.ln("{{ st.res:d }}")
