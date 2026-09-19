using System.Linq;
var n = 10_000_001 + args.Length;
var sw = System.Diagnostics.Stopwatch.StartNew();
double best = 1e30; long c = 0;
for (int r = 0; r < 7; r++) {
    sw.Restart();
    c = Enumerable.Range(0, n - 1).FirstOrDefault(x => x > 9_999_997, -1);
    best = System.Math.Min(best, sw.Elapsed.TotalMilliseconds);
}
System.Console.WriteLine($"RESULT {c} {best:F6}");
