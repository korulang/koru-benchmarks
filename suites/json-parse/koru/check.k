import std/parser
import std/fs
import std/args
import std/io

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

std/args:get(index: 1)
| arg path |> std/fs:read-lines(path)
    ! line l |> std/parser:parse(l, grammar: json)
        | value _ |> std/io:print.ln("ACCEPT")
        | parse-error { line, col, expected, found } |> std/io:print.ln("REJECT {{ line:d }}:{{ col:d }} expected {{ expected:s }} found {{ found:s }}")
    | done _ |> _
    | failed e |> std/io:print.ln("READ-FAILED {{ e:s }}")
| out-of-bounds |> std/io:print.ln("usage: check <file>")
