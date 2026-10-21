// binarytrees_arena — LangArena Binarytrees::Arena, run.js scored parameters
// (depth=20, iterations=30, warmup_iterations=max(30*0.2,1)=6 → 36 checksum
// accumulations, oracle 75497436).
//
// Faithful port of reference/zig/binarytrees.zig BinarytreesArena:
//   arena:   ArrayList of { item: i32, left: i32, right: i32 } nodes
//   build:   append node (left/right = -1); if depth > 0 recurse left at
//            item - 2^(depth-1) and right at item + 2^(depth-1), then write
//            the child indexes back into the parent row
//   run:     arena = empty; root = build(0, depth); result_val += sum(root)
//   sum:     node.item +% 1 plus each present child's sum
//
// Faithfulness differences, stated:
// - `arena` is a plural `std/store` — its row handles ARE the reference's
//   arena indexes (branded values, so `left`/`right` hold real handles, never
//   raw positions). `std/store:clear` is the per-run `arena = .empty`.
// - The warmup/measured split is collapsed into one 36-iteration loop: the
//   checksum accumulates identically (6 + 30; the sieve kernel documents the
//   same collapse, verified byte-exact at test.js scale).
// - Item arithmetic is i64 (the reference wraps i32; node items fit i32
//   easily, and wrapping arithmetic is a ring — the u32 truncation at the
//   accumulator produces the identical low 32 bits).
// - Capacity is pinned at 2097151 = 2^21 - 1, the exact node count of a
//   depth-20 tree; the reference's ArrayList grows dynamically, the store's
//   capacity is declared — same rows, same arithmetic.
// - Verified at test.js scale (depth=4, iters=3 → 4 accumulations): 124,
//   byte-exact.
import std/io
import std/store

std/store:new(arena, capacity: 2097151) { item: i64, left: -1[i64], right: -1[i64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// idv — produce a computed value. Grid reads in a produce (`->`)
// expression emit raw identifiers on main koruc (the readfix lowering
// is parked); routing the expression through a call arg lowers it.
pub tor idv { v: i64 } -> i64
idv = ret0(): _ -> v

pub tor build { item: i64, depth: i64 } -> i64
build = std/store:insert(arena) { item, left: -1, right: -1 }
| row h |> if(depth > 0)
    | then |> build(item: item - (@as(i64, 1) << @as(u6, @intCast(depth - 1))), depth: depth - 1): l
        |> build(item: item + (@as(i64, 1) << @as(u6, @intCast(depth - 1))), depth: depth - 1): r
        |> std/store:stored { arena[h].left: l, arena[h].right: r } -> h
    | else -> h

pub tor tsum { h: i64 } -> i64
tsum = if(arena[h].left >= 0)
| then |> tsum(h: arena[h].left): ls
    |> tsum(h: arena[h].right): rs
    |> idv(v: arena[h].item + 1 + ls + rs): r -> r
| else |> idv(v: arena[h].item + 1): r -> r

capture { acc: 0[i64] }
! as g |> for(0..36)
    ! each _ |> std/store:clear(arena)
        |> build(item: 0, depth: 20): root
        |> tsum(h: root): s
        |> captured { acc: @rem(g.acc + s, 4294967296) }
| captured res |> std/io:print.ln("{{ res.acc:d }}")
