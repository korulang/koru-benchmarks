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

import std/io
import std/grid
import std/store
import std/fmt

std/grid:new(neu, size: 13) { thr: 0.0[f64], pth: 0.0[f64], out: 0.0[f64], err: 0.0[f64] }
std/grid:new(syn, size: 30) { w: 0.0[f64], pw: 0.0[f64], src: 0[i64], dst: 0[i64] }
std/store:new(st) { res: 0[i64], last: 42[i64] }
std/store:new(fs) { act: 0.0[f64], ni: 0.0[f64], sum: 0.0[f64], e: 0.0[f64], tw: 0.0[f64], so: 0.0[f64], tt: 0.0[f64], x0: 0.0[f64], x1: 0.0[f64], tg: 0.0[f64], col: 0.0[f64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

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
ffh = std/store:stored { fs.act: syn[h].w * neu[0].out + syn[h + 10].w * neu[1].out }
    |> std/store:stored { fs.ni: fs.act - neu[h + 2].thr }
    |> std/grid:stored { neu[h + 2].out: 1.0 / (1.0 + @exp(0.0 - fs.ni)) }
    |> if(h < 9)
        | then |> ffh(h: h + 1): r -> r
        | else |> ret0(): r -> r

// ffk — accumulate output-layer activation over syns 20+k
pub tor ffk { k: i64, acc: f64 } -> f64
ffk = if(k < 10)
| then |> ffk(k: k + 1, acc: acc + syn[20 + k].w * neu[k + 2].out): r -> r
| else -> acc

pub tor ff { a0: f64, a1: f64 } -> i64
ff = std/grid:stored { neu[0].out: a0 }
    |> std/grid:stored { neu[1].out: a1 }
    |> ffh(h: 0): _
    |> ffk(k: 0, acc: 0.0): act
    |> std/store:stored { fs.ni: act - neu[12].thr }
    |> std/grid:stored { neu[12].out: 1.0 / (1.0 + @exp(0.0 - fs.ni)) }
    |> ret0(): _ -> 0

// ---- updateWeights(n): synapses_in + threshold ----
// hidden n=2..11 → syns {n-2, n-2+10}; output n=12 → syns 20..29
pub tor uwl { n: i64, k: i64, cnt: i64, si: i64, dlt: i64 } -> i64
uwl = if(k < cnt)
| then |> std/store:stored { fs.tw: syn[si].w }
    |> std/store:stored { fs.so: neu[syn[si].src].out }
    |> std/grid:stored { syn[si].w: syn[si].w + (0.3 * 1.0 * fs.e * fs.so) + (0.3 * (syn[si].w - syn[si].pw)) }
    |> std/grid:stored { syn[si].pw: fs.tw }
    |> uwl(n, k: k + 1, cnt, si: si + dlt, dlt): r -> r
| else |> std/store:stored { fs.tt: neu[n].thr }
    |> std/grid:stored { neu[n].thr: neu[n].thr + (0.3 * 1.0 * fs.e * -1.0) + (0.3 * (neu[n].thr - neu[n].pth)) }
    |> std/grid:stored { neu[n].pth: fs.tt }
    |> ret0(): _ -> 0

pub tor updw { n: i64 } -> i64
updw = std/store:stored { fs.e: neu[n].err }
    |> if(n < 12)
        | then |> uwl(n, k: 0, cnt: 2, si: n - 2, dlt: 10): r -> r
        | else |> uwl(n, k: 0, cnt: 10, si: 20, dlt: 1): r -> r

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
