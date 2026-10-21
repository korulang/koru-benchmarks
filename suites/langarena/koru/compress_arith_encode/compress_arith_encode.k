// compress_arith_encode — LangArena Compress::ArithEncode, run.js
// scored parameters (size=100004, iterations=500, warmup=100 → 600
// runs). Per run: byte frequencies -> cumulative [low,high) table,
// then a 32-bit range coder per byte: high/low rescaled by
// range*freq/total (trunc), then renormalize: emit 0+pending*1 when
// high < 0x80000000; emit 1+pending*0 and subtract when low >=
// 0x80000000; count pending when straddling [0x40000000,0xC0000000);
// then shift out. Final pending+1 bit-flush, then LEFT-ALIGNED
// partial byte (unlike Huffman's as-is append). result_val +=
// encoded.len — oracle 15303600 = 600 × 25506.

import std/io
import std/grid
import std/store

std/grid:new(pat, size: 11) { b: 0[i64] }
std/grid:new(dat, size: 100004) { b: 0[i64] }
std/grid:new(frq, size: 256) { v: 0[i64] }
std/grid:new(ft, size: 256) { lo: 0[i64], hi: 0[i64] }
std/grid:new(out, size: 40000) { b: 0[i64] }
std/store:new(st) { res: 0[i64], n: 100004[i64], p: 0[i64], buf: 0[i64], bp: 0[i64], bits: 0[i64], lo: 0[i64], hi: 0[i64], pd: 0[i64], rng: 0[i64], t1: 0[i64], t2: 0[i64], tot: 0[i64], cum: 0[i64] }

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

// wb — writeBit: buffer<<=1 | bit; at 8 bits append & 0xFF
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

// wpd — emit st.pd copies of bit b, draining pending to 0
pub tor wpd { b: i64 } -> i64
wpd = if(st.pd > 0)
| then |> wb(b): _
    |> std/store:stored { st.pd: st.pd - 1 }
    |> wpd(b): r -> r
| else -> 0

// arsh — low <<= 1; high = ((high<<1)|1) & 0xFFFFFFFF
pub tor arsh { } -> i64
arsh = std/store:stored { st.lo: st.lo * 2 }
    |> std/store:stored { st.hi: @rem(st.hi * 2 + 1, 4294967296) }
    |> ret0(): _ -> 0

// arn — the renormalization loop; every continue-arm shifts and
// self-calls, the else-arm breaks
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

// aenc — per byte: rescale, then arn
pub tor aenc { i: i64 } -> i64
aenc = if(i < st.n)
| then |> std/store:stored { st.t1: dat[i].b }
    |> std/store:stored { st.rng: st.hi - st.lo + 1 }
    |> std/store:stored { st.hi: st.lo + @divTrunc(st.rng * ft[st.t1].hi, st.tot) - 1 }
    |> std/store:stored { st.lo: st.lo + @divTrunc(st.rng * ft[st.t1].lo, st.tot) }
    |> arn(): _
    |> aenc(i: i + 1): r -> r
| else -> 0

// afin — pending+1, final bit + drain, flush LEFT-ALIGNED partial
pub tor afin { } -> i64
afin = std/store:stored { st.pd: st.pd + 1 }
    |> if(st.lo < 1073741824)
        | then |> wb(b: 0): _
            |> wpd(b: 1): r -> r
        | else |> wb(b: 1): _
            |> wpd(b: 0): r -> r

pub tor afl { } -> i64
afl = if(st.bp > 0)
| then |> std/store:stored { st.buf: @rem(st.buf * @as(i64, 1) << @as(u6, @intCast(8 - st.bp)), 256) }
    |> std/grid:stored { out[st.p].b: st.buf }
    |> std/store:stored { st.res: st.res + st.p + 1 }
    |> ret0(): r -> r
| else |> std/store:stored { st.res: st.res + st.p }
    |> ret0(): r -> r

// run1 — one runImpl: freqs -> table -> encode -> flush -> res
pub tor run1 { } -> i64
run1 = zfr(i: 0): _
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
    |> afl(): r -> r

// runl — 600 runs
pub tor runl { k: i64 } -> i64
runl = run1(): _
    |> if(k < 599)
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
