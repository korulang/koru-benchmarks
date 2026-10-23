# Kostya benchmarks — Koru submission staging

Status: **local proof complete, nothing public.** The full protocol chain is
verified end-to-end on this machine against the real `xtime.rb` for all
five tasks; the remaining legs are Linux CI + Lars's approval of the
exact diff.

## What is proven (receipts)

- All five `test.k` + `notify.kz` compile under a **clean checkout** of
  koru@9d5ae4e9b (`zig build` → `KORU_STDLIB=... koruc -OReleaseFast
  test.k`) — the stranger's-machine recipe works, and the
  pin-built binaries produce byte-identical output to the
  development-tree builds. The pin sits on `parse-int`'s widening to
  `string<*>`: matmul parses argv directly
  (`args:get | arg a |> parse-int(s: a)`), no `from-page`/`free`
  round-trip on borrowed argv memory.
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
KORU_BUILD = KORU_STDLIB=$(KORU_STDLIB) PATH=$(KORU_ZIG):$(PATH) \
	koruc -OReleaseFast -o $@ $<
```

## Open decisions for Lars before anything goes public

1. **Koru distribution.** The maintainer needs `koruc` + `koru_std` from
   a pinned commit (verified at 9d5ae4e9b). Options: public git remote +
   `ARG KORU_COMMIT`, or a vendored tarball in the PR. Which?
2. **Two zigs.** The suite Dockerfile installs zig **0.16.0** for
   `test.zig`; `koruc` pins **0.15.2** and shells to bare `zig` via PATH
   (no `KORU_ZIG` env var exists — `bo_argv[0] = "zig"` in
   `compiler.materialize-build.kz`). Options: a `koru` wrapper script
   that prepends zig-0.15.2 to PATH (zero toolchain change), or add a
   `KORU_ZIG` env override to koruc (cleaner, a toolchain change).
3. **koruc output path.** `koruc` writes `a.out` + backend artifacts to
   CWD; the Makefile wants `target/base64_koru`. Either `koruc -o`
   learns to name the executable, or the recipe moves `a.out` after
   build and cleans the emitted `*.zig`/`zig-out` litter. Cosmetic.
4. **Task coverage.** All five tasks staged and proven end-to-end:
   base64, brainfuck, json, matmul, primes. The drivers reuse the
   proven kernels; per-task verify gates, notify brackets, and
   faithfulness disclosures live in each test.k header.
5. **Disclosure text.** The submission must state plainly: static
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
KORU_STDLIB=<koru>/koru_std koruc -OReleaseFast test.k
ruby <koru-benchmarks>/$d/xtime_local.rb ./a.out   # listens on :19001
cat target/results.log
# task args: matmul takes MSIZE (e.g. ./a.out 1500); brainfuck takes the
# program file; json reads /tmp/1.json (json/generate_json.rb makes it)
```
