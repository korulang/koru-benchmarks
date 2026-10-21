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
| then |> std/grid:stored { m1[i].v: 0 }
    |> std/grid:stored { m2[i].v: 0 }
    |> clrm(i: i + 1): r -> r
| else -> 0

// jsc — scan s1[i]'s match window [st.ws..st.we]; first unmatched
// equal char wins (reference breaks out of the scan)
pub tor jsc { p: i64, i: i64, j: i64 } -> i64
jsc = if(j <= st.we)
| then |> if(m2[j].v == 0 and strb[pr[p].o1 + i].b == strb[pr[p].o2 + j].b)
        | then |> std/grid:stored { m1[i].v: 1 }
            |> std/grid:stored { m2[j].v: 1 }
            |> std/store:stored { st.m: st.m + 1 }: _ -> 1
        | else |> jsc(p, i, j: j + 1): r -> r
| else -> 0

// jm1 — match pass over s1 positions
pub tor jm1 { p: i64, i: i64 } -> i64
jm1 = if(i < pr[p].l1)
| then |> if(i > st.md)
        | then |> std/store:stored { st.ws: i - st.md }
        | else |> std/store:stored { st.ws: 0 }
    |> if(i + st.md < pr[p].l2 - 1)
        | then |> std/store:stored { st.we: i + st.md }
        | else |> std/store:stored { st.we: pr[p].l2 - 1 }
    |> jsc(p, i, j: st.ws): _
    |> jm1(p, i: i + 1): r -> r
| else -> 0

// trp — transposition pass: k walks s2's matched flags; each matched
// s1[i] is compared against s2[k] in match order
pub tor trp { p: i64, i: i64 } -> i64
trp = if(i < pr[p].l1)
| then |> if(m1[i].v == 1)
        | then |> kadv(p): _
            |> if(st.k < pr[p].l2)
                | then |> if(strb[pr[p].o1 + i].b == strb[pr[p].o2 + st.k].b)
                    | then |> ret0(): _
                    | else |> std/store:stored { st.tr: st.tr + 1 }
                |> std/store:stored { st.k: st.k + 1 }
            | else |> ret0(): _
        | else |> ret0(): _
    |> trp(p, i: i + 1): r -> r
| else -> 0

// kadv — advance k past unmatched s2 flags
pub tor kadv { p: i64 } -> i64
kadv = if(st.k < pr[p].l2 and m2[st.k].v == 0)
| then |> std/store:stored { st.k: st.k + 1 }
    |> kadv(p): r -> r
| else -> 0

// jpair — one pair's Jaro score: match pass, transposition pass,
// (m/l1 + m/l2 + (m-tr)/m)/3 * 1000 floored into st.res
pub tor jpair { p: i64 } -> i64
jpair = if(p < 1000)
| then |> clrm(i: 0): _
    |> std/store:stored { st.m: 0 }
    |> std/store:stored { st.tr: 0 }
    |> std/store:stored { st.k: 0 }
    |> if(pr[p].l1 > pr[p].l2)
        | then |> std/store:stored { st.md: @divTrunc(pr[p].l1, 2) - 1 }
        | else |> std/store:stored { st.md: @divTrunc(pr[p].l2, 2) - 1 }
    |> if(st.md < 0)
        | then |> std/store:stored { st.md: 0 }
        | else |> ret0(): _
    |> jm1(p, i: 0): _
    |> if(st.m > 0)
        | then |> trp(p, i: 0): _
            |> std/store:stored { st.res: st.res + @as(i64, @intFromFloat(@floor((@as(f64, @floatFromInt(st.m)) / @as(f64, @floatFromInt(pr[p].l1)) + @as(f64, @floatFromInt(st.m)) / @as(f64, @floatFromInt(pr[p].l2)) + (@as(f64, @floatFromInt(st.m)) - @as(f64, @floatFromInt(@divTrunc(st.tr, 2)))) / @as(f64, @floatFromInt(st.m))) / 3.0 * 1000.0))) }
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
