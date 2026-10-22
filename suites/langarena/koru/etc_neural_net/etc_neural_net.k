// etc_neural_net — LangArena Etc::NeuralNet, run.js scored
// parameters (iterations=1700, warmup=340 → 2040 runs; each run
// trains a 2-10-1 sigmoid net on XOR 1000 times; checksum =
// checksumFloat(sum of the 4 test-case outputs) = DJB2 over the
// "{d:.7}" text — oracle 144809112).
//
// Lifecycle (benchmark.zig): reset(42) → prepare builds the net ONCE
// (13 neuron draws + 30 synapse draws of nextFloat(1.0)) → warmup →
// reset → run_all. Training draws nothing, so the second reset is
// inert; the same net is trained by all 2040 runs.
//
// Topology (fixed): neurons 0..1 inputs, 2..11 hidden, 12 output.
// synapses 0..9:   input0 → hidden h (dest 2+k)
// synapses 10..19: input1 → hidden h
// synapses 20..29: hidden h → output
// synapses_in[2+h] = {h, h+10}; synapses_in[12] = {20..29};
// synapses_out[2+h] = {20+h} (single synapse, dest 12).
//
// f64 op order mirrors the Zig source so intermediates round
// identically: err = (t-o)*o*(1-o); w += 0.3*err*src_out +
// 0.3*(w-prev_w); thr += 0.3*err*(-1) + 0.3*(thr-prev_thr);
// sigmoid = 1/(1+exp(-(act-thr))).
//
// Optimizations retained (checksum 144809112, min-of-5 0.68s vs
// baseline 0.74s; Rust max-perf reference 0.874s same box — Koru
// ahead at ~0.78x; timings drift ±0.03s across box states, an
// interleaved A/B of the two ff variants below was identical):
//  * uwl carries a computed source index s (hidden: 0..1, output:
//    2..11) instead of loading syn[si].src — removes a dependent load
//    + bounds check per synapse and lets SLP emit fmul.2d/fadd.2d in
//    updw/htl; syn.src column still initialized and faithful.
//  * idv/idvi value bindings replace fs.* store temporaries (neutral
//    vs v1 — LLVM had already promoted them — kept for clarity).
//
// Falsified hypotheses (all measured, all reverted):
//  * inline fdlibm-style exp (xexp tor): compiled, checksum green,
//    ~0.83s — Apple libm exp's table-based AArch64 path is faster.
//  * output-layer activation reassociation to a pair tree: checksum
//    stayed 144809112 (oracle only sees {d:.7} of the final sum) and an
//    interleaved min-of-6 A/B against the left fold was identical at
//    0.68s both ways; reverted to the reference fold for faithfulness.
//  * fixed-point skipping: probe /tmp/nn_work/nn_probe.k snapshots all
//    30 w/pw + 13 thr/pth bit patterns around each 4-case group —
//    stable_iters=0 across all 2,040,000 groups (checksum identical),
//    so no training group is a no-op to skip.
//  * Reassociation legality in general: confirmed checksum-permissible
//    (~1ulp departures invisible to the oracle) but no profitable
//    reassociation exists — the hidden layer is already 2-wide packed
//    and the serial adds are cheap next to 11 libm exp calls per
//    training case (~89.8M exp calls total = the measured floor).

import std/io
import std/grid
import std/store
import std/fmt

std/grid:new(neu, size: 13) { thr: 0.0[f64], pth: 0.0[f64], out: 0.0[f64], err: 0.0[f64] }
std/grid:new(syn, size: 30) { w: 0.0[f64], pw: 0.0[f64], src: 0[i64], dst: 0[i64] }
std/store:new(st) { res: 0[i64], last: 42[i64] }
std/store:new(fs) { col: 0.0[f64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// idv/idvi — value bindings (register-resident temporaries, recipe 6)
pub tor idv { v: f64 } -> f64
idv -> v

pub tor idvi { v: i64 } -> i64
idvi -> v

// nxf — nextFloat(1.0) = 1.0 * last/139968 (one rounding)
pub tor nxf { } -> f64
nxf = std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }: _ -> 1.0 * @as(f64, @floatFromInt(st.last)) / 139968.0

// ---- init: 13 neuron threshold draws, then 30 synapse draws ----
pub tor inl { n: i64 } -> i64
inl = nxf(): t
    |> std/grid:stored { neu[n].thr: t * 2.0 - 1.0 }
    |> std/grid:stored { neu[n].pth: neu[n].thr }
    |> if(n < 12)
        | then |> inl(n: n + 1): r -> r
        | else |> ret0(): r -> r

pub tor sy1 { k: i64 } -> i64
sy1 = nxf(): v
    |> std/grid:stored { syn[k].w: v * 2.0 - 1.0 }
    |> std/grid:stored { syn[k].pw: syn[k].w }
    |> std/grid:stored { syn[k].src: @divTrunc(k, 10) }
    |> std/grid:stored { syn[k].dst: 2 + @rem(k, 10) }
    |> if(k < 19)
        | then |> sy1(k: k + 1): r -> r
        | else |> ret0(): r -> r

pub tor sy2 { k: i64 } -> i64
sy2 = nxf(): v
    |> std/grid:stored { syn[20 + k].w: v * 2.0 - 1.0 }
    |> std/grid:stored { syn[20 + k].pw: syn[20 + k].w }
    |> std/grid:stored { syn[20 + k].src: 2 + k }
    |> std/grid:stored { syn[20 + k].dst: 12 }
    |> if(k < 9)
        | then |> sy2(k: k + 1): r -> r
        | else |> ret0(): r -> r

// ---- feedForward: inputs → hidden (2+h uses syns h, h+10) → output ----
pub tor ffh { h: i64 } -> i64
ffh = idv(v: syn[h].w * neu[0].out + syn[h + 10].w * neu[1].out - neu[h + 2].thr): ni
    |> std/grid:stored { neu[h + 2].out: 1.0 / (1.0 + @exp(0.0 - ni)) }
    |> if(h < 9)
        | then |> ffh(h: h + 1): r -> r
        | else |> ret0(): r -> r

// ffk — output-layer activation: reference left fold over syns 20+k
pub tor ffk { k: i64, acc: f64 } -> f64
ffk = if(k < 10)
| then |> ffk(k: k + 1, acc: acc + syn[20 + k].w * neu[k + 2].out): r -> r
| else -> acc

pub tor ff { a0: f64, a1: f64 } -> i64
ff = std/grid:stored { neu[0].out: a0 }
    |> std/grid:stored { neu[1].out: a1 }
    |> ffh(h: 0): _
    |> ffk(k: 0, acc: 0.0): act
    |> std/grid:stored { neu[12].out: 1.0 / (1.0 + @exp(0.0 - (act - neu[12].thr))) }
    |> ret0(): _ -> 0

// ---- updateWeights(n): synapses_in + threshold ----
// hidden n=2..11 → syns {n-2, n-2+10} (srcs 0,1); output n=12 → syns
// 20..29 (srcs 2..11). src/dst columns still carry the reference values;
// the per-synapse src lookup is collapsed to a computed index (fixed
// topology — synapses_in lists are built once and never change).
pub tor uwl { n: i64, k: i64, cnt: i64, si: i64, dlt: i64, s: i64, e: f64 } -> i64
uwl = if(k < cnt)
| then |> idv(v: syn[si].w): tw
    |> std/grid:stored { syn[si].w: tw + (0.3 * 1.0 * e * neu[s].out) + (0.3 * (tw - syn[si].pw)) }
    |> std/grid:stored { syn[si].pw: tw }
    |> uwl(n, k: k + 1, cnt, si: si + dlt, dlt, s: s + 1, e): r -> r
| else |> idv(v: neu[n].thr): tt
    |> std/grid:stored { neu[n].thr: tt + (0.3 * 1.0 * e * -1.0) + (0.3 * (tt - neu[n].pth)) }
    |> std/grid:stored { neu[n].pth: tt }
    |> ret0(): _ -> 0

pub tor updw { n: i64 } -> i64
updw = idv(v: neu[n].err): e
    |> if(n < 12)
        | then |> uwl(n, k: 0, cnt: 2, si: n - 2, dlt: 10, s: 0, e): r -> r
        | else |> uwl(n, k: 0, cnt: 10, si: 20, dlt: 1, s: 2, e): r -> r

// htl — hiddenTrain for neurons 2..11 in order; each reads
// prev_weight of its single out-synapse (20+h) times err[12]
pub tor htl { h: i64 } -> i64
htl = std/grid:stored { neu[h + 2].err: syn[20 + h].pw * neu[12].err * (neu[h + 2].out * (1.0 - neu[h + 2].out)) }
    |> updw(n: h + 2): _
    |> if(h < 9)
        | then |> htl(h: h + 1): r -> r
        | else |> ret0(): r -> r

// train — feedForward + outputTrain(12) + hiddenTrain(2..11)
pub tor train { a0: f64, a1: f64, tg: f64 } -> i64
train = ff(a0, a1): _
    |> std/grid:stored { neu[12].err: (tg - neu[12].out) * (neu[12].out * (1.0 - neu[12].out)) }
    |> updw(n: 12): _
    |> htl(h: 0): r -> r

// trn — one run: 1000 × train(00→0, 10→1, 01→1, 11→0)
pub tor trn { k: i64 } -> i64
trn = train(a0: 0.0, a1: 0.0, tg: 0.0): _
    |> train(a0: 1.0, a1: 0.0, tg: 1.0): _
    |> train(a0: 0.0, a1: 1.0, tg: 1.0): _
    |> train(a0: 1.0, a1: 1.0, tg: 0.0): _
    |> if(k < 999)
        | then |> trn(k: k + 1): r -> r
        | else |> ret0(): r -> r

// runl — 2040 runs (1700 scored + 340 warmup) on the same net
pub tor runl { it: i64 } -> i64
runl = trn(k: 0): _
    |> if(it < 2039)
        | then |> runl(it: it + 1): r -> r
        | else |> ret0(): r -> r

// ---- checksum: feedForward the 4 test cases, sum out[12],
// format {d:.7}, DJB2 mod 2^32 over the bytes ----
pub tor tsum { t: i64 } -> i64
tsum = if(t < 4)
| then |> if(t == 0)
    | then |> ff(a0: 0.0, a1: 0.0): _
    | else |> if(t == 1)
        | then |> ff(a0: 0.0, a1: 1.0): _
        | else |> if(t == 2)
            | then |> ff(a0: 1.0, a1: 0.0): _
            | else |> ff(a0: 1.0, a1: 1.0): _
    |> std/store:stored { fs.col: fs.col + neu[12].out }
    |> tsum(t: t + 1): r -> r
| else -> 0

// djh — DJB2 mod 2^32 over a formatted text's bytes
pub tor djh { t: string<*@scoped> } -> i64
djh = std/store:stored { st.res: 5381 }
    |> djb(k: 0, t): r -> r

pub tor djb { k: i64, t: string<*@scoped> } -> i64
djb = if(k < t.len)
| then |> std/store:stored { st.res: @rem(st.res * 33 + @as(i64, @intCast(t[@as(usize, @intCast(k))])), 4294967296) }
    |> djb(k: k + 1, t): r -> r
| else -> st.res

ret0(): _
|> inl(n: 0): _
|> sy1(k: 0): _
|> sy2(k: 0): _
|> runl(it: 0): _
|> tsum(t: 0): _
|> std/fmt:ln("{{ fs.col:d:.7 }}"): ft
|> djh(t: ft.text): r
|> std/io:print.ln("{{ r:d }}")
