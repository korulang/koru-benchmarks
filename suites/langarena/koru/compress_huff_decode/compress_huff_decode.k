// compress_huff_decode — LangArena Compress::HuffDecode, run.js
// scored parameters (size=1000003, iterations=350, warmup=70 → 420
// runs). prepare runs the HuffEncode pipeline once (frequencies,
// ordered-merge tree, MSB-first bit pack); each run decodes the
// stream (left=0, right=1; a leaf emits only when byte_val != 0 —
// the freq-0 dummy quirk carried). result_val += decoded.len;
// checksum adds +100000 when decoded == test_data byte-exact —
// oracle 420101260.
//
// Wave-5: falsified the prior "bit-by-bit serial floor" claim.
// The floor was the representation, not the dependency. Decode
// is a per-node transition table instead of a tree walk:
//   lut[node*256 + byte]  → packed emitted bytes + (count|next)
//   lu2[rank*65536 + u16] → two packed output words + (count|next)
// Internal nodes are re-ranked 0..nr-1 so the 16-bit table is
// nr*64K rows; trees with >16 internals use the byte table (same
// semantics — still a faithful decode, not a degraded path).
// Tables are built once from the same tree the run loop would
// rebuild (loop-invariant hoist, same as the baseline's tree).
// Each run still decodes all bit_count bits MSB-first, writes the
// decoded bytes, and returns decoded.len — the residual tail bits
// (<16) finish on the same table at byte granularity plus the
// original bit walk. Edge probes (/tmp/hd_pa|b|c.k, hd_t_ab.k)
// cover >16-internal fallback, multi-rank 16-bit, two-symbol, and
// single-leaf/dummy-leaf trees — all byte-exact, checksum green.

import std/io
import std/grid
import std/store

std/grid:new(pat, size: 11) { b: 0[u8] }
std/grid:new(dat, size: 1000003) { b: 0[u8] }
std/grid:new(frq, size: 256) { v: 0[i64] }
std/grid:new(hn, size: 512) { fr: 0[i64], bv: 0[i64], lf: 0[i64], l: 0[i64], r: 0[i64] }
std/grid:new(hl, size: 512) { v: 0[i64] }
std/grid:new(cod, size: 256) { c: 0[i64], l: 0[i64] }
std/grid:new(out, size: 300000) { b: 0[u8] }
// dec as packed i64 words: decode emits into a u64 register, flushed 8B/store
std/grid:new(decq, size: 125010) { q: 0[i64] }
// lut[node*256 + byte] = {pk: emitted bytes packed LSB-first, cx: count|next<<4}
// covering every (node, window) state incl. mid-code carry — the tree walk
// tabled. Rows built only for internal nodes; a leaf `cur` cannot occur.
std/grid:new(lut, size: 131072) { pk: 0[i64], cx: 0[i64] }
// lu2[rank*65536 + w16]: rank = internal node idx - leaf count. Emits up to
// 16 packed bytes (p0 low, p1 high); cx = count | next_rank<<5. The T-squared
// of lut: one lookup consumes TWO stream bytes.
std/grid:new(lu2, size: 1048576) { p0: 0[i64], p1: 0[i64], cx: 0[i64] }
std/grid:slice(hnl) { hn.l }
std/grid:slice(hnr) { hn.r }
std/grid:slice(hnlf) { hn.lf }
std/grid:slice(hnbv) { hn.bv }
std/grid:slice(outb) { out.b }
std/grid:slice(decw) { decq.q }
std/grid:slice(lutpk) { lut.pk }
std/grid:slice(lutcx) { lut.cx }
std/grid:slice(lu2p0) { lu2.p0 }
std/grid:slice(lu2p1) { lu2.p1 }
std/grid:slice(lu2cx) { lu2.cx }
std/store:new(st) { res: 0[i64], n: 1000003[i64], p: 0[i64], cb: 0[i64], bp: 0[i64], bits: 0[i64], t1: 0[i64], t2: 0[i64], t3: 0[i64], nn: 0[i64], ln: 0[i64], acc: 0[i64], ii: 0[i64], pf: 0[i64], bc: 0[i64], fb: 0[i64], f6: 0[i64], u16: 0[i64], ln2: 0[i64], pr: 0[i64], ds: 0[i64], cur: 0[i64], el: 0[i64], ok: 0[i64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

pub tor idv { v: i64 } -> i64
idv -> v

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
cntb = std/grid:stored { frq[@as(usize, @intCast(dat[i].b))].v: frq[@as(usize, @intCast(dat[i].b))].v + 1 }
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
    |> std/store:stored { st.ln2: st.ln }
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
    | then |> std/store:stored { st.t1: @as(i64, dat[i].b) }
        |> std/store:stored { st.t2: cod[st.t1].c }
        |> henc(i, k: cod[st.t1].l): r -> r
    | else |> ret0(): r -> r
| else |> std/store:stored { st.cb: st.cb + @rem(@divFloor(st.t2, @as(i64, 1) << @as(u6, @intCast(k - 1))), 2) * (@as(i64, 1) << @as(u6, @intCast(7 - st.bp))) }
    |> std/store:stored { st.bits: st.bits + 1 }
    |> if(st.bp == 7)
        | then |> std/grid:stored { out[st.p].b: @as(u8, @intCast(st.cb)) }
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
// appends current_byte as-is); records encoded length
pub tor hfl { } -> i64
hfl = if(st.bp > 0)
| then |> std/grid:stored { out[st.p].b: @as(u8, @intCast(st.cb)) }
    |> std/store:stored { st.el: st.p + 1 }
    |> ret0(): r -> r
| else |> std/store:stored { st.el: st.p }
    |> ret0(): r -> r

// ---- decode table: lut[cur*256 + w] = {pk, cn | nx<<4} by simulating
// the reference walk over window bits (MSB-first). Consumed count is
// always 8: a code split by the boundary carries `cur` = mid-tree node.
pub tor blw { n0: i64, w: i64, j: i64, c2: i64, pk: i64, cn: i64, root: i64 } -> i64
blw = if(j < 8)
| then |> idv(v: (w >> @as(u6, @intCast(7 - j))) & 1): bit
    |> idv(v: if(bit == 1) hnr[@as(usize, @intCast(c2))] else hnl[@as(usize, @intCast(c2))]): nc
    |> if(hnlf[@as(usize, @intCast(nc))] == 1)
        | then |> if(hnbv[@as(usize, @intCast(nc))] != 0)
            | then |> blw(n0, w, j: j + 1, c2: root, pk: pk | (hnbv[@as(usize, @intCast(nc))] << @as(u6, @intCast(cn * 8))), cn: cn + 1, root): r -> r
            | else |> blw(n0, w, j: j + 1, c2: root, pk, cn, root): r -> r
        | else |> blw(n0, w, j: j + 1, c2: nc, pk, cn, root): r -> r
| else |> std/grid:stored { lut[n0 * 256 + w].pk: pk }
    |> std/grid:stored { lut[n0 * 256 + w].cx: cn | (c2 << 4) }
    |> ret0(): r -> r

pub tor bldw { n0: i64, w: i64, root: i64 } -> i64
bldw = blw(n0, w, j: 0, c2: n0, pk: 0, cn: 0, root): _
    |> if(w < 255)
        | then |> bldw(n0, w: w + 1, root): r -> r
        | else |> ret0(): r -> r

pub tor bldn { n0: i64, nn: i64, root: i64 } -> i64
bldn = if(n0 < nn)
| then |> if(hnlf[@as(usize, @intCast(n0))] == 0)
        | then |> bldw(n0, w: 0, root): _
            |> bldn(n0: n0 + 1, nn, root): r -> r
        | else |> bldn(n0: n0 + 1, nn, root): r -> r
| else -> 0

// ---- 16-bit table: same walk over a 2-byte window, per internal rank ----
pub tor blw2 { rk: i64, w: i64, j: i64, c2: i64, p0: i64, p1: i64, cn: i64, root: i64, ln: i64 } -> i64
blw2 = if(j < 16)
| then |> idv(v: (w >> @as(u6, @intCast(15 - j))) & 1): bit
    |> idv(v: if(bit == 1) hnr[@as(usize, @intCast(c2))] else hnl[@as(usize, @intCast(c2))]): nc
    |> if(hnlf[@as(usize, @intCast(nc))] == 1)
        | then |> if(hnbv[@as(usize, @intCast(nc))] != 0)
            | then |> if(cn < 8)
                | then |> blw2(rk, w, j: j + 1, c2: root, p0: p0 | (hnbv[@as(usize, @intCast(nc))] << @as(u6, @intCast(cn * 8))), p1, cn: cn + 1, root, ln): r -> r
                | else |> blw2(rk, w, j: j + 1, c2: root, p0, p1: p1 | (hnbv[@as(usize, @intCast(nc))] << @as(u6, @intCast((cn - 8) * 8))), cn: cn + 1, root, ln): r -> r
            | else |> blw2(rk, w, j: j + 1, c2: root, p0, p1, cn, root, ln): r -> r
        | else |> blw2(rk, w, j: j + 1, c2: nc, p0, p1, cn, root, ln): r -> r
| else |> std/grid:stored { lu2[rk * 65536 + w].p0: p0 }
    |> std/grid:stored { lu2[rk * 65536 + w].p1: p1 }
    |> std/grid:stored { lu2[rk * 65536 + w].cx: cn | ((c2 - ln) << 5) }
    |> ret0(): r -> r

pub tor bldw2 { rk: i64, w: i64, root: i64, ln: i64 } -> i64
bldw2 = blw2(rk, w, j: 0, c2: rk + ln, p0: 0, p1: 0, cn: 0, root, ln): _
    |> if(w < 65535)
        | then |> bldw2(rk, w: w + 1, root, ln): r -> r
        | else |> ret0(): r -> r

pub tor bldn2 { rk: i64, nr: i64, root: i64, ln: i64 } -> i64
bldn2 = if(rk < nr)
| then |> bldw2(rk, w: 0, root, ln): _
    |> bldn2(rk: rk + 1, nr, root, ln): r -> r
| else -> 0

// enc1 — the one prepare-time encode (HuffEncode.prepare + one run)
pub tor enc1 { } -> i64
enc1 = zfr(i: 0): _
    |> cntb(i: 0): _
    |> hbuild(): _
    |> hwk(n: hl[0].v, c: 0, l: 0): _
    |> bldn(n0: 0, st.nn, root: hl[0].v): _
    |> std/store:stored { st.u16: if(st.nn - st.ln2 <= 16) @as(i64, 1) else @as(i64, 0) }
    |> bldn2(rk: 0, nr: if(st.nn - st.ln2 < 16) st.nn - st.ln2 else @as(i64, 16), root: hl[0].v, ln: st.ln2): _
    |> std/store:stored { st.p: 0 }
    |> std/store:stored { st.cb: 0 }
    |> std/store:stored { st.bp: 0 }
    |> std/store:stored { st.bits: 0 }
    |> henc(i: 0, k: 0): _
    |> hfl(): _
    |> std/store:stored { st.bc: st.bits }
    |> std/store:stored { st.fb: @divFloor(st.bits, 8) }
    |> std/store:stored { st.f6: @divFloor(st.bits, 16) }
    |> ret0(): _ -> 0

// ---- decode: one byte per step through the (node, byte) table ----
// Register-carried: b = input byte idx, cur = mid-code node (root at a code
// boundary), qw = output word idx, acc = pending emitted bytes packed
// LSB-first (low `fill` bytes valid), fill in 0..7. fb = bc>>3 full bytes;
// rem = bc&7 tail bits. Per step: w = out[b]; e = lut[cur*256+w]; emit its
// packed bytes through the acc word; carry its next node.
pub tor hdec { b: i64, cur: i64, qw: i64, acc: i64, fill: i64, fb: i64, rem: i64, root: i64 } -> i64
hdec = if(b < fb)
| then |> idv(v: @as(i64, outb[@as(usize, @intCast(b))])): w
    |> idv(v: lutpk[@as(usize, @intCast(cur * 256 + w))]): pk
    |> idv(v: lutcx[@as(usize, @intCast(cur * 256 + w))]): cnx
    |> idv(v: acc | (pk << @as(u6, @intCast(fill * 8)))): ac2
    |> idv(v: fill + (cnx & 15)): nb
    |> idv(v: (pk >> @as(u6, @intCast(((8 - fill) * 8) & 63))) & ((@as(i64, 1) << @as(u6, @intCast(((nb - 8) * 8) & 63))) - 1)): sp
    |> std/grid:stored { decw[@as(usize, @intCast(qw))]: ac2 }
    |> hdec(b: b + 1, cur: cnx >> 4,
        qw: qw + (if(nb >= 8) @as(i64, 1) else @as(i64, 0)),
        acc: if(nb >= 8) sp else ac2,
        fill: if(nb >= 8) nb - 8 else nb,
        fb, rem, root): r -> r
| else |> htl(s: 0, cur, qw, acc, fill, w: @as(i64, outb[@as(usize, @intCast(b))]), rem, root): r -> r

// htl — tail walk: the final partial byte's `rem` bits, bit-by-bit from
// cur, emitting into the same acc word; flush at end.
pub tor htl { s: i64, cur: i64, qw: i64, acc: i64, fill: i64, w: i64, rem: i64, root: i64 } -> i64
htl = if(s < rem)
| then |> idv(v: (w >> @as(u6, @intCast(7 - s))) & 1): bit
    |> idv(v: if(bit == 1) hnr[@as(usize, @intCast(cur))] else hnl[@as(usize, @intCast(cur))]): nc
    |> if(hnlf[@as(usize, @intCast(nc))] == 1)
        | then |> if(hnbv[@as(usize, @intCast(nc))] != 0)
            | then |> idv(v: acc | (hnbv[@as(usize, @intCast(nc))] << @as(u6, @intCast(fill * 8)))): a2
                |> idv(v: fill + 1): f2
                |> if(f2 == 8)
                    | then |> std/grid:stored { decw[@as(usize, @intCast(qw))]: a2 }
                        |> htl(s: s + 1, cur: root, qw: qw + 1, acc: 0, fill: 0, w, rem, root): r -> r
                    | else |> htl(s: s + 1, cur: root, qw, acc: a2, fill: f2, w, rem, root): r -> r
            | else |> htl(s: s + 1, cur: root, qw, acc, fill, w, rem, root): r -> r
        | else |> htl(s: s + 1, cur: nc, qw, acc, fill, w, rem, root): r -> r
| else |> if(fill > 0)
    | then |> std/grid:stored { decw[@as(usize, @intCast(qw))]: acc }
        |> idv(v: qw * 8 + fill): r -> r
    | else -> qw * 8 + fill

// ---- 16-bit decode: one step consumes TWO stream bytes ----
// cr = current node RANK (node - leaf count); the chain cr -> lu2[cr,w2].cx -> cr.
// acc/f8 = pending emitted bits (f8 in 0..56, multiple of 8). Per step the
// 128-bit (p1:p0) pack shifts in at f8; decw[qw] gets the completed word and
// decw[qw+1] the next partial unconditionally (it is overwritten until qw
// advances — the last write to any word before qw passes it is its full
// content; words past the final cursor are never read).
pub tor hdec16 { b: i64, cr: i64, qw: i64, acc: i64, f8: i64, e2: i64, rem: i64, root: i64, ln: i64 } -> i64
hdec16 = if(b < e2)
| then |> idv(v: @as(i64, outb[@as(usize, @intCast(b))]) * 256 + @as(i64, outb[@as(usize, @intCast(b + 1))])): w2
    |> idv(v: cr * 65536 + w2): ix
    |> idv(v: lu2p0[@as(usize, @intCast(ix))]): p0
    |> idv(v: lu2p1[@as(usize, @intCast(ix))]): p1
    |> idv(v: lu2cx[@as(usize, @intCast(ix))]): cnx
    |> idv(v: acc | (p0 << @as(u6, @intCast(f8)))): w0
    |> idv(v: f8 + (cnx & 31) * 8): nb8
    |> idv(v: (@as(i64, 1) << @as(u6, @intCast(nb8 & 63))) - 1): msk
    |> idv(v: (p0 >> @as(u6, @intCast((64 - f8) & 63))) & ((@as(i64, 1) << @as(u6, @intCast(f8))) - 1)): sp0
    |> idv(v: sp0 | (p1 << @as(u6, @intCast(f8)))): an0
    |> idv(v: (p1 >> @as(u6, @intCast((64 - f8) & 63))) & msk): an1
    |> std/grid:stored { decw[@as(usize, @intCast(qw))]: w0 }
    |> std/grid:stored { decw[@as(usize, @intCast(qw + 1))]: an0 }
    |> hdec16(b: b + 2, cr: cnx >> 5,
        qw: qw + (nb8 >> 6),
        acc: if(nb8 < 64) w0 else (if(nb8 < 128) an0 else an1),
        f8: nb8 & 63, e2, rem, root, ln): r -> r
| else |> htl16(s: 0, cur: cr + ln, qw, acc, fill: f8 >> 3,
    w: @as(i64, outb[@as(usize, @intCast(b))]) * 256 + @as(i64, outb[@as(usize, @intCast(b + 1))]),
    rem, root): r -> r

// htl16 — tail walk over the last rem = bc & 15 bits (a 16-bit window's
// high bits), bit-by-bit from node cur, emitting into acc; flush at end.
pub tor htl16 { s: i64, cur: i64, qw: i64, acc: i64, fill: i64, w: i64, rem: i64, root: i64 } -> i64
htl16 = if(s < rem)
| then |> idv(v: (w >> @as(u6, @intCast(15 - s))) & 1): bit
    |> idv(v: if(bit == 1) hnr[@as(usize, @intCast(cur))] else hnl[@as(usize, @intCast(cur))]): nc
    |> if(hnlf[@as(usize, @intCast(nc))] == 1)
        | then |> if(hnbv[@as(usize, @intCast(nc))] != 0)
            | then |> idv(v: acc | (hnbv[@as(usize, @intCast(nc))] << @as(u6, @intCast(fill * 8)))): a2
                |> idv(v: fill + 1): f2
                |> if(f2 == 8)
                    | then |> std/grid:stored { decw[@as(usize, @intCast(qw))]: a2 }
                        |> htl16(s: s + 1, cur: root, qw: qw + 1, acc: 0, fill: 0, w, rem, root): r -> r
                    | else |> htl16(s: s + 1, cur: root, qw, acc: a2, fill: f2, w, rem, root): r -> r
            | else |> htl16(s: s + 1, cur: root, qw, acc, fill, w, rem, root): r -> r
        | else |> htl16(s: s + 1, cur: nc, qw, acc, fill, w, rem, root): r -> r
| else |> if(fill > 0)
    | then |> std/grid:stored { decw[@as(usize, @intCast(qw))]: acc }
        |> idv(v: qw * 8 + fill): r -> r
    | else -> qw * 8 + fill

// run1 — one runImpl: decode, add length
pub tor run1 { } -> i64
run1 = if(st.u16 == 1)
| then |> hdec16(b: 0, cr: hl[0].v - st.ln2, qw: 0, acc: 0, f8: 0, e2: st.f6 * 2, rem: st.bc - st.f6 * 16, root: hl[0].v, ln: st.ln2): dsf
    |> std/store:stored { st.ds: dsf }
    |> std/store:stored { st.res: st.res + dsf }
    |> ret0(): r -> r
| else |> hdec(b: 0, cur: hl[0].v, qw: 0, acc: 0, fill: 0, st.fb, rem: st.bc - st.fb * 8, root: hl[0].v): dsf
    |> std/store:stored { st.ds: dsf }
    |> std/store:stored { st.res: st.res + dsf }
    |> ret0(): r -> r

// runl — 420 runs
pub tor runl { k: i64 } -> i64
runl = run1(): _
    |> if(k < 419)
        | then |> runl(k: k + 1): r -> r
        | else |> ret0(): r -> r

// vfy — checksum's std.mem.eql(test_data, decoded): byte-compare,
// gated on equal lengths by the caller
pub tor vfy { i: i64 } -> i64
vfy = if(i < st.n)
| then |> if(dat[i].b == @as(u8, @intCast((decw[@as(usize, @intCast(i >> 3))] >> @as(u6, @intCast((i & 7) * 8))) & 255)))
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
