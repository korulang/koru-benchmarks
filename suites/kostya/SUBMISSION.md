# Kostya benchmarks — Koru submission staging

Status: **local proof complete, nothing public.** The full protocol chain is
verified end-to-end on this machine against the real `xtime.rb` for all
five tasks; the remaining legs are Linux CI + Lars's approval of the
exact diff.

## What is proven (receipts)

- All five `test.k` + `notify.kz` compile under a **clean checkout** of
  koru@f5f677fa2 (`zig build` → `KORU_STDLIB=... koruc -OReleaseFast
  -o <name> test.k`) — the stranger's-machine recipe works, and the
  pin-built binaries produce verified output (matmul
  `-287.0003333333136`, primes oracle list, json means — all rerun at
  the pin). The pin sits on the day's toolchain work: `parse-int`
  widened to `string<*>` (argv parses directly, no `from-page`/`free`),
  `-o` pinned at `220_056`, `KORU_ZIG` override pinned at `220_057`.
- Running under the real `xtime.rb` (port-patched local copy,
  `xtime_local.rb`, one-line diff because minio squats :9001 on this
  laptop): announce `"Koru\t<pid>"` accepted, timed region bracketed,
  `"stop"` accepted, `target/results.log` row written for all five
  tasks (e.g. `Koru	536898000	0	0	0.0` for matmul at n=1500). The
  notify shim is a genuine `.kz` host integration — `std/net` refuses
  by design, no socket surface exists; `std/compiler:paths` + a
  project-local module is the honest spelling.
- Output sums verified: `1431666688` (174764 x 8192 encodes) and
  `1073741824` (131072 x 8192 decodes). Fixture self-check, setup
  roundtrip verify, per-iteration probes, and a final byte-exact
  dec==inp walk all pass silently — a wrong or elided program prints
  `FIXTURE_OR_SETUP_FAIL`/`BADPROBE`/`BADROUNDTRIP` and never posts a
  clean time.
- Measured region: 0.25s bracketed (encode ~115ms + decode ~134ms).
  For context only — the LangArena board's whole-process numbers remain
  the primary comparison; this task's Rust/Zig/C entries use SIMD
  codecs, so base64 is the protocol proof point, not the showcase.
- `brainfuck/test.k` + `brainfuck/notify.kz` (same shim + a `putb`
  raw-byte tor) verified end-to-end: `xtime.rb` bracket 0.722s on the
  scored `bench.b` (3.136s on `mandel.b`, `run2`'s input — both at the
  pin),
  `QUIET=1` checksum `23280` identical to `bf.rs` release (1.14s),
  non-quiet output **byte-identical** to the reference, hello-world
  verify gate 42059 through the real parse+interp path. The notify
  shim is unchanged — `putb` is one more proc on the same module.
  **Bracket fix at review time:** the announce had sat after the
  fold-parse, timing interp only; the reference brackets parse+interp
  (read outside). Now `send-pid` precedes the file read — our window
  is strictly a superset of the reference's.
- `matmul/test.k` verified end-to-end: argv parsing matches the
  reference (`argv[1]` → n, missing/unparseable/negative → 100), the
  `calc(101)` self-check gates the announce (−18.6716666 vs −18.67±0.1),
  and the timed result is **bit-exact** against an independent C oracle
  replicating the reference's transposed-dot math: `-287.0003333333136`
  at n=1500 vs oracle `-287.0003333333` (13 sig digits). `xtime.rb`
  bracket 0.537s at the pin, results.log row written. Disclosed: static flat grids
  (n≤1500, `BOUND_FAIL` past it) and i-k-j row-streamed multiply instead
  of transpose+dot — same k-ascending accumulation, bit-identical.
- `json/test.k` verified end-to-end: both key orderings pass the verify
  gate through the real parse path, `/tmp/1.json` is read **outside**
  the timed bracket exactly like the reference, and the means match a
  Python oracle to ~12 significant digits (`x -4.995830918389563e-30`
  vs `-4.995830918389581e-30`, `y/z` same class — summation-order float
  error, expected). `xtime.rb` bracket 0.105s — parse+accumulate only.
  Disclosed: schema-directed `std/json:parse` into `[]{x,y,z}` records
  (the typed-reader contract; unknown fields passed over).
- `primes/test.k` verified end-to-end: `find(100,2)` sorted yields
  exactly `[2,23,29]` through the real sieve+trie+walk path, and the
  scored output is **identical** to an independent Eratosthenes oracle —
  the full set of primes ≤ 5,000,000 starting `32338`:
  `[323381, 323383, 3233803, 3233809, 3233851, 3233863, 3233873,
  3233887, 3233897]`, sorted. The sort sits inside the timed bracket
  (the reference sorts inside `find`). `xtime.rb` bracket 0.030s —
  Atkin + plist + digit-trie + collect, flat-arena nodes instead of
  per-node hashmaps (disclosed moat).

## Linux leg (droplet receipt, 2026-10-23)

Debian 13 x64 droplet (`s-2vcpu-4gb`), toolchain built the way the
submission's Dockerfile stanza will: `curl` zig 0.15.2 + `curl` the
github archive `koru-f5f677fa2.tar.gz`, `zig build` → koruc. All five
drivers compiled via `KORU_STDLIB=<archive>/koru_std
KORU_ZIG=/opt/zig/zig koruc -OReleaseFast -o target/<t>_koru test.k`
— exactly the recipe above. Outputs re-verified on Linux: matmul
`-287.0003333333136`, primes 9/9, base64 sums identical, brainfuck
bench.b correct, json means match a Python oracle run against the
droplet's own freshly-generated `/tmp/1.json` (~12 sig digits).
The real unpatched `xtime.rb` (port 9001) accepted announce+stop for
all five and wrote `target/results.log` rows; brackets on the shared
2-vCPU box: base64 0.602s, brainfuck 2.206s (bench.b), json 0.311s,
matmul 4.233s (n=1500), primes 0.121s. Times are droplet-context, not
comparison data — the LangArena board remains the perf basis.

## Integration diff (draft, for the maintainer's tree)

`base64/Makefile`:
```make
executables := ... \
	target/base64_koru

target/base64_koru: test.k notify.kz | target
	$(KORU_BUILD)
```

`common/commands.mk`:
```make
KORU_BUILD = KORU_STDLIB=$(KORU_STDLIB) KORU_ZIG=$(KORU_ZIG) \
	koruc -OReleaseFast -o $@ $<
```

## Open decisions for Lars before anything goes public

1. ~~**Koru distribution.**~~ **Resolved — `ARG` + GitHub source
   archive, matching the suite's own idiom.** Every toolchain in the
   suite's `docker/Dockerfile` arrives as `ARG <VER>` +
   `curl <upstream URL> | tar -x` (zig itself included); nothing is
   vendored into the PR and no published image is consumed. Koru's row:
   ```dockerfile
   ARG KORU=f5f677fa2
   RUN curl -L https://github.com/korulang/koru/archive/$KORU.tar.gz \
       | tar -xz && cd koru-* && zig build
   ARG ZIG_KORU=zig-x86_64-linux-0.15.2
   RUN curl -L https://ziglang.org/download/0.15.2/$ZIG_KORU.tar.xz | tar -xJ
   ENV KORU_ZIG="/root/bin/$ZIG_KORU/zig"
   ```
   Archive URL verified anonymously (`200` on codeload). Prereq already
   done: koru main pushed through f5f677fa2.
2. ~~**Two zigs.**~~ **Resolved — `KORU_ZIG` env override landed
   upstream** (koru@f5f677fa2). The suite Dockerfile installs zig
   **0.16.0** for `test.zig`; koruc pins **0.15.2** — now named
   explicitly: `KORU_ZIG=/path/to/zig-0.15.2 koruc ...`. One resolver
   (`emitter_helpers.zigExe()`) covers all nine spawn sites in both
   processes — koruc's backend build and the backend's `build`/
   `build-exe`/`env`/`fetch` — which the zig-lib overlay's version gate
   needs to be true. Verified: wrapper script logs show all three
   pipeline spawns honoring it; wrong path fails loud
   (`error.FileNotFound`), never silently falls back. Regression pin
   `220_057`. The Makefile recipe below uses it.
3. ~~**koruc output path.**~~ **Resolved — `-o` already exists.**
   `koruc -OReleaseFast -o target/base64_koru test.k` lands the binary
   at the name given (verified: `-o` parsed at `src/main.zig:7538`,
   consumed for `exe_name`; regression-pinned at `220_056`, which also
   asserts no `a.out` is written). The recipe keeps the Makefile's
   `| target` order-only prereq — `-o` does not create the parent dir,
   matching `cc`. Remaining litter is the emitted `backend*.zig` /
   `zig-out/` in the task dir — a `clean`-target or `.gitignore`
   concern, cosmetic either way.
4. **Task coverage.** All five tasks staged and proven end-to-end:
   base64, brainfuck, json, matmul, primes. The drivers reuse the
   proven kernels; per-task verify gates, notify brackets, and
   faithfulness disclosures live in each test.k header.
5. ~~**Commented sources vs the line-count metric.**~~ **Resolved —
   generated artifact.** Lars's call: canonical sources keep the
   per-driver disclosure headers; the submitted files are produced by
   `scripts/strip-comments.sh SRC DST` (drops `^\s*//` lines, collapses
   blank runs; trailing comments stay — `//` is legal inside string
   literals). Stripped drivers rebuilt and outputs re-verified identical
   (matmul `-287.0003333333136`, primes list, bf `23280`, json means,
   base64 sums). The staged worktree carries the stripped form; the
   annotated originals here remain the source of truth.
6. **Disclosure text.** The submission must state plainly: static
   buffers vs fresh alloc (immaterial — Zig's own entry uses a
   FixedBufferAllocator), table-free base64 (select chains vs SIMD —
   the disclosed moat), per-iteration probes (the honest-liveness
   mechanism — costs one read per iteration, negligible at this size),
   matmul i-k-j vs transpose+dot (bit-identical accumulation),
   primes flat-arena trie vs per-node hashmaps, and fixed grid bounds
   (`BOUND_FAIL` on n>1500).

## Local re-verification recipe

```sh
# per task dir (base64, brainfuck, json, matmul, primes) —
# the patched copy must live beside notify.kz (paths are source-relative)
d=suites/kostya/matmul; mkdir -p /tmp/kverify
sed 's/port: 9001/port: 19001/' $d/test.k > /tmp/kverify/test.k
cp $d/notify.kz /tmp/kverify/ && cd /tmp/kverify
# same recipe as KORU_BUILD in common/commands.mk (koruc needs Zig 0.15.2,
# not the suite's 0.16.0 — KORU_ZIG names it explicitly)
KORU_STDLIB=<koru>/koru_std KORU_ZIG=<zig-0.15.2> \
    koruc -OReleaseFast -o test_bin test.k
ruby <koru-benchmarks>/$d/xtime_local.rb ./test_bin  # listens on :19001
cat target/results.log
# task args: matmul takes MSIZE (e.g. ./test_bin 1500); brainfuck takes the
# program file; json reads /tmp/1.json (json/generate_json.rb makes it)
```
