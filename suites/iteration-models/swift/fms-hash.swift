import Foundation
let n = 10_000_000 + CommandLine.arguments.count
var best = Double.greatestFiniteMagnitude; var c = 0
for _ in 0..<7 {
    let t = Date()
    c = (1..<n).lazy.filter { $0 * 89478611 % 97 < 60 }.map { $0 * 3 }.reduce(0, +)
    best = min(best, -t.timeIntervalSinceNow * 1000)
}
print("RESULT \(c) \(String(format: "%.6f", best))")
