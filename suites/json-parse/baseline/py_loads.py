#!/usr/bin/env python3
# Baseline: CPython json.loads — FULL-TREE category, interpreted-runtime
# reference (its parser core is C). Same protocol: argv doc, 3s timed passes.
import json, sys, time
doc = open(sys.argv[1]).read()
start = time.perf_counter_ns()
deadline = start + 3 * 10**9
passes = 0
sink = 0
while time.perf_counter_ns() < deadline:
    v = json.loads(doc)
    sink += len(v["items"])
    passes += 1
elapsed = (time.perf_counter_ns() - start) / 1e9
print(f"passes={passes} seconds={elapsed:.6f} sink={sink}")
