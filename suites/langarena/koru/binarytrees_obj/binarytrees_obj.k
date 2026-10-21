// LangArena Binarytrees::Obj — crystal-lang / reference/binarytrees_obj.*
//
// Object-flavor binary tree on the `[tree]` store substrate: rows are heap
// nodes and the store synthesizes a `parent` self-FK (per 690_048). Where the
// arena port stores branded child handles in `left`/`right` columns, this one
// attaches children by writing their `parent` — the object-graph direction.
//
// Scored params (run.js): depth = 20, iterations = 30, warmup = 6 → 36
//   accumulated sums of (item+1) over all nodes. depth 20 → 2^21-1 = 2097151
//   nodes; expected checksum 75497436. Smoke params (test.js): depth = 4,
//   iterations = 3 (+1 warmup) → 31 nodes × 4 = 124.
//
// Substrate note (honest gap, not hidden): `std/store:preorder` walks the
// self-FK with a capacity-sized stack-local DFS buffer (segfaults at
// capacity ~2M) and an O(len²) full-scan children lookup — unusable at scored
// size. The checksum is order-free (Σ(item+1) over all rows), so a row
// `query` computes the identical sum in O(len) and is the honest equivalent.

import std/io
import std/store

[tree]std/store:new(tree, capacity: 2097151) { item: i64 }
std/store:new(res) { acc: 0[i64] }

// build(item, depth) — inserts the node row, recurses for children, and
// attaches each child by writing its synthesized `parent` link. The [tree]
// store's self-FK substrate holds the object graph; parent links point
// child→parent, the mirror of the arena port's left/right handles.
pub tor build { item: i64, depth: i64 } -> i64
build = std/store:insert(tree) { item }
| row h |> if(depth > 0)
    | then |> build(item: item - (@as(i64, 1) << @as(u6, @intCast(depth - 1))), depth: depth - 1): l
        |> build(item: item + (@as(i64, 1) << @as(u6, @intCast(depth - 1))), depth: depth - 1): r
        |> std/store:stored { tree[l].parent: h }
        |> std/store:stored { tree[r].parent: h } -> h
    | else -> h

// for(0..36) — 6 warmups + 30 iterations: clear the arena, build a depth-20
// tree, visit every row folding (item + 1) into the u32 checksum.
for(0..36)
! each _ |> std/store:clear(tree)
    |> build(item: 0, depth: 20): root
    |> std/store:query(tree)
        ! query s |> std/store:stored { res.acc: @rem(res.acc + s.item + 1, 4294967296) }

std/io:print.ln("{{ res.acc:d }}")
