// base64_encode — LangArena Base64::Encode, run.js scored parameters
// (size=500000, iterations=5000, warmup_iterations=max(5000*0.2,1)=1000 →
// 6000 checksum accumulations, oracle 3516658482).
//
// Faithful port of reference/crystal/main.cr Base64::Encode:
//   input:    "a" * 500000 (u8, no RNG)
//   run:      str2 = strict_encode(str); result_val += str2.bytesize (u32 &+)
//   checksum: DJB2("encode #{str[0..3]}... to #{str2[0..3]}...: #{result_val}")
//   str[0..3] in Crystal is the first FOUR bytes.
//
// encoded size = ceil(500000/3)*4 = 166666*4 + 4 = 666668
//   (500000 mod 3 = 2 → 166666 full groups + a 2-byte tail group).
// result_val = 666668 * 6000 mod 2^32 = 4000008000.
// Verified against the oracle: DJB2("encode aaaa... to YWFh...: 4000008000")
//   = 3516658482.
//
// Faithfulness differences, stated:
// - Input/output are static u8 grids; the reference heap-allocates a fresh
//   output each run. Same bytes, same size, no allocation timing either way.
// - The warmup/measured split is collapsed into one 6000-iteration loop
//   (same collapse as matmul_single and etc_sieve).
// - The base64 alphabet is arithmetic on the index (A-Z/a-z/0-9/+// ranges),
//   not a table — identical bytes emitted.
//
// Wave-5: SWAR arithmetic encode (u8 delta select-chain, measured):
//   b64ch is now pure u8 arithmetic — selects the ADDEND (delta) via a
//   2-way-if `|>` chain (recipe 3): 65 | 71 | 252(=-4) | 3v+51 for v>=62
//   (since out = 4v-205 for '+'/'/' => delta = 3v+51, wrapping). Extraction
//   is u8 `/` `%` `*%` `+%`. Emitted NEON is ~47 ops/48B vs ~57 for the
//   old ladder — 0.33s -> 0.27s (min-of-5).
// Falsified this wave:
//   - Linear delta-sum  delta = 65+6[v26]-75[v52]-15[v62]+3[v63]:
//     0.35s — slower than both (probe /tmp/b64e/delta).
//   - Output-select variant (select v+65|v+71|v-4|4v-205): identical 0.27s
//     (probe /tmp/b64e/sel4); delta form kept, equal codegen.
//   - "All-'a' flatters the ladder": FALSIFIED. Same binaries on mixed
//     input (i*37+11 mod 256, probes /tmp/b64e/mixl,/tmp/b64e/mixs) give
//     identical times — 0.33s ladder / 0.27s swar. The ladder emits NO
//     branches (SimplifyCFG folded it to selects; the loop is data-
//     independent NEON) — it wins vs LUT because it vectorizes, not
//     because a predictor sees the same arm.
// - The tail group is written literally for size=500000 (mod 3 = 2 → i0 i1 i2
//   '='), the same specialisation the reference's Encoder.calcSize fixes.
// - The checksum feeds the first four bytes READ BACK from the grids, not
//   literals — a wrong encode produces a wrong checksum.
// - [unsafe(bounds)] is NOT waived — group indices (3*g+k, 4*g+k) keep the
//   floor.
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

// base64 index 0..63 -> ASCII byte: A-Z(65..) a-z(+71) 0-9(-4) +(43) /(47)
// SWAR: select the addend (u8 wrapping); v>=62 => out = 4v-205 => delta 3v+51
pub tor idv8 { v: u8 } -> u8
idv8 -> v

pub tor b64ch { v: u8 } -> u8
b64ch = idv8(v: 65): r3
    |> idv8(v: if (v >= 26) 71 else r3): r2
    |> idv8(v: if (v >= 52) 252 else r2): r1
    |> idv8(v: if (v >= 62) v *% 3 +% 51 else r1): r -> v +% r

std/grid:new(inp, size: 500000) { b: 97[u8] }
std/grid:new(out, size: 666668) { c: 0[u8] }

capture { acc: 0[i64] }
! as g |> for(0..6000)
    ! each it |> for(0..166666)
        ! each q |> b64ch(v: inp[3 * q].b / 4): c0
            |> b64ch(v: inp[3 * q].b % 4 *% 16 +% inp[3 * q + 1].b / 16): c1
            |> b64ch(v: inp[3 * q + 1].b % 16 *% 4 +% inp[3 * q + 2].b / 64): c2
            |> b64ch(v: inp[3 * q + 2].b % 64): c3
            |> std/grid:stored { out[4 * q].c: c0 }
            |> std/grid:stored { out[4 * q + 1].c: c1 }
            |> std/grid:stored { out[4 * q + 2].c: c2 }
            |> std/grid:stored { out[4 * q + 3].c: c3 }
        | done |> b64ch(v: inp[499998].b / 4): t0
            |> b64ch(v: inp[499998].b % 4 *% 16 +% inp[499999].b / 16): t1
            |> b64ch(v: inp[499999].b % 16 *% 4): t2
            |> std/grid:stored { out[666664].c: t0 }
            |> std/grid:stored { out[666665].c: t1 }
            |> std/grid:stored { out[666666].c: t2 }
            |> std/grid:stored { out[666667].c: 61 }
            |> captured { acc: @rem(g.acc + 666668, 4294967296) }
| captured res
    |> djb2-4(h: 5381, a: 101, b: 110, c: 99, d: 111): h1
    |> djb2-4(h: h1, a: 100, b: 101, c: 32, d: @as(i64, inp[0].b)): h2
    |> djb2-4(h: h2, a: @as(i64, inp[1].b), b: @as(i64, inp[2].b), c: @as(i64, inp[3].b), d: 46): h3
    |> djb2-4(h: h3, a: 46, b: 46, c: 32, d: 116): h4
    |> djb2-4(h: h4, a: 111, b: 32, c: @as(i64, out[0].c), d: @as(i64, out[1].c)): h5
    |> djb2-4(h: h5, a: @as(i64, out[2].c), b: @as(i64, out[3].c), c: 46, d: 46): h6
    |> djb2-3(h: h6, a: 46, b: 58, c: 32): h7
    |> djb2-digits(n: res.acc, h: h7): hf
    |> std/io:print.ln("{{ hf:d }}")
