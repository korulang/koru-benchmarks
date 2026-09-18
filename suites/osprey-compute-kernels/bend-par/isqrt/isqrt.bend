# Bend 2 fork/join variant of the Osprey compute-kernel reference.
# 8-way range split via recursive psum; leaves run the sequential fold.
# caveat: @unsafe — same non-structural recursion as the bend/ port.

import Base

@unsafe
def iter(+n: Nat, +x: Nat, +y: Nat, lt: Bool) -> Nat:
  match lt:
    case False{}:
      x
    case True{}:
      iter(n, y,
           Nat.div(Nat.add(y, Nat.div(n, y)), 2n),
           Nat.is_lt(Nat.div(Nat.add(y, Nat.div(n, y)), 2n), y))

@unsafe
def isqrt(+n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n:
      1n
    case 1n+p:
      iter(n, n,
           Nat.div(Nat.add(n, 1n), 2n),
           Nat.is_lt(Nat.div(Nat.add(n, 1n), 2n), n))

def go(+n: Nat, +i: Nat, acc: Nat) -> Nat:
  match n:
    case 0n:
      acc
    case 1n+p:
      go(p, Nat.sub(i, 1n), Nat.add(acc, isqrt(i)))

def psum(+k: Nat, +n: Nat, +i: Nat) -> Nat:
  match k:
    case 0n:
      go(n, i, 0n)
    case 1n+kp:
      a b = psum(kp, Nat.sub(n, Nat.div(n, 2n)), i)  psum(kp, Nat.div(n, 2n), Nat.sub(i, Nat.sub(n, Nat.div(n, 2n))))
      Nat.add(a, b)

def main() -> IO(Unit):
  r = psum(3n, Nat.mul(1000n, 1000n), Nat.mul(1000n, 1000n))
  IO.print(Nat.show(r))
