import json, sys, time
# Generic full-tree loader (works for any JSON shape, unlike the doc.json-specific
# py_loads.py). Same protocol: read doc, 3s in-process timed-pass loop building the
# full tree, print passes=<n> seconds=<s>. Sink prevents dead-code elision.
data = open(sys.argv[1], "rb").read()
start = time.time(); passes = 0; sink = 0
while time.time() - start < 3.0:
    v = json.loads(data)
    sink += len(v) if isinstance(v, (list, dict)) else 1
    passes += 1
secs = time.time() - start
print(f"passes={passes} seconds={secs:.6f} sink={sink}")
