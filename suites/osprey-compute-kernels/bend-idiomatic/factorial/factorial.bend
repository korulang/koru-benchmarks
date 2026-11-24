# Bend 2 idiomatic port of the Osprey compute-kernel reference.
# Faithful naive product 1*2*...*10,000,000 mod 1000000007.
# Linear repetition is structural tail recursion over Nat fuel. Since Bend Nat
# is a 48-bit immediate and acc*i can exceed it, i is decomposed into two
# 12-bit chunks; i < 10,000,000 < 4096^2, so all intermediate products fit.

import Base

def MD() -> Nat:
  Nat.add(Nat.mul(Nat.mul(1000n, 1000n), 1000n), 7n)

def CHUNK() -> Nat:
  Nat.mul(64n, 64n)

def reduce2(+x: Nat, +m: Nat, +big: Bool) -> Nat:
  match big:
    case True{}:
      Nat.sub(x, m)
    case False{}:
      x

def mulmod(+a: Nat, +b: Nat, +m: Nat) -> Nat:
  lo = Nat.mod(b, CHUNK())
  hi = Nat.div(b, CHUNK())
  alo = Nat.mod(Nat.mul(a, lo), m)
  ahi0 = Nat.mod(Nat.mul(a, hi), m)
  ahi = Nat.mod(Nat.mul(ahi0, CHUNK()), m)
  +sum = Nat.add(alo, ahi)
  reduce2(sum, m, Nat.is_ge(sum, m))

def go(+i: Nat, acc: Nat) -> Nat:
  match i:
    case 0n:
      acc
    case 1n+p:
      go(p, mulmod(acc, i, MD()))

def main() -> IO(Unit):
  lim = Nat.mul(10n, Nat.mul(1000n, 1000n))
  r = go(lim, 1n)
  IO.print(Nat.show(r))
