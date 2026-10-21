// csv_parse — LangArena CSV::Parse, run.js scored parameters
// (rows=100000, iterations=70, warmup default = iters*0.2 = 14 → 84
// runs; checksum = sum over runs of checksumFloat(avg x|y|z) +
// checksumString(data), mod 2^32 — oracle 1071523081).
//
// Generated line shape (the reference's bufPrint), ~75.3 bytes:
//   "point {c}\n, ""{i%100}""",{x:.10},,{z:.10},"[{tf}\n, {i%100}]",{y:.10}\n
// where \n inside the quoted fields is a literal backslash+n (the
// Zig source's \\n), i.e. two bytes — the only real newline is the
// row terminator. Draw order per row is x, z, y (not x,y,z).
//
// Columns: 0 quoted label, 1 x, 2 empty, 3 z, 4 quoted bracketed
// field, 5 y — the reference reads cols 1/3/5 as f64. The parser is a
// field scanner over the doc grid: quoted-field skip honoring ""
// escapes, scalars read by pnum (provably strtod-exact: {d:.10}
// mantissa < 2^53, single IEEE divide by 10^10 — see
// json_parse_dom.k).
//
import std/io
import std/grid
import std/store
import std/fmt

std/grid:new(doc, size: 7600000) { b: 0[u8] }
std/store:new(st) { last: 42[i64], acc: 0[i64], p: 0[i64], pos: 0[i64], num: 0[i64], frc: 0[i64], t3: 0[i64], nc: 0[i64] }
std/store:new(fs) { sx: 0.0[f64], sy: 0.0[f64], sz: 0.0[f64] }

// nxfl — one Helper.nextFloat(1.0) draw
pub tor nxfl { } -> f64
nxfl = std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }: _ -> @as(f64, @floatFromInt(st.last)) / 139968.0

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// ---- document generation ----

pub tor cpy { t: string<*@scoped> } -> i64
cpy = for(0..t.len)
    ! each k |> std/grid:stored { doc[st.p].b: t[k] }
        |> std/store:stored { st.p: st.p + 1 }
    | done
    |> ret0(): _ -> 0

// lit — copy a string parameter's bytes (literal call sites)
pub tor lit { t: string } -> i64
lit = for(0..t.len)
    ! each k |> std/grid:stored { doc[st.p].b: t[k] }
        |> std/store:stored { st.p: st.p + 1 }
    | done
    |> ret0(): _ -> 0

// pb — one raw byte
pub tor pb { b: i64 } -> i64
pb = std/grid:stored { doc[st.p].b: @as(u8, @intCast(b)) }
    |> std/store:stored { st.p: st.p + 1 }
    |> ret0(): _ -> 0

// puti — decimal integer via fmt
pub tor puti { v: i64 } -> i64
puti = std/fmt:ln("{{ v:d }}"): s
    |> cpy(t: s.text): _ -> 0

// putf10 — the {d:.10} float field
pub tor putf10 { v: f64 } -> i64
putf10 = std/fmt:ln("{{ v:d:.10 }}"): s
    |> cpy(t: s.text): _ -> 0

// puttf — true/false literal
pub tor puttf { i: i64 } -> i64
puttf = if(@rem(i, 2) == 0)
| then |> lit(t: "true"): _ -> 0
| else |> lit(t: "false"): _ -> 0

// genrow — one CSV line for row i. Draw order x, z, y.
pub tor genrow { i: i64 } -> i64
genrow = nxfl(): x
    |> nxfl(): z
    |> nxfl(): y
    |> lit(t: "\"point "): _
    |> pb(b: 65 + @rem(i, 26)): _
    |> lit(t: "\\n, \"\""): _
    |> puti(v: @rem(i, 100)): _
    |> lit(t: "\"\"\","): _
    |> putf10(v: x): _
    |> lit(t: ",,"): _
    |> putf10(v: z): _
    |> lit(t: ",\"["): _
    |> puttf(i): _
    |> lit(t: "\\n, "): _
    |> puti(v: @rem(i, 100)): _
    |> lit(t: "]\","): _
    |> putf10(v: y): _
    |> pb(b: 10): _ -> 0

// ---- field scanner over doc[0..st.p] ----

// skipq — quoted field: opening " at pos; "" inside is an escaped
// quote, lone " closes
pub tor skipq { } -> i64
skipq = std/store:stored { st.pos: st.pos + 1 }
    |> sql(): r -> r

// sql — inside a quoted field
pub tor sql { } -> i64
sql = if(doc[st.pos].b == 34)
| then |> if(doc[st.pos + 1].b == 34)
    | then |> std/store:stored { st.pos: st.pos + 2 }
        |> sql(): r -> r
    | else |> std/store:stored { st.pos: st.pos + 1 }: _ -> 0
| else |> std/store:stored { st.pos: st.pos + 1 }
    |> sql(): r -> r

// pdig — digit loop into st.num; frac digits counted in st.frc
pub tor pdig { frac: i64 } -> i64
pdig = if(doc[st.pos].b >= 48 and doc[st.pos].b <= 57)
| then |> std/store:stored { st.num: st.num * 10 + doc[st.pos].b - 48 }
    |> std/store:stored { st.pos: st.pos + 1 }
    |> if(frac == 1)
        | then |> std/store:stored { st.frc: st.frc + 1 }
            |> pdig(frac): r -> r
        | else |> pdig(frac): r -> r
| else -> 0

// pow10 — 10^e as f64
pub tor pow10 { e: i64, v: f64 } -> f64
pow10 = if(e > 0)
| then |> pow10(e: e - 1, v: v * 10.0): r -> r
| else -> v

// pnum — scalar float: int digits, optional .frac
pub tor pnum { } -> f64
pnum = std/store:stored { st.num: 0 }
    |> std/store:stored { st.frc: 0 }
    |> pdig(frac: 0): _
    |> if(doc[st.pos].b == 46)
        | then |> std/store:stored { st.pos: st.pos + 1 }
            |> pdig(frac: 1): _
        | else |> ret0(): _
        |> pow10(e: st.frc, v: 1.0): d
        |> ret0(): _ -> @as(f64, @floatFromInt(st.num)) / d

// row — parse one line: qfield, x, (empty), z, qfield, y, \n
pub tor row { } -> i64
row = skipq(): _
    |> std/store:stored { st.pos: st.pos + 1 }
    |> pnum(): x
    |> std/store:stored { fs.sx: fs.sx + x }
    |> std/store:stored { st.pos: st.pos + 1 }
    |> std/store:stored { st.pos: st.pos + 1 }
    |> pnum(): z
    |> std/store:stored { fs.sz: fs.sz + z }
    |> std/store:stored { st.pos: st.pos + 1 }
    |> skipq(): _
    |> std/store:stored { st.pos: st.pos + 1 }
    |> pnum(): y
    |> std/store:stored { fs.sy: fs.sy + y }
    |> std/store:stored { st.pos: st.pos + 1 }
    |> std/store:stored { st.nc: st.nc + 1 }: _ -> 0

// scan — row loop over the whole document
pub tor scan { } -> i64
scan = if(st.pos < st.p)
| then |> row(): _
    |> scan(): r -> r
| else -> 0

// djh — DJB2 a scoped string into st.t3 (u32 arithmetic)
pub tor djh { t: string<*@scoped> } -> i64
djh = for(0..t.len)
    ! each k |> std/store:stored { st.t3: @rem(st.t3 * 33 + @as(i64, @intCast(t[k])), 4294967296) }
    | done
    |> ret0(): _ -> 0

// csum — checksumFloat(v) into acc mod 2^32
pub tor csum { v: f64 } -> i64
csum = std/fmt:ln("{{ v:d:.7 }}"): s
    |> std/store:stored { st.t3: 5381 }
    |> djh(t: s.text): _
    |> std/store:stored { st.acc: @rem(st.acc + st.t3, 4294967296) }: _ -> 0

// djdoc — checksumString(data): DJB2 over all doc bytes → st.t3
pub tor djdoc { i: i64 } -> i64
djdoc = if(i < st.p)
| then |> std/store:stored { st.t3: @rem(st.t3 * 33 + doc[i].b, 4294967296) }
    |> djdoc(i: i + 1): r -> r
| else -> 0

// ---- driver ----

for(0..100000)
! each i |> genrow(i: @as(i64, @intCast(i))): _

// 84 runs = 70 measured + 14 warmup (warmup_iterations defaults to
// iters*0.2 for tasks with no explicit warmup)
for(0..84)
! each _ |> std/store:stored { st.pos: 0 }
    |> std/store:stored { fs.sx: 0.0 }
    |> std/store:stored { fs.sy: 0.0 }
    |> std/store:stored { fs.sz: 0.0 }
    |> std/store:stored { st.nc: 0 }
    |> scan(): _
    |> csum(v: fs.sx / @as(f64, @floatFromInt(st.nc))): _
    |> csum(v: fs.sy / @as(f64, @floatFromInt(st.nc))): _
    |> csum(v: fs.sz / @as(f64, @floatFromInt(st.nc))): _

// final checksum adds checksumString(data) once
std/store:stored { st.t3: 5381 }
|> djdoc(i: 0): _
|> std/store:stored { st.acc: @rem(st.acc + st.t3, 4294967296) }: _

std/io:print.ln("{{ st.acc:d }}")
