# Bend 2 port of the Osprey compute-kernel reference (see reference/cases).
# Faithful naive algorithm; oracle-gated by expected.txt.

import Base

def jos(+fuel: Nat, +i: Nat, acc: Nat) -> Nat:
  match fuel:
    case 0n:
      acc
    case 1n+p:
      jos(p, Nat.add(i, 1n), Nat.mod(Nat.add(acc, 7n), i))

def main() -> IO(Unit):
  lim = Nat.sub(Nat.mul(10n, Nat.mul(1000n, 1000n)), 1n)
  r = jos(lim, 2n, 0n)
  IO.print(Nat.show(r))
