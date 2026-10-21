// compress_arith_decode — LangArena Compress::ArithDecode, run.js
// scored parameters (size=100005, iterations=350, warmup=70 → 420
// runs). prepare runs the ArithEncode pipeline once (freq table +
// 32-bit range coder). Each run rebuilds the cumulative table,
// primes `value` with 32 MSB-first bits (readBit past EOF returns
// 0), then per symbol: scaled = ((value-low+1)*total-1)/range,
// binary-search the first high_table entry > scaled, emit, rescale,
// and renormalize (subtract on E2/E3, shift + readBit always).
// result_val += decoded.len; +100000 on byte-exact roundtrip —
// oracle 42102100 = 420 × 100005 + 100000.

import std/io
import std/grid
import std/store

std/grid:new(pat, size: 11) { b: 0[i64] }
std/grid:new(dat, size: 100005) { b: 0[i64] }
std/grid:new(frq, size: 256) { v: 0[i64] }
std/grid:new(ft, size: 256) { lo: 0[i64], hi: 0[i64] }
std/grid:new(out, size: 40000) { b: 0[i64] }
std/grid:new(dec, size: 100005) { b: 0[i64] }
std/store:new(st) { res: 0[i64], n: 100005[i64], p: 0[i64], buf: 0[i64], bp: 0[i64], bits: 0[i64], lo: 0[i64], hi: 0[i64], pd: 0[i64], rng: 0[i64], t1: 0[i64], t2: 0[i64], t3: 0[i64], tot: 0[i64], cum: 0[i64], el: 0[i64], bpos: 0[i64], ip: 0[i64], curb: 0[i64], val: 0[i64], sc: 0[i64], sym: 0[i64], ok: 0[i64] }

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

// cft — cumulative table: ft[i].lo = cum, ft[i].hi = cum + f[i]
pub tor cft { i: i64 } -> i64
cft = std/grid:stored { ft[i].lo: st.cum }
    |> std/store:stored { st.cum: st.cum + frq[i].v }
    |> std/grid:stored { ft[i].hi: st.cum }
    |> if(i < 255)
        | then |> cft(i: i + 1): r -> r
        | else |> ret0(): r -> r

// ---- encoder half (prepare-time, mirrors ArithEncode exactly) ----
pub tor wb { b: i64 } -> i64
wb = std/store:stored { st.buf: st.buf * 2 + b }
    |> std/store:stored { st.bp: st.bp + 1 }
    |> std/store:stored { st.bits: st.bits + 1 }
    |> if(st.bp == 8)
        | then |> std/grid:stored { out[st.p].b: @rem(st.buf, 256) }
            |> std/store:stored { st.p: st.p + 1 }
            |> std/store:stored { st.buf: 0 }
            |> std/store:stored { st.bp: 0 }
            |> ret0(): r -> r
        | else |> ret0(): r -> r

pub tor wpd { b: i64 } -> i64
wpd = if(st.pd > 0)
| then |> wb(b): _
    |> std/store:stored { st.pd: st.pd - 1 }
    |> wpd(b): r -> r
| else -> 0

pub tor arsh { } -> i64
arsh = std/store:stored { st.lo: st.lo * 2 }
    |> std/store:stored { st.hi: @rem(st.hi * 2 + 1, 4294967296) }
    |> ret0(): _ -> 0

pub tor arn { } -> i64
arn = if(st.hi < 2147483648)
| then |> wb(b: 0): _
    |> wpd(b: 1): _
    |> arsh(): _
    |> arn(): r -> r
| else |> if(st.lo >= 2147483648)
    | then |> wb(b: 1): _
        |> wpd(b: 0): _
        |> std/store:stored { st.lo: st.lo - 2147483648 }
        |> std/store:stored { st.hi: st.hi - 2147483648 }
        |> arsh(): _
        |> arn(): r -> r
    | else |> if(st.lo >= 1073741824)
        | then |> if(st.hi < 3221225472)
            | then |> std/store:stored { st.pd: st.pd + 1 }
                |> std/store:stored { st.lo: st.lo - 1073741824 }
                |> std/store:stored { st.hi: st.hi - 1073741824 }
                |> arsh(): _
                |> arn(): r -> r
            | else |> ret0(): r -> r
        | else |> ret0(): r -> r

pub tor aenc { i: i64 } -> i64
aenc = if(i < st.n)
| then |> std/store:stored { st.t1: dat[i].b }
    |> std/store:stored { st.rng: st.hi - st.lo + 1 }
    |> std/store:stored { st.hi: st.lo + @divTrunc(st.rng * ft[st.t1].hi, st.tot) - 1 }
    |> std/store:stored { st.lo: st.lo + @divTrunc(st.rng * ft[st.t1].lo, st.tot) }
    |> arn(): _
    |> aenc(i: i + 1): r -> r
| else -> 0

pub tor afin { } -> i64
afin = std/store:stored { st.pd: st.pd + 1 }
    |> if(st.lo < 1073741824)
        | then |> wb(b: 0): _
            |> wpd(b: 1): r -> r
        | else |> wb(b: 1): _
            |> wpd(b: 0): r -> r

// afl2 — LEFT-aligned flush; records st.el instead of touching res
pub tor afl2 { } -> i64
afl2 = if(st.bp > 0)
| then |> std/store:stored { st.buf: @rem(st.buf * @as(i64, 1) << @as(u6, @intCast(8 - st.bp)), 256) }
    |> std/grid:stored { out[st.p].b: st.buf }
    |> std/store:stored { st.el: st.p + 1 }
    |> ret0(): r -> r
| else |> std/store:stored { st.el: st.p }
    |> ret0(): r -> r

// enc1 — the one prepare-time encode
pub tor enc1 { } -> i64
enc1 = zfr(i: 0): _
    |> cntb(i: 0): _
    |> std/store:stored { st.cum: 0 }
    |> cft(i: 0): _
    |> std/store:stored { st.tot: st.cum }
    |> std/store:stored { st.lo: 0 }
    |> std/store:stored { st.hi: 4294967295 }
    |> std/store:stored { st.pd: 0 }
    |> std/store:stored { st.p: 0 }
    |> std/store:stored { st.buf: 0 }
    |> std/store:stored { st.bp: 0 }
    |> std/store:stored { st.bits: 0 }
    |> aenc(i: 0): _
    |> afin(): _
    |> afl2(): r -> r

// ---- decoder half ----
// rbit — BitInputStream.readBit: MSB-first; past EOF current_byte=0.
// Produces the bit.
pub tor rbit { } -> i64
rbit = if(st.ip == 8)
| then |> std/store:stored { st.bpos: st.bpos + 1 }
    |> std/store:stored { st.ip: 0 }
    |> if(st.bpos < st.el)
        | then |> std/store:stored { st.curb: out[st.bpos].b }
            |> rbit(): r -> r
        | else |> std/store:stored { st.curb: 0 }
            |> rbit(): r -> r
| else |> std/store:stored { st.t3: @rem(@divFloor(st.curb, @as(i64, 1) << @as(u6, @intCast(7 - st.ip))), 2) }
    |> std/store:stored { st.ip: st.ip + 1 }
    |> ret0(): _ -> st.t3

// vin — value = 32 leading bits
pub tor vin { i: i64 } -> i64
vin = if(i < 32)
| then |> rbit(): rb
    |> std/store:stored { st.val: st.val * 2 + rb }
    |> vin(i: i + 1): r -> r
| else -> 0

// bs — binary search: first index with ft.hi > st.sc
pub tor bs { l: i64, r2: i64 } -> i64
bs = if(l < r2)
| then |> std/store:stored { st.t3: @divTrunc(l + r2, 2) }
    |> if(ft[st.t3].hi <= st.sc)
        | then |> bs(l: st.t3 + 1, r2): r -> r
        | else |> bs(l, r2: st.t3): r -> r
| else -> l

// ard — decoder renorm: no pending drain; shift + readBit per iter
pub tor ard { } -> i64
ard = if(st.hi < 2147483648)
| then |> std/store:stored { st.lo: st.lo * 2 }
    |> std/store:stored { st.hi: @rem(st.hi * 2 + 1, 4294967296) }
    |> rbit(): rb
    |> std/store:stored { st.val: st.val * 2 + rb }
    |> ard(): r -> r
| else |> if(st.lo >= 2147483648)
    | then |> std/store:stored { st.val: st.val - 2147483648 }
        |> std/store:stored { st.lo: st.lo - 2147483648 }
        |> std/store:stored { st.hi: st.hi - 2147483648 }
        |> std/store:stored { st.lo: st.lo * 2 }
        |> std/store:stored { st.hi: @rem(st.hi * 2 + 1, 4294967296) }
        |> rbit(): rb
        |> std/store:stored { st.val: st.val * 2 + rb }
        |> ard(): r -> r
    | else |> if(st.lo >= 1073741824)
        | then |> if(st.hi < 3221225472)
            | then |> std/store:stored { st.val: st.val - 1073741824 }
                |> std/store:stored { st.lo: st.lo - 1073741824 }
                |> std/store:stored { st.hi: st.hi - 1073741824 }
                |> std/store:stored { st.lo: st.lo * 2 }
                |> std/store:stored { st.hi: @rem(st.hi * 2 + 1, 4294967296) }
                |> rbit(): rb
                |> std/store:stored { st.val: st.val * 2 + rb }
                |> ard(): r -> r
            | else |> ret0(): r -> r
        | else |> ret0(): r -> r

// adec — per symbol: scaled -> binary search -> emit -> rescale -> ard
pub tor adec { j: i64 } -> i64
adec = if(j < st.tot)
| then |> std/store:stored { st.rng: st.hi - st.lo + 1 }
    |> std/store:stored { st.sc: @divTrunc((st.val - st.lo + 1) * st.tot - 1, st.rng) }
    |> bs(l: 0, r2: 256): sym
    |> std/grid:stored { dec[j].b: sym }
    |> std/store:stored { st.hi: st.lo + @divTrunc(st.rng * ft[sym].hi, st.tot) - 1 }
    |> std/store:stored { st.lo: st.lo + @divTrunc(st.rng * ft[sym].lo, st.tot) }
    |> ard(): _
    |> adec(j: j + 1): r -> r
| else -> 0

// run1 — one runImpl: fresh table, value prime, decode n symbols
pub tor run1 { } -> i64
run1 = std/store:stored { st.cum: 0 }
    |> cft(i: 0): _
    |> std/store:stored { st.bpos: 0 }
    |> std/store:stored { st.ip: 0 }
    |> std/store:stored { st.curb: out[0].b }
    |> std/store:stored { st.val: 0 }
    |> vin(i: 0): _
    |> std/store:stored { st.lo: 0 }
    |> std/store:stored { st.hi: 4294967295 }
    |> adec(j: 0): _
    |> std/store:stored { st.res: st.res + st.tot }
    |> ret0(): _ -> 0

// runl — 420 runs
pub tor runl { k: i64 } -> i64
runl = run1(): _
    |> if(k < 419)
        | then |> runl(k: k + 1): r -> r
        | else |> ret0(): r -> r

// vfy — checksum's mem.eql(test_data, decoded); dec len is always n
pub tor vfy { i: i64 } -> i64
vfy = if(i < st.n)
| then |> if(dat[i].b == dec[i].b)
    | then |> vfy(i: i + 1): r -> r
    | else |> ret0(): r -> r
| else |> std/store:stored { st.ok: 1 }
    |> ret0(): r -> r

pub tor fin { } -> i64
fin = vfy(i: 0): _
    |> if(st.ok == 1)
        | then |> std/store:stored { st.res: st.res + 100000 }
            |> ret0(): r -> r
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
|> enc1(): _
|> runl(k: 0): _
|> fin(): _
|> std/io:print.ln("{{ st.res:d }}")
