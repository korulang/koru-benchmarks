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
//
// Perf notes (PERF.md recipes; extends the compress_arith_decode win):
// - pat/dat/out are u8 cells (recipe 12); hot columns are borrowed
//   slices (datb/outb/ftlo/fthi — verbatim reads, recipes 2/13).
// - The encoder is ONE param-carried self-loop `ael` (recipe 6) —
//   i/lo/hi/pd/acc/nb/p/tot/m in registers, no store rows, no per-bit
//   sub-calls. The dispatch chain IS the reference's renorm test, in
//   the reference's precedence: E1/E2 unified (lo,hi top bits equal),
//   then E3 (lo>=2^30 & hi<3*2^30 — lo<2^31<=hi is implied by falling
//   past the first test), else rescale/final. No separate "any-renorm?"
//   gate and no nb>=8 head check — byte flushing lives in the mutual
//   tail-loop `afl`, entered only after an emit.
// - DISCLOSED representation tricks (recipe 7, exact on every input):
//   (a) A renorm emit is a RUN of 1+pd bits — bit b then pd copies of
//       !b — appended to the bit accumulator arithmetically in one op
//       instead of the reference's per-bit write_bit loop.
//   (b) Consecutive E1/E2 steps are batched via one test: both shift
//       (lo,hi) left while the interval sits entirely in one half,
//       which holds iff lo and hi agree on their top bit — so the
//       maximal same-case run is exactly k = clz(lo^hi) - 32. The run
//       emits b + pd copies of !b + (k-1) copies of b = s = k+pd bits,
//       appended in closed form:
//         rv = (1<<(s-1)) + b*hm - t,  hm = (1<<k)-1,  t = 1<<(k-1)
//       (b=1 gives 1<<(s-1) + (1<<(k-1))-1; b=0 gives ((1<<pd)-1)<<(k-1)
//       = (1<<(s-1)) - (1<<(k-1))). With the leading bit folded in,
//       acc' = ((2*acc+1)<<(s-1)) + b*hm - t. hi' gets low k bits = hm
//       (the reference's |1 per step); lo' needs & 0xFFFFFFFF because
//       b=1 shifts can reach bit 32. Identical bit sequence, identical
//       pending accounting, precedence preserved — the batch ends on
//       the first step where the reference would take a different
//       branch (top-bit disagreement covers E1/E2 exhaustively).
//   (c) Overflow bound: consecutive E3s double the interval while
//       requiring length <= 2^30, so pd <= 30; k <= 31; nb < 8.
//       A batch append of s=k+pd bits is taken only while nb+s <= 62
//       (guards i64/u6 shift); larger falls back to the equivalent
//       single-step emit (1+pd <= 31 bits) and re-batches next step.
//   (d) The two truncating divisions (rng*ftlo/tot, rng*fthi/tot) are
//       computed by exact Granlund-Montgomery round-up magic:
//       q = (x*m) >> 66 with m = floor(2^66/tot)+1, computed once per
//       run in i128 (m < 2^50 for tot <= 100004; x = rng*freq < 2^49).
//       Exactness: x*m/2^66 = x/tot + x*r/(tot*2^66) with r < tot, so
//       the added fraction is < x/2^66 < 2^-17 < 1/tot for all
//       reachable x < 2^49 — hence the floor can never cross the
//       quotient boundary (verified over the reachable domain). Emits as
//       smulh+shift (~2 instrs) replacing sdiv (~12+ cycles).
//   Bits leave acc FIFO via afl's acc>>(nb-8); the tail is
//   left-aligned exactly like BitOutputStream.flush. Byte stores to
//   out[] are real (LLVM legally elides the dead ones — res only sums
//   p — identical to the baseline where the same stores died).
// - Falsified hypotheses: (a) source-level inlining of wb into the
//   encode loop gained nothing — LLVM already inlined/promoted the
//   baseline store rows (v1 ~1.19s vs ~1.08s base). (b) separate
//   clz32(hi)/clz32(~lo) E1/E2 batching was neutral without the
//   unified dispatch (v2 ~1.08s); the win came with clz(lo^hi)
//   unification (v3 ~0.98s). (c) @rem(x,2^32) in the hot path lowered
//   to an abs/sign sequence — plain xor/and masks on in-range values
//   removed it (v4 ~0.90s). (d) E3 run batching has a verified closed
//   form — j = min(clz64(2^31-lo-1), clz64(hi-2^31)) - 33 — but ~75%
//   of E3 runs have length 1, so ~12 batch instrs lose to ~9 step
//   instrs; parked.

import std/io
import std/grid
import std/store

std/grid:new(pat, size: 11) { b: 0[u8] }
std/grid:new(dat, size: 100004) { b: 0[u8] }
std/grid:new(frq, size: 256) { v: 0[i64] }
std/grid:new(ft, size: 256) { lo: 0[i64], hi: 0[i64] }
std/grid:new(out, size: 40000) { b: 0[u8] }
std/grid:slice(patb) { pat.b }
std/grid:slice(datb) { dat.b }
std/grid:slice(outb) { out.b }
std/grid:slice(ftlo) { ft.lo }
std/grid:slice(fthi) { ft.hi }
std/store:new(st) { res: 0[i64], n: 100004[i64], cum: 0[i64], tot: 0[i64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

pub tor idv { v: i64 } -> i64
idv -> v

pub tor idv8 { v: u8 } -> u8
idv8 -> v

// genl — test_data[i] = "ABRACADABRA"[i % 11]
pub tor genl { i: i64 } -> i64
genl = std/grid:stored { dat[i].b: patb[@as(usize, @intCast(@rem(i, 11)))] }
    |> if(i < st.n - 1)
        | then |> genl(i: i + 1): r -> r
        | else |> ret0(): r -> r

pub tor zfr { i: i64 } -> i64
zfr = std/grid:stored { frq[i].v: 0 }
    |> if(i < 255)
        | then |> zfr(i: i + 1): r -> r
        | else |> ret0(): r -> r

pub tor cntb { i: i64 } -> i64
cntb = std/grid:stored { frq[@as(usize, @intCast(datb[@as(usize, @intCast(i))]))].v: frq[@as(usize, @intCast(datb[@as(usize, @intCast(i))]))].v + 1 }
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

// ael — fused encode self-loop; all hot state in params. The if-chain
// is the renorm test itself (reference precedence): emit-run batch
// (lo/hi top bits equal), lean E3 step, symbol rescale, final -> adn.
pub tor ael { i: i64, lo: i64, hi: i64, pd: i64, acc: i64, nb: i64, p: i64, tot: i64, m: i64 } -> i64
ael = if(lo ^ hi < 2147483648)
| then |> idv(v: @as(i64, lo) >> @as(u6, 31)): b
    |> idv(v: @as(i64, @intCast(@clz(lo ^ hi))) - 32): k
    |> idv(v: k + pd): s
    |> if(s + nb <= 62)
        | then |> idv(v: (@as(i64, 1) << @as(u6, @intCast(k))) - 1): hm
            |> idv(v: @as(i64, 1) << @as(u6, @intCast(k - 1))): t
            |> afl(i,
                lo: (@as(i64, lo) << @as(u6, @intCast(k))) & 4294967295,
                hi: ((@as(i64, hi) << @as(u6, @intCast(k))) & 4294967295) + hm,
                pd: 0,
                acc: ((acc + acc + 1) << @as(u6, @intCast(s - 1))) + b * hm - t,
                nb: nb + s,
                p, tot, m): r -> r
        | else |> idv(v: (@as(i64, 1) << @as(u6, @intCast(pd))) - 1 + b): rv
            |> afl(i,
                lo: (lo * 2) & 4294967295,
                hi: ((hi * 2) & 4294967295) + 1,
                pd: 0,
                acc: (@as(i64, acc) << @as(u6, @intCast(pd + 1))) + rv,
                nb: nb + pd + 1,
                p, tot, m): r -> r
| else |> if(lo >= 1073741824 and hi < 3221225472)
    | then |> ael(i,
        lo: (lo - 1073741824) * 2,
        hi: (hi - 1073741824) * 2 + 1,
        pd: pd + 1,
        acc, nb, p, tot, m): r -> r
    | else |> if(i < tot)
        | then |> idv8(v: datb[@as(usize, @intCast(i))]): sym
            |> idv(v: hi - lo + 1): rng
            |> idv(v: rng * ftlo[@as(usize, @intCast(@as(i64, sym)))]): xa
            |> idv(v: rng * fthi[@as(usize, @intCast(@as(i64, sym)))]): xb
            |> idv(v: @as(i64, @intCast((@as(i128, xa) * @as(i128, m)) >> @as(u7, 66)))): q1
            |> idv(v: @as(i64, @intCast((@as(i128, xb) * @as(i128, m)) >> @as(u7, 66)))): q2
            |> ael(i: i + 1,
                lo: lo + q1,
                hi: lo + q2 - 1,
                pd, acc, nb, p, tot, m): r -> r
        | else |> idv(v: pd + 1): fpd
            |> idv(v: if(lo < 1073741824) @as(i64, 0) else 1): fb
            |> adn(acc: (@as(i64, acc) << @as(u6, @intCast(fpd + 1))) + ((@as(i64, 1) << @as(u6, @intCast(fpd))) - 1 + fb),
                nb: nb + fpd + 1, p): r -> r

// afl — byte flush: entered only after an emit appended bits (nb>0
// possible, nb<8 invariant restored before tailing back into ael)
pub tor afl { i: i64, lo: i64, hi: i64, pd: i64, acc: i64, nb: i64, p: i64, tot: i64, m: i64 } -> i64
afl = if(nb >= 8)
| then |> idv(v: @as(i64, acc) >> @as(u6, @intCast(nb - 8))): by
    |> std/grid:stored { outb[@as(usize, @intCast(p))]: @as(u8, @intCast(by)) }
    |> afl(i, lo, hi, pd, acc: acc - (by * (@as(i64, 1) << @as(u6, @intCast(nb - 8)))), nb: nb - 8, p: p + 1, tot, m): r -> r
| else |> ael(i, lo, hi, pd, acc, nb, p, tot, m): r -> r

// adn — end-of-run drain: flush full bytes, then the LEFT-ALIGNED
// partial byte, then accumulate res += encoded.len (p)
pub tor adn { acc: i64, nb: i64, p: i64 } -> i64
adn = if(nb >= 8)
| then |> idv(v: @as(i64, acc) >> @as(u6, @intCast(nb - 8))): by
    |> std/grid:stored { outb[@as(usize, @intCast(p))]: @as(u8, @intCast(by)) }
    |> adn(acc: acc - (by * (@as(i64, 1) << @as(u6, @intCast(nb - 8)))), nb: nb - 8, p: p + 1): r -> r
| else |> if(nb > 0)
    | then |> std/grid:stored { outb[@as(usize, @intCast(p))]: @as(u8, @intCast(@as(i64, acc) << @as(u6, @intCast(8 - nb)))) }
        |> std/store:stored { st.res: st.res + p + 1 }
        |> ret0(): r -> r
    | else |> std/store:stored { st.res: st.res + p }
        |> ret0(): r -> r

// run1 — one runImpl: freqs -> table -> encode -> res (tot == n here:
// the frequency sum is the data length, and the reference loops over
// the same 100004 bytes it divides by)
pub tor run1 { } -> i64
run1 = zfr(i: 0): _
    |> cntb(i: 0): _
    |> std/store:stored { st.cum: 0 }
    |> cft(i: 0): _
    |> std/store:stored { st.tot: st.cum }
    |> idv(v: @as(i64, @intCast(@divTrunc(@as(i128, 73786976294838206464), @as(i128, st.tot)) + 1))): m
    |> ael(i: 0, lo: 0, hi: 4294967295, pd: 0, acc: 0, nb: 0, p: 0, tot: st.cum, m): r -> r

// runl — 600 runs
pub tor runl { k: i64 } -> i64
runl = run1(): _
    |> if(k < 599)
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
