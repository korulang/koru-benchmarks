// clbg_spectralnorm — LangArena CLBG::Spectralnorm, run.js scored
// parameters (size=1200, iterations=132, warmup default
// iters*0.2 = 26 → 158 runs; u/v persist across runs — each run does
// v_new = AtA·u then u_new = AtA·v_new; checksum =
// checksumFloat(sqrt(vBv/vv)) — oracle 1052198219).
//
// A(i,j) = 1 / (s(s+1)/2 + i + 1), s = i+j — the CLBG spectral-norm
// power-iteration kernel. Pure f64 grids; the two-step AtA is staged
// through gsrc/gw scratch rows, exact operation order as the
// reference's eval_A_times_u / eval_At_times_u pair.
//
import std/io
import std/grid
import std/store
import std/fmt

std/grid:new(gu, size: 1200) { v: 0.0[f64] }
std/grid:new(gv, size: 1200) { v: 0.0[f64] }
std/grid:new(gsrc, size: 1200) { v: 0.0[f64] }
std/grid:new(gw, size: 1200) { v: 0.0[f64] }
std/store:new(st) { t3: 0[i64] }
std/store:new(fs) { sum: 0.0[f64], vbv: 0.0[f64], vv: 0.0[f64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// ---- eval_A_times_u: rowa walks i, cola accumulates over j ----

pub tor cola { i: i64, j: i64 } -> i64
cola = if(j < 1200)
| then |> std/store:stored { fs.sum: fs.sum + 1.0 / ((@as(f64, @floatFromInt(i)) + @as(f64, @floatFromInt(j))) * (@as(f64, @floatFromInt(i)) + @as(f64, @floatFromInt(j)) + 1.0) / 2.0 + @as(f64, @floatFromInt(i)) + 1.0) * gsrc[j].v }
    |> cola(i, j: j + 1): r -> r
| else -> 0

pub tor rowa { i: i64 } -> i64
rowa = if(i < 1200)
| then |> std/store:stored { fs.sum: 0.0 }
    |> cola(i, j: 0): _
    |> std/grid:stored { gw[i].v: fs.sum }
    |> rowa(i: i + 1): r -> r
| else -> 0

// ---- eval_At_times_u over gw: colt accumulates A(j,i)*gw[j] ----

// coltv — writes into gv (v_new)
pub tor coltv { i: i64, j: i64 } -> i64
coltv = if(j < 1200)
| then |> std/store:stored { fs.sum: fs.sum + 1.0 / ((@as(f64, @floatFromInt(j)) + @as(f64, @floatFromInt(i))) * (@as(f64, @floatFromInt(j)) + @as(f64, @floatFromInt(i)) + 1.0) / 2.0 + @as(f64, @floatFromInt(j)) + 1.0) * gw[j].v }
    |> coltv(i, j: j + 1): r -> r
| else -> 0

pub tor rowtv { i: i64 } -> i64
rowtv = if(i < 1200)
| then |> std/store:stored { fs.sum: 0.0 }
    |> coltv(i, j: 0): _
    |> std/grid:stored { gv[i].v: fs.sum }
    |> rowtv(i: i + 1): r -> r
| else -> 0

// coltu — writes into gu (u_new)
pub tor coltu { i: i64, j: i64 } -> i64
coltu = if(j < 1200)
| then |> std/store:stored { fs.sum: fs.sum + 1.0 / ((@as(f64, @floatFromInt(j)) + @as(f64, @floatFromInt(i))) * (@as(f64, @floatFromInt(j)) + @as(f64, @floatFromInt(i)) + 1.0) / 2.0 + @as(f64, @floatFromInt(j)) + 1.0) * gw[j].v }
    |> coltu(i, j: j + 1): r -> r
| else -> 0

pub tor rowtu { i: i64 } -> i64
rowtu = if(i < 1200)
| then |> std/store:stored { fs.sum: 0.0 }
    |> coltu(i, j: 0): _
    |> std/grid:stored { gu[i].v: fs.sum }
    |> rowtu(i: i + 1): r -> r
| else -> 0

// ---- gsrc copies ----

pub tor cpu { i: i64 } -> i64
cpu = if(i < 1200)
| then |> std/grid:stored { gsrc[i].v: gu[i].v }
    |> cpu(i: i + 1): r -> r
| else -> 0

pub tor cpv { i: i64 } -> i64
cpv = if(i < 1200)
| then |> std/grid:stored { gsrc[i].v: gv[i].v }
    |> cpv(i: i + 1): r -> r
| else -> 0

// onerun — v_new = AtA·u then u_new = AtA·v_new
pub tor onerun { } -> i64
onerun = cpu(i: 0): _
    |> rowa(i: 0): _
    |> rowtv(i: 0): _
    |> cpv(i: 0): _
    |> rowa(i: 0): _
    |> rowtu(i: 0): _
    |> ret0(): _ -> 0

// runl — 158 runs (132 measured + 26 warmup)
pub tor runl { k: i64 } -> i64
runl = if(k < 158)
| then |> onerun(): _
    |> runl(k: k + 1): r -> r
| else -> 0

// ---- checksum: sqrt(vBv / vv) → checksumFloat ----

pub tor dotl { i: i64 } -> i64
dotl = if(i < 1200)
| then |> std/store:stored { fs.vbv: fs.vbv + gu[i].v * gv[i].v }
    |> std/store:stored { fs.vv: fs.vv + gv[i].v * gv[i].v }
    |> dotl(i: i + 1): r -> r
| else -> 0

// djh — DJB2 a scoped string into st.t3 (u32 arithmetic)
pub tor djh { t: string<*@scoped> } -> i64
djh = for(0..t.len)
    ! each k |> std/store:stored { st.t3: @rem(st.t3 * 33 + @as(i64, @intCast(t[k])), 4294967296) }
    | done
    |> ret0(): _ -> 0

pub tor csfv { v: f64 } -> i64
csfv = std/fmt:ln("{{ v:d:.7 }}"): s
    |> std/store:stored { st.t3: 5381 }
    |> djh(t: s.text): _
    |> ret0(): _ -> st.t3

// ---- driver ----

// u = v = 1.0
for(0..1200)
! each i |> std/grid:stored { gu[i].v: 1.0 }
    |> std/grid:stored { gv[i].v: 1.0 }

runl(k: 0): _
|> std/store:stored { fs.vbv: 0.0 }
|> std/store:stored { fs.vv: 0.0 }
|> dotl(i: 0): _
|> csfv(v: @sqrt(fs.vbv / fs.vv)): h
|> std/io:print.ln("{{ h:d }}")
