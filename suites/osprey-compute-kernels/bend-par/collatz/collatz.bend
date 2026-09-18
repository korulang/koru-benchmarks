# Bend 2 fork/join variant of the Osprey compute-kernel reference.
# 8-way range split via recursive psum; leaves run the sequential fold.
# caveat: @unsafe — same non-structural recursion as the bend/ port.

import Base

@unsafe
def coll(+n: Nat, even: Bool) -> Nat:
  match n:
    case 0n:
      0n
    case 1n:
      0n
    case 2n+pp:
      match even:
        case True{}:
          Nat.add(1n, coll(Nat.div(n, 2n), Nat.is_eq(Nat.mod(n, 4n), 0n)))
        case False{}:
          m = Nat.add(Nat.mul(3n, n), 1n)
          Nat.add(1n, coll(m, True{}))

def collatz(+n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n:
      0n
    case 2n+pp:
      coll(n, Nat.is_eq(Nat.mod(n, 2n), 0n))

def go(+n: Nat, +i: Nat, acc: Nat) -> Nat:
  match n:
    case 0n:
      acc
    case 1n+p:
      go(p, Nat.sub(i, 1n), Nat.add(acc, collatz(i)))

def psum(+k: Nat, +n: Nat, +i: Nat) -> Nat:
  match k:
    case 0n:
      go(n, i, 0n)
    case 1n+kp:
      a b = psum(kp, Nat.sub(n, Nat.div(n, 2n)), i)  psum(kp, Nat.div(n, 2n), Nat.sub(i, Nat.sub(n, Nat.div(n, 2n))))
      Nat.add(a, b)

def main() -> IO(Unit):
  r = psum(3n, Nat.mul(100n, 1000n), Nat.mul(100n, 1000n))
  IO.print(Nat.show(r))
