# Parked decisions — LangArena port sweep

Non-blocking items discovered while porting. Batch these when convenient;
none gate a port today. Last updated: after calculator_* commits (413ebbe),
18/40 ports green.

## Toolchain / language

1. **`std/store:preorder` is unusable at scale.** Emits a capacity-sized
   DFS buffer on the stack (`__koru_stack: [cap]usize` — 16.7MB at 2M,
   segfaults) and resolves children by full scan → O(len²). `binarytrees_obj`
   documents it in-source and uses parent-FK + row `query` instead.
   *Decision needed:* stack-buffer patch (small) vs children-index on the
   self-FK (substrate design). Status: deferred.

2. **Tail-call lowering breadth.** Only self-calls with direct `-> r`
   returns lower to loops. `-> {r.i, r.j}` projections and mutual
   recursion emit real calls (both burned us as stack overflows at
   scored size). Ports restructure around it honestly, but widening the
   lowering — mutual tail calls at minimum — would unlock more idiomatic
   ports. *Decision needed:* widen lowering or keep the constraint.

3. **`for` inside tor bodies.** `for`/`! each` is flow-surface only; tor
   bodies need hand-rolled tail tors for every loop. This is why the
   parser/emitter tors exist at all. Works, but verbose.
   *Decision needed:* language feature or accepted shape.

4. **Recursion-depth failures are silent SIGSEGVs.** A non-lowered tail
   call at 500K depth crashes with no diagnostic; found by bisecting
   emitted code. A depth counter or call-site warning would have saved
   the bisect. *Decision needed:* diagnostic instrumentation or leave.

5. **`->` produce-tail position rule.** After a `|>` step, produce only
   parses when the step is a tor call (`call(): _ -> expr`); a
   `std/store:stored` step in the same position gives PARSE001, and the
   diagnostic doesn't say why. Worked around with single-step helper
   tors. *Decision needed:* widen the grammar or better diagnostic.

6. **`| done` binds by indentation column.** Misaligned `done` silently
   attaches to the wrong loop (two checksum bugs caught this way — loud
   failure, but only because we checksum). *Decision needed:* accept
   (column-scoped is the design) or revisit.

## Process / repo state

7. **Mergeback pending.** `read-arm-expr` carries the produce-arm fix
   (`a7ddcbcb3`) and the `std/array:sort` template fix (`0d05d6175`);
   `sweep-trusted-cursor` carries `c7442550a`. Neither is in `main`.
   Every port so far runs against the readfix compiler.

8. **LCG draw-order fork.** Zig `nextInt` computes `(last*max)/IM`,
   Crystal computes `last/IM*max` — ulp-boundary draws can differ.
   Verified identical on all 35000 calculator draws and all graph draws
   (oracles match either way); must be re-verified for any new
   draw-consuming task. If a task ever splits on it, the ports need
   multiply-first order.

9. **Suite runtime is Debug builds.** All numbers here are correctness
   receipts, not performance. Before any LangArena submission/perf claim:
   ReleaseFast builds, honest protocol, no mean-on-laptop numbers.
