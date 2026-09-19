open System.Diagnostics
[<EntryPoint>]
let main argv =
    let n = 10_000_001 + argv.Length
    let data = Array.init (n - 1) (fun i -> i + 1)
    let sw = Stopwatch()
    let mutable best = 1e30
    let mutable c = 0L
    for _ in 0 .. 6 do
        sw.Restart()
        c <- data |> Array.filter (fun x -> x % 2 = 0) |> Array.map (fun x -> int64 x * 3L) |> Array.sum
        best <- min best sw.Elapsed.TotalMilliseconds
    printfn "RESULT %d %.6f" c best
    0
