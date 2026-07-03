// nestedloop — triple-nested counting loop accumulating (i*j*k) mod P.
// Faithful port of reference/cases/nestedloop/nestedloop.osp (oracle 255643180):
//   loopK(i,j,k,acc) = k==0 ? acc : loopK(i,j,k-1,(acc+i*j*k) mod P)
//   loopJ(i,j,n,acc) = j==0 ? acc : loopJ(i,j-1,n, loopK(i,j,n,acc))
//   loopI(i,n,acc)   = i==0 ? acc : loopI(i-1,n, loopJ(i,n,n,acc))
//
// (Went green 2026-07-03 when the emitter learned parallel assignment for
// tail-self-loop args — koru pin 320_121/320_122.)
// Single-return form: each loop event has ONE output — scalar `-> i64` bare
// returns, no single-variant tag unions. loop-j/loop-i chain two binds in the
// else arm and produce the tail bind.
import std/io

pub event loop-k { i: i64, j: i64, k: i64, acc: i64 } -> i64

loop-k = if(k == 0)
| then -> acc
| else |> loop-k(i, j, k: k - 1, acc: @rem(acc + i * j * k, 1000000007)): v -> v

pub event loop-j { i: i64, j: i64, n: i64, acc: i64 } -> i64

loop-j = if(j == 0)
| then -> acc
| else |> loop-k(i, j, k: n, acc): kv |> loop-j(i, j: j - 1, n, acc: kv): v -> v

pub event loop-i { i: i64, n: i64, acc: i64 } -> i64

loop-i = if(i == 0)
| then -> acc
| else |> loop-j(i, j: n, n, acc): jv |> loop-i(i: i - 1, n, acc: jv): v -> v

loop-i(i: 250, n: 250, acc: 0): r |> std/io:print.ln("{{ r:d }}")
