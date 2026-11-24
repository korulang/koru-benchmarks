# osprey_kernels — vendored multi-language reference corpus

This directory is a **verbatim vendor** of the benchmark cases from the Osprey
language's public benchmark suite. It is reference material, not a Koru test —
nothing here is on the regression board.

## Source

- Language: Osprey, by Christian Findlay / Nimblesite — https://www.ospreylang.dev
  (their own published benchmark board: https://www.ospreylang.dev/benchmarks/)
- Repo: `https://github.com/Nimblesite/osprey`
- Commit: `79989f21317785b7e7870968a1facaf0a50bea13` (2026-07-01)
- Path in source: `benchmarks/`
- License: MIT — see `LICENSE.osprey` (copyright (c) 2025 Christian Findlay). The
  MIT notice is retained here to satisfy the license.

## What is here

- `cases/<name>/` — one directory per kernel. Each holds the reference
  implementation in **five languages** (`<name>.osp` Osprey, `.rs` Rust, `.c` C,
  `.ml` OCaml, `.hs` Haskell), the integer oracle `expected.txt`, and `bench.json`
  metadata (name + description).
- `run.sh`, `report.py` — Osprey's own harness (release-build compile, `hyperfine`
  timing with warmup 3 / min-runs 10, peak RSS via `/usr/bin/time`, byte-compare
  against `expected.txt`). Kept so any future Koru perf comparison can run under
  *their exact protocol* rather than an approximation.

## Why we vendored the whole corpus, not just the oracle

Two reasons, both load-bearing:

1. **Oracle.** `expected.txt` is the correctness ground truth each Koru port in
   `../koru/<name>/` must reproduce, faithfully (same naive algorithm, same
   parameters — no memoization/SIMD/algorithmic shortcut).

2. **Design input.** Koru's idioms are not settled — least of all a
   high-performance compute-kernel idiom. The five reference implementations of
   each kernel are external influence worth absorbing: when a kernel is awkward or
   impossible in pure Koru, how Osprey / OCaml / Haskell / Rust / C express it is a
   candidate idiom for Koru to adopt, not merely a spec to satisfy. The corpus is
   here to be read and argued with.


## Comparator fidelity inventory (2026-11-24 sweep)

The C references for all 22 kernels were read this session for fixed-array and
memory-lifecycle shortcuts. Seventeen scalar kernels (`ackermann`, `coins`,
`collatz`, `coprime`, `digitsum`, `factorial`, `fib`, `gcdsum`, `hanoi`,
`isqrt`, `josephus`, `mutual`, `nestedloop`, `pascal`, `powmod`, `primes`,
`tak`) contain no data-structure corner cut: their C references implement the
same scalar recurrence or loop the metadata names. `textstats` uses the fixed
vocab only to select immutable strings and still performs the string metrics;
that array is input storage, not a skipped workload structure.

Four kernels need reader-visible comparator qualifications:

- `wordfreq` — C counts `hash % 8` into `counts[8]` while `(void)vocab`
  discards the keys. It never performs the Map<string,int> aggregation the
  kernel metadata names. `wordfreq.map.c` / `cmap` is the like-for-like C
  comparator; the fixed-array C columns are memory-protocol artifacts.
- `listops` — the kernel metadata names a persistent `List<int>`, but the C
  reference uses a fixed contiguous stack array, Rust uses `Vec`, and OCaml
  uses `Array`. Those are contiguous-sequence implementations, not persistent
  list comparators. Haskell at least uses its ordinary list type.
- `binarytrees` — C does per-node malloc/free while arena-backed ports allocate
  once and reset. That is a memory-protocol mismatch, not a codegen comparison.
  `binarytrees_arena.c` / `carena` is the like-for-like C comparator.
- `exprtree` — C heap-allocates every node but never frees the tree, so unlike
  Rust's recursive drop or managed-language reclamation, teardown cost is
  absent. This is a memory-lifecycle artifact even though the node layout is
  faithful.

These qualifications are emitted into generated board metadata as
`comparator_class`/`comparator_note` on the cells they describe. They are
labels, not verdicts: the cells remain measured, and wrong answers remain
excluded.

## The 22 kernels (with oracle)

ackermann 8189 · binarytrees 19659600 · coins 116727 · collatz 10753840 ·
coprime 2433175 · digitsum 55000002 · exprtree 900720437 · factorial 682498929 ·
fib 9227465 · gcdsum 7201567 · hanoi 33554431 · isqrt 666167500 · josephus 1400177 ·
listops 15992435 · mutual 64999 · nestedloop 255643180 · pascal 20058300 ·
powmod 980475159 · primes 17984 · tak 9 · textstats 1574956 · wordfreq 900036
