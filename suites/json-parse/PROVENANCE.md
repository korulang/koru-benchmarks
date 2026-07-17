# Provenance

- `data/doc.json`: `gen_doc.py` (CPython, `random.seed(41)`), minified
  `json.dumps`, 27,102 bytes. Nesting <= 4, arrays <= 16, objects <= 8 keys,
  no backslash escapes inside strings. Regenerate: `./gen_doc.py`.
- Koru entry: `koru/bench.k`, compiled through the sibling checkout's koruc
  (`../koru/zig-out/bin/koruc build bench.k`), grammar identical to koru
  regression test 641_004 (the JSON flagship) plus file/args/benchmarking
  plumbing.
- Baselines: `zig build-exe -O ReleaseFast` (zig 0.15.2 at suite creation);
  CPython 3 stdlib json.
- Protocol: in-process 3-second wall-clock timed passes, one process per
  contender, sequential, same machine, same file. No warmup beyond the
  first pass; startup excluded by construction (timing starts after load).
- Machine at first measurement: Lars's M2 Pro (darwin), recorded per-run in
  results output — numbers are machine-local, never portable.
