// etc_words — LangArena Etc::Words, run.js scored parameters
// (words=50000, word_len=4, iterations=360, warmup=72 → 432 runs;
// prepare builds one text — words of nextInt(4)+nextInt(3)+3 chars
// over a-z, space-separated — each run counts frequencies and adds
// max_count + checksumString(max_word) + distinct — oracle
// 1998586832).
//
// The reference uses a StringHashMap; ht is an open-addressed
// {epoch, off, len, count} table (262144 slots at ~7% load). Verified
// in simulation that the maximum is unique (single word at count 9),
// so the map's iteration order never selects max_word — the result
// is order-independent.
//
import std/io
import std/grid
import std/store
import std/fmt

std/grid:new(text, size: 450000) { b: 0[u8] }
std/grid:new(ht, size: 262144) { ep: 0[i64], off: 0[i64], len: 0[i64], cnt: 0[i64] }
std/store:new(st) { last: 42[i64], res: 0[i64], tlen: 0[i64], ep: 0[i64], nz: 0[i64], maxc: 0[i64], maxo: 0[i64], maxl: 0[i64], hh: 0[i64], t1: 0[i64], t2: 0[i64] }

pub tor ret0 { } -> i64
ret0 = if(0 == 0)
| then -> 0
| else -> 0

// nxt — nextInt(max): LCG draw, truncated scale
pub tor nxt { max: i64 } -> i64
nxt = std/store:stored { st.last: @rem(st.last *% 3877 +% 29573, 139968) }: _ -> @as(i64, @intFromFloat(@as(f64, @floatFromInt(st.last)) / 139968.0 * @as(f64, @floatFromInt(max))))

// filw — fill one word: j chars of 'a'+nextInt(26) at st.tlen
pub tor filw { n: i64, j: i64 } -> i64
filw = if(j < n)
| then |> nxt(max: 26): c
    |> std/grid:stored { text[st.tlen].b: @as(u8, @intCast(97 + c)) }
    |> std/store:stored { st.tlen: st.tlen + 1 }
    |> filw(n, j: j + 1): r -> r
| else -> 0

// genl — build the text: word i, space between words
pub tor genl { i: i64 } -> i64
genl = if(i < 50000)
| then |> nxt(max: 4): a
    |> nxt(max: 3): b
    |> filw(n: a + b + 3, j: 0): _
    |> if(i < 49999)
        | then |> std/grid:stored { text[st.tlen].b: 32 }
            |> std/store:stored { st.tlen: st.tlen + 1 }
        | else |> ret0(): _
    |> genl(i: i + 1): r -> r
| else -> 0

// wend — find the end of the word at st.t1 (scan to ' ' or tlen)
pub tor wend { j: i64 } -> i64
wend = if(j < st.tlen and text[j].b != 32)
| then |> wend(j: j + 1): r -> r
| else -> j

// whl — DJB2 of text[off..end) → st.t2 (masked to the table range
// at use; the map hash is my own, never checksummed)
pub tor whl { j: i64, end: i64, h: i64 } -> i64
whl = if(j < end)
| then |> whl(j: j + 1, end, h: h * 33 + @as(i64, @intCast(text[j].b))): r -> r
| else -> h

// prb — linear-probe insert-or-bump for the word at off/end;
// epoch st.ep marks entries live this run
pub tor prb { h: i64, off: i64, len: i64 } -> i64
prb = if(ht[h].ep == st.ep and ht[h].len == len)
| then |> wcmp(h, off, j: 0, len): r -> r
| else |> if(ht[h].ep != st.ep)
    | then |> std/grid:stored { ht[h].ep: st.ep }
        |> std/grid:stored { ht[h].off: off }
        |> std/grid:stored { ht[h].len: len }
        |> std/grid:stored { ht[h].cnt: 1 }
        |> std/store:stored { st.nz: st.nz + 1 }: _ -> 1
    | else |> prb(h: @rem(h + 1, 262144), off, len): r -> r

// wcmp — compare slot word with candidate, byte for byte;
// equal → bump count (produce 1), differ → probe next slot
pub tor wcmp { h: i64, off: i64, j: i64, len: i64 } -> i64
wcmp = if(j < len)
| then |> if(text[ht[h].off + j].b == text[off + j].b)
        | then |> wcmp(h, off, j: j + 1, len): r -> r
        | else |> prb(h: @rem(h + 1, 262144), off, len): r -> r
| else |> std/grid:stored { ht[h].cnt: ht[h].cnt + 1 }: _ -> 1

// wscan — split text on ' ', count each word
pub tor wscan { pos: i64 } -> i64
wscan = if(pos < st.tlen)
| then |> wend(j: pos): e
    |> if(e > pos)
        | then |> whl(j: pos, end: e, h: 5381): h
            |> prb(h: @rem(h, 262144), off: pos, len: e - pos): _
        | else |> ret0(): _
    |> wscan(pos: e + 1): r -> r
| else -> 0

// maxl — iterate the table: strict > keeps the first-seen maximum
// (unique in this corpus — verified in sim)
pub tor maxl { i: i64 } -> i64
maxl = if(i < 262144)
| then |> if(ht[i].ep == st.ep and ht[i].cnt > st.maxc)
        | then |> std/store:stored { st.maxc: ht[i].cnt }
            |> std/store:stored { st.maxo: ht[i].off }
            |> std/store:stored { st.maxl: ht[i].len }
        | else |> ret0(): _
    |> maxl(i: i + 1): r -> r
| else -> 0

// djb — checksumString of the max word → st.hh
pub tor djb { j: i64, h: i64 } -> i64
djb = if(j < st.maxl)
| then |> djb(j: j + 1, h: @rem(h * 33 + @as(i64, @intCast(text[st.maxo + j].b)), 4294967296)): r -> r
| else -> h

// onerun — one runImpl: fresh epoch, count, find max, accumulate
pub tor onerun { } -> i64
onerun = std/store:stored { st.ep: st.ep + 1 }
    |> std/store:stored { st.nz: 0 }
    |> wscan(pos: 0): _
    |> std/store:stored { st.maxc: 0 }
    |> maxl(i: 0): _
    |> djb(j: 0, h: 5381): hh
    |> std/store:stored { st.hh: hh }
    |> std/store:stored { st.res: @rem(st.res + st.maxc + st.hh + st.nz, 4294967296) }: _ -> 0

// runl — 432 runs (360 measured + 72 warmup)
pub tor runl { k: i64 } -> i64
runl = if(k < 432)
| then |> onerun(): _
    |> runl(k: k + 1): r -> r
| else -> 0

// ---- driver ----
genl(i: 0): _
|> runl(k: 0): _
|> std/io:print.ln("{{ st.res:d }}")
