# Provenance — langguess

Candidate suite, traced 2026-10-23. Not yet a port — this directory is the
trace so the idea survives; see `README.md` for the oracle plan.

## What this is

The guesslang language-detection model — the one behind VS Code's untitled-
editor language guessing — packaged by Microsoft as
`@vscode/vscode-languagedetection` (MIT).

Upstream:

- npm: `@vscode/vscode-languagedetection@1.0.23`
- source: https://github.com/microsoft/vscode-languagedetection (tag `v1.0.23`)
- model lineage: guesslang by Y. Somda, https://github.com/yoeo/guesslang
  (weights NOT retrained — same 674,604 parameters everywhere)

The workload that made this interesting — Eugene Ostroukhov's UchenML demo
races three engines on the *same* weights:

- https://uchenml.tech/demos/langguess/
- recorded Apple M4 Max, Node v24.19.0, 2026-10-07:

| engine | 200 chars | 201 KB file | code | params |
|---|---|---|---|---|
| Uchen / native (arm64) | 5.8 µs | 15.4 µs | 222 KB | 959 KB uint8 |
| Uchen / WASM SIMD, Node | 9.5 µs | 31.8 µs | 135 KB | 959 KB uint8 |
| LiteRT.js 2.5.3 (sparse .tflite, XNNPACK) | 29.1 µs | 67.9 µs | 9,670 KB | 2,703 KB fp32 |
| TensorFlow.js (upstream pkg, CPU backend) | 2,418 µs | 52,649 µs | 828 KB | 959 KB uint8 |

Demo's own parity claim: every engine's top language matched on every
input; largest confidence divergence 5.2e-8.

## Verification receipt — weights are the published ones

sha256 of the vendored `reference/package/model/` files, computed
2026-10-23 against the npm tarball for 1.0.23, matches the values the demo
page publishes:

```
100ce176367e7311e37ced0695057452991a8692029a79340a25e622893e7983  model.json
fab6442698f64d5b1d2df052061d12bafd570330556819d29f48c7bcbb5889f7  group1-shard1of1.bin
```

## What's vendored

- `reference/package/` — the npm tarball contents, unmodified: `model/`
  (the oracle weights), `dist/` (tfjs bundled, zero runtime deps — the
  reference runs with plain `node`, see below), `cli/`, LICENSE (MIT).
- `reference/src/index.ts` — upstream's readable wrapper from the git tag
  (the dist bundle is minified). The wrapper is thin: min content 20 chars
  else `[]`, truncate at 100,000 chars, `\r\n` → `\n`, output sorted by
  confidence desc.
- `samples/` — two smoke inputs with `*.expected.json` top-5 produced by
  running the vendored reference under `node` this session. They pin the
  output *shape*; the real corpus is an open question (see README).

## Where the featurizer spec lives

The model.json graph contains the whole pipeline as TF.js string ops —
byte-pair split, hash, embedding lookup — which is exactly why upstream
TF.js is ~250x slower than the compiled engines. A Koru port reimplements
that featurizer from the graph ops in `model.json` (this is what Uchen did
in C++). There is no separate readable featurizer source; the graph JSON is
the spec.
