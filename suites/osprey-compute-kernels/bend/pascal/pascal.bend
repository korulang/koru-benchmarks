# Bend 2 port of the Osprey compute-kernel reference (see reference/cases).
# Faithful naive algorithm; oracle-gated by expected.txt.

import Base

def binom(+n: Nat, +k: Nat) -> Nat:
  match n:
    case 0n:
      Bool.pick(Nat, Nat.is_eq(k, 0n), 1n, 0n)
    case 1n+p:
      match k:
        case 0n:
          1n
        case 1n+kp:
          Nat.add(binom(p, k), binom(p, kp))

def main() -> IO(Unit):
  r = binom(27n, 13n)
  IO.print(Nat.show(r))
