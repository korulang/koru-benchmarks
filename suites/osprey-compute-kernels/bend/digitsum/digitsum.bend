# Bend 2 port of the Osprey compute-kernel reference (see reference/cases).
# Faithful naive algorithm; oracle-gated by expected.txt.
# caveat: @unsafe — digsum(n/10) is not a match-exposed decrease.

import Base

@unsafe
def digsum(+n: Nat, small: Bool) -> Nat:
  match small:
    case True{}:
      n
    case False{}:
      Nat.add(Nat.mod(n, 10n), digsum(Nat.div(n, 10n), Nat.is_lt(Nat.div(n, 10n), 10n)))

def go(+i: Nat, acc: Nat) -> Nat:
  match i:
    case 0n:
      acc
    case 1n+p:
      go(p, Nat.add(acc, digsum(i, Nat.is_lt(i, 10n))))

def main() -> IO(Unit):
  lim = Nat.mul(2000n, 1000n)
  r = go(lim, 0n)
  IO.print(Nat.show(r))
