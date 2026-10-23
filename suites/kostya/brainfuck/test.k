// test.k — Kostya benchmarks brainfuck task, Koru entry.
//
// Same program shape as bf.zig / bf.rs:
//   verify:  the reference's literal hello-world program runs through the
//            real parse+interp path in quiet mode; its Fletcher-16 must
//            equal the checksum of printing "Hello World!\n" (42059).
//            A mismatch prints VERIFY_FAIL and never announces on :9001.
//   quiet:   QUIET env set -> '.' accumulates Fletcher-16 (sum1 += n,
//            sum2 += sum1, mod 255) and prints "Output checksum: N"
//            after the run; unset -> '.' writes the byte to stdout.
//   timed:   send-pid, then the program file (argv[1]) is read once,
//            folded, and interpreted ONCE before send("stop"). The
//            reference announces after its file read and brackets
//            parse+interp only; ours additionally includes the file
//            read — strictly more work inside the window, not less.
//
// Faithfulness differences, stated:
// - Tape is a fixed i32 grid (65536 cells) vs the reference's growable
//   ArrayList. i32 element type is required: bench.b's nested multiply
//   loops drive cells well past 255 transiently — a u8 tape would wrap
//   and diverge. pos is usize; '<' is unchecked like the reference's
//   `pos -= 1` (a program walking below 0 is UB/panic in both).
// - Ops are a flat stream with precomputed jump targets, not the
//   reference's recursive Op tree + `_run` recursion — identical
//   observable semantics at one dispatch per bracket instead of two.
// - Parse-time run folding (the LangArena kernel's disclosed shape):
//   '+'/'-' runs fold to one INC op with the SIGNED i32 net delta —
//   exact always, since i32 cells don't wrap at 256. '>'/'<' runs fold
//   to one MOVE op with signed net delta — and on THIS tape the fold is
//   exact for MIXED directions too, because there is no clamp for a
//   `<` run to hit (the LangArena kernel needed homogeneous runs
//   precisely because its pos-0 clamp made mixed nets inexact; verified
//   there by counterexample, absent here by construction).
// - ',' is not an opcode in the reference parser (falls to `else =>
//   continue`); it flushes a pending run here and becomes a dead op —
//   same observable behavior (bench.b contains none).
// - Loop condition is `cell > 0` on the i32 cell (reference checks
//   `tape.get() > 0`, not !=0 — a negative cell exits the loop in both).
// - Fixed op/stack grids (65536 entries) sized far past bench.b's 220
//   chars (and mandel.b-class programs); disclosed bound, not adaptive.
// - File read goes through std/fs:read-lines (the read-file surface
//   returns an <allocated!>-qualified string the `for` transform cannot
//   iterate); the dropped '\n' bytes are non-command bytes — the
//   reference's parser skips them identically, so the op stream is
//   unchanged.
//
// Liveness: the interpreter's dispatches write tape cells and read the
// op stream; the checksum consumes every printed byte's value. The one
// measured run's work is fully checksum-pinned — no probe needed.

import std/io
import std/args
import std/env
import std/fs
import std/grid
import std/store
import std/switch

std/compiler:paths { notify: ./notify.kz }

import notify

const {
    VERI: "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++."
}

std/grid:new(tape, size: 65536) { c: 0[i32] }
std/grid:new(ops, size: 65536) { o: 0[u8], j: 0[i32], v: 0[i32] }
std/grid:new(stk, size: 4096) { v: 0[i32] }
std/store:new(st) { nop: 0[i64], sp: 0[i64], ro: 0[i64], rn: 0[i64], s1: 0[i64], s2: 0[i64], quiet: 0[i64] }

std/grid:slice(tape_s) { tape.c }
std/grid:slice(so) { ops.o }
std/grid:slice(sj) { ops.j }
std/grid:slice(sv) { ops.v }

pub tor ret0 {} -> i64
ret0 -> 0

pub tor idv { v: i64 } -> i64
idv -> v

// interp — tail-recursive dispatch (self_loop lowered; ip/pos register-
// resident). switch:char dispatch, borrowed-slice access.
//   '+' arm: cell += signed i32 delta (folded +- run).
//   '>' arm: pos += signed delta (folded <> run — mixed allowed, no clamp).
pub tor interp { ip: usize, pos: usize } -> i64
interp = if(ip < st.nop)
| then |> std/switch:char(so[ip])
    | `+` _ |> std/grid:stored { tape_s[pos]: tape_s[pos] + sv[ip] }
        |> interp(ip: ip + 1, pos): r -> r
    | `>` _ |> idv(v: @as(i64, @intCast(pos)) + @as(i64, sv[ip])): np
        |> interp(ip: ip + 1, pos: @as(usize, @intCast(np))): r -> r
    | `[` _ |> if(tape_s[pos] <= 0)
        | then |> interp(ip: @as(usize, @intCast(sj[ip])), pos): r -> r
        | else |> interp(ip: ip + 1, pos): r -> r
    | `]` _ |> if(tape_s[pos] > 0)
        | then |> interp(ip: @as(usize, @intCast(sj[ip])), pos): r -> r
        | else |> interp(ip: ip + 1, pos): r -> r
    | `.` _ |> if(st.quiet != 0)
        | then |> idv(v: @rem(st.s1 + @as(i64, tape_s[pos]), 255)): ns1
            |> std/store:stored { st.s1: ns1, st.s2: @rem(st.s2 + ns1, 255) }
            |> interp(ip: ip + 1, pos): r -> r
        | else |> notify:putb(b: @as(i64, tape_s[pos])): _
            |> interp(ip: ip + 1, pos): r -> r
    | no-match |> interp(ip: ip + 1, pos): r -> r
| else -> 0

// flush — emit the pending folded run as one op. st.ro: 0 none, 43 inc
// run, 62 move run; v carries the signed net delta either way.
pub tor flush {} -> i64
flush = if(st.ro != 0)
| then |> std/grid:stored { ops[st.nop].o: if(st.ro == 43) @as(u8, 43) else @as(u8, 62), ops[st.nop].j: 0, ops[st.nop].v: @as(i32, @intCast(st.rn)) }
    |> std/store:stored { st.nop: st.nop + 1, st.ro: 0, st.rn: 0 }
    |> ret0(): _ -> 0
| else -> 0

// emit — fold +- runs (43) and mixed <> runs (62). '.', ',', '[' and ']'
// flush first. ']' pops the matching '[' and links both endpoints on the
// folded stream ('[' j -> past ']', ']' j -> past '['). Any other byte
// (comments, ',') becomes a dead op the no-match arm skips.
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
                |> std/grid:stored { ops[open].j: @as(i32, @intCast(st.nop + 1)), ops[st.nop].o: @as(u8, @intCast(c)), ops[st.nop].j: @as(i32, @intCast(open + 1)), ops[st.nop].v: 0 }
                |> std/store:stored { st.nop: st.nop + 1 }
                |> ret0(): _ -> 0
            | else |> std/grid:stored { ops[st.nop].o: @as(u8, @intCast(c)), ops[st.nop].j: 0, ops[st.nop].v: 0 }
                |> if(c == 91)
                    | then |> std/grid:stored { stk[st.sp].v: @as(i32, @intCast(st.nop)) }
                        |> std/store:stored { st.sp: st.sp + 1 }
                |> std/store:stored { st.nop: st.nop + 1 }
                |> ret0(): _ -> 0

// tape-zero — the verify run and the measured run share the grid;
// the reference uses a fresh Tape per run, we re-zero.
pub tor tape-zero { i: i64 } -> i64
tape-zero = if(i < 65536)
| then |> std/grid:stored { tape_s[@as(usize, @intCast(i))]: 0 }
    |> tape-zero(i: i + 1): r -> r
| else -> i

// ---- verify: hello-world through the real path, quiet checksum ----
for(VERI)
! each ch |> emit(c: ch): _
| done |> flush(): _
    |> std/store:stored { st.quiet: 1 }
    |> interp(ip: 0, pos: 0): _
|> idv(v: st.s1 + st.s2 * 256): chk
|> if(chk != 42059)
    | then |> std/io:print.ln("VERIFY_FAIL")
    | else |> std/store:stored { st.s1: 0, st.s2: 0, st.nop: 0, st.sp: 0, st.ro: 0, st.rn: 0 }
        |> tape-zero(i: 0): _
        |> std/env:is-set(name: "QUIET")
            | yes |> std/store:stored { st.quiet: 1 }
            | no |> std/store:stored { st.quiet: 0 }
        |> std/args:get(index: 1)
            | arg p |> notify:send-pid(name: "Koru", port: 9001): _
                |> std/fs:read-lines(path: p)
                    ! line l |> for(l)
                        ! each ch |> emit(c: ch): _
                    | done _ |> flush(): _
                        |> interp(ip: 0, pos: 0): _
                        |> notify:send(msg: "stop", port: 9001): _
                    |> idv(v: st.s1 + st.s2 * 256): chk2
                    |> if(st.quiet != 0)
                        | then |> std/io:print.ln("Output checksum: {{ chk2:d }}")
                | failed e |> std/io:print.ln("read failed {{ e:s }}")
            | out-of-bounds |> std/io:print.ln("Expected argument")
