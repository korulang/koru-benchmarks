// nestedloop — triple-nested counting loop accumulating (i*j*k) mod P.
// Faithful port of reference/cases/nestedloop/nestedloop.osp (oracle 255643180):
//   loopK(i,j,k,acc) = k==0 ? acc : loopK(i,j,k-1,(acc+i*j*k) mod P)
//   loopJ(i,j,n,acc) = j==0 ? acc : loopJ(i,j-1,n, loopK(i,j,n,acc))
//   loopI(i,n,acc)   = i==0 ? acc : loopI(i-1,n, loopJ(i,n,n,acc))
//
// RED — BLOCKED by the tail-self-loop parallel-assignment bug (koru pin
// 320_121, GENERALIZED). loop-k's self-tail-loop lowers to `k = k - 1;
// acc = acc + i * j * k;` — acc's RHS reads the already-decremented k. Produces
// 157988652 instead of 255643180. This is a faithful port; the compiler
// mis-lowers it. Goes green when the emitter stages RHS into temporaries before
// assigning. Minimal repro pinned separately: loop-k(2,3,4,0) = 60, emits 36.
import std/io

pub event loop-k { i: i64, j: i64, k: i64, acc: i64 }
| value i64

loop-k = if(k == 0)
| then => value acc
| else |> loop-k(i, j, k: k - 1, acc: @rem(acc + i * j * k, 1000000007))
    | value v => value v

pub event loop-j { i: i64, j: i64, n: i64, acc: i64 }
| value i64

loop-j = if(j == 0)
| then => value acc
| else |> loop-k(i, j, k: n, acc)
    | value kv |> loop-j(i, j: j - 1, n, acc: kv)
        | value v => value v

pub event loop-i { i: i64, n: i64, acc: i64 }
| value i64

loop-i = if(i == 0)
| then => value acc
| else |> loop-j(i, j: n, n, acc)
    | value jv |> loop-i(i: i - 1, n, acc: jv)
        | value v => value v

loop-i(i: 250, n: 250, acc: 0)
| value r |> std/io:print.ln("{{ r:d }}")
