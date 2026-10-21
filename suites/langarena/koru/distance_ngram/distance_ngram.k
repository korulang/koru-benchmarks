// distance_ngram — LangArena Distance::NGram, run.js scored
// parameters (count=10, size=20000, n=4, iterations=100, warmup=20
// → 120 runs; per run: ngram distance of each pair, floor(val*1000)
// saturating-added to result_val — oracle 397440).
//
// The reference keys two AutoHashMap(u32,u32) by the raw 4-byte gram.
// The alphabet is 10 chars, so at most 10^4 = 10000 grams exist —
// c1/c2 are dense 10000-entry count tables indexed by the bijective
// base-10 encoding ((b0-97)*10+b1-97)... of the same gram. Distinct-
// key counting (nz1/nz2) and the per-occurrence intersection rule
// (c2 occurrence count <= c1 count) are preserved exactly.
//
// verified: multiply-first vs divide-first nextInt produces no fork
// for max in {10, 20000} across the whole LCG range.
//
import std/io
import std/grid
import std/store
import std/fmt

std/grid:new(strb, size: 400080) { b: 0[u8] }
std/grid:new(pr, size: 10) { o1: 0[i64], l1: 0[i64], o2: 0[i64], l2: 0[i64] }
std/grid:new(c1, size: 10000) { v: 0[i64] }
std/grid:new(c2, size: 10000) { v: 0[i64] }
std/store:new(st) { last: 42[i64], res: 0[i64], off: 0[i64], nz1: 0[i64], nz2: 0[i64], inter: 0[i64], g: 0[i64] }

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
genp = if(p < 10)
| then |> nxt(max: 20000): l1
    |> nxt(max: 20000): l2
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

// clrl — reset both count tables for a fresh pair pass
pub tor clrl { i: i64 } -> i64
clrl = if(i < 10000)
| then |> std/grid:stored { c1[i].v: 0 }
    |> std/grid:stored { c2[i].v: 0 }
    |> clrl(i: i + 1): r -> r
| else -> 0

// gr1 — count s1's 4-grams; nz1 tracks distinct grams
pub tor gr1 { p: i64, i: i64 } -> i64
gr1 = if(i <= pr[p].l1 - 4)
| then |> std/store:stored { st.g: (((@as(i64, @intCast(strb[pr[p].o1 + i].b)) - 97) * 10 + @as(i64, @intCast(strb[pr[p].o1 + i + 1].b)) - 97) * 10 + @as(i64, @intCast(strb[pr[p].o1 + i + 2].b)) - 97) * 10 + @as(i64, @intCast(strb[pr[p].o1 + i + 3].b)) - 97 }
    |> if(c1[st.g].v == 0)
        | then |> std/store:stored { st.nz1: st.nz1 + 1 }
        | else |> ret0(): _
    |> std/grid:stored { c1[st.g].v: c1[st.g].v + 1 }
    |> gr1(p, i: i + 1): r -> r
| else -> 0

// gr2 — count s2's 4-grams; intersection credits each s2 occurrence
// while its running count does not exceed s1's count
pub tor gr2 { p: i64, i: i64 } -> i64
gr2 = if(i <= pr[p].l2 - 4)
| then |> std/store:stored { st.g: (((@as(i64, @intCast(strb[pr[p].o2 + i].b)) - 97) * 10 + @as(i64, @intCast(strb[pr[p].o2 + i + 1].b)) - 97) * 10 + @as(i64, @intCast(strb[pr[p].o2 + i + 2].b)) - 97) * 10 + @as(i64, @intCast(strb[pr[p].o2 + i + 3].b)) - 97 }
    |> if(c2[st.g].v == 0)
        | then |> std/store:stored { st.nz2: st.nz2 + 1 }
        | else |> ret0(): _
    |> std/grid:stored { c2[st.g].v: c2[st.g].v + 1 }
    |> if(c1[st.g].v > 0 and c2[st.g].v <= c1[st.g].v)
        | then |> std/store:stored { st.inter: st.inter + 1 }
        | else |> ret0(): _
    |> gr2(p, i: i + 1): r -> r
| else -> 0

// pairl — distance of pair p, floor(val*1000) into st.res
pub tor pairl { p: i64 } -> i64
pairl = if(p < 10)
| then |> std/store:stored { st.nz1: 0 }
    |> std/store:stored { st.nz2: 0 }
    |> std/store:stored { st.inter: 0 }
    |> clrl(i: 0): _
    |> if(pr[p].l1 >= 4 and pr[p].l2 >= 4)
        | then |> gr1(p, i: 0): _
            |> gr2(p, i: 0): _
            |> if(st.nz1 + st.nz2 > 0)
                | then |> std/store:stored { st.res: st.res + @as(i64, @intFromFloat(@floor(@as(f64, @floatFromInt(st.inter)) / @as(f64, @floatFromInt(st.nz1 + st.nz2)) * 1000.0))) }
                | else |> ret0(): _
        | else |> ret0(): _
    |> pairl(p: p + 1): r -> r
| else -> 0

// runl — 120 runs (100 measured + 20 warmup)
pub tor runl { k: i64 } -> i64
runl = if(k < 120)
| then |> pairl(p: 0): _
    |> runl(k: k + 1): r -> r
| else -> 0

// ---- driver ----
genp(p: 0): _
|> runl(k: 0): _
|> std/io:print.ln("{{ st.res:d }}")
