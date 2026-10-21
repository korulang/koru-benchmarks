// etc_logparser — LangArena Etc::LogParser, run.js scored parameters
// (lines_count=52000, iterations=10, warmup=2 → 12 runs; the log is
// deterministic i% arithmetic — no RNG; each run counts matches of
// 13 regex patterns over the whole buffer — oracle 2439432).
//
// The reference links PCRE2; this port implements each pattern's
// exact semantics as byte-grid scans with the same non-overlapping
// resume (next search starts at the previous match's end):
//   p1  " [45]dd "                    p2  ci-alt bot/crawler/...
//   p3  ci-alt etc/passwd|wp-admin|../  p4  D+.D+.D+.35
//   p5  /api/[^ "]+                   p6  POST [^ ]* HTTP
//   p7  ci-alt /login|/signin         p8  ci-alt get|post|put
//   p9  email                         p10 password=[^&\s"]+
//   p11 token=/api[_-]?key=[^&\s"]+   p12 session[_-]?id=[^&\s"]+
//   p13 [D+/w+/D+:1[3-7]:D+:D+ [+-]D+]
// Per-pattern sim counts (52000 lines): 33089 26000 11885 204 12876
// 13000 17334 39000 17334 17334 6933 3962 4335 → total 203286 ×12.
//
import std/io
import std/grid
import std/store
import std/fmt

std/grid:new(logb, size: 7600000) { b: 0[u8] }
std/grid:new(strs, size: 512) { b: 0[u8] }
std/grid:new(stt, size: 48) { o: 0[i64], l: 0[i64] }
std/grid:new(alt, size: 256) { b: 0[u8] }
std/grid:new(altt, size: 32) { o: 0[i64], l: 0[i64] }
std/grid:new(cnts, size: 13) { v: 0[i64] }
std/grid:new(stt9, size: 11) { v: 0[i64] }
std/store:new(st) { res: 0[i64], tl: 0[i64], so: 0[i64], ao: 0[i64], tot: 0[i64], t1: 0[i64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// ---- emit helpers ----
pub tor pb { b: i64 } -> i64
pb = std/grid:stored { logb[st.tl].b: @as(u8, @intCast(b)) }
    |> std/store:stored { st.tl: st.tl + 1 }
    |> ret0(): _ -> 0

pub tor lit { t: string } -> i64
lit = for(0..t.len)
    ! each k |> std/grid:stored { logb[st.tl].b: t[k] }
        |> std/store:stored { st.tl: st.tl + 1 }
    | done
    |> ret0(): _ -> 0

pub tor pi { v: i64 } -> i64
pi = if(v >= 10)
| then |> pi(v: @divTrunc(v, 10)): _
    |> pb(b: 48 + @rem(v, 10)): _ -> 0
| else |> pb(b: 48 + v): _ -> 0

pub tor pxd { v: i64 } -> i64
pxd = if(v < 10)
| then |> pb(b: 48 + v): _ -> 0
| else |> pb(b: 87 + v): _ -> 0

pub tor ph { v: i64 } -> i64
ph = if(v >= 16)
| then |> ph(v: @divTrunc(v, 16)): _
    |> pxd(v: @rem(v, 16)): _ -> 0
| else |> pxd(v): _ -> 0

// esr — emit string-table entry e
pub tor esr { e: i64, k: i64 } -> i64
esr = if(k < stt[e].l)
| then |> pb(b: strs[stt[e].o + k].b): _
    |> esr(e, k: k + 1): r -> r
| else -> 0

// stw — record a string into strs + stt (build phase)
pub tor stw { e: i64, t: string } -> i64
stw = std/grid:stored { stt[e].o: st.so }
    |> std/grid:stored { stt[e].l: @as(i64, @intCast(t.len)) }
    |> for(0..t.len)
        ! each k |> std/grid:stored { strs[st.so].b: t[k] }
            |> std/store:stored { st.so: st.so + 1 }
        | done
        |> ret0(): _ -> 0

// atw — record an alternation literal into alt + altt
pub tor atw { e: i64, t: string } -> i64
atw = std/grid:stored { altt[e].o: st.ao }
    |> std/grid:stored { altt[e].l: @as(i64, @intCast(t.len)) }
    |> for(0..t.len)
        ! each k |> std/grid:stored { alt[st.ao].b: t[k] }
            |> std/store:stored { st.ao: st.ao + 1 }
        | done
        |> ret0(): _ -> 0

// ---- log generation ----
// emitL — the i%3==0 login line
pub tor emitL { i: i64 } -> i64
emitL = lit(t: "192.168.1."): _
    |> pi(v: @rem(i, 255) + 1): _
    |> lit(t: " - - ["): _
    |> pi(v: @rem(i, 31)): _
    |> lit(t: "/Oct/2023:"): _
    |> pi(v: @rem(i, 60)): _
    |> lit(t: ":55:36 +0000] \""): _
    |> esr(e: @rem(i, 4), k: 0): _
    |> lit(t: " /login?email="): _
    |> esr(e: 10 + @rem(i, 8), k: 0): _
    |> pi(v: @rem(i, 100)): _
    |> lit(t: "@"): _
    |> esr(e: 18 + @rem(i, 6), k: 0): _
    |> lit(t: "&password=secret"): _
    |> pi(v: @rem(i, 10000)): _
    |> lit(t: " HTTP/1.1\" "): _
    |> pi(v: stt9[@rem(i, 11)].v): _
    |> lit(t: " 2326 \"http://"): _
    |> esr(e: 18 + @rem(i, 6), k: 0): _
    |> lit(t: "\" \""): _
    |> esr(e: 24 + @rem(i, 4), k: 0): _
    |> lit(t: "\"\n"): _ -> 0

// emitA — the i%5==0 api line (token = "abcdef123456" x (i%3+1))
pub tor tk { n: i64 } -> i64
tk = if(n > 0)
| then |> lit(t: "abcdef123456"): _
    |> tk(n: n - 1): r -> r
| else -> 0

pub tor emitA { i: i64 } -> i64
emitA = lit(t: "192.168.1."): _
    |> pi(v: @rem(i, 255) + 1): _
    |> lit(t: " - - ["): _
    |> pi(v: @rem(i, 31)): _
    |> lit(t: "/Oct/2023:"): _
    |> pi(v: @rem(i, 60)): _
    |> lit(t: ":55:36 +0000] \""): _
    |> esr(e: @rem(i, 4), k: 0): _
    |> lit(t: " /api/data?token="): _
    |> tk(n: @rem(i, 3) + 1): _
    |> lit(t: " HTTP/1.1\" "): _
    |> pi(v: stt9[@rem(i, 11)].v): _
    |> lit(t: " 2326 \"http://"): _
    |> esr(e: 18 + @rem(i, 6), k: 0): _
    |> lit(t: "\" \""): _
    |> esr(e: 24 + @rem(i, 4), k: 0): _
    |> lit(t: "\"\n"): _ -> 0

// emitP — the i%7==0 session line (session_id = hex(i*12345))
pub tor emitP { i: i64 } -> i64
emitP = lit(t: "192.168.1."): _
    |> pi(v: @rem(i, 255) + 1): _
    |> lit(t: " - - ["): _
    |> pi(v: @rem(i, 31)): _
    |> lit(t: "/Oct/2023:"): _
    |> pi(v: @rem(i, 60)): _
    |> lit(t: ":55:36 +0000] \""): _
    |> esr(e: @rem(i, 4), k: 0): _
    |> lit(t: " /user/profile?session_id=sess_"): _
    |> ph(v: i * 12345): _
    |> lit(t: " HTTP/1.1\" "): _
    |> pi(v: stt9[@rem(i, 11)].v): _
    |> lit(t: " 2326 \"http://"): _
    |> esr(e: 18 + @rem(i, 6), k: 0): _
    |> lit(t: "\" \""): _
    |> esr(e: 24 + @rem(i, 4), k: 0): _
    |> lit(t: "\"\n"): _ -> 0

// emitX — the default path line
pub tor emitX { i: i64 } -> i64
emitX = lit(t: "192.168.1."): _
    |> pi(v: @rem(i, 255) + 1): _
    |> lit(t: " - - ["): _
    |> pi(v: @rem(i, 31)): _
    |> lit(t: "/Oct/2023:"): _
    |> pi(v: @rem(i, 60)): _
    |> lit(t: ":55:36 +0000] \""): _
    |> esr(e: @rem(i, 4), k: 0): _
    |> lit(t: " "): _
    |> esr(e: 4 + @rem(i, 6), k: 0): _
    |> lit(t: " HTTP/1.1\" "): _
    |> pi(v: stt9[@rem(i, 11)].v): _
    |> lit(t: " 2326 \"http://"): _
    |> esr(e: 18 + @rem(i, 6), k: 0): _
    |> lit(t: "\" \""): _
    |> esr(e: 24 + @rem(i, 4), k: 0): _
    |> lit(t: "\"\n"): _ -> 0

// genl — 52000 lines, else-if order %3 / %5 / %7 / default
pub tor genl { i: i64 } -> i64
genl = if(i < 52000)
| then |> if(@rem(i, 3) == 0)
        | then |> emitL(i): _
        | else |> if(@rem(i, 5) == 0)
            | then |> emitA(i): _
            | else |> if(@rem(i, 7) == 0)
                | then |> emitP(i): _
                | else |> emitX(i): _
    |> genl(i: i + 1): r -> r
| else -> 0

// ---- matcher helpers ----
// digE — end of digit run at j (produce j)
pub tor digE { j: i64 } -> i64
digE = if(j < st.tl and logb[j].b >= 48 and logb[j].b <= 57)
| then |> digE(j: j + 1): r -> r
| else -> j

// nwsE — end of [^&\s"] run at j
pub tor nwsE { j: i64 } -> i64
nwsE = if(j < st.tl and logb[j].b != 38 and logb[j].b != 32 and logb[j].b != 9 and logb[j].b != 10 and logb[j].b != 13 and logb[j].b != 12 and logb[j].b != 11 and logb[j].b != 34)
| then |> nwsE(j: j + 1): r -> r
| else -> j

// alteq — match length if log[i..] equals alt entry a, else 0
// (ci: case-fold both). The length goes through st.t1 because a
// grid-field access inside a produce arm only lowers on readfix —
// main koruc emits it raw (a7ddcbcb3 territory).
pub tor alteq { i: i64, a: i64, k: i64, ci: i64 } -> i64
alteq = if(k < altt[a].l)
| then |> if(i + k < st.tl)
        | then |> if(ci == 1)
            | then |> lowb(v: logb[i + k].b): x1
                |> lowb(v: alt[altt[a].o + k].b): x2
                |> if(x1 == x2)
                    | then |> alteq(i, a, k: k + 1, ci): r -> r
                    | else -> 0
            | else |> if(logb[i + k].b == alt[altt[a].o + k].b)
                | then |> alteq(i, a, k: k + 1, ci): r -> r
                | else -> 0
        | else -> 0
| else |> std/store:stored { st.t1: altt[a].l }: _ -> st.t1

pub tor lowb { v: i64 } -> i64
lowb = if(v >= 65 and v <= 90)
| then -> v + 32
| else -> v

// altat — first alternative (in pattern order) matching at i
// produces its length, -1 if none
pub tor altat { i: i64, a: i64, na: i64, ci: i64 } -> i64
altat = if(a < na)
| then |> alteq(i, a, k: 0, ci): m
    |> if(m > 0)
        | then -> m
        | else |> altat(i, a: a + 1, na, ci): r -> r
| else -> -1

// scalt — generic alternation scan: count matches of alts [a0,na)
// over the whole log, non-overlapping resume, into cnts[p]
pub tor scalt { i: i64, p: i64, a0: i64, na: i64, ci: i64 } -> i64
scalt = if(i < st.tl)
| then |> altat(i, a: a0, na, ci): m
    |> if(m > 0)
        | then |> std/grid:stored { cnts[p].v: cnts[p].v + 1 }
            |> scalt(i: i + m, p, a0, na, ci): r -> r
        | else |> scalt(i: i + 1, p, a0, na, ci): r -> r
| else -> 0

// sc1 — " [45]dd "
pub tor sc1 { i: i64 } -> i64
sc1 = if(i + 4 < st.tl)
| then |> if(logb[i].b == 32 and (logb[i + 1].b == 53 or logb[i + 1].b == 52) and logb[i + 2].b >= 48 and logb[i + 2].b <= 57 and logb[i + 3].b >= 48 and logb[i + 3].b <= 57 and logb[i + 4].b == 32)
        | then |> std/grid:stored { cnts[0].v: cnts[0].v + 1 }
            |> sc1(i: i + 5): r -> r
        | else |> sc1(i: i + 1): r -> r
| else -> 0

// sc4 — \d+\.\d+\.\d+\.35 : digit run, then .D+.D+.35 tail;
// a failed start inside a digit run can never match (the next '.'
// boundary is shared), so the scan continues from run end
pub tor sc4 { i: i64 } -> i64
sc4 = if(i < st.tl)
| then |> if(logb[i].b >= 48 and logb[i].b <= 57)
        | then |> digE(j: i): e1
            |> if(e1 < st.tl and logb[e1].b == 46)
                | then |> digE(j: e1 + 1): e2
                    |> if(e2 > e1 + 1 and e2 < st.tl and logb[e2].b == 46)
                        | then |> digE(j: e2 + 1): e3
                            |> if(e3 > e2 + 1 and e3 + 2 < st.tl and logb[e3].b == 46 and logb[e3 + 1].b == 51 and logb[e3 + 2].b == 53)
                                | then |> std/grid:stored { cnts[3].v: cnts[3].v + 1 }
                                    |> sc4(i: e3 + 3): r -> r
                                | else |> sc4(i: e1): r -> r
                        | else |> sc4(i: e1): r -> r
                | else |> sc4(i: e1): r -> r
        | else |> sc4(i: i + 1): r -> r
| else -> 0

// sc5 — /api/[^ "]+
pub tor sc5 { i: i64 } -> i64
sc5 = if(i < st.tl)
| then |> altat(i, a: 0, na: 1, ci: 0): m
    |> if(m > 0)
        | then |> apir(j: i + 5): e
            |> if(e > i + 5)
                | then |> std/grid:stored { cnts[4].v: cnts[4].v + 1 }
                    |> sc5(i: e): r -> r
                | else |> sc5(i: i + 1): r -> r
        | else |> sc5(i: i + 1): r -> r
| else -> 0

// apir — end of [^ "] run (no ampersand exclusion — pattern p5's
// class is [^ "], not the nws class)
pub tor apir { j: i64 } -> i64
apir = if(j < st.tl and logb[j].b != 32 and logb[j].b != 34)
| then |> apir(j: j + 1): r -> r
| else -> j

// sc6 — POST [^ ]* HTTP
pub tor sc6 { i: i64 } -> i64
sc6 = if(i < st.tl)
| then |> altat(i, a: 1, na: 2, ci: 0): m
    |> if(m > 0)
        | then |> nspE(j: i + 5): e
            |> if(e + 5 <= st.tl and logb[e].b == 32 and logb[e + 1].b == 72 and logb[e + 2].b == 84 and logb[e + 3].b == 84 and logb[e + 4].b == 80)
                | then |> std/grid:stored { cnts[5].v: cnts[5].v + 1 }
                    |> sc6(i: e + 5): r -> r
                | else |> sc6(i: i + 1): r -> r
        | else |> sc6(i: i + 1): r -> r
| else -> 0

// nspE — end of [^ ] run
pub tor nspE { j: i64 } -> i64
nspE = if(j < st.tl and logb[j].b != 32)
| then |> nspE(j: j + 1): r -> r
| else -> j

// sc9 — email: [a-zA-Z0-9._%+-]+ @ [a-zA-Z0-9.-]+ \. alpha{2,}
pub tor sc9 { i: i64 } -> i64
sc9 = if(i < st.tl)
| then |> mc1c(v: logb[i].b): c
        |> if(c == 1)
        | then |> mc1E(j: i): e1
            |> if(e1 < st.tl and logb[e1].b == 64)
                | then |> mc2E(j: e1 + 1): e2
                    |> dotbk(p: e2 - 1, lo: e1 + 1, hi: e2): m
                        |> if(m > 0)
                            | then |> std/grid:stored { cnts[8].v: cnts[8].v + 1 }
                                |> sc9(i: m): r -> r
                            | else |> sc9(i: e1): r -> r
                | else |> sc9(i: e1): r -> r
        | else |> sc9(i: i + 1): r -> r
| else -> 0

// dotbk — find the LAST '.' in (lo, hi) with >=2 trailing alphas
// (greedy domain+ backtrack; the domain needs >= 1 char before the
// dot, so p must stay strictly inside); produces hi or -1
pub tor dotbk { p: i64, lo: i64, hi: i64 } -> i64
dotbk = if(p > lo)
| then |> if(logb[p].b == 46 and hi - p - 1 >= 2)
        | then |> alla(j: p + 1, hi): ok
            |> if(ok == 1)
                | then -> hi
                | else |> dotbk(p: p - 1, lo, hi): r -> r
        | else |> dotbk(p: p - 1, lo, hi): r -> r
| else -> -1

// alla — 1 if log[j..hi) all alpha
pub tor alla { j: i64, hi: i64 } -> i64
alla = if(j < hi)
| then |> if((logb[j].b >= 97 and logb[j].b <= 122) or (logb[j].b >= 65 and logb[j].b <= 90))
        | then |> alla(j: j + 1, hi): r -> r
        | else -> 0
| else -> 1

// mc1c — email local-part class
pub tor mc1c { v: i64 } -> i64
mc1c = if((v >= 97 and v <= 122) or (v >= 65 and v <= 90) or (v >= 48 and v <= 57) or v == 46 or v == 95 or v == 37 or v == 43 or v == 45)
| then -> 1
| else -> 0

// mc1E — end of local-part run
pub tor mc1E { j: i64 } -> i64
mc1E = if(j < st.tl)
| then |> mc1c(v: logb[j].b): c
    |> if(c == 1)
        | then |> mc1E(j: j + 1): r -> r
        | else -> j
| else -> j

// mc2c — email domain class
pub tor mc2c { v: i64 } -> i64
mc2c = if((v >= 97 and v <= 122) or (v >= 65 and v <= 90) or (v >= 48 and v <= 57) or v == 46 or v == 45)
| then -> 1
| else -> 0

// mc2E — end of domain run
pub tor mc2E { j: i64 } -> i64
mc2E = if(j < st.tl)
| then |> mc2c(v: logb[j].b): c
    |> if(c == 1)
        | then |> mc2E(j: j + 1): r -> r
        | else -> j
| else -> j

// sc10 — password=[^&\s"]+
pub tor sc10 { i: i64 } -> i64
sc10 = if(i < st.tl)
| then |> altat(i, a: 2, na: 3, ci: 0): m
    |> if(m > 0)
        | then |> nwsE(j: i + 9): e
            |> if(e > i + 9)
                | then |> std/grid:stored { cnts[9].v: cnts[9].v + 1 }
                    |> sc10(i: e): r -> r
                | else |> sc10(i: i + 1): r -> r
        | else |> sc10(i: i + 1): r -> r
| else -> 0

// sc11 — token=[^&\s"]+ | api[_-]?key=[^&\s"]+  (token= tried first)
pub tor sc11 { i: i64 } -> i64
sc11 = if(i < st.tl)
| then |> altat(i, a: 3, na: 7, ci: 0): m
    |> if(m > 0)
        | then |> nwsE(j: i + m): e
            |> if(e > i + m)
                | then |> std/grid:stored { cnts[10].v: cnts[10].v + 1 }
                    |> sc11(i: e): r -> r
                | else |> sc11(i: i + 1): r -> r
        | else |> sc11(i: i + 1): r -> r
| else -> 0

// sc12 — session[_-]?id=[^&\s"]+
pub tor sc12 { i: i64 } -> i64
sc12 = if(i < st.tl)
| then |> altat(i, a: 7, na: 10, ci: 0): m
    |> if(m > 0)
        | then |> nwsE(j: i + m): e
            |> if(e > i + m)
                | then |> std/grid:stored { cnts[11].v: cnts[11].v + 1 }
                    |> sc12(i: e): r -> r
                | else |> sc12(i: i + 1): r -> r
        | else |> sc12(i: i + 1): r -> r
| else -> 0

// sc13 — \[\d+/\w+/\d+:1[3-7]:\d+:\d+ [+\-]\d+\]
pub tor sc13 { i: i64 } -> i64
sc13 = if(i < st.tl)
| then |> if(logb[i].b == 91)
        | then |> digE(j: i + 1): e1
            |> if(e1 > i + 1 and e1 < st.tl and logb[e1].b == 47)
                | then |> wdrE(j: e1 + 1): e2
                    |> if(e2 > e1 + 1 and e2 < st.tl and logb[e2].b == 47)
                        | then |> digE(j: e2 + 1): e3
                            |> if(e3 > e2 + 1 and e3 + 3 < st.tl and logb[e3].b == 58 and logb[e3 + 1].b == 49 and logb[e3 + 2].b >= 51 and logb[e3 + 2].b <= 55 and logb[e3 + 3].b == 58)
                                | then |> digE(j: e3 + 4): e4
                                    |> if(e4 > e3 + 4 and e4 < st.tl and logb[e4].b == 58)
                                        | then |> digE(j: e4 + 1): e5
                                            |> if(e5 > e4 + 1 and e5 + 1 < st.tl and logb[e5].b == 32 and (logb[e5 + 1].b == 43 or logb[e5 + 1].b == 45))
                                                | then |> digE(j: e5 + 2): e6
                                                    |> if(e6 > e5 + 2 and e6 < st.tl and logb[e6].b == 93)
                                                        | then |> std/grid:stored { cnts[12].v: cnts[12].v + 1 }
                                                            |> sc13(i: e6 + 1): r -> r
                                                        | else |> sc13(i: i + 1): r -> r
                                                | else |> sc13(i: i + 1): r -> r
                                        | else |> sc13(i: i + 1): r -> r
                                | else |> sc13(i: i + 1): r -> r
                        | else |> sc13(i: i + 1): r -> r
                | else |> sc13(i: i + 1): r -> r
        | else |> sc13(i: i + 1): r -> r
| else -> 0

// wdrE — end of \w+ run
pub tor wdrE { j: i64 } -> i64
wdrE = if(j < st.tl and ((logb[j].b >= 48 and logb[j].b <= 57) or (logb[j].b >= 97 and logb[j].b <= 122) or (logb[j].b >= 65 and logb[j].b <= 90) or logb[j].b == 95))
| then |> wdrE(j: j + 1): r -> r
| else -> j

// runp — all 13 scans, sum into st.tot
pub tor runp { } -> i64
runp = sc1(i: 0): _
    |> scalt(i: 0, p: 1, a0: 10, na: 17, ci: 1): _
    |> scalt(i: 0, p: 2, a0: 17, na: 20, ci: 1): _
    |> sc4(i: 0): _
    |> sc5(i: 0): _
    |> sc6(i: 0): _
    |> scalt(i: 0, p: 6, a0: 20, na: 22, ci: 1): _
    |> scalt(i: 0, p: 7, a0: 22, na: 25, ci: 1): _
    |> sc9(i: 0): _
    |> sc10(i: 0): _
    |> sc11(i: 0): _
    |> sc12(i: 0): _
    |> sc13(i: 0): _
    |> sumc(i: 0): _ -> 0

// sumc — accumulate cnts into st.tot
pub tor sumc { i: i64 } -> i64
sumc = if(i < 13)
| then |> std/store:stored { st.tot: st.tot + cnts[i].v }
    |> sumc(i: i + 1): r -> r
| else -> 0

// clrc — reset per-run counters
pub tor clrc { i: i64 } -> i64
clrc = if(i < 13)
| then |> std/grid:stored { cnts[i].v: 0 }
    |> clrc(i: i + 1): r -> r
| else -> 0

// runl — 12 runs (10 measured + 2 warmup)
pub tor runl { k: i64 } -> i64
runl = if(k < 12)
| then |> clrc(i: 0): _
    |> std/store:stored { st.tot: 0 }
    |> runp(): _
    |> std/store:stored { st.res: @rem(st.res + st.tot, 4294967296) }
    |> runl(k: k + 1): r -> r
| else -> 0

// ---- driver ----
// string table: 0-3 methods, 4-9 paths, 10-17 users, 18-23 domains,
// 24-27 agents; stt9 statuses; altt 0..23 alternations
stw(e: 0, t: "GET"): _
|> stw(e: 1, t: "POST"): _
|> stw(e: 2, t: "PUT"): _
|> stw(e: 3, t: "DELETE"): _
|> stw(e: 4, t: "/index.html"): _
|> stw(e: 5, t: "/api/users"): _
|> stw(e: 6, t: "/admin"): _
|> stw(e: 7, t: "/images/logo.png"): _
|> stw(e: 8, t: "/etc/passwd"): _
|> stw(e: 9, t: "/wp-admin/setup.php"): _
|> stw(e: 10, t: "john"): _
|> stw(e: 11, t: "jane"): _
|> stw(e: 12, t: "alex"): _
|> stw(e: 13, t: "sarah"): _
|> stw(e: 14, t: "mike"): _
|> stw(e: 15, t: "anna"): _
|> stw(e: 16, t: "david"): _
|> stw(e: 17, t: "elena"): _
|> stw(e: 18, t: "example.com"): _
|> stw(e: 19, t: "gmail.com"): _
|> stw(e: 20, t: "yahoo.com"): _
|> stw(e: 21, t: "hotmail.com"): _
|> stw(e: 22, t: "company.org"): _
|> stw(e: 23, t: "mail.ru"): _
|> stw(e: 24, t: "Mozilla/5.0"): _
|> stw(e: 25, t: "Googlebot/2.1"): _
|> stw(e: 26, t: "curl/7.68.0"): _
|> stw(e: 27, t: "scanner/2.0"): _
|> std/grid:stored { stt9[0].v: 200 }
|> std/grid:stored { stt9[1].v: 201 }
|> std/grid:stored { stt9[2].v: 301 }
|> std/grid:stored { stt9[3].v: 302 }
|> std/grid:stored { stt9[4].v: 400 }
|> std/grid:stored { stt9[5].v: 401 }
|> std/grid:stored { stt9[6].v: 403 }
|> std/grid:stored { stt9[7].v: 404 }
|> std/grid:stored { stt9[8].v: 500 }
|> std/grid:stored { stt9[9].v: 502 }
|> std/grid:stored { stt9[10].v: 503 }
|> atw(e: 0, t: "/api/"): _
|> atw(e: 1, t: "POST "): _
|> atw(e: 2, t: "password="): _
|> atw(e: 3, t: "token="): _
|> atw(e: 4, t: "api_key="): _
|> atw(e: 5, t: "api-key="): _
|> atw(e: 6, t: "apikey="): _
|> atw(e: 7, t: "session_id="): _
|> atw(e: 8, t: "session-id="): _
|> atw(e: 9, t: "sessionid="): _
|> atw(e: 10, t: "bot"): _
|> atw(e: 11, t: "crawler"): _
|> atw(e: 12, t: "scanner"): _
|> atw(e: 13, t: "spider"): _
|> atw(e: 14, t: "indexing"): _
|> atw(e: 15, t: "crawl"): _
|> atw(e: 16, t: "robot"): _
|> atw(e: 17, t: "etc/passwd"): _
|> atw(e: 18, t: "wp-admin"): _
|> atw(e: 19, t: "../"): _
|> atw(e: 20, t: "/login"): _
|> atw(e: 21, t: "/signin"): _
|> atw(e: 22, t: "get"): _
|> atw(e: 23, t: "post"): _
|> atw(e: 24, t: "put"): _
|> genl(i: 0): _
|> runl(k: 0): _
|> std/io:print.ln("{{ st.res:d }}")
