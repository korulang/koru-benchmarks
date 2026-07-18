import std/parser

// JSON grammar — VERBATIM the grammar block of the koru entry
// (suites/json-parse/koru/bench.k, the 641_004 grammar). This contender lowers
// THIS grammar to a standalone C parser via `koruc json.k generate c`, so the
// row is the SAME library's output on a different target (C vs Zig by the parse
// transform). Correctness parity against the koru entry (both accept doc.json,
// both reject corrupt.json) is the anti-drift gate — if this grammar ever
// diverges from bench.k's, the parity gate fails.
[with]std/parser:grammar(json)
! value v |> match(v)
    | `"([^"\\]|\\.)*"` s -> s
    | `-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?` n -> n
    | `true|false|null` k -> k
    | object o -> o
    | array a -> a
! string s |> match(s)
    | `"([^"\\]|\\.)*"` x -> x
! pair p |> match(p)
    | string s |> lit(":") |> sub(value): v
! members m |> match(m)
    | pair p |> lit(",") |> sub(members): r
    | pair p -> p
! object o |> match(o)
    | `\{` _ |> sub(members): m |> lit("}")
    | `\{` _ |> lit("}")
! elements e |> match(e)
    | value v |> lit(",") |> sub(elements): r
    | value v -> v
! array a |> match(a)
    | `\[` _ |> sub(elements): e |> lit("]")
    | `\[` _ |> lit("]")
