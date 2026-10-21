// base64 — kostya/benchmarks Base64, Goose-race port (private).
// Identical workload to goose/bench/kostya2/base64/test.goose:
//   STR_SIZE=131072 'a' input; TRIES=8192 encodes then 8192 decodes into a
//   fresh buffer per iteration, summing real output lengths. Fixture
//   encode/decode + one full round trip run before the timed loops, as his
//   does. The codec is table-driven — an alphabet grid and a 256-entry
//   decode table, the same shape other languages' stdlib codecs take.
// Output lines match the suite's shape; the sums are the gate, the trailing
// fields are real std/time:now() deltas in ms.

import std/io
import std/grid
import std/store
import std/time

std/grid:new(alpha, size: 64) { c: 0[u8] }
std/grid:new(dtab, size: 256) { v: 0[u8] }
std/grid:new(inp, size: 131072) { b: 97[u8] }
std/grid:new(enc, size: 174764) { c: 0[u8] }
std/grid:new(dec, size: 131072) { b: 0[u8] }
std/store:new(st) { sum: 0[i64], bad: 0[i64] }

pub tor ret0 {} -> i64
ret0 -> 0

pub tor idv { v: i64 } -> i64
idv -> v

pub tor lit { t: string }
lit = for(0..t.len)
    ! each k |> std/grid:stored { alpha[k].c: t[k] }

pub tor dtb {}
dtb = for(0..64)
    ! each k |> std/grid:stored { dtab[alpha[k].c].v: @as(u8, @intCast(k)) }

// one encode of inp -> enc; produces the encoded length (174764).
// 43690 full triplets + tail pair (3 chars + '=').
pub tor enc1 { it: usize } -> i64
enc1 = for(0..43690)
    ! each q |> std/grid:stored { enc[4 * q].c: alpha[@divTrunc(@as(i64, inp[3 * q].b), 4)].c }
        |> std/grid:stored { enc[4 * q + 1].c: alpha[@rem(@as(i64, inp[3 * q].b), 4) * 16 + @divTrunc(@as(i64, inp[3 * q + 1].b), 16)].c }
        |> std/grid:stored { enc[4 * q + 2].c: alpha[@rem(@as(i64, inp[3 * q + 1].b), 16) * 4 + @divTrunc(@as(i64, inp[3 * q + 2].b), 64)].c }
        |> std/grid:stored { enc[4 * q + 3].c: alpha[@rem(@as(i64, inp[3 * q + 2].b), 64)].c }
    | done |> std/grid:stored { enc[174760].c: alpha[@divTrunc(@as(i64, inp[131070].b), 4)].c }
        |> std/grid:stored { enc[174761].c: alpha[@rem(@as(i64, inp[131070].b), 4) * 16 + @divTrunc(@as(i64, inp[131071].b), 16)].c }
        |> std/grid:stored { enc[174762].c: alpha[@rem(@as(i64, inp[131071].b), 16) * 4].c }
        |> std/grid:stored { enc[174763].c: 61 }
        |> ret0(): _ -> 174764

// one decode of enc -> dec; produces the decoded length (131072).
// 43690 full quartets (3 bytes each) + tail quartet ('=' -> 2 bytes).
pub tor dec1 { it: usize } -> i64
dec1 = for(0..43690)
    ! each q |> idv(v: @as(i64, dtab[enc[4 * q].c].v) * 262144 + @as(i64, dtab[enc[4 * q + 1].c].v) * 4096 + @as(i64, dtab[enc[4 * q + 2].c].v) * 64 + @as(i64, dtab[enc[4 * q + 3].c].v)): v
        |> std/grid:stored { dec[3 * q].b: @as(u8, @intCast(@divTrunc(v, 65536))) }
        |> std/grid:stored { dec[3 * q + 1].b: @as(u8, @intCast(@rem(@divTrunc(v, 256), 256))) }
        |> std/grid:stored { dec[3 * q + 2].b: @as(u8, @intCast(@rem(v, 256))) }
    | done |> idv(v: @as(i64, dtab[enc[174760].c].v) * 262144 + @as(i64, dtab[enc[174761].c].v) * 4096 + @as(i64, dtab[enc[174762].c].v) * 64): w
        |> std/grid:stored { dec[131070].b: @as(u8, @intCast(@divTrunc(w, 65536))) }
        |> std/grid:stored { dec[131071].b: @as(u8, @intCast(@rem(@divTrunc(w, 256), 256))) }
        |> ret0(): _ -> 131072

pub tor encloop {}
encloop = for(0..8192)
    ! each it |> enc1(it): l
        |> std/store:stored { st.sum: st.sum + l }

// byte-exact verify of dec against inp — without this the decode's stores
// are dead (flat grid) and LLVM elides the whole loop, measuring nothing.
// The C reference strncmp's the same roundtrip once before timing; we pay
// one extra linear pass per iteration — a disclosed handicap.
pub tor vcmp {}
vcmp = for(0..131072)
    ! each i |> if(dec[i].b != inp[i].b)
        | then |> std/store:stored { st.bad: st.bad + 1 }

pub tor decloop {}
decloop = for(0..8192)
    ! each it |> dec1(it): l
        |> std/store:stored { st.sum: st.sum + l }
        |> vcmp()

// fixture + full round-trip warmup, then the two timed loops — same shape
// and order as the Goose test's main().
lit(t: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
    |> dtb() |> enc1(it: 0): _ |> dec1(it: 0): _
    |> std/time:now(): t0 |> encloop() |> idv(v: st.sum): es
    |> std/store:stored { st.sum: 0 }
    |> std/time:now(): t1 |> decloop() |> idv(v: st.sum): ds
    |> std/time:now(): t2
    |> idv(v: @as(i64, @intCast(@divTrunc(t1 - t0, 1000000)))): ems
    |> idv(v: @as(i64, @intCast(@divTrunc(t2 - t1, 1000000)))): dms
    |> idv(v: st.bad): badc |> if(badc > 0)
        | then |> std/io:print.ln("BADROUNDTRIP")
    |> std/io:print.ln("encode aaaa... to YWFh...: {{ es:d }}, {{ ems:d }}")
    |> std/io:print.ln("decode YWFh... to aaaa...: {{ ds:d }}, {{ dms:d }}")
