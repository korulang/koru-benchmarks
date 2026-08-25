// wordfreq — flat-fold (identity) port, oracle 900036.
// The reference checksum is sum((k+1)*counts[k]) over 8 buckets, where
// counts[k] = #{i : r1(r1(1+i))%8 == k}. Since each token contributes
// exactly (bucket_i + 1) to that sum, the weighted count TELESCOPES:
//     sum_k (k+1)*counts[k]  ==  sum_i (bucket_i + 1)
// so the counter table never needs to exist — one branchless fold over the
// token stream. This is the same algebraic reduction clang achieves for the
// C reference (wordfreq.c); it is NOT a changed algorithm, it is the map
// the oracle's own structure hides. Measures whether Koru's Zig IR
// strength-reduces the r1 chain + %8 as clang does.
import std/io

pub tor r1 { x: i64 } -> i64
r1 -> @rem(x * 16807, 2147483647)

pub tor hash-at { seed: i64, i: i64 } -> i64
hash-at = r1(x: seed + i): a |> r1(x: a): b -> b

capture { acc: 0[i64] }
! as a |> for(0..200000)
    ! each i |> hash-at(seed: 1, i: @as(i64, @intCast(i))): h |> captured { acc: a.acc + @rem(h, 8) + 1 }
| captured r |> std/io:print.ln("{{ r.acc:d }}")
