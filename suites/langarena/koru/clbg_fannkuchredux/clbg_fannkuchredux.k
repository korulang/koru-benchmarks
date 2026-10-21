// clbg_fannkuchredux — LangArena CLBG::Fannkuchredux, run.js scored
// parameters (n=8, iterations=700, warmup = iters*0.2 = 140 → 840
// runs; result_val += checksum*100 + max_flips per run, u32 wrap —
// oracle 135762480; per-run contribution is 1616*100 + 22 = 161622).
//
// The reference is the classic CLBG fannkuch on perm1/perm/count[8]:
// an outer permutation-advance machine with a pancake-flip inner loop.
// The two-exit advance loop (return vs continue) is encoded by adv
// producing 1 = whole computation done, 0 = keep going.
//
import std/io
import std/grid
import std/store

std/grid:new(perm1, size: 8) { v: 0[i64] }
std/grid:new(perm, size: 8) { v: 0[i64] }
std/grid:new(cnt, size: 8) { v: 0[i64] }
std/store:new(st) { r: 0[i64], pc: 0[i64], cs: 0[i64], mf: 0[i64], acc: 0[i64], k: 0[i64], fc: 0[i64], p0: 0[i64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// frst — count[r-1] = r while r > 1
pub tor frst { } -> i64
frst = if(st.r > 1)
| then |> std/grid:stored { cnt[st.r - 1].v: st.r }
    |> std/store:stored { st.r: st.r - 1 }
    |> frst(): r -> r
| else -> 0

// swp — reverse perm[0..k]: swap perm[i],perm[j] while i < j
pub tor swp { i: i64, j: i64 } -> i64
swp = if(i < j)
| then |> std/grid:stored { perm[i].v: perm[i].v +% perm[j].v }
    |> std/grid:stored { perm[j].v: perm[i].v -% perm[j].v }
    |> std/grid:stored { perm[i].v: perm[i].v -% perm[j].v }
    |> swp(i: i + 1, j: j - 1): r -> r
| else -> 0

// flip — pancake flips until perm[0] == 0
pub tor flip { } -> i64
flip = std/store:stored { st.k: perm[0].v }
    |> if(st.k != 0)
        | then |> swp(i: 0, j: st.k): _
            |> std/store:stored { st.fc: st.fc + 1 }
            |> flip(): r -> r
        | else -> 0

// cpyperm — perm <- perm1
pub tor cpyperm { i: i64 } -> i64
cpyperm = if(i < 8)
| then |> std/grid:stored { perm[i].v: perm1[i].v }
    |> cpyperm(i: i + 1): r -> r
| else -> 0

// rotl — rotate perm1 left by one through index r:
// perm1[i] = perm1[i+1] for i<r, perm1[r] = saved p0
pub tor rotl { i: i64 } -> i64
rotl = if(i < st.r)
| then |> std/grid:stored { perm1[i].v: perm1[i + 1].v }
    |> rotl(i: i + 1): r -> r
| else |> std/grid:stored { perm1[st.r].v: st.p0 }: _ -> 0

// adv — permutation advance; produces 1 when the enumeration is done
// (r == n) or 0 when the outer loop should continue
pub tor adv { } -> i64
adv = if(st.r == 8)
| then -> 1
| else |> std/store:stored { st.p0: perm1[0].v }
    |> rotl(i: 0): _
    |> std/grid:stored { cnt[st.r].v: cnt[st.r].v - 1 }
    |> if(cnt[st.r].v > 0)
        | then -> 0
        | else |> std/store:stored { st.r: st.r + 1 }
            |> adv(): r -> r

// fko — outer machine: reset counts, copy, flip, accumulate, advance.
// Armed `|> if` steps push the continuation column deeper each time —
// the `|>` after each sits at that step's arm column (PARKED #7).
pub tor fko { } -> i64
fko = frst(): _
    |> cpyperm(i: 0): _
    |> std/store:stored { st.fc: 0 }
    |> flip(): _
    |> if(st.fc > st.mf)
        | then |> std/store:stored { st.mf: st.fc }
        | else |> ret0(): _
        |> if(@rem(st.pc, 2) == 0)
            | then |> std/store:stored { st.cs: st.cs + st.fc }
            | else |> std/store:stored { st.cs: st.cs - st.fc }
            |> adv(): done
            |> if(done == 1)
                | then -> 0
                | else |> std/store:stored { st.pc: st.pc + 1 }
                    |> fko(): r -> r

// onerun — fresh fannkuchredux(8): contribution into acc
pub tor onerun { } -> i64
onerun = for(0..8)
    ! each i |> std/grid:stored { perm1[i].v: @as(i64, @intCast(i)) }
        |> std/grid:stored { perm[i].v: 0 }
        |> std/grid:stored { cnt[i].v: 0 }
    | done
    |> std/store:stored { st.r: 8 }
    |> std/store:stored { st.pc: 0 }
    |> std/store:stored { st.cs: 0 }
    |> std/store:stored { st.mf: 0 }
    |> fko(): _
    |> std/store:stored { st.acc: @rem(st.acc +% (st.cs *% 100 +% st.mf) +% 4294967296, 4294967296) }: _ -> 0

// runl — 840 runs (700 measured + 140 warmup)
pub tor runl { k: i64 } -> i64
runl = if(k < 840)
| then |> onerun(): _
    |> runl(k: k + 1): r -> r
| else -> 0

// ---- driver ----
runl(k: 0): _
|> std/io:print.ln("{{ st.acc:d }}")
