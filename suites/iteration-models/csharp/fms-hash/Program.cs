using System.Linq;
var n = 10_000_001 + args.Length;
var sw = System.Diagnostics.Stopwatch.StartNew();
double best = 1e30; long c = 0;
for (int r = 0; r < 7; r++) {
    sw.Restart();
    c = Enumerable.Range(1, n - 1).Where(x => (long)x * 89478611L % 97 < 60).Select(x => x * 3L).Sum();
    best = System.Math.Min(best, sw.Elapsed.TotalMilliseconds);
}
System.Console.WriteLine($"RESULT {c} {best:F6}");
