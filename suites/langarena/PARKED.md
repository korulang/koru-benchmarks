# Parked decisions — LangArena port sweep

Non-blocking items discovered while porting. Batch these when convenient;
none gate a port today. Last updated: after etc_cache_simulation
landed, 34/44 ports green.

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

7. **`|>` continuations are column-scoped** — RESOLVED. A step after
   an `if`'s arms must align with the `| then`/`| else` column; KORU010
   now names the arm column and the offending line (`1e57df218`, pins
   `210_325`/`210_326`). See #9 for the remaining trap in the same
   area.

8. **Store/grid field names collide with Zig keywords unguarded.**
   `st.fn` emitted `__koru_store_st.fn` and failed at Zig-compile time
   ("expected pointer dereference … found 'fn'"), not at a koruc
   diagnostic. *Decision needed:* reserved-word check in koruc
   (cheap teach-miss) or leave.

9. **A `|>` continuation after producing arms is silently dead code.**
   `->` inside an arm lowers to an early `return` in the handler; a
   continuation aligned at the arm column compiles cleanly but never
   executes when every arm produces (`json_parse_dom`'s `link` lost its
   `tl` write this way — verified in `output_emitted.zig`: the
   continuation sits after two `return`s). Silent unreachable user code
   is a diagnostic gap: koruc could refuse "continuation unreachable —
   every arm produces" or teach "drop `->` from the arms to let the
   chain continue." *Decision needed:* diagnostic, or accept.

9b. **PARSE005 pun check misfires on `name: name + expr` after a
    positional arg.** `pl(i, j: j + 1)` was refused "redundant explicit
    label 'j:' — the value 'j' already puns" — but `pos: pos + 1`
    (brainfuck) and `enj(i, j: j + 1)` (nbody, same file!) both compile.
    Error text also renders stale content when the line changed. Sideways
    fix used: renamed params (`bi`/`bj`) so args can't start with the
    param name. *Decision needed:* pin a red parser test and fix the pun
    detector, or leave.

10. **Grid bytes can't reach a `string` param.** `std/json:parse` wants
    `input: string`; there is no `.k` spelling that hands a grid's byte
    column to it (`doc.b[0..n]` emits undeclared Zig, `std/string:append`
    reallocs per call — 200K fragments is not a path). ParseDom works
    around it with a hand-rolled parser over the `doc` grid — honest,
    but it means `std/json:parse` is unexercised by the suite.
    *Decision needed:* a real grid→string surface (this is a toolchain
    feature, not a benchmark hack) or accept hand-rolled parsing.

10b. **Top-level `tor = if` arms swallow a same-column `|>` tail chain.**
    In `etc_cache_simulation`'s `ins`, steps written at the `| then`/
    `| else` column after the arms emitted *inside the else arm* — the
    then path fell through the `i64` function without producing (Zig
    implicit-return error, not a koruc diagnostic). Only arm-ending
    calls make a conditional terminal at top level. The arm-column
    continuation rule (#7) does not extend past a top-level armed `if`
    — that position has no "after the if." *Decision needed:* diagnose
    "no continuation after a top-level `if`" or accept the helper-tor
    pattern.

## Process / repo state

11. **Mergeback pending.** `read-arm-expr` carries the produce-arm fix
   (`a7ddcbcb3`), the `std/array:sort` template fix (`0d05d6175`), and
   the KORU010 arm-column hint (`1e57df218` + `79118140b`);
   `sweep-trusted-cursor` carries `c7442550a`. Neither is in `main`.
   The suite gates through `run.sh` on main-repo koruc; kernels are
   written to compile on main (the `-> grid[i].f` arm shape is avoided
   via store hops until `a7ddcbcb3` lands).

12. **LCG draw-order fork.** Zig `nextInt` computes `(last*max)/IM`,
    Crystal computes `last/IM*max` — ulp-boundary draws can differ.
    Verified identical on all 35000 calculator draws, all graph draws,
    all 15.6M maze shuffle draws, and all 150K json draws (oracles match
    either way); must be re-verified for any new draw-consuming task.
    If a task ever splits on it, the ports need multiply-first order.

13. **Suite runtime is Debug builds.** All numbers here are correctness
    receipts, not performance. Before any LangArena submission/perf claim:
    ReleaseFast builds, honest protocol, no mean-on-laptop numbers.
