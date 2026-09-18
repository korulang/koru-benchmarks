# Bend 2 fork/join variant of the Osprey compute-kernel reference.
# 8-way range split via recursive psum; leaves run the sequential fold.
# caveat: @unsafe — same non-structural recursion as the bend/ port.

import Base

@unsafe
def gcd(+a: Nat, +b: Nat) -> Nat:
  match b:
    case 0n:
      a
    case 1n+bp:
      gcd(b, Nat.mod(a, b))

def go(+n: Nat, +i: Nat, acc: Nat) -> Nat:
  match n:
    case 0n:
      acc
    case 1n+p:
      k = Nat.add(Nat.mul(1234n, 1000n), 567n)
      go(p, Nat.sub(i, 1n), Nat.add(acc, gcd(i, k)))

def psum(+k: Nat, +n: Nat, +i: Nat) -> Nat:
  match k:
    case 0n:
      go(n, i, 0n)
    case 1n+kp:
      a b = psum(kp, Nat.sub(n, Nat.div(n, 2n)), i)  psum(kp, Nat.div(n, 2n), Nat.sub(i, Nat.sub(n, Nat.div(n, 2n))))
      Nat.add(a, b)

def main() -> IO(Unit):
  r = psum(3n, Nat.sub(Nat.mul(2000n, 1000n), 1n), Nat.sub(Nat.mul(2000n, 1000n), 1n))
  IO.print(Nat.show(r))
