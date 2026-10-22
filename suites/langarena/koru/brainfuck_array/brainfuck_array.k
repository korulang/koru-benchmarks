// brainfuck_array — LangArena Brainfuck::Array, run.js scored parameters
// (program = mandelbrot-generator bf, warmup_program = hello-world bf run
// 1000x, iterations=1 -> oracle 954437102).
//
// Faithful port of reference/zig/brainfuck_array.zig Brainfuck::Array:
//   parse:  keep ascii chars in "[]<>+-,." (all chars qualify here)
//   jumps:  '[' pushes, ']' pops and links both endpoints
//   run:    tape u8[30000], pos clamps at 0 on '<'; '.' folds
//           result = result << 2 +% cell (u32 wrap)
//   warmup runs the hello-world program 1000x; its result is DISCARDED
//   (reference warmup never touches @result_val) - only the single
//   measured run accumulates.
//
// DISCLOSED parse-time representation trick (explicitly permitted route,
// goose-race kernel's proven shape — PERF.md recipe 7):
//   The folded ops stream replaces the reference's per-char command array.
//   - '+'/'-' runs fold to ONE op (o='+', v=net delta normalized mod 256);
//     exact always: u8 wrapping adds commute, cell+%(sum mod 256) ==
//     repeated +/-. Delta is normalized at flush so the apply arm is one +%.
//   - '>'/'<' runs fold to ONE op (o='>', v=signed delta) but ONLY while
//     the run is homogeneous in direction. The '<' clamp at pos 0 makes
//     net-delta folding of mixed-direction runs inexact in general:
//     at pos 0, `><<<>>` yields 2 unfolded (1,0,0,0,1,2) vs 1 folded
//     (0+1). Homogeneous runs are exact: pure '>' is pos+k; pure '<' is
//     max(max(p-1,0)-1,0)... == max(p-k,0), so the apply arm is a single
//     max(pos+d,0). Verified by scan: WARM's 12 move-runs and PROG's 27
//     are all same-direction except ONE `<<>` in PROG, which splits to
//     `<<`+`>` (one extra op) — the exact choice vs the goose-race
//     kernel's inexact-under-clamp mixed fold. Folded op counts:
//     PROG 185 chars -> 84 ops, WARM 111 chars -> 43 ops.
//   - '[', ']', '.', ',', and any non-command byte flush the pending run.
//     ']' pops the bracket stack — underflow never triggers for these
//     programs (verified balanced: PROG 13/13, WARM 1/1), same exposure
//     as the baseline.
//   - Jump targets rebuild on the folded stream with past-bracket
//     convention: '[' j -> index past ']', ']' j -> index past '['. The
//     reference links bracket positions to each other and pays an extra
//     dispatch bouncing '[' -> ']' -> body; the observable semantics are
//     identical ('[' with cell==0 skips the body, ']' with cell!=0
//     re-enters it) at one dispatch per bracket instead of two.
//   Output is checksum-identical (oracle 954437102 verified).
//
// Faithfulness differences, stated:
// - Fixed grids (ops/stk 512, tape 30000) vs reference growable arrays;
//   capacity sized for these programs (folded ops <= 185/111 chars).
// - The dispatch while-loop is a tail-recursive tor (self_loop lowered);
//   ip/pos ride as parameters so they stay register-resident.
// - Tape zeroing between runs replaces fresh allocation; warmup runs
//   reuse whatever tape state remains (their results are discarded).
// - res/acc i64 with explicit mod-2^32 folds (u32 wrap).
// - ',' opcode -> a no-match op that advances (reference: same no-op).
//
// Falsified / rejected approaches:
// - Mixed-direction <> net-delta fold (the goose-race spelling): REJECTED
//   on correctness, not speed — counterexample `><<<>>` at pos 0 above.
//   Homogeneous-only fold is the exact version for this tape's clamp.
// - [layout(row)] on ops: 0.76s — identical to column layout (the folded
//   table is ~84 entries, L1-resident either way). Reverted.
// - Per-char dispatch (the original baseline shape): 1.37s vs the folded
//   stream's 0.76s; kept in git history, superseded.

import std/io
import std/grid
import std/store
import std/switch

const {
    PROG: ">++[<+++++++++++++>-]<[[>+>+<<-]>[<+>-]++++++++[>++++++++<-]>.[-]<<>++++++++++[>++++++++++[>++++++++++[>++++++++++[>++++++++++[>++++++++++[>++++++++++[-]<-]<-]<-]<-]<-]<-]<-]++++++++++."
    WARM: "++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>."
}

std/grid:new(tape, size: 30000) { c: 0[u8] }
std/grid:new(ops, size: 512) { o: 0[u8], j: 0[ops], v: 0[i32] }
std/grid:new(stk, size: 512) { v: 0[ops] }
std/store:new(st) { nop: 0[i64], sp: 0[i64], res: 0[i64], ro: 0[i64], rn: 0[i64] }

std/grid:slice(tape_s) { tape.c }
std/grid:slice(so) { ops.o }
std/grid:slice(sj) { ops.j }
std/grid:slice(sv) { ops.v }

pub tor ret0 {} -> i64
ret0 -> 0

pub tor idv { v: i64 } -> i64
idv -> v

// interp — the dispatch loop as a tail-recursive tor (self_loop lowered).
// ip/pos ride as parameters (register-resident); switch:char emits a
// native Zig switch; tape/ops are borrowed slices so access is verbatim.
//   '+' arm: cell +% normalized delta (folded +- run).
//   '>' arm: pos = max(pos + signed delta, 0) (folded homogeneous <> run;
//           the max is the '<' clamp — exact for pure-< runs, free for >).
pub tor interp { ip: usize, pos: usize } -> i64
interp = if(ip < st.nop)
| then |> std/switch:char(so[ip])
    | `+` _ |> std/grid:stored { tape_s[pos]: tape_s[pos] +% @as(u8, @intCast(sv[ip])) }
        |> interp(ip: ip + 1, pos): r -> r
    | `>` _ |> idv(v: @max(@as(i64, @intCast(pos)) + @as(i64, sv[ip]), 0)): np
        |> interp(ip: ip + 1, pos: @as(usize, @intCast(np))): r -> r
    | `[` _ |> if(tape_s[pos] == 0)
        | then |> interp(ip: sj[ip], pos): r -> r
        | else |> interp(ip: ip + 1, pos): r -> r
    | `]` _ |> if(tape_s[pos] != 0)
        | then |> interp(ip: sj[ip], pos): r -> r
        | else |> interp(ip: ip + 1, pos): r -> r
    | `.` _ |> std/store:stored { st.res: @rem(st.res * 4 + @as(i64, tape_s[pos]), 4294967296) }
        |> interp(ip: ip + 1, pos): r -> r
    | no-match |> interp(ip: ip + 1, pos): r -> r
| else -> 0

// flush — emit the pending folded run (if any) as one op. st.ro: 0 none,
// 43 inc-run, 62 right-move run, 60 left-move run (op byte canonicalizes
// to '>' for both move directions; the sign lives in v).
pub tor flush {} -> i64
flush = if(st.ro != 0)
| then |> std/grid:stored { ops[st.nop].o: if(st.ro == 43) @as(u8, 43) else @as(u8, 62), ops[st.nop].j: 0, ops[st.nop].v: @as(i32, @intCast(if(st.ro == 43) @mod(st.rn, 256) else st.rn)) }
    |> std/store:stored { st.nop: st.nop + 1, st.ro: 0, st.rn: 0 }
    |> ret0(): _ -> 0
| else -> 0

// emit — fold +- and homogeneous <> runs; '.', ',', '[' and ']' flush then
// emit. ']' also pops the matching '[' and links both endpoints on the
// folded stream ('[' j -> past ']', ']' j -> past '[').
pub tor emit { c: i64 } -> i64
emit = if(c == 43 or c == 45)
| then |> if(st.ro != 0 and st.ro != 43)
    | then |> flush(): _
        |> std/store:stored { st.ro: 43, st.rn: 44 - c }
        |> ret0(): _ -> 0
    | else |> std/store:stored { st.ro: 43, st.rn: st.rn + 44 - c }
        |> ret0(): _ -> 0
| else |> if(c == 62 or c == 60)
    | then |> if(st.ro != c)
        | then |> flush(): _
            |> std/store:stored { st.ro: c, st.rn: c - 61 }
            |> ret0(): _ -> 0
        | else |> std/store:stored { st.rn: st.rn + c - 61 }
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

// Warmup: fold-parse WARM into ops once, run interp 1000x. Results are
// discarded — the reference warmup never touches @result_val.
for(WARM)
! each ch |> emit(c: @as(i64, ch)): _
| done |> flush(): _

for(0..1000)
! each _ |> std/store:stored { st.res: 0 }
    |> interp(ip: 0, pos: 0): _

// Measured run: fold-parse PROG, zero the tape, run once.
std/store:stored { st.nop: 0, st.sp: 0, st.res: 0, st.ro: 0, st.rn: 0 }

for(PROG)
! each ch |> emit(c: @as(i64, ch)): _
| done |> flush(): _

for(0..30000)
! each i |> std/grid:stored { tape[i].c: 0 }

for(0..1)
! each _ |> interp(ip: 0, pos: 0): _

std/io:print.ln("{{ st.res:d }}")
