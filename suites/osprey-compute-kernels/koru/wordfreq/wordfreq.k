// wordfreq — count a pseudo-random token stream into a Map<string, int>, then
// report a position-weighted checksum of the counts. Faithful port of
// reference/cases/wordfreq (oracle 900036): Park-Miller MINSTD RNG generates
// 200000 tokens over an 8-word vocab; each is bumped into a std/string-map;
// the report sums (position+1)*count over the 8 words in vocab order.
//
// Seed: the harness feeds "0" on stdin -> seed=1 (the deterministic oracle
// path). A non-zero parseable line takes that value as seed directly — the
// reference's cryptographically-random-reseed branch (`randomBelow`) has no
// pure-Koru equivalent (no CSPRNG builtin), so this port falls back to the
// literal value instead of re-randomizing; that only affects the (unchecked)
// random demo path, never the oracle-checked mode.
import std/io
import std/string
import std/string-map

pub event r1 { x: i64 } -> i64
r1 -> @rem(x * 16807, 2147483647)

pub event hash-at { seed: i64, i: i64 } -> i64
hash-at = r1(x: seed + i): a |> r1(x: a): b -> b

pub event bucket-of { h: i64 } -> i64
bucket-of -> @rem(h, 8)

pub event seed-of { line: []const u8 } -> i64
seed-of = std/string:from-page(text: line)
| ok s |> std/string:parse-int(s)
    | ok v |> std/string:free(s) |> if(v == 0)
        | then -> 1
        | else -> v
    | err _ |> std/string:free(s) -> 1
| err _ -> 1

// bump — the naive-phase mirror of the .osp's `bump(m,w) = mapSet(m, w,
// mapGet(m, w) ?: 0 + 1)`: an 8-way dispatch on the bucket index, one
// value/missing get-then-set pair per literal vocab word.
pub event bump { m: *Map_string_i64<std/string-map:map>, k: i64 }

bump = if(k == 0)
| then |> std/string-map:get(m, k: "the")
    | value v |> std/string-map:set(m, k: "the", v: v + 1)
    | missing |> std/string-map:set(m, k: "the", v: 1)
| else |> if(k == 1)
    | then |> std/string-map:get(m, k: "quick")
        | value v |> std/string-map:set(m, k: "quick", v: v + 1)
        | missing |> std/string-map:set(m, k: "quick", v: 1)
    | else |> if(k == 2)
        | then |> std/string-map:get(m, k: "brown")
            | value v |> std/string-map:set(m, k: "brown", v: v + 1)
            | missing |> std/string-map:set(m, k: "brown", v: 1)
        | else |> if(k == 3)
            | then |> std/string-map:get(m, k: "fox")
                | value v |> std/string-map:set(m, k: "fox", v: v + 1)
                | missing |> std/string-map:set(m, k: "fox", v: 1)
            | else |> if(k == 4)
                | then |> std/string-map:get(m, k: "jumps")
                    | value v |> std/string-map:set(m, k: "jumps", v: v + 1)
                    | missing |> std/string-map:set(m, k: "jumps", v: 1)
                | else |> if(k == 5)
                    | then |> std/string-map:get(m, k: "over")
                        | value v |> std/string-map:set(m, k: "over", v: v + 1)
                        | missing |> std/string-map:set(m, k: "over", v: 1)
                    | else |> if(k == 6)
                        | then |> std/string-map:get(m, k: "lazy")
                            | value v |> std/string-map:set(m, k: "lazy", v: v + 1)
                            | missing |> std/string-map:set(m, k: "lazy", v: 1)
                        | else |> std/string-map:get(m, k: "dog")
                            | value v |> std/string-map:set(m, k: "dog", v: v + 1)
                            | missing |> std/string-map:set(m, k: "dog", v: 1)

pub event count-of { m: *Map_string_i64<std/string-map:map>, key: []const u8 } -> i64
count-of = std/string-map:get(m, k: key)
| value v -> v
| missing -> 0

std/io:read-lines()
! line l |> seed-of(line: l): seed |> std/string-map:new()
    | map m |> for(0..200000)
        ! each i |> hash-at(seed, i: @as(i64, @intCast(i))): h |> bucket-of(h): k |> bump(m, k)
        | done |> count-of(m, key: "the"): c0 |> count-of(m, key: "quick"): c1 |> count-of(m, key: "brown"): c2 |> count-of(m, key: "fox"): c3 |> count-of(m, key: "jumps"): c4 |> count-of(m, key: "over"): c5 |> count-of(m, key: "lazy"): c6 |> count-of(m, key: "dog"): c7 |> std/string-map:free(m) |> std/io:print.ln("{{ 1 * c0 + 2 * c1 + 3 * c2 + 4 * c3 + 5 * c4 + 6 * c5 + 7 * c6 + 8 * c7:d }}")
    | err e |> std/io:print.ln("ERR {{ e:s }}")
| done _ |> _
| failed e |> std/io:print.ln("FAILED {{ e:s }}")
