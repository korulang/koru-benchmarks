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
// the trailing partial byte is appended WITHOUT left-aligning.

import std/io
import std/grid
import std/store

std/grid:new(pat, size: 11) { b: 0[i64] }
std/grid:new(dat, size: 1000002) { b: 0[i64] }
std/grid:new(frq, size: 256) { v: 0[i64] }
std/grid:new(hn, size: 512) { fr: 0[i64], bv: 0[i64], lf: 0[i64], l: 0[i64], r: 0[i64] }
std/grid:new(hl, size: 512) { v: 0[i64] }
std/grid:new(cod, size: 256) { c: 0[i64], l: 0[i64] }
std/grid:new(out, size: 300000) { b: 0[i64] }
std/store:new(st) { res: 0[i64], n: 1000002[i64], p: 0[i64], cb: 0[i64], bp: 0[i64], bits: 0[i64], t1: 0[i64], t2: 0[i64], t3: 0[i64], nn: 0[i64], ln: 0[i64], acc: 0[i64], ii: 0[i64], pf: 0[i64] }

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

// ---- per-run: frequencies ----
pub tor zfr { i: i64 } -> i64
zfr = std/grid:stored { frq[i].v: 0 }
    |> if(i < 255)
        | then |> zfr(i: i + 1): r -> r
        | else |> ret0(): r -> r

pub tor cntb { i: i64 } -> i64
cntb = std/grid:stored { frq[dat[i].b].v: frq[dat[i].b].v + 1 }
    |> if(i < st.n - 1)
        | then |> cntb(i: i + 1): r -> r
        | else |> ret0(): r -> r

// ---- leaf list: node per nonzero freq, in byte order ----
pub tor mkn { i: i64 } -> i64
mkn = std/grid:stored { hn[st.nn].fr: frq[i].v }
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
| then |> if(frq[i].v > 0)
    | then |> mkn(i): _
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

// ---- code walk: DFS from root; leaf → cod[bv] = (code, len) when
// len>0 or bv!=0 — non-tail self-calls but depth <= 511 ----
pub tor hwk { n: i64, c: i64, l: i64 } -> i64
hwk = if(hn[n].lf == 1)
| then |> if(l > 0)
    | then |> std/grid:stored { cod[hn[n].bv].c: c }
        |> std/grid:stored { cod[hn[n].bv].l: l }
        |> ret0(): r -> r
    | else |> if(hn[n].bv != 0)
        | then |> std/grid:stored { cod[hn[n].bv].c: c }
            |> std/grid:stored { cod[hn[n].bv].l: l }
            |> ret0(): r -> r
        | else |> ret0(): r -> r
| else |> hwk(n: hn[n].l, c: c * 2, l: l + 1): _
    |> hwk(n: hn[n].r, c: c * 2 + 1, l: l + 1): _
    |> ret0(): _ -> 0

// ---- encode: per byte emit its code MSB-first ----
// henc(i,k): k==0 → load byte i's code (k:=len); k>0 → emit bit k-1
pub tor henc { i: i64, k: i64 } -> i64
henc = if(k == 0)
| then |> if(i < st.n)
    | then |> std/store:stored { st.t1: dat[i].b }
        |> std/store:stored { st.t2: cod[st.t1].c }
        |> henc(i, k: cod[st.t1].l): r -> r
    | else |> ret0(): r -> r
| else |> std/store:stored { st.cb: st.cb + @rem(@divFloor(st.t2, @as(i64, 1) << @as(u6, @intCast(k - 1))), 2) * (@as(i64, 1) << @as(u6, @intCast(7 - st.bp))) }
    |> std/store:stored { st.bits: st.bits + 1 }
    |> if(st.bp == 7)
        | then |> std/grid:stored { out[st.p].b: st.cb }
            |> std/store:stored { st.p: st.p + 1 }
            |> std/store:stored { st.cb: 0 }
            |> std/store:stored { st.bp: 0 }
            |> if(k - 1 == 0)
                | then |> henc(i: i + 1, k: 0): r -> r
                | else |> henc(i, k: k - 1): r -> r
        | else |> std/store:stored { st.bp: st.bp + 1 }
            |> if(k - 1 == 0)
                | then |> henc(i: i + 1, k: 0): r -> r
                | else |> henc(i, k: k - 1): r -> r

// hfl — flush partial byte (no alignment shift — the reference
// appends current_byte as-is) and close the run
pub tor hfl { } -> i64
hfl = if(st.bp > 0)
| then |> std/grid:stored { out[st.p].b: st.cb }
    |> std/store:stored { st.res: st.res + st.p + 1 }
    |> ret0(): r -> r
| else |> std/store:stored { st.res: st.res + st.p }
    |> ret0(): r -> r

// run1 — one runImpl: freqs, tree, codes, encode
pub tor run1 { } -> i64
run1 = zfr(i: 0): _
    |> cntb(i: 0): _
    |> hbuild(): _
    |> hwk(n: hl[0].v, c: 0, l: 0): _
    |> std/store:stored { st.p: 0 }
    |> std/store:stored { st.cb: 0 }
    |> std/store:stored { st.bp: 0 }
    |> std/store:stored { st.bits: 0 }
    |> henc(i: 0, k: 0): _
    |> hfl(): r -> r

// runl — 240 runs
pub tor runl { k: i64 } -> i64
runl = run1(): _
    |> if(k < 239)
        | then |> runl(k: k + 1): r -> r
        | else |> ret0(): r -> r

// ---- driver ----
ret0(): _
|> std/grid:stored { pat[0].b: 65 }
|> std/grid:stored { pat[1].b: 66 }
|> std/grid:stored { pat[2].b: 82 }
|> std/grid:stored { pat[3].b: 65 }
|> std/grid:stored { pat[4].b: 67 }
|> std/grid:stored { pat[5].b: 65 }
|> std/grid:stored { pat[6].b: 68 }
|> std/grid:stored { pat[7].b: 65 }
|> std/grid:stored { pat[8].b: 66 }
|> std/grid:stored { pat[9].b: 82 }
|> std/grid:stored { pat[10].b: 65 }
|> genl(i: 0): _
|> runl(k: 0): _
|> std/io:print.ln("{{ st.res:d }}")
