# Bend 2 fork/join variant of the Osprey compute-kernel reference.
# 8-way range split via recursive psum; leaves run the sequential fold.
# caveat: @unsafe — same non-structural recursion as the bend/ port.

import Base

@unsafe
def digsum(+n: Nat, small: Bool) -> Nat:
  match small:
    case True{}:
      n
    case False{}:
      Nat.add(Nat.mod(n, 10n), digsum(Nat.div(n, 10n), Nat.is_lt(Nat.div(n, 10n), 10n)))

def go(+n: Nat, +i: Nat, acc: Nat) -> Nat:
  match n:
    case 0n:
      acc
    case 1n+p:
      go(p, Nat.sub(i, 1n), Nat.add(acc, digsum(i, Nat.is_lt(i, 10n))))

def psum(+k: Nat, +n: Nat, +i: Nat) -> Nat:
  match k:
    case 0n:
      go(n, i, 0n)
    case 1n+kp:
      a b = psum(kp, Nat.sub(n, Nat.div(n, 2n)), i)  psum(kp, Nat.div(n, 2n), Nat.sub(i, Nat.sub(n, Nat.div(n, 2n))))
      Nat.add(a, b)

def main() -> IO(Unit):
  r = psum(3n, Nat.mul(2000n, 1000n), Nat.mul(2000n, 1000n))
  IO.print(Nat.show(r))
