import sys, time
n = 10_000_001 + len(sys.argv) - 1
data = list(range(1, n))
best, c = 1e30, 0
for _ in range(7):
    t = time.perf_counter()
    c = sum(v * 3 for v in data if v % 2 == 0)
    best = min(best, (time.perf_counter() - t) * 1000)
print(f"RESULT {c} {best:.6f}")
