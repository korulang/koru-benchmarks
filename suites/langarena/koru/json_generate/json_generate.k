// json_generate — LangArena Json::Generate, run.js scored parameters
// (coords=20000, iterations=100, warmup=20 -> 120 serialize runs over
// one generated dataset; checksum = result_val, incremented once per
// run whose emitted text starts with `{"coordinates":` and is >=15
// bytes — i.e. the run count, 120, provided every run produces the
// full document).
//
// The generated text is load-bearing upstream of Json::ParseDom /
// Json::ParseMapping, so it must be byte-exact Zig reference output:
// `{"x":{d:.8},"y":{d:.8},"z":{d:.8},"name":"{d:.7} {d}",...}` —
// floats formatted via std/fmt:ln, whose {{ v:d:.8 }} spec passes
// through to Zig's own std.fmt, giving byte-exact rounding for free.
// fmt:ln's .text borrows per-call-site scratch (@scoped) — cpy confines
// the borrow to a tor param, zero allocation. Per-entry data lives in
// grids: gx/gy/gz f64, names as a fixed 32-byte stride slab + nl lens.
// (Verified byte-exact: smoke doc hash + length match the independent
// oracle exactly.)
//
// Draw order (Helper): x,y,z = nextFloat(1.0) then name =
// nextFloat(1.0) + nextInt(10000). Zig's nextInt is
// floor(last*max/IM) (multiply-first) vs Crystal's floor(last/IM*max)
// — brute-forced over all 139968 LCG states: zero divergent draws for
// max<=10000, so the divide-first nxt spelling is exact. nextFloat is
// last/IM under both orders (multiplication by 1.0 is exact).
//
import std/io
import std/grid
import std/store
import std/fmt

std/grid:new(gx, size: 20000) { v: 0.0[f64] }
std/grid:new(gy, size: 20000) { v: 0.0[f64] }
std/grid:new(gz, size: 20000) { v: 0.0[f64] }
std/grid:new(nm, size: 640000) { c: 0[u8] }
std/grid:new(nl, size: 20000) { n: 0[i64] }
std/grid:new(doc, size: 2100000) { b: 0[u8] }
std/store:new(st) { last: 42[i64], acc: 0[i64], p: 0[i64], np: 0[i64] }

// nxt — one Helper.next_int draw
pub tor nxt { max: f64 } -> i64
nxt = std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }: _ -> @as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * max))

// nxfl — one Helper.nextFloat(1.0) draw (last/IM under both orders)
pub tor nxfl { } -> f64
nxfl = std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }: _ -> @as(f64, @floatFromInt(st.last)) / 139968.0

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// frag tors — append a fixed literal to doc. `|>` continuations after
// a for's `| done` resume at the done/each arm column, not the `|>`
// column — KORU010 teaches this now.
pub tor fhead { } -> i64
fhead = for("{\"coordinates\":[")
    ! each ch |> std/grid:stored { doc[st.p].b: ch }
        |> std/store:stored { st.p: st.p + 1 }
    | done
    |> ret0(): r -> r

pub tor fcomma { } -> i64
fcomma = for(",")
    ! each ch |> std/grid:stored { doc[st.p].b: ch }
        |> std/store:stored { st.p: st.p + 1 }
    | done
    |> ret0(): r -> r

pub tor fx { } -> i64
fx = for("{\"x\":")
    ! each ch |> std/grid:stored { doc[st.p].b: ch }
        |> std/store:stored { st.p: st.p + 1 }
    | done
    |> ret0(): r -> r

pub tor fy { } -> i64
fy = for(",\"y\":")
    ! each ch |> std/grid:stored { doc[st.p].b: ch }
        |> std/store:stored { st.p: st.p + 1 }
    | done
    |> ret0(): r -> r

pub tor fz { } -> i64
fz = for(",\"z\":")
    ! each ch |> std/grid:stored { doc[st.p].b: ch }
        |> std/store:stored { st.p: st.p + 1 }
    | done
    |> ret0(): r -> r

pub tor fnm { } -> i64
fnm = for(",\"name\":\"")
    ! each ch |> std/grid:stored { doc[st.p].b: ch }
        |> std/store:stored { st.p: st.p + 1 }
    | done
    |> ret0(): r -> r

pub tor ftail { } -> i64
ftail = for("\",\"opts\":{\"1\":[1,true]}}")
    ! each ch |> std/grid:stored { doc[st.p].b: ch }
        |> std/store:stored { st.p: st.p + 1 }
    | done
    |> ret0(): r -> r

pub tor fend { } -> i64
fend = for("],\"info\":\"some info\"}")
    ! each ch |> std/grid:stored { doc[st.p].b: ch }
        |> std/store:stored { st.p: st.p + 1 }
    | done
    |> ret0(): r -> r

// cpy — append a scoped string (fmt scratch) to doc. The
// string<*@scoped> param confines the borrow to this frame — for()'s
// expr param won't accept scoped, but t.len/t[k] reads are fine.
pub tor cpy { t: string<*@scoped> } -> i64
cpy = for(0..t.len)
    ! each k |> std/grid:stored { doc[st.p].b: t[k] }
        |> std/store:stored { st.p: st.p + 1 }
    | done
    |> ret0(): _ -> 0

// ncpy — append a scoped string into entry i's name slab
pub tor ncpy { t: string<*@scoped>, i: i64 } -> i64
ncpy = for(0..t.len)
    ! each k |> std/grid:stored { nm[i * 32 + @as(i64, @intCast(k))].c: t[k] }
    | done
    |> std/grid:stored { nl[i].n: @as(i64, @intCast(t.len)) }: _ -> 0

// putf — append v formatted {d:.8} to doc
pub tor putf { v: f64 } -> i64
putf = std/fmt:ln("{{ v:d:.8 }}"): s
    |> cpy(t: s.text): _ -> 0

// pname — append entry i's 32-stride name slab (nl[i] bytes) to doc
pub tor pname { i: i64 } -> i64
pname = for(0..@as(usize, @intCast(nl[i].n)))
    ! each k |> std/grid:stored { doc[st.p].b: nm[i * 32 + @as(i64, @intCast(k))].c }
        |> std/store:stored { st.p: st.p + 1 }
    | done
    |> ret0(): r -> r

// emite — append one entry: {d:.8} floats + name slab + literal tail
pub tor emite { i: i64 } -> i64
emite = if(i > 0)
| then |> fcomma(): _
| else |> ret0(): _
|> fx(): _
|> putf(v: gx[i].v): _
|> fy(): _
|> putf(v: gy[i].v): _
|> fz(): _
|> putf(v: gz[i].v): _
|> fnm(): _
|> pname(i): _
|> ftail(): _ -> 0

// generate — the reference's prepare(): 20000 entries, draw order
// x,y,z then name's float + int. Name text is captured into the nm
// slab once; the run loop re-serializes the same data every time.
for(0..20000)
! each i |> nxfl(): a
    |> nxfl(): b
    |> nxfl(): c
    |> std/grid:stored { gx[i].v: a }
    |> std/grid:stored { gy[i].v: b }
    |> std/grid:stored { gz[i].v: c }
    |> nxfl(): nf
    |> nxt(max: 10000.0): ni
    |> std/fmt:ln("{{ nf:d:.7 }} {{ ni:d }}"): s
    |> ncpy(t: s.text, i: @as(i64, @intCast(i))): _

// runs: 120 = 100 measured + 20 warmup. Each run serializes the full
// document into doc and counts it if the prefix check passes —
// `{"coordinates":[` = { " coordinates " : [ at bytes 0,1,13,14,15.
for(0..120)
! each _ |> std/store:stored { st.p: 0 }
    |> fhead(): _
    |> for(0..20000)
        ! each i |> emite(i: @as(i64, @intCast(i))): _
        | done
    |> fend(): _
    |> if(st.p >= 15 and doc[0].b == 123 and doc[1].b == 34 and doc[13].b == 34 and doc[14].b == 58)
        | then |> std/store:stored { st.acc: st.acc + 1 }
        | else |> ret0(): _

std/io:print.ln("{{ st.acc:d }}")
