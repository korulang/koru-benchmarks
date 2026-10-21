// clbg_nbody — LangArena CLBG::Nbody, run.js scored parameters
// (iterations=20000, warmup default = iters*0.2 = 4000 → 24000 runs;
// each run = 1000 integration steps over the 5-body system and state
// ACCUMULATES across runs; checksum = (csf(v1) << 5) & csf(v2),
// u32 arithmetic — oracle 338799744).
//
// No RNG: fixed initial conditions. Constants are baked f64 literals —
// Zig evaluates vx*365.24 / mass*SOLAR_MASS in one f64 rounding each;
// writing the products keeps the Koru side bit-identical
// (SOLAR_MASS = 4*pi*pi = 39.47841760435743).
//
// Pair updates replicate moveFromI exactly: body i's pair pass AND
// position advance happen before body i+1's pass; the reference
// computes mag = dt / (d*d*d) with d = sqrt(...) — three multiplies,
// reproduced literally since the roundings differ from d/sqrt forms.
//
import std/io
import std/grid
import std/store
import std/fmt

std/grid:new(bd, size: 5) { x: 0.0[f64], y: 0.0[f64], z: 0.0[f64], vx: 0.0[f64], vy: 0.0[f64], vz: 0.0[f64], m: 0.0[f64] }
std/store:new(st) { t3: 0[i64], acc: 0[i64] }
std/store:new(fs) { e: 0.0[f64], v1: 0.0[f64], dx: 0.0[f64], dy: 0.0[f64], dz: 0.0[f64], d: 0.0[f64], mg: 0.0[f64], bm: 0.0[f64], b2m: 0.0[f64], px: 0.0[f64], py: 0.0[f64], pz: 0.0[f64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// pairw — one moveFromI pair interaction between bodies i and j:
// velocity impulse on both. Store scratch is safe — no recursion
// between set and use within this leaf tor.
pub tor pairw { i: i64, j: i64 } -> i64
pairw = std/store:stored { fs.dx: bd[i].x - bd[j].x }
    |> std/store:stored { fs.dy: bd[i].y - bd[j].y }
    |> std/store:stored { fs.dz: bd[i].z - bd[j].z }
    |> std/store:stored { fs.d: @sqrt(fs.dx * fs.dx + fs.dy * fs.dy + fs.dz * fs.dz) }
    |> std/store:stored { fs.mg: 0.01 / (fs.d * fs.d * fs.d) }
    |> std/store:stored { fs.bm: bd[i].m * fs.mg }
    |> std/store:stored { fs.b2m: bd[j].m * fs.mg }
    |> std/grid:stored { bd[i].vx: bd[i].vx - fs.dx * fs.b2m }
    |> std/grid:stored { bd[i].vy: bd[i].vy - fs.dy * fs.b2m }
    |> std/grid:stored { bd[i].vz: bd[i].vz - fs.dz * fs.b2m }
    |> std/grid:stored { bd[j].vx: bd[j].vx + fs.dx * fs.bm }
    |> std/grid:stored { bd[j].vy: bd[j].vy + fs.dy * fs.bm }
    |> std/grid:stored { bd[j].vz: bd[j].vz + fs.dz * fs.bm }
    |> ret0(): _ -> 0

// pl — the j-loop inside moveFromI: pairs (i, j) for j = i+1..4
pub tor pl { bi: i64, bj: i64 } -> i64
pl = if(bj < 5)
| then |> pairw(i: bi, j: bj): _
    |> pl(bi, bj: bj + 1): r -> r
| else -> 0

// movi — moveFromI: pair pass for body i, then its position advance
pub tor movi { i: i64 } -> i64
movi = pl(bi: i, bj: i + 1): _
    |> std/grid:stored { bd[i].x: bd[i].x + 0.01 * bd[i].vx }
    |> std/grid:stored { bd[i].y: bd[i].y + 0.01 * bd[i].vy }
    |> std/grid:stored { bd[i].z: bd[i].z + 0.01 * bd[i].vz }
    |> ret0(): _ -> 0

// stepi — the i-loop of one integration step
pub tor stepi { i: i64 } -> i64
stepi = if(i < 5)
| then |> movi(i): _
    |> stepi(i: i + 1): r -> r
| else -> 0

// runn — one run = 1000 steps
pub tor runn { n: i64 } -> i64
runn = if(n < 1000)
| then |> stepi(i: 0): _
    |> runn(n: n + 1): r -> r
| else -> 0

// runl — 24000 runs (20000 measured + 4000 warmup)
pub tor runl { k: i64 } -> i64
runl = if(k < 24000)
| then |> runn(n: 0): _
    |> runl(k: k + 1): r -> r
| else -> 0

// ---- energy: e = Σ ½mv² − ΣΣ mᵢmⱼ/d ----

// enj — inner pair loop of energy for body i
pub tor enj { i: i64, j: i64 } -> i64
enj = if(j < 5)
| then |> std/store:stored { fs.dx: bd[i].x - bd[j].x }
    |> std/store:stored { fs.dy: bd[i].y - bd[j].y }
    |> std/store:stored { fs.dz: bd[i].z - bd[j].z }
    |> std/store:stored { fs.d: @sqrt(fs.dx * fs.dx + fs.dy * fs.dy + fs.dz * fs.dz) }
    |> std/store:stored { fs.e: fs.e - bd[i].m * bd[j].m / fs.d }
    |> enj(i, j: j + 1): r -> r
| else -> 0

// eni — outer energy loop
pub tor eni { i: i64 } -> i64
eni = if(i < 5)
| then |> std/store:stored { fs.e: fs.e + 0.5 * bd[i].m * (bd[i].vx * bd[i].vx + bd[i].vy * bd[i].vy + bd[i].vz * bd[i].vz) }
    |> enj(i, j: i + 1): _
    |> eni(i: i + 1): r -> r
| else -> 0

// energy — e through fs, produced for the caller
pub tor energy { } -> f64
energy = std/store:stored { fs.e: 0.0 }
    |> eni(i: 0): _
    |> ret0(): _ -> fs.e

// ---- offsetMomentum: sun takes -Σmv/SM ----

// offl — momentum accumulation loop
pub tor offl { i: i64 } -> i64
offl = if(i < 5)
| then |> std/store:stored { fs.px: fs.px + bd[i].vx * bd[i].m }
    |> std/store:stored { fs.py: fs.py + bd[i].vy * bd[i].m }
    |> std/store:stored { fs.pz: fs.pz + bd[i].vz * bd[i].m }
    |> offl(i: i + 1): r -> r
| else -> 0

pub tor offp { } -> i64
offp = std/store:stored { fs.px: 0.0 }
    |> std/store:stored { fs.py: 0.0 }
    |> std/store:stored { fs.pz: 0.0 }
    |> offl(i: 0): _
    |> std/grid:stored { bd[0].vx: (0.0 - fs.px) / 39.47841760435743 }
    |> std/grid:stored { bd[0].vy: (0.0 - fs.py) / 39.47841760435743 }
    |> std/grid:stored { bd[0].vz: (0.0 - fs.pz) / 39.47841760435743 }
    |> ret0(): _ -> 0

// djh — DJB2 a scoped string into st.t3 (u32 arithmetic)
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

// ---- driver ----

// init — baked literals (v*365.24, m*SOLAR_MASS precomputed)
std/grid:stored { bd[0].x: 0.0 }
|> std/grid:stored { bd[0].y: 0.0 }
|> std/grid:stored { bd[0].z: 0.0 }
|> std/grid:stored { bd[0].vx: 0.0 }
|> std/grid:stored { bd[0].vy: 0.0 }
|> std/grid:stored { bd[0].vz: 0.0 }
|> std/grid:stored { bd[0].m: 39.47841760435743 }
|> std/grid:stored { bd[1].x: 4.841431442464721 }
|> std/grid:stored { bd[1].y: -1.1603200440274284 }
|> std/grid:stored { bd[1].z: -0.10362204447112311 }
|> std/grid:stored { bd[1].vx: 0.606326392995832 }
|> std/grid:stored { bd[1].vy: 2.81198684491626 }
|> std/grid:stored { bd[1].vz: -0.02521836165988763 }
|> std/grid:stored { bd[1].m: 0.03769367487038949 }
|> std/grid:stored { bd[2].x: 8.34336671824458 }
|> std/grid:stored { bd[2].y: 4.124798564124305 }
|> std/grid:stored { bd[2].z: -0.4035234171143214 }
|> std/grid:stored { bd[2].vx: -1.0107743461787924 }
|> std/grid:stored { bd[2].vy: 1.8256623712304119 }
|> std/grid:stored { bd[2].vz: 0.008415761376584154 }
|> std/grid:stored { bd[2].m: 0.011286326131968767 }
|> std/grid:stored { bd[3].x: 12.894369562139131 }
|> std/grid:stored { bd[3].y: -15.111151401698631 }
|> std/grid:stored { bd[3].z: -0.22330757889265573 }
|> std/grid:stored { bd[3].vx: 1.0827910064415354 }
|> std/grid:stored { bd[3].vy: 0.8687130181696082 }
|> std/grid:stored { bd[3].vz: -0.010832637401363636 }
|> std/grid:stored { bd[3].m: 0.0017237240570597112 }
|> std/grid:stored { bd[4].x: 15.379697114850917 }
|> std/grid:stored { bd[4].y: -25.919314609987964 }
|> std/grid:stored { bd[4].z: 0.17925877295037118 }
|> std/grid:stored { bd[4].vx: 0.979090732243898 }
|> std/grid:stored { bd[4].vy: 0.5946989986476762 }
|> std/grid:stored { bd[4].vz: -0.034755955504078104 }
|> std/grid:stored { bd[4].m: 0.0020336868699246304 }
|> offp(): _
|> energy(): v
|> std/store:stored { fs.v1: v }
|> runl(k: 0): _
|> energy(): v2
|> csfv(v: fs.v1): h1
|> csfv(v: v2): h2
|> std/io:print.ln("{{ @rem((h1 << 5) & h2, 4294967296):d }}")
