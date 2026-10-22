// compress_huff_encode — LangArena Compress::HuffEncode, run.js
// scored parameters (size=1000002, iterations=200, warmup=40 → 240
// runs; each run counts byte frequencies, builds the Huffman tree
// (stable sort + orderedRemove/insert merge), derives codes, and
// bit-packs the data MSB-first; result_val += encoded.len — oracle
// 62727600 = 240 × 261365).
//
// The reference's quirks are carried: the single-leaf case gets a
// dummy right child; buildHuffmanCodes assigns a code only when
// length>0 or byte_val!=0 (so the freq-0 dummy can "own" byte 0);
// the trailing partial byte is appended WITHOUT left-aligning (the
// pending bits already sit at the top of the byte).
//
// Wave-6: the emit path is per-symbol multi-bit, not bit-at-a-time,
// and the histogram is banked. Byte-exact verified against a Python
// replica of the reference algorithm (len 261365, FNV-1a of the full
// stream identical — /tmp/he_work/he_oracle.py vs /tmp/he_verify3.k).
//
//   EMIT — henc keeps a left-aligned bit-buffer in a u64 register
//   param: w's top wl bits are pending (next bit to emit at bit 63;
//   wl < 8 on entry). cod is ONE packed u64 word per symbol:
//   cl = (code << (64-len)) | len — the code pre-shifted to the TOP
//   of the word (len <= 56 always: a length-57 prefix code needs a
//   Fibonacci frequency larger than the input). Per symbol:
//     w |= (cl >> 8) << (8 - wl)   // >>8 drops len; <<(8-wl) lands
//                                  // the code directly below pending
//     wl += len
//   and hedr drains whole bytes (out[p] = w>>56, w <<= 8 — self-
//   cleaning, emitted bits shift out the top, no masking) until
//   wl < 8. u64 makes every shift logical — on i64, `cl >> 8` is
//   ARITHMETIC: a code with MSB=1 makes cl negative and sign-extends
//   1-bits that <<(8-wl) then ORs into the pending region — corrupt
//   byte values at a still-green length checksum (caught in review,
//   fixed by going u64 rather than by masking).
//   Loop state (w, wl, p) rides tor params — the baseline's per-bit
//   store-row round-trips (cb/bp/bits/p on every one of ~2.6M bits)
//   are gone.
//
//   HONESTY PROBE — hfin reads the last produced byte and compares it
//   to an out-of-range value (st.nn + 512 > any u8). Without a
//   consumed read reaching `res`, LLVM proves the entire `out` store
//   stream dead and the drain loop degenerates to shifts-only
//   (observed in disasm: p += count, w <<= 8*count, zero stores — a
//   faster program doing strictly less work than the reference,
//   which really writes 261365 bytes/run). The probe is one load/run;
//   the runtime-constant index means no store instance is provably
//   unread, so every run's stores survive (verified: `strb ...+0x1`
//   post-increment inside the drain loop on the emitted asm).
//
//   HISTOGRAM — 8-bank frq: slot = (i&7)*256 + byte. The test pattern
//   is ~45% 'A' at gaps of 2-3, so a single 256-bin table serializes
//   every RMW on the same address (store-forwarding latency).
//   Eight banks spread the hot bins; lfi sums the 8 banks per byte —
//   the sum is exactly the reference's frequencies[i]. zfr clears all
//   2048 slots per run; no epoch games.
//
//   Also: dat/pat/out are u8 columns (recipe 12) read through
//   borrowed slices — no per-access floor check in the 1e6-byte
//   passes.
//
// Falsified / rejected hypotheses (wave-6):
//   - "bit-at-a-time is the floor" — false; the multi-bit append is
//     ~12 instrs/symbol vs ~10 ops/bit × ~2.6 bits + store traffic.
//   - 16 histogram banks: no gain over 8 (forwarding window already
//     covered); 4 banks: no better. u32 frq cells: no gain — the loop
//     is memory-op-throughput-bound, not capacity-bound.
//   - Pair-symbol table (cod[(b1,b2)] = combined packed code):
//     rejected by arithmetic, unmeasured — l1+l2 can exceed the
//     56-bit headroom, and a 64K-entry rebuild per run (~64K stores ×
//     240) costs more than the ~0.1s the second lookup saves.
//   - Word-buffered output (pack 8 bytes per i64 store): rejected —
//     byte stores are ~0.26/symbol; the pack ops cost more than the
//     store bandwidth they save.

import std/io
import std/grid
import std/store

std/grid:new(pat, size: 11) { b: 0[u8] }
std/grid:new(dat, size: 1000002) { b: 0[u8] }
std/grid:new(frq, size: 2048) { v: 0[i64] }
std/grid:new(hn, size: 512) { fr: 0[i64], bv: 0[i64], lf: 0[i64], l: 0[i64], r: 0[i64] }
std/grid:new(hl, size: 512) { v: 0[i64] }
std/grid:new(cod, size: 256) { cl: 0[u64] }
std/grid:new(out, size: 300000) { b: 0[u8] }
std/grid:slice(datb) { dat.b }
std/grid:slice(frqv) { frq.v }
std/grid:slice(codcl) { cod.cl }
std/grid:slice(outb) { out.b }
std/store:new(st) { res: 0[i64], n: 1000002[i64], t1: 0[i64], t3: 0[i64], nn: 0[i64], ln: 0[i64], ii: 0[i64], pf: 0[i64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

pub tor idv { v: i64 } -> i64
idv -> v

pub tor idu { v: u64 } -> u64
idu -> v

// genl — test_data[i] = "ABRACADABRA"[i % 11]
pub tor genl { i: i64 } -> i64
genl = std/grid:stored { dat[i].b: pat[@rem(i, 11)].b }
    |> if(i < st.n - 1)
        | then |> genl(i: i + 1): r -> r
        | else |> ret0(): r -> r

// ---- per-run: frequencies ----
pub tor zfr { i: i64 } -> i64
zfr = std/grid:stored { frqv[@as(usize, @intCast(i))]: 0 }
    |> if(i < 2047)
        | then |> zfr(i: i + 1): r -> r
        | else |> ret0(): r -> r

// cntb — 8-bank histogram over the borrowed u8 column (see header).
pub tor cntb { i: i64, n: i64 } -> i64
cntb = std/grid:stored { frqv[@as(usize, @intCast((i & 7) * 256)) + @as(usize, @intCast(datb[@as(usize, @intCast(i))]))]: frqv[@as(usize, @intCast((i & 7) * 256)) + @as(usize, @intCast(datb[@as(usize, @intCast(i))]))] + 1 }
    |> if(i < n - 1)
        | then |> cntb(i: i + 1, n): r -> r
        | else |> ret0(): r -> r

// ---- leaf list: node per nonzero freq, in byte order ----
// f = sum of the 8 bank counts for byte i = the reference's freq
pub tor mkn { i: i64, f: i64 } -> i64
mkn = std/grid:stored { hn[st.nn].fr: f }
    |> std/grid:stored { hn[st.nn].bv: i }
    |> std/grid:stored { hn[st.nn].lf: 1 }
    |> std/grid:stored { hn[st.nn].l: -1 }
    |> std/grid:stored { hn[st.nn].r: -1 }
    |> std/grid:stored { hl[st.ln].v: st.nn }
    |> std/store:stored { st.nn: st.nn + 1 }
    |> std/store:stored { st.ln: st.ln + 1 }
    |> ret0(): _ -> 0

pub tor lfi { i: i64 } -> i64
lfi = if(i < 256)
| then |> idv(v: frqv[@as(usize, @intCast(i))] + frqv[@as(usize, @intCast(i + 256))] + frqv[@as(usize, @intCast(i + 512))] + frqv[@as(usize, @intCast(i + 768))] + frqv[@as(usize, @intCast(i + 1024))] + frqv[@as(usize, @intCast(i + 1280))] + frqv[@as(usize, @intCast(i + 1536))] + frqv[@as(usize, @intCast(i + 1792))]): f
    |> if(f > 0)
        | then |> mkn(i, f): _
            |> lfi(i: i + 1): r -> r
        | else |> lfi(i: i + 1): r -> r
| else -> 0

// ---- stable insertion sort of hl[] by node frequency ----
// sft shifts hlist[j] right while freq > key's; i/j in params
pub tor srtk { i: i64 } -> i64
srtk = std/store:stored { st.t1: hl[i].v }   // key node index
    |> sftk(i, j: i - 1): r -> r

pub tor sftk { i: i64, j: i64 } -> i64
sftk = if(j >= 0)
| then |> if(hn[hl[j].v].fr > hn[st.t1].fr)
    | then |> std/grid:stored { hl[j + 1].v: hl[j].v }
        |> sftk(i, j: j - 1): r -> r
    | else |> std/grid:stored { hl[j + 1].v: st.t1 }
        |> srtn(i): r -> r
| else |> std/grid:stored { hl[0].v: st.t1 }
    |> srtn(i): r -> r

pub tor srtn { i: i64 } -> i64
srtn = if(i < st.ln - 1)
| then |> srtk(i: i + 1): r -> r
| else |> ret0(): r -> r

// ---- merge loop: pop two smallest, insert parent by freq ----
// shl: hl[i] = hl[i+2] for i in 0..ln-3  (orderedRemove(0) x2)
pub tor shl { i: i64 } -> i64
shl = std/grid:stored { hl[i].v: hl[i + 2].v }
    |> if(i < st.ln - 3)
        | then |> shl(i: i + 1): r -> r
        | else |> ret0(): r -> r

// fnd: st.ii = first idx with freq >= st.pf (insert point)
pub tor fnd { j: i64 } -> i64
fnd = if(j < st.ln)
| then |> if(hn[hl[j].v].fr < st.pf)
    | then |> fnd(j: j + 1): r -> r
    | else |> std/store:stored { st.ii: j }
        |> ret0(): r -> r
| else |> std/store:stored { st.ii: j }
    |> ret0(): r -> r

// shr: shift hl[j] = hl[j-1] descending from ln down to ii+1
pub tor shr { j: i64 } -> i64
shr = if(j > st.ii)
| then |> std/grid:stored { hl[j].v: hl[j - 1].v }
    |> shr(j: j - 1): r -> r
| else |> ret0(): r -> r

// mrg — while ln > 1: a=hl[0], b=hl[1] → parent(a+b), insert sorted
pub tor mrg { } -> i64
mrg = if(st.ln > 1)
| then |> std/store:stored { st.pf: hn[hl[0].v].fr + hn[hl[1].v].fr }
    |> std/grid:stored { hn[st.nn].fr: st.pf }
    |> std/grid:stored { hn[st.nn].bv: 0 }
    |> std/grid:stored { hn[st.nn].lf: 0 }
    |> std/grid:stored { hn[st.nn].l: hl[0].v }
    |> std/grid:stored { hn[st.nn].r: hl[1].v }
    |> shl(i: 0): _
    |> std/store:stored { st.ln: st.ln - 2 }
    |> fnd(j: 0): _
    |> std/store:stored { st.t3: st.ln }
    |> shr(j: st.t3): _
    |> std/grid:stored { hl[st.ii].v: st.nn }
    |> std/store:stored { st.nn: st.nn + 1 }
    |> std/store:stored { st.ln: st.ln + 1 }
    |> mrg(): r -> r
| else -> 0

// sg1 — single-leaf special case: leaf + dummy(0,0) under a root;
// reference keeps leaf.frequency as the root's freq
pub tor sg1 { } -> i64
sg1 = std/grid:stored { hn[st.nn].fr: 0 }
    |> std/grid:stored { hn[st.nn].bv: 0 }
    |> std/grid:stored { hn[st.nn].lf: 1 }
    |> std/grid:stored { hn[st.nn].l: -1 }
    |> std/grid:stored { hn[st.nn].r: -1 }
    |> std/grid:stored { hn[st.nn + 1].fr: hn[hl[0].v].fr }
    |> std/grid:stored { hn[st.nn + 1].bv: 0 }
    |> std/grid:stored { hn[st.nn + 1].lf: 0 }
    |> std/grid:stored { hn[st.nn + 1].l: hl[0].v }
    |> std/grid:stored { hn[st.nn + 1].r: st.nn }
    |> std/grid:stored { hl[0].v: st.nn + 1 }
    |> std/store:stored { st.nn: st.nn + 2 }
    |> ret0(): _ -> 0

// hbuild — leaf list → sort → single-leaf special → merge loop
pub tor hbuild { } -> i64
hbuild = std/store:stored { st.nn: 0 }
    |> std/store:stored { st.ln: 0 }
    |> lfi(i: 0): _
    |> srtn(i: 0): _
    |> if(st.ln == 1)
        | then |> sg1(): r -> r
        | else |> mrg(): r -> r

// ---- code walk: DFS from root; leaf → cod[bv].cl =
// (code<<(64-len))|len when len>0 or bv!=0 — non-tail self-calls but
// depth <= 511 ----
// (bv!=0 && len==0 can only be a root leaf, unreachable here — the
// packed word for it is 0, matching code=0/length=0.)
pub tor hwk { n: i64, c: i64, l: i64 } -> i64
hwk = if(hn[n].lf == 1)
| then |> if(l > 0)
    | then |> std/grid:stored { cod[hn[n].bv].cl: (@as(u64, @intCast(c)) << @as(u6, @intCast(64 - l))) | @as(u64, @intCast(l)) }
        |> ret0(): r -> r
    | else |> if(hn[n].bv != 0)
        | then |> std/grid:stored { cod[hn[n].bv].cl: @as(u64, 0) }
            |> ret0(): r -> r
        | else |> ret0(): r -> r
| else |> hwk(n: hn[n].l, c: c * 2, l: l + 1): _
    |> hwk(n: hn[n].r, c: c * 2 + 1, l: l + 1): _
    |> ret0(): _ -> 0

// ---- encode: per byte append its whole code to a left-aligned
// register bit-buffer; hedr drains whole bytes while wl >= 8 ----
// henc(i, w, wl, p, n): w = pending bits at TOP of word (bit 63 is
// next to emit), wl = pending count (0..7 on entry), p = out cursor.
pub tor henc { i: i64, w: u64, wl: i64, p: i64, n: i64 } -> i64
henc = if(i < n)
| then |> idu(v: codcl[@as(usize, @intCast(datb[@as(usize, @intCast(i))]))]): cl
    |> idv(v: @as(i64, @intCast(cl & @as(u64, 255)))): l
    |> idu(v: w | ((cl >> @as(u6, 8)) << @as(u6, @intCast(8 - wl)))): w2
    |> hedr(i, w: w2, wl: wl + l, p, n): r -> r
| else |> if(wl > 0)
    | then |> std/grid:stored { outb[@as(usize, @intCast(p))]: @as(u8, @intCast(w >> @as(u6, 56))) }
        |> hfin(p: p + 1): r -> r
    | else |> hfin(p): r -> r

// hedr — emit w's top byte per iteration until wl < 8 pending
pub tor hedr { i: i64, w: u64, wl: i64, p: i64, n: i64 } -> i64
hedr = if(wl >= 8)
| then |> std/grid:stored { outb[@as(usize, @intCast(p))]: @as(u8, @intCast(w >> @as(u6, 56))) }
    |> hedr(i, w: w << @as(u6, 8), wl: wl - 8, p: p + 1, n): r -> r
| else |> henc(i: i + 1, w, wl, p, n): r -> r

// hfin — close the run: st.res += encoded length (p bytes). The
// probe keeps every run's `out` stores live (see header).
pub tor hfin { p: i64 } -> i64
hfin = if(p > 0 and @as(i64, outb[@as(usize, @intCast(p - 1))]) == st.nn + 512)
| then |> std/store:stored { st.res: st.res + p + 1 }
    |> ret0(): r -> r
| else |> std/store:stored { st.res: st.res + p }
    |> ret0(): r -> r

// run1 — one runImpl: freqs, tree, codes, encode
pub tor run1 { } -> i64
run1 = zfr(i: 0): _
    |> cntb(i: 0, st.n): _
    |> hbuild(): _
    |> hwk(n: hl[0].v, c: 0, l: 0): _
    |> henc(i: 0, w: @as(u64, 0), wl: 0, p: 0, st.n): r -> r

// runl — 240 runs
pub tor runl { k: i64 } -> i64
runl = run1(): _
    |> if(k < 239)
        | then |> runl(k: k + 1): r -> r
        | else |> ret0(): r -> r

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
|> runl(k: 0): _
|> std/io:print.ln("{{ st.res:d }}")
