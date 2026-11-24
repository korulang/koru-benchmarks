# Bend 2 port of the Osprey compute-kernel reference (see reference/cases).
# Faithful naive repeated multiplication; oracle-gated by expected.txt.
# Idiomatic numeric encoding: linear loops are structural tail recursion over
# Nat fuel. Bend Nat is a 48-bit immediate, so modular multiplication uses a
# two-chunk decomposition of the <1,000,000 base rather than bitwise doubling.
# Every exponent chain still performs twenty repeated multiplications.

import Base

def MD() -> Nat:
  Nat.add(Nat.mul(Nat.mul(1000n, 1000n), 1000n), 7n)

def CHUNK() -> Nat:
  Nat.mul(32n, 32n)

def reduce2(+x: Nat, +m: Nat, +big: Bool) -> Nat:
  match big:
    case True{}:
      Nat.sub(x, m)
    case False{}:
      x

# b is always the outer-loop base (< 1,000,000, hence < 1024^2). Split it
# into two 10-bit chunks so every intermediate product fits Bend's 48-bit Nat.
def mulmod(+a: Nat, +b: Nat, +m: Nat) -> Nat:
  lo = Nat.mod(b, CHUNK())
  hi = Nat.div(b, CHUNK())
  alo = Nat.mod(Nat.mul(a, lo), m)
  ahi0 = Nat.mod(Nat.mul(a, hi), m)
  ahi = Nat.mod(Nat.mul(ahi0, CHUNK()), m)
  +sum = Nat.add(alo, ahi)
  reduce2(sum, m, Nat.is_ge(sum, m))

def pm(+b: Nat, +e: Nat, acc: Nat) -> Nat:
  match e:
    case 0n:
      acc
    case 1n+ep:
      pm(b, ep, mulmod(acc, b, MD()))

def go(+i: Nat, acc: Nat) -> Nat:
  match i:
    case 0n:
      acc
    case 1n+p:
      go(p, Nat.mod(Nat.add(acc, pm(i, 20n, 1n)), MD()))

def main() -> IO(Unit):
  lim = Nat.sub(Nat.mul(1000n, 1000n), 1n)
  r = go(lim, 0n)
  IO.print(Nat.show(r))
