# Bend 2 port of the Osprey compute-kernel reference (see reference/cases).
# Faithful naive algorithm; oracle-gated by expected.txt.
# caveat: @unsafe — Newton iterates x<- (x+n/x)/2 converge, not structurally shrink.

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

def go(+i: Nat, acc: Nat) -> Nat:
  match i:
    case 0n:
      acc
    case 1n+p:
      go(p, Nat.add(acc, isqrt(i)))

def main() -> IO(Unit):
  lim = Nat.mul(1000n, 1000n)
  r = go(lim, 0n)
  IO.print(Nat.show(r))
