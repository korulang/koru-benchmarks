// etc_gameoflife — LangArena Etc::GameOfLife, run.js scored
// parameters (w=500, h=500, iterations=500, warmup=100 → 600 runs;
// prepare seeds once with nextFloat(1.0) < 0.1 per cell — 250000
// draws; each run = one toroidal generation; checksum = FNV-1a over
// alive bits + countAlive — oracle 3805797673).
//
// The reference precomputes an 8-pointer neighbor ring per cell;
// nb grid carries the same precomputed indices (torus wrap).
//
import std/io
import std/grid
import std/store

std/grid:new(cells, size: 250000) { a: 0[u8], nx: 0[u8] }
std/grid:new(nb, size: 250000) { n0: 0[i64], n1: 0[i64], n2: 0[i64], n3: 0[i64], n4: 0[i64], n5: 0[i64], n6: 0[i64], n7: 0[i64] }
std/store:new(st) { last: 42[i64], nc: 0[i64], hh: 0[i64], cnt: 0[i64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// nxfl — nextFloat(1.0): last/IM as f64
pub tor nxfl { } -> f64
nxfl = std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }: _ -> @as(f64, @floatFromInt(st.last)) / 139968.0

// nbl — precompute the 8 toroidal neighbor indices for cell i
// (dy,dx scan order of the reference linkNeighbors)
pub tor nbl { i: i64 } -> i64
nbl = if(i < 250000)
| then |> std/store:stored { st.nc: @divTrunc(i, 500) }
    |> std/store:stored { st.cnt: @rem(i, 500) }
    |> std/grid:stored { nb[i].n0: @rem(st.nc + 499, 500) * 500 + @rem(st.cnt + 499, 500) }
    |> std/grid:stored { nb[i].n1: @rem(st.nc + 499, 500) * 500 + st.cnt }
    |> std/grid:stored { nb[i].n2: @rem(st.nc + 499, 500) * 500 + @rem(st.cnt + 1, 500) }
    |> std/grid:stored { nb[i].n3: st.nc * 500 + @rem(st.cnt + 499, 500) }
    |> std/grid:stored { nb[i].n4: st.nc * 500 + @rem(st.cnt + 1, 500) }
    |> std/grid:stored { nb[i].n5: @rem(st.nc + 1, 500) * 500 + @rem(st.cnt + 499, 500) }
    |> std/grid:stored { nb[i].n6: @rem(st.nc + 1, 500) * 500 + st.cnt }
    |> std/grid:stored { nb[i].n7: @rem(st.nc + 1, 500) * 500 + @rem(st.cnt + 1, 500) }
    |> nbl(i: i + 1): r -> r
| else -> 0

// seedl — one nextFloat draw per cell; alive when < 0.1
pub tor seedl { i: i64 } -> i64
seedl = if(i < 250000)
| then |> nxfl(): f
    |> if(f < 0.1)
        | then |> std/grid:stored { cells[i].a: 1 }
        | else |> ret0(): _
    |> seedl(i: i + 1): r -> r
| else -> 0

// cntl — count neighbors, write cells[i].nx per the reference rule
pub tor cntl { i: i64 } -> i64
cntl = if(i < 250000)
| then |> std/store:stored { st.nc: cells[nb[i].n0].a + cells[nb[i].n1].a + cells[nb[i].n2].a + cells[nb[i].n3].a + cells[nb[i].n4].a + cells[nb[i].n5].a + cells[nb[i].n6].a + cells[nb[i].n7].a }
    |> if(cells[i].a == 1)
        | then |> if(st.nc == 2 or st.nc == 3)
            | then |> std/grid:stored { cells[i].nx: 1 }
            | else |> std/grid:stored { cells[i].nx: 0 }
        | else |> if(st.nc == 3)
            | then |> std/grid:stored { cells[i].nx: 1 }
            | else |> std/grid:stored { cells[i].nx: 0 }
    |> cntl(i: i + 1): r -> r
| else -> 0

// updl — apply next state
pub tor updl { i: i64 } -> i64
updl = if(i < 250000)
| then |> std/grid:stored { cells[i].a: cells[i].nx }
    |> updl(i: i + 1): r -> r
| else -> 0

// genl — one generation
pub tor genl { g: i64 } -> i64
genl = if(g < 600)
| then |> cntl(i: 0): _
    |> updl(i: 0): _
    |> genl(g: g + 1): r -> r
| else -> 0

// fnl — fused FNV-1a over alive bits + countAlive
pub tor fnl { i: i64 } -> i64
fnl = if(i < 250000)
| then |> std/store:stored { st.hh: @rem((st.hh ^ @as(i64, @intCast(cells[i].a))) * 16777619, 4294967296) }
    |> std/store:stored { st.cnt: st.cnt + cells[i].a }
    |> fnl(i: i + 1): r -> r
| else -> 0

// ---- driver ----
nbl(i: 0): _
|> seedl(i: 0): _
|> genl(g: 0): _
|> std/store:stored { st.hh: 2166136261 }
|> std/store:stored { st.cnt: 0 }
|> fnl(i: 0): _
|> std/io:print.ln("{{ st.hh + st.cnt:d }}")
