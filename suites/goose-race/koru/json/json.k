// Json: the mean of the coordinates in /tmp/1.json, matching the kostya2
// typed-reader contract — schema-directed std/json:parse straight into
// {x,y,z} records, undeclared members ("name", "opts", "info") passed over
// as serde passes over fields a struct does not have, reordered keys
// tolerated. The verify gate runs both key orderings before the timed read.

import std/io
import std/json
import std/store

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
pub tor chk { text: string<*>, tag: string } -> i64
chk = calc(text): rc
    |> if(rc != 0 or st.x != 2.0 or st.y != 0.5 or st.z != 0.25)
        | then |> std/io:print.ln("VERIFY FAILED {{ tag:s }}")
            |> ret1(): r -> r
        | else |> ret0(): r -> r

// verify — both orderings of the one-record document must mean to
// (2.0, 0.5, 0.25); n=1 so the sums are the means.
chk(text: "{\"coordinates\":[{\"x\":2.0,\"y\":0.5,\"z\":0.25}]}", tag: "normal"): _
|> chk(text: "{\"coordinates\":[{\"y\":0.5,\"x\":2.0,\"z\":0.25}]}", tag: "reorder"): _
|> std/io:read-file(path: "/tmp/1.json")
| not-found |> std/io:print.ln("file missing")
| failed e |> std/io:print.ln("read failed")
| ok content |> calc(text: content): rc
    |> if(rc == 0)
        | then |> std/store:stored { st.x: st.x / st.n, st.y: st.y / st.n, st.z: st.z / st.n }
            |> std/io:print.ln("Coordinate { x: {{ st.x:e }}, y: {{ st.y:e }}, z: {{ st.z:f }} }")
    |> std/io:free(content)
