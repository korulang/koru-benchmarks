# koru-benchmarks

A repository of **benchmarks that consume [Koru](https://github.com/korulang/koru)**
as a downstream user would — importing the toolchain and building real kernels
with it. It is deliberately *not* part of the core `koru` repo, so the core
regression suite stays fast and this body of work can grow on its own.

## Why this is separate

- **Keep the core suite slim.** These kernels are built to *run* — many iterate
  to millions of steps. They do not belong in koru's per-commit `MUST_RUN` suite,
  where they would add real wall-clock to every run.
- **Dogfood the toolchain.** Building kernels here exercises `koruc` the way an
  actual user does — that is signal the in-repo tests cannot give.
- **A home for the whole benchmark story.** Over time this is where the
  cross-language benchmark work lives together (compute kernels first; the
  sieve drag-race, the `std/kernel` nbody suite, and the effect-branch workloads
  migrate in gradually), feeding one Benchmarks section on the website.

## The ordering — toolchain first, always

The Koru toolchain is the priority. These benchmarks are **instruments that
drive toolchain work**, never a scoreboard to be won:

- A red kernel **names a gap** — something the language can't yet express, or a
  place the compiler leaks a host-level error instead of a Koru-level one.
- The gap is closed by **improving the toolchain**. The kernel then greens as a
  **side effect** of the language becoming more capable. That is the only green
  that counts.
- When a red isolates a genuine missing language feature, the *minimal* repro is
  pinned as a small, fast failing test back in the **core koru repo** (where it
  drives the fix) — not the heavy benchmark. The heavy version stays here.
- Winning a benchmark is not a goal. A green earned any way other than the
  language genuinely getting more capable is worth less than the honest red.

## Faithfulness & design input

Each kernel is a faithful port of a reference implementation — **same naive
algorithm, same parameters**, no memoization / SIMD / algorithmic shortcut. The
reference corpus is kept in full (five languages per kernel), for two reasons:
it is the correctness **oracle**, and it is **design input** — Koru's idioms are
unsettled, so how other languages express a kernel is a candidate idiom for Koru
to absorb, not merely a spec to satisfy.

## Layout

```
suites/<suite>/
  reference/            # vendored multi-language reference (oracle + design input)
  koru/<name>/
    <name>.k            # the Koru port
    expected.txt        # the integer oracle (verbatim from the reference)
```

## Running

```bash
./run.sh                 # build every kernel through koruc, check against oracle
./run.sh josephus        # filter by name
KORUC=/path/to/koruc ./run.sh

./bench.sh               # perf board (Koru + reference langs, incl. Osprey)
./bench.sh josephus      # filter by name
```

`koruc` is located in the sibling `../koru` checkout by default (build it with
`cd ../koru && zig build`), the same convention `korulang_org` uses.

For the [Osprey](https://www.ospreylang.dev) column, `./bench.sh` prefers a
sibling `../osprey` checkout (`cd ../osprey && make build` — binary at
`target/release/osprey`), then `$OSPREY`, then PATH. Homebrew's bottle currently
cannot link the C runtime outside its layout; the sibling build is the honest
local path (Docker already builds Osprey from source). Osprey is by Christian
Findlay / Nimblesite ([source](https://github.com/Nimblesite/osprey)); its own
published benchmark board lives at <https://www.ospreylang.dev/benchmarks/>.

### Board-worthy timing — a quiet, dedicated box

Wall-clock from a shared/loaded dev machine is **ballpark only** (the results
artifact records `load_avg` for exactly this reason). A number that leaves the
room needs a quiet host with a dedicated CPU. Two pieces, both already here:

- **`docker/Dockerfile`** — the reproducible environment (all reference
  toolchains + koruc from `KORU_REF`). Reproducible *environment*, not stable
  *timing*.
- **`scripts/bench-on-droplet.sh`** — rents a CPU-Optimized (dedicated-vCPU)
  DigitalOcean droplet, runs that image on it, pulls `results/latest.json` back
  to `results/droplet/`, and destroys the droplet. Dedicated vCPU is the stable
  *timing*. Needs `doctl auth init` first.

**DO droplets are x86_64** — this yields an **x86_64/SysV-ABI board, a separate
column from the M2 (ARM64) board; never merge the two.** No cross-language
"beats / matches" claim leaves either board unless re-run under the target's
exact rules on that same machine.

## Status

First light. One suite is landing:

- **`osprey-compute-kernels`** — 22 naive compute kernels (integer recursion,
  folds, and data-structure stress) vendored from the
  [Osprey benchmark suite](https://www.ospreylang.dev/benchmarks/).
  See its README for provenance and the honest board.

The first kernel through the toolchain — `josephus` — is green (`1400177`), and
building it already surfaced a real finding: `for(a..b)` binds its loop variable
as `usize`, and mixing it with an `i64` accumulator leaks a **raw Zig type
error** to the user rather than a Koru-level diagnostic — a candidate core pin.
