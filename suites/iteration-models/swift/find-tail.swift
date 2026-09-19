import Foundation
let n = 10_000_000 + CommandLine.arguments.count
var best = Double.greatestFiniteMagnitude; var c = -1
for _ in 0..<7 {
    let t = Date()
    c = (0..<n).lazy.first(where: { $0 > 9_999_997 }) ?? -1
    best = min(best, -t.timeIntervalSinceNow * 1000)
}
print("RESULT \(c) \(String(format: "%.6f", best))")
