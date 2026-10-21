// template_regex — LangArena Template::Regex, run.js
// scored parameters (count=50000, iterations=50, warmup=10 → 60
// runs). The reference drives PCRE2-JIT pattern "{{(.*?)}}" as a
// find-all loop: leftmost match from start_offset, copy literal gap
// text[last_pos..match_start], substitute vars[trim(capture)] or
// nothing, continue from match_end. A "{{" with no later "}}" fails
// at that offset and the engine retries one byte on. (Lazy ".*?"
// stops at the first "}}", so this is exactly find-{{ then
// first-}}.) result accumulates rendered.len; checksum adds
// checksumBytes(last render) — oracle 3554506535 =
// 60 × 4199375 + DJB2(3302544035).

import std/io
import std/grid
import std/store

std/grid:new(txt, size: 6100000) { b: 0[i64] }
std/grid:new(ren, size: 4300000) { b: 0[i64] }
std/grid:new(pool, size: 3000000) { b: 0[i64] }
std/grid:new(tag, size: 524288) { v: 0[i64] }
std/grid:new(kof, size: 524288) { v: 0[i64] }
std/grid:new(kln, size: 524288) { v: 0[i64] }
std/grid:new(vof, size: 524288) { v: 0[i64] }
std/grid:new(vln, size: 524288) { v: 0[i64] }
std/grid:new(nam, size: 24) { o: 0[i64], l: 0[i64] }
std/store:new(st) { res: 0[i64], n: 50000[i64], tp: 0[i64], tl: 0[i64], rp: 0[i64], pc: 0[i64], ls: 0[i64], hh: 0[i64], sl: 0[i64], ql: 0[i64], qs: 0[i64], t1: 0[i64], t2: 0[i64], t3: 0[i64], ms: 0[i64], me: 0[i64], so: 0[i64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// lit — append string bytes to txt at st.tp
pub tor lit { t: string } -> i64
lit = for(0..t.len)
    ! each k |> std/grid:stored { txt[st.tp].b: t[k] }
        |> std/store:stored { st.tp: st.tp + 1 }
    | done
    |> ret0(): _ -> 0

// plit — append string bytes to pool at st.pc
pub tor plit { t: string } -> i64
plit = for(0..t.len)
    ! each k |> std/grid:stored { pool[st.pc].b: t[k] }
        |> std/store:stored { st.pc: st.pc + 1 }
    | done
    |> ret0(): _ -> 0

// inum — decimal digits of v (>= 0) into txt
pub tor inum { v: i64 } -> i64
inum = if(v >= 10)
| then |> inum(v: @divTrunc(v, 10)): _
    |> std/grid:stored { txt[st.tp].b: @rem(v, 10) + 48 }
    |> std/store:stored { st.tp: st.tp + 1 }
    |> ret0(): _ -> 0
| else |> std/grid:stored { txt[st.tp].b: v + 48 }
    |> std/store:stored { st.tp: st.tp + 1 }
    |> ret0(): _ -> 0

// pnum — decimal digits of v into pool
pub tor pnum { v: i64 } -> i64
pnum = if(v >= 10)
| then |> pnum(v: @divTrunc(v, 10)): _
    |> std/grid:stored { pool[st.pc].b: @rem(v, 10) + 48 }
    |> std/store:stored { st.pc: st.pc + 1 }
    |> ret0(): _ -> 0
| else |> std/grid:stored { pool[st.pc].b: v + 48 }
    |> std/store:stored { st.pc: st.pc + 1 }
    |> ret0(): _ -> 0

// ---- dict: hash+probe over pool-resident queries ----
pub tor hsh { po: i64, l: i64 } -> i64
hsh = std/store:stored { st.hh: 5381 }
    |> hshl(po, l): r -> r

pub tor hshl { po: i64, l: i64 } -> i64
hshl = if(l > 0)
| then |> std/store:stored { st.hh: @rem(st.hh * 33 + pool[po].b, 4294967296) }
    |> hshl(po: po + 1, l: l - 1): r -> r
| else -> st.hh

pub tor eqp { a: i64, b: i64, l: i64 } -> i64
eqp = if(l > 0)
| then |> if(pool[a].b == pool[b].b)
    | then |> eqp(a: a + 1, b: b + 1, l: l - 1): r -> r
    | else -> 0
| else -> 1

// lkp2 — linear probe; query = pool[st.qs .. st.qs + st.ql];
// produces the slot index (hit or landing); st.sl also set.
pub tor lkp2 { m: i64 } -> i64
lkp2 = if(tag[m].v == 1)
| then |> if(kln[m].v == st.ql)
    | then |> eqp(a: st.qs, b: kof[m].v, l: st.ql): eq
        |> if(eq == 1)
            | then |> std/store:stored { st.sl: m }
                |> ret0(): _ -> st.sl
            | else |> lkp2(m: @rem(m + 1, 524288)): r -> r
    | else |> lkp2(m: @rem(m + 1, 524288)): r -> r
| else |> std/store:stored { st.sl: m }
    |> ret0(): _ -> st.sl

pub tor lkup { } -> i64
lkup = hsh(po: st.qs, l: st.ql): hh
    |> lkp2(m: @rem(hh, 524288)): r -> r

// avar — insert key pool[q0..st.pc) -> value (vo,vl)
pub tor avar { q0: i64, vo: i64, vl: i64 } -> i64
avar = std/store:stored { st.qs: q0 }
    |> std/store:stored { st.ql: st.pc - q0 }
    |> lkup(): _
    |> std/grid:stored { tag[st.sl].v: 1 }
    |> std/grid:stored { kof[st.sl].v: q0 }
    |> std/grid:stored { kln[st.sl].v: st.ql }
    |> std/grid:stored { vof[st.sl].v: vo }
    |> std/grid:stored { vln[st.sl].v: vl }
    |> ret0(): _ -> 0

// stn — record a name literal at nam[e], bytes into pool
pub tor stn { e: i64, t: string } -> i64
stn = std/grid:stored { nam[e].o: st.pc }
    |> std/grid:stored { nam[e].l: @as(i64, @intCast(t.len)) }
    |> plit(t): r -> r

// kv1 — vars.put("TITLE", "Template title")
pub tor kv1 { } -> i64
kv1 = stn(e: 22, t: "Template title"): _
    |> std/store:stored { st.qs: st.pc }
    |> plit(t: "TITLE"): _
    |> avar(q0: st.qs, vo: nam[22].o, vl: nam[22].l): r -> r

// kvi — FIRST_NAME{i}/LAST_NAME{i}/CITY{i} key+value rows
pub tor kvi { i: i64 } -> i64
kvi = if(i < st.n)
| then |> std/store:stored { st.qs: st.pc }
    |> plit(t: "FIRST_NAME"): _
    |> pnum(v: i): _
    |> avar(q0: st.qs, vo: nam[@rem(i, 8)].o, vl: nam[@rem(i, 8)].l): _
    |> std/store:stored { st.qs: st.pc }
    |> plit(t: "LAST_NAME"): _
    |> pnum(v: i): _
    |> avar(q0: st.qs, vo: nam[@rem(i, 8) + 8].o, vl: nam[@rem(i, 8) + 8].l): _
    |> std/store:stored { st.qs: st.pc }
    |> plit(t: "CITY"): _
    |> pnum(v: i): _
    |> avar(q0: st.qs, vo: nam[@rem(i, 6) + 16].o, vl: nam[@rem(i, 6) + 16].l): _
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
    |> ret0(): _ -> 0

// ---- render ----
// cpyl — copy txt[a..b) to ren at st.rp
pub tor cpyl { a: i64, b: i64 } -> i64
cpyl = if(a < b)
| then |> std/grid:stored { ren[st.rp].b: txt[a].b }
    |> std/store:stored { st.rp: st.rp + 1 }
    |> cpyl(a: a + 1, b): r -> r
| else -> 0

// cpyv — copy pool[vo..vo+vl) to ren
pub tor cpyv { vo: i64, vl: i64 } -> i64
cpyv = if(vl > 0)
| then |> std/grid:stored { ren[st.rp].b: pool[vo].b }
    |> std/store:stored { st.rp: st.rp + 1 }
    |> cpyv(vo: vo + 1, vl: vl - 1): r -> r
| else -> 0

// ckey — copy txt[a..b) to pool scratch at 2400000; st.ql = len
pub tor ckey { a: i64, b: i64 } -> i64
ckey = if(a < b)
| then |> std/grid:stored { pool[2400000 + st.t3].b: txt[a].b }
    |> std/store:stored { st.t3: st.t3 + 1 }
    |> ckey(a: a + 1, b): r -> r
| else |> std/store:stored { st.ql: st.t3 }
    |> std/store:stored { st.qs: 2400000 }
    |> ret0(): r -> r

// jse — first "}}" at-or-after j; produces j, st.t1 = found
pub tor jse { j: i64 } -> i64
jse = if(j + 1 < st.tl)
| then |> if(txt[j].b == 125)
    | then |> if(txt[j + 1].b == 125)
        | then |> std/store:stored { st.t1: 1 }
            |> ret0(): _ -> j
        | else |> jse(j: j + 1): r -> r
    | else |> jse(j: j + 1): r -> r
| else |> std/store:stored { st.t1: 0 }
    |> ret0(): _ -> 0

// trl/trr — trim ASCII spaces off txt bounds
pub tor trl { a: i64, b: i64 } -> i64
trl = if(a < b)
| then |> if(txt[a].b == 32)
    | then |> trl(a: a + 1, b): r -> r
    | else -> a
| else -> a

pub tor trr { a: i64, b: i64 } -> i64
trr = if(b > a)
| then |> if(txt[b - 1].b == 32)
    | then |> trr(a, b: b - 1): r -> r
    | else -> b
| else -> b

// mfind — pcre2_jit_match equivalent: leftmost "{{ ... }}" from
// offset i; lazy ".*?" = first "}}" after "{{"; a "{{" with no
// close retries from i+1 (engine behavior). Produces 1 + st.ms/me,
// or 0.
pub tor mfind { i: i64 } -> i64
mfind = if(i + 1 < st.tl)
| then |> if(txt[i].b == 123)
    | then |> if(txt[i + 1].b == 123)
        | then |> jse(j: i + 2): jj
            |> if(st.t1 == 1)
                | then |> std/store:stored { st.ms: i }
                    |> std/store:stored { st.me: jj + 2 }
                    |> ret0(): _ -> 1
                | else |> mfind(i: i + 1): r -> r
        | else |> mfind(i: i + 1): r -> r
    | else |> mfind(i: i + 1): r -> r
| else -> 0

// rend — the match/splice loop; st.ls = last_pos, st.so = start_off
pub tor rend { } -> i64
rend = mfind(i: st.so): m
    |> if(m == 1)
        | then |> cpyl(a: st.ls, b: st.ms): _
            |> trl(a: st.ms + 2, b: st.me - 2): ka
            |> trr(a: ka, b: st.me - 2): kb
            |> std/store:stored { st.t3: 0 }
            |> ckey(a: ka, b: kb): _
            |> if(st.ql > 0)
                | then |> lkup(): s2
                    |> if(tag[s2].v == 1)
                        | then |> cpyv(vo: vof[s2].v, vl: vln[s2].v): _
                            |> std/store:stored { st.ls: st.me }
                            |> std/store:stored { st.so: st.me }
                            |> rend(): r -> r
                        | else |> std/store:stored { st.ls: st.me }
                            |> std/store:stored { st.so: st.me }
                            |> rend(): r -> r
                | else |> std/store:stored { st.ls: st.me }
                    |> std/store:stored { st.so: st.me }
                    |> rend(): r -> r
        | else |> ret0(): r -> r

// run1 — one runImpl
pub tor run1 { } -> i64
run1 = std/store:stored { st.rp: 0 }
    |> std/store:stored { st.ls: 0 }
    |> std/store:stored { st.so: 0 }
    |> rend(): _
    |> cpyl(a: st.ls, b: st.tl): _
    |> std/store:stored { st.res: st.res + st.rp }
    |> ret0(): _ -> 0

// runl — 60 runs
pub tor runl { k: i64 } -> i64
runl = run1(): _
    |> if(k < 59)
        | then |> runl(k: k + 1): r -> r
        | else |> ret0(): r -> r

// djf — checksumBytes(ren[0..rp)) once
pub tor djf { i: i64 } -> i64
djf = if(i < st.rp)
| then |> std/store:stored { st.hh: @rem(st.hh * 33 + ren[i].b, 4294967296) }
    |> djf(i: i + 1): r -> r
| else |> std/store:stored { st.res: st.res + st.hh }
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
|> std/store:stored { st.hh: 5381 }
|> djf(i: 0): _
|> std/io:print.ln("{{ st.res:d }}")
