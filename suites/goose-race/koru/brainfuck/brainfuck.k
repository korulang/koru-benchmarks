// brainfuck — Goose kostya2 brainfuck port (bf.goose / kostya bf.c).
//
// Workload: read a .b program, parse to ops, interpret on an i32 tape
// (cells `while cell > 0`), quiet checksum printer:
//   s1 = (s1 + cell) % 255; s2 = (s2 + s1) % 255; checksum = s2<<8 | s1
// Output: "Output checksum: N"  (QUIET semantics, as the raced runs use)
// verify(): the hello-world self-check both references run first.
//
// Substrate, stated:
// - Goose stores a Loop{body: Op[:]} tree; Koru has no slice-typed op
//   field, so the program lowers to a flat ops grid with a bracket-jump
//   table: '[' j = index past ']', ']' j = index past '['. Identical
//   execution semantics — a '[' skips when cell<=0, a ']' re-enters
//   while cell>0.
// - Parse folds runs: consecutive +/- emit one op (o='+', v=net delta);
//   consecutive </> emit one op (o='>', v=net move). This is a peephole
//   the references don't do — the folded stream dispatches ~4x fewer ops
//   for the same output. Brackets flush pending runs so jump targets
//   stay exact.
// - The dispatch loop is a tail-recursive tor (self_loop lowered); ip/pos
//   ride as parameters so they stay register-resident. std/switch:char
//   dispatches on the op byte (emits a native Zig switch); borrowed
//   slices so/sv/sj/tv index raw — no per-access floor.
// - ops.o:u8 + ops.j:0[ops] (certified u19: checked once at the write,
//   raw at every read) + ops.v:i32 keep the op table at ~8B/entry.
// - tape is a 1M-cell i32 grid — BSS pages materialize only where programs
//   write, same as the reference's doubling calloc. Between runs the tape
//   re-zeroes only what the previous run touched: st.hwm tracks the
//   rightmost cell reached, and the clear walks 0..hwm instead of 1M.

import std/io
import std/grid
import std/store
import std/switch
import std/time

const {
    HELLO: "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++."
    RIGHT: "Hello World!\n"
}

std/grid:new(tape, size: 1048576) { v: 0[i32] }
std/grid:new(src, size: 262144) { c: 0[u8] }
std/grid:new(ops, size: 262144) { o: 0[u8], j: 0[ops], v: 0[i32] }
std/grid:new(stk, size: 4096) { v: 0[ops] }
std/store:new(st) { pos: 0[i64], nop: 0[i64], sp: 0[i64], ip: 0[i64], s1: 0[i64], s2: 0[i64], si: 0[i64], hwm: 0[i64], ro: 0[i64], rn: 0[i64] }

std/grid:slice(so) { ops.o }
std/grid:slice(sj) { ops.j }
std/grid:slice(sv) { ops.v }
std/grid:slice(tv) { tape.v }

pub tor ret0 {} -> i64
ret0 -> 0

pub tor idv { v: i64 } -> i64
idv -> v

// step — one op at ip, tail-lowered dispatch loop. ip/pos ride as
// parameters so they stay register-resident; switch:char dispatches on
// the op byte; `+-` folds to one arm reading the net delta from sv,
// `<>` likewise for moves; jump targets read the certified j slice raw.
pub tor step { ip: usize, pos: usize } -> i64
step = if(ip < st.nop)
| then |> std/switch:char(so[ip])
    | `+-` _ |> std/grid:stored { tv[pos]: tv[pos] +% sv[ip] }
        |> step(ip: ip + 1, pos): r -> r
    | `<>` _ |> idv(v: @as(i64, @intCast(pos)) + @as(i64, sv[ip])): np
        |> if(np > st.hwm)
            | then |> std/store:stored { st.hwm: np }
                |> step(ip: ip + 1, pos: @as(usize, @intCast(np))): r -> r
            | else |> step(ip: ip + 1, pos: @as(usize, @intCast(np))): r -> r
    | `.` _ |> std/store:stored { st.s1: @rem(st.s1 + @as(i64, tv[pos]), 255) }
        |> std/store:stored { st.s2: @rem(st.s2 + st.s1, 255) }
        |> step(ip: ip + 1, pos): r -> r
    | `[` _ |> if(tv[pos] <= 0)
        | then |> step(ip: sj[ip], pos): r -> r
        | else |> step(ip: ip + 1, pos): r -> r
    | `]` _ |> if(tv[pos] > 0)
        | then |> step(ip: sj[ip], pos): r -> r
        | else |> step(ip: ip + 1, pos): r -> r
    | no-match |> ret0(): _ -> 0
| else -> 0

// flush — emit the pending folded run (if any) as one op.
pub tor flush {} -> i64
flush = if(st.ro != 0)
| then |> std/grid:stored { ops[st.nop].o: @as(u8, @intCast(st.ro)), ops[st.nop].j: 0, ops[st.nop].v: @as(i32, @intCast(st.rn)) }
    |> std/store:stored { st.nop: st.nop + 1, st.ro: 0, st.rn: 0 }
    |> ret0(): _ -> 0
| else -> 0

// emit — fold +/- and </> runs; '.', '[' and ']' flush then emit.
// st.ro holds the pending run's op byte (43=inc, 62=move, 0=none).
pub tor emit { c: i64 } -> i64
emit = if(c == 43 or c == 45)
| then |> if(st.ro != 0 and st.ro != 43)
    | then |> flush(): _
        |> std/store:stored { st.ro: 43, st.rn: 44 - c }
        |> ret0(): _ -> 0
    | else |> std/store:stored { st.ro: 43, st.rn: st.rn + 44 - c }
        |> ret0(): _ -> 0
| else |> if(c == 62 or c == 60)
    | then |> if(st.ro != 0 and st.ro != 62)
        | then |> flush(): _
            |> std/store:stored { st.ro: 62, st.rn: c - 61 }
            |> ret0(): _ -> 0
        | else |> std/store:stored { st.ro: 62, st.rn: st.rn + c - 61 }
            |> ret0(): _ -> 0
    | else |> flush(): _
        |> if(c == 93)
            | then |> std/store:stored { st.sp: st.sp - 1 }
                |> idv(v: @as(i64, stk[st.sp].v)): open
                |> std/grid:stored { ops[open].j: st.nop + 1, ops[st.nop].o: @as(u8, @intCast(c)), ops[st.nop].j: open + 1, ops[st.nop].v: 0 }
                |> std/store:stored { st.nop: st.nop + 1 }
                |> ret0(): _ -> 0
            | else |> std/grid:stored { ops[st.nop].o: @as(u8, @intCast(c)), ops[st.nop].j: 0, ops[st.nop].v: 0 }
                |> if(c == 91)
                    | then |> std/grid:stored { stk[st.sp].v: st.nop }
                        |> std/store:stored { st.sp: st.sp + 1 }
                |> std/store:stored { st.nop: st.nop + 1 }
                |> ret0(): _ -> 0

// parse — scan src[0..len); command bytes feed the folding emitter.
pub tor parse { len: usize } -> i64
parse = for(0..len)
    ! each i |> idv(v: @as(i64, src[i].c)): c
        |> if(c == 43 or c == 45 or c == 60 or c == 62 or c == 46 or c == 91 or c == 93)
            | then |> emit(c): _
    | done |> flush(): _
        |> ret0(): _ -> 0

// runsrc — src[0..len) already holds the program; parse + reset + interpret,
// producing the quiet checksum (s2<<8 | s1).
pub tor runsrc { len: usize } -> i64
runsrc = std/grid:for(0..(st.hwm + 1), tape)
    ! each i |> std/grid:stored { tape[i].v: 0 }
    | done |> std/store:stored { st.nop: 0, st.sp: 0, st.hwm: 0, st.ro: 0, st.rn: 0 }
        |> parse(len): _
        |> std/store:stored { st.s1: 0, st.s2: 0 }
        |> step(ip: 0, pos: 0): _
        |> idv(v: st.s2 * 256 + st.s1): r -> r

// feed — push one byte through the quiet checksum printer.
pub tor feed { c: i64 } -> i64
feed = std/store:stored { st.s1: @rem(st.s1 + c, 255), st.s2: @rem(st.s2 + st.s1, 255) }
    |> ret0(): _ -> 0

// ---- driver ----
for(HELLO)
! each ch |> std/grid:stored { src[st.si].c: @as(u8, @intCast(ch)) }
    |> std/store:stored { st.si: st.si + 1 }
| done |> idv(v: st.si): hlen
    |> runsrc(len: @as(usize, @intCast(hlen))): left
    |> std/store:stored { st.s1: 0 }
    |> std/store:stored { st.s2: 0 }
    |> for(RIGHT)
        ! each ch |> feed(c: @as(i64, ch)): _
    | done |> idv(v: st.s2 * 256 + st.s1): right
        |> if(left != right)
            | then |> std/io:print.ln("VERIFYFAIL {{ left:d }} {{ right:d }}")

// Measured run.
std/store:stored { st.si: 0 }
std/io:args(): a
|> std/io:read-file(path: a[1])
| not-found |> std/io:print.ln("file missing")
| failed e |> std/io:print.ln("read failed")
| ok content |> for(0..content.len)
    ! each i |> std/grid:stored { src[i].c: content[i] }
    | done |> runsrc(content.len): ck
        |> std/io:free(content)
        |> std/io:print.ln("Output checksum: {{ ck:d }}")
