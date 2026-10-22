// compress_bwt_encode — LangArena Compress::BWTEncode, run.js scored
// parameters (size=100000, iterations=30, warmup=6 → 36 runs; each
// run BWT-transforms the generated "ABRACADABRA"-repeated test data
// and adds transformed.len (= n) to result_val — oracle 3600000).
//
// Reference algorithm carried faithfully: cyclic-shift doubling.
//   1. counting sort of positions by first byte
//   2. rank init from sorted first chars
//   3. while k < n: stable sort sa by (rank[i], rank[(i+k)%n]),
//      re-rank, k *= 2
//   4. transformed[i] = data[sa[i]-1] (or data[n-1] + oidx when sa[i]==0)
// The reference uses driftsort (sort_by on (rank,rank[(i+k)%n]) pairs).
// We use a stable counting radix over the bounded rank keys — better
// big-O (O(n)/round vs O(n log n)) — plus four exact restructurings:
//
//   a) KEY2-SORTED ORDER IS FREE. Sorting suffix indices by
//      key2 = rank[(e+k) mod n] yields exactly (sa[j]-k mod n) for
//      j=0..n-1, because rank[(sa[j]-k)+k] = rank[sa[j]] is
//      non-decreasing in j. The scatter therefore reads the packed
//      source array sequentially and subtracts k inline — the whole
//      second-key sort collapses into the scatter itself, and sak/tsa
//      ping-pong source<->destination roles each round (no shift pass,
//      no copy pass). Within-pair ties are broken by rank-position of
//      e+k rather than prior sa order — a different but valid stable
//      sort for the doubling recurrence; when ranks go unique the sa
//      is THE sorted rotation order, identical to the reference's.
//      (PERF recipe 7 — exact; verified byte-identical against a
//      reference implementation.)
//   b) SA AND PAIR-KEY SHARE ONE i64. Values are packed
//      cell = e | r2<<17 | r1<<34 (e, r1, r2 < 2^17 since n=1e5): e is
//      the suffix index, (r1, r2) its sort key with r1 = rank[e] in
//      the HIGH field so cell>>17 = r2 | r1<<17 orders pair keys
//      lexicographically as a plain integer (r1 major). The rerank
//      rewrites cell = e | newrank<<34 in place — simultaneously the
//      element at position i (next round's source) and its fresh
//      rank (next round's key2 lookup, no second array). NOTE: the
//      earlier e|r1<<17|r2<<34 layout compared keys as (r2, r1) —
//      fine for ==, silently wrong for any order-sensitive select.
//   c) RERANK EMITS CURSORS, NOT COUNTS. dst[i]>>17 is the pair key;
//      with (b)'s field order it is non-decreasing down the sorted
//      positions, so the rank transition is branch-free:
//      cr2 = cr + min(kk - pk, 1). Every element writes
//      cnt[rank+1] = i+1: the last write per rank is its bucket end =
//      next bucket's start, so cnt[r] IS the scatter cursor for rank
//      r next round. No histogram, no prefix pass, no zero pass
//      inside the doubling loop (cnt needs n+1 cells for the rank-n
//      boundary store; only phase 1's 256-byte histogram still
//      counts). Old rnk values are never read during rerank so rnk
//      (element-indexed, for next round's bucket key) is written in
//      place. (An `if(kk==pk)` inside an idv if-expression fails to
//      compile — nested blk label redefinition — and `>` compiles
//      but under the OLD field order compared (r2,r1), which is how
//      the 36842 misresult entered; the arithmetic min form is
//      branch-free and needs no comparison expression at all.)
//   d) DEAD LAST-ROUND WORK SKIPPED. The final round (k*2 >= n)
//      needs no key bits and no rerank — Rust computes and discards
//      them. sktL* scatters plain e; nrn* never runs. The nb<n exit
//      is exact: unique ranks can no longer change sa.
//
// Falsified by analysis (this input): early-exit on rank
// stabilization. Rotations i and i+11 of the period-11 input share
// LCP ~= n-i-11, so max-LCP ~= n forces k >= n/2 before ranks go
// unique — the exit check fires only after the last useful round.
// Wider initial ranks (W-byte init to skip early rounds) rejected:
// each saved round costs ~9 mem-ops/elem but a W=8 radix init costs
// ~16 — net <2% for real complexity.
//
// Perf (2026-10-22, pass 3): hot columns are borrowed slices;
// loop-carried state (cum, rank counter, prev key, k) are tor params —
// registers, not store rows (PERF recipes 6/13); byte grids u8,
// position/rank columns i32, packed sa+key columns i64; wraps are
// bound two-way ifs. Per-element ops per round: scatter 3L+2S,
// rerank 1L+3S — two passes, ~9 ops vs ~28 originally. Working set
// ~2.6MB. result_val accumulates transformed.len only — the content
// is the work, the length is the receipt.

import std/io
import std/grid
import std/store

std/grid:new(pat, size: 11) { b: 0[u8] }
std/grid:new(dat, size: 100000) { b: 0[u8] }
std/grid:new(cnt, size: 100001) { v: 0[i32] }
std/grid:new(rnk, size: 100000) { v: 0[i32] }
std/grid:new(sak, size: 100000) { v: 0[i64] }
std/grid:new(tsa, size: 100000) { v: 0[i64] }
std/grid:new(out, size: 100000) { b: 0[u8] }
std/grid:slice(dat_s) { dat.b }
std/grid:slice(cnt_s) { cnt.v }
std/grid:slice(rnk_s) { rnk.v }
std/grid:slice(sak_s) { sak.v }
std/grid:slice(tsa_s) { tsa.v }
std/grid:slice(out_s) { out.b }
std/grid:slice(pat_s) { pat.b }
std/store:new(st) { res: 0[i64], n: 100000[i64], oidx: 0[i64], t1: 0[i64], t2: 0[i64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

pub tor idv { v: i64 } -> i64
idv -> v

// genl — test_data[i] = "ABRACADABRA"[i % 11]
pub tor genl { i: i64 } -> i64
genl = std/grid:stored { dat_s[@as(usize, @intCast(i))]: pat_s[@as(usize, @intCast(@rem(i, 11)))] }
    |> if(i < st.n - 1)
        | then |> genl(i: i + 1): r -> r
        | else |> ret0(): r -> r

// ---- phase 1: counting sort by first byte ----
pub tor zc { i: i64 } -> i64
zc = std/grid:stored { cnt_s[@as(usize, @intCast(i))]: 0 }
    |> if(i < 255)
        | then |> zc(i: i + 1): r -> r
        | else |> ret0(): r -> r

pub tor cntb { i: i64, nn: i64 } -> i64
cntb = std/grid:stored { cnt_s[@as(usize, dat_s[@as(usize, @intCast(i))])]: cnt_s[@as(usize, dat_s[@as(usize, @intCast(i))])] + 1 }
    |> if(i < nn - 1)
        | then |> cntb(i: i + 1, nn): r -> r
        | else |> ret0(): r -> r

// pfx — in-place: cnt[i] becomes bucket start; cum += old cnt[i]
pub tor pfx { i: i64, cum: i64, nn: i64 } -> i64
pfx = if(i < nn)
| then |> idv(v: @as(i64, cnt_s[@as(usize, @intCast(i))])): t
    |> std/grid:stored { cnt_s[@as(usize, @intCast(i))]: @as(i32, @intCast(cum)) }
    |> pfx(i: i + 1, cum: cum + t, nn): r -> r
| else -> 0

// sct — phase-1 scatter straight into sak: sak[cnt[b]++] = i
pub tor sct { i: i64, nn: i64 } -> i64
sct = idv(v: @as(i64, dat_s[@as(usize, @intCast(i))])): b
    |> idv(v: @as(i64, cnt_s[@as(usize, @intCast(b))])): p
    |> std/grid:stored { cnt_s[@as(usize, @intCast(b))]: @as(i32, @intCast(p + 1)) }
    |> std/grid:stored { sak_s[@as(usize, @intCast(p))]: i }
    |> if(i < nn - 1)
        | then |> sct(i: i + 1, nn): r -> r
        | else |> ret0(): r -> r

// ---- rank init from sorted first chars ----
// rinit0 — position 0: rank 0; cnt[0]=0, cnt[1]=1 (shifted-cursor
// scheme: element at position i with rank r writes cnt[r+1]=i+1, so
// after the pass cnt[r] = start of rank r's bucket)
pub tor rinit0 { } -> i64
rinit0 = idv(v: sak_s[0]): t2
    |> std/grid:stored { rnk_s[@as(usize, @intCast(t2))]: 0 }
    |> std/grid:stored { cnt_s[0]: 0 }
    |> std/grid:stored { cnt_s[1]: 1 }
    |> ret0(): _ -> 0

// rinit — on char change the rank increments; writes element-rank
// rnk[t1], position-rank into sak[i]<<34, and the shifted bucket
// cursor cnt[cr2+1]=i+1 (see rinit0)
pub tor rinit { i: i64, cr: i64, pc: i64, nn: i64 } -> i64
rinit = idv(v: sak_s[@as(usize, @intCast(i))]): t1
    |> if(@as(i64, dat_s[@as(usize, @intCast(t1))]) != pc)
        | then |> std/grid:stored { rnk_s[@as(usize, @intCast(t1))]: @as(i32, @intCast(cr + 1)) }
            |> std/grid:stored { sak_s[@as(usize, @intCast(i))]: t1 + ((cr + 1) << 34) }
            |> std/grid:stored { cnt_s[@as(usize, @intCast(cr + 2))]: @as(i32, @intCast(i + 1)) }
            |> if(i < nn - 1)
                | then |> rinit(i: i + 1, cr: cr + 1, pc: @as(i64, dat_s[@as(usize, @intCast(t1))]), nn): r -> r
                | else -> cr + 1
        | else |> std/grid:stored { rnk_s[@as(usize, @intCast(t1))]: @as(i32, @intCast(cr)) }
            |> std/grid:stored { sak_s[@as(usize, @intCast(i))]: t1 + (cr << 34) }
            |> std/grid:stored { cnt_s[@as(usize, @intCast(cr + 1))]: @as(i32, @intCast(i + 1)) }
            |> if(i < nn - 1)
                | then |> rinit(i: i + 1, cr, pc, nn): r -> r
                | else -> cr

// ---- doubling rounds: sak/tsa ping-pong ----
// sktS — read sak[i] (= e | rank<<34), scatter shifted element into
// tsa by key1=rnk[e-k mod n]; stored word = e | r2<<17 | r1<<34
// (r1 high so dst>>17 compares pair keys lexicographically — see b)
pub tor sktS { i: i64, k: i64, nn: i64 } -> i64
sktS = idv(v: sak_s[@as(usize, @intCast(i))]): v
    |> idv(v: (v & 131071) - k): dd
    |> idv(v: if(dd < 0) dd + nn else dd): e
    |> idv(v: @as(i64, rnk_s[@as(usize, @intCast(e))])): r1
    |> idv(v: @as(i64, cnt_s[@as(usize, @intCast(r1))])): p
    |> std/grid:stored { cnt_s[@as(usize, @intCast(r1))]: @as(i32, @intCast(p + 1)) }
    |> std/grid:stored { tsa_s[@as(usize, @intCast(p))]: e + (r1 << 34) + ((v & -17179869184) >> 17) }
    |> if(i < nn - 1)
        | then |> sktS(i: i + 1, k, nn): r -> r
        | else |> ret0(): r -> r

// sktT — mirror: read tsa, scatter into sak
pub tor sktT { i: i64, k: i64, nn: i64 } -> i64
sktT = idv(v: tsa_s[@as(usize, @intCast(i))]): v
    |> idv(v: (v & 131071) - k): dd
    |> idv(v: if(dd < 0) dd + nn else dd): e
    |> idv(v: @as(i64, rnk_s[@as(usize, @intCast(e))])): r1
    |> idv(v: @as(i64, cnt_s[@as(usize, @intCast(r1))])): p
    |> std/grid:stored { cnt_s[@as(usize, @intCast(r1))]: @as(i32, @intCast(p + 1)) }
    |> std/grid:stored { sak_s[@as(usize, @intCast(p))]: e + (r1 << 34) + ((v & -17179869184) >> 17) }
    |> if(i < nn - 1)
        | then |> sktT(i: i + 1, k, nn): r -> r
        | else |> ret0(): r -> r

// sktLS/sktLT — final round fused with emt: position p IS the output
// slot, so out[p] = data[(e-1) mod n] is written in the same pass
// (saves a whole emit sweep; oidx recorded when e==0)
pub tor sktLS { i: i64, k: i64, nn: i64 } -> i64
sktLS = idv(v: sak_s[@as(usize, @intCast(i))]): v
    |> idv(v: (v & 131071) - k): dd
    |> idv(v: if(dd < 0) dd + nn else dd): e
    |> idv(v: @as(i64, rnk_s[@as(usize, @intCast(e))])): r1
    |> idv(v: @as(i64, cnt_s[@as(usize, @intCast(r1))])): p
    |> std/grid:stored { cnt_s[@as(usize, @intCast(r1))]: @as(i32, @intCast(p + 1)) }
    |> std/grid:stored { tsa_s[@as(usize, @intCast(p))]: e }
    |> idv(v: if(e == 0) nn - 1 else e - 1): j
    |> std/grid:stored { out_s[@as(usize, @intCast(p))]: dat_s[@as(usize, @intCast(j))] }
    |> if(e == 0)
        | then |> std/store:stored { st.oidx: p }
            |> if(i < nn - 1)
                | then |> sktLS(i: i + 1, k, nn): r -> r
                | else -> 0
        | else |> if(i < nn - 1)
            | then |> sktLS(i: i + 1, k, nn): r -> r
            | else -> 0

pub tor sktLT { i: i64, k: i64, nn: i64 } -> i64
sktLT = idv(v: tsa_s[@as(usize, @intCast(i))]): v
    |> idv(v: (v & 131071) - k): dd
    |> idv(v: if(dd < 0) dd + nn else dd): e
    |> idv(v: @as(i64, rnk_s[@as(usize, @intCast(e))])): r1
    |> idv(v: @as(i64, cnt_s[@as(usize, @intCast(r1))])): p
    |> std/grid:stored { cnt_s[@as(usize, @intCast(r1))]: @as(i32, @intCast(p + 1)) }
    |> std/grid:stored { sak_s[@as(usize, @intCast(p))]: e }
    |> idv(v: if(e == 0) nn - 1 else e - 1): j
    |> std/grid:stored { out_s[@as(usize, @intCast(p))]: dat_s[@as(usize, @intCast(j))] }
    |> if(e == 0)
        | then |> std/store:stored { st.oidx: p }
            |> if(i < nn - 1)
                | then |> sktLT(i: i + 1, k, nn): r -> r
                | else -> 0
        | else |> if(i < nn - 1)
            | then |> sktLT(i: i + 1, k, nn): r -> r
            | else -> 0

// nrnT0/nrnS0 — position 0 of the just-scattered array: rank 0,
// stale key bits cleared, cursors seeded (cnt[0]=0, cnt[1]=1)
pub tor nrnT0 { } -> i64
nrnT0 = idv(v: tsa_s[0] & 131071): t2
    |> std/grid:stored { rnk_s[@as(usize, @intCast(t2))]: 0 }
    |> std/grid:stored { tsa_s[0]: t2 }
    |> std/grid:stored { cnt_s[0]: 0 }
    |> std/grid:stored { cnt_s[1]: 1 }
    |> ret0(): _ -> 0

pub tor nrnS0 { } -> i64
nrnS0 = idv(v: sak_s[0] & 131071): t2
    |> std/grid:stored { rnk_s[@as(usize, @intCast(t2))]: 0 }
    |> std/grid:stored { sak_s[0]: t2 }
    |> std/grid:stored { cnt_s[0]: 0 }
    |> std/grid:stored { cnt_s[1]: 1 }
    |> ret0(): _ -> 0

// nrnT/nrnS — rerank in place + next round's cursors.
// kk = cell>>17 is the packed pair key (r1 high, r2 low) — the
// scatter writes r1 into bits 34+ and r2 into bits 17..33 so that
// INTEGER order on kk is lexicographic pair order: kk is then
// non-decreasing down the sorted positions and
//   cr2 = cr + min(kk - pk, 1)
// is a branch-free rank transition (0 on same key, 1 on new key).
// LESSON: an earlier layout packed r1 LOW (e|r1<<17|r2<<34); integer
// comparison then ordered (r2, r1) — `kk > pk` selects corrupted the
// SA (oidx 36842 vs 18181) and min(kk-pk,1) went negative and
// segfaulted through cnt[cr2+1]. Only `==` was safe there. (`==`
// inside an idv if-expression also hits a nested-blk redefinition;
// `>` compiles. The min form avoids if-expressions entirely.)
pub tor nrnT { i: i64, cr: i64, pk: i64, nn: i64 } -> i64
nrnT = idv(v: tsa_s[@as(usize, @intCast(i))]): v
    |> idv(v: v >> 17): kk
    |> idv(v: v & 131071): t2
    |> idv(v: cr + @min(kk - pk, 1)): cr2
    |> std/grid:stored { rnk_s[@as(usize, @intCast(t2))]: @as(i32, @intCast(cr2)) }
    |> std/grid:stored { tsa_s[@as(usize, @intCast(i))]: t2 + (cr2 << 34) }
    |> std/grid:stored { cnt_s[@as(usize, @intCast(cr2 + 1))]: @as(i32, @intCast(i + 1)) }
    |> if(i < nn - 1)
        | then |> nrnT(i: i + 1, cr: cr2, pk: kk, nn): r -> r
        | else -> cr2

pub tor nrnS { i: i64, cr: i64, pk: i64, nn: i64 } -> i64
nrnS = idv(v: sak_s[@as(usize, @intCast(i))]): v
    |> idv(v: v >> 17): kk
    |> idv(v: v & 131071): t2
    |> idv(v: cr + @min(kk - pk, 1)): cr2
    |> std/grid:stored { rnk_s[@as(usize, @intCast(t2))]: @as(i32, @intCast(cr2)) }
    |> std/grid:stored { sak_s[@as(usize, @intCast(i))]: t2 + (cr2 << 34) }
    |> std/grid:stored { cnt_s[@as(usize, @intCast(cr2 + 1))]: @as(i32, @intCast(i + 1)) }
    |> if(i < nn - 1)
        | then |> nrnS(i: i + 1, cr: cr2, pk: kk, nn): r -> r
        | else -> cr2

// dblA — source ranks in sak: scatter into tsa, rerank, recurse to
// dblB. The scatter must run once per round, so the k*2 branch picks
// the variant first (running sktS then sktLS would re-scatter on
// exhausted cursors). pk0 captured before nrnT0 clears tsa[0]'s bits.
pub tor dblA { k: i64, nn: i64, nb: i64 } -> i64
dblA = if(k < nn and nb < nn)
| then |> if(k * 2 < nn)
        | then |> sktS(i: 0, k, nn): _
            |> idv(v: tsa_s[0] >> 17): pk0
            |> nrnT0(): _
            |> nrnT(i: 1, cr: 0, pk: pk0, nn): ncr
            |> dblB(k: k * 2, nn, nb: ncr + 1): r -> r
        | else |> sktLS(i: 0, k, nn): r -> r
| else |> emtS(i: 0, nn): r -> r

// dblB — mirror: source in tsa, scatter into sak
pub tor dblB { k: i64, nn: i64, nb: i64 } -> i64
dblB = if(k < nn and nb < nn)
| then |> if(k * 2 < nn)
        | then |> sktT(i: 0, k, nn): _
            |> idv(v: sak_s[0] >> 17): pk0
            |> nrnS0(): _
            |> nrnS(i: 1, cr: 0, pk: pk0, nn): ncr
            |> dblA(k: k * 2, nn, nb: ncr + 1): r -> r
        | else |> sktLT(i: 0, k, nn): r -> r
| else |> emtT(i: 0, nn): r -> r

// emtS/emtT — transformed[i] = data[sa[i]-1]; sa[i]==0 → data[n-1]
pub tor emtS { i: i64, nn: i64 } -> i64
emtS = idv(v: sak_s[@as(usize, @intCast(i))] & 131071): s
    |> idv(v: if(s == 0) nn - 1 else s - 1): j
    |> std/grid:stored { out_s[@as(usize, @intCast(i))]: dat_s[@as(usize, @intCast(j))] }
    |> if(s == 0)
        | then |> std/store:stored { st.oidx: i }
            |> if(i < nn - 1)
                | then |> emtS(i: i + 1, nn): r -> r
                | else |> ret0(): r -> r
        | else |> if(i < nn - 1)
            | then |> emtS(i: i + 1, nn): r -> r
            | else |> ret0(): r -> r

pub tor emtT { i: i64, nn: i64 } -> i64
emtT = idv(v: tsa_s[@as(usize, @intCast(i))] & 131071): s
    |> idv(v: if(s == 0) nn - 1 else s - 1): j
    |> std/grid:stored { out_s[@as(usize, @intCast(i))]: dat_s[@as(usize, @intCast(j))] }
    |> if(s == 0)
        | then |> std/store:stored { st.oidx: i }
            |> if(i < nn - 1)
                | then |> emtT(i: i + 1, nn): r -> r
                | else |> ret0(): r -> r
        | else |> if(i < nn - 1)
            | then |> emtT(i: i + 1, nn): r -> r
            | else |> ret0(): r -> r

// one full transform (runImpl)
pub tor bwt { nn: i64 } -> i64
bwt = zc(i: 0): _
    |> cntb(i: 0, nn): _
    |> pfx(i: 0, cum: 0, nn: 256): _
    |> sct(i: 0, nn): _
    |> rinit0(): _
    |> rinit(i: 1, cr: 0, pc: @as(i64, dat_s[@as(usize, @intCast(sak_s[0]))]), nn): nb0
    |> dblA(k: 1, nn, nb: nb0 + 1): _
    |> std/store:stored { st.res: st.res + nn }
    |> ret0(): _ -> 0

// runl — 36 runs
pub tor runl { k: i64 } -> i64
runl = bwt(nn: st.n): _
    |> if(k < 35)
        | then |> runl(k: k + 1): r -> r
        | else |> ret0(): r -> r

// ---- driver ----
ret0(): _
|> std/grid:stored { pat_s[0]: @as(u8, 65) }
|> std/grid:stored { pat_s[1]: @as(u8, 66) }
|> std/grid:stored { pat_s[2]: @as(u8, 82) }
|> std/grid:stored { pat_s[3]: @as(u8, 65) }
|> std/grid:stored { pat_s[4]: @as(u8, 67) }
|> std/grid:stored { pat_s[5]: @as(u8, 65) }
|> std/grid:stored { pat_s[6]: @as(u8, 68) }
|> std/grid:stored { pat_s[7]: @as(u8, 65) }
|> std/grid:stored { pat_s[8]: @as(u8, 66) }
|> std/grid:stored { pat_s[9]: @as(u8, 82) }
|> std/grid:stored { pat_s[10]: @as(u8, 65) }
|> genl(i: 0): _
|> runl(k: 0): _
|> std/io:print.ln("{{ st.res:d }}")
