using System.Linq;
var n = 10_000_001 + args.Length;
var data = new int[n - 1];
for (int i = 0; i < n - 1; i++) data[i] = i + 1;
var sw = System.Diagnostics.Stopwatch.StartNew();
double best = 1e30; long c = 0;
for (int r = 0; r < 7; r++) {
    sw.Restart();
    c = data.Where(x => x % 2 == 0).Select(x => x * 3L).Sum();
    best = System.Math.Min(best, sw.Elapsed.TotalMilliseconds);
}
System.Console.WriteLine($"RESULT {c} {best:F6}");
