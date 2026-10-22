// clbg_fannkuchredux — LangArena CLBG::Fannkuchredux, run.js scored
// parameters (n=8, iterations=700, warmup = iters*0.2 = 140 → 840
// runs; result_val += checksum*100 + max_flips per run, u32 wrap —
// oracle 135762480; per-run contribution is 1616*100 + 22 = 161622).
//
// The reference is the classic CLBG fannkuch on perm1/perm/count[8]:
// an outer permutation-advance machine with a pancake-flip inner loop.
//
// WAVE-5 OPTIMIZATION (faithfulness diffs vs the original port):
//  1. REPRESENTATION: the 8-element permutation AND the 8-element
//     count array are each packed into ONE i64 cell — byte i of
//     perm1 is perm1[i], byte r of cnt is count[r] (byte 0 of cnt
//     is spare, stays 0). The reference's second array `perm` is
//     gone entirely: the flip works on a register copy carried in
//     tor params — only the flip COUNT and next perm1 state are
//     observable. LLVM promotes both cells to registers inside the
//     hot loop (disasm: x4 = perm1, x11 = cnt; the cell write is a
//     store with no reload on the loop path). Semantics verified
//     identical: per-run
//     flips=180260, advances=69280, checksum=1616, max_flips=22
//     (C oracles /tmp/fkr_u64.c, /tmp/fkr_count.c).
//  2. THE FLIP: reversing bytes 0..k of the packed word is
//     `pv = (pv & ~m) + (byteSwap(pv) >> s)` where s = 8*(7-k) and
//     m = (u64)-1 >> s — one rev, two variable shifts, one bic —
//     replacing the ~(k+1)/2-iteration swap loop (391525 swap
//     iterations per run, the dominant cost). The (u64)-1 >> s
//     trick makes the k=7 edge exact with no LUT and no load on
//     the critical path (emits lsr/bic/rev/asr — 8 ALU per flip).
//  3. THE ADVANCE ROTATION (perm1 <- [perm1[1..=r], perm1[0]]):
//     `((v>>8)&lt) + (p0<<8r) + (v&~m2)` — r in 1..3 specialized
//     with constant masks (~97% of advance iterations: r=1 40320,
//     r=2 20160, r=3 6720, r>=4 2080 — /tmp/fkr_hist.c); LLVM
//     compiles them to rev/lsr/and/orr and and/bfi/bfxil.
//  4. THE COUNT RESET (count[i] = i+1 for i in 1..r-1): a single
//     masked merge `cc = (cc & ~m3) + (ID & m3)` with
//     m3 = ((u64)-1 >> 8*(8-r)) & ~0xff and ID = 0x0807060504030200.
//     At r=8 the shift is 0 (full mask); at r=1 m3=0 (no-op), so
//     only the `if(r>1)` skip remains. No reset loop at all.
//     count[r] decrement is `cc - (1 << 8r)` — never borrows since
//     the algorithm only decrements a live count (cnt[r] >= 1).
//  5. Scalar state (r, pc, cs, mf, fc, pv) carried in tor params —
//     self-calls emit `continue :__koru_self_loop`, everything
//     register-resident (PERF.md recipe 6). The store is gone; acc
//     is a runl param; the u32 wrap is `(acc + c) & 0xffffffff`
//     (two's-complement mask — exact for negative c too).
//  6. Bit ops (`<<`,`>>`,`&`,`+%`,`^`,`@bitCast`,`@byteSwap`)
//     splice as Zig — the same builtins the base64/hash kernels
//     already use. `+%` joins the disjoint byte fields.
//  Semantics preserved: same permutation enumeration, same flip
//     counts, same parity rule, same 840-run u32 accumulation.
//
// Falsified this session (probe timings, checksum always green):
//  - u8 slice cells + param state, same algorithm: 1.09s (no gain —
//    LLVM had already cleaned up the i64/bounds-check original).
//  - swap-spelled rotl to break the memmove idiom: ~1.06s.
//  - straight-line stored-block rotl for r in 1..3 (u8 arrays):
//    ~1.01s — memmove was NOT the deficit; the swap loop was
//    (~392k iterations/run — noflip skeleton runs 0.10s,
//    /tmp/fkr_probe/noflip.k).
//  - keep-mask via an 8-entry i64 LUT (mt grid + slice): 0.55s —
//    the dependent load sat on the flip critical path; the
//    arithmetic (u64)-1>>s mask (~same ALU, no load) won 0.10s.
//  - packed-u64 cnt vs u8[8] cnt: neutral (0.45-0.46 both) —
//    retained since it removes the last per-iteration loads.

import std/io
import std/grid

// perm1: ONE i64 cell — byte i of the word IS perm1[i]
std/grid:new(perm1, size: 1) { v: 0[i64] }
// cnt: ONE i64 cell — byte r of the word IS count[r]
std/grid:new(cnt, size: 1) { v: 0[i64] }
std/grid:slice(p1s) { perm1.v }
std/grid:slice(ccs) { cnt.v }

pub tor idv { v: i64 } -> i64
idv -> v

// frst — count[i] = i+1 for i in 1..r-1 (i.e. count[r-1]=r while
// r>1); produces the resting r. On the packed word this is one
// masked merge: m = bytes 1..r-1 = (U64MAX >> 8*(8-r)) & ~0xff —
// shift-by-0 at r=8 and empty-mask at r=1 are exact for free —
// against ID = 0x0807060504030200 (byte i = i+1).
pub tor frst { r: i64 } -> i64
frst = if(r > 1)
| then |> std/grid:stored { ccs[0]: (ccs[0] & ((@as(i64, @bitCast(@as(u64, 18446744073709551615) >> @as(u6, @intCast((8 - r) * 8)))) & -256) ^ -1)) +% (578437695752307200 & (@as(i64, @bitCast(@as(u64, 18446744073709551615) >> @as(u6, @intCast((8 - r) * 8)))) & -256)) }: _ -> 1
| else -> r

// flip — pancake flips on the packed word until byte 0 is 0.
// One flip reverses bytes 0..k: the low k+1 bytes of byteSwap(pv)
// land at rev>>(8*(7-k)); the keep-above-k mask is
// ~((u64)-1 >> 8*(7-k)) — one shift, no LUT, no k=7 edge.
pub tor flip { pv: i64, fc: i64 } -> i64
flip = if((pv & 255) != 0)
| then |> idv(v: pv & 255): k
    |> flip(pv: (pv & (@as(i64, @bitCast(@as(u64, 18446744073709551615) >> @as(u6, @intCast((7 - k) * 8)))) ^ -1)) +% (@byteSwap(pv) >> @as(u6, @intCast((7 - k) * 8))), fc: fc + 1): x -> x
| else -> fc

// adv — permutation advance; produces the resting r (8 = done).
// The rotation [p1[1..=r], p1[0]] on the packed word is
// ((v>>8)&lt) + (p0<<8r) + (v & ~m) — disjoint fields, +% is OR.
// r in 1..3 (97% of iterations) get constant masks; r >= 4 computes
// ~m = ~((u64)-1 >> 8*(7-r)). The count decrement is a packed byte
// subtract (safe — counts are never decremented at 0).
pub tor adv { r: i64 } -> i64
adv = if(r == 8)
| then -> 8
| else |> if(r == 1)
    | then |> std/grid:stored { p1s[0]: ((p1s[0] >> 8) & 255) +% ((p1s[0] & 255) << 8) +% (p1s[0] & -65536) }
    | else |> if(r == 2)
        | then |> std/grid:stored { p1s[0]: ((p1s[0] >> 8) & 65535) +% ((p1s[0] & 255) << 16) +% (p1s[0] & -16777216) }
        | else |> if(r == 3)
            | then |> std/grid:stored { p1s[0]: ((p1s[0] >> 8) & 16777215) +% ((p1s[0] & 255) << 24) +% (p1s[0] & -4294967296) }
            | else |> std/grid:stored { p1s[0]: ((p1s[0] >> 8) & ((@as(i64, 1) << @as(u6, @intCast(8 * r))) - 1)) +% ((p1s[0] & 255) << @as(u6, @intCast(8 * r))) +% (p1s[0] & (@as(i64, @bitCast(@as(u64, 18446744073709551615) >> @as(u6, @intCast((7 - r) * 8)))) ^ -1)) }
    |> std/grid:stored { ccs[0]: ccs[0] -% (@as(i64, 1) << @as(u6, @intCast(8 * r))) }
    |> if((ccs[0] >> @as(u6, @intCast(8 * r))) & 255 > 0)
        | then -> r
        | else |> adv(r: r + 1): x -> x

// fko — outer machine: reset counts, flip, accumulate, advance.
// pv enters as the packed perm1 word — no copy, the array is dead
// after the count. Produces the run contribution cs*100 + mf.
pub tor fko { r: i64, pc: i64, cs: i64, mf: i64 } -> i64
fko = frst(r): r1
    |> flip(pv: p1s[0], fc: 0): fc
    |> idv(v: if(fc > mf) fc else mf): mf1
    |> idv(v: if(@rem(pc, 2) == 0) cs + fc else cs - fc): cs1
    |> adv(r: r1): r2
    |> if(r2 == 8)
        | then -> cs1 *% 100 +% mf1
        | else |> fko(r: r2, pc: pc + 1, cs: cs1, mf: mf1): x -> x

// onerun — fresh fannkuchredux(8): produces the run contribution
pub tor onerun { } -> i64
onerun = std/grid:stored { p1s[0]: 506097522914230528 }
    |> fko(r: 8, pc: 0, cs: 0, mf: 0): c -> c

// runl — 840 runs (700 measured + 140 warmup), acc wraps at 2^32
pub tor runl { k: i64, acc: i64 } -> i64
runl = if(k < 840)
| then |> onerun(): c
    |> runl(k: k + 1, acc: (acc + c) & 4294967295): x -> x
| else -> acc

// ---- driver ----
runl(k: 0, acc: 0): a
|> std/io:print.ln("{{ a:d }}")
