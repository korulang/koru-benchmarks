// Contender: FParsec (F#/.NET) — a parser-COMBINATOR library, koru's .NET
// general-library peer (same category as parsec/nom; NOT a specialized JSON
// deserializer). RECOGNIZER lane: it validates the full JSON grammar and
// returns unit, building NO value tree — the matched lane against the koru
// std/parser recognizer and the other general-lib recognizers. General RFC
// surface (whitespace anywhere), like the zig hand-rolled rival, where the
// koru grammar is comptime-specialized to the doc's dialect.
//
// Repetition uses skipMany/skip* discards (no list allocation) so the
// recognizer genuinely builds nothing. String escapes accept the \uXXXX shape
// leniently, matching the nom/parsec entries for a like-for-like grammar.
//
// Protocol identical to every contender: read the doc from the LAST argv, 3s
// in-process timed-pass loop, print `passes=<n> seconds=<s>`; on an invalid
// doc print `INVALID` and exit 1 (the suite's reject gate). FParsec parses a
// .NET string (compact UTF-16 CharStream) — its native, optimized stream.
module Main

open FParsec
open System.Diagnostics

let isDigit c = c >= '0' && c <= '9'

// value is recursive; forward its reference.
let jvalue, jvalueRef = createParserForwardedToRef<unit, unit> ()

let ws : Parser<unit, unit> =
    skipManySatisfy (fun c -> c = ' ' || c = '\t' || c = '\n' || c = '\r')

// JSON string, opening quote consumed here; builds nothing.
let jstring : Parser<unit, unit> =
    let normal = skipSatisfy (fun c -> c <> '"' && c <> '\\' && c >= ' ')
    let escape =
        skipChar '\\'
        >>. skipSatisfy (fun c -> "\"\\/bfnrtu0123456789abcdefABCDEF".IndexOf c >= 0)
    skipChar '"' >>. skipMany (normal <|> escape) .>> skipChar '"'

let jnumber : Parser<unit, unit> =
    let intPart =
        skipChar '0'
        <|> (skipSatisfy (fun c -> c >= '1' && c <= '9') >>. skipManySatisfy isDigit)
    let frac = optional (skipChar '.' >>. skipMany1Satisfy isDigit)
    let expo =
        optional (skipAnyOf "eE" >>. optional (skipAnyOf "+-") >>. skipMany1Satisfy isDigit)
    optional (skipChar '-') >>. intPart >>. frac >>. expo

// members / elements as recognizers: parse the first, then skipMany more —
// discards everything, no list built (mirrors parsec's sepByD / nom's folds).
let jmember : Parser<unit, unit> =
    (jstring .>> ws) .>> skipChar ':' .>> ws .>> jvalue

let sepByDiscard (p: Parser<unit, unit>) (sep: Parser<unit, unit>) : Parser<unit, unit> =
    optional (p >>. skipMany (sep >>. p))

let jobject : Parser<unit, unit> =
    between (skipChar '{' >>. ws) (skipChar '}') (sepByDiscard jmember (skipChar ',' >>. ws))

let jarray : Parser<unit, unit> =
    between (skipChar '[' >>. ws) (skipChar ']') (sepByDiscard jvalue (skipChar ',' >>. ws))

// value dispatch; each value consumes trailing whitespace (lexeme discipline).
jvalueRef.Value <-
    choice
        [ jstring
          jobject
          jarray
          skipString "true"
          skipString "false"
          skipString "null"
          jnumber ]
    .>> ws

let json : Parser<unit, unit> = ws >>. jvalue .>> eof

[<EntryPoint>]
let main argv =
    let path = argv.[argv.Length - 1]
    let doc = System.IO.File.ReadAllText path

    match run json doc with
    | Failure (_, _, _) ->
        printfn "INVALID"
        exit 1
    | Success _ -> ()

    let sw = Stopwatch.StartNew()
    let mutable passes = 0
    let mutable sink = 0
    while sw.Elapsed.TotalSeconds < 3.0 do
        match run json doc with
        | Success _ -> sink <- sink + 1
        | Failure _ -> failwith "parse failed mid-loop"
        passes <- passes + 1
    let secs = sw.Elapsed.TotalSeconds
    printfn "passes=%d seconds=%.6f sink=%d" passes secs sink
    0
