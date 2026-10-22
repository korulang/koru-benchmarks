// template_parse — LangArena Template::Parse, run.js
// scored parameters (count=50000, iterations=50, warmup=10 → 60
// runs). prepareBase builds a 6011872-byte document once (all
// deterministic — no RNG). Each run scans for {{key}}, finds the
// first "}}" after it, trims the inner text, looks it up in vars
// (150001 keys), splices the value or nothing; unmatched "{{" stays
// literal. result accumulates rendered.len; checksum adds
// checksumBytes(last render) — oracle 3554506535 =
// 60 × 4199375 + DJB2(3302544035).
//
// vars is a content-keyed open-address table: key bytes are copied
// into a pool grid, DJB2-32 hashed, linear-probed; values are
// (off,len) into the pool — the 22 name/city strings + "Template
// title". Lookup miss appends nothing (vars.get -> null path).
//
// Perf (wave 4):
// 1. txt/ren/pool are u8 cells (recipe 12: i64 cells were 8x the
//    byte traffic — grids were 48/34/24MB, now 6/4.3/3MB) + borrowed
//    slices ts/rs/ps for verbatim indexing in every hot loop.
// 2. Dict grids tag/kof/kln/vof/vln (5 x 4MB i64) collapsed to ONE
//    [layout(row)] grid kv {ko:u32, kl:u8, vi:u8} = 8B/row, 4MB total:
//    one cache line per probe instead of up to five. Empty slot <=>
//    kl == 0 (all keys are non-empty). Values are exactly the 23 nam
//    entries, so the row stores the nam index vi, not a (vo,vl) pair
//    — disclosed representation change, checksum-identical.
// 3. Loop state carried in tor params (recipe 6): rend carries
//    i/ls/rp; hshl/hshp/djf carry the hash accumulator; cpyl/cpyv
//    take rp and produce the new cursor (was a st.* store+load per
//    byte and per tag).
// 4. Copies are counted-for over borrowed slices (recipe 13): cpyl
//    (literal runs txt->ren) and cpyv (pool value->ren) are the
//    honest memcpy shape; the ckey scratch-copy of each key into
//    pool[2400000..] is gone — hshl hashes the key bytes in place
//    over txt and eqx compares txt[ka..] vs pool[ko..] directly.
// 5. Insert-time hash/probe (hshp/lkpp/eqpp) mirrors the render
//    side over pool — the two differ only in which slice the query
//    bytes live in.
// 6. Word-at-a-time "{{" scan (wave 5): pck packs txt into 8-byte
//    words tw once; wsw tests each word with a SWAR has-byte mask
//    (x - 0x0101..) & ~x & 0x8080.. after XOR with 0x7B7B.. ('{'),
//    and m & (m >> 8) flags adjacent '{' bytes. Only candidate words
//    fall back to byte-scanning (wsbyte); the tail runs byte-wise.
//    tw is sized ceil(txt capacity / 8) = 762500 — tlw is 751484
//    words at tl = 6011872.
//
// Faithfulness diffs (all checksum-identical, oracle 3554506535):
//   - Dict representation: 5 parallel i64 grids -> packed row kv.
//   - Values: per-key (vo,vl) into pool -> vi into 23-entry nam.
//   - Hash wrap: @rem(hh, 2^32) -> hh & 0xFFFFFFFF (same values,
//    hh never negative).
//   - Query copy eliminated; word-indexed pre-scan added (the
//    byte-scan order/positions are unchanged — verified against
//    wsbyte at every position during bring-up).
//
// Falsified during bring-up:
//   - "Word scan is drop-in once the mask constant is right": the
//    first landing used tw size 750240 (= an early tl estimate /8)
//    while pck wrote tlw = 751484 words — 1244 i64s (~10KB) past
//    the grid scribbled on kv, so ~977 kv slots around the CITY
//    cluster read as non-empty garbage; CITY16000+ lookups probed
//    to the first intact empty slot (1254) and missed (checksum
//    3050029780, len 4195467). Symptom looked like a hash/eqx bug;
//    it was a plain capacity bug — tw must cover ceil(tl/8), not
//    the initial document-size guess.

import std/io
import std/grid
import std/store

std/grid:new(txt, size: 6100000) { b: 0[u8] }
std/grid:new(ren, size: 4300000) { b: 0[u8] }
std/grid:new(pool, size: 3000000) { b: 0[u8] }
[layout(row)]std/grid:new(kv, size: 524288) { ko: 0[u32], kl: 0[u8], vi: 0[u8] }
std/grid:new(nam, size: 24) { o: 0[u32], l: 0[u8] }
std/grid:new(tw, size: 762500) { w: 0[i64] }
std/grid:slice(ts) { txt.b }
std/grid:slice(rs) { ren.b }
std/grid:slice(ps) { pool.b }
std/grid:slice(tws) { tw.w }
std/store:new(st) { res: 0[i64], n: 50000[i64], tp: 0[i64], tl: 0[i64], tlw: 0[i64], pc: 0[i64], qs: 0[i64], rp: 0[i64], t1: 0[i64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

pub tor idv { v: i64 } -> i64
idv -> v

// lit — append string bytes to txt at st.tp
pub tor lit { t: string } -> i64
lit = for(0..t.len)
    ! each k |> std/grid:stored { ts[@as(usize, @intCast(st.tp)) + k]: t[k] }
    | done
    |> std/store:stored { st.tp: st.tp + @as(i64, @intCast(t.len)) }: _ -> 0

// plit — append string bytes to pool at st.pc
pub tor plit { t: string } -> i64
plit = for(0..t.len)
    ! each k |> std/grid:stored { ps[@as(usize, @intCast(st.pc)) + k]: t[k] }
    | done
    |> std/store:stored { st.pc: st.pc + @as(i64, @intCast(t.len)) }: _ -> 0

// inum — decimal digits of v (>= 0) into txt
pub tor inum { v: i64 } -> i64
inum = if(v >= 10)
| then |> inum(v: @divTrunc(v, 10)): _
    |> std/grid:stored { ts[@as(usize, @intCast(st.tp))]: @as(u8, @intCast(@rem(v, 10) + 48)) }
    |> std/store:stored { st.tp: st.tp + 1 }
    |> ret0(): _ -> 0
| else |> std/grid:stored { ts[@as(usize, @intCast(st.tp))]: @as(u8, @intCast(v + 48)) }
    |> std/store:stored { st.tp: st.tp + 1 }
    |> ret0(): _ -> 0

// pnum — decimal digits of v into pool
pub tor pnum { v: i64 } -> i64
pnum = if(v >= 10)
| then |> pnum(v: @divTrunc(v, 10)): _
    |> std/grid:stored { ps[@as(usize, @intCast(st.pc))]: @as(u8, @intCast(@rem(v, 10) + 48)) }
    |> std/store:stored { st.pc: st.pc + 1 }
    |> ret0(): _ -> 0
| else |> std/grid:stored { ps[@as(usize, @intCast(st.pc))]: @as(u8, @intCast(v + 48)) }
    |> std/store:stored { st.pc: st.pc + 1 }
    |> ret0(): _ -> 0

// ---- dict: DJB2-32 hash + linear probe over kv rows ----
// hshl/hshp — hash ts[o..o+l) / ps[o..o+l); hh carried in a param
pub tor hshl { o: i64, l: i64, hh: i64 } -> i64
hshl = if(l > 0)
| then |> hshl(o: o + 1, l: l - 1, hh: (hh * 33 + @as(i64, ts[@as(usize, @intCast(o))])) & 4294967295): r -> r
| else -> hh

pub tor hshp { o: i64, l: i64, hh: i64 } -> i64
hshp = if(l > 0)
| then |> hshp(o: o + 1, l: l - 1, hh: (hh * 33 + @as(i64, ps[@as(usize, @intCast(o))])) & 4294967295): r -> r
| else -> hh

// eqx — compare txt[qa..qa+l) vs pool[kb..kb+l); produces 1/0
pub tor eqx { qa: i64, kb: i64, l: i64 } -> i64
eqx = if(l > 0)
| then |> if(ts[@as(usize, @intCast(qa))] == ps[@as(usize, @intCast(kb))])
    | then |> eqx(qa: qa + 1, kb: kb + 1, l: l - 1): r -> r
    | else -> 0
| else -> 1

// eqpp — compare pool[qa..qa+l) vs pool[kb..kb+l); produces 1/0
pub tor eqpp { qa: i64, kb: i64, l: i64 } -> i64
eqpp = if(l > 0)
| then |> if(ps[@as(usize, @intCast(qa))] == ps[@as(usize, @intCast(kb))])
    | then |> eqpp(qa: qa + 1, kb: kb + 1, l: l - 1): r -> r
    | else -> 0
| else -> 1

// lkpt — linear probe; query = txt[qa..qa+ql). Produces the slot
// index (hit or landing); caller distinguishes via kv[s].kl != 0.
pub tor lkpt { m: i64, qa: i64, ql: i64 } -> i64
lkpt = if(kv[m].kl != 0)
| then |> if(@as(i64, kv[m].kl) == ql)
    | then |> eqx(qa, kb: @as(i64, kv[m].ko), l: ql): eq
        |> if(eq == 1)
            | then -> m
            | else |> lkpt(m: @rem(m + 1, 524288), qa, ql): r -> r
    | else |> lkpt(m: @rem(m + 1, 524288), qa, ql): r -> r
| else -> m

// lkpp — linear probe; query = pool[qa..qa+ql)
pub tor lkpp { m: i64, qa: i64, ql: i64 } -> i64
lkpp = if(kv[m].kl != 0)
| then |> if(@as(i64, kv[m].kl) == ql)
    | then |> eqpp(qa, kb: @as(i64, kv[m].ko), l: ql): eq
        |> if(eq == 1)
            | then -> m
            | else |> lkpp(m: @rem(m + 1, 524288), qa, ql): r -> r
    | else |> lkpp(m: @rem(m + 1, 524288), qa, ql): r -> r
| else -> m

// avar — insert key pool[q0..st.pc) -> nam[e]
pub tor avar { q0: i64, e: i64 } -> i64
avar = hshp(o: q0, l: st.pc - q0, hh: 5381): hh
    |> lkpp(m: @rem(hh, 524288), qa: q0, ql: st.pc - q0): s2
    |> std/grid:stored { kv[s2].ko: @as(u32, @intCast(q0)), kv[s2].kl: @as(u8, @intCast(st.pc - q0)), kv[s2].vi: @as(u8, @intCast(e)) }
    |> ret0(): _ -> 0

// stn — record a name literal at nam[e], bytes into pool
pub tor stn { e: i64, t: string } -> i64
stn = std/grid:stored { nam[e].o: @as(u32, @intCast(st.pc)), nam[e].l: @as(u8, @intCast(t.len)) }
    |> plit(t): r -> r

// kv1 — vars.put("TITLE", "Template title")
pub tor kv1 { } -> i64
kv1 = stn(e: 22, t: "Template title"): _
    |> std/store:stored { st.qs: st.pc }
    |> plit(t: "TITLE"): _
    |> avar(q0: st.qs, e: 22): r -> r

// kvi — FIRST_NAME{i}/LAST_NAME{i}/CITY{i} key+value rows
pub tor kvi { i: i64 } -> i64
kvi = if(i < st.n)
| then |> std/store:stored { st.qs: st.pc }
    |> plit(t: "FIRST_NAME"): _
    |> pnum(v: i): _
    |> avar(q0: st.qs, e: @rem(i, 8)): _
    |> std/store:stored { st.qs: st.pc }
    |> plit(t: "LAST_NAME"): _
    |> pnum(v: i): _
    |> avar(q0: st.qs, e: @rem(i, 8) + 8): _
    |> std/store:stored { st.qs: st.pc }
    |> plit(t: "CITY"): _
    |> pnum(v: i): _
    |> avar(q0: st.qs, e: @rem(i, 6) + 16): _
    |> kvi(i: i + 1): r -> r
| else -> 0

// ---- text build (prepareBase) ----
pub tor growr { i: i64 } -> i64
growr = lit(t: "<tr>"): _
    |> lit(t: "<td>{{ FIRST_NAME"): _
    |> inum(v: i): _
    |> lit(t: " }}</td>"): _
    |> lit(t: "<td>{{LAST_NAME"): _
    |> inum(v: i): _
    |> lit(t: "}}</td>"): _
    |> lit(t: "<td>{{  CITY"): _
    |> inum(v: i): _
    |> lit(t: "  }}</td>"): _
    |> lit(t: "<td>{balance: "): _
    |> inum(v: @rem(i, 100)): _
    |> lit(t: "}</td>"): _
    |> lit(t: "</tr>\n"): _
    |> ret0(): _ -> 0

pub tor grow { i: i64 } -> i64
grow = if(i < st.n)
| then |> if(@rem(i, 3) == 0)
    | then |> lit(t: "<!-- {comment} -->"): _
        |> growr(i): _
        |> grow(i: i + 1): r -> r
    | else |> growr(i): _
        |> grow(i: i + 1): r -> r
| else -> 0

pub tor tbuild { } -> i64
tbuild = lit(t: "<html><body>"): _
    |> lit(t: "<h1>{{TITLE}}</h1>"): _
    |> lit(t: "<p>"): _
    |> lit(t: "Lorem {ipsum} dolor {sit} amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore {et} dolore magna aliqua. "): _
    |> lit(t: "</p>"): _
    |> lit(t: "<table>"): _
    |> grow(i: 0): _
    |> lit(t: "</table>"): _
    |> lit(t: "</body></html>"): _
    |> std/store:stored { st.tl: st.tp }
    |> std/store:stored { st.tlw: @divTrunc(st.tp, 8) }
    |> pck(): _
    |> ret0(): _ -> 0

// pck — pack txt[0..tlw*8) into u64 words for the render scan
// (little-endian: byte k*8+j goes to word byte j). Text bytes past
// the last full word are covered by the byte-scan tail of wsw.
pub tor pck { } -> i64
pck = for(0..@as(usize, @intCast(st.tlw)))
    ! each k |> std/grid:stored { tws[k]: @as(i64, ts[k * 8]) | (@as(i64, ts[k * 8 + 1]) << 8) | (@as(i64, ts[k * 8 + 2]) << 16) | (@as(i64, ts[k * 8 + 3]) << 24) | (@as(i64, ts[k * 8 + 4]) << 32) | (@as(i64, ts[k * 8 + 5]) << 40) | (@as(i64, ts[k * 8 + 6]) << 48) | (@as(i64, ts[k * 8 + 7]) << 56) }
    | done
    |> ret0(): _ -> 0

// ---- render ----
// cpyl — copy txt[a..b) to ren at rp; produces the new rp
pub tor cpyl { a: i64, b: i64, rp: i64 } -> i64
cpyl = for(0..@as(usize, @intCast(b - a)))
    ! each k |> std/grid:stored { rs[@as(usize, @intCast(rp)) + k]: ts[@as(usize, @intCast(a)) + k] }
    | done
    |> ret0(): _ -> rp + (b - a)

// cpyv — copy pool[off..off+vl) to ren at rp; produces the new rp
pub tor cpyv { off: i64, vl: i64, rp: i64 } -> i64
cpyv = for(0..@as(usize, @intCast(vl)))
    ! each k |> std/grid:stored { rs[@as(usize, @intCast(rp)) + k]: ps[@as(usize, @intCast(off)) + k] }
    | done
    |> ret0(): _ -> rp + vl

// jse — first "}}" at-or-after j; produces j, st.t1 = found
pub tor jse { j: i64 } -> i64
jse = if(j + 1 < st.tl)
| then |> if(ts[@as(usize, @intCast(j))] == 125)
    | then |> if(ts[@as(usize, @intCast(j + 1))] == 125)
        | then |> std/store:stored { st.t1: 1 }
            |> ret0(): _ -> j
        | else |> jse(j: j + 1): r -> r
    | else |> jse(j: j + 1): r -> r
| else |> std/store:stored { st.t1: 0 }
    |> ret0(): _ -> 0

// trl/trr — trim ASCII spaces off txt bounds
pub tor trl { a: i64, b: i64 } -> i64
trl = if(a < b)
| then |> if(ts[@as(usize, @intCast(a))] == 32)
    | then |> trl(a: a + 1, b): r -> r
    | else -> a
| else -> a

pub tor trr { a: i64, b: i64 } -> i64
trr = if(b > a)
| then |> if(ts[@as(usize, @intCast(b - 1))] == 32)
    | then |> trr(a, b: b - 1): r -> r
    | else -> b
| else -> b

// wsbyte — first "{{" pair-start in ts[i..lim); produces it or -1
pub tor wsbyte { i: i64, lim: i64 } -> i64
wsbyte = if(i < lim)
| then |> if(ts[@as(usize, @intCast(i))] == 123)
    | then |> if(ts[@as(usize, @intCast(i + 1))] == 123)
        | then -> i
        | else |> wsbyte(i: i + 1, lim): r -> r
    | else |> wsbyte(i: i + 1, lim): r -> r
| else -> -1

// wswm — one packed word: x = tws[wi] ^ 0x7B7B..; m has 0x80 at
// every '{' byte (SWAR haszero). m & (m >> 8) != 0 flags a "{{"
// pair-start inside the word — arithmetic >> also flags a '{' in
// byte 7, which wsbyte resolves correctly against the next word's
// first byte (and the tail guard caps it at tl-1).
pub tor wswm { wi: i64, x: i64 } -> i64
wswm = idv(v: (x -% 72340172838076673) & (x ^ -1) & -9187201950435737472): m
    |> if((m & (m >> 8)) != 0)
        | then |> wsbyte(i: wi * 8, lim: @min(wi * 8 + 8, st.tl - 1)): f
            |> if(f >= 0)
                | then -> f
                | else |> wsw(wi: wi + 1): r -> r
        | else |> wsw(wi: wi + 1): r -> r

// wsw — whole-word scan for the next "{{" pair-start
pub tor wsw { wi: i64 } -> i64
wsw = if(wi < st.tlw)
| then |> wswm(wi, x: tws[@as(usize, @intCast(wi))] ^ 8897841259083430779): r -> r
| else |> wsbyte(i: wi * 8, lim: st.tl - 1): f
    |> if(f >= 0)
        | then -> f
        | else -> st.tl

// ws — first "{{" pair-start at byte >= i; produces pos or st.tl
pub tor ws { i: i64 } -> i64
ws = if(i + 1 < st.tl)
| then |> wsbyte(i, lim: @min(i - @rem(i, 8) + 8, st.tl - 1)): f
    |> if(f >= 0)
        | then -> f
        | else |> wsw(wi: @divTrunc(i, 8) + 1): r -> r
| else -> st.tl

// rend — the scan. i = cursor, ls = literal-run start, rp = render
// write cursor; all register-carried. Produces the final rp.
pub tor rend { i: i64, ls: i64, rp: i64 } -> i64
rend = ws(i): j0
|> if(j0 < st.tl)
    | then |> jse(j: j0 + 2): jj
        |> if(st.t1 == 1)
            | then |> cpyl(a: ls, b: j0, rp): rp1
                |> trl(a: j0 + 2, b: jj): ka
                |> trr(a: ka, b: jj): kb
                |> if(kb > ka)
                    | then |> hshl(o: ka, l: kb - ka, hh: 5381): hh
                        |> lkpt(m: @rem(hh, 524288), qa: ka, ql: kb - ka): s2
                        |> if(kv[s2].kl != 0)
                            | then |> cpyv(off: @as(i64, nam[@as(i64, kv[s2].vi)].o), vl: @as(i64, nam[@as(i64, kv[s2].vi)].l), rp: rp1): rp2
                                |> rend(i: jj + 2, ls: jj + 2, rp: rp2): r -> r
                            | else |> rend(i: jj + 2, ls: jj + 2, rp: rp1): r -> r
                    | else |> rend(i: jj + 2, ls: jj + 2, rp: rp1): r -> r
            | else |> rend(i: j0 + 1, ls, rp): r -> r
    | else |> cpyl(a: ls, b: st.tl, rp): r -> r

// run1 — one runImpl; produces via st.res/st.rp side effects
pub tor run1 { } -> i64
run1 = rend(i: 0, ls: 0, rp: 0): rpf
    |> std/store:stored { st.rp: rpf }
    |> std/store:stored { st.res: st.res + rpf }
    |> ret0(): _ -> 0

// runl — 60 runs
pub tor runl { k: i64 } -> i64
runl = run1(): _
    |> if(k < 59)
        | then |> runl(k: k + 1): r -> r
        | else |> ret0(): r -> r

// djf — checksumBytes(ren[0..st.rp)) once; hh carried in a param
pub tor djf { i: i64, hh: i64 } -> i64
djf = if(i < st.rp)
| then |> djf(i: i + 1, hh: (hh * 33 + @as(i64, rs[@as(usize, @intCast(i))])) & 4294967295): r -> r
| else |> std/store:stored { st.res: st.res + hh }
    |> ret0(): r -> r

// ---- driver ----
ret0(): _
|> std/store:stored { st.pc: 0 }
|> stn(e: 0, t: "John"): _
|> stn(e: 1, t: "Jane"): _
|> stn(e: 2, t: "Bob"): _
|> stn(e: 3, t: "Alice"): _
|> stn(e: 4, t: "Charlie"): _
|> stn(e: 5, t: "Diana"): _
|> stn(e: 6, t: "Sarah"): _
|> stn(e: 7, t: "Mike"): _
|> stn(e: 8, t: "Smith"): _
|> stn(e: 9, t: "Johnson"): _
|> stn(e: 10, t: "Brown"): _
|> stn(e: 11, t: "Taylor"): _
|> stn(e: 12, t: "Wilson"): _
|> stn(e: 13, t: "Davis"): _
|> stn(e: 14, t: "Miller"): _
|> stn(e: 15, t: "Jones"): _
|> stn(e: 16, t: "New York"): _
|> stn(e: 17, t: "Los Angeles"): _
|> stn(e: 18, t: "Chicago"): _
|> stn(e: 19, t: "Houston"): _
|> stn(e: 20, t: "Phoenix"): _
|> stn(e: 21, t: "San Francisco"): _
|> kv1(): _
|> kvi(i: 0): _
|> tbuild(): _
|> runl(k: 0): _
|> djf(i: 0, hh: 5381): _
|> std/io:print.ln("{{ st.res:d }}")
