// etc_cache_simulation — LangArena Etc::CacheSimulation, run.js
// scored parameters (values=5000, size=2500, iterations=5000,
// warmup=1000 → 6000 runs x 1000 ops; checksum =
// (((5432<<5)+hits)<<5+misses)<<5+size — oracle 3263751556).
//
// Load-bearing harness semantics: benchmark.zig calls
// helper.reset() between warmup() and run_all() — runImpl draws
// one nextInt(5000) per op, so the measured phase replays the LCG
// from 42. Earlier kernels never noticed because their draws all
// happen in prepare. Sim-verified: the replay changes hits/misses
// (2917090/3082910 vs 2917099/3082901 without it).
//
// The LRU is keyed on "item_{key_num}" — the string is formatting
// only, so pos[] indexes nodes by key_num directly; node[] carries
// the doubly-linked ring with -1 sentinels and slot recycling on
// eviction.
//
import std/io
import std/grid
import std/store
import std/fmt

std/grid:new(pos, size: 5000) { v: -1[i64] }
std/grid:new(node, size: 2500) { key: 0[i64], prv: -1[i64], nxt: -1[i64] }
std/store:new(st) { last: 42[i64], res: 5432[i64], hits: 0[i64], miss: 0[i64], head: -1[i64], tail: -1[i64], size: 0[i64], fr: -1[i64], nn: 0[i64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// nxt — nextInt(max): LCG draw, truncated scale
pub tor nxt { max: i64 } -> i64
nxt = std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }: _ -> @as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * @as(f64, @floatFromInt(max))))

// posl — init pos[] to -1 (empty map)
pub tor posl { i: i64 } -> i64
posl = if(i < 5000)
| then |> std/grid:stored { pos[i].v: -1 }
    |> posl(i: i + 1): r -> r
| else -> 0

// mtof — moveToFront: unlink d from its position, push at head
pub tor mtof { d: i64 } -> i64
mtof = if(d == st.head)
| then -> 0
| else |> if(node[d].prv >= 0)
        | then |> std/grid:stored { node[node[d].prv].nxt: node[d].nxt }
        | else |> ret0(): _
    |> if(node[d].nxt >= 0)
        | then |> std/grid:stored { node[node[d].nxt].prv: node[d].prv }
        | else |> ret0(): _
    |> if(d == st.tail)
        | then |> std/store:stored { st.tail: node[d].prv }
        | else |> ret0(): _
    |> std/grid:stored { node[d].prv: -1 }
    |> std/grid:stored { node[d].nxt: st.head }
    |> if(st.head >= 0)
        | then |> std/grid:stored { node[st.head].prv: d }
        | else |> ret0(): _
    |> std/store:stored { st.head: d }
    |> if(st.tail < 0)
        | then |> std/store:stored { st.tail: d }
        | else |> ret0(): _
    |> ret0(): _ -> 0

// evict — removeOldest: snapshot the tail slot into st.fr first,
// drop it from the map, unlink, decrement size
pub tor evict { } -> i64
evict = std/store:stored { st.fr: st.tail }
    |> std/grid:stored { pos[node[st.tail].key].v: -1 }
    |> if(node[st.tail].prv >= 0)
        | then |> std/grid:stored { node[node[st.tail].prv].nxt: -1 }
            |> std/store:stored { st.tail: node[st.tail].prv }
            |> std/store:stored { st.size: st.size - 1 }: _ -> 0
        | else |> std/store:stored { st.head: -1 }
            |> std/store:stored { st.tail: -1 }
            |> std/store:stored { st.size: st.size - 1 }: _ -> 0

// ins — insert key k into a free/recycled slot at front
pub tor ins { k: i64 } -> i64
ins = if(st.fr >= 0)
| then |> std/store:stored { st.nn: st.fr }
    |> std/store:stored { st.fr: -1 }
    |> insb(k): r -> r
| else |> std/store:stored { st.nn: st.size }
    |> insb(k): r -> r

// insb — write the chosen slot into node[] and push it at head
// (addToFront); called from both ins arms. Each if is terminal in
// its chain — a bare body chain cannot continue after armed steps.
pub tor insb { k: i64 } -> i64
insb = std/grid:stored { node[st.nn].key: k }
    |> std/grid:stored { node[st.nn].prv: -1 }
    |> std/grid:stored { node[st.nn].nxt: st.head }
    |> if(st.head >= 0)
        | then |> std/grid:stored { node[st.head].prv: st.nn }
            |> insb2(k): r -> r
        | else |> insb2(k): r -> r

pub tor insb2 { k: i64 } -> i64
insb2 = std/store:stored { st.head: st.nn }
    |> if(st.tail < 0)
        | then |> std/store:stored { st.tail: st.nn }
            |> insb3(k): r -> r
        | else |> insb3(k): r -> r

pub tor insb3 { k: i64 } -> i64
insb3 = std/store:stored { st.size: st.size + 1 }
    |> std/grid:stored { pos[k].v: st.nn }
    |> ret0(): _ -> 0

// op — one op: draw key, hit → moveToFront + put-update (same node,
// value not checksummed); miss → evict-if-full + insert
pub tor op { } -> i64
op = nxt(max: 5000): k
    |> if(pos[k].v >= 0)
        | then |> std/store:stored { st.hits: st.hits + 1 }
            |> mtof(d: pos[k].v): _ -> 0
        | else |> std/store:stored { st.miss: st.miss + 1 }
            |> if(st.size >= 2500)
                | then |> evict(): _
                | else |> ret0(): _
            |> ins(k): _ -> 0

// opl — one runImpl: 1000 ops
pub tor opl { n: i64 } -> i64
opl = if(n < 1000)
| then |> op(): _
    |> opl(n: n + 1): r -> r
| else -> 0

// phl — warmup runs 0..999, then helper.reset() (last=42) replay,
// then 5000 measured runs — matching benchmark.zig exactly
pub tor phl { k: i64 } -> i64
phl = if(k < 6000)
| then |> opl(n: 0): _
    |> if(k == 999)
        | then |> std/store:stored { st.last: 42 }
        | else |> ret0(): _
    |> phl(k: k + 1): r -> r
| else -> 0

// ---- driver ----
posl(i: 0): _
|> phl(k: 0): _
|> std/store:stored { st.res: @rem(@rem(@rem(st.res * 32 + st.hits, 4294967296) * 32 + st.miss, 4294967296) * 32 + st.size, 4294967296) }
|> std/io:print.ln("{{ st.res:d }}")
