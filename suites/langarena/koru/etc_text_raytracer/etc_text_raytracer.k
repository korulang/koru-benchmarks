// etc_text_raytracer — LangArena Etc::TextRaytracer, run.js scored
// parameters (w=800, h=800, iterations=100, warmup=20 → 120 runs;
// each run shades every pixel and adds its LUT byte to result_val;
// checksum = result_val as u32 — oracle 2761140480).
//
// Fully deterministic — no RNG. Per pixel: ray dir =
// normalize(((i-w/2)/w, (j-h/2)/h, 1)); first sphere in SCENE order
// that intersects wins (NOT nearest — carried literally); shading is
// Lambert diffuse toward LIGHT1 at (0.7,-1.0,1.7), color =
// white*(clamp(lam,0,1)*0.5) + sphere.color*0.3, LUT index =
// int(col*6) clamped to 5. No-hit pixel contributes ' ' (32).
//
// f64 op sequences mirror the Zig reference exactly — every
// intermediate rounds the same way, which is what the checksum pins.
// Iteration order doesn't matter (pure byte sum); a flat k over
// w*h keeps one loop.

import std/io
import std/grid
import std/store

// sphere table: center, radius, color  (red, green, blue)
std/grid:new(sph, size: 3) { cx: 0.0[f64], cy: 0.0[f64], cz: 0.0[f64], r: 0.0[f64], cr: 0.0[f64], cg: 0.0[f64], cb: 0.0[f64] }
// LUT ".-+*XM"
std/grid:new(lut, size: 6) { v: 0[i64] }
std/store:new(st) { res: 0[i64], hit: 0[i64], ci: 0[i64], idx: 0[i64], w: 800[i64], h: 800[i64] }
std/store:new(fs) { dx: 0.0[f64], dy: 0.0[f64], dz: 0.0[f64], tv: 0.0[f64], mg: 0.0[f64], tc: 0.0[f64], r2: 0.0[f64], d2: 0.0[f64], px: 0.0[f64], py: 0.0[f64], pz: 0.0[f64], nx: 0.0[f64], ny: 0.0[f64], nz: 0.0[f64], lx: 0.0[f64], ly: 0.0[f64], lz: 0.0[f64], lm: 0.0[f64], l5: 0.0[f64], cr: 0.0[f64], cg: 0.0[f64], cb: 0.0[f64], col: 0.0[f64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// invm — 1/fs.mg, or 0 when mg == 0 (Vector.normalize's zero guard)
pub tor invm { } -> f64
invm = if(fs.mg > 0.0)
| then -> 1.0 / fs.mg
| else -> 0.0

// pxl — ray direction for pixel (fi, fj), normalized in place
pub tor pxl { fi: f64, fj: f64 } -> i64
pxl = std/store:stored { st.hit: 0 }
    |> std/store:stored { fs.dx: (fi - @as(f64, @floatFromInt(st.w)) / 2.0) / @as(f64, @floatFromInt(st.w)) }
    |> std/store:stored { fs.dy: (fj - @as(f64, @floatFromInt(st.h)) / 2.0) / @as(f64, @floatFromInt(st.h)) }
    |> std/store:stored { fs.dz: 1.0 }
    |> std/store:stored { fs.mg: @sqrt(fs.dx * fs.dx + fs.dy * fs.dy + fs.dz * fs.dz) }
    |> invm(): iv
    |> std/store:stored { fs.dx: fs.dx * iv }
    |> std/store:stored { fs.dy: fs.dy * iv }
    |> std/store:stored { fs.dz: fs.dz * iv }
    |> trys(s: 0): _
    |> trys(s: 1): _
    |> trys(s: 2): _
    |> fini(): r -> r

// trys — try sphere s unless an earlier sphere already hit
// (reference keeps the FIRST intersecting sphere in scene order)
pub tor trys { s: i64 } -> i64
trys = if(st.hit == 0)
| then |> tsgo(s): r -> r
| else |> ret0(): r -> r

// tsgo — tca = l·dir; tca < 0 → no hit
pub tor tsgo { s: i64 } -> i64
tsgo = std/store:stored { fs.tc: sph[s].cx * fs.dx + sph[s].cy * fs.dy + sph[s].cz * fs.dz }
    |> if(fs.tc < 0.0)
        | then |> ret0(): r -> r
        | else |> ts2(s): r -> r

// ts2 — d2 = l·l - tca², r2 = radius²; d2 > r2 → no hit
pub tor ts2 { s: i64 } -> i64
ts2 = std/store:stored { fs.r2: sph[s].r * sph[s].r }
    |> std/store:stored { fs.d2: sph[s].cx * sph[s].cx + sph[s].cy * sph[s].cy + sph[s].cz * sph[s].cz - fs.tc * fs.tc }
    |> if(fs.d2 > fs.r2)
        | then |> ret0(): r -> r
        | else |> ts3(s): r -> r

// ts3 — thc = sqrt(r2-d2), t0 = tca-thc; t0 > 10000 → no hit
pub tor ts3 { s: i64 } -> i64
ts3 = std/store:stored { fs.tv: fs.tc - @sqrt(fs.r2 - fs.d2) }
    |> if(fs.tv > 10000.0)
        | then |> ret0(): r -> r
        | else |> std/store:stored { st.hit: 1 }
            |> std/store:stored { st.ci: s }
            |> ret0(): r -> r

// clam — fs.lm = clamp(fs.lm, 0, 1)
pub tor clam { } -> i64
clam = if(fs.lm < 0.0)
| then |> std/store:stored { fs.lm: 0.0 }: _ -> 0
| else |> if(fs.lm > 1.0)
    | then |> std/store:stored { fs.lm: 1.0 }: _ -> 0
    | else |> ret0(): r -> r

// shade — diffuseShading + LUT index; assumes st.hit/st.ci/fs.tv set.
// pi = orig + dir*tval (orig is the zero vector)
pub tor shade { } -> i64
shade = std/store:stored { fs.px: fs.dx * fs.tv }
    |> std/store:stored { fs.py: fs.dy * fs.tv }
    |> std/store:stored { fs.pz: fs.dz * fs.tv }
    |> std/store:stored { fs.nx: fs.px - sph[st.ci].cx }
    |> std/store:stored { fs.ny: fs.py - sph[st.ci].cy }
    |> std/store:stored { fs.nz: fs.pz - sph[st.ci].cz }
    |> std/store:stored { fs.mg: @sqrt(fs.nx * fs.nx + fs.ny * fs.ny + fs.nz * fs.nz) }
    |> invm(): iv
    |> std/store:stored { fs.nx: fs.nx * iv }
    |> std/store:stored { fs.ny: fs.ny * iv }
    |> std/store:stored { fs.nz: fs.nz * iv }
    |> std/store:stored { fs.lx: 0.7 - fs.px }
    |> std/store:stored { fs.ly: -1.0 - fs.py }
    |> std/store:stored { fs.lz: 1.7 - fs.pz }
    |> std/store:stored { fs.mg: @sqrt(fs.lx * fs.lx + fs.ly * fs.ly + fs.lz * fs.lz) }
    |> invm(): iv2
    |> std/store:stored { fs.lx: fs.lx * iv2 }
    |> std/store:stored { fs.ly: fs.ly * iv2 }
    |> std/store:stored { fs.lz: fs.lz * iv2 }
    |> std/store:stored { fs.lm: fs.lx * fs.nx + fs.ly * fs.ny + fs.lz * fs.nz }
    |> clam(): _
    |> std/store:stored { fs.l5: fs.lm * 0.5 }
    |> std/store:stored { fs.cr: fs.l5 + sph[st.ci].cr * 0.3 }
    |> std/store:stored { fs.cg: fs.l5 + sph[st.ci].cg * 0.3 }
    |> std/store:stored { fs.cb: fs.l5 + sph[st.ci].cb * 0.3 }
    |> std/store:stored { fs.col: (fs.cr + fs.cg + fs.cb) / 3.0 }
    |> std/store:stored { st.idx: @as(i64, @intFromFloat(fs.col * 6.0)) }
    |> if(st.idx >= 6)
        | then |> std/store:stored { st.idx: 5 }: _ -> 0
        | else |> ret0(): r -> r

// fini — pixel byte: LUT[idx] on hit, ' ' (32) on miss;
// += into the i64 accumulator (u32 wrap applied once at the end)
pub tor fini { } -> i64
fini = if(st.hit == 1)
| then |> shade(): _
    |> std/store:stored { st.res: st.res + lut[st.idx].v }
    |> ret0(): r -> r
| else |> std/store:stored { st.res: st.res + 32 }
    |> ret0(): r -> r

// coll — i inner loop of row j
pub tor coll { i: i64, j: i64 } -> i64
coll = pxl(fi: @as(f64, @floatFromInt(i)), fj: @as(f64, @floatFromInt(j))): _
    |> if(i < st.w - 1)
        | then |> coll(i: i + 1, j): r -> r
        | else |> ret0(): r -> r

// rowl — j outer loop
pub tor rowl { j: i64 } -> i64
rowl = coll(i: 0, j): _
    |> if(j < st.h - 1)
        | then |> rowl(j: j + 1): r -> r
        | else |> ret0(): r -> r

// runl — 120 runs (100 iterations + 20 warmup); every run identical,
// res accumulates across all of them
pub tor runl { k: i64 } -> i64
runl = if(k < 120)
| then |> rowl(j: 0): _
    |> runl(k: k + 1): r -> r
| else -> st.res

// ---- driver: fill scene tables, run, print checksum ----
ret0(): _
|> std/grid:stored { sph[0].cx: -1.0 }
|> std/grid:stored { sph[0].cy: 0.0 }
|> std/grid:stored { sph[0].cz: 3.0 }
|> std/grid:stored { sph[0].r: 0.3 }
|> std/grid:stored { sph[0].cr: 1.0 }
|> std/grid:stored { sph[0].cg: 0.0 }
|> std/grid:stored { sph[0].cb: 0.0 }
|> std/grid:stored { sph[1].cx: 0.0 }
|> std/grid:stored { sph[1].cy: 0.0 }
|> std/grid:stored { sph[1].cz: 3.0 }
|> std/grid:stored { sph[1].r: 0.8 }
|> std/grid:stored { sph[1].cr: 0.0 }
|> std/grid:stored { sph[1].cg: 1.0 }
|> std/grid:stored { sph[1].cb: 0.0 }
|> std/grid:stored { sph[2].cx: 1.0 }
|> std/grid:stored { sph[2].cy: 0.0 }
|> std/grid:stored { sph[2].cz: 3.0 }
|> std/grid:stored { sph[2].r: 0.4 }
|> std/grid:stored { sph[2].cr: 0.0 }
|> std/grid:stored { sph[2].cg: 0.0 }
|> std/grid:stored { sph[2].cb: 1.0 }
|> std/grid:stored { lut[0].v: 46 }
|> std/grid:stored { lut[1].v: 45 }
|> std/grid:stored { lut[2].v: 43 }
|> std/grid:stored { lut[3].v: 42 }
|> std/grid:stored { lut[4].v: 88 }
|> std/grid:stored { lut[5].v: 77 }
|> runl(k: 0): r
|> std/io:print.ln("{{ @rem(r, 4294967296):d }}")
