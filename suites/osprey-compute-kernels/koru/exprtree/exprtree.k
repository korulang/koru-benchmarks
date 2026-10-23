// exprtree — build then modular-evaluate a random arithmetic expression
// tree, 10 iterations with rolling seeds. Faithful port of
// reference/cases/exprtree (oracle 900720437) on the oracle-checked path:
// seed line "0"/empty -> seed 1, hashAt(seed,i) = r1(r1(seed+i)) with
// r1(x) = x*16807 mod 2147483647, BIG_MOD = 1e9+7.
//
// Faithfulness differences, stated:
// - The reference's Expr = Lit|Add|Mul union becomes a flat arena —
//   a std/grid of {tag,a,b} rows, preorder-numbered exactly like
//   binarytrees (left = h+1, right = h + 2^depth). tag 0=Lit (a=value),
//   1=Add, 2=Mul (a,b = child row indexes). The hash position idx
//   (heap-order, *2+1 / *2+2) is a separate arithmetic parameter, as in
//   the reference. Arena allocated once, overwritten per iteration —
//   no allocation-pressure measurement.
// - eval is an honest recursive chase over the arena tags.
// - KNOWN GAP (same as textstats): mode "1" draws a crypto-random seed;
//   Koru stdlib has no random builtin, so nonzero seeds pass through
//   unchanged. Mode 1 is never oracle-checked.
import std/io
import std/grid

std/grid:new(arena, size: 32767) { tag: 0[i32], a: 0[i32], b: 0[i32] }

pub tor to-int { s: string } -> i64

to-int = capture { n: 0[i64] }
! as a |> for(s)
    ! each ch |> captured { n: a.n * 10 + (ch - 48) }
| captured r -> r.n

pub tor seed-of { v: i64 } -> i64

seed-of = if(v == 0)
| then -> 1
| else -> v

pub tor r1 { x: i64 } -> i64

r1 -> @rem(x * 16807, 2147483647)

pub tor hash-at { s: i64, i: i64 } -> i64

hash-at = r1(x: s + i): h1 |> r1(x: h1): h2 -> h2

pub tor build { s: i64, idx: i64, depth: i64, h: i64 } -> i64

build = if(depth == 0)
| then |> hash-at(s, i: idx): v
    |> std/grid:stored { arena[@as(usize, @intCast(h))].tag: 0,
          arena[@as(usize, @intCast(h))].a: @as(i32, @intCast(@rem(v, 1000))),
          arena[@as(usize, @intCast(h))].b: 0 }: _ -> h
| else |> hash-at(s, i: idx): v
    |> std/grid:stored { arena[@as(usize, @intCast(h))].tag: @as(i32, @intCast(1 + @rem(v, 2))),
          arena[@as(usize, @intCast(h))].a: @as(i32, @intCast(h + 1)),
          arena[@as(usize, @intCast(h))].b: @as(i32, @intCast(h + (@as(i64, 1) << @as(u6, @intCast(depth))))) }: _
    |> build(s, idx: idx * 2 + 1, depth: depth - 1, h: h + 1): _
    |> build(s, idx: idx * 2 + 2, depth: depth - 1, h: h + (@as(i64, 1) << @as(u6, @intCast(depth)))): _ -> h

pub tor eval { h: i64 } -> i64

eval = if(arena[@as(usize, @intCast(h))].tag == 0)
| then -> @as(i64, arena[@as(usize, @intCast(h))].a)
| else |> eval(h: @as(i64, arena[@as(usize, @intCast(h))].a)): l
    |> eval(h: @as(i64, arena[@as(usize, @intCast(h))].b)): r
    |> if(arena[@as(usize, @intCast(h))].tag == 1)
        | then -> @rem(l + r, 1000000007)
        | else -> @rem(l * r, 1000000007)

capture { seed: 1[i64] }
! as sd |> std/io:read-lines()
    ! line l |> to-int(s: l): v |> seed-of(v): sv |> captured { seed: sv }
    | done _ |> _
    | failed _ |> captured { sd.seed }
| captured sr |> capture { acc: 0[i64] }
    ! as a |> for(0..10)
        ! each t |> build(s: sr.seed + @as(i64, @intCast(t)) * 7, idx: 1, depth: 14, h: 0): _ |> eval(h: 0): v |> captured { acc: @rem(a.acc + v, 1000000007) }
    | captured res |> std/io:print.ln("{{ res.acc:d }}")
