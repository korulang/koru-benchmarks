import Foundation
let n = 10_000_000 + CommandLine.arguments.count
var best = Double.greatestFiniteMagnitude; var c = 0
for _ in 0..<7 {
    let t = Date()
    c = sequence(state: 0) { (s: inout Int) -> Int? in
        while true {
            s += 1
            if s >= n { return nil }
            if s % 2 == 0 { return s }
        }
    }.lazy.map { $0 * 3 }.reduce(0, +)
    best = min(best, -t.timeIntervalSinceNow * 1000)
}
print("RESULT \(c) \(String(format: "%.6f", best))")
