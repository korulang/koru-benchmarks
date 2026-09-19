import sys, time
n = 10_000_001 + len(sys.argv) - 1
best, c = 1e30, -1
for _ in range(7):
    t = time.perf_counter()
    c = -1
    for v in range(n):
        if v > 9_999_997:
            c = v
            break
    best = min(best, (time.perf_counter() - t) * 1000)
print(f"RESULT {c} {best:.6f}")
