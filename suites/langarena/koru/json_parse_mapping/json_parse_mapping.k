// json_parse_mapping — LangArena Json::ParseMapping, run.js scored
// parameters (coords=25000, iterations=100, warmup=20 -> 120 runs;
// checksum = sum over runs of checksumFloat(avg x|y|z), mod 2^32 —
// oracle 3826684672, smoke 1969907348).
//
// Same byte-exact document generation as json_generate/json_parse_dom.
// Where ParseDom builds a generic tree, this is the reference's
// semantic shape: a typed mapping `{coordinates: []Coord}` — fields
// bind by key, unknown members are skipped, values land straight in
// the typed slots. Implemented as a scanner over the doc grid: no DOM,
// no node allocation, just positional readers + a value skipper.
//
// f64 leaf parse is provably strtod-exact for this corpus (see
// json_parse_dom.k header — {d:.8} mantissa / 10^k in one IEEE divide).
//
// Toolchain gap (parked, PARKED.md #10): std/json:parse wants
// `input: string` and no .k spelling hands grid bytes to it — so even
// the schema-directed API can't consume this document today.
//
import std/io
import std/grid
import std/store
import std/fmt

std/grid:new(gx, size: 25000) { v: 0.0[f64] }
std/grid:new(gy, size: 25000) { v: 0.0[f64] }
std/grid:new(gz, size: 25000) { v: 0.0[f64] }
std/grid:new(nm, size: 800000) { c: 0[u8] }
std/grid:new(nl, size: 25000) { n: 0[i64] }
std/grid:new(doc, size: 2400000) { b: 0[u8] }
std/store:new(st) { last: 42[i64], acc: 0[i64], p: 0[i64], pos: 0[i64], num: 0[i64], frc: 0[i64], t1: 0[i64], t2: 0[i64], t3: 0[i64], nc: 0[i64] }
std/store:new(fs) { sx: 0.0[f64], sy: 0.0[f64], sz: 0.0[f64] }

// nxt — one Helper.next_int draw
pub tor nxt { max: f64 } -> i64
nxt = std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }: _ -> @as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * max))

// nxfl — one Helper.nextFloat(1.0) draw
pub tor nxfl { } -> f64
nxfl = std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }: _ -> @as(f64, @floatFromInt(st.last)) / 139968.0

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// ---- document generation (identical to json_generate) ----

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

pub tor cpy { t: string<*@scoped> } -> i64
cpy = for(0..t.len)
    ! each k |> std/grid:stored { doc[st.p].b: t[k] }
        |> std/store:stored { st.p: st.p + 1 }
    | done
    |> ret0(): _ -> 0

pub tor ncpy { t: string<*@scoped>, i: i64 } -> i64
ncpy = for(0..t.len)
    ! each k |> std/grid:stored { nm[i * 32 + @as(i64, @intCast(k))].c: t[k] }
    | done
    |> std/grid:stored { nl[i].n: @as(i64, @intCast(t.len)) }: _ -> 0

pub tor putf { v: f64 } -> i64
putf = std/fmt:ln("{{ v:d:.8 }}"): s
    |> cpy(t: s.text): _ -> 0

pub tor pname { i: i64 } -> i64
pname = for(0..@as(usize, @intCast(nl[i].n)))
    ! each k |> std/grid:stored { doc[st.p].b: nm[i * 32 + @as(i64, @intCast(k))].c }
        |> std/store:stored { st.p: st.p + 1 }
    | done
    |> ret0(): r -> r

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

// ---- typed-mapped scanner over doc[0..st.p] ----

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

// pnum — JSON number: int digits, optional .frac (strtod-exact here)
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

// pscan — advance pos to the closing quote (no escapes in this doc)
pub tor pscan { } -> i64
pscan = if(doc[st.pos].b == 34)
| then -> 0
| else |> std/store:stored { st.pos: st.pos + 1 }
    |> pscan(): r -> r

// pstr — consume "...", span lands in st.t1 (start)/st.t2 (len)
pub tor pstr { } -> i64
pstr = std/store:stored { st.pos: st.pos + 1 }
    |> std/store:stored { st.t1: st.pos }
    |> pscan(): _
    |> std/store:stored { st.t2: st.pos - st.t1 }
    |> std/store:stored { st.pos: st.pos + 1 }: _ -> 0

// skstr — consume a string, discarding its span
pub tor skstr { } -> i64
skstr = std/store:stored { st.pos: st.pos + 1 }
    |> pscan(): _
    |> std/store:stored { st.pos: st.pos + 1 }: _ -> 0

// mscan — skip a scalar (number/bool/null): run to , ] }
pub tor mscan { } -> i64
mscan = if(doc[st.pos].b == 44 or doc[st.pos].b == 93 or doc[st.pos].b == 125)
| then -> 0
| else |> std/store:stored { st.pos: st.pos + 1 }
    |> mscan(): r -> r

// mkv — skip any JSON value (typed mapping drops unknown members)
pub tor mkv { } -> i64
mkv = if(doc[st.pos].b == 123)
| then |> mkobj(): r -> r
| else |> mkv2(): r -> r

pub tor mkv2 { } -> i64
mkv2 = if(doc[st.pos].b == 91)
| then |> mkarr(): r -> r
| else |> mkv3(): r -> r

pub tor mkv3 { } -> i64
mkv3 = if(doc[st.pos].b == 34)
| then |> skstr(): r -> r
| else |> mscan(): r -> r

// mkobj — consume '{', skip members via mkobjl
pub tor mkobj { } -> i64
mkobj = std/store:stored { st.pos: st.pos + 1 }
    |> mkobjl(): r -> r

// mkobjl — object-member skip loop: "key" : value then , or }
pub tor mkobjl { } -> i64
mkobjl = if(doc[st.pos].b == 125)
| then |> std/store:stored { st.pos: st.pos + 1 }: _ -> 0
| else |> skstr(): _
    |> std/store:stored { st.pos: st.pos + 1 }
    |> mkv(): _
    |> if(doc[st.pos].b == 44)
        | then |> std/store:stored { st.pos: st.pos + 1 }
            |> mkobjl(): r -> r
        | else |> std/store:stored { st.pos: st.pos + 1 }: _ -> 0

// mkarr — consume '[', skip elements via mkarrl
pub tor mkarr { } -> i64
mkarr = std/store:stored { st.pos: st.pos + 1 }
    |> mkarrl(): r -> r

// mkarrl — array-element skip loop
pub tor mkarrl { } -> i64
mkarrl = if(doc[st.pos].b == 93)
| then |> std/store:stored { st.pos: st.pos + 1 }: _ -> 0
| else |> mkv(): _
    |> if(doc[st.pos].b == 44)
        | then |> std/store:stored { st.pos: st.pos + 1 }
            |> mkarrl(): r -> r
        | else |> std/store:stored { st.pos: st.pos + 1 }: _ -> 0

// ---- the typed read: one coordinate object binds x/y/z into sums ----

// cval — dispatch on the current key span (st.t1/st.t2): x/y/z read a
// float into the typed slot, anything else is skipped wholesale.
pub tor cval { } -> i64
cval = if(st.t2 == 1 and doc[st.t1].b == 120)
| then |> pnum(): v
    |> std/store:stored { fs.sx: fs.sx + v }: _ -> 0
| else |> cval2(): r -> r

pub tor cval2 { } -> i64
cval2 = if(st.t2 == 1 and doc[st.t1].b == 121)
| then |> pnum(): v
    |> std/store:stored { fs.sy: fs.sy + v }: _ -> 0
| else |> cval3(): r -> r

pub tor cval3 { } -> i64
cval3 = if(st.t2 == 1 and doc[st.t1].b == 122)
| then |> pnum(): v
    |> std/store:stored { fs.sz: fs.sz + v }: _ -> 0
| else |> mkv(): r -> r

// cbody — one member per iteration inside a coordinate object;
// self-tail loop, '}' ends it
pub tor cbody { } -> i64
cbody = if(doc[st.pos].b == 125)
| then |> std/store:stored { st.pos: st.pos + 1 }: _ -> 0
| else |> pstr(): _
    |> std/store:stored { st.pos: st.pos + 1 }
    |> cval(): _
    |> if(doc[st.pos].b == 44)
        | then |> std/store:stored { st.pos: st.pos + 1 }
            |> cbody(): r -> r
        | else |> std/store:stored { st.pos: st.pos + 1 }: _ -> 0

// carrl — one coordinate object per iteration; ']' ends the array
pub tor carrl { } -> i64
carrl = if(doc[st.pos].b == 93)
| then |> std/store:stored { st.pos: st.pos + 1 }: _ -> 0
| else |> std/store:stored { st.pos: st.pos + 1 }
    |> cbody(): _
    |> std/store:stored { st.nc: st.nc + 1 }
    |> if(doc[st.pos].b == 44)
        | then |> std/store:stored { st.pos: st.pos + 1 }
            |> carrl(): r -> r
        | else |> std/store:stored { st.pos: st.pos + 1 }: _ -> 0

// carr — consume '[', read the coordinate array
pub tor carr { } -> i64
carr = std/store:stored { st.pos: st.pos + 1 }
    |> carrl(): r -> r

// rfl — root member loop: "coordinates" binds typed; "info" (or any
// other member) is skipped. Non-producing arms so the arm-column
// continuation below actually runs (see PARKED.md #9).
pub tor rfl { } -> i64
rfl = if(doc[st.pos].b == 125)
| then |> std/store:stored { st.pos: st.pos + 1 }: _ -> 0
| else |> pstr(): _
    |> std/store:stored { st.pos: st.pos + 1 }
    |> if(st.t2 == 11 and doc[st.t1].b == 99)
        | then |> carr(): _
        | else |> mkv(): _
        |> if(doc[st.pos].b == 44)
            | then |> std/store:stored { st.pos: st.pos + 1 }
                |> rfl(): r -> r
            | else |> std/store:stored { st.pos: st.pos + 1 }: _ -> 0

// djh — DJB2 a scoped string into st.t3 (u32 arithmetic, like the ref)
pub tor djh { t: string<*@scoped> } -> i64
djh = for(0..t.len)
    ! each k |> std/store:stored { st.t3: @rem(st.t3 * 33 + @as(i64, @intCast(t[k])), 4294967296) }
    | done
    |> ret0(): _ -> 0

// csum — checksumFloat(v): DJB2 of the {d:.7} text, into acc mod 2^32
pub tor csum { v: f64 } -> i64
csum = std/fmt:ln("{{ v:d:.7 }}"): s
    |> std/store:stored { st.t3: 5381 }
    |> djh(t: s.text): _
    |> std/store:stored { st.acc: @rem(st.acc + st.t3, 4294967296) }: _ -> 0

// ---- driver ----

// generate the document (prepare): 25000 entries
for(0..25000)
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

std/store:stored { st.p: 0 }
|> fhead(): _
|> for(0..25000)
    ! each i |> emite(i: @as(i64, @intCast(i))): _
    | done
|> fend(): _

// runs: 120 = 100 measured + 20 warmup — each run re-scans the document
// into the typed {coordinates} mapping and averages the floats.
for(0..120)
! each _ |> std/store:stored { st.pos: 1 }
    |> std/store:stored { fs.sx: 0.0 }
    |> std/store:stored { fs.sy: 0.0 }
    |> std/store:stored { fs.sz: 0.0 }
    |> std/store:stored { st.nc: 0 }
    |> rfl(): _
    |> csum(v: fs.sx / @as(f64, @floatFromInt(st.nc))): _
    |> csum(v: fs.sy / @as(f64, @floatFromInt(st.nc))): _
    |> csum(v: fs.sz / @as(f64, @floatFromInt(st.nc))): _

std/io:print.ln("{{ st.acc:d }}")
