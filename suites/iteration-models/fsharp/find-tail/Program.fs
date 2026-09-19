open System.Diagnostics
[<EntryPoint>]
let main argv =
    let n = 10_000_001 + argv.Length
    let sw = Stopwatch()
    let mutable best = 1e30
    let mutable c = 0L
    for _ in 0 .. 6 do
        sw.Restart()
        c <- seq { 0 .. n - 1 } |> Seq.tryFind (fun x -> x > 9_999_997) |> Option.map int64 |> Option.defaultValue -1L
        best <- min best sw.Elapsed.TotalMilliseconds
    printfn "RESULT %d %.6f" c best
    0
