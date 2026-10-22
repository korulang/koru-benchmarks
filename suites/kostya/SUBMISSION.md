# Kostya benchmarks — Koru submission staging

Status: **local proof complete, nothing public.** The full protocol chain is
verified end-to-end on this machine against the real `xtime.rb`; the
remaining legs are Linux CI + Lars's approval of the exact diff.

## What is proven (receipts)

- `base64/test.k` + `base64/notify.kz` compile under a **clean clone** of
  koru@dc2acc0 (`git clone` → `zig build` → `KORU_STDLIB=... koruc
  -OReleaseFast test.k`) — the stranger's-machine recipe works.
- Running under the real `xtime.rb` (port-patched local copy,
  `xtime_local.rb`, one-line diff because minio squats :9001 on this
  laptop): announce `"Koru\t<pid>"` accepted, timed region bracketed,
  `"stop"` accepted, `target/results.log` row written
  (`Koru	250009000	0	0	0.0`). The notify shim is a genuine `.kz`
  host integration — `std/net` refuses by design, no socket surface
  exists; `std/compiler:paths` + a project-local module is the honest
  spelling.
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
  raw-byte tor) verified end-to-end: `xtime.rb` bracket 0.718s,
  `QUIET=1` checksum `23280` identical to `bf.rs` release (1.14s),
  non-quiet output **byte-identical** to the reference, hello-world
  verify gate 42059 through the real parse+interp path. The notify
  shim is unchanged — `putb` is one more proc on the same module.

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
   a pinned commit (verified at dc2acc0). Options: public git remote +
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
4. **Task coverage.** base64 + brainfuck staged and proven. Other
   tasks (json, matmul, primes) want their own `test.k` drivers —
   the LangArena kernels carry the algorithms; the drivers are
   per-suite-shape work, not new kernel work.
5. **Disclosure text.** The submission must state plainly: static
   buffers vs fresh alloc (immaterial — Zig's own entry uses a
   FixedBufferAllocator), table-free base64 (select chains vs SIMD —
   the disclosed moat), per-iteration probes (the honest-liveness
   mechanism — costs one read per iteration, negligible at this size).

## Local re-verification recipe

```sh
# in koru-benchmarks/suites/kostya/base64/
cp test.k /tmp/t.k && sed -i '' 's/port: 9001/port: 19001/' /tmp/t.k
koruc -OReleaseFast /tmp/t.k          # needs KORU_STDLIB
ruby xtime_local.rb ./a.out           # listens on :19001
cat target/results.log
```
