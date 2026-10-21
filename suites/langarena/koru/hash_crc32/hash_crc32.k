// hash_crc32 — LangArena Hash::CRC32, run.js scored parameters
// (size=1000000, iterations=150, warmup_iterations=30 → 180 checksum
// accumulations, oracle 2318723244).
//
// Faithful port of reference/zig/buffer_hash_crc32.zig:
//   prepare:  data[i] = nextInt(256) — LCG last = (last*3877 + 29573)
//             mod 139968 seeded 42; byte = floor(last * 256 / 139968) via f64
//   run:      bit-at-a-time CRC32 (poly 0xEDB88320, init/xorout 0xFFFFFFFF)
//   checksum: result_val +%= crc32(data) per iteration — u32 wrap
//
// Faithfulness differences, stated:
// - Static u8 grid; the reference heap-allocates once. Same bytes.
// - The warmup/measured split is collapsed into one 180-iteration loop.
// - The inner 8-tap while loop is unrolled as chain steps — same taps,
//   same order; no table (the reference is deliberately bit-at-a-time,
//   and a table would not measure the same work).
// - acc is widened to i64 with an explicit mod-2^32 fold (u32
//   &+); crc likewise is i64 — every intermediate stays < 2^32 by
//   construction, so the arithmetic is identical without masking.
// - Working state lives in a singleton store, not `capture`: capture
//   bindings end with their arm, so a nested `! each` byte arm cannot see
//   an outer `! as g`. `std/store:stored` writes are ambient (KORU108).
//
import std/io
import std/grid
import std/store

std/grid:new(data, size: 1000000) { b: 0[u8] }
std/store:new(st) { acc: 0[i64], crc: 0[i64], last: 42[i64] }

// crctap — one bit-at-a-time CRC32 step: if lsb then (crc>>1)^poly else crc>>1
pub tor crctap { crc: i64 } -> i64
crctap = if(crc & 1 == 1)
| then -> (crc >> 1) ^ 0xEDB88320
| else -> crc >> 1

// prepare: fill data once via the LangArena LCG (nextInt(256) per byte)
for(0..1000000)
! each i |> std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }
    |> std/grid:stored { data[i].b: @as(u8, @intCast(@as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) * 256.0 / 139968.0)))) }

// run: 180 accumulations (150 iterations + 30 warmups); each recomputes
// the full bit-at-a-time CRC32 over the buffer — that is the measured work.
for(0..180)
! each it |> std/store:stored { st.crc: 0xFFFFFFFF }
    |> for(0..1000000)
        ! each i |> std/store:stored { st.crc: st.crc ^ @as(i64, data[i].b) }
            |> crctap(st.crc): t1 |> std/store:stored { st.crc: t1 }
            |> crctap(st.crc): t2 |> std/store:stored { st.crc: t2 }
            |> crctap(st.crc): t3 |> std/store:stored { st.crc: t3 }
            |> crctap(st.crc): t4 |> std/store:stored { st.crc: t4 }
            |> crctap(st.crc): t5 |> std/store:stored { st.crc: t5 }
            |> crctap(st.crc): t6 |> std/store:stored { st.crc: t6 }
            |> crctap(st.crc): t7 |> std/store:stored { st.crc: t7 }
            |> crctap(st.crc): t8 |> std/store:stored { st.crc: t8 }
    | done |> std/store:stored { st.acc: @rem(st.acc + (st.crc ^ 0xFFFFFFFF), 4294967296) }

std/io:print.ln("{{ st.acc:d }}")
