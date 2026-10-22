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
// Perf notes (whole-process min, this machine):
//   baseline 13 separate scans      ~2.97s
//   + std/grid:slice raw borrows    ~2.05s  (declines per-byte
//     __koru_at floor checks; every index is already guarded by st.tl)
//   + fused single-pass scanner     ~0.33s  (one dispatch pass; rs[p]
//     resume cursors preserve find_iter non-overlap per pattern)
//   RETAINED: u32 cursors/u8 bytes (PERF.md lane recipe), c9 byte-class
//     table, switch:char on the folded byte, per-pattern fail-forward
//     (t4/t9 jump the resume to the run end — a failed start inside a
//     run can never match: the shared end boundary is consumed).
//   FALSIFIED (all measured slower than the kept shape):
//   - dispatch-class table dsp[c] -> switch tag: +0.03s. The arm index
//     becomes a dependent load feeding the indirect jump.
//   - folding the t9g/t1 gates into per-class switch arms: +0.03-0.05s.
//     More arms widened the jump-table region; the single shared gate
//     call site wins.
//   - raw-byte dispatch without lowb (both-case letter arms): +0.03s.
//   - hoisting alteq's per-char bound check into am(): +0.03s. Most
//     literals die on char 0, so the pre-check is pure overhead.
//
// Phase split (std/time instrumented probe, this machine — the residual
// ~1.07x board deficit is BASIS, not kernel): Rust's scored window is
// Instant around 10 run() calls only (0.314s measured); our whole-process
// number additionally contains ~62ms Rust excludes: 2 warmup scans
// (~56.5ms, required — checksum accumulates over all 12 runs) + log
// generation (~4.8ms) + startup/print (~1ms). Apples-to-apples the fused
// scanner's 10-run window is ~283ms vs Rust's 314ms — ~0.90x, ~10% ahead.
// No kernel headroom remains; the gap is measurement surface.
//
import std/io
import std/grid
import std/store
import std/fmt
import std/switch

std/grid:new(logb, size: 7600000) { b: 0[u8] }
std/grid:new(strs, size: 512) { b: 0[u8] }
std/grid:new(stt, size: 48) { o: 0[i64], l: 0[i64] }
std/grid:new(alt, size: 256) { b: 0[u8] }
std/grid:new(altt, size: 32) { o: 0[i64], l: 0[i64] }
std/grid:new(cnts, size: 13) { v: 0[i64] }
std/grid:new(stt9, size: 11) { v: 0[i64] }
std/store:new(st) { res: 0[i64], tl: 0[i64], so: 0[i64], ao: 0[i64], tot: 0[i64], t1: 0[i64] }
// Raw borrows for the scan side: the per-byte __koru_at floor (a panic
// edge per read — ~7 bound pairs per byte in nwsE alone) is what the
// borrow declines; index obligation is the scanners' own guards, which
// already bound every index by st.tl. Cursors are u32 — they widen to
// usize at the index for free, so no casts anywhere in a scan body.
std/grid:slice(lb) { logb.b }
std/grid:slice(al) { alt.b }
std/grid:slice(alo) { altt.o }
std/grid:slice(aln) { altt.l }
// rs[p]: pattern p's resume point — the next index where a match may
// start, i.e. the end of p's previous match (regex find_iter's
// non-overlapping resume, held explicitly because the scans below are
// FUSED into one pass over the buffer). c9t/c9: the email local-part
// class [a-zA-Z0-9._%+-] as a 256-entry byte table — one load instead of
// a 7-way compare per byte.
std/grid:new(rsv, size: 13) { v: 0[i64] }
std/grid:slice(rs) { rsv.v }
std/grid:slice(cv) { cnts.v }
std/grid:new(c9t, size: 256) { v: 0[u8] }
std/grid:slice(c9) { c9t.v }

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
pub tor digE { j: u32 } -> u32
digE = if(j < st.tl and lb[j] >= 48 and lb[j] <= 57)
| then |> digE(j: j + 1): r -> r
| else -> j

// nwsE — end of [^&\s"] run at j
pub tor nwsE { j: u32 } -> u32
nwsE = if(j < st.tl and lb[j] != 38 and lb[j] != 32 and lb[j] != 9 and lb[j] != 10 and lb[j] != 13 and lb[j] != 12 and lb[j] != 11 and lb[j] != 34)
| then |> nwsE(j: j + 1): r -> r
| else -> j

// alteq — match length if log[i..] equals alt entry a, else 0
// (ci: case-fold the log byte only — every ci literal in altt is
// already lowercase, so folding it again is dead work). aln[a]/alo[a]
// are i64 slice reads — loop-invariant, hoisted by LLVM; the u32 cast
// is free in ReleaseFast. Hoisting the per-char bound check into am()
// was MEASURED slower — most literals die on char 0, so the hoisted
// check is pure extra work at every call.
pub tor alteq { i: u32, a: u32, k: u32, ci: i64 } -> u32
alteq = if(k < aln[a])
| then |> if(i + k < st.tl)
        | then |> if(ci == 1)
            | then |> lowb(v: lb[i + k]): x1
                |> if(x1 == al[@as(u32, @intCast(alo[a])) + k])
                    | then |> alteq(i, a, k: k + 1, ci): r -> r
                    | else -> 0
            | else |> if(lb[i + k] == al[@as(u32, @intCast(alo[a])) + k])
                | then |> alteq(i, a, k: k + 1, ci): r -> r
                | else -> 0
        | else -> 0
| else -> @as(u32, @intCast(aln[a]))

pub tor lowb { v: u8 } -> u8
lowb = if(v >= 65 and v <= 90)
| then -> v + 32
| else -> v

// The alternation-scan machinery is FUSED: instead of 13 passes over the
// buffer, `fuse` makes one pass and a switch on the (case-folded) byte
// dispatches only to patterns that could start there. Per-pattern resume
// cursors rs[p] keep find_iter's non-overlapping-match semantics — a
// position inside p's previous match is skipped for p only.

// am — produce match-END (i + len) of literal alt a at i, or 0
pub tor am { i: u32, a: u32, ci: i64 } -> u32
am = alteq(i, a, k: 0, ci): m
    |> if(m > 0)
        | then -> i + m
        | else -> 0

// am2/am3 — first alt (pattern order) matching at i, produce end or 0
pub tor am2 { i: u32, a: u32, b: u32, ci: i64 } -> u32
am2 = am(i, a, ci): e
    |> if(e > 0)
        | then -> e
        | else |> am(i, a: b, ci): e2 -> e2

pub tor am3 { i: u32, a: u32, b: u32, d: u32, ci: i64 } -> u32
am3 = am(i, a, ci): e
    |> if(e > 0)
        | then -> e
        | else |> am(i, a: b, ci): e2
            |> if(e2 > 0)
                | then -> e2
                | else |> am(i, a: d, ci): e3 -> e3

// hit — match [i, e) of pattern p: count it, resume p at e
pub tor hit { p: u32, e: u32 } -> i64
hit = if(e > 0)
| then |> std/grid:stored { cv[p]: cv[p] + 1 }
    |> std/grid:stored { rs[p]: e }
    |> ret0(): _ -> 0
| else -> 0

// ---- per-pattern tests (produce match end or 0) ----
// t1 — " [45]dd "
pub tor t1 { i: u32, c: u8 } -> i64
t1 = if(c == 32 and i >= rs[0] and i + 4 < st.tl and (lb[i + 1] == 53 or lb[i + 1] == 52) and lb[i + 2] >= 48 and lb[i + 2] <= 57 and lb[i + 3] >= 48 and lb[i + 3] <= 57 and lb[i + 4] == 32)
| then |> hit(p: 0, e: i + 5): _ -> 0
| else -> 0

// t4 — \d+\.\d+\.\d+\.35 ; a failed start inside a digit run can
// never match (the next '.' boundary is shared), so on tail failure the
// resume point jumps to the run end — the old sc4's `sc4(i: e1)`, held
// here as rs[3] because the cursor is shared.
pub tor t4 { i: u32 } -> i64
t4 = if(i >= rs[3])
| then |> digE(j: i): e1
    |> if(e1 < st.tl and lb[e1] == 46)
        | then |> digE(j: e1 + 1): e2
            |> if(e2 > e1 + 1 and e2 < st.tl and lb[e2] == 46)
                | then |> digE(j: e2 + 1): e3
                    |> if(e3 > e2 + 1 and e3 + 2 < st.tl and lb[e3] == 46 and lb[e3 + 1] == 51 and lb[e3 + 2] == 53)
                        | then |> hit(p: 3, e: e3 + 3): _ -> 0
                        | else |> std/grid:stored { rs[3]: e1 }: _ -> 0
                | else |> std/grid:stored { rs[3]: e1 }: _ -> 0
        | else |> std/grid:stored { rs[3]: e1 }: _ -> 0
| else -> 0

// t9 — email: mc1E run, '@', domain run, last-dot + >=2 alphas.
// Fail-forward identical to the old sc9: any start inside a dead
// local-part run ends at the same byte and fails the same way, so the
// resume point jumps to the run end.
pub tor t9 { i: u32 } -> i64
t9 = mc1E(j: i): e1
    |> if(e1 < st.tl and lb[e1] == 64)
        | then |> mc2E(j: e1 + 1): e2
            |> dotbk(p: e2 - 1, lo: e1 + 1, hi: e2): m
                |> if(m > 0)
                    | then |> hit(p: 8, e: m): _ -> 0
                    | else |> std/grid:stored { rs[8]: e1 }: _ -> 0
        | else |> std/grid:stored { rs[8]: e1 }: _ -> 0

// t13 — \[\d+/\w+/\d+:1[3-7]:\d+:\d+ [+\-]\d+\]
pub tor t13 { i: u32 } -> i64
t13 = if(i >= rs[12])
| then |> digE(j: i + 1): e1
    |> if(e1 > i + 1 and e1 < st.tl and lb[e1] == 47)
        | then |> wdrE(j: e1 + 1): e2
            |> if(e2 > e1 + 1 and e2 < st.tl and lb[e2] == 47)
                | then |> digE(j: e2 + 1): e3
                    |> if(e3 > e2 + 1 and e3 + 3 < st.tl and lb[e3] == 58 and lb[e3 + 1] == 49 and lb[e3 + 2] >= 51 and lb[e3 + 2] <= 55 and lb[e3 + 3] == 58)
                        | then |> digE(j: e3 + 4): e4
                            |> if(e4 > e3 + 4 and e4 < st.tl and lb[e4] == 58)
                                | then |> digE(j: e4 + 1): e5
                                    |> if(e5 > e4 + 1 and e5 + 1 < st.tl and lb[e5] == 32 and (lb[e5 + 1] == 43 or lb[e5 + 1] == 45))
                                        | then |> digE(j: e5 + 2): e6
                                            |> if(e6 > e5 + 2 and e6 < st.tl and lb[e6] == 93)
                                                | then |> hit(p: 12, e: e6 + 1): _ -> 0
                                                | else -> 0
                                        | else -> 0
                                | else -> 0
                        | else -> 0
                | else -> 0
        | else -> 0
| else -> 0

// m5 — "/api/" then [^ "]+ : produce end or 0
pub tor m5 { i: u32 } -> u32
m5 = am(i, a: 0, ci: 0): e
    |> if(e > 0)
        | then |> apir(j: e): e2
            |> if(e2 > e)
                | then -> e2
                | else -> 0
        | else -> 0

// m6 — "POST " then [^ ]* then " HTTP" : produce end or 0
pub tor m6 { i: u32 } -> u32
m6 = am(i, a: 1, ci: 0): e
    |> if(e > 0)
        | then |> nspE(j: e): e2
            |> if(e2 + 5 <= st.tl and lb[e2] == 32 and lb[e2 + 1] == 72 and lb[e2 + 2] == 84 and lb[e2 + 3] == 84 and lb[e2 + 4] == 80)
                | then -> e2 + 5
                | else -> 0
        | else -> 0

// m10 — "password=" then [^&\s"]+ : produce end or 0
pub tor m10 { i: u32 } -> u32
m10 = am(i, a: 2, ci: 0): e
    |> if(e > 0)
        | then |> nwsE(j: e): e2
            |> if(e2 > e)
                | then -> e2
                | else -> 0
        | else -> 0

// m11 — [^&\s"]+ run from e (token/session value): produce end or 0
pub tor m11 { e: u32 } -> u32
m11 = nwsE(j: e): e2
    |> if(e2 > e)
        | then -> e2
        | else -> 0

// ---- per-byte-class dispatch tors (switch arms stay flat) ----
// dSlash — '/' : p5 "/api/x" then p7 ci "/login|/signin"
pub tor dSlash { i: u32 } -> i64
dSlash = if(i >= rs[4])
| then |> m5(i): e |> hit(p: 4, e): _ |> d7(i): r -> r
| else |> d7(i): r -> r

pub tor d7 { i: u32 } -> i64
d7 = if(i >= rs[6])
| then |> am2(i, a: 20, b: 21, ci: 1): e |> hit(p: 6, e): _ -> 0
| else -> 0

// dP — folded 'p' : p8 ci post|put, then raw 'p' -> p10 password=,
// raw 'P' -> p6 POST.
pub tor dP { i: u32, c: u8 } -> i64
dP = if(i >= rs[7])
| then |> am2(i, a: 23, b: 24, ci: 1): e |> hit(p: 7, e): _ |> dP2(i, c): r -> r
| else |> dP2(i, c): r -> r

pub tor dP2 { i: u32, c: u8 } -> i64
dP2 = if(c == 112)
| then |> if(i >= rs[9])
        | then |> m10(i): e |> hit(p: 9, e): _ -> 0
        | else -> 0
| else |> if(c == 80)
    | then |> if(i >= rs[5])
            | then |> m6(i): e |> hit(p: 5, e): _ -> 0
            | else -> 0
    | else -> 0

// dS — folded 's' : p2 ci scanner|spider, then raw 's' -> p12 session*
pub tor dS { i: u32, c: u8 } -> i64
dS = if(i >= rs[1])
| then |> am2(i, a: 12, b: 13, ci: 1): e |> hit(p: 1, e): _ |> dS12(i, c): r -> r
| else |> dS12(i, c): r -> r

pub tor dS12 { i: u32, c: u8 } -> i64
dS12 = if(c == 115 and i >= rs[11])
| then |> am3(i, a: 7, b: 8, d: 9, ci: 0): e
    |> if(e > 0)
        | then |> m11(e): e2 |> hit(p: 11, e: e2): _ -> 0
        | else -> 0
| else -> 0

// dA — raw 'a' : p11 api[_-]?key= (alts 4,5,6 = api_key|api-key|apikey)
pub tor dA { i: u32, c: u8 } -> i64
dA = if(c == 97 and i >= rs[10])
| then |> am3(i, a: 4, b: 5, d: 6, ci: 0): e
    |> if(e > 0)
        | then |> m11(e): e2 |> hit(p: 10, e: e2): _ -> 0
        | else -> 0
| else -> 0

// dT — raw 't' : p11 token=
pub tor dT { i: u32, c: u8 } -> i64
dT = if(c == 116 and i >= rs[10])
| then |> am(i, a: 3, ci: 0): e
    |> if(e > 0)
        | then |> m11(e): e2 |> hit(p: 10, e: e2): _ -> 0
        | else -> 0
| else -> 0

// t9g — the email gate: eligible (i >= resume) AND c in the c9
// local-part class. Runs unconditionally per byte — folding it into
// the switch arms (one t9g call site per local-part class byte) was
// MEASURED slower: it widened the jump table and lost to the single
// shared check site (see falsified notes in the header).
pub tor t9g { i: u32, c: u8 } -> i64
t9g = if(i >= rs[8] and c9[c] != 0)
| then |> t9(i): _ -> 0
| else -> 0


// fuse — ONE pass over the buffer. Per byte: email test (class table +
// resume gate), the " [45]dd " test, then a folded-byte dispatch into
// only the patterns that could start there. n is st.tl bound once at
// the call so the loop guard is a register compare, not a store-field
// load per byte.
pub tor fuse { i: u32, n: u32 } -> i64
fuse = if(i < n)
| then |> idv8(v: lb[i]): c
        |> lowb(v: c): cf
        |> t9g(i, c): _
        |> t1(i, c): _
        |> std/switch:char(cf)
            | `0-9` _ |> t4(i): _ |> fuse(i: i + 1, n): r -> r
            | `[` _ |> t13(i): _ |> fuse(i: i + 1, n): r -> r
            | `/` _ |> dSlash(i): _ |> fuse(i: i + 1, n): r -> r
            | `a` _ |> dA(i, c): _ |> fuse(i: i + 1, n): r -> r
            | `b` _ |> if(i >= rs[1])
                | then |> am(i, a: 10, ci: 1): e |> hit(p: 1, e): _ |> fuse(i: i + 1, n): r -> r
                | else |> fuse(i: i + 1, n): r -> r
            | `c` _ |> if(i >= rs[1])
                | then |> am2(i, a: 11, b: 15, ci: 1): e |> hit(p: 1, e): _ |> fuse(i: i + 1, n): r -> r
                | else |> fuse(i: i + 1, n): r -> r
            | `e` _ |> if(i >= rs[2])
                | then |> am(i, a: 17, ci: 1): e |> hit(p: 2, e): _ |> fuse(i: i + 1, n): r -> r
                | else |> fuse(i: i + 1, n): r -> r
            | `g` _ |> if(i >= rs[7])
                | then |> am(i, a: 22, ci: 1): e |> hit(p: 7, e): _ |> fuse(i: i + 1, n): r -> r
                | else |> fuse(i: i + 1, n): r -> r
            | `i` _ |> if(i >= rs[1])
                | then |> am(i, a: 14, ci: 1): e |> hit(p: 1, e): _ |> fuse(i: i + 1, n): r -> r
                | else |> fuse(i: i + 1, n): r -> r
            | `p` _ |> dP(i, c): _ |> fuse(i: i + 1, n): r -> r
            | `r` _ |> if(i >= rs[1])
                | then |> am(i, a: 16, ci: 1): e |> hit(p: 1, e): _ |> fuse(i: i + 1, n): r -> r
                | else |> fuse(i: i + 1, n): r -> r
            | `s` _ |> dS(i, c): _ |> fuse(i: i + 1, n): r -> r
            | `t` _ |> dT(i, c): _ |> fuse(i: i + 1, n): r -> r
            | `w` _ |> if(i >= rs[2])
                | then |> am(i, a: 18, ci: 1): e |> hit(p: 2, e): _ |> fuse(i: i + 1, n): r -> r
                | else |> fuse(i: i + 1, n): r -> r
            | `.` _ |> if(i >= rs[2])
                | then |> am(i, a: 19, ci: 1): e |> hit(p: 2, e): _ |> fuse(i: i + 1, n): r -> r
                | else |> fuse(i: i + 1, n): r -> r
            | no-match |> fuse(i: i + 1, n): r -> r
| else -> 0

// wdrE — end of \w+ run
pub tor wdrE { j: u32 } -> u32
wdrE = if(j < st.tl and ((lb[j] >= 48 and lb[j] <= 57) or (lb[j] >= 97 and lb[j] <= 122) or (lb[j] >= 65 and lb[j] <= 90) or lb[j] == 95))
| then |> wdrE(j: j + 1): r -> r
| else -> j

// apir — end of [^ "] run (no ampersand exclusion — pattern p5's
// class is [^ "], not the nws class)
pub tor apir { j: u32 } -> u32
apir = if(j < st.tl and lb[j] != 32 and lb[j] != 34)
| then |> apir(j: j + 1): r -> r
| else -> j

// nspE — end of [^ ] run
pub tor nspE { j: u32 } -> u32
nspE = if(j < st.tl and lb[j] != 32)
| then |> nspE(j: j + 1): r -> r
| else -> j

// dotbk — find the LAST '.' in (lo, hi) with >=2 trailing alphas
// (greedy domain+ backtrack; the domain needs >= 1 char before the
// dot, so p must stay strictly inside); produces hi or 0 (u32 lane —
// was -1; caller tests m > 0, same semantics)
pub tor dotbk { p: u32, lo: u32, hi: u32 } -> u32
dotbk = if(p > lo)
| then |> if(lb[p] == 46 and hi - p - 1 >= 2)
        | then |> alla(j: p + 1, hi): ok
            |> if(ok == 1)
                | then -> hi
                | else |> dotbk(p: p - 1, lo, hi): r -> r
        | else |> dotbk(p: p - 1, lo, hi): r -> r
| else -> 0

// alla — 1 if log[j..hi) all alpha
pub tor alla { j: u32, hi: u32 } -> i64
alla = if(j < hi)
| then |> if((lb[j] >= 97 and lb[j] <= 122) or (lb[j] >= 65 and lb[j] <= 90))
        | then |> alla(j: j + 1, hi): r -> r
        | else -> 0
| else -> 1

// mc1E — end of local-part run (class via the c9 table — one load)
pub tor mc1E { j: u32 } -> u32
mc1E = if(j < st.tl and c9[lb[j]] != 0)
| then |> mc1E(j: j + 1): r -> r
| else -> j

// mc2c — email domain class
pub tor mc2c { v: u8 } -> i64
mc2c = if((v >= 97 and v <= 122) or (v >= 65 and v <= 90) or (v >= 48 and v <= 57) or v == 46 or v == 45)
| then -> 1
| else -> 0

// mc2E — end of domain run
pub tor mc2E { j: u32 } -> u32
mc2E = if(j < st.tl)
| then |> mc2c(v: lb[j]): c
    |> if(c == 1)
        | then |> mc2E(j: j + 1): r -> r
        | else -> j
| else -> j

// c9r — fill c9[a..b) with 1 (build the local-part class table)
pub tor c9r { a: u32, b: u32 } -> i64
c9r = if(a < b)
| then |> std/grid:stored { c9t[a].v: 1 }
    |> c9r(a: a + 1, b): r -> r
| else -> 0

// idv8 — bind a raw byte (the select recipe's diamond shape)
pub tor idv8 { v: u8 } -> u8
idv8 -> v

// runp — the fused scan, then sum into st.tot
pub tor runp { } -> i64
runp = fuse(i: 0, n: @as(u32, @intCast(st.tl))): _
    |> sumc(i: 0): _ -> 0

// sumc — accumulate cnts into st.tot
pub tor sumc { i: u32 } -> i64
sumc = if(i < 13)
| then |> std/store:stored { st.tot: st.tot + cv[i] }
    |> sumc(i: i + 1): r -> r
| else -> 0

// clrc — reset per-run counters and resume cursors
pub tor clrc { i: u32 } -> i64
clrc = if(i < 13)
| then |> std/grid:stored { cv[i]: 0, rs[i]: 0 }
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
// c9 = email local-part class [a-zA-Z0-9._%+-]
|> c9r(a: 48, b: 58): _
|> c9r(a: 65, b: 91): _
|> c9r(a: 97, b: 123): _
|> std/grid:stored { c9t[37].v: 1, c9t[43].v: 1, c9t[45].v: 1, c9t[46].v: 1, c9t[95].v: 1 }
|> genl(i: 0): _
|> runl(k: 0): _
|> std/io:print.ln("{{ st.res:d }}")
