// compress_lzw_decode — LangArena Compress::LZWDecode, run.js
// scored parameters (size=1000007, iterations=1600, warmup=320 →
// 1920 runs). prepare runs lzwEncode once; each run rebuilds the
// decode dict (dd[c] = dec offset + len per code) and walks the u16
// code stream, appending each string to `dec`; the current_code ==
// next_code case synthesizes previous_str + previous_str[0].
// result_val += decoded.len; +100000 on byte-exact roundtrip —
// oracle 1920113440 = 1920 × 1000007 + 100000.
//
// Decode needs no hashing: dict is a code-indexed table. Encode is
// keyed by injective (code,byte) pairs — no hashing either.
//
// Perf (2026-10-22): byte grids are u8 (i64 cells were 8x the
// copy traffic — the single biggest deficit), emt/c2p were
// counted-for copies over borrowed pl/dl slices (verbatim
// indexing, ds bumped per string not per byte). Encoded stream
// is 9358B = 4679 codes, so per-code st.* traffic is trivial;
// the byte volume is the task. 1.70s -> 0.59s.
//
// Wave-6 (2026-10-22): two changes.
// (a) Decode dict materialized INTO dec: each inserted entry is
//     prev_emission ++ cur[0], already contiguous in dec (emissions
//     are sequential), so dd[c] = (dec offset, len) and insert is
//     two scalar stores — the pool->pool entry copy (~1MB/run) gone.
//     Emits are dec->dec counted-for copies (src ends <= dest,
//     always safe) or a byte store for literals. ~2x bytes/run -> ~1x.
// (b) Encode rekeyed on injective (cur_code*256+byte) — one direct
//     probe per input byte, no string materialization/hashing
//     (recipe 14). lzi was ~0.40s of the 0.48s process — the
//     phase-split falsified "decode is the task": 1920 decodes cost
//     ~0.09s; the prepare-time string-table encode cost ~0.40s.
// Falsified: prefix-chain/parent-pointer walk for decode — ~1M
//     dependent loads/run (~1ms/run at L1 latency) vs 46us/run for
//     the vectorized materialized copy; the walk answers the wrong
//     problem (latency vs bandwidth), same lesson as bwt_decode.
// Disclosed representation changes (PERF.md recipes 7/11/14): the
// decode dictionary is materialized BY the output buffer, not beside
// it; the encode dictionary is keyed by the injective pair, not the
// string. Same greedy parse, same code stream, same byte-exact dec.
// 0.57s -> 0.10s, checksum 1920113440 verified.

import std/io
import std/grid
import std/store

std/grid:new(pat, size: 11) { b: 0[u8] }
std/grid:new(dat, size: 1000007) { b: 0[u8] }
std/grid:new(kt, size: 1400000) { v: 0[i64] }
std/grid:new(out, size: 400100) { b: 0[u8] }
std/grid:new(dec, size: 1000007) { b: 0[u8] }
std/grid:new(dd, size: 100000) { off: 0[i64], ln: 0[i64] }
std/grid:slice(dl) { dec.b }
std/store:new(st) { res: 0[i64], n: 1000007[i64], p: 0[i64], cs: 0[i64], cl: 0[i64], ep: 0[i64], pc: 0[i64], nc: 0[i64], hh: 0[i64], sl: 0[i64], sn: 0[i64], ql: 0[i64], t1: 0[i64], t2: 0[i64], t3: 0[i64], sym: 0[i64], ds: 0[i64], el: 0[i64], pos: 0[i64], prc: 0[i64], prs: 0[i64], prl: 0[i64], ok: 0[i64], cc: 0[i64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// genl — test_data[i] = "ABRACADABRA"[i % 11]
pub tor genl { i: i64 } -> i64
genl = std/grid:stored { dat[i].b: pat[@rem(i, 11)].b }
    |> if(i < st.n - 1)
        | then |> genl(i: i + 1): r -> r
        | else |> ret0(): r -> r

// emit — append code as big-endian u16
pub tor emit { c: i64 } -> i64
emit = std/grid:stored { out[st.p].b: @as(u8, @intCast(@rem(@divFloor(c, 256), 256))) }
    |> std/grid:stored { out[st.p + 1].b: @as(u8, @intCast(@rem(c, 256))) }
    |> std/store:stored { st.p: st.p + 2 }
    |> ret0(): _ -> 0

// lzi — greedy scan keyed by the injective pair (cur_code, byte):
// every candidate phrase is an existing phrase plus one byte, so
// key = cur_code*256+byte is unique per phrase and kt[key] = code
// (0 = empty) answers contains_key + insert in one probe — no string
// materialization, no hashing, no equality walk (PERF.md recipe 14,
// same rewrite the lzw_encode contestant used). Seed phrases (len 1)
// never enter kt: after a miss the current code is the byte itself.
// Code stream identical to the reference's HashMap<Vec<u8>> dict.
// kt bound: nc reaches 4934 on this input, max key 1263359 < 1400000.
pub tor lzi { i: i64 } -> i64
lzi = if(i < st.n)
| then |> std/store:stored { st.t1: st.cc * 256 + @as(i64, dat[i].b) }
    |> if(kt[st.t1].v != 0)
        | then |> std/store:stored { st.cc: kt[st.t1].v }
            |> lzi(i: i + 1): r -> r
        | else |> emit(c: st.cc): _
            |> std/grid:stored { kt[st.t1].v: st.nc }
            |> std/store:stored { st.nc: st.nc + 1 }
            |> std/store:stored { st.cc: @as(i64, dat[i].b) }
            |> lzi(i: i + 1): r -> r
| else -> 0

// enc1 — the one prepare-time lzwEncode
pub tor enc1 { } -> i64
enc1 = std/store:stored { st.nc: 256 }
    |> std/store:stored { st.p: 0 }
    |> std/store:stored { st.cc: @as(i64, dat[0].b) }
    |> lzi(i: 1): _
    |> emit(c: st.cc): _
    |> std/store:stored { st.el: st.p }
    |> ret0(): _ -> 0

// ---- decode ----
// Dict entries are (offset,len) pairs pointing INTO dec itself: the
// inserted entry prev_str ++ cur_str[0] occupies the contiguous range
// dec[prev_emit_start .. cur_emit_start + 1] — already written, since
// emissions are sequential. Insert is therefore two scalar stores and
// emitting a code >= 256 is a forward dec->dec copy whose source always
// ends at or before the destination (prev emission ends exactly where
// the next begins), so the counted-for is overlap-safe. A code < 256
// is a single literal byte store. No string materialization pass and
// no prefix-chain walk: ~1x output bytes moved per run instead of ~2x.
//
// emd — copy dec[off..off+l] to dec at st.ds; ds bumped per string.
pub tor emd { off: i64, l: i64 } -> i64
emd = for(0..@as(usize, @intCast(l)))
    ! each k |> std/grid:stored { dl[@as(usize, @intCast(st.ds)) + k]: dl[@as(usize, @intCast(off)) + k] }
    |> std/store:stored { st.ds: st.ds + l }
    |> ret0(): _ -> 0

// ddi — dict append: dd[nc] = (prev emission start, prev_len + 1)
pub tor ddi { } -> i64
ddi = std/grid:stored { dd[st.nc].off: st.prs }
    |> std/grid:stored { dd[st.nc].ln: st.prl + 1 }
    |> std/store:stored { st.nc: st.nc + 1 }
    |> ret0(): _ -> 0

// lzd — code-stream walk. st.pos cursor; st.prs/st.prl = the previous
// emission's (dec offset, len). Three cases per code: <256 -> literal;
// < nc -> table hit (emd); == nc -> synth prev_str+prev_str[0] (the
// emitted range IS the new entry); else -> stop (InvalidCode).
pub tor lzd { } -> i64
lzd = if(st.pos < st.el)
| then |> std/store:stored { st.t1: @as(i64, out[st.pos].b) * 256 + @as(i64, out[st.pos + 1].b) }
    |> std/store:stored { st.pos: st.pos + 2 }
    |> if(st.t1 < 256)
        | then |> std/store:stored { st.t3: st.ds }
            |> std/grid:stored { dl[@as(usize, @intCast(st.ds))]: @as(u8, @intCast(st.t1)) }
            |> std/store:stored { st.ds: st.ds + 1 }
            |> ddi(): _
            |> std/store:stored { st.prs: st.t3 }
            |> std/store:stored { st.prl: 1 }
            |> lzd(): r -> r
        | else |> if(st.t1 < st.nc)
            | then |> std/store:stored { st.t3: st.ds }
                |> std/store:stored { st.t2: dd[st.t1].ln }
                |> emd(off: dd[st.t1].off, l: st.t2): _
                |> ddi(): _
                |> std/store:stored { st.prs: st.t3 }
                |> std/store:stored { st.prl: st.t2 }
                |> lzd(): r -> r
            | else |> if(st.t1 == st.nc)
                | then |> std/store:stored { st.t3: st.ds }
                    |> emd(off: st.prs, l: st.prl): _
                    |> std/grid:stored { dl[@as(usize, @intCast(st.ds))]: dl[@as(usize, @intCast(st.prs))] }
                    |> std/store:stored { st.ds: st.ds + 1 }
                    |> std/grid:stored { dd[st.nc].off: st.t3 }
                    |> std/grid:stored { dd[st.nc].ln: st.prl + 1 }
                    |> std/store:stored { st.nc: st.nc + 1 }
                    |> std/store:stored { st.prs: st.t3 }
                    |> std/store:stored { st.prl: st.prl + 1 }
                    |> lzd(): r -> r
                | else |> ret0(): r -> r
| else -> 0

// run1 — one lzwDecode over the encoded stream. First code is a
// literal byte by domain (encoder's first emit is always a seeded
// code < 256 — Rust indexes dict[first] which panics otherwise).
pub tor run1 { } -> i64
run1 = std/store:stored { st.nc: 256 }
    |> std/store:stored { st.ds: 0 }
    |> std/store:stored { st.t1: @as(i64, out[0].b) * 256 + @as(i64, out[1].b) }
    |> std/store:stored { st.pos: 2 }
    |> if(st.t1 < 256)
        | then |> std/grid:stored { dl[0]: @as(u8, @intCast(st.t1)) }
            |> std/store:stored { st.ds: 1 }
            |> std/store:stored { st.prs: 0 }
            |> std/store:stored { st.prl: 1 }
            |> lzd(): r -> r
        | else |> ret0(): r -> r

// runl — 1920 runs; result_val += decoded.len per run
pub tor runl { k: i64 } -> i64
runl = run1(): _
    |> std/store:stored { st.res: st.res + st.ds }
    |> if(k < 1919)
        | then |> runl(k: k + 1): r -> r
        | else |> ret0(): r -> r

// vfy — checksum's mem.eql(test_data, decoded)
pub tor vfy { i: i64 } -> i64
vfy = if(i < st.n)
| then |> if(dat[i].b == dec[i].b)
    | then |> vfy(i: i + 1): r -> r
    | else |> ret0(): r -> r
| else |> std/store:stored { st.ok: 1 }
    |> ret0(): r -> r

pub tor fin { } -> i64
fin = if(st.ds == st.n)
| then |> vfy(i: 0): _
    |> if(st.ok == 1)
        | then |> std/store:stored { st.res: st.res + 100000 }
            |> ret0(): r -> r
        | else |> ret0(): r -> r
| else -> 0

// ---- driver ----
ret0(): _
|> std/grid:stored { pat[0].b: @as(u8, 65) }
|> std/grid:stored { pat[1].b: @as(u8, 66) }
|> std/grid:stored { pat[2].b: @as(u8, 82) }
|> std/grid:stored { pat[3].b: @as(u8, 65) }
|> std/grid:stored { pat[4].b: @as(u8, 67) }
|> std/grid:stored { pat[5].b: @as(u8, 65) }
|> std/grid:stored { pat[6].b: @as(u8, 68) }
|> std/grid:stored { pat[7].b: @as(u8, 65) }
|> std/grid:stored { pat[8].b: @as(u8, 66) }
|> std/grid:stored { pat[9].b: @as(u8, 82) }
|> std/grid:stored { pat[10].b: @as(u8, 65) }
|> genl(i: 0): _
|> enc1(): _
|> runl(k: 0): _
|> fin(): _
|> std/io:print.ln("{{ st.res:d }}")
