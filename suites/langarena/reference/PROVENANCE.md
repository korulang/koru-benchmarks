# LangArena — vendored reference corpus

This directory vendors the shared task configuration and selected reference
implementations from LangArena, kostya's programming-language evaluation suite.
It is reference material, not a Koru test — nothing here is on the regression
board.

## Source

- Suite: LangArena, by kostya — https://kostya.github.io/LangArena/
- Repo: `https://github.com/kostya/LangArena`
- Commit: `3c9f84ddaeec834c0631747cb789e8cfd602f993` (2026-10-21)
- License: MIT — see `LICENSE.langarena`. The MIT notice is retained here to
  satisfy the license.

## What is here

- `test.js`, `run.js` — the shared task configs consumed by every language
  driver in the arena. Each task carries `name`, input parameters, iteration /
  warmup counts, and the expected u32 `checksum`. `test.js` is the small-size
  dev config; `run.js` is the scored-size config. The checksums are the oracle:
  they are produced by ~27 language implementations agreeing on the same
  result, so they constitute a cross-validated differential corpus.
- `xtime.rb` — the arena's wall-time / peak-RSS wrapper (21 lines, `ps` poll
  every 30ms). Vendored for protocol fidelity; our own timing discipline
  supersedes it for local measurement.
- `crystal/main.cr` — the origin implementation. The suite began as kostya's
  Crystal code; every other language was ported from it. This is the semantic
  reference when ports disagree.
- `zig/` — the Zig port in full (driver + all tasks + build files), vendored as
  the systems-language peer and as the canonical description of the
  compatibility surface: the LCG (`helper.zig`: `last = (last*3877 + 29573)
  mod 139968`) and the checksum (`DJB2 u32` over bytes; floats formatted
  `%.7f` first). Our kernels must reproduce these exactly — the generated
  input data feeds the checksummed result, so RNG or float-format divergence
  fails every task transitively.

## Why these files and not the whole repo

The arena's orchestration (`benchmarks.rb`, docker images) lives on kostya's
side and is only meaningful for the scored run. What we need locally is the
task spec (configs) plus a faithful description of the per-task semantics
(crystal origin, zig peer). If a third peer is needed for a disagreement, pull
it from the pinned commit.

## Oracle convention

The arena's wire protocol is `Name: OK in Xs` / `ERR[actual, expected]` printed
by a driver binary that reads a config file. In this suite's correctness-first
use we keep the repo's existing convention instead: each `koru/<task>/<task>.k`
computes the task and prints its accumulated checksum; `expected.txt` holds the
u32 from the config. The `Name: OK in Xs` driver is a submission-phase wrapper,
not needed for the oracle to fire.
