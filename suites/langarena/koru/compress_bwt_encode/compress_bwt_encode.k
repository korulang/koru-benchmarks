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
// The reference uses driftsort (sort_by on (rank,rank[(i+k)%n]) pairs)
// for the pair sort; we use a stable two-pass counting radix over the
// same bounded rank keys — stability keeps identical sa order under
// ties, so the result is the same transform (and radix is the better
// big-O: O(n)/round vs O(n log n)).
//
// Perf (2026-10-22): hot columns are borrowed slices (verbatim
// indexing, no floor checks); loop-carried state (cum, rank counter,
// prev char, k) are tor params — registers, not store rows (PERF
// recipes 6/13); byte grids are u8 (recipe 12); the (i+k)%n wrap is a
// bound two-way if since sa[i]+k < 2n. result_val accumulates
// transformed.len only — the content is the work, the length is the
// receipt.

import std/io
import std/grid
import std/store

std/grid:new(pat, size: 11) { b: 0[u8] }
std/grid:new(dat, size: 100000) { b: 0[u8] }
std/grid:new(cnt, size: 100000) { v: 0[i64] }
std/grid:new(ps, size: 100000) { v: 0[i64] }
std/grid:new(sa, size: 100000) { v: 0[i64] }
std/grid:new(tsa, size: 100000) { v: 0[i64] }
std/grid:new(rnk, size: 100000) { v: 0[i64] }
std/grid:new(nr, size: 100000) { v: 0[i64] }
std/grid:new(out, size: 100000) { b: 0[u8] }
std/grid:slice(dat_s) { dat.b }
std/grid:slice(cnt_s) { cnt.v }
std/grid:slice(ps_s) { ps.v }
std/grid:slice(sa_s) { sa.v }
std/grid:slice(tsa_s) { tsa.v }
std/grid:slice(rnk_s) { rnk.v }
std/grid:slice(nr_s) { nr.v }
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

// pfx — positions ps[i] = cum; cum += cnt[i], param-carried
pub tor pfx { i: i64, cum: i64, nn: i64 } -> i64
pfx = if(i < nn)
| then |> std/grid:stored { ps_s[@as(usize, @intCast(i))]: cum }
    |> pfx(i: i + 1, cum: cum + cnt_s[@as(usize, @intCast(i))], nn): r -> r
| else -> 0

// sct — scatter: tsa[ps[b]++] = i
pub tor sct { i: i64, nn: i64 } -> i64
sct = idv(v: @as(i64, dat_s[@as(usize, @intCast(i))])): b
    |> std/grid:stored { tsa_s[@as(usize, @intCast(ps_s[@as(usize, @intCast(b))]))]: i }
    |> std/grid:stored { ps_s[@as(usize, @intCast(b))]: ps_s[@as(usize, @intCast(b))] + 1 }
    |> if(i < nn - 1)
        | then |> sct(i: i + 1, nn): r -> r
        | else |> ret0(): r -> r

// cpy: sa <- tsa
pub tor cpy { i: i64, nn: i64 } -> i64
cpy = std/grid:stored { sa_s[@as(usize, @intCast(i))]: tsa_s[@as(usize, @intCast(i))] }
    |> if(i < nn - 1)
        | then |> cpy(i: i + 1, nn): r -> r
        | else |> ret0(): r -> r

// ---- rank init from sorted first chars ----
pub tor rinit0 { } -> i64
rinit0 = std/grid:stored { rnk_s[@as(usize, @intCast(sa_s[0]))]: 0 }
    |> ret0(): _ -> 0

// rinit { i, cr, pc } — cr = current rank, pc = prev char (params)
pub tor rinit { i: i64, cr: i64, pc: i64, nn: i64 } -> i64
rinit = idv(v: sa_s[@as(usize, @intCast(i))]): t1
    |> if(@as(i64, dat_s[@as(usize, @intCast(t1))]) != pc)
        | then |> std/grid:stored { rnk_s[@as(usize, @intCast(t1))]: cr + 1 }
            |> if(i < nn - 1)
                | then |> rinit(i: i + 1, cr: cr + 1, pc: @as(i64, dat_s[@as(usize, @intCast(t1))]), nn): r -> r
                | else -> cr + 1
        | else |> std/grid:stored { rnk_s[@as(usize, @intCast(t1))]: cr }
            |> if(i < nn - 1)
                | then |> rinit(i: i + 1, cr, pc, nn): r -> r
                | else -> cr

// ---- radix passes over rank keys ----
pub tor zn { i: i64, nn: i64 } -> i64
zn = std/grid:stored { cnt_s[@as(usize, @intCast(i))]: 0 }
    |> if(i < nn - 1)
        | then |> zn(i: i + 1, nn): r -> r
        | else |> ret0(): r -> r

// cA — count key2 = rnk[(x + k) mod n]; x+k < 2n so the wrap is a bound-if
pub tor cA { i: i64, k: i64, nn: i64 } -> i64
cA = idv(v: if(sa_s[@as(usize, @intCast(i))] + k >= nn) sa_s[@as(usize, @intCast(i))] + k - nn else sa_s[@as(usize, @intCast(i))] + k): w
    |> std/grid:stored { cnt_s[@as(usize, @intCast(rnk_s[@as(usize, @intCast(w))]))]: cnt_s[@as(usize, @intCast(rnk_s[@as(usize, @intCast(w))]))] + 1 }
    |> if(i < nn - 1)
        | then |> cA(i: i + 1, k, nn): r -> r
        | else |> ret0(): r -> r

pub tor sA { i: i64, k: i64, nn: i64 } -> i64
sA = idv(v: if(sa_s[@as(usize, @intCast(i))] + k >= nn) sa_s[@as(usize, @intCast(i))] + k - nn else sa_s[@as(usize, @intCast(i))] + k): w
    |> idv(v: rnk_s[@as(usize, @intCast(w))]): t1
    |> std/grid:stored { tsa_s[@as(usize, @intCast(ps_s[@as(usize, @intCast(t1))]))]: sa_s[@as(usize, @intCast(i))] }
    |> std/grid:stored { ps_s[@as(usize, @intCast(t1))]: ps_s[@as(usize, @intCast(t1))] + 1 }
    |> if(i < nn - 1)
        | then |> sA(i: i + 1, k, nn): r -> r
        | else |> ret0(): r -> r

// ck — combined-key counting: key = rnk[e]*nb + rnk[(e+k)%n] (stable,
// identical order to the two-pass radix when nb*nb fits cnt)
pub tor ck { i: i64, k: i64, nn: i64, nb: i64 } -> i64
ck = idv(v: sa_s[@as(usize, @intCast(i))]): e
    |> idv(v: if(e + k >= nn) e + k - nn else e + k): w
    |> std/grid:stored { cnt_s[@as(usize, @intCast(rnk_s[@as(usize, @intCast(e))] * nb + rnk_s[@as(usize, @intCast(w))]))]: cnt_s[@as(usize, @intCast(rnk_s[@as(usize, @intCast(e))] * nb + rnk_s[@as(usize, @intCast(w))]))] + 1 }
    |> if(i < nn - 1)
        | then |> ck(i: i + 1, k, nn, nb): r -> r
        | else |> ret0(): r -> r

pub tor sk { i: i64, k: i64, nn: i64, nb: i64 } -> i64
sk = idv(v: sa_s[@as(usize, @intCast(i))]): e
    |> idv(v: if(e + k >= nn) e + k - nn else e + k): w
    |> idv(v: rnk_s[@as(usize, @intCast(e))] * nb + rnk_s[@as(usize, @intCast(w))]): t1
    |> std/grid:stored { tsa_s[@as(usize, @intCast(ps_s[@as(usize, @intCast(t1))]))]: e }
    |> std/grid:stored { ps_s[@as(usize, @intCast(t1))]: ps_s[@as(usize, @intCast(t1))] + 1 }
    |> if(i < nn - 1)
        | then |> sk(i: i + 1, k, nn, nb): r -> r
        | else |> ret0(): r -> r

// cB/sB — second pass by key1 = rnk[x]
pub tor cB { i: i64, nn: i64 } -> i64
cB = std/grid:stored { cnt_s[@as(usize, @intCast(rnk_s[@as(usize, @intCast(tsa_s[@as(usize, @intCast(i))]))]))]: cnt_s[@as(usize, @intCast(rnk_s[@as(usize, @intCast(tsa_s[@as(usize, @intCast(i))]))]))] + 1 }
    |> if(i < nn - 1)
        | then |> cB(i: i + 1, nn): r -> r
        | else |> ret0(): r -> r

pub tor sB { i: i64, nn: i64 } -> i64
sB = idv(v: rnk_s[@as(usize, @intCast(tsa_s[@as(usize, @intCast(i))]))]): t1
    |> std/grid:stored { sa_s[@as(usize, @intCast(ps_s[@as(usize, @intCast(t1))]))]: tsa_s[@as(usize, @intCast(i))] }
    |> std/grid:stored { ps_s[@as(usize, @intCast(t1))]: ps_s[@as(usize, @intCast(t1))] + 1 }
    |> if(i < nn - 1)
        | then |> sB(i: i + 1, nn): r -> r
        | else |> ret0(): r -> r

// rdx — one radix round: sort sa by (key1, key2)
pub tor rdx { k: i64, nn: i64, nb: i64 } -> i64
rdx = if(nb * nb <= nn)
| then |> zn(i: 0, nn: nb * nb): _
    |> ck(i: 0, k, nn, nb): _
    |> pfx(i: 0, cum: 0, nn: nb * nb): _
    |> sk(i: 0, k, nn, nb): _
    |> cpy(i: 0, nn): _
    |> ret0(): r -> r
| else |> zn(i: 0, nn: nb): _
    |> cA(i: 0, k, nn): _
    |> pfx(i: 0, cum: 0, nn: nb): _
    |> sA(i: 0, k, nn): _
    |> zn(i: 0, nn: nb): _
    |> cB(i: 0, nn): _
    |> pfx(i: 0, cum: 0, nn: nb): _
    |> sB(i: 0, nn): _
    |> ret0(): r -> r

// nrn — re-rank from sorted sa; pairwise compare via slices.
// cr is the running rank counter (param); keys read verbatim.
pub tor nrn0 { nn: i64 } -> i64
nrn0 = std/grid:stored { nr_s[@as(usize, @intCast(sa_s[0]))]: 0 }
    |> ret0(): _ -> 0

pub tor nrn { i: i64, k: i64, cr: i64, nn: i64 } -> i64
nrn = idv(v: sa_s[@as(usize, @intCast(i - 1))]): t1
    |> idv(v: sa_s[@as(usize, @intCast(i))]): t2
    |> idv(v: if(t1 + k >= nn) t1 + k - nn else t1 + k): w1
    |> idv(v: if(t2 + k >= nn) t2 + k - nn else t2 + k): w2
    |> idv(v: rnk_s[@as(usize, @intCast(t1))]): r1
    |> idv(v: rnk_s[@as(usize, @intCast(t2))]): r2
    |> idv(v: rnk_s[@as(usize, @intCast(w1))]): q1
    |> idv(v: rnk_s[@as(usize, @intCast(w2))]): q2
    |> if(r1 == r2)
        | then |> if(q1 == q2)
            | then |> std/grid:stored { nr_s[@as(usize, @intCast(t2))]: cr }
                |> if(i < nn - 1)
                    | then |> nrn(i: i + 1, k, cr, nn): r -> r
                    | else -> cr
            | else |> std/grid:stored { nr_s[@as(usize, @intCast(t2))]: cr + 1 }
                |> if(i < nn - 1)
                    | then |> nrn(i: i + 1, k, cr: cr + 1, nn): r -> r
                    | else -> cr + 1
        | else |> std/grid:stored { nr_s[@as(usize, @intCast(t2))]: cr + 1 }
            |> if(i < nn - 1)
                | then |> nrn(i: i + 1, k, cr: cr + 1, nn): r -> r
                | else -> cr + 1

// cpn — rank <- nr
pub tor cpn { i: i64, nn: i64 } -> i64
cpn = std/grid:stored { rnk_s[@as(usize, @intCast(i))]: nr_s[@as(usize, @intCast(i))] }
    |> if(i < nn - 1)
        | then |> cpn(i: i + 1, nn): r -> r
        | else |> ret0(): r -> r

// dbl — doubling loop: while k < n { radix-sort, re-rank, k *= 2 }
pub tor dbl { k: i64, nn: i64, nb: i64 } -> i64
dbl = if(k < nn and nb < nn)
| then |> rdx(k, nn, nb): _
    |> nrn0(nn): _
    |> nrn(i: 1, k, cr: 0, nn): crn
    |> cpn(i: 0, nn): _
    |> dbl(k: k * 2, nn, nb: crn + 1): r -> r
| else -> 0

// emt — transformed[i] = data[sa[i]-1]; sa[i]==0 → data[n-1], oidx=i
pub tor emt { i: i64, nn: i64 } -> i64
emt = idv(v: sa_s[@as(usize, @intCast(i))]): s
    |> idv(v: if(s == 0) nn - 1 else s - 1): j
    |> std/grid:stored { out_s[@as(usize, @intCast(i))]: dat_s[@as(usize, @intCast(j))] }
    |> if(s == 0)
        | then |> std/store:stored { st.oidx: i }
            |> if(i < nn - 1)
                | then |> emt(i: i + 1, nn): r -> r
                | else |> ret0(): r -> r
        | else |> if(i < nn - 1)
            | then |> emt(i: i + 1, nn): r -> r
            | else |> ret0(): r -> r

// one full transform (runImpl)
pub tor bwt { nn: i64 } -> i64
bwt = zc(i: 0): _
    |> cntb(i: 0, nn): _
    |> pfx(i: 0, cum: 0, nn: 256): _
    |> sct(i: 0, nn): _
    |> cpy(i: 0, nn): _
    |> rinit0(): _
    |> rinit(i: 1, cr: 0, pc: @as(i64, dat_s[@as(usize, @intCast(sa_s[0]))]), nn): nb0
    |> dbl(k: 1, nn, nb: nb0 + 1): _
    |> emt(i: 0, nn): _
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
