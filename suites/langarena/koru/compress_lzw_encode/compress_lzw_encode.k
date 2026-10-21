// compress_lzw_encode — LangArena Compress::LZWEncode, run.js
// scored parameters (size=200006, iterations=85, warmup=17 → 102
// runs; each run re-encodes from scratch; result_val += encoded.len
// — oracle 425748 = 102 × 4174).
//
// The reference keeps a StringHashMap<byte-string -> code> seeded
// with all 256 single bytes; per position it materializes
// current+next into a scratch buffer and probes. This port mirrors
// that exactly: dict entries are byte copies in a pool grid (the
// arena dupes), each probe first copies the candidate slice into the
// pool tail (the temp_buf), hashing and comparing pool bytes; on a
// miss the scratch copy IS the inserted entry. Codes emit big-endian
// u16 pairs; dict never evicts; epoch tags reset the table per run.

import std/io
import std/grid
import std/store

std/grid:new(pat, size: 11) { b: 0[i64] }
std/grid:new(dat, size: 200006) { b: 0[i64] }
std/grid:new(pool, size: 4000000) { b: 0[i64] }
std/grid:new(tag, size: 8192) { v: 0[i64] }
std/grid:new(ks, size: 8192) { v: 0[i64] }
std/grid:new(kl, size: 8192) { v: 0[i64] }
std/grid:new(kc, size: 8192) { v: 0[i64] }
std/grid:new(out, size: 400100) { b: 0[i64] }
std/store:new(st) { res: 0[i64], n: 200006[i64], p: 0[i64], cs: 0[i64], cl: 0[i64], ep: 0[i64], pc: 0[i64], nc: 0[i64], hh: 0[i64], sl: 0[i64], sn: 0[i64], ql: 0[i64], t1: 0[i64], t2: 0[i64] }

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

// hsh — DJB2 over pool[po..po+l], 32-bit wrap
pub tor hsh { po: i64, l: i64 } -> i64
hsh = std/store:stored { st.hh: 5381 }
    |> hshl(po, l): r -> r

pub tor hshl { po: i64, l: i64 } -> i64
hshl = if(l > 0)
| then |> std/store:stored { st.hh: @rem(st.hh * 33 + pool[po].b, 4294967296) }
    |> hshl(po: po + 1, l: l - 1): r -> r
| else -> st.hh

// eqp — compare pool[a..a+l] vs pool[b..b+l]; produces 1/0
pub tor eqp { a: i64, b: i64, l: i64 } -> i64
eqp = if(l > 0)
| then |> if(pool[a].b == pool[b].b)
    | then |> eqp(a: a + 1, b: b + 1, l: l - 1): r -> r
    | else -> 0
| else -> 1

// lkp2 — linear probe from slot m; sets st.sl on exit; produces the
// code or -1. st.ql = query length, pool[st.pc..] = query bytes.
pub tor lkp2 { m: i64 } -> i64
lkp2 = if(tag[m].v == st.ep)
| then |> if(kl[m].v == st.ql)
    | then |> eqp(a: st.pc, b: ks[m].v, l: st.ql): eq
        |> if(eq == 1)
            | then |> std/store:stored { st.t2: kc[m].v }
                |> std/store:stored { st.sl: m }
                |> ret0(): _ -> st.t2
            | else |> lkp2(m: @rem(m + 1, 8192)): r -> r
    | else |> lkp2(m: @rem(m + 1, 8192)): r -> r
| else |> std/store:stored { st.sl: m }
    |> ret0(): _ -> -1

// lkup — hash + probe the pool-resident query at st.pc (len st.ql)
pub tor lkup { } -> i64
lkup = hsh(po: st.pc, l: st.ql): hh
    |> lkp2(m: @rem(hh, 8192)): r -> r

// cpd — copy dat[src..src+l] to pool[dst..]
pub tor cpd { src: i64, dst: i64, l: i64 } -> i64
cpd = if(l > 0)
| then |> std/grid:stored { pool[dst].b: dat[src].b }
    |> cpd(src: src + 1, dst: dst + 1, l: l - 1): r -> r
| else -> 0

// sed — seed the dict: pool[b]=b, probe-and-insert code b
pub tor sed { b: i64 } -> i64
sed = if(b < 256)
| then |> std/grid:stored { pool[b].b: b }
    |> std/store:stored { st.pc: b }
    |> std/store:stored { st.ql: 1 }
    |> lkup(): cd
    |> std/grid:stored { tag[st.sl].v: st.ep }
    |> std/grid:stored { ks[st.sl].v: b }
    |> std/grid:stored { kl[st.sl].v: 1 }
    |> std/grid:stored { kc[st.sl].v: b }
    |> sed(b: b + 1): r -> r
| else -> 0

// emit — append code as big-endian u16
pub tor emit { c: i64 } -> i64
emit = std/grid:stored { out[st.p].b: @rem(@divFloor(c, 256), 256) }
    |> std/grid:stored { out[st.p + 1].b: @rem(c, 256) }
    |> std/store:stored { st.p: st.p + 2 }
    |> ret0(): _ -> 0

// lzi — greedy scan: probe dat[cs..i+1] (materialized at pool[pc]);
// hit → extend; miss → emit current code, seal scratch as the new
// entry, restart at i.
pub tor lzi { i: i64 } -> i64
lzi = if(i < st.n)
| then |> std/store:stored { st.ql: i + 1 - st.cs }
    |> cpd(src: st.cs, dst: st.pc, l: st.ql): _
    |> lkup(): cd
    |> if(cd >= 0)
        | then |> std/store:stored { st.cl: st.ql }
            |> lzi(i: i + 1): r -> r
        | else |> std/store:stored { st.sn: st.sl }
            |> std/store:stored { st.ql: st.cl }
            |> cpd(src: st.cs, dst: st.pc + st.cl + 1, l: st.cl): _
            |> std/store:stored { st.t1: st.pc }
            |> std/store:stored { st.pc: st.pc + st.cl + 1 }
            |> lkup(): c2
            |> emit(c: c2): _
            |> std/grid:stored { tag[st.sn].v: st.ep }
            |> std/grid:stored { ks[st.sn].v: st.t1 }
            |> std/grid:stored { kl[st.sn].v: st.cl + 1 }
            |> std/grid:stored { kc[st.sn].v: st.nc }
            |> std/store:stored { st.nc: st.nc + 1 }
            |> std/store:stored { st.cs: i }
            |> std/store:stored { st.cl: 1 }
            |> lzi(i: i + 1): r -> r
| else -> 0

// run1 — one lzwEncode over the full input
pub tor run1 { } -> i64
run1 = std/store:stored { st.ep: st.ep + 1 }
    |> std/store:stored { st.pc: 0 }
    |> std/store:stored { st.nc: 256 }
    |> std/store:stored { st.p: 0 }
    |> std/store:stored { st.cs: 0 }
    |> std/store:stored { st.cl: 1 }
    |> sed(b: 0): _
    |> std/store:stored { st.pc: 1024 }
    |> lzi(i: 1): _
    |> std/store:stored { st.ql: st.cl }
    |> cpd(src: st.cs, dst: st.pc + 2048, l: st.cl): _
    |> std/store:stored { st.t1: st.pc }
    |> std/store:stored { st.pc: st.pc + 2048 }
    |> lkup(): c3
    |> emit(c: c3): _
    |> std/store:stored { st.res: st.res + st.p }
    |> ret0(): _ -> 0

// runl — 102 runs
pub tor runl { k: i64 } -> i64
runl = run1(): _
    |> if(k < 101)
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
