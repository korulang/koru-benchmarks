# koru-par — parallel-class LangArena variants

Lane ruling (Lars, 2026-10-25): `koru/` stays **pure serial** — those
are the LangArena submissions. `koru-par/` carries `[parallel]` variants
as a **separate honest track**, not an arena submission: the vendored
references are single-threaded classes, so a parallel port is a
different-class measurement (like the x86_64/arm64 board split) — real
numbers, honestly labelled, never cherry-picked into the serial board.

Each port's header records its measured serial-vs-parallel delta and the
checksum it must still hit (the oracle is execution-order-insensitive
only where the port proves it — spectralnorm's per-row folds are
exactly-order-preserving).

## Parallel-suitability map of the 47 (triage, 2026-10-25)

**Parallel wins:**
- `clbg_spectralnorm` — ported; 0.821s → 0.157s = **5.22×** (hyperfine,
  checksum-identical). Rows independent, one disjoint store write per row.

**Parallel-shaped but class-bound:**
- `matmul_single` — outer rows independent and fold-shaped, but
  `Matmul::Single` is the arena's explicit *serial* class (a threaded
  `Matmul::T4` exists). A koru-par matmul should port **T4's semantics**
  (worker row-ranges over a pool) — a different task, not a marked Single.
- `base64_encode` — pure map, parallelizable, but a ~0.27s task: pool
  overhead eats the margin on this machine. Untested; expected marginal.

**Honestly serial (refusal class):**
- `compress_bwt_decode` — per-symbol serial prefix-chain; no provable
  partition exists. Stays serial.
- `etc_logparser` — sequential line-streaming parse. Stays serial.
- Everything else already ahead serial (43/47) — parallelism not needed.

## Notes

- `[parallel]` annotates mid-chain invocations; impls whose head call is
  the loop open with `ret0(): _ |>` to seat it. `[parallel]<impl>` at
  decl position parses but does not fan out (tracked gap).
