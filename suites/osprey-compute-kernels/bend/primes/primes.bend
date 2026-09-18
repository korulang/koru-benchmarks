# Bend 2 port of the Osprey compute-kernel reference (see reference/cases).
# Faithful naive algorithm; oracle-gated by expected.txt.
# caveat: @unsafe — trial division d<-d+1 grows and the d*d>n bound is not structural.
# caveat: over/div conditions are param flags (Bend cannot match a local binder).

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

def go(+i: Nat, acc: Nat, isp: Bool) -> Nat:
  match i:
    case 0n:
      acc
    case 1n+p:
      match isp:
        case True{}:
          go(p, Nat.add(acc, 1n), isPrime(p))
        case False{}:
          go(p, acc, isPrime(p))

def main() -> IO(Unit):
  r = go(Nat.sub(Nat.mul(200n, 1000n), 1n), 0n,
         isPrime(Nat.sub(Nat.mul(200n, 1000n), 1n)))
  IO.print(Nat.show(r))
