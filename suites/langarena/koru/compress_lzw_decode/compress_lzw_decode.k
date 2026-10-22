// compress_lzw_decode — LangArena Compress::LZWDecode, run.js
// scored parameters (size=1000007, iterations=1600, warmup=320 →
// 1920 runs). prepare runs lzwEncode once; each run rebuilds the
// decode dict (pool slices: offset+len per code) and walks the u16
// code stream, appending each string to `dec`; the current_code ==
// next_code case synthesizes previous_str + previous_str[0].
// result_val += decoded.len; +100000 on byte-exact roundtrip —
// oracle 1920113440 = 1920 × 1000007 + 100000.
//
// Decode needs no hashing: dict is a code-indexed table, entries
// are (pool offset, len) pairs — same "copied bytes" model as the
// encoder's arena.
//
// Perf (2026-10-22): byte grids are u8 (i64 cells were 8x the
// copy traffic — the single biggest deficit), emt/c2p are
// counted-for copies over borrowed pl/dl slices (verbatim
// indexing, ds bumped per string not per byte). Encoded stream
// is 9358B = 4679 codes, so per-code st.* traffic is trivial;
// the byte volume is the task. 1.70s -> 0.59s, checksum
// 1920113440 verified.

import std/io
import std/grid
import std/store

std/grid:new(pat, size: 11) { b: 0[u8] }
std/grid:new(dat, size: 1000007) { b: 0[u8] }
std/grid:new(pool, size: 4000000) { b: 0[u8] }
std/grid:new(tag, size: 8192) { v: 0[i64] }
std/grid:new(ks, size: 8192) { v: 0[i64] }
std/grid:new(kl, size: 8192) { v: 0[i64] }
std/grid:new(kc, size: 8192) { v: 0[i64] }
std/grid:new(out, size: 400100) { b: 0[u8] }
std/grid:new(dec, size: 1000007) { b: 0[u8] }
std/grid:new(dd, size: 100000) { off: 0[i64], ln: 0[i64] }
std/grid:slice(pl) { pool.b }
std/grid:slice(dl) { dec.b }
std/store:new(st) { res: 0[i64], n: 1000007[i64], p: 0[i64], cs: 0[i64], cl: 0[i64], ep: 0[i64], pc: 0[i64], nc: 0[i64], hh: 0[i64], sl: 0[i64], sn: 0[i64], ql: 0[i64], t1: 0[i64], t2: 0[i64], t3: 0[i64], sym: 0[i64], ds: 0[i64], el: 0[i64], pos: 0[i64], prc: 0[i64], prs: 0[i64], prl: 0[i64], ok: 0[i64] }

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
| then |> std/store:stored { st.hh: @rem(st.hh * 33 + @as(i64, pool[po].b), 4294967296) }
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
| then |> std/grid:stored { pool[b].b: @as(u8, @intCast(b)) }
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
emit = std/grid:stored { out[st.p].b: @as(u8, @intCast(@rem(@divFloor(c, 256), 256))) }
    |> std/grid:stored { out[st.p + 1].b: @as(u8, @intCast(@rem(c, 256))) }
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

// enc1 — the one prepare-time lzwEncode
pub tor enc1 { } -> i64
enc1 = std/store:stored { st.ep: st.ep + 1 }
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
    |> std/store:stored { st.el: st.p }
    |> ret0(): _ -> 0

// ---- decode ----
// dsd — seed dict codes 0..255: dd[b] = (pool_off=b, len=1)
pub tor dsd { b: i64 } -> i64
dsd = if(b < 256)
| then |> std/grid:stored { pool[b].b: @as(u8, @intCast(b)) }
    |> std/grid:stored { dd[b].off: b }
    |> std/grid:stored { dd[b].ln: 1 }
    |> dsd(b: b + 1): r -> r
| else -> 0

// emt — append pool[off..off+len] to dec at st.ds. Borrowed-slice
// counted-for copy: pl/dl index verbatim (no floor checks), ds bumped
// once per string, not once per byte.
pub tor emt { off: i64, l: i64 } -> i64
emt = for(0..@as(usize, @intCast(l)))
    ! each k |> std/grid:stored { dl[@as(usize, @intCast(st.ds)) + k]: pl[@as(usize, @intCast(off)) + k] }
    |> std/store:stored { st.ds: st.ds + l }
    |> ret0(): _ -> 0

// c2p — copy pool[src..src+l] to pool[dst..] (entry materialization)
pub tor c2p { src: i64, dst: i64, l: i64 } -> i64
c2p = for(0..@as(usize, @intCast(l)))
    ! each k |> std/grid:stored { pl[@as(usize, @intCast(dst)) + k]: pl[@as(usize, @intCast(src)) + k] }
    |> ret0(): _ -> 0

// dins — dict append: dd[nc] = prev_str + pool[st.t2]
// st.prs/st.prl = prev_str slice; st.t2 = first byte of current_str
pub tor dins { } -> i64
dins = std/grid:stored { dd[st.nc].off: st.pc }
    |> std/grid:stored { dd[st.nc].ln: st.prl + 1 }
    |> c2p(src: st.prs, dst: st.pc, l: st.prl): _
    |> std/grid:stored { pool[st.pc + st.prl].b: @as(u8, @intCast(st.t2)) }
    |> std/store:stored { st.pc: st.pc + st.prl + 1 }
    |> std/store:stored { st.nc: st.nc + 1 }
    |> ret0(): _ -> 0

// lzd — code-stream walk. st.pos cursor, st.prs/st.prl prev_str.
// Three cases per code: < nc -> table hit; == nc -> synth
// prev_str+prev_str[0]; else -> stop (InvalidCode).
pub tor lzd { } -> i64
lzd = if(st.pos < st.el)
| then |> std/store:stored { st.t1: @as(i64, out[st.pos].b) * 256 + @as(i64, out[st.pos + 1].b) }
    |> std/store:stored { st.pos: st.pos + 2 }
    |> if(st.t1 < st.nc)
        | then |> std/store:stored { st.t2: @as(i64, pool[dd[st.t1].off].b) }
            |> emt(off: dd[st.t1].off, l: dd[st.t1].ln): _
            |> dins(): _
            |> std/store:stored { st.prs: dd[st.t1].off }
            |> std/store:stored { st.prl: dd[st.t1].ln }
            |> lzd(): r -> r
        | else |> if(st.t1 == st.nc)
            | then |> std/store:stored { st.t2: @as(i64, pool[st.prs].b) }
                |> std/store:stored { st.t3: st.pc }
                |> std/store:stored { st.sym: st.prl + 1 }
                |> c2p(src: st.prs, dst: st.pc, l: st.prl): _
                |> std/grid:stored { pool[st.t3 + st.prl].b: @as(u8, @intCast(st.t2)) }
                |> std/store:stored { st.pc: st.pc + st.sym }
                |> emt(off: st.t3, l: st.sym): _
                |> dins(): _
                |> std/store:stored { st.prs: st.t3 }
                |> std/store:stored { st.prl: st.sym }
                |> lzd(): r -> r
            | else |> ret0(): r -> r
| else -> 0

// run1 — one lzwDecode over the encoded stream
pub tor run1 { } -> i64
run1 = std/store:stored { st.pc: 256 }
    |> std/store:stored { st.nc: 256 }
    |> std/store:stored { st.ds: 0 }
    |> dsd(b: 0): _
    |> std/store:stored { st.t1: @as(i64, out[0].b) * 256 + @as(i64, out[1].b) }
    |> std/store:stored { st.pos: 2 }
    |> emt(off: dd[st.t1].off, l: dd[st.t1].ln): _
    |> std/store:stored { st.prs: dd[st.t1].off }
    |> std/store:stored { st.prl: dd[st.t1].ln }
    |> lzd(): _
    |> std/store:stored { st.res: st.res + st.ds }
    |> ret0(): _ -> 0

// runl — 1920 runs
pub tor runl { k: i64 } -> i64
runl = run1(): _
    |> if(k < 1919)
        | then |> runl(k: k + 1): r -> r
        | else |> ret0(): r -> r

// vfy — checksum's mem.eql(test_data, decoded)
pub tor vfy { i: i64 } -> i64
vfy = if(i < st.n)
| then |> if(dat[i].b == dec[i].b)
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
