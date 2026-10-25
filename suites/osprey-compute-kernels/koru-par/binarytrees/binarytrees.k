// binarytrees — allocate + checksum 1200 binary trees of depth 13.
// Faithful port of reference/cases/binarytrees (oracle 19659600).
//
// Faithfulness differences, stated:
// - The reference allocates each tree on the heap as Leaf|Node unions.
//   Koru has no recursive union types, so the tree is a flat arena —
//   a std/grid of {left,right} child indexes, preorder-numbered: node h
//   at depth d keeps left = h+1, right = h + 2^d (the left subtree holds
//   2^d - 1 rows). The arena is allocated once and overwritten per
//   iteration — this port does NOT measure allocation pressure, which is
//   what the kernel nominally stresses; it measures build+traverse only.
// - check(t) = 1 + check(left) + check(right) is run as an honest child-
//   pointer chase over the arena (same node count, same recursion shape,
//   no algebraic shortcut), so the written left/right fields are read
//   back, not elided.
import std/io
import std/grid

std/grid:new(arena, size: 16383) { left: -1[i32], right: -1[i32] }

pub tor build { depth: i64, h: i64 } -> i64

build = if(depth > 0)
| then |> std/grid:stored { arena[@as(usize, @intCast(h))].left: @as(i32, @intCast(h + 1)),
          arena[@as(usize, @intCast(h))].right: @as(i32, @intCast(h + (@as(i64, 1) << @as(u6, @intCast(depth))))) }: _
    |> build(depth: depth - 1, h: h + 1): _
    |> build(depth: depth - 1, h: h + (@as(i64, 1) << @as(u6, @intCast(depth)))): _ -> h
| else |> std/grid:stored { arena[@as(usize, @intCast(h))].left: -1,
          arena[@as(usize, @intCast(h))].right: -1 }: _ -> h

pub tor check { h: i64 } -> i64

check = if(arena[@as(usize, @intCast(h))].left >= 0)
| then |> check(h: @as(i64, arena[@as(usize, @intCast(h))].left)): l
    |> check(h: @as(i64, arena[@as(usize, @intCast(h))].right)): r -> 1 + l + r
| else -> 1

capture { acc: 0[i64] }
! as g |> [parallel]for(0..1200)
    ! each _ |> build(depth: 13, h: 0): _ |> check(h: 0): c |> captured { acc: g.acc + c }
| captured res |> std/io:print.ln("{{ res.acc:d }}")
