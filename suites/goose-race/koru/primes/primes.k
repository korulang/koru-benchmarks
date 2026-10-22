// primes — kostya/benchmarks Primes, Goose-race port (private).
// Identical workload to goose/bench/kostya2/primes/primes.goose:
//   sieve of Atkin to lim → primes to a digit trie → BFS from the node
//   prefix's digits reach → terminal primes collected, sorted, printed.
//   verify: find(100, 2) = [2, 23, 29]   scored: find(5000000, 32338)
// Layout: flat grids stand in for his arrays — tn = nodes (fc = first child
// run, nc = run length, tm = terminal), rn = the child-run arena, que = BFS
// ring-read-front queue, res = matches. His realloc_slice grows a run in
// place at the arena top and copies it forward otherwise — rnput/rnmove do
// the same. Prefixes accumulate as i64 (pf*10+digit): identical to his
// byte-string + parse_int since a leading digit is never 0.
// Field widths are i64 throughout — honest gap vs his packed 9/17-byte rows.

import std/io
import std/grid
import std/store
import std/array

std/grid:new(sieve, size: 5000001) { p: 0[u8] }
std/grid:new(plist, size: 400000) { v: 0[u32] }
std/grid:new(tn, size: 2500000) { fc: 0[u32], nc: 0[u32], tm: 0[u32] }
std/grid:new(rn, size: 2500000) { ch: 0[u8], nd: 0[u32] }
std/grid:new(que, size: 2500000) { nd: 0[u32], pf: 0[u32] }
std/grid:new(res, size: 8192) { v: 0[u32] }
std/store:new(st) { nn: 0[i64], nr: 0[i64], nq: 0[i64], fr: 0[i64], nres: 0[i64], np: 0[i64], lim: 0[i64], t1: 0[i64], t2: 0[i64], t3: 0[i64] }

pub tor ret0 {} -> i64
ret0 -> 0

pub tor idv { v: i64 } -> i64
idv -> v

// ---- sieve of Atkin (limit lim) ----------------------------------------

// x/y loop bound: smallest usize > floor(sqrt(lim)); overshoot is safe —
// the n <= lim guards inside absorb extra x/y values.
pub tor xb { lim: usize } -> usize
xb -> @as(usize, @intFromFloat(@sqrt(@as(f64, @floatFromInt(lim))))) + 1

pub tor s1 { n: usize, lim: usize }
s1 = if(n <= lim and (@rem(n, 12) == 1 or @rem(n, 12) == 5))
| then |> std/grid:stored { sieve[n].p: 1 - sieve[n].p }

pub tor s2 { n: usize, lim: usize }
s2 = if(n <= lim and @rem(n, 12) == 7)
| then |> std/grid:stored { sieve[n].p: 1 - sieve[n].p }

// x > y guards the usize subtraction left-to-right (Zig `and` is lazy)
pub tor s3 { x: usize, y: usize, lim: usize }
s3 = if(x > y and 3 * x * x - y * y <= lim and @rem(3 * x * x - y * y, 12) == 11)
| then |> std/grid:stored { sieve[3 * x * x - y * y].p: 1 - sieve[3 * x * x - y * y].p }

pub tor xstep { x: usize, lim: usize, b: usize }
xstep = for(1..b)
    ! each y |> s1(n: 4 * x * x + y * y, lim)
        |> s2(n: 3 * x * x + y * y, lim)
        |> s3(x, y, lim)

pub tor atkin { lim: usize }
atkin = xb(lim): b |> for(1..b)
    ! each x |> xstep(x, lim, b)

// omit_squares: r = 5.. while r*r < lim; strikes r², 2r², ... < lim
pub tor sq { lim: usize }
sq = std/store:stored { st.lim: @as(i64, @intCast(lim)) }
    |> xb(lim): b |> std/grid:for(5..b, sieve)
    ! each r |> if(sieve[r].p == 1)
        | then |> for(0..@as(usize, @intCast(@divTrunc(st.lim - 1, r * r))))
            ! each k |> std/grid:stored { sieve[r * r * (@as(i64, @intCast(k)) + 1)].p: 0 }

// to_list: [2, 3] + flagged p in 5..lim+1
pub tor tl { lim: usize }
tl = std/grid:stored { plist[0].v: 2 }
    |> std/grid:stored { plist[1].v: 3 }
    |> std/store:stored { st.np: 2 }
    |> std/grid:for(5..lim + 1, sieve)
        ! each p |> if(sieve[p].p == 1)
            | then |> std/grid:stored { plist[st.np].v: @as(u32, @intCast(p)) }
                |> std/store:stored { st.np: st.np + 1 }

// ---- digit trie (flat CSR) ---------------------------------------------

// largest power of ten <= p  (pw10(2)=1, pw10(23)=10)
pub tor pw10 { p: i64, pw: i64 } -> i64
pw10 = if(@divTrunc(p, pw) >= 10)
| then |> pw10(p, pw: pw * 10): r -> r
| else -> pw

// scan node head's child run for ch -> child node id or -1
pub tor chscan { head: i64, ch: i64, k: i64 } -> i64
chscan = if(k < tn[head].nc)
| then |> if(rn[tn[head].fc + k].ch == ch)
    | then |> idv(v: rn[tn[head].fc + k].nd): r -> r
    | else |> chscan(head, ch, k: k + 1): r -> r
| else -> -1

pub tor newnd {} -> i64
newnd = std/grid:stored { tn[st.nn].fc: 0 }
    |> std/grid:stored { tn[st.nn].nc: 0 }
    |> std/grid:stored { tn[st.nn].tm: 0 }
    |> std/store:stored { st.nn: st.nn + 1 }
    |> ret0(): _ -> st.nn - 1

// append (ch -> nd) at the arena top, bump nr
pub tor rnput { ch: i64, nd: i64 } -> i64
rnput = std/grid:stored { rn[st.nr].ch: @as(u8, @intCast(ch)) }
    |> std/grid:stored { rn[st.nr].nd: @as(u32, @intCast(nd)) }
    |> std/store:stored { st.nr: st.nr + 1 }
    |> ret0(): _ -> 0

pub tor cpkids { src: i64, dst: i64, k: i64 } -> i64
cpkids = if(k > 0)
| then |> std/grid:stored { rn[dst].ch: rn[src].ch }
    |> std/grid:stored { rn[dst].nd: rn[src].nd }
    |> cpkids(src: src + 1, dst: dst + 1, k: k - 1): r -> r
| else -> 0

// move head's run to the arena top, then append the new child there
pub tor rnmove { head: i64, ch: i64, nd: i64 } -> i64
rnmove = cpkids(src: tn[head].fc, dst: st.nr, k: tn[head].nc): _
    |> std/grid:stored { tn[head].fc: @as(u32, @intCast(st.nr)) }
    |> std/store:stored { st.nr: st.nr + tn[head].nc }
    |> rnput(ch, nd): r -> r

// link (head --ch--> nd); run grows in place at the top, else moves
pub tor link { head: i64, ch: i64, nd: i64 } -> i64
link = if(tn[head].nc == 0)
| then |> std/grid:stored { tn[head].fc: @as(u32, @intCast(st.nr)) }
    |> rnput(ch, nd): _
| else |> if(tn[head].fc + tn[head].nc == st.nr)
    | then |> rnput(ch, nd): _
    | else |> rnmove(head, ch, nd): _
|> std/grid:stored { tn[head].nc: tn[head].nc + 1 }: _
|> ret0(): _ -> 0

// descend head along ch, creating the child when absent -> child id
pub tor descend { head: i64, ch: i64 } -> i64
descend = chscan(head, ch, k: 0): f
    |> if(f >= 0)
        | then -> f
        | else |> newnd(): nd
            |> link(head, ch, nd): _
            |> ret0(): _ -> nd

// insert prime p's digits MSD-first; terminal on the leaf
pub tor insd { p: i64, pw: i64, head: i64 } -> i64
insd = if(pw > 0)
| then |> descend(head, ch: @rem(@divTrunc(p, pw), 10)): h2
    |> insd(p, pw: @divTrunc(pw, 10), head: h2): _ -> 0
| else |> std/grid:stored { tn[head].tm: 1 }
    |> ret0(): _ -> 0

// build the trie over plist[0..np]; node 0 is the root (made by rst)
pub tor tb {}
tb = for(0..@as(usize, @intCast(st.np)))
    ! each i |> pw10(p: plist[i].v, pw: 1): pw
        |> insd(p: plist[i].v, pw, head: 0): _

// ---- BFS from the prefix's node -----------------------------------------

// enqueue children of head with pf extended by each child's digit
pub tor enqc { head: i64, pf: i64, k: i64 } -> i64
enqc = if(k < tn[head].nc)
| then |> std/grid:stored { que[st.nq].nd: rn[tn[head].fc + k].nd }
    |> std/grid:stored { que[st.nq].pf: @as(u32, @intCast(pf * 10 + @as(i64, rn[tn[head].fc + k].ch))) }
    |> std/store:stored { st.nq: st.nq + 1 }
    |> enqc(head, pf, k: k + 1): r -> r
| else -> 0

pub tor bfsstep {} -> i64
bfsstep = if(st.fr < st.nq)
| then |> std/store:stored { st.t1: que[st.fr].nd }
    |> std/store:stored { st.t2: que[st.fr].pf }
    |> std/store:stored { st.fr: st.fr + 1 }
    |> if(tn[st.t1].tm == 1)
        | then |> std/grid:stored { res[st.nres].v: @as(u32, @intCast(st.t2)) }
            |> std/store:stored { st.nres: st.nres + 1 }
            |> enqc(head: st.t1, pf: st.t2, k: 0): _
            |> bfsstep(): r -> r
        | else |> enqc(head: st.t1, pf: st.t2, k: 0): _
            |> bfsstep(): r -> r
| else -> 0

// walk the trie along pfx's digits (no creation) -> node id or -1
pub tor pfxw { p: i64, pw: i64, head: i64 } -> i64
pfxw = if(pw > 0)
| then |> chscan(head, ch: @rem(@divTrunc(p, pw), 10), k: 0): f
    |> if(f >= 0)
        | then |> pfxw(p, pw: @divTrunc(pw, 10), head: f): r -> r
        | else -> -1
| else -> head

// ---- driver --------------------------------------------------------------

// zero sieve[0..lim]; bump allocators reset in rst (grid reuse is
// faithful — each find freshly allocates in the Goose original)
pub tor zsv { lim: usize }
zsv = for(0..lim + 1)
    ! each i |> std/grid:stored { sieve[i].p: 0 }

pub tor rst {} -> i64
rst = std/store:stored { st.nn: 1 }
    |> std/grid:stored { tn[0].fc: 0 }
    |> std/grid:stored { tn[0].nc: 0 }
    |> std/grid:stored { tn[0].tm: 0 }
    |> std/store:stored { st.nr: 0 }
    |> std/store:stored { st.nq: 0 }
    |> std/store:stored { st.fr: 0 }
    |> std/store:stored { st.nres: 0 }
    |> std/store:stored { st.np: 0 }
    |> ret0(): _ -> 0

// find(lim, pfx): full pipeline; leaves matches in res[0..nres]
pub tor find { lim: usize, pfx: i64 } -> i64
find = rst(): _ |> zsv(lim) |> atkin(lim) |> sq(lim) |> tl(lim) |> tb()
    |> pw10(p: pfx, pw: 1): pw
    |> pfxw(p: pfx, pw, head: 0): head
    |> if(head >= 0)
        | then |> std/grid:stored { que[st.nq].nd: @as(u32, @intCast(head)) }
            |> std/grid:stored { que[st.nq].pf: @as(u32, @intCast(pfx)) }
            |> std/store:stored { st.nq: st.nq + 1 }
            |> bfsstep(): _
        |> ret0(): _ -> 0

// print res one per line (the race gate normalizes token sequences)
pub tor show {}
show = for(0..@as(usize, @intCast(st.nres)))
    ! each i |> idv(v: res[i].v): v |> std/io:print.ln("{{ v:d }}")

// verify (find(100,2) = [2,23,29] — gate-visible if wrong), then scored run
find(lim: 100, pfx: 2): _ |> find(lim: 5000000, pfx: 32338): _
    |> std/array:sort(main_module.__koru_grid_res.v[0..@as(usize, @intCast(st.nres))]): _
    |> show()
