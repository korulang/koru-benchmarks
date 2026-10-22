// json_generate — LangArena Json::Generate, run.js scored parameters
// (coords=20000, iterations=100, warmup=20 -> 120 serialize runs over
// one generated dataset; checksum = result_val, incremented once per
// run whose emitted text starts with `{"coordinates":` and is >=15
// bytes — i.e. the run count, 120, provided every run produces the
// full document).
//
// The generated text is load-bearing upstream of Json::ParseDom /
// Json::ParseMapping, so it must be byte-exact Zig reference output:
// `{"x":{d:.8},"y":{d:.8},"z":{d:.8},"name":"{d:.7} {d}",...}`.
//
// Draw order (Helper): x,y,z = nextFloat(1.0) then name =
// nextFloat(1.0) + nextInt(10000). Zig's nextInt is
// floor(last*max/IM) (multiply-first) vs Crystal's floor(last/IM*max)
// — brute-forced over all 139968 LCG states: zero divergent draws for
// max<=10000, so the divide-first nxt spelling is exact. nextFloat is
// last/IM under both orders (multiplication by 1.0 is exact).
//
// Perf rewrite — disclosed representation choices:
//  * x/y/z are kept as k = round(v*1e8) in u32 cells, not f64. For
//    v = last/139968 in [0,1), Zig {d:.8} prints exactly "0." + the
//    8 decimal digits of round(v*1e8): a decimal tie at digit 8 would
//    need frac(last*1562500/2187) == .5 exactly, impossible for an
//    odd denominator, and the f64 product error (~1e-8) is far below
//    the 1/2187 distance to every boundary — so "0."+digits(k) is
//    byte-identical to {d:.8} of the raw draw (verified: the emitted
//    doc buffer diffed byte-for-byte against the pre-rewrite
//    binary's — 1,857,782 bytes, zero diffs).
//  * doc/nm/nl/kx/ky/kz are accessed through borrowed slices — raw
//    indexing, no per-byte __koru_at floor (recipes 12/13).
//  * The emit cursor rides tor params through self-loop emitl
//    (register-resident, recipe 6), not a store row field.
//  * Literals are unrolled constant-byte stores — LLVM merges adjacent
//    byte stores into wide stores, the same shape as Rust's push_str.
//    Every entry writes a trailing comma unconditionally and fend
//    overwrites the last one with ']' — removes the per-entry
//    if(i>0) branch; final bytes identical.
//  * The 7.2M std.fmt.bufPrint({d:.8}) calls are replaced by integer
//    digit extraction (div-by-const -> mulhi chains) — the dominant
//    cost in the old shape (~86% of runtime; measured by stubbing
//    putf to copy a fixed 10-byte literal: 0.40s -> 0.057s).
//  * The name slab copy is a fixed 16-byte move — the variable-length
//    for-copy lowered to a per-entry memcpy call; the fixed width
//    vectorizes and its <=5-byte overshoot is overwritten by the tail.
//
// Perf (2026-10-22): 0.40s -> ~0.030s min-of-5 whole-process
// (~0.14x Rust's 0.212s; checksum 120, doc byte-identical).

import std/io
import std/grid
import std/store
import std/fmt

std/grid:new(kx, size: 20000) { v: 0[u32] }
std/grid:new(ky, size: 20000) { v: 0[u32] }
std/grid:new(kz, size: 20000) { v: 0[u32] }
std/grid:new(nm, size: 640000) { c: 0[u8] }
std/grid:new(nl, size: 20000) { n: 0[i64] }
std/grid:new(doc, size: 2100000) { b: 0[u8] }
std/grid:slice(kxs) { kx.v }
std/grid:slice(kys) { ky.v }
std/grid:slice(kzs) { kz.v }
std/grid:slice(nms) { nm.c }
std/grid:slice(nls) { nl.n }
std/grid:slice(ds) { doc.b }
std/store:new(st) { last: 42[i64], acc: 0[i64], p: 0[i64] }

// nxt — one Helper.next_int draw
pub tor nxt { max: f64 } -> i64
nxt = std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }: _ -> @as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * max))

// nxfl — one Helper.nextFloat(1.0) draw (last/IM under both orders)
pub tor nxfl { } -> f64
nxfl = std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }: _ -> @as(f64, @floatFromInt(st.last)) / 139968.0

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// idl — identity bind helper (lets a read bind a name mid-chain)
pub tor idl { v: i64 } -> i64
idl -> v

// putx — write `{"x":` + `0.` + 8 digits of k at ds[p..], return p+15
pub tor putx { p: usize, k: u32 } -> usize
putx = std/grid:stored { ds[p]: @as(u8, 123) }
    |> std/grid:stored { ds[p + 1]: @as(u8, 34) }
    |> std/grid:stored { ds[p + 2]: @as(u8, 120) }
    |> std/grid:stored { ds[p + 3]: @as(u8, 34) }
    |> std/grid:stored { ds[p + 4]: @as(u8, 58) }
    |> std/grid:stored { ds[p + 5]: @as(u8, 48) }
    |> std/grid:stored { ds[p + 6]: @as(u8, 46) }
    |> std/grid:stored { ds[p + 7]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 10000000), 10))) }
    |> std/grid:stored { ds[p + 8]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 1000000), 10))) }
    |> std/grid:stored { ds[p + 9]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 100000), 10))) }
    |> std/grid:stored { ds[p + 10]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 10000), 10))) }
    |> std/grid:stored { ds[p + 11]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 1000), 10))) }
    |> std/grid:stored { ds[p + 12]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 100), 10))) }
    |> std/grid:stored { ds[p + 13]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 10), 10))) }
    |> std/grid:stored { ds[p + 14]: @as(u8, @intCast(48 + @rem(k, 10))) }
    |> ret0(): _ -> p + 15

// puty — write `,"y":` + `0.` + 8 digits of k at ds[p..], return p+15
pub tor puty { p: usize, k: u32 } -> usize
puty = std/grid:stored { ds[p]: @as(u8, 44) }
    |> std/grid:stored { ds[p + 1]: @as(u8, 34) }
    |> std/grid:stored { ds[p + 2]: @as(u8, 121) }
    |> std/grid:stored { ds[p + 3]: @as(u8, 34) }
    |> std/grid:stored { ds[p + 4]: @as(u8, 58) }
    |> std/grid:stored { ds[p + 5]: @as(u8, 48) }
    |> std/grid:stored { ds[p + 6]: @as(u8, 46) }
    |> std/grid:stored { ds[p + 7]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 10000000), 10))) }
    |> std/grid:stored { ds[p + 8]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 1000000), 10))) }
    |> std/grid:stored { ds[p + 9]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 100000), 10))) }
    |> std/grid:stored { ds[p + 10]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 10000), 10))) }
    |> std/grid:stored { ds[p + 11]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 1000), 10))) }
    |> std/grid:stored { ds[p + 12]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 100), 10))) }
    |> std/grid:stored { ds[p + 13]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 10), 10))) }
    |> std/grid:stored { ds[p + 14]: @as(u8, @intCast(48 + @rem(k, 10))) }
    |> ret0(): _ -> p + 15

// putz — write `,"z":` + `0.` + 8 digits of k at ds[p..], return p+15
pub tor putz { p: usize, k: u32 } -> usize
putz = std/grid:stored { ds[p]: @as(u8, 44) }
    |> std/grid:stored { ds[p + 1]: @as(u8, 34) }
    |> std/grid:stored { ds[p + 2]: @as(u8, 122) }
    |> std/grid:stored { ds[p + 3]: @as(u8, 34) }
    |> std/grid:stored { ds[p + 4]: @as(u8, 58) }
    |> std/grid:stored { ds[p + 5]: @as(u8, 48) }
    |> std/grid:stored { ds[p + 6]: @as(u8, 46) }
    |> std/grid:stored { ds[p + 7]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 10000000), 10))) }
    |> std/grid:stored { ds[p + 8]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 1000000), 10))) }
    |> std/grid:stored { ds[p + 9]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 100000), 10))) }
    |> std/grid:stored { ds[p + 10]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 10000), 10))) }
    |> std/grid:stored { ds[p + 11]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 1000), 10))) }
    |> std/grid:stored { ds[p + 12]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 100), 10))) }
    |> std/grid:stored { ds[p + 13]: @as(u8, @intCast(48 + @rem(@divTrunc(k, 10), 10))) }
    |> std/grid:stored { ds[p + 14]: @as(u8, @intCast(48 + @rem(k, 10))) }
    |> ret0(): _ -> p + 15

// putnm — write `,"name":"` + nm slab + `","opts":{"1":[1,true]}},`
// (trailing comma: interior separator for i<19999, overwritten with
// ']' by fend for the last entry). nl = nls[i] bytes at nms[i*32..].
pub tor putnm { p: usize, i: usize } -> usize
putnm = std/grid:stored { ds[p]: @as(u8, 44) }
    |> std/grid:stored { ds[p + 1]: @as(u8, 34) }
    |> std/grid:stored { ds[p + 2]: @as(u8, 110) }
    |> std/grid:stored { ds[p + 3]: @as(u8, 97) }
    |> std/grid:stored { ds[p + 4]: @as(u8, 109) }
    |> std/grid:stored { ds[p + 5]: @as(u8, 101) }
    |> std/grid:stored { ds[p + 6]: @as(u8, 34) }
    |> std/grid:stored { ds[p + 7]: @as(u8, 58) }
    |> std/grid:stored { ds[p + 8]: @as(u8, 34) }
    |> idl(v: nls[i]): nn
    // fixed 16-byte slab copy — nn <= 14 always ("0.ddddddd" + " " +
    // <=4 digits), so the <=5-byte overshoot lands inside the 25-byte
    // tail written next and is fully overwritten. One vector move,
    // no memcpy call.
    |> for(0..16)
        ! each k |> std/grid:stored { ds[p + 9 + k]: nms[i * 32 + k] }
        | done
        |> std/grid:stored { ds[p + 9 + @as(usize, @intCast(nn))]: @as(u8, 34) }
        |> std/grid:stored { ds[p + 10 + @as(usize, @intCast(nn))]: @as(u8, 44) }
        |> std/grid:stored { ds[p + 11 + @as(usize, @intCast(nn))]: @as(u8, 34) }
        |> std/grid:stored { ds[p + 12 + @as(usize, @intCast(nn))]: @as(u8, 111) }
        |> std/grid:stored { ds[p + 13 + @as(usize, @intCast(nn))]: @as(u8, 112) }
        |> std/grid:stored { ds[p + 14 + @as(usize, @intCast(nn))]: @as(u8, 116) }
        |> std/grid:stored { ds[p + 15 + @as(usize, @intCast(nn))]: @as(u8, 115) }
        |> std/grid:stored { ds[p + 16 + @as(usize, @intCast(nn))]: @as(u8, 34) }
        |> std/grid:stored { ds[p + 17 + @as(usize, @intCast(nn))]: @as(u8, 58) }
        |> std/grid:stored { ds[p + 18 + @as(usize, @intCast(nn))]: @as(u8, 123) }
        |> std/grid:stored { ds[p + 19 + @as(usize, @intCast(nn))]: @as(u8, 34) }
        |> std/grid:stored { ds[p + 20 + @as(usize, @intCast(nn))]: @as(u8, 49) }
        |> std/grid:stored { ds[p + 21 + @as(usize, @intCast(nn))]: @as(u8, 34) }
        |> std/grid:stored { ds[p + 22 + @as(usize, @intCast(nn))]: @as(u8, 58) }
        |> std/grid:stored { ds[p + 23 + @as(usize, @intCast(nn))]: @as(u8, 91) }
        |> std/grid:stored { ds[p + 24 + @as(usize, @intCast(nn))]: @as(u8, 49) }
        |> std/grid:stored { ds[p + 25 + @as(usize, @intCast(nn))]: @as(u8, 44) }
        |> std/grid:stored { ds[p + 26 + @as(usize, @intCast(nn))]: @as(u8, 116) }
        |> std/grid:stored { ds[p + 27 + @as(usize, @intCast(nn))]: @as(u8, 114) }
        |> std/grid:stored { ds[p + 28 + @as(usize, @intCast(nn))]: @as(u8, 117) }
        |> std/grid:stored { ds[p + 29 + @as(usize, @intCast(nn))]: @as(u8, 101) }
        |> std/grid:stored { ds[p + 30 + @as(usize, @intCast(nn))]: @as(u8, 93) }
        |> std/grid:stored { ds[p + 31 + @as(usize, @intCast(nn))]: @as(u8, 125) }
        |> std/grid:stored { ds[p + 32 + @as(usize, @intCast(nn))]: @as(u8, 125) }
        |> std/grid:stored { ds[p + 33 + @as(usize, @intCast(nn))]: @as(u8, 44) }
        |> ret0(): _ -> p + 34 + @as(usize, @intCast(nn))

// emitl — serialize entries i..20000 at ds[p..], self-loop carries
// (i, p) in registers (recipe 6). Returns final cursor.
pub tor emitl { i: usize, p: usize } -> usize
emitl = putx(p, k: kxs[i]): p1
    |> puty(p: p1, k: kys[i]): p2
    |> putz(p: p2, k: kzs[i]): p3
    |> putnm(p: p3, i): p4
    |> if(i < 19999)
        | then |> emitl(i: i + 1, p: p4): r -> r
        | else -> p4

// fhead — `{"coordinates":[` at ds[0..15), returns 15
pub tor fhead { } -> usize
fhead = std/grid:stored { ds[0]: @as(u8, 123) }
    |> std/grid:stored { ds[1]: @as(u8, 34) }
    |> std/grid:stored { ds[2]: @as(u8, 99) }
    |> std/grid:stored { ds[3]: @as(u8, 111) }
    |> std/grid:stored { ds[4]: @as(u8, 111) }
    |> std/grid:stored { ds[5]: @as(u8, 114) }
    |> std/grid:stored { ds[6]: @as(u8, 100) }
    |> std/grid:stored { ds[7]: @as(u8, 105) }
    |> std/grid:stored { ds[8]: @as(u8, 110) }
    |> std/grid:stored { ds[9]: @as(u8, 97) }
    |> std/grid:stored { ds[10]: @as(u8, 116) }
    |> std/grid:stored { ds[11]: @as(u8, 101) }
    |> std/grid:stored { ds[12]: @as(u8, 115) }
    |> std/grid:stored { ds[13]: @as(u8, 34) }
    |> std/grid:stored { ds[14]: @as(u8, 58) }
    |> std/grid:stored { ds[15]: @as(u8, 91) }
    |> ret0(): _ -> 16

// fend — ']' overwrites the last entry's trailing comma at p-1, then
// `,"info":"some info"}` at ds[p..p+20). Returns p+20.
pub tor fend { p: usize } -> usize
fend = std/grid:stored { ds[p - 1]: @as(u8, 93) }
    |> std/grid:stored { ds[p]: @as(u8, 44) }
    |> std/grid:stored { ds[p + 1]: @as(u8, 34) }
    |> std/grid:stored { ds[p + 2]: @as(u8, 105) }
    |> std/grid:stored { ds[p + 3]: @as(u8, 110) }
    |> std/grid:stored { ds[p + 4]: @as(u8, 102) }
    |> std/grid:stored { ds[p + 5]: @as(u8, 111) }
    |> std/grid:stored { ds[p + 6]: @as(u8, 34) }
    |> std/grid:stored { ds[p + 7]: @as(u8, 58) }
    |> std/grid:stored { ds[p + 8]: @as(u8, 34) }
    |> std/grid:stored { ds[p + 9]: @as(u8, 115) }
    |> std/grid:stored { ds[p + 10]: @as(u8, 111) }
    |> std/grid:stored { ds[p + 11]: @as(u8, 109) }
    |> std/grid:stored { ds[p + 12]: @as(u8, 101) }
    |> std/grid:stored { ds[p + 13]: @as(u8, 32) }
    |> std/grid:stored { ds[p + 14]: @as(u8, 105) }
    |> std/grid:stored { ds[p + 15]: @as(u8, 110) }
    |> std/grid:stored { ds[p + 16]: @as(u8, 102) }
    |> std/grid:stored { ds[p + 17]: @as(u8, 111) }
    |> std/grid:stored { ds[p + 18]: @as(u8, 34) }
    |> std/grid:stored { ds[p + 19]: @as(u8, 125) }
    |> ret0(): _ -> p + 20

// ncpy — append a scoped string into entry i's name slab (prepare only)
pub tor ncpy { t: string<*@scoped>, i: usize } -> i64
ncpy = for(0..t.len)
    ! each k |> std/grid:stored { nms[i * 32 + k]: t[k] }
    | done
    |> std/grid:stored { nl[i].n: @as(i64, @intCast(t.len)) }: _ -> 0

// generate — the reference's prepare(): 20000 entries, draw order
// x,y,z then name's float + int. kx/ky/kz store round(v*1e8) — the
// exact digit content of {d:.8} — as u32 (see header). Name text is
// captured into the nm slab once; the run loop re-serializes the
// same data every time.
for(0..20000)
! each i |> nxfl(): a
    |> nxfl(): b
    |> nxfl(): c
    |> std/grid:stored { kx[i].v: @as(u32, @intFromFloat(@round(a * 100000000.0))) }
    |> std/grid:stored { ky[i].v: @as(u32, @intFromFloat(@round(b * 100000000.0))) }
    |> std/grid:stored { kz[i].v: @as(u32, @intFromFloat(@round(c * 100000000.0))) }
    |> nxfl(): nf
    |> nxt(max: 10000.0): ni
    |> std/fmt:ln("{{ nf:d:.7 }} {{ ni:d }}"): s
    |> ncpy(t: s.text, i): _

// runs: 120 = 100 measured + 20 warmup. Each run serializes the full
// document into doc and counts it if the prefix check passes —
// `{"coordinates":[` = { " coordinates " : [ at bytes 0,1,13,14,15.
for(0..120)
! each _ |> fhead(): p0
    |> emitl(i: 0, p: p0): pf
    |> fend(p: pf): pe
    |> std/store:stored { st.p: @as(i64, @intCast(pe)) }
    |> if(st.p >= 15 and ds[0] == 123 and ds[1] == 34 and ds[13] == 34 and ds[14] == 58)
        | then |> std/store:stored { st.acc: st.acc + 1 }
        | else |> ret0(): _

std/io:print.ln("{{ st.acc:d }}")
