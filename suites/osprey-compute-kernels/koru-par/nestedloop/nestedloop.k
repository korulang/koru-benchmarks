// nestedloop — triple-nested counting loop accumulating (i*j*k) mod P,
// i,j,k in [1,250]. Faithful port of koru/nestedloop (oracle 255643180).
// loop-k and loop-j are verbatim. The sequential loop-i threaded `acc`
// through every i — parallelizable because each step is
// acc = (acc + i*j*k) mod P and mod-P addition is associative and
// commutative: row i's net effect is acc -> (acc + S_i) mod P where
// S_i sums i*j*k over the row's (j,k), so each i contributes an
// independent row-sum computed with acc: 0 and the capture combine
// re-applies the same mod — the powmod idiom, and the same
// decomposition bend-par/nestedloop uses (i-split, per-chunk j/k,
// mod-add join). Same parameters, same per-(i,j,k) arithmetic; only
// the i-loop became [parallel]for.
import std/io

pub tor loop-k { i: i64, j: i64, k: i64, acc: i64 } -> i64

loop-k = if(k == 0)
| then -> acc
| else |> loop-k(i, j, k: k - 1, acc: @rem(acc + i * j * k, 1000000007)): v -> v

pub tor loop-j { i: i64, j: i64, n: i64, acc: i64 } -> i64

loop-j = if(j == 0)
| then -> acc
| else |> loop-k(i, j, k: n, acc): kv |> loop-j(i, j: j - 1, n, acc: kv): v -> v

capture { acc: 0[i64] }
! as a |> [parallel]for(1..251)
    ! each i |> loop-j(i: @as(i64, @intCast(i)), j: 250, n: 250, acc: 0): r |> captured { acc: @rem(a.acc + r, 1000000007) }
| captured r |> std/io:print.ln("{{ r.acc:d }}")
