# Bend 2 fork/join variant of the Osprey compute-kernel reference.
# 8-way range split; each chunk seeds its own is_even entry flag.

import Base

def eo(+n: Nat, e: Bool) -> Bool:
  match n:
    case 0n:
      e
    case 1n+p:
      eo(p, Bool.not(e))

def go(+n: Nat, +i: Nat, acc: Nat, e: Bool) -> Nat:
  match n:
    case 0n:
      acc
    case 1n+p:
      match e:
        case True{}:
          go(p, Nat.sub(i, 1n), Nat.add(acc, 1n),
             eo(Nat.mod(Nat.sub(i, 1n), 1000n), True{}))
        case False{}:
          go(p, Nat.sub(i, 1n), acc,
             eo(Nat.mod(Nat.sub(i, 1n), 1000n), True{}))

def psum(+k: Nat, +n: Nat, +i: Nat) -> Nat:
  match k:
    case 0n:
      go(n, i, 0n, eo(Nat.mod(i, 1000n), True{}))
    case 1n+kp:
      a b = psum(kp, Nat.sub(n, Nat.div(n, 2n)), i)  psum(kp, Nat.div(n, 2n), Nat.sub(i, Nat.sub(n, Nat.div(n, 2n))))
      Nat.add(a, b)

def main() -> IO(Unit):
  r = psum(3n, Nat.sub(Nat.mul(130n, 1000n), 1n), Nat.sub(Nat.mul(130n, 1000n), 1n))
  IO.print(Nat.show(r))
