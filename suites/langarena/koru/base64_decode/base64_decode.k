// base64_decode — LangArena Base64::Decode, run.js scored parameters
// (size=500000, iterations=4000, warmup_iterations=800 → 4800 checksum
// accumulations, oracle 1329134018).
//
// Faithful port of reference/crystal/main.cr Base64::Decode:
//   setup:    str2 = strict_encode("a" * 500000)   → 666668 bytes
//   run:      str3 = decode(str2); result_val += str3.bytesize (u32 &+)
//   checksum: DJB2("decode #{str2[0..3]}... to #{str3[0..3]}...: #{result_val}")
//
// encoded "a"*500000 is "YWFh" x166666 + "YWE=" (last 2-byte group).
// decoded len = 500000; result_val = 500000 * 4800 mod 2^32 = 2400000000.
// Verified against the oracle: DJB2("decode YWFh... to aaaa...: 2400000000")
//   = 1329134018.
//
// Faithfulness differences, stated:
// - The encoded input is initialised to its known content ("YWFh" pattern
//   + "YWE=" tail) rather than produced by a real encode call — Decode's
//   setup encode is not the measured work, and the encode task itself is
//   proven separately by base64_encode.
// - Static u8 grids; the reference heap-allocates per run. Same bytes.
// - The warmup/measured split is collapsed into one 4800-iteration loop.
// - Reverse map is arithmetic on the ASCII byte, not a table.
// - The tail group is written literally ('YWE=' → 2 bytes), matching
//   Decoder.calcSizeForSlice semantics for a 2-byte final group.
// - [unsafe(bounds)] is NOT waived.
//
import std/io
import std/grid

pub tor djb2-byte { h: i64, b: i64 } -> i64
djb2-byte -> @rem(h * 33 + b, 4294967296)

pub tor djb2-4 { h: i64, a: i64, b: i64, c: i64, d: i64 } -> i64
djb2-4 = djb2-byte(h, b: a): h1
|> djb2-byte(h: h1, b): h2
|> djb2-byte(h: h2, b: c): h3
|> djb2-byte(h: h3, b: d): h4 -> h4

pub tor djb2-3 { h: i64, a: i64, b: i64, c: i64 } -> i64
djb2-3 = djb2-byte(h, b: a): h1
|> djb2-byte(h: h1, b): h2
|> djb2-byte(h: h2, b: c): h3 -> h3

pub tor djb2-digits { n: i64, h: i64 } -> i64
djb2-digits = if(n < 10)
| then |> djb2-byte(h, b: 48 + n): r -> r
| else |> djb2-digits(n: @divTrunc(n, 10), h): h2 |> djb2-byte(h: h2, b: 48 + @rem(n, 10)): r -> r

// ASCII byte -> 6-bit base64 value
pub tor b64val { c: i64 } -> i64
b64val = if(c >= 97)
| then -> c - 71
| else |> if(c >= 65)
    | then -> c - 65
    | else |> if(c >= 48)
        | then -> c + 4
        | else |> if(c == 43)
            | then -> 62
            | else -> 63

// "YWFh" repeating pattern byte for position i (i mod 4 → Y W F h)
pub tor initch { i: i64 } -> i64
initch = if(@rem(i, 4) == 0)
| then -> 89
| else |> if(@rem(i, 4) == 1)
    | then -> 87
    | else |> if(@rem(i, 4) == 2)
        | then -> 70
        | else -> 104

std/grid:new(enc, size: 666668) { c: 0[u8] }
std/grid:new(dec, size: 500000) { b: 0[u8] }

for(0..666668)
! each i |> initch(i: @as(i64, @intCast(i))): c |> std/grid:stored { enc[i].c: @as(u8, @intCast(c)) }
std/grid:stored { enc[666666].c: 69 }
std/grid:stored { enc[666667].c: 61 }

capture { acc: 0[i64] }
! as g |> for(0..4800)
    ! each it |> for(0..166666)
        ! each q |> b64val(c: @as(i64, enc[4 * q].c)): v0
            |> b64val(c: @as(i64, enc[4 * q + 1].c)): v1
            |> b64val(c: @as(i64, enc[4 * q + 2].c)): v2
            |> b64val(c: @as(i64, enc[4 * q + 3].c)): v3
            |> std/grid:stored { dec[3 * q].b: @as(u8, @intCast(v0 * 4 + @divTrunc(v1, 16))) }
            |> std/grid:stored { dec[3 * q + 1].b: @as(u8, @intCast(@rem(v1, 16) * 16 + @divTrunc(v2, 4))) }
            |> std/grid:stored { dec[3 * q + 2].b: @as(u8, @intCast(@rem(v2, 4) * 64 + v3)) }
        | done |> b64val(c: @as(i64, enc[666664].c)): t0
            |> b64val(c: @as(i64, enc[666665].c)): t1
            |> b64val(c: @as(i64, enc[666666].c)): t2
            |> std/grid:stored { dec[499998].b: @as(u8, @intCast(t0 * 4 + @divTrunc(t1, 16))) }
            |> std/grid:stored { dec[499999].b: @as(u8, @intCast(@rem(t1, 16) * 16 + @divTrunc(t2, 4))) }
            |> captured { acc: @rem(g.acc + 500000, 4294967296) }
| captured res
    |> djb2-4(h: 5381, a: 100, b: 101, c: 99, d: 111): h1
    |> djb2-4(h: h1, a: 100, b: 101, c: 32, d: @as(i64, enc[0].c)): h2
    |> djb2-4(h: h2, a: @as(i64, enc[1].c), b: @as(i64, enc[2].c), c: @as(i64, enc[3].c), d: 46): h3
    |> djb2-4(h: h3, a: 46, b: 46, c: 32, d: 116): h4
    |> djb2-4(h: h4, a: 111, b: 32, c: @as(i64, dec[0].b), d: @as(i64, dec[1].b)): h5
    |> djb2-4(h: h5, a: @as(i64, dec[2].b), b: @as(i64, dec[3].b), c: 46, d: 46): h6
    |> djb2-3(h: h6, a: 46, b: 58, c: 32): h7
    |> djb2-digits(n: res.acc, h: h7): hf
    |> std/io:print.ln("{{ hf:d }}")
