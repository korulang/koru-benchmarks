# Bend 2 port of the Osprey compute-kernel reference (see reference/cases).
# Faithful naive algorithm; oracle-gated by expected.txt.

import Base

def MD() -> Nat:
  Nat.add(Nat.mul(Nat.mul(1000n, 1000n), 1000n), 7n)

def lk(+i: Nat, +j: Nat, +k: Nat, acc: Nat) -> Nat:
  match k:
    case 0n:
      acc
    case 1n+kp:
      lk(i, j, kp, Nat.mod(Nat.add(acc, Nat.mul(Nat.mul(i, j), k)), MD()))

def lj(+i: Nat, +j: Nat, +n: Nat, acc: Nat) -> Nat:
  match j:
    case 0n:
      acc
    case 1n+jp:
      lj(i, jp, n, lk(i, j, n, acc))

def li(+i: Nat, +n: Nat, acc: Nat) -> Nat:
  match i:
    case 0n:
      acc
    case 1n+ip:
      li(ip, n, lj(i, n, n, acc))

def main() -> IO(Unit):
  r = li(250n, 250n, 0n)
  IO.print(Nat.show(r))
