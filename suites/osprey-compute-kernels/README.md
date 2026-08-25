# osprey-compute-kernels

22 naive compute kernels — integer recursion, folds, and data-structure stress —
each ported to Koru and checked against an integer oracle. The reference
implementations (seven languages per kernel — C, Rust, OCaml, Haskell, C3 and
Odin for the cross-language drag-race; Osprey is the native speaker) and
provenance live in `reference/`
(see `PROVENANCE.md`; vendored MIT from the
[Osprey benchmark suite](https://www.ospreylang.dev/benchmarks/)). Osprey is a
language by Christian Findlay / Nimblesite — <https://www.ospreylang.dev>
([source](https://github.com/Nimblesite/osprey)).

Faithful port: same naive algorithm, same parameters as the reference — no
memoization, no SIMD, no algorithmic shortcut. `expected.txt` in each `koru/<name>/`
is the reference oracle, unchanged.

## Board (provisional — only run-verified rows are marked SHOWN)

Only kernels with a `koru/<name>/` port have been built through `koruc`. The rest
are a *projected* classification of what each kernel will need — a work list, not
a result. Run `../../run.sh` for the real, current board.

**Run-verified**

- `josephus` — **GREEN (SHOWN)** `1400177`. Scalar capture-fold over `for(2..N)`.
  Surfaced the `usize`/`i64` loop-variable bridge (fixed in-port via `@as(i64,
  @intCast(i))`; the raw-Zig-error leak is floated as a core-pin candidate).

**Projected: single-accumulator / linear-recursion folds** (the `capture { acc }
! as a |> for(a..b) ! each i |> captured { acc: … }` idiom — expected portable)

- `factorial`, `digitsum`, `gcdsum`, `collatz`, `mutual`, `isqrt`, `powmod`,
  `primes`, `coprime`, `nestedloop`

**Projected: non-tail tree recursion** (combine *two* recursive results, e.g.
`fib(n-1)+fib(n-2)`) — not a tail self-continuation, so it does not flatten to a
loop; the interesting frontier for how Koru expresses/runs non-tail recursion

- `fib`, `hanoi`, `ackermann`, `tak`, `pascal`, `coins`

**Projected: blocked on an absent language feature** (each names a real gap)

- `binarytrees`, `exprtree` — recursive **algebraic/union types** with record
  variants + destructuring `match` (absent in pure Koru today)
- `textstats` — **RED (SHOWN)** `1574956`. Static text scan (string length /
  `contains` / `startsWith`). Migrated `event`→`tor` and `[]const u8`→`string`,
  but the seed-into-outer-capture refeed still trips the current punging rule
  (KORU164 "captured: punning is mandatory") — a live idiom gap, not the
  originally-projected missing string builtins.

**Run-verified beyond the fold** (where "run-verified" means the kernel compiles
through current `koruc` and matches its oracle):

- `wordfreq` — **GREEN (SHOWN)** `900036`. The first allocation-bearing kernel.
  Naive form is a 200k-iteration `Map<string,int>` HAMT aggregation through
  `std/string-map`; Koru (4.5 ms) beats Rust/C3/Odin on the identical workload.
  The reference C column cheats by never allocating (fixed `counts[8]`), so a
  dedicated **`cmap`** variant column (`wordfreq.map.c`, a hand-rolled chained
  string map with real hashing) measures what plain C actually costs at this
  kernel: ~3.2 ms — still ahead of Koru, but the gap is ~1.4x, not ~2.2x, and
  C's "win" is the map, not the language. Port was previously listed as
  "blocked"; it landed behind a one-line `event`→`tor` migration.
- `wordfreq` **fold (`koru-fold` column)** — **GREEN (SHOWN)** `900036`, beats
  the whole board at **1.8 ms**. The weighted checksum `sum((k+1)*counts[k])`
  telescopes to `sum(bucket_i+1)`, so the counter table never needs to exist:
  one branchless fold over the token stream. This is the same algebraic
  reduction clang applies to the C reference — and Koru's Zig IR produces the
  same magic-numbered, branchless inner loop, so the fold *matches and edges*
  cheat-C (2.0 ms). Faithfulness note: it is not a changed algorithm — it is
  the map the oracle's own structure hides.

## The `koru-fold` column

`koru-fold` is the flat fold / algebraic-identity variant of a kernel — the
reduction the oracle actually computes, stripped of any data structure the
naive form carries for faithfulness. It exists as a **distinct column** only
where it differs from the faithful port:

- **`wordfreq`** — distinct: faithful port is a string-map; the fold is the
  telescoped checksum (above). The only kernel where the identity exists.
- Kernel classes that do NOT get a fold cell: single-accumulator kernels
  whose faithful port *already is* the flat fold (`digitsum`, `factorial`,
  `gcdsum`, `isqrt`, `josephus`, `nestedloop`, `powmod`, `primes`, `mutual`,
  `collatz`) — a fold column there would be the same binary twice; and the
  genuinely recursive kernels (`fib`, `hanoi`, `ackermann`, `tak`, `pascal`,
  `coins`) where flattening would change the algorithm the suite preserves.
  The infrastructure is wired for all kernels; a cell appears only when an
  honest fold realization exists.

## Oracles

## Oracles

ackermann 8189 · binarytrees 19659600 · coins 116727 · collatz 10753840 ·
coprime 2433175 · digitsum 55000002 · exprtree 900720437 · factorial 682498929 ·
fib 9227465 · gcdsum 7201567 · hanoi 33554431 · isqrt 666167500 · josephus 1400177 ·
listops 15992435 · mutual 64999 · nestedloop 255643180 · pascal 20058300 ·
powmod 980475159 · primes 17984 · tak 9 · textstats 1574956 · wordfreq 900036
