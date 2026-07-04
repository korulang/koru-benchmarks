// textstats — pseudo-random token stream, per-token string metrics
// (length + contains "o" + startsWith "t") folded into a checksum over
// 200000 draws. Faithful port of reference/cases/textstats (oracle
// 1574956) on the oracle-checked path: seed line "0"/empty -> seed 1,
// hashAt(seed,i) = r1(r1(seed+i)) with r1(x) = x*16807 mod 2147483647,
// word(k) an 8-way fixed vocab, score = len + 7*has-o + 3*starts-t.
// String ops are per-char folds over []const u8 (810_121/810_182 shapes),
// w.len (660_001) and w[0] indexing (010_062) — no substring builtins
// needed for single-char needles.
// KNOWN DIVERGENCE (named gap): the reference's mode "1" draws a
// cryptographically-secure random seed; Koru's stdlib has NO random
// builtin, so nonzero seeds pass through unchanged. Mode 1 is never
// oracle-checked (their harness feeds "0"), so the checked algorithm
// is faithful; the missing random builtin is the gap.
import std/io

pub event to-int { s: []const u8 } -> i64

to-int = capture { n: 0[i64] }
! as a |> for(s)
    ! each ch |> captured { n: a.n * 10 + (ch - 48) }
| captured r -> r.n

pub event seed-of { v: i64 } -> i64

seed-of = if(v == 0)
| then -> 1
| else -> v

pub event word { k: i64 } -> []const u8

word = if(k == 0)
| then -> "the"
| else |> if(k == 1)
    | then -> "quick"
    | else |> if(k == 2)
        | then -> "brown"
        | else |> if(k == 3)
            | then -> "fox"
            | else |> if(k == 4)
                | then -> "jumps"
                | else |> if(k == 5)
                    | then -> "over"
                    | else |> if(k == 6)
                        | then -> "lazy"
                        | else -> "dog"

pub event has-o { w: []const u8 } -> i64

has-o = capture { found: 0[i64] }
! as a |> for(w)
    ! each ch |> captured { found: @max(a.found, @intFromBool(ch == 'o')) }
| captured r -> r.found

pub event starts-with-t { w: []const u8 } -> i64

starts-with-t = if(w[0] == 't')
| then -> 1
| else -> 0

pub event score { w: []const u8 } -> i64

score = has-o(w): o |> starts-with-t(w): t -> @as(i64, @intCast(w.len)) + o * 7 + t * 3

capture { seed: 1[i64] }
! as sd |> std/io:read-lines()
    ! line l |> to-int(s: l): v |> seed-of(v): sv |> captured { seed: sv }
    | done _ |> _
    | failed _ |> captured { seed: sd.seed }
| captured r |> capture { acc: 0[i64] }
    ! as a |> for(0..200000)
        ! each i |> word(k: @rem(@rem(@rem((r.seed + @as(i64, @intCast(i))) * 16807, 2147483647) * 16807, 2147483647), 8)): w |> score(w): s |> captured { acc: a.acc + s }
    | captured r2 |> std/io:print.ln("{{ r2.acc:d }}")
