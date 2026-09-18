# Bend 2 fork/join variant of the Osprey compute-kernel reference.
# 8-way range split via recursive psum; leaves run the sequential fold.
# caveat: @unsafe — same non-structural recursion as the bend/ port.

import Base

@unsafe
def hasFactor(over: Bool, div: Bool, +n: Nat, +d: Nat) -> Bool:
  match over:
    case True{}:
      False{}
    case False{}:
      match div:
        case True{}:
          True{}
        case False{}:
          hasFactor(Nat.is_gt(Nat.mul(Nat.add(d, 1n), Nat.add(d, 1n)), n),
                    Nat.is_eq(Nat.mod(n, Nat.add(d, 1n)), 0n),
                    n, Nat.add(d, 1n))

@unsafe
def isPrime(+n: Nat) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n:
      False{}
    case 1n+p:
      hf = hasFactor(Nat.is_gt(4n, n), Nat.is_eq(Nat.mod(n, 2n), 0n), n, 2n)
      Bool.not(hf)

def go(+n: Nat, +i: Nat, acc: Nat, isp: Bool) -> Nat:
  match n:
    case 0n:
      acc
    case 1n+p:
      match isp:
        case True{}:
          go(p, Nat.sub(i, 1n), Nat.add(acc, 1n), isPrime(Nat.sub(i, 1n)))
        case False{}:
          go(p, Nat.sub(i, 1n), acc, isPrime(Nat.sub(i, 1n)))

def psum(+k: Nat, +n: Nat, +i: Nat) -> Nat:
  match k:
    case 0n:
      go(n, i, 0n, isPrime(i))
    case 1n+kp:
      a b = psum(kp, Nat.sub(n, Nat.div(n, 2n)), i)  psum(kp, Nat.div(n, 2n), Nat.sub(i, Nat.sub(n, Nat.div(n, 2n))))
      Nat.add(a, b)

def main() -> IO(Unit):
  r = psum(3n, Nat.sub(Nat.mul(200n, 1000n), 1n), Nat.sub(Nat.mul(200n, 1000n), 1n))
  IO.print(Nat.show(r))
