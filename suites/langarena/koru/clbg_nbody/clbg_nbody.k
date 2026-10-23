// clbg_nbody — LangArena CLBG::Nbody, run.js scored parameters
// (iterations=20000, warmup default = iters*0.2 = 4000 → 24000 runs;
// each run = 1000 integration steps over the 5-body system and state
// ACCUMULATES across runs; checksum = (csf(v1) << 5) & csf(v2),
// u32 arithmetic — oracle 338799744).
//
// SPELLED AS std/kernel end to end: shape/init, self+pairwise energy
// folds chained BEFORE step (v1 = -0.1690751638 computed, not pinned),
// step(pairwise+self) for the 24M integration steps, then self+pairwise
// folds chained AFTER step (v2 = -0.1690366593 computed). One
// `| reduce r |>` exit carries all four accumulators — kernel op
// position in the `|>` chain is the schedule: before step = once over
// the initial state, under `| step |>` = per step, past step = once over
// the final state (landed in koru b92b91a4c after a measured bug: a
// reduce chained before step used to be absorbed INTO the step loop and
// accumulated per step — v1 = -4057214.86, a real wrong result).
//
// Accumulator writes inside self/pairwise bodies (`kin1 +=`, `pot1 -=`)
// are NOT `k.` paths — they pass the transform through verbatim and
// resolve to the `var` slots the following `reduce` op declares at the
// top of the handler. That gives exact oracle accumulation: elementwise
// terms fold i-ascending into one scalar, pair terms fold
// i-asc/j-ascending — same traversal, same strict float mode as the
// reference's eni/enj loops. (A reduce op's own loop runs
// @setFloatMode(.optimized) — reassociation would gamble the 7-decimal
// format, so these folds deliberately live in strict self/pairwise ops
// and the reduces only declare the exit fields.)
//
// Initial state carries the momentum offset BAKED into body 0's
// velocity (reference runs offsetMomentum before v1: sun takes
// -Σ(mᵢvᵢ)/m_sun = -0.00038766340719874267, -0.0032753590371765707,
// 2.3935734080003e-05 — same class as the reference's v*365.24
// pre-bakes, one compile-time evaluation instead of a runtime pass).
// The kernel's pairwise emits `for i: for j in i+1..5` symmetric-impulse
// then self advance — bit-identical to moveFromI's interleaved order,
// because a pair (i,j) only ever reads positions j>i, which are always
// unadvanced. Proven, not assumed: a C oracle replicating both orders
// produced the same v2 and checksum (338799744).
//
// mag = dt/(dsq·√dsq) — mathematically identical to the reference's
// dt/(d·d·d) with d=√dsq, ~1-2ulp different rounding, inside the
// oracle's 1e-7 format slack. Impulse products are spelled dx*(m*mag) —
// mass·mag grouped first — matching the reference's product order;
// (dx*m)*mag measurably drifts the 7-decimal format over 24M steps
// (falsified during the kernel probe).
//
// FALSIFIED during this kernel port:
// - missing momentum offset flips v1's format → checksum 336806016.
// - `reduce` before `step` absorbed into the step loop → v1=-4057214.86.
//   FIXED upstream (koru b92b91a4c): position in the chain is now the
//   schedule; this file is the honest consumer of that fix.

import std/kernel
import std/io
import std/fmt
import std/store

std/store:new(st) { t3: 0[i64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// djh — djb2 over the formatted text (checksumFloat's second half)
pub tor djh { t: string<*@scoped> } -> i64
djh = for(0..t.len)
    ! each k |> std/store:stored { st.t3: @rem(st.t3 * 33 + @as(i64, @intCast(t[k])), 4294967296) }
    | done
    |> ret0(): _ -> 0

// csfv — checksumFloat(v) produced as u32-in-i64
pub tor csfv { v: f64 } -> i64
csfv = std/fmt:ln("{{ v:d:.7 }}"): s
    |> std/store:stored { st.t3: 5381 }
    |> djh(t: s.text): _
    |> ret0(): _ -> st.t3

std/kernel:shape(Body) {
    x: f64, y: f64, z: f64,
    vx: f64, vy: f64, vz: f64,
    mass: f64,
}

std/kernel:init(Body) {
    { x: 0.0, y: 0.0, z: 0.0,
      vx: -0.00038766340719874267, vy: -0.0032753590371765707, vz: 2.3935734080003e-05,
      mass: 39.47841760435743 },
    { x: 4.841431442464721, y: -1.1603200440274284, z: -0.10362204447112311,
      vx: 0.606326392995832, vy: 2.81198684491626, vz: -0.02521836165988763,
      mass: 0.03769367487038949 },
    { x: 8.34336671824458, y: 4.124798564124305, z: -0.4035234171143214,
      vx: -1.0107743461787924, vy: 1.8256623712304119, vz: 0.008415761376584154,
      mass: 0.011286326131968767 },
    { x: 12.894369562139131, y: -15.111151401698631, z: -0.22330757889265573,
      vx: 1.0827910064415354, vy: 0.8687130181696082, vz: -0.010832637401363636,
      mass: 0.0017237240570597112 },
    { x: 15.379697114850917, y: -25.919314609987964, z: 0.17925877295037118,
      vx: 0.979090732243898, vy: 0.5946989986476762, vz: -0.034755955504078104,
      mass: 0.0020336868699246304 },
}
| kernel k |> std/kernel:self {
        kin1 += 0.5 * k.mass * (k.vx*k.vx + k.vy*k.vy + k.vz*k.vz)
    }
    |> std/kernel:pairwise {
        pot1 -= k.mass * k.other.mass / @sqrt((k.x-k.other.x)*(k.x-k.other.x) + (k.y-k.other.y)*(k.y-k.other.y) + (k.z-k.other.z)*(k.z-k.other.z))
    }
    |> std/kernel:reduce {
        kin1[f64]
        pot1[f64]
    }
    |> std/kernel:step(0..24000000)
    |> std/kernel:self {
        kin2 += 0.5 * k.mass * (k.vx*k.vx + k.vy*k.vy + k.vz*k.vz)
    }
    |> std/kernel:pairwise {
        pot2 -= k.mass * k.other.mass / @sqrt((k.x-k.other.x)*(k.x-k.other.x) + (k.y-k.other.y)*(k.y-k.other.y) + (k.z-k.other.z)*(k.z-k.other.z))
    }
    |> std/kernel:reduce {
        kin2[f64]
        pot2[f64]
    }
    | step |> std/kernel:pairwise {
            const dx = k.x - k.other.x;
            const dy = k.y - k.other.y;
            const dz = k.z - k.other.z;
            const dsq = dx*dx + dy*dy + dz*dz;
            const mag = 0.01 / (dsq * @sqrt(dsq));
            k.vx -= dx * (k.other.mass * mag);
            k.vy -= dy * (k.other.mass * mag);
            k.vz -= dz * (k.other.mass * mag);
            k.other.vx += dx * (k.mass * mag);
            k.other.vy += dy * (k.mass * mag);
            k.other.vz += dz * (k.mass * mag);
        } |> std/kernel:self {
                k.x += 0.01 * k.vx;
                k.y += 0.01 * k.vy;
                k.z += 0.01 * k.vz;
            }
| reduce r |> csfv(v: r.kin1 + r.pot1): h1
    |> csfv(v: r.kin2 + r.pot2): h2
    |> std/io:print.ln("{{ @rem((h1 << 5) & h2, 4294967296):d }}")
