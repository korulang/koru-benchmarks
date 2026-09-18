# Bend 2 port of the Osprey compute-kernel reference (see reference/cases).
# Faithful naive algorithm; oracle-gated by expected.txt.

import Base

def hanoi(+n: Nat, acc: Nat) -> Nat:
  match n:
    case 0n:
      acc
    case 1n+p:
      hanoi(p, Nat.add(hanoi(p, acc), 1n))

def main() -> IO(Unit):
  r = hanoi(25n, 0n)
  IO.print(Nat.show(r))
