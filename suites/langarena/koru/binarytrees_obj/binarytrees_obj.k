// LangArena Binarytrees::Obj — crystal-lang / reference/binarytrees_obj.*
//
// Object-flavor binary tree on `std/tree`: real owned heap nodes declared in
// pure .k — `std/tree:node(Node)` registers the kind, `mint` creates each
// node (`*Node<owned!>`), `dispose` consumes the root and frees recursively.
// This port replaces the `[tree]`-store-row version: the store's parent-FK
// substrate was a stand-in for the thing this kernel means — an object graph.
//
// Scored params (run.js): depth = 20, iterations = 30, warmup = 6 → 36
//   accumulated sums of (item+1) over all nodes. depth 20 → 2^21-1 = 2097151
//   nodes; expected checksum 75497436. Smoke params (test.js): depth = 4,
//   iterations = 3 (+1 warmup) → 31 nodes × 4 = 124.
//
// The each-body is hoist-clean: `build |> sum |> dispose` never reads the
// item, so the invariant prefix lifts onto `| done` — one tree built, folded,
// and freed; the loop carries only the accumulate.

import std/io
import std/tree

std/tree:node(Node) { item: i64, left: ?Node, right: ?Node }

// build(item, depth) — mints the node with fresh children as owned edges.
// Items step ±(1 << (depth-1)) per level — the LangArena checksum shape.
pub tor build { item: i64, depth: i64 } -> *Node<owned!>
build = if(depth > 0)
    | then |> build(item: item - (@as(i64, 1) << @as(u6, @intCast(depth - 1))), depth: depth - 1): l
           |> build(item: item + (@as(i64, 1) << @as(u6, @intCast(depth - 1))), depth: depth - 1): r
           |> std/tree:mint(Node) { item, left: l, right: r }: h -> h
    | else |> std/tree:mint(Node) { item, left: null, right: null }: h -> h

// sum — the order-free checksum fold: Σ(item + 1) over all nodes.
pub tor sum { t: ?*Node<*> } -> i64
sum = if(t != null)
    | then |> sum(t: t.?.left): l |> sum(t: t.?.right): r -> t.?.item + 1 + l + r
    | else -> 0

// for(0..36) — 6 warmups + 30 iterations: build a depth-20 tree, fold
// (item + 1) into the u32 checksum, dispose.
capture { acc: 0[i64] }
! as g |> for(0..36)
    ! each _ |> build(item: 0, depth: 20): t
        |> sum(t): c
        |> std/tree:dispose(t): _
        |> captured { acc: @rem(g.acc + c, 4294967296) }
| captured res |> std/io:print.ln("{{ res.acc:d }}")
