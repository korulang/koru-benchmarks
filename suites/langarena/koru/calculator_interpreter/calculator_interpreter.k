// calculator_interpreter — LangArena Calculator::Interpreter,
// run.js scored parameters (operations=35000, iterations=100,
// warmup=20 -> 120 runs x V = 38749936; V = 2112015170 as u32).
//
// prepare() generates + parses the program ONCE (same text generator
// and recursive-descent parser as calculator_ast.k — see that file);
// every run spins a fresh Interpreter and evaluates all 35011
// statements. Eval: Number -> value; Variable -> hash lookup (0 if
// absent); BinaryOp -> wrapping i64 ops with the reference's
// simpleDiv/simpleMod = trunc division and a - div*b; Assignment ->
// eval expr then store.
//
// The reference's Hash(String,Int64) is an open-addressed table here:
// vt slots keyed on name bytes in txt, DJB2 hash + linear probe —
// name identity is byte content, not position, exactly like a real
// string-keyed map.
//
import std/io
import std/grid
import std/store

std/grid:new(txt, size: 6000000) { b: 0[u8] }
std/grid:new(dg, size: 20) { d: 0[i64] }
std/grid:new(vt, size: 131072) { u: 0[i64], s: 0[i64], l: 0[i64], v: 0[i64] }
std/grid:new(nd, size: 1000000) { k: 0[i64], a: 0[i64], b: 0[i64], c: 0[i64] }
std/grid:new(ex, size: 40000) { n: 0[i64] }
std/store:new(st) { last: 42[i64], tp: 0[i64], pos: 0[i64], cur: 0[i64], nc: 0[i64], ec: 0[i64], nv: 0[i64], op: 0[i64], vs: 0[i64], vl: 0[i64], lv: 0[i64], ll: 0[i64], acc: 0[i64], v: 0[i64] }

// nxt — one Helper.next_int draw (advances st.last, returns the value)
pub tor nxt { max: f64 } -> i64
nxt = std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }: _ -> @as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * max))

// ---- text emission -------------------------------------------------------

// dfill/dcopy — render decimal digits of x (x >= 0 always in this
// grammar's templates) into txt via the dg scratch, LSB-first then copy.
pub tor dfill { x: i64, c: i64 } -> i64
dfill = std/grid:stored { dg[c].d: @rem(x, 10) }
    |> if(x >= 10)
        | then |> dfill(x: @divTrunc(x, 10), c: c + 1): r -> r
        | else -> c + 1

pub tor dcopy { c: i64, j: i64 } -> i64
dcopy = if(j < c)
| then |> std/grid:stored { txt[st.tp].b: @as(u8, @intCast(dg[c - 1 - j].d + 48)) }
    |> std/store:stored { st.tp: st.tp + 1 }
    |> dcopy(c, j: j + 1): r -> r
| else -> 0

pub tor putn { x: i64 } -> i64
putn = dfill(x, c: 0): c
    |> dcopy(c, j: 0): r -> r

// tpp — bump text position (single-step stored + produce: mid-chain
// -> tails only parse after tor calls, not std/store:stored steps)
pub tor tpp { } -> i64
tpp = std/store:stored { st.tp: st.tp + 1 }: _ -> 0

pub tor putc { ch: i64 } -> i64
putc = std/grid:stored { txt[st.tp].b: @as(u8, @intCast(ch)) }
    |> tpp(): r -> r

// emith0 — "v0 = 1\n"
pub tor emith0 { } -> i64
emith0 = putc(ch: 118): _ |> putc(ch: 48): _ |> putc(ch: 32): _ |> putc(ch: 61): _ |> putc(ch: 32): _ |> putc(ch: 49): _ |> putc(ch: 10): _ -> 0

// emithv — "v{v} = v{v-1} + {v}\n" for v = 1..10
pub tor emithv { v: i64 } -> i64
emithv = putc(ch: 118): _ |> putn(x: v): _ |> putc(ch: 32): _ |> putc(ch: 61): _ |> putc(ch: 32): _ |> putc(ch: 118): _ |> putn(x: v - 1): _ |> putc(ch: 32): _ |> putc(ch: 43): _ |> putc(ch: 32): _ |> putn(x: v): _ |> putc(ch: 10): _ -> 0

// emitpre — "v{i+10} = v{i+9} + " (the shared op-line head)
pub tor emitpre { i: i64 } -> i64
emitpre = putc(ch: 118): _ |> putn(x: i + 10): _ |> putc(ch: 32): _ |> putc(ch: 61): _ |> putc(ch: 32): _ |> putc(ch: 118): _ |> putn(x: i + 9): _ |> putc(ch: 32): _ |> putc(ch: 43): _ |> putc(ch: 32): _ -> 0


// ec0 — template 0 body + trailing newline
pub tor ec0 { i: i64 } -> i64
ec0 = putc(ch: 40): _ |> putc(ch: 118): _ |> putn(x: i + 9): _ |> putc(ch: 32): _ |> putc(ch: 47): _ |> putc(ch: 32): _ |> putc(ch: 51): _ |> putc(ch: 41): _ |> putc(ch: 32): _ |> putc(ch: 42): _ |> putc(ch: 32): _ |> putc(ch: 52): _ |> putc(ch: 32): _ |> putc(ch: 45): _ |> putc(ch: 32): _ |> putn(x: i): _ |> putc(ch: 32): _ |> putc(ch: 47): _ |> putc(ch: 32): _ |> putc(ch: 40): _ |> putc(ch: 51): _ |> putc(ch: 32): _ |> putc(ch: 43): _ |> putc(ch: 32): _ |> putc(ch: 40): _ |> putc(ch: 49): _ |> putc(ch: 56): _ |> putc(ch: 32): _ |> putc(ch: 45): _ |> putc(ch: 32): _ |> putc(ch: 118): _ |> putn(x: i + 8): _ |> putc(ch: 41): _ |> putc(ch: 41): _ |> putc(ch: 32): _ |> putc(ch: 37): _ |> putc(ch: 32): _ |> putc(ch: 118): _ |> putn(x: i + 7): _ |> putc(ch: 32): _ |> putc(ch: 43): _ |> putc(ch: 32): _ |> putc(ch: 50): _ |> putc(ch: 32): _ |> putc(ch: 42): _ |> putc(ch: 32): _ |> putc(ch: 40): _ |> putc(ch: 40): _ |> putc(ch: 57): _ |> putc(ch: 32): _ |> putc(ch: 45): _ |> putc(ch: 32): _ |> putc(ch: 118): _ |> putn(x: i + 4): _ |> putc(ch: 41): _ |> putc(ch: 32): _ |> putc(ch: 42): _ |> putc(ch: 32): _ |> putc(ch: 40): _ |> putc(ch: 118): _ |> putn(x: i + 5): _ |> putc(ch: 32): _ |> putc(ch: 43): _ |> putc(ch: 32): _ |> putc(ch: 55): _ |> putc(ch: 41): _ |> putc(ch: 41): _ |> putc(ch: 10): _ -> 0


// ec1 — template 1 body + trailing newline
pub tor ec1 { i: i64 } -> i64
ec1 = putc(ch: 118): _ |> putn(x: i + 9): _ |> putc(ch: 32): _ |> putc(ch: 43): _ |> putc(ch: 32): _ |> putc(ch: 40): _ |> putc(ch: 118): _ |> putn(x: i + 8): _ |> putc(ch: 32): _ |> putc(ch: 43): _ |> putc(ch: 32): _ |> putc(ch: 118): _ |> putn(x: i + 7): _ |> putc(ch: 41): _ |> putc(ch: 32): _ |> putc(ch: 42): _ |> putc(ch: 32): _ |> putc(ch: 118): _ |> putn(x: i + 6): _ |> putc(ch: 32): _ |> putc(ch: 45): _ |> putc(ch: 32): _ |> putc(ch: 40): _ |> putc(ch: 118): _ |> putn(x: i + 5): _ |> putc(ch: 32): _ |> putc(ch: 47): _ |> putc(ch: 32): _ |> putc(ch: 32): _ |> putc(ch: 118): _ |> putn(x: i + 4): _ |> putc(ch: 41): _ |> putc(ch: 10): _ -> 0


// ec2 — template 2 body + trailing newline
pub tor ec2 { i: i64 } -> i64
ec2 = putc(ch: 40): _ |> putc(ch: 51): _ |> putc(ch: 55): _ |> putc(ch: 56): _ |> putc(ch: 57): _ |> putc(ch: 32): _ |> putc(ch: 45): _ |> putc(ch: 32): _ |> putc(ch: 40): _ |> putc(ch: 40): _ |> putc(ch: 40): _ |> putc(ch: 118): _ |> putn(x: i + 3): _ |> putc(ch: 41): _ |> putc(ch: 41): _ |> putc(ch: 41): _ |> putc(ch: 41): _ |> putc(ch: 32): _ |> putc(ch: 43): _ |> putc(ch: 32): _ |> putc(ch: 49): _ |> putc(ch: 10): _ -> 0


// ec3 — template 3 body + trailing newline
pub tor ec3 { i: i64 } -> i64
ec3 = putc(ch: 52): _ |> putc(ch: 47): _ |> putc(ch: 50): _ |> putc(ch: 32): _ |> putc(ch: 42): _ |> putc(ch: 32): _ |> putc(ch: 40): _ |> putc(ch: 49): _ |> putc(ch: 45): _ |> putc(ch: 51): _ |> putc(ch: 41): _ |> putc(ch: 32): _ |> putc(ch: 43): _ |> putc(ch: 32): _ |> putc(ch: 118): _ |> putn(x: i + 1): _ |> putc(ch: 47): _ |> putc(ch: 118): _ |> putn(x: i + 5): _ |> putc(ch: 10): _ -> 0


// ec4 — template 4 body + trailing newline
pub tor ec4 { i: i64 } -> i64
ec4 = putc(ch: 49): _ |> putc(ch: 43): _ |> putc(ch: 50): _ |> putc(ch: 43): _ |> putc(ch: 51): _ |> putc(ch: 43): _ |> putc(ch: 52): _ |> putc(ch: 43): _ |> putc(ch: 53): _ |> putc(ch: 43): _ |> putc(ch: 54): _ |> putc(ch: 43): _ |> putc(ch: 118): _ |> putn(x: i + 9): _ |> putc(ch: 10): _ -> 0


// ec5 — template 5 body + trailing newline
pub tor ec5 { i: i64 } -> i64
ec5 = putc(ch: 40): _ |> putc(ch: 57): _ |> putc(ch: 57): _ |> putc(ch: 57): _ |> putc(ch: 57): _ |> putc(ch: 57): _ |> putc(ch: 32): _ |> putc(ch: 47): _ |> putc(ch: 32): _ |> putc(ch: 118): _ |> putn(x: i + 7): _ |> putc(ch: 41): _ |> putc(ch: 10): _ -> 0


// ec6 — template 6 body + trailing newline
pub tor ec6 { i: i64 } -> i64
ec6 = putc(ch: 48): _ |> putc(ch: 32): _ |> putc(ch: 43): _ |> putc(ch: 32): _ |> putc(ch: 48): _ |> putc(ch: 32): _ |> putc(ch: 45): _ |> putc(ch: 32): _ |> putc(ch: 118): _ |> putn(x: i + 2): _ |> putc(ch: 10): _ -> 0


// ec7 — template 7 body + trailing newline
pub tor ec7 { i: i64 } -> i64
ec7 = putc(ch: 40): _ |> putc(ch: 40): _ |> putc(ch: 40): _ |> putc(ch: 40): _ |> putc(ch: 40): _ |> putc(ch: 40): _ |> putc(ch: 40): _ |> putc(ch: 40): _ |> putc(ch: 40): _ |> putc(ch: 40): _ |> putc(ch: 118): _ |> putn(x: i + 4): _ |> putc(ch: 41): _ |> putc(ch: 41): _ |> putc(ch: 41): _ |> putc(ch: 41): _ |> putc(ch: 41): _ |> putc(ch: 41): _ |> putc(ch: 41): _ |> putc(ch: 41): _ |> putc(ch: 41): _ |> putc(ch: 41): _ |> putc(ch: 32): _ |> putc(ch: 42): _ |> putc(ch: 32): _ |> putc(ch: 50): _ |> putc(ch: 10): _ -> 0


// ec8 — template 8 body + trailing newline
pub tor ec8 { i: i64 } -> i64
ec8 = putn(x: i): _ |> putc(ch: 32): _ |> putc(ch: 42): _ |> putc(ch: 32): _ |> putc(ch: 40): _ |> putc(ch: 118): _ |> putn(x: i + 9): _ |> putc(ch: 37): _ |> putc(ch: 54): _ |> putc(ch: 41): _ |> putc(ch: 37): _ |> putc(ch: 55): _ |> putc(ch: 10): _ -> 0


// ec9 — template 9 body + trailing newline
pub tor ec9 { i: i64 } -> i64
ec9 = putc(ch: 40): _ |> putc(ch: 49): _ |> putc(ch: 41): _ |> putc(ch: 47): _ |> putc(ch: 40): _ |> putc(ch: 48): _ |> putc(ch: 45): _ |> putc(ch: 118): _ |> putn(x: i + 5): _ |> putc(ch: 41): _ |> putc(ch: 32): _ |> putc(ch: 43): _ |> putc(ch: 32): _ |> putc(ch: 40): _ |> putc(ch: 118): _ |> putn(x: i + 3): _ |> putc(ch: 41): _ |> putc(ch: 10): _ -> 0


// ---- parser ---------------------------------------------------------------

pub tor adv { } -> i64
adv = std/store:stored { st.pos: st.pos + 1 }
    |> if(st.pos >= st.tp)
        | then |> std/store:stored { st.cur: 0 }: _ -> st.cur
        | else |> std/store:stored { st.cur: txt[st.pos].b }: _ -> st.cur

pub tor skw { } -> i64
skw = if(st.cur == 32 or st.cur == 9 or st.cur == 10 or st.cur == 13)
| then |> adv(): _ |> skw(): r -> r
| else -> 0

// ncp — bump node count, produce the slot just written
pub tor ncp { } -> i64
ncp = std/store:stored { st.nc: st.nc + 1 }: _ -> st.nc - 1

// mkn — allocate node k(a,b,c), return its index
pub tor mkn { k: i64, a: i64, b: i64, c: i64 } -> i64
mkn = std/grid:stored { nd[st.nc].k: k }
    |> std/grid:stored { nd[st.nc].a: a }
    |> std/grid:stored { nd[st.nc].b: b }
    |> std/grid:stored { nd[st.nc].c: c }
    |> ncp(): r -> r

// pnl — number-char loop, returns the accumulated value (wraps like
// the reference's v &* 10 &+ digit)
pub tor pnl { v: i64 } -> i64
pnl = if(st.cur >= 48 and st.cur <= 57)
| then |> std/store:stored { st.nv: st.cur - 48 }
    |> adv(): _
    |> pnl(v: v *% 10 +% st.nv): r -> r
| else -> v

// pvl — variable-name char loop (letters + digits)
pub tor pvl { } -> i64
pvl = if((st.cur >= 97 and st.cur <= 122) or (st.cur >= 65 and st.cur <= 90) or (st.cur >= 48 and st.cur <= 57))
| then |> adv(): _ |> pvl(): r -> r
| else -> 0

// pelx/ptlx — the op char must ride in a PARAM: scratch store fields
// get clobbered by nested pexpr recursion between the op read and the
// mkn that consumes it (same reason pvar carries s/l through pvassign).
pub tor pelx { n: i64, op: i64 } -> i64
pelx = adv(): _
    |> pterm(): r2
    |> mkn(k: 2, a: op, b: n, c: r2): m
    |> pel(n: m): r -> r

// pel — expr tail loop: + and - , left-assoc
pub tor pel { n: i64 } -> i64
pel = skw(): _
    |> if(st.cur == 43 or st.cur == 45)
        | then |> pelx(n, op: st.cur): r -> r
        | else -> n

pub tor ptlx { n: i64, op: i64 } -> i64
ptlx = adv(): _
    |> pfactor(): r2
    |> mkn(k: 2, a: op, b: n, c: r2): m
    |> ptl(n: m): r -> r

// ptl — term tail loop: * / % , left-assoc
pub tor ptl { n: i64 } -> i64
ptl = skw(): _
    |> if(st.cur == 42 or st.cur == 47 or st.cur == 37)
        | then |> ptlx(n, op: st.cur): r -> r
        | else -> n

// pvassign — name range carried as params across the pexpr recursion
pub tor pvassign { s: i64, l: i64 } -> i64
pvassign = pexpr(): e
    |> mkn(k: 3, a: s, b: l, c: e): r -> r

// pvar — variable or assignment: name, skipws, optional '= expr'
pub tor pvar { } -> i64
pvar = std/store:stored { st.vs: st.pos }
    |> pvl(): _
    |> std/store:stored { st.vl: st.pos - st.vs }
    |> skw(): _
    |> if(st.cur == 61)
        | then |> adv(): _
            |> pvassign(s: st.vs, l: st.vl): r -> r
        | else |> mkn(k: 1, a: st.vs, b: st.vl, c: 0): r -> r

// pfactor — digit | letter | '(' expr ')' | else advance->Number(0)
pub tor pfactor { } -> i64
pfactor = skw(): _
    |> if(st.cur >= 48 and st.cur <= 57)
        | then |> pnl(v: 0): val
            |> mkn(k: 0, a: val, b: 0, c: 0): r -> r
        | else |> if((st.cur >= 97 and st.cur <= 122) or (st.cur >= 65 and st.cur <= 90))
            | then |> pvar(): r -> r
            | else |> if(st.cur == 40)
                | then |> adv(): _
                    |> pexpr(): n
                    |> skw(): _
                    |> if(st.cur == 41)
                        | then |> adv(): _ -> n
                        | else -> n
                | else |> adv(): _
                    |> mkn(k: 0, a: 0, b: 0, c: 0): r -> r

pub tor pterm { } -> i64
pterm = pfactor(): n
    |> ptl(n): r -> r

pub tor pexpr { } -> i64
pexpr = pterm(): n
    |> pel(n): r -> r

// pmain — statement loop (tail-lowered): one expression per line
pub tor pmain { } -> i64
pmain = skw(): _
    |> if(st.cur == 0)
        | then -> 0
        | else |> pexpr(): e
            |> std/grid:stored { ex[st.ec].n: e }
            |> std/store:stored { st.ec: st.ec + 1 }
            |> pmain(): r -> r

// djb — DJB2 over txt[i..e)
pub tor djb { i: i64, e: i64, h: i64 } -> i64
djb = if(i < e)
| then |> djb(i: i + 1, e, h: @rem(h * 33 + txt[i].b, 4294967296)): r -> r
| else -> h

// ---- evaluator --------------------------------------------------------------

// vh — DJB2 over txt[i..e) (the string-keyed hash)
pub tor vh { i: i64, e: i64, h: i64 } -> i64
vh = if(i < e)
| then |> vh(i: i + 1, e, h: @rem(h * 33 + txt[i].b, 4294967296)): r -> r
| else -> h

// vnm — byte-compare txt[a..a+l] vs txt[b..b+l)
pub tor vnm { a: i64, b: i64, l: i64, i: i64 } -> i64
vnm = if(i >= l)
| then -> 1
| else |> if(txt[a + i].b == txt[b + i].b)
    | then |> vnm(a, b, l, i: i + 1): r -> r
    | else -> 0

// vpr — linear probe for the slot of name (s,l); empty or match
pub tor vpr { s: i64, l: i64, idx: i64 } -> i64
vpr = if(vt[idx].u == 0)
| then -> idx
| else |> if(vt[idx].l == l)
    | then |> vnm(a: s, b: vt[idx].s, l, i: 0): eq
        |> if(eq == 1)
            | then -> idx
            | else |> vpr(s, l, idx: @rem(idx + 1, 131072)): r -> r
    | else |> vpr(s, l, idx: @rem(idx + 1, 131072)): r -> r

// evl — evaluate node n (nd fields: k 0=num 1=var 2=binop 3=assign)
pub tor evl { n: i64 } -> i64
evl = if(nd[n].k == 0)
| then -> nd[n].a
| else |> if(nd[n].k == 1)
    | then |> vh(i: nd[n].a, e: nd[n].a + nd[n].b, h: 5381): hh
        |> vpr(s: nd[n].a, l: nd[n].b, idx: @rem(hh, 131072)): sl
        |> if(vt[sl].u == 1)
            | then -> vt[sl].v
            | else -> 0
    | else |> if(nd[n].k == 2)
        | then |> evl(n: nd[n].b): l
            |> evl(n: nd[n].c): r
            |> if(nd[n].a == 43)
                | then -> l +% r
                | else |> if(nd[n].a == 45)
                    | then -> l -% r
                    | else |> if(nd[n].a == 42)
                        | then -> l *% r
                        | else |> if(nd[n].a == 47)
                            | then |> if(r == 0)
                                | then -> 0
                                | else -> @divTrunc(l, r)
                            | else |> if(r == 0)
                                | then -> 0
                                | else -> @rem(l, r)
        | else |> evl(n: nd[n].c): v
            |> vh(i: nd[n].a, e: nd[n].a + nd[n].b, h: 5381): hh
            |> vpr(s: nd[n].a, l: nd[n].b, idx: @rem(hh, 131072)): sl
            |> if(vt[sl].u == 0)
                | then |> std/grid:stored { vt[sl].u: 1 }
                    |> std/grid:stored { vt[sl].s: nd[n].a }
                    |> std/grid:stored { vt[sl].l: nd[n].b }
                    |> std/grid:stored { vt[sl].v: v }: _ -> v
                | else |> std/grid:stored { vt[sl].v: v }: _ -> v

// ---- driver ---------------------------------------------------------------

// generate_random_program: fixed header, then n LCG-templated lines
emith0(): _

for(1..11)
! each v |> emithv(v: @as(i64, @intCast(v))): _

for(0..35000)
! each i |> nxt(max: 10.0): c
    |> emitpre(i: @as(i64, @intCast(i))): _
    |> if(c == 0)
        | then |> ec0(i: @as(i64, @intCast(i))): _
        | else |> if(c == 1)
            | then |> ec1(i: @as(i64, @intCast(i))): _
            | else |> if(c == 2)
                | then |> ec2(i: @as(i64, @intCast(i))): _
                | else |> if(c == 3)
                    | then |> ec3(i: @as(i64, @intCast(i))): _
                    | else |> if(c == 4)
                        | then |> ec4(i: @as(i64, @intCast(i))): _
                        | else |> if(c == 5)
                            | then |> ec5(i: @as(i64, @intCast(i))): _
                            | else |> if(c == 6)
                                | then |> ec6(i: @as(i64, @intCast(i))): _
                                | else |> if(c == 7)
                                    | then |> ec7(i: @as(i64, @intCast(i))): _
                                    | else |> if(c == 8)
                                        | then |> ec8(i: @as(i64, @intCast(i))): _
                                        | else |> ec9(i: @as(i64, @intCast(i))): _

// parse once (prepare), then 120 = 100 measured + 20 warmup runs;
// each run is a fresh Interpreter: clear the var table, evaluate all
// statements, accumulate the last result as u32 wrap-add.
std/store:stored { st.pos: 0 }
std/store:stored { st.cur: txt[0].b }
pmain(): _

for(0..120)
! each _ |> for(0..131072)
    ! each i |> std/grid:stored { vt[i].u: 0 }
    | done |> for(0..@as(usize, @intCast(st.ec)))
        ! each i |> evl(n: ex[i].n): v
            |> if(@as(i64, @intCast(i)) == st.ec - 1)
                | then |> std/store:stored { st.acc: @rem(st.acc + @rem(v, 4294967296) + 4294967296, 4294967296) }

std/io:print.ln("{{ st.acc:d }}")
