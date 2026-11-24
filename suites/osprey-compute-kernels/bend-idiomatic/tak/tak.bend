# tak — Takeuchi tak(32,16,8). Faithful oracle-gated port.
# Idiomatic Bend: the three independent argument recursions use parallel call
# notation. The dependent outer recurrence remains sequential. @unsafe remains
# mandatory because tak's nested self-call is outside Bend's termination proof.

import Base

@unsafe
def tak(+c: Bool, +x: Nat, +y: Nat, +z: Nat) -> Nat:
  match c:
    case False{}:
      z
    case True{}:
      +t1 +t2 +t3 = tak(Nat.is_gt(Nat.sub(x,1n), y), Nat.sub(x,1n), y, z) tak(Nat.is_gt(Nat.sub(y,1n), z), Nat.sub(y,1n), z, x) tak(Nat.is_gt(Nat.sub(z,1n), x), Nat.sub(z,1n), x, y)
      tak(Nat.is_gt(t1,t2), t1, t2, t3)

def main() -> IO(Unit):
  r = tak(Nat.is_gt(32n,16n), 32n, 16n, 8n)
  IO.print(Nat.show(r))
