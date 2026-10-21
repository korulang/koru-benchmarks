// clbg_mandelbrot — LangArena CLBG::Mandelbrot, run.js scored
// parameters (w=400, h=400, iterations=100, warmup=20 → 120 runs;
// each run APPENDS "P4\n400 400\n" + 20000 bitmap bytes to result_bin
// — the buffer accumulates, 2401200 bytes total; checksum =
// checksumBytes over all of it — oracle 3455988829).
//
// Per pixel: escape iteration z' = z²+c, ITER=50, |z|² ≤ 4; byte_acc
// shifts left per pixel, low bit set when the pixel stayed bounded;
// flush on bit_num==8 or row end (w%8==0 → the pad branch is inert
// but carried faithfully).
//
import std/io
import std/grid
import std/store
import std/fmt

std/grid:new(doc, size: 2402000) { b: 0[u8] }
std/store:new(st) { acc: 0[i64], p: 0[i64], ba: 0[i64], bn: 0[i64], t3: 0[i64] }
std/store:new(fs) { cr: 0.0[f64], ci: 0.0[f64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// lit — copy a literal's bytes into the doc
pub tor lit { t: string } -> i64
lit = for(0..t.len)
    ! each k |> std/grid:stored { doc[st.p].b: t[k] }
        |> std/store:stored { st.p: st.p + 1 }
    | done
    |> ret0(): _ -> 0

// pb — one raw byte
pub tor pb { b: i64 } -> i64
pb = std/grid:stored { doc[st.p].b: @as(u8, @intCast(b)) }
    |> std/store:stored { st.p: st.p + 1 }
    |> ret0(): _ -> 0

// escp — escape loop: produces 1 if still bounded at exit, else 0.
// Update order matches the reference: zi uses old zr, then zr, then
// the squared magnitudes.
pub tor escp { i: i64, zr: f64, zi: f64, tr: f64, ti: f64 } -> i64
escp = if(i < 50 and tr + ti <= 4.0)
| then |> escp(i: i + 1, zr: tr - ti + fs.cr, zi: 2.0 * zr * zi + fs.ci, tr: (tr - ti + fs.cr) * (tr - ti + fs.cr), ti: (2.0 * zr * zi + fs.ci) * (2.0 * zr * zi + fs.ci)): r -> r
| else |> if(tr + ti <= 4.0)
    | then -> 1
    | else -> 0

// flushb — emit byte_acc when a byte completes or at row end
pub tor flushb { x: i64 } -> i64
flushb = if(st.bn == 8)
| then |> pb(b: st.ba): _
    |> std/store:stored { st.ba: 0 }
    |> std/store:stored { st.bn: 0 }: _ -> 0
| else |> if(x == 399)
    | then |> if(8 - @rem(400, 8) < 8)
        | then |> std/store:stored { st.ba: st.ba * (@as(i64, 1) << @as(u6, @intCast(8 - @rem(400, 8)))) }
        | else |> ret0(): _
        |> pb(b: st.ba): _
        |> std/store:stored { st.ba: 0 }
        |> std/store:stored { st.bn: 0 }: _ -> 0
    | else -> 0

// pixl — one pixel: cr = 2x/w - 1.5, escape, shift in the bit
pub tor pixl { x: i64, y: i64 } -> i64
pixl = if(x < 400)
| then |> std/store:stored { fs.cr: 2.0 * @as(f64, @floatFromInt(x)) / 400.0 - 1.5 }
    |> escp(i: 0, zr: 0.0, zi: 0.0, tr: 0.0, ti: 0.0): bit
    |> std/store:stored { st.ba: @rem(st.ba * 2 + bit, 256) }
    |> std/store:stored { st.bn: st.bn + 1 }
    |> flushb(x): _
    |> pixl(x: x + 1, y): r -> r
| else -> 0

// rowl — one image row: ci = 2y/h - 1
pub tor rowl { y: i64 } -> i64
rowl = if(y < 400)
| then |> std/store:stored { fs.ci: 2.0 * @as(f64, @floatFromInt(y)) / 400.0 - 1.0 }
    |> pixl(x: 0, y): _
    |> rowl(y: y + 1): r -> r
| else -> 0

// onerun — append one P4 image to the doc
pub tor onerun { } -> i64
onerun = lit(t: "P4"): _
    |> pb(b: 10): _
    |> lit(t: "400 400"): _
    |> pb(b: 10): _
    |> std/store:stored { st.ba: 0 }
    |> std/store:stored { st.bn: 0 }
    |> rowl(y: 0): _
    |> if(st.bn > 0)
        | then |> std/store:stored { st.ba: st.ba * (@as(i64, 1) << @as(u6, @intCast(8 - st.bn))) }
            |> pb(b: st.ba): _ -> 0
        | else -> 0

// runl — 120 runs (100 measured + 20 warmup)
pub tor runl { k: i64 } -> i64
runl = if(k < 120)
| then |> onerun(): _
    |> runl(k: k + 1): r -> r
| else -> 0

// djdoc — checksumBytes: DJB2 over all emitted doc bytes → st.t3
pub tor djdoc { i: i64 } -> i64
djdoc = if(i < st.p)
| then |> std/store:stored { st.t3: @rem(st.t3 * 33 + doc[i].b, 4294967296) }
    |> djdoc(i: i + 1): r -> r
| else -> 0

// ---- driver ----
runl(k: 0): _
|> std/store:stored { st.t3: 5381 }
|> djdoc(i: 0): _
|> std/io:print.ln("{{ st.t3:d }}")
