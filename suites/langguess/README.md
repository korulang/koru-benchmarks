# langguess — language detection on the guesslang weights (candidate)

Status: **traced, not ported.** Reference vendored and verified
(`PROVENANCE.md`); no `koru/` kernel yet. Whether koruc can express the
workload today is *unmeasured* — first action below.

## Why it belongs here

- **The oracle ships pre-built and differential.** The vendored npm package
  *is* a runnable reference — `node reference/package/cli/index.js` emits the
  full ranked distribution with zero dependencies. Expected outputs are
  generated, never hand-written. Three independent engines were already
  measured agreeing to 5.2e-8, so the oracle isn't hostage to one
  implementation's quirks.
- **Discrete headline, soft tail.** Top-1 `languageId` per input is a hard
  gate — no float-tolerance games. Confidences get an epsilon (~1e-5 is
  defensible against the measured 5.2e-8 cross-engine spread).
- **The comparator set is pre-enumerated.** The demo's author already listed
  every arm and its measurement rules, including one flagging a bias in
  LiteRT.js's favor. Arms, fastest first: Uchen-native (5.8 µs @200 chars),
  Uchen-WASM, LiteRT.js, TF.js (the floor — same math, general engine).
- **New workload shape for the board.** Bytes → byte-pair hash → embedding
  bag mean (70-dim) → dense 512→relu→32→relu→54 → argmax. String/byte
  hashing plus real numerics — not another integer fold. `matmul_single`
  (langarena, green at 1.19x vs rust wave-6) already proves the dense-layer
  half is expressible and fast; the unproven half is the featurizer.
- **Thematically on-brand.** A language toolchain detecting languages.

## Contract the port must satisfy

From `reference/src/index.ts` (upstream wrapper):

- input < 20 chars → empty result
- truncate at 100,000 chars; `\r\n` → `\n` before featurizing
- output: ranked `{languageId, confidence}` over 54 classes, sorted desc

The featurizer (byte-pair split + hashing into embedding buckets) is inside
the TF.js graph in `model.json` — the graph JSON is the spec; there is no
separate readable source. A faithful port reimplements it exactly; a wrong
hash lands on wrong buckets and the top-1 gate catches it.

## Open questions before a port

1. **Corpus.** guesslang upstream ships per-language test files; the suite's
   own `reference/` sources across other suites are also usable inputs.
   Decide corpus → freeze `expected.json` per input by running the vendored
   reference.
2. **koruc surface.** Unproven: reading a 715 KB weight binary, uint8→f32
   dequant (per-tensor affine, 9 tensors), embedding-bag gather/mean, dense
   matmul, argmax over string labels. Per repo doctrine a red names a gap.
3. **Expected-file shape.** Extends the `expected.txt` convention: one
   manifest `expected.json` mapping corpus input → top-1 + confidences.

## Bench-gate ordering

Gate first, meter second: top-1 equality + confidence ε against the
vendored reference on the frozen corpus, proven to reject a deliberately
broken port (e.g. off-by-one bucket hash) before any timing. The published
arm times are M4-Max/WASM numbers — our board's rules apply to our numbers
only.
