# Wave 5 — commissioned 2026-10-22

Common rules (all briefs): identical to wave4.md — checksum first,
min-of-5, disclose faithfulness + falsified hypotheses in the header,
name /tmp verification artifacts, no commits, no deletions, pure .k.

These are the LAST deficits — each already had at least one
optimization pass (huff_decode, bwt_*, base64_* had deep attacks with
"floors" claimed). Wave-4 proved claimed floors can be wrong twice
over: mandelbrot's serial-latency "floor" fell to exact closed-form
math (cardioid test), brainfuck_recursion's dispatch "floor" fell to
algebraic loop folding (0x — 280x). The standing question for every
task below is not "shave instructions" but "is there a representation
or closed form that collapses the serial work?" Byte-packing
(fannkuchredux), domain-encoded cells (maze_bfs p-field), closed-form
membership (mandelbrot), algebraic folds (bfr), magic division
(arith_encode) are the proven shapes.

If the floor is REAL, the right answer is the measured proof of it —
a falsified-hypothesis entry that survives judging, like bwt_decode's
latency-chase bound. Do not manufacture a win; do not hide a loss.

## compress_huff_decode — 1.07s vs Rust 0.733s = 1.46x
Prior attack: register-carried bit walk + u8 + tree-once. Claimed
floor: bit-by-bit serial decode shared with Rust. Wave-5 question:
can the bitstream be decoded multi-symbol per word (canonical-Huffman
table decomposition, first-level lookup + residual walk), or is the
code structure non-canonical? Oracle: expected.txt.

## compress_bwt_decode — 1.36s vs Rust 0.972s = 1.40x
Prior attack: serial LF-map pointer chase, latency-bound, bandwidth
recipes falsified. Wave-5 question: LF-chase IS serial in the chain —
but can it be batched (decode N symbols per pass via precomputed
LF^k strides), vectorized per block, or restructured (sampling + local
chase)? If provably latency-bound, prove it tighter. Oracle: expected.txt.

## compress_bwt_encode — 0.46s vs Rust 0.322s = 1.43x
Prior attack: combined-key radix + rank-bound buckets. Wave-5
question: the Rust side sorts pairs via driftsort per round; ours is
a counting radix. Residual candidates: induced sorting (SA-IS lite),
early-exit on rank stabilization, or u8/i32 lane narrowing on the
suffix array itself. Oracle: expected.txt.

## graph_astar — 0.44s vs Rust 0.343s = 1.28x
One pass done (slices + param heap). Heap-churn-bound like maze_astar
(0.72x now) — check whether the maze_astar contestant's tricks port:
u32 heap indices, packed cell fields, register-carried heap size.
Oracle: expected.txt.

## base64_encode — 0.32s vs Rust 0.258s = 1.24x
Prior attack: LUT falsified (dependent loads lose to predicted ladder
on all-'a' input). Residual: the alphabet lookup is the serial piece.
Wave-5 question: SWAR arithmetic encoding (map 6-bit -> ASCII via
mul/shift tricks, no branches, no loads)? Or is the input distribution
the real story — measure under mixed input. Oracle: expected.txt.

## sort_quick — 1.24s vs Rust 1.060s = 1.17x
One pass done (slice partition scans). Note sort_self's radix won the
family at 0.27x — quicksort's pivot compares may have the same
distribution-sort answer available (the harness shares data prep).
Check faithfulness first: the checksum may pin traversal order.
Oracle: expected.txt.

## distance_jaro — 1.10s vs Rust 0.938s = 1.17x
One pass done (param scan state + slices). Wave-5 question: bitset
match windows (Jaro's w/2 window is a bitmask problem — the Rust side
may do it scalar while bit-parallelism is available in .k).
Oracle: expected.txt.

## base64_decode — 0.30s vs Rust 0.276s = 1.09x
Walk windows + bound-if selects landed. Residual likely small;
table-ize the reverse alphabet (128B LUT vs the compare ladder —
the encode-side LUT failed on predictable input, decode input differs).
Oracle: expected.txt.

## etc_logparser — 0.33s vs Rust 0.310s = 1.07x
Was 9.6x, landed ~parity via fused single-pass scanner. Residual is
small; check per-phase timing before committing effort. Oracle:
expected.txt.
