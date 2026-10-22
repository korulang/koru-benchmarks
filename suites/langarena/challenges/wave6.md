# Wave 6 — commissioned 2026-10-22

Common rules: identical to wave4.md/wave5.md — checksum first, min-of-5
whole-process, header documents faithfulness + falsified hypotheses,
name /tmp verification artifacts, no commits, no deletions, pure .k.

THE PREMISE IS DIFFERENT: every task below is already AHEAD. Nobody
has proven they are at their floor. Wave-5 taught that every claimed
floor on this suite was a representation assumption — your job is
"prove the floor or break it." A survived proof is a valid landing;
a break is a better one.

Proven wave-4/5 shapes to check first: byte/word packing (fkr),
domain-encoded cells + epoch inversion (maze*, graph_astar), 16-bit
transition LUTs (huff_decode), delta-select char maps (base64*),
i64 bitsets (jaro), stride-batched serial chases (bwt_decode),
algebraic loop folding (bfr), closed-form membership (mandelbrot),
radix substitution (sort_*).

## compress_huff_encode — 0.76s vs Rust 0.771s = 0.99x
Sibling decoder just went 0.35x via transition tables — is there a
per-symbol or per-word emit path faster than bit-at-a-time append?
Oracle: expected.txt.

## compress_lzw_decode — 0.56s vs Rust 0.570s = 0.98x
u8 lanes + slice copies landed. String-table decode has a serial
prefix-chain per code — can entries be resolved without the walk
(materialized strings, parent-pointer shortcutting, batch copies)?
Oracle: expected.txt.

## etc_sieve — 0.86s vs Rust 0.945s = 0.91x
Oracle: expected.txt.

## sort_merge — 1.11s vs Rust 1.292s = 0.86x
Slice merge walks landed. sort_quick/sort_self both went ~0.07-0.31x
via radix substitution — the checksum pins sorted output only, so the
same substitution is legal here. Verify that claim yourself first.
Oracle: expected.txt.

## etc_neural_net — 0.74s vs Rust 0.861s = 0.86x
Matrix/activation compute — same FMA family as matmul/nbody.
Oracle: expected.txt.

## compress_arith_decode — 0.98s vs Rust 1.169s = 0.84x
Oracle: expected.txt.

## graph_bfs — 0.53s vs Rust 0.646s = 0.82x
Oracle: expected.txt.

## calculator_interpreter — 0.45s vs Rust 0.553s = 0.81x
An interpreter — brainfuck_recursion went ~0x via parse-time
algebraic folding. Check whether expression evaluation has a
fold/compile step available (bytecode, constant folding, fused
dispatch) that stays semantics-exact. Oracle: expected.txt.

## clbg_nbody — 0.65s vs Rust 0.829s = 0.78x
[layout(row)] AoS + register fields landed. Compute-bound;
what remains is force-pair math throughput. Oracle: expected.txt.
