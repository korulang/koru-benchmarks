# Bend 2 fork/join variant of the Osprey compute-kernel reference.
# 8-way split over the outer i loop; j/k loops stay sequential.

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

def li(+cnt: Nat, +i: Nat, +n: Nat, acc: Nat) -> Nat:
  match cnt:
    case 0n:
      acc
    case 1n+cp:
      li(cp, Nat.sub(i, 1n), n, lj(i, n, n, acc))

def psum(+k: Nat, +cnt: Nat, +i: Nat, +n: Nat) -> Nat:
  match k:
    case 0n:
      li(cnt, i, n, 0n)
    case 1n+kp:
      a b = psum(kp, Nat.sub(cnt, Nat.div(cnt, 2n)), i, n)  psum(kp, Nat.div(cnt, 2n), Nat.sub(i, Nat.sub(cnt, Nat.div(cnt, 2n))), n)
      Nat.mod(Nat.add(a, b), MD())

def main() -> IO(Unit):
  r = psum(3n, 250n, 250n, 250n)
  IO.print(Nat.show(r))
