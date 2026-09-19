open System.Diagnostics
[<EntryPoint>]
let main argv =
    let n = 10_000_001 + argv.Length
    let evens = seq { for i in 2 .. 2 .. n - 1 -> i }
    let sw = Stopwatch()
    let mutable best = 1e30
    let mutable c = 0L
    for _ in 0 .. 6 do
        sw.Restart()
        c <- evens |> Seq.map (fun v -> int64 v * 3L) |> Seq.sum
        best <- min best sw.Elapsed.TotalMilliseconds
    printfn "RESULT %d %.6f" c best
    0
