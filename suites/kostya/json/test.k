// test.k — Kostya benchmarks json task, Koru entry.
//
// Same program shape as test.zig / test-rs:
//   verify:    two one-record documents — the second with keys reordered —
//              must each parse through the real path and mean to
//              Coordinate{2.0, 0.5, 0.25}. The reference panics on a miss;
//              we print VERIFY_FAIL and never announce on :9001.
//   input:     readFile("/tmp/1.json") happens BEFORE the announce — the
//              reference reads the file outside its notify bracket and so
//              do we.
//   timed:     send-pid, calc(text) — the full parse + x/y/z accumulate —
//              send("stop"). Parse alone is the measured work, exactly
//              the reference's bracket.
//   output:    the three means printed as a Coordinate-ish line (format
//              differs from the reference's Zig struct print; the suite
//              consumes results.log, not stdout — disclosed).
//
// Faithfulness differences, stated:
// - Parse is schema-directed: std/json:parse binds the `coordinates`
//   array straight into []{x,y,z} records — the typed-reader contract
//   (serde-struct / std.json.parseFromSlice(T) class), not a DOM walk.
//   Undeclared members ("name", "opts", "info") are passed over as the
//   reference's .ignore_unknown_fields passes them over; reordered keys
//   are tolerated — both proven by the verify gate.
// - accumulation is the same `x += item.x` fold; means divide by the
//   count as f64.
// - The file text is freed explicitly after use (Koru obligation surface)
//   where the reference arena-drops it — after the timed region either
//   way.

import std/io
import std/json
import std/store

std/compiler:paths { notify: ./notify.kz }

import notify

std/store:new(st) { x: 0.0[f64], y: 0.0[f64], z: 0.0[f64], n: 0.0[f64] }

pub tor ret0 {} -> i64
ret0 -> 0

pub tor ret1 {} -> i64
ret1 -> 1

// calc — parse `text`, accumulate x/y/z sums + count into st. 0 ok, 1 bad.
pub tor calc { text: string<*> } -> i64
calc = std/store:stored { st.x: 0.0, st.y: 0.0, st.z: 0.0, st.n: 0.0 }
    |> std/json:parse(input: text)
    | malformed { message, offset } |> std/io:print.ln("malformed @{{ offset:d }}: {{ message:s }}")
        |> ret1(): r -> r
    | ok { coordinates: []{ x: f64, y: f64, z: f64 } }
        |> std/store:stored { st.n: @as(f64, @floatFromInt(coordinates.len)) }
        |> for(0..coordinates.len)
            ! each i |> std/store:stored { st.x: st.x + coordinates[i].x, st.y: st.y + coordinates[i].y, st.z: st.z + coordinates[i].z }
        | done |> ret0(): r -> r

// chk — a verified calc call: rc 0 and sums (2.0, 0.5, 0.25), n=1.
// Returns 0 only when the document meant to exactly the reference's
// `right` Coordinate.
pub tor chk { text: string<*>, tag: string } -> i64
chk = calc(text): rc
    |> if(rc != 0 or st.x != 2.0 or st.y != 0.5 or st.z != 0.25)
        | then |> std/io:print.ln("VERIFY FAIL {{ tag:s }}")
            |> ret1(): r -> r
        | else |> ret0(): r -> r

// verify — both key orderings must pass before the announce; a bad parse
// or a wrong mean prints VERIFY_FAIL and the run never reaches :9001.
chk(text: "{\"coordinates\":[{\"x\":2.0,\"y\":0.5,\"z\":0.25}]}", tag: "normal"): r1
|> chk(text: "{\"coordinates\":[{\"y\":0.5,\"x\":2.0,\"z\":0.25}]}", tag: "reorder"): r2
|> if(r1 != 0 or r2 != 0)
    | then |> std/io:print.ln("VERIFY_FAIL")
    | else |> std/io:read-file(path: "/tmp/1.json")
        | not-found |> std/io:print.ln("file missing")
        | failed _ |> std/io:print.ln("read failed")
        | ok content |> notify:send-pid(name: "Koru", port: 9001): _
            |> calc(text: content): rc
            |> notify:send(msg: "stop", port: 9001): _
            |> if(rc == 0)
                | then |> std/store:stored { st.x: st.x / st.n, st.y: st.y / st.n, st.z: st.z / st.n }
                    |> std/io:print.ln("Coordinate { x: {{ st.x:e }}, y: {{ st.y:e }}, z: {{ st.z:f }} }")
            |> std/io:free(content)
