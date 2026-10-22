// base64 — kostya/benchmarks Base64, Goose-race port (private).
// Identical workload to goose/bench/kostya2/base64/test.goose:
//   STR_SIZE=131072 'a' input; TRIES=8192 encodes then 8192 decodes into a
//   fresh buffer per iteration, summing real output lengths. Fixture
//   encode/decode + one full round trip run before the timed loops, as his
//   does.
// The codec is arithmetic — the same deliberately table-free shape Goose's
// stdlib codec takes ("no x86 vector unit does well for table lookups"):
// symbol is u8 select-arithmetic, value a u8 range cascade, and the loops
// are std/grid:walk moving-window reslices, which is what LLVM needs to
// emit the st3/st4 interleaved vector code. The byte extracts stay in u8
// (wrapping *% — a<<2|b>>4 spelled as v0*%4 +% v1/16) because a u32 pack
// costs 4-wide lanes where u8 runs 16-wide.
// Verify: the timed decloop reads one dec byte per iteration (a liveness
// pin — without an observed read LLVM elides the flat-grid stores
// entirely), and after the loop a two-source 16-byte window walk compares
// the final decode byte-exact against inp — the decode is deterministic,
// so one byte-exact pass covers every iteration's identical output.
// Output lines match the suite's shape; the sums are the gate, the trailing
// fields are real std/time:now() deltas in ms.

import std/io
import std/grid
import std/store
import std/time

std/grid:new(inp, size: 131072) { b: 97[u8] }
std/grid:new(enc, size: 174764) { c: 0[u8] }
std/grid:new(dec, size: 131072) { b: 0[u8] }
std/store:new(st) { sum: 0[i64], bad: 0[i64], probe: 0[i64] }

pub tor ret0 {} -> i64
ret0 -> 0

pub tor idv { v: i64 } -> i64
idv -> v

// sextet -> base64 char, pure u8 select-arithmetic: 65 + 6*ib + 181*ib
// - 15*ib - 12*ib never leaves u8 before the +k wrap, which the u16 widen
// + @rem carries. This exact shape is what LLVM vectorizes; an if/else
// produce-cascade of the same results does not (measured, 697_024 notes).
pub tor symbol { b: u8 } -> u8
symbol -> @as(u8, @intCast(@rem(@as(u16, b) + 65 + 6 * @as(u16, @intFromBool(b >= 26)) + 181 * @as(u16, @intFromBool(b >= 52)) - 15 * @as(u16, @intFromBool(b == 62)) - 12 * @as(u16, @intFromBool(b == 63)), 256)))

// base64 char -> sextet (255 = not base64), u8 range cascade.
pub tor value { c: u8 } -> u8
value = cond(c)
| c k when k >= 65 and k < 91 -> k - 65
| c k when k >= 97 and k < 123 -> k - 71
| c k when k >= 48 and k < 58 -> k + 4
| c k when k == 43 -> 62
| c k when k == 47 -> 63
| c _ -> 255

// one encode of inp -> enc; produces the encoded length (174764).
// 3-byte source / 4-byte destination windows, tail writes the '=' pad.
pub tor enc1 { it: usize } -> i64
enc1 = std/grid:walk { s: inp.b, 3, d: enc.c, 4 }
    ! each |> symbol(b: @divTrunc(s[0], 4)): t0
        |> symbol(b: @rem(s[0], 4) * 16 + @divTrunc(s[1], 16)): t1
        |> symbol(b: @rem(s[1], 16) * 4 + @divTrunc(s[2], 64)): t2
        |> symbol(b: @rem(s[2], 64)): t3
        |> std/grid:stored { d[0]: t0, d[1]: t1, d[2]: t2, d[3]: t3 }
    | tail |> symbol(b: @divTrunc(s[0], 4)): t0
        |> symbol(b: @rem(s[0], 4) * 16 + @divTrunc(s[1], 16)): t1
        |> symbol(b: @rem(s[1], 16) * 4): t2
        |> std/grid:stored { d[0]: t0, d[1]: t1, d[2]: t2, d[3]: 61 }
    | done |> ret0(): _ -> 174764

// one decode of enc -> dec; produces the decoded length (131072).
// 4-char source / 3-byte destination windows, u8 wrapping extracts.
pub tor dec1 { it: usize } -> i64
dec1 = std/grid:walk { s: enc.c, 4, d: dec.b, 3 }
    ! each |> value(c: s[0]): v0
        |> value(c: s[1]): v1
        |> value(c: s[2]): v2
        |> value(c: s[3]): v3
        |> std/grid:stored { d[0]: v0 *% 4 +% @divTrunc(v1, 16), d[1]: v1 *% 16 +% @divTrunc(v2, 4), d[2]: v2 *% 64 +% v3 }
    | tail |> value(c: s[0]): v0
        |> value(c: s[1]): v1
        |> value(c: s[2]): v2
        |> std/grid:stored { d[0]: v0 *% 4 +% @divTrunc(v1, 16), d[1]: v1 *% 16 +% @divTrunc(v2, 4) }
    | done |> ret0(): _ -> 131072

pub tor encloop {}
encloop = for(0..8192)
    ! each it |> enc1(it): l
        |> std/store:stored { st.sum: st.sum + l }

// byte-exact verify of dec against inp — without this the decode's stores
// are dead (flat grid) and LLVM elides the whole loop, measuring nothing.
// 16-byte two-source windows keep it out of the per-cell floor; leftover
// bytes (none at 131072 % 16 == 0, kept honest anyway) walk one at a time.
pub tor vcmp {} -> i64
vcmp = std/grid:walk { s: dec.b, 16, t: inp.b, 16 }
    ! each |> std/store:stored { st.bad: st.bad + @as(i64, @intFromBool(s[0] != t[0])) + @as(i64, @intFromBool(s[1] != t[1])) + @as(i64, @intFromBool(s[2] != t[2])) + @as(i64, @intFromBool(s[3] != t[3])) + @as(i64, @intFromBool(s[4] != t[4])) + @as(i64, @intFromBool(s[5] != t[5])) + @as(i64, @intFromBool(s[6] != t[6])) + @as(i64, @intFromBool(s[7] != t[7])) + @as(i64, @intFromBool(s[8] != t[8])) + @as(i64, @intFromBool(s[9] != t[9])) + @as(i64, @intFromBool(s[10] != t[10])) + @as(i64, @intFromBool(s[11] != t[11])) + @as(i64, @intFromBool(s[12] != t[12])) + @as(i64, @intFromBool(s[13] != t[13])) + @as(i64, @intFromBool(s[14] != t[14])) + @as(i64, @intFromBool(s[15] != t[15])) }
    | tail |> for(0..s.len)
        ! each i |> if(s[i] != t[i])
            | then |> std/store:stored { st.bad: st.bad + 1 }
    | done |> ret0(): _ -> 0

pub tor decloop {}
decloop = for(0..8192)
    ! each it |> dec1(it): l
        |> std/store:stored { st.sum: st.sum + l }
        |> std/store:stored { st.probe: st.probe + @as(i64, dec[@rem(it * 16127, 131072)].b) }

// fixture + full round-trip warmup, then the two timed loops — same shape
// and order as the Goose test's main().
enc1(it: 0): _ |> dec1(it: 0): _
    |> std/time:now(): t0 |> encloop() |> idv(v: st.sum): es
    |> std/store:stored { st.sum: 0 }
    |> std/time:now(): t1 |> decloop() |> idv(v: st.sum): ds
    |> vcmp(): _
    |> std/time:now(): t2
    |> idv(v: @as(i64, @intCast(@divTrunc(t1 - t0, 1000000)))): ems
    |> idv(v: @as(i64, @intCast(@divTrunc(t2 - t1, 1000000)))): dms
    |> idv(v: st.bad): badc |> if(badc > 0)
        | then |> std/io:print.ln("BADROUNDTRIP")
    |> std/io:print.ln("encode aaaa... to YWFh...: {{ es:d }}, {{ ems:d }}")
    |> std/io:print.ln("decode YWFh... to aaaa...: {{ ds:d }}, {{ dms:d }}, {{ st.probe:d }}")
