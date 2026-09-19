open System.Diagnostics
[<EntryPoint>]
let main argv =
    let n = 10_000_001 + argv.Length
    let sw = Stopwatch()
    let mutable best = 1e30
    let mutable c = 0L
    for _ in 0 .. 6 do
        sw.Restart()
        c <- seq { 1 .. n - 1 } |> Seq.filter (fun x -> int64 x * 89478611L % 97L < 60L) |> Seq.map (fun x -> int64 x * 3L) |> Seq.sum
        best <- min best sw.Elapsed.TotalMilliseconds
    printfn "RESULT %d %.6f" c best
    0
