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
// - The dispatch loop is a tail-recursive tor (self_loop lowered), same
//   as the LangArena bf kernels.
// - tape is a 1M-cell i32 grid — BSS pages materialize only where programs
//   write, same as the reference's doubling calloc. Between runs the tape
//   re-zeroes only what the previous run touched: st.hwm tracks the
//   rightmost cell reached, and the clear walks 0..hwm instead of 1M.

import std/io
import std/grid
import std/store
import std/time

const {
    HELLO: "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++."
    RIGHT: "Hello World!\n"
}

std/grid:new(tape, size: 1048576) { v: 0[i32] }
std/grid:new(src, size: 262144) { c: 0[u8] }
std/grid:new(ops, size: 262144) { o: 0[i64], j: 0[i64] }
std/grid:new(stk, size: 4096) { v: 0[i64] }
std/store:new(st) { pos: 0[i64], nop: 0[i64], sp: 0[i64], ip: 0[i64], s1: 0[i64], s2: 0[i64], si: 0[i64], hwm: 0[i64] }

pub tor ret0 {} -> i64
ret0 -> 0

pub tor idv { v: i64 } -> i64
idv -> v

// nip — advance ip and tail-recurse (keeps step at fixed arity)
pub tor nip {} -> i64
nip = std/store:stored { st.ip: st.ip + 1 }
    |> step(): r -> r

// step — one op at st.ip, tail-lowered dispatch loop.
// '+'/'-' fold into one arm (43/45 -> +1/-1 via 44-o); '<'/'>' likewise.
pub tor step {} -> i64
step = if(st.ip < st.nop)
| then |> idv(v: ops[st.ip].o): o
    |> if(o == 43 or o == 45)
    | then |> std/grid:stored { tape[st.pos].v: tape[st.pos].v +% @as(i32, @intCast(44 - o)) }
        |> nip(): r -> r
    | else |> if(o == 62 or o == 60)
        | then |> std/store:stored { st.pos: st.pos + o - 61 }
            |> if(st.pos > st.hwm)
                | then |> std/store:stored { st.hwm: st.pos }
                    |> nip(): r -> r
                | else |> nip(): r -> r
        | else |> if(o == 46)
            | then |> std/store:stored { st.s1: @rem(st.s1 + @as(i64, tape[st.pos].v), 255) }
                |> std/store:stored { st.s2: @rem(st.s2 + st.s1, 255) }
                |> nip(): r -> r
            | else |> if(o == 91)
                | then |> if(tape[st.pos].v <= 0)
                    | then |> std/store:stored { st.ip: ops[st.ip].j }
                        |> step(): r -> r
                    | else |> nip(): r -> r
                | else |> if(tape[st.pos].v > 0)
                    | then |> std/store:stored { st.ip: ops[st.ip].j }
                        |> step(): r -> r
                    | else |> nip(): r -> r
| else -> 0

// emit — append op byte at st.nop; '[' pushes, ']' links both ends.
pub tor emit { o: i64 } -> i64
emit = if(o == 93)
| then |> std/store:stored { st.sp: st.sp - 1 }
    |> idv(v: stk[st.sp].v): open
    |> std/grid:stored { ops[open].j: st.nop + 1, ops[st.nop].o: o, ops[st.nop].j: open + 1 }
    |> std/store:stored { st.nop: st.nop + 1 }
    |> ret0(): _ -> 0
| else |> std/grid:stored { ops[st.nop].o: o, ops[st.nop].j: 0 }
    |> if(o == 91)
        | then |> std/grid:stored { stk[st.sp].v: st.nop }
            |> std/store:stored { st.sp: st.sp + 1 }
    |> std/store:stored { st.nop: st.nop + 1 }
    |> ret0(): _ -> 0

// parse — scan src[0..len); only command bytes emit ops.
pub tor parse { len: usize } -> i64
parse = for(0..len)
    ! each i |> idv(v: @as(i64, src[i].c)): c
        |> if(c == 43 or c == 45 or c == 60 or c == 62 or c == 46 or c == 91 or c == 93)
            | then |> emit(o: c): _
    | done |> ret0(): _ -> 0

// runsrc — src[0..len) already holds the program; parse + reset + interpret,
// producing the quiet checksum (s2<<8 | s1).
pub tor runsrc { len: usize } -> i64
runsrc = std/grid:for(0..(st.hwm + 1), tape)
    ! each i |> std/grid:stored { tape[i].v: 0 }
    | done |> std/store:stored { st.nop: 0, st.sp: 0, st.hwm: 0 }
        |> parse(len): _
        |> std/store:stored { st.pos: 0, st.ip: 0, st.s1: 0, st.s2: 0 }
        |> step(): _
        |> idv(v: st.s2 * 256 + st.s1): r -> r

// feed — push one byte through the quiet checksum printer.
// store write blocks sequence: s2's entry reads the just-written s1 —
// that's the order the reference's two assignments have too.
pub tor feed { c: i64 } -> i64
feed = std/store:stored { st.s1: @rem(st.s1 + c, 255), st.s2: @rem(st.s2 + st.s1, 255) }
    |> ret0(): _ -> 0

// ---- driver ----
// verify(): run HELLO through the interpreter, checksum it; feed the
// literal "Hello World!\n" through the same printer; they must agree —
// the same self-check bf.goose and bf.c run before the timed region.
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

// Measured run: read the .b file named in argv[1], interpret it, print
// the quiet checksum — same output line as the references under QUIET=1.
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
