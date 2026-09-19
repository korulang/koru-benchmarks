# iteration-models

One task shape — filter → map → sum, early exit, producer/consumer split —
written in each language's idiomatic iteration model, on the same machine.

## Cases (N = 10_000_000, bound = 10_000_000 + argc unless noted)

| case | task | oracle |
|---|---|---|
| fms-range | lazy range, filter evens, map ×3, sum | 75000015000000 |
| fms-array | same over materialized array | 75000015000000 |
| fms-hash | range, hash-pred filter `(i·89478611)%97<60`, map ×3, sum | 92783524020606 |
| find-tail | first i > N−3 (analytic pred, ~N visits) | 9999998 |
| producer-split | yield-analog producer → consumer sums replies ×3 | 75000015000000 |

`fms-hash` is the anti-fold control: the predicate can't be closed-formed, so
the loop must actually run. `fms-array` is the memory-bound control.

## Columns

| column | model |
|---|---|
| koru | `for`/`!`-pulse protocol, literal bound (comptime-visible trip count) |
| koru-opaque | same, bound via `std/args:count()` — runtime trip count |
| zig | plain `for` (the floor Koru emits toward) |
| rust | `Iterator` chains (`iter().filter().map().sum()`) |
| rust-iter | hand-written `Iterator` impl — the pull-model yield analog |
| cpp | `std::ranges` views / hand iterator |
| csharp | LINQ / `yield` (compiled, net8.0 Release) |
| fsharp | `Array`\|`Seq` / `seq {}` (compiled, net8.0 Release) |
| swift | `lazy` sequences / `sequence(state:)` |
| node | generators, `for-of` |
| python | generator expressions |

Go, Java: toolchains absent on the reference machine — cells report `absent`.

## Protocol

Internal best-of-7 per program (process spawn ~5-15ms would dominate the fast
rows — different from the Osprey board's hyperfine-per-process on purpose).
Every program prints `RESULT <checksum> <best_ms>`; the harness verifies the
checksum against the oracle before recording a time. A wrong answer is
excluded; a missing toolchain reports `absent`.

## Run

    ./bench-iter.sh [filter]

Results land in `../../results/iteration-models-latest.json`.
