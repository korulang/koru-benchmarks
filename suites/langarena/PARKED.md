# Parked decisions — LangArena port sweep

Non-blocking items discovered while porting. Batch these when convenient;
none gate a port today. Last updated: after the Compress + Template
sweep landed. **2026-10-22: full-suite gate is 68/68 green on main
koruc — sort_self is green now (see #11; the mergeback landed).**

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

11. **Mergeback — RESOLVED 2026-10-22.** All four commits are in `main`
   now (`a7ddcbcb3`, `0d05d6175`, `1e57df218`, `c7442550a` — verified by
   `git merge-base --is-ancestor`). The branches still exist but their
   work is landed; `sort_self` is green and the full gate is 68/68. The
   `-> grid[i].f` produce workaround (`idv(v: grid[i].f): r -> r`) can be
   retired at leisure — no urgency since the fix it routes around is
   merged.

12. **LCG draw-order fork.** Zig `nextInt` computes `(last*max)/IM`,
    Crystal computes `last/IM*max` — ulp-boundary draws can differ.
    Verified identical on all 35000 calculator draws, all graph draws,
    all 15.6M maze shuffle draws, and all 150K json draws (oracles match
    either way); must be re-verified for any new draw-consuming task.
    If a task ever splits on it, the ports need multiply-first order.

13. **Length-only checksums can't see wrong bytes.** The Compress
    encoders accumulate `encoded.len` — compress_lzw_encode passed its
    exact oracle while emitting -1 for every len-1 code (seed dict
    entries sat in the wrong hash buckets; `st.pc` was advanced before
    the seed `lkup`, so seeds hashed unwritten pool bytes). Caught by
    compress_lzw_decode's byte-exact roundtrip gate, fixed in both
    files, encode commit amended (5d748a7). Rule of thumb for future
    encode-only tasks: checksum agreement is necessary, not
    sufficient — pin emitted content (a hash of the bytes) in the
    smoke when the scored oracle is length-only.

14. **Suite runtime is Debug builds.** All numbers here are correctness
    receipts, not performance. Before any LangArena submission/perf claim:
    ReleaseFast builds, honest protocol, no mean-on-laptop numbers.

15. **claims_descendants transforms nested in a claimed body double-fire**
    (found 2026-10-21, wiring `std/grid:for`). A `std/grid:sweep` or
    `std/grid:for` site nested inside another's `! each`/`! sweep` body —
    or inside its `| done` tail — has its generated units emitted twice
    (`duplicate struct member` at Zig compile). Reproduced with
    sweep-in-sweep, so it's the transform-runner's limitation, not the
    construct's. `grid:for` refuses the shape loudly (KORU161, "hoist the
    inner loop into a tor"). Fix belongs in the transform runner:
    generated units from an inner claimed site must not re-enter the
    outer clone's write-back path.

16. **grid-loop bodies see module scope + the cursor only.** A body that
    references a caller-scope binding (tor param, local) emits undeclared
    identifiers in the generated body event — the event handler is a
    separate proc and nothing captures the caller's frame. Worked around
    in goose-race/primes by hoisting `lim` into the module-level `st`
    store. Same limit as sweep. The range expressions are NOT affected —
    they ride in as driver-event input and lower at the call site.

17. **`==` inside a bound `if` expression emits colliding `blk:` labels**
    (found 2026-10-22, compress_bwt_encode nrn). `idv(v: if (a == b) x
    else y)` fails Zig-side with `redefinition of label 'blk'`: the
    generic equality dispatcher opens a `blk:` block, and the bound
    const's own `break :blk` wrapper reuses the same label. `<`, `>=`
    comparisons emit plain — only `==`/`!=` get the type-dispatch
    boilerplate. Worked around by keeping equality dispatch in tor-arm
    `if`s (early-return shape) and reserving bound if-expressions for
    ordered comparisons. Fix: unique label names per emission site in
    the equality/codegen path.

18. **Nested if-expressions inside `idv(...)` also collide.** Same
    mechanism as #17 — `idv(v: if c1 (if c2 x else y) else z)` puts a
    second `blk:` inside the first. Flatten to two separate bound
    if-expression binds.

19. **Stacked `[...]` annotations silently drop the grid.** A flow site
    spelled `[unsafe(bounds)][layout(row)]` parses both annotations but
    `collectIn` scans only one — the grid never registers and
    `grid:stored` downstream fails with "does not address a grid cell"
    (KORU161). Each annotation works alone. Either support multiple
    annotations per site or refuse the second loudly. (clbg_nbody
    contestant, 2026-10-22)

20. **No mid-chain value-binding step.** `|> expr: name` is refused
    (KORU103); the only spelling for a register-resident local inside a
    chain is a `std/store` scratch row round-trip or `idv` tor bounce.
    A bind step that stays in-registers would let loop-carried values
    spell themselves without the store. (clbg_nbody contestant)

21. **store:stored emits a non-inline handler + field-enum dispatch per
    write.** Every hot store-row update pays a call plus a switch on
    the field tag (compress_arith_decode disasm, 2026-10-22). Emitting
    the write as a direct `__koru_store_st.f = v` (or making the
    handler `pub inline`) would keep store rows cheap for state that
    can't param-carry. Contestant proposal, judged worth fixing.

22. **No certified-unchecked read on plain `grid[i]`.** Programs that
    can't use `std/grid:slice` still pay `__koru_at` panic-path reads
    per access. A `0[grid]`-style certified index or documented
    unchecked-read spelling would close it. (arith_decode contestant)

23. **std/fmt float `{d:.N}` costs ~48ns/call.** bufPrint dominates
    any formatting-heavy task (86% of json_generate's 0.40s). An
    int->decimal emit helper or a fixed-precision fast path in
    koru_std would pay across the suite. (json_generate contestant)

24. **`std/array:sort` should gain an integer radix path.** sort_self's
    wave-3 contestant replaced `std.mem.sort`->pdq with a pure-.k 2-pass
    LSD radix (16-bit digits, sign-biased hi digit — full i32 domain)
    and went 1.19s -> 0.080s, 0.31x vs Rust driftsort. On integer keys
    a distribution sort beats every comparison sort Zig ships.
    *Decision needed:* route integer-element sorts to an LSD radix in
    the std/array template (needs a type-gated path + scratch), expose
    `std/sort:radix` as a separate surface, or leave it per-kernel.
    (sort_self contestant, 2026-10-22; judged correct, not yet ported)

25. **A `for`'s `| done` continuation cannot host another `for|done`**
    (SHAPE002). One unguarded done per chain level; sequencing counted
    phases forces tor self-loops. Cosmetic — scalar work survives — but
    it pushes real loops into hand-rolled tails. (sort_self contestant)

26. **Slice write sites need `@as(usize, @intCast(...))` ceremony** even
    when the index is provably narrow (i32 digit values used as usize
    positions). Cosmetic; a narrow-int index acceptance would declutter
    every radix/counting kernel. (sort_self contestant)

27. **No "hot tor failed to inline" diagnostic.** The raytracer
    contestant found a 0.63s -> 0.68s regression only by disassembling:
    moving shading into a hit arm made the handler transitively too
    large and LLVM stopped inlining it — three real calls per pixel. A
    koruc warning at emit or a size threshold report would have caught
    it at compile time. (text_raytracer contestant, 2026-10-22)

28. **`[layout(row)]` cannot produce row-view slices.** Interleaved
    per-pixel data had to be spelled as a flat f64 column + manual
    k*3 stride — a `std/grid:slice` variant that borrows row-structured
    records would express it directly. (text_raytracer contestant)

33. **`std/grid:slice` on a certified-index field emits
    `use of undeclared identifier '__koru_idx_cells'`** — the generated
    slice type name is unqualified. Workaround: keep the grid
    certified (writes pay the floor, reads raw). (maze_bfs contestant,
    2026-10-22)

34. **Certified u21 stores spill-reload** — `strh`/`ubfx`/`strb` bounce
    (~7 instrs) in cold paths; a direct 3-byte store or insert-style
    lowering would help swap-heavy code. (maze_bfs contestant)
