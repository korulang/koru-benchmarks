// hash_sha256 — LangArena Hash::SHA256, run.js scored parameters
// (size 1_000_000, iterations 1200, warmup 240 -> 1440 accumulations,
// oracle 2844672256).
//
// NOTE: LangArena's "SHA256" is a TOY hash (SimpleSHA256), not SHA-256:
//   per byte i: lane j = i % 8;
//     h = ((h << 5) &+ h) &+ byte          (u32 wrap)
//     h = (h &+ (h << 10)) ^ (h >> 6)      (u32 wrap on the sum)
//   digest = 8 lanes big-endian; test returns the first 4 digest bytes
//   reinterpreted as a NATIVE-endian u32 -> bswap32(h0) on little-endian.
//
// Faithfulness differences, stated:
// - lanes/acc in i64 with explicit mod-2^32 folds (store leaves don't
//   take u32; every intermediate < 2^63 by construction)
// - lanes re-initialized per run (reference: fresh StaticArray)
// - tape/data fixed 1M u8 grid, LCG-filled once in prepare (same LCG
//   byte stream as hash_crc32 — Helper.reset boundary is irrelevant
//   here because all runs hash the same prepared buffer)
//
import std/io
import std/grid
import std/store

std/grid:new(data, size: 1000000) { b: 0[u8] }
std/grid:new(hh, size: 8) { v: 0[i64] }
std/store:new(st) { last: 42[i64], x: 0[i64], acc: 0[i64] }

// prepare: fill data once via the LangArena LCG (nextInt(256) per byte)
for(0..1000000)
! each i |> std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }
    |> std/grid:stored { data[i].b: @as(u8, @intCast(@as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) * 256.0 / 139968.0)))) }

// run: 1440 accumulations; each re-digests the buffer — the measured work.
for(0..1440)
! each it |> std/grid:stored { hh[0].v: 0x6a09e667 }
    |> std/grid:stored { hh[1].v: 0xbb67ae85 }
    |> std/grid:stored { hh[2].v: 0x3c6ef372 }
    |> std/grid:stored { hh[3].v: 0xa54ff53a }
    |> std/grid:stored { hh[4].v: 0x510e527f }
    |> std/grid:stored { hh[5].v: 0x9b05688c }
    |> std/grid:stored { hh[6].v: 0x1f83d9ab }
    |> std/grid:stored { hh[7].v: 0x5be0cd19 }
    |> for(0..1000000)
        ! each i |> std/store:stored { st.x: hh[@rem(@as(i64, @intCast(i)), 8)].v }
            |> std/store:stored { st.x: @rem((st.x << 5) + st.x + @as(i64, data[i].b), 4294967296) }
            |> std/store:stored { st.x: @rem(st.x + (st.x << 10), 4294967296) ^ (st.x >> 6) }
            |> std/grid:stored { hh[@rem(@as(i64, @intCast(i)), 8)].v: st.x }
    | done |> std/store:stored { st.acc: @rem(st.acc + @rem(((hh[0].v & 255) << 24) + ((hh[0].v & 65280) << 8) + ((hh[0].v >> 8) & 65280) + (hh[0].v >> 24), 4294967296), 4294967296) }

std/io:print.ln("{{ st.acc:d }}")
