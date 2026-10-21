// etc_sieve — LangArena Etc::Sieve, run.js scored parameters
// (limit=3000000, iterations=270, warmup_iterations=max(270*0.2,1)=54 → 324
// checksum accumulations, oracle 1042248060).
//
// Faithful port of reference/crystal/main.cr Etc::Sieve:
//   primes: u8[limit+1] all 1; 0 and 1 struck
//   mark:   p=2..floor(sqrt(limit)); if primes[p]==1 strike p*p, p*p+p, ...
//   count:  n=3..limit step 2; count primes, track last_prime
//   run:    acc += (last_prime + count) as u32, per iteration, mod 2^32
//
// Faithfulness differences, stated:
// - The reference allocates a fresh primes array per iteration; ours is one
//   static grid reset to 1 per iteration — same marking/counting arithmetic
//   on identical data, no allocation timing in either.
// - The warmup/measured split is collapsed into one 324-iteration loop: the
//   checksum accumulates identically (54 + 270; the matmul kernel documents
//   the same collapse, verified byte-exact at test.js scale).
// - primality is a u8 field like the reference's Array(UInt8).
// - sqrt(3000000) = 1732.05… is written as the literal bound 1733
//   (for(2..1733) covers p <= 1732); it is comptime-known either way.
// - The count/last pass walks n = 3 + 2k for k = 0..1499999 — the same odd
//   walk as the reference's n=3 step 2.
// - [unsafe(bounds)] is NOT waived — the marking loop's product index
//   (p*p + k*p) and the reset's full-range index keep the floor (the
//   optimizer's range proof handles them in release builds).
//
import std/io
import std/grid

std/grid:new(sieve, size: 3000001) { p: 1[u8] }
std/grid:stored { sieve[0].p: 0 }
std/grid:stored { sieve[1].p: 0 }

capture { acc: 0[i64] }
! as g |> for(0..324)
    ! each it |> for(0..3000001)
        ! each n |> std/grid:stored { sieve[n].p: 1 }
        | done |> for(2..1733)
            ! each p |> if(sieve[p].p == 1)
                | then |> for(0..(3000000 - p * p) / p + 1)
                    ! each k |> std/grid:stored { sieve[p * p + k * p].p: 0 }
            | done |> capture { last: 2[i64], count: 1[i64] }
                ! as a |> for(0..1499999)
                    ! each k |> if(sieve[3 + 2 * k].p == 1)
                        | then |> captured { last: @as(i64, @intCast(3 + 2 * k)), count: a.count + 1 }
                | captured r |> captured { acc: @rem(g.acc + r.last + r.count, 4294967296) }
| captured res |> std/io:print.ln("{{ res.acc:d }}")
