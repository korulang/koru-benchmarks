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
// The reference uses std.sort.block (stable) for the pair sort; we
// use a stable two-pass counting radix over the same bounded rank
// keys — stability keeps identical sa order under ties, so the
// result is the same transform.
//
// result_val accumulates transformed.len only — the content is the
// work, the length is the receipt.

import std/io
import std/grid
import std/store

std/grid:new(pat, size: 11) { b: 0[i64] }
std/grid:new(dat, size: 100000) { b: 0[i64] }
std/grid:new(cnt, size: 100000) { v: 0[i64] }
std/grid:new(ps, size: 100000) { v: 0[i64] }
std/grid:new(sa, size: 100000) { v: 0[i64] }
std/grid:new(tsa, size: 100000) { v: 0[i64] }
std/grid:new(rnk, size: 100000) { v: 0[i64] }
std/grid:new(nr, size: 100000) { v: 0[i64] }
std/grid:new(out, size: 100000) { b: 0[i64] }
std/store:new(st) { res: 0[i64], n: 100000[i64], oidx: 0[i64], cr: 0[i64], pc: 0[i64], t1: 0[i64], t2: 0[i64], k: 0[i64], acc: 0[i64] }

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

// ---- phase 1: counting sort by first byte ----
// zero cnt[0..255]
pub tor zc { i: i64 } -> i64
zc = std/grid:stored { cnt[i].v: 0 }
    |> if(i < 255)
        | then |> zc(i: i + 1): r -> r
        | else |> ret0(): r -> r

pub tor cntb { i: i64 } -> i64
cntb = std/grid:stored { cnt[dat[i].b].v: cnt[dat[i].b].v + 1 }
    |> if(i < st.n - 1)
        | then |> cntb(i: i + 1): r -> r
        | else |> ret0(): r -> r

// positions into ps[0..255]: ps[i] = cum; cum += cnt[i]
pub tor pfx { i: i64 } -> i64
pfx = if(i < 256)
| then |> std/grid:stored { ps[i].v: st.acc }
    |> std/store:stored { st.acc: st.acc + cnt[i].v }
    |> pfx(i: i + 1): r -> r
| else -> 0

// scatter: tsa[ps[b]++] = i  (ps doubles as cursor)
pub tor sct { i: i64 } -> i64
sct = std/store:stored { st.t1: dat[i].b }
    |> std/grid:stored { tsa[ps[st.t1].v].v: i }
    |> std/grid:stored { ps[st.t1].v: ps[st.t1].v + 1 }
    |> if(i < st.n - 1)
        | then |> sct(i: i + 1): r -> r
        | else |> ret0(): r -> r

// cpy: sa <- tsa
pub tor cpy { i: i64 } -> i64
cpy = std/grid:stored { sa[i].v: tsa[i].v }
    |> if(i < st.n - 1)
        | then |> cpy(i: i + 1): r -> r
        | else |> ret0(): r -> r

// ---- rank init from sorted first chars ----
pub tor rinit0 { } -> i64
rinit0 = std/grid:stored { rnk[sa[0].v].v: 0 }
    |> std/store:stored { st.pc: dat[sa[0].v].b }
    |> std/store:stored { st.cr: 0 }
    |> ret0(): _ -> 0

// rinit — self-recursive tail only: a helper-tor bounce would be a
// mutual call and never lower (PARKED #2), so the loop tail is an
// `if` nested inside each arm.
pub tor rinit { i: i64 } -> i64
rinit = std/store:stored { st.t1: sa[i].v }
    |> if(dat[st.t1].b != st.pc)
        | then |> std/store:stored { st.cr: st.cr + 1 }
            |> std/store:stored { st.pc: dat[st.t1].b }
            |> std/grid:stored { rnk[st.t1].v: st.cr }
            |> if(i < st.n - 1)
                | then |> rinit(i: i + 1): r -> r
                | else |> ret0(): r -> r
        | else |> std/grid:stored { rnk[st.t1].v: st.cr }
            |> if(i < st.n - 1)
                | then |> rinit(i: i + 1): r -> r
                | else |> ret0(): r -> r

// ---- radix passes over rank keys ----
// zn: zero cnt[0..n)
pub tor zn { i: i64 } -> i64
zn = std/grid:stored { cnt[i].v: 0 }
    |> if(i < st.n - 1)
        | then |> zn(i: i + 1): r -> r
        | else |> ret0(): r -> r

// pn: ps[i] = cum; cum += cnt[i] over 0..n
pub tor pn { i: i64 } -> i64
pn = if(i < st.n)
| then |> std/grid:stored { ps[i].v: st.acc }
    |> std/store:stored { st.acc: st.acc + cnt[i].v }
    |> pn(i: i + 1): r -> r
| else -> 0

// pass A: sa → tsa by key2 = rnk[(x + k) % n]
pub tor cA { i: i64 } -> i64
cA = std/grid:stored { cnt[rnk[@rem(sa[i].v + st.k, st.n)].v].v: cnt[rnk[@rem(sa[i].v + st.k, st.n)].v].v + 1 }
    |> if(i < st.n - 1)
        | then |> cA(i: i + 1): r -> r
        | else |> ret0(): r -> r

pub tor sA { i: i64 } -> i64
sA = std/store:stored { st.t1: rnk[@rem(sa[i].v + st.k, st.n)].v }
    |> std/grid:stored { tsa[ps[st.t1].v].v: sa[i].v }
    |> std/grid:stored { ps[st.t1].v: ps[st.t1].v + 1 }
    |> if(i < st.n - 1)
        | then |> sA(i: i + 1): r -> r
        | else |> ret0(): r -> r

// pass B: tsa → sa by key1 = rnk[x]
pub tor cB { i: i64 } -> i64
cB = std/grid:stored { cnt[rnk[tsa[i].v].v].v: cnt[rnk[tsa[i].v].v].v + 1 }
    |> if(i < st.n - 1)
        | then |> cB(i: i + 1): r -> r
        | else |> ret0(): r -> r

pub tor sB { i: i64 } -> i64
sB = std/store:stored { st.t1: rnk[tsa[i].v].v }
    |> std/grid:stored { sa[ps[st.t1].v].v: tsa[i].v }
    |> std/grid:stored { ps[st.t1].v: ps[st.t1].v + 1 }
    |> if(i < st.n - 1)
        | then |> sB(i: i + 1): r -> r
        | else |> ret0(): r -> r

// rdx — one radix round: sort sa by (key1, key2)
pub tor rdx { } -> i64
rdx = zn(i: 0): _
    |> cA(i: 0): _
    |> std/store:stored { st.acc: 0 }
    |> pn(i: 0): _
    |> sA(i: 0): _
    |> zn(i: 0): _
    |> cB(i: 0): _
    |> std/store:stored { st.acc: 0 }
    |> pn(i: 0): _
    |> sB(i: 0): _
    |> ret0(): _ -> 0

// nrn — re-rank from sorted sa; nr[sa[0]] = 0, then pairwise compare
pub tor nrn0 { } -> i64
nrn0 = std/grid:stored { nr[sa[0].v].v: 0 }
    |> ret0(): _ -> 0

pub tor nrn { i: i64 } -> i64
nrn = std/store:stored { st.t1: sa[i - 1].v }
    |> std/store:stored { st.t2: sa[i].v }
    |> if(rnk[st.t1].v == rnk[st.t2].v)
        | then |> if(rnk[@rem(st.t1 + st.k, st.n)].v == rnk[@rem(st.t2 + st.k, st.n)].v)
            | then |> std/grid:stored { nr[st.t2].v: nr[st.t1].v }
                |> if(i < st.n - 1)
                    | then |> nrn(i: i + 1): r -> r
                    | else |> ret0(): r -> r
            | else |> std/grid:stored { nr[st.t2].v: nr[st.t1].v + 1 }
                |> if(i < st.n - 1)
                    | then |> nrn(i: i + 1): r -> r
                    | else |> ret0(): r -> r
        | else |> std/grid:stored { nr[st.t2].v: nr[st.t1].v + 1 }
            |> if(i < st.n - 1)
                | then |> nrn(i: i + 1): r -> r
                | else |> ret0(): r -> r

// cpn — rank <- nr
pub tor cpn { i: i64 } -> i64
cpn = std/grid:stored { rnk[i].v: nr[i].v }
    |> if(i < st.n - 1)
        | then |> cpn(i: i + 1): r -> r
        | else |> ret0(): r -> r

// dbl — doubling loop: while k < n { radix-sort, re-rank, k *= 2 }
pub tor dbl { } -> i64
dbl = if(st.k < st.n)
| then |> rdx(): _
    |> nrn0(): _
    |> nrn(i: 1): _
    |> cpn(i: 0): _
    |> std/store:stored { st.k: st.k * 2 }
    |> dbl(): r -> r
| else -> 0

// emt — transformed[i] = data[sa[i]-1]; sa[i]==0 → data[n-1], oidx=i
pub tor emt { i: i64 } -> i64
emt = if(sa[i].v == 0)
| then |> std/grid:stored { out[i].b: dat[st.n - 1].b }
    |> std/store:stored { st.oidx: i }
    |> if(i < st.n - 1)
        | then |> emt(i: i + 1): r -> r
        | else |> ret0(): r -> r
| else |> std/grid:stored { out[i].b: dat[sa[i].v - 1].b }
    |> if(i < st.n - 1)
        | then |> emt(i: i + 1): r -> r
        | else |> ret0(): r -> r

// one full transform (runImpl)
pub tor bwt { } -> i64
bwt = zc(i: 0): _
    |> cntb(i: 0): _
    |> std/store:stored { st.acc: 0 }
    |> pfx(i: 0): _
    |> sct(i: 0): _
    |> cpy(i: 0): _
    |> rinit0(): _
    |> rinit(i: 1): _
    |> std/store:stored { st.k: 1 }
    |> dbl(): _
    |> emt(i: 0): _
    |> std/store:stored { st.res: st.res + st.n }
    |> ret0(): _ -> 0

// runl — 36 runs
pub tor runl { k: i64 } -> i64
runl = bwt(): _
    |> if(k < 35)
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
