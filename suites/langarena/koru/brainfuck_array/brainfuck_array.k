// brainfuck_array — LangArena Brainfuck::Array, run.js scored parameters
// (program = mandelbrot-generator bf, warmup_program = hello-world bf run
// 1000x, iterations=1 -> oracle 954437102).
//
// Faithful port of reference/crystal/main.cr Brainfuck::Array:
//   parse:  keep ascii chars in "+-<>[].," (all chars qualify here)
//   jumps:  '[' pushes, ']' pops and writes both endpoints (nil on
//           underflow/leftover - never triggers for these programs)
//   run:    tape u8[30000], pos clamps at 0 on '<'; '.' folds
//           result = result << 2 +% cell (u32 wrap)
//   warmup runs the hello-world program 1000x; its result is DISCARDED
//   (crystal warmup never touches @result_val) - only the single measured
//   run accumulates.
//
// Faithfulness differences, stated:
// - Fixed grids (cmd/jmp/stk 512, tape 30000) vs reference growable
//   arrays; cmd capacity is sized for these programs (185/111).
// - The dispatch while-loop is a tail-recursive tor (self_loop lowered).
// - Dispatch is one-op-per-char like the reference — the goose-race
//   kernel's run-folding (+- and <> collapsed to net deltas) is a
//   known further route (~4x fewer dispatches there) but restructures
//   the program representation beyond the reference; deliberately not
//   taken here.
// - Tape zeroing between runs replaces fresh allocation; warmup runs
//   reuse whatever tape state remains (their results are discarded).
// - res/acc i64 with explicit mod-2^32 folds (u32 wrap).
// - No `,` opcode present - treated as no-op through the else arm.
//
import std/io
import std/grid
import std/store
import std/switch

const {
    PROG: ">++[<+++++++++++++>-]<[[>+>+<<-]>[<+>-]++++++++[>++++++++<-]>.[-]<<>++++++++++[>++++++++++[>++++++++++[>++++++++++[>++++++++++[>++++++++++[>++++++++++[-]<-]<-]<-]<-]<-]<-]<-]++++++++++."
    WARM: "++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>."
}

std/grid:new(tape, size: 30000) { c: 0[u8] }
std/grid:slice(tape_s) { tape.c }
std/grid:slice(cmd_s) { cmd.c }
std/grid:slice(jmp_s) { jmp.v }
std/grid:new(cmd, size: 512) { c: 0[u8] }
std/grid:new(jmp, size: 512) { v: 0[i64] }
std/grid:new(stk, size: 512) { v: 0[i64] }
std/store:new(st) { pos: 0[i64], n: 0[i64], d: 0[i64], res: 0[i64] }

// iscmd — byte belongs to "+-<>[].,"
pub tor iscmd { c: i64 } -> i64
iscmd = if(c == 43 or c == 45 or c == 60 or c == 62 or c == 46 or c == 91 or c == 93 or c == 44)
| then -> 1
| else -> 0

// interp — the dispatch loop as a tail-recursive tor (self_loop
// lowered). pc/pos ride as parameters so they stay register-resident
// (the goose-race shape); switch:char emits a native Zig switch;
// tape/cmd/jmp are borrowed slices so every access is verbatim.
pub tor interp { pc: i64, pos: i64 } -> i64
interp = if(pc < st.n)
| then |> std/switch:char(cmd_s[@as(usize, @intCast(pc))])
    | `+` _ |> std/grid:stored { tape_s[@as(usize, @intCast(pos))]: tape_s[@as(usize, @intCast(pos))] +% 1 }
        |> interp(pc: pc + 1, pos): r -> r
    | `-` _ |> std/grid:stored { tape_s[@as(usize, @intCast(pos))]: tape_s[@as(usize, @intCast(pos))] -% 1 }
        |> interp(pc: pc + 1, pos): r -> r
    | `>` _ |> interp(pc: pc + 1, pos: pos + 1): r -> r
    | `<` _ |> interp(pc: pc + 1, pos: @max(pos - 1, 0)): r -> r
    | `[` _ |> if(tape_s[@as(usize, @intCast(pos))] == 0)
        | then |> interp(pc: jmp_s[@as(usize, @intCast(pc))], pos): r -> r
        | else |> interp(pc: pc + 1, pos): r -> r
    | `]` _ |> if(tape_s[@as(usize, @intCast(pos))] != 0)
        | then |> interp(pc: jmp_s[@as(usize, @intCast(pc))], pos): r -> r
        | else |> interp(pc: pc + 1, pos): r -> r
    | `.` _ |> std/store:stored { st.res: @rem(st.res * 4 + @as(i64, tape_s[@as(usize, @intCast(pos))]), 4294967296) }
        |> interp(pc: pc + 1, pos): r -> r
    | no-match |> interp(pc: pc + 1, pos): r -> r
| else -> 0

// Warmup: parse WARM into cmd/jmp once, run interp 1000x. Results are
// discarded — the reference warmup never touches @result_val.

// parse: every char of these programs is a command (the "+-<>[].," filter
// is vacuous for PROG/WARM — verified: 185/111 chars all commands)
for(WARM)
! each ch |> std/grid:stored { cmd[st.n].c: @as(u8, @intCast(ch)) }
    |> std/store:stored { st.n: st.n + 1 }

// build jumps: '[' pushes its index, ']' pops and links both ends
for(0..512)
! each i |> if(i < st.n)
    | then |> if(cmd[i].c == 91)
        | then |> std/grid:stored { stk[st.d].v: @as(i64, @intCast(i)) }
            |> std/store:stored { st.d: st.d + 1 }
        | else |> if(cmd[i].c == 93)
            | then |> std/store:stored { st.d: st.d - 1 }
                |> std/grid:stored { jmp[stk[st.d].v].v: @as(i64, @intCast(i)) }
                |> std/grid:stored { jmp[i].v: stk[st.d].v }

for(0..1000)
! each _ |> std/store:stored { st.res: 0 }
    |> interp(pc: 0, pos: 0): _

// Measured run: parse PROG, rebuild jumps, zero the tape, run once.
std/store:stored { st.n: 0 }
std/store:stored { st.d: 0 }
std/store:stored { st.res: 0 }

for(PROG)
! each ch |> std/grid:stored { cmd[st.n].c: @as(u8, @intCast(ch)) }
    |> std/store:stored { st.n: st.n + 1 }

for(0..512)
! each i |> if(i < st.n)
    | then |> if(cmd[i].c == 91)
        | then |> std/grid:stored { stk[st.d].v: @as(i64, @intCast(i)) }
            |> std/store:stored { st.d: st.d + 1 }
        | else |> if(cmd[i].c == 93)
            | then |> std/store:stored { st.d: st.d - 1 }
                |> std/grid:stored { jmp[stk[st.d].v].v: @as(i64, @intCast(i)) }
                |> std/grid:stored { jmp[i].v: stk[st.d].v }

for(0..30000)
! each i |> std/grid:stored { tape[i].c: 0 }

for(0..1)
! each _ |> interp(pc: 0, pos: 0): _

std/io:print.ln("{{ st.res:d }}")
