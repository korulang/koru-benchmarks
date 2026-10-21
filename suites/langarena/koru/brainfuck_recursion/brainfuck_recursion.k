// brainfuck_recursion — LangArena Brainfuck::Recursion, run.js scored
// parameters (same programs as Brainfuck::Array, oracle 954437102).
//
// Faithful port of reference/crystal/main.cr Brainfuck::Recursion:
//   parse:  recursive descent builds a NESTED op tree — '[' parses a
//           child op-list, ']' ends it. Non-command chars (incl. ',')
//           produce NO node — unlike ::Array which keeps ',' as a
//           runtime no-op.
//   run:    run_ops walks the tree; a loop node is
//           `while tape.get != 0: run_ops(children)` — the body re-runs
//           while the cell is nonzero. '.' does res = res<<2 + cell
//           (i64, then to_u32 — same truncated value as folding mod 2^32
//           per step).
//   warmup runs the hello-world program 1000x, result DISCARDED.
//
// Substrate, stated:
// - op tree is a flat grid: ops[i] = { kind, next, child } — next links
//   siblings, child is a loop's first body op; 0 = none (index 0 is the
//   top-level sentinel).
// - parse is the pstep tor: recursive descent over src (the program text
//   materialized to a byte grid — const strings are not indexable).
//   vch selects whether a level's first link lands on prev.next (0) or
//   prev.child (1), which makes the child-head land directly on the loop
//   node and leaves child=0 for empty bodies. prev rides the return
//   record so the post-body continuation recovers the loop-node index
//   (store fields can't hold per-frame state across recursion).
// - dispatch while-loop is a tail-recursive tor (self_loop lowered);
//   rloop is the `while cell != 0` loop-body rerun, also tail-lowered.
//   Body re-entry is a REAL call — loop nesting depth ≤ 6 here.
// - tape is a fixed 30000 grid (reference grows on '>'); both programs
//   stay within it (verified by the oracle run).
// - tape re-zeroed + res reset PER measured run (reference allocates a
//   fresh Tape/Program per run — per-iteration state must not leak);
//   warmup runs share a dirty tape, results discarded anyway.
//
import std/io
import std/grid
import std/store

const {
    PROG: ">++[<+++++++++++++>-]<[[>+>+<<-]>[<+>-]++++++++[>++++++++<-]>.[-]<<>++++++++++[>++++++++++[>++++++++++[>++++++++++[>++++++++++[>++++++++++[>++++++++++[-]<-]<-]<-]<-]<-]<-]<-]++++++++++."
    WARM: "++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>."
}

std/grid:new(tape, size: 30000) { c: 0[u8] }
std/grid:new(src, size: 512) { c: 0[u8] }
std/grid:new(ops, size: 512) { kind: 0[i64], next: 0[i64], child: 0[i64] }
std/store:new(st) { pos: 0[i64], m: 1[i64], res: 0[i64], acc: 0[i64], si: 0[i64] }

// isop — byte is a node-producing command (+-<>..[) ; ']' handled by pstep
pub tor isop { c: i64 } -> i64
isop = if(c == 43 or c == 45 or c == 60 or c == 62 or c == 46 or c == 91)
| then -> 1
| else -> 0

// pstep — recursive-descent parse. prev = link target for THIS level's
// next alloc (sibling via next, or the loop node via child when vch=1).
// p0 = the level's ENTRY prev, returned unchanged so the '[' arm's
// post-body continuation recovers the loop-node index after the body
// recursion clobbers st.m — store fields can't hold per-frame state.
pub tor pstep { pos: i64, prev: i64, p0: i64, vch: i64 } -> { pos: i64, prev: i64 }
pstep = if(src[pos].c == 0)
| then -> { pos, prev: p0 }
| else |> if(src[pos].c == 93)
    | then -> { pos: pos + 1, prev: p0 }
    | else |> isop(c: @as(i64, src[pos].c)): ok
        |> if(ok == 0)
        | then |> pstep(pos: pos + 1, prev, p0, vch): r -> r
        | else |> if(vch == 0)
            | then |> std/grid:stored { ops[prev].next: st.m }
            | else |> std/grid:stored { ops[prev].child: st.m }
        |> std/grid:stored { ops[st.m].kind: @as(i64, src[pos].c) }
        |> std/grid:stored { ops[st.m].next: 0 }
        |> std/grid:stored { ops[st.m].child: 0 }
        |> std/store:stored { st.m: st.m + 1 }
        |> if(src[pos].c == 91)
            | then |> pstep(pos: pos + 1, prev: st.m - 1, p0: st.m - 1, vch: 1): r
                |> pstep(r.pos, r.prev, p0, vch: 0): r2 -> r2
            | else |> pstep(pos: pos + 1, prev: st.m - 1, p0, vch: 0): r -> r

// rloop — `while tape.get != 0: run_ops(body)` (tail-lowered)
pub tor rloop { body: i64 } -> i64
rloop = if(tape[st.pos].c != 0)
| then |> runops(i: body): _
    |> rloop(body): r -> r
| else -> 0

// runops — tree walk as tail-recursive tor over sibling links
pub tor runops { i: i64 } -> i64
runops = if(i > 0)
| then |> if(ops[i].kind == 43)
    | then |> std/grid:stored { tape[st.pos].c: tape[st.pos].c +% 1 }
        |> runops(i: ops[i].next): r -> r
    | else |> if(ops[i].kind == 45)
        | then |> std/grid:stored { tape[st.pos].c: tape[st.pos].c -% 1 }
            |> runops(i: ops[i].next): r -> r
        | else |> if(ops[i].kind == 62)
            | then |> std/store:stored { st.pos: st.pos + 1 }
                |> runops(i: ops[i].next): r -> r
            | else |> if(ops[i].kind == 60)
                | then |> std/store:stored { st.pos: @max(st.pos - 1, 0) }
                    |> runops(i: ops[i].next): r -> r
                | else |> if(ops[i].kind == 46)
                    | then |> std/store:stored { st.res: @rem(st.res * 4 + @as(i64, tape[st.pos].c), 4294967296) }
                        |> runops(i: ops[i].next): r -> r
                    | else |> if(ops[i].kind == 91)
                        | then |> rloop(body: ops[i].child): _
                            |> runops(i: ops[i].next): r -> r
                        | else -> 0
| else -> 0

// Warmup: materialize WARM into src, parse once, run 1000x — results
// discarded, matching the reference (Program.new parses per run; the
// parse is 111 bytes, hoist is noted above).
for(WARM)
! each ch |> std/grid:stored { src[st.si].c: @as(u8, @intCast(ch)) }
    |> std/store:stored { st.si: st.si + 1 }

for(0..1)
! each _ |> pstep(pos: 0, prev: 0, p0: 0, vch: 0): _

for(0..1000)
! each _ |> std/store:stored { st.pos: 0 }
    |> std/store:stored { st.res: 0 }
    |> runops(i: ops[0].next): _

// Measured run: materialize PROG, reparse (st.m resets), re-zero tape,
// run once.
std/store:stored { st.si: 0 }
std/store:stored { st.m: 1 }

for(PROG)
! each ch |> std/grid:stored { src[st.si].c: @as(u8, @intCast(ch)) }
    |> std/store:stored { st.si: st.si + 1 }

for(0..1)
! each _ |> pstep(pos: 0, prev: 0, p0: 0, vch: 0): _

for(0..1)
! each _ |> for(0..30000)
    ! each i |> std/grid:stored { tape[i].c: 0 }
    | done |> std/store:stored { st.res: 0 }
    |> std/store:stored { st.pos: 0 }
    |> runops(i: ops[0].next): _
    |> std/store:stored { st.acc: @rem(st.acc + st.res, 4294967296) }

std/io:print.ln("{{ st.acc:d }}")
