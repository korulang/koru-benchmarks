import sys, time
n = 10_000_001 + len(sys.argv) - 1
def evens():
    for i in range(2, n, 2):
        yield i
best, c = 1e30, 0
for _ in range(7):
    t = time.perf_counter()
    c = sum(v * 3 for v in evens())
    best = min(best, (time.perf_counter() - t) * 1000)
print(f"RESULT {c} {best:.6f}")
