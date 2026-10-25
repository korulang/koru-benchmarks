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

## Ports and measurements (arm64 dev box, hyperfine)

| port | serial | parallel | delta | oracle |
|---|---|---|---|---|
| `clbg_spectralnorm` | 0.821s | 0.157s | **5.22×** | checksum-identical |
| `matmul_t4` | 6.968s | 0.815s | **8.5×** | checksum-identical |
| `binarytrees_arena` | 0.113s | 0.114s | **~1.0×** | checksum-identical |

- **spectralnorm** — `[parallel]for` on the four outer row loops; rows
  independent, one disjoint `stored` write per row. Flips the serial
  board's 1.202× deficit row to ~0.23 vs rust — different-class number.
- **matmul_t4** — ports `Matmul::T4`'s semantics (the arena's own
  threaded variant: pool × row ranges), not a marked Single. The
  `[parallel]for` sits on the 900-row loop; c writes are disjoint by
  row. Serial board's 1.203× deficit → ~0.14 vs rust.
- **binarytrees_arena** — the 2M-node checksum fold is a legal additive
  `[parallel]for` and checksums fine — but gains nothing: the fold is a
  pure memory stream (~5GB/s serial, already bandwidth-bound). Legal ≠
  profitable; left in as the honest counter-example.
- `build` inside binarytrees_arena is fork/join-shaped (disjoint
  preorder subtrees) but untested — 2M mutex-guarded `stored` calls per
  run would tax it hard.

## Parallel-suitability map of the 47 (triage, 2026-10-25)

**Parallel-shaped, port cost is a restructure:**
- `clbg_mandelbrot`, `etc_text_raytracer` — per-row / per-pixel
  independence, but both ports emit bytes/fields through a shared
  sequential cursor (`st.p` append / `fs` store-actor). Parallelizing
  needs indexed writes threaded through the call chain — a real port,
  not an annotation.
- `clbg_nbody` — forces fold pairwise-symmetrically (writes touch two
  bodies); needs per-body force accumulation or two-phase. Moderate.
- `clbg_fannkuchredux` — CLBG winners partition permutations by prefix
  block; the port is tail-tor, so a restructure first.
- `sort_merge` — textbook fork/join merge sort; already 0.062 ahead
  serially.
- `base64_*`, `distance_*`, `etc_gameoflife` — parallelizable maps /
  pair-batches / per-generation rows; all already far ahead serially.

**Honestly serial (refusal class, ~25 tasks):** the compress family
(LZW/Huffman/arith/BWT are sequential stream coders; bwt_decode's
prefix-chain per symbol is inherently serial), json/csv/template parsers
(byte-stream), hash_crc32/sha256 (chained state), brainfuck/calculator
interpreters, logparser/cache_sim/words (streaming), maze/graph
(frontier-serial port shapes).

## Notes

- `[parallel]` annotates mid-chain invocations; impls whose head call is
  the loop open with `ret0(): _ |>` to seat it. `[parallel]<impl>` at
  decl position parses but does not fan out (tracked gap).
