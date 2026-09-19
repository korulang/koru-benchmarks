import sys, time
n = 10_000_001 + len(sys.argv) - 1
best, c = 1e30, 0
for _ in range(7):
    t = time.perf_counter()
    c = sum(i * 3 for i in range(1, n) if i * 89478611 % 97 < 60)
    best = min(best, (time.perf_counter() - t) * 1000)
print(f"RESULT {c} {best:.6f}")
