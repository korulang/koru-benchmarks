# tak — Takeuchi tak(32,16,8). Faithful port of reference/cases/tak
# (oracle 9). TWO forced encodings: (1) @unsafe — Bend's mandatory
# termination checker rejects tak's nested self-call (a computed first
# arg can never be a match-exposed smaller part), so this def sits
# OUTSIDE Bend's proof guarantees; (2) the x>y guard is hoisted to a
# leading `c` parameter because match may only scrutinize a parameter,
# never a computed value. Same recurrence, same oracle.

import Base

@unsafe
def tak(+c: Bool, +x: Nat, +y: Nat, +z: Nat) -> Nat:
  match c:
    case False{}:
      z
    case True{}:
      +t1 = tak(Nat.is_gt(Nat.sub(x,1n), y), Nat.sub(x,1n), y, z)
      +t2 = tak(Nat.is_gt(Nat.sub(y,1n), z), Nat.sub(y,1n), z, x)
      +t3 = tak(Nat.is_gt(Nat.sub(z,1n), x), Nat.sub(z,1n), x, y)
      tak(Nat.is_gt(t1,t2), t1, t2, t3)

def main() -> IO(Unit):
  r = tak(Nat.is_gt(32n,16n), 32n, 16n, 8n)
  IO.print(Nat.show(r))
