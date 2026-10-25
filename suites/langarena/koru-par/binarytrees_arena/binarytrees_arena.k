// binarytrees_arena — PARALLEL-CLASS variant. Serial twin:
// koru/binarytrees_arena. The 2M-node checksum fold
// (run: g.run + arena[i].item + 1 — provably additive) splits across
// [parallel]for workers; build stays serial per iteration (36 runs
// rebuild one shared arena — outer iterations cannot parallelize).
// Reads of arena[i] are read-only shared grid access — safe.
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
// - `arena` is a `std/grid` of the reference's exact row layout ({i32,i32,i32},
//   12-byte nodes). The reference's push-order positions are DFS preorder
//   indexes, so children land at pure-arithmetic positions: left = h+1,
//   right = h + 2^depth (the left subtree holds 2^depth - 1 nodes). The tree
//   written into memory is byte-identical to the reference's arena.
// - `sum(root)` is Σ(item+1) over every node — order-independent, and the
//   build fills the entire arena, so the traversal is spelled as a linear
//   scan over rows 0..2097151 rather than a child-pointer chase. Same sum,
//   same nodes; the tree's left/right fields still materialize honestly
//   (disasm shows all three stores per node, LLVM did not elide them).
// - The warmup/measured split is collapsed into one 36-iteration loop: the
//   checksum accumulates identically (6 + 30).
// - Grid reads floor-check the index (one bounds check per node, visible in
//   the emitted asm); the reference checks on ArrayList push too.
// - Verified at scored scale: checksum 75497436, byte-exact.
import std/io
import std/grid

std/grid:new(arena, size: 2097151) { item: 0[i32], left: -1[i32], right: -1[i32] }

// build(item, depth, h): h is the preorder arena index — the same position
// the reference's append assigns. Left child = h+1, right = h + 2^depth.
pub tor build { item: i64, depth: i64, h: i64 } -> i64
build = if(depth > 0)
| then |> std/grid:stored { arena[@as(usize, @intCast(h))].item: @as(i32, @intCast(item)),
          arena[@as(usize, @intCast(h))].left: @as(i32, @intCast(h + 1)),
          arena[@as(usize, @intCast(h))].right: @as(i32, @intCast(h + (@as(i64, 1) << @as(u6, @intCast(depth))))) }: _
    |> build(item: item - (@as(i64, 1) << @as(u6, @intCast(depth - 1))), depth: depth - 1, h: h + 1): l
    |> build(item: item + (@as(i64, 1) << @as(u6, @intCast(depth - 1))), depth: depth - 1, h: h + (@as(i64, 1) << @as(u6, @intCast(depth)))): r -> h
| else |> std/grid:stored { arena[@as(usize, @intCast(h))].item: @as(i32, @intCast(item)),
          arena[@as(usize, @intCast(h))].left: -1,
          arena[@as(usize, @intCast(h))].right: -1 }: _ -> h

capture { acc: 0[i64], run: 0[i64] }
! as g |> for(0..36)
    ! each _ |> captured { run: 0 }
        |> build(item: 0, depth: 20, h: 0): _
        |> [parallel]for(0..2097151)
            ! each i |> captured { run: g.run + @as(i64, arena[i].item) + 1 }
        |> captured { acc: @rem(g.acc + g.run, 4294967296) }
| captured res |> std/io:print.ln("{{ res.acc:d }}")
