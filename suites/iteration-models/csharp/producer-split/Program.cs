using System.Collections.Generic;
using System.Linq;
var n = 10_000_001 + args.Length;
IEnumerable<int> EvensTo(int n) { for (int i = 2; i < n; i += 2) yield return i; }
var sw = System.Diagnostics.Stopwatch.StartNew();
double best = 1e30; long c = 0;
for (int r = 0; r < 7; r++) {
    sw.Restart();
    c = EvensTo(n).Select(v => v * 3L).Sum();
    best = System.Math.Min(best, sw.Elapsed.TotalMilliseconds);
}
System.Console.WriteLine($"RESULT {c} {best:F6}");
