# Bend 2 port of the Osprey compute-kernel reference (see reference/cases).
# Faithful naive algorithm; oracle-gated by expected.txt.
# caveat: @unsafe — gcd(b, a%b) is not a match-exposed decrease.

import Base

@unsafe
def gcd(+a: Nat, +b: Nat) -> Nat:
  match b:
    case 0n:
      a
    case 1n+bp:
      gcd(b, Nat.mod(a, b))

def go(+i: Nat, acc: Nat) -> Nat:
  match i:
    case 0n:
      acc
    case 1n+p:
      k = Nat.add(Nat.mul(1234n, 1000n), 567n)
      go(p, Nat.add(acc, gcd(i, k)))

def main() -> IO(Unit):
  lim = Nat.sub(Nat.mul(2000n, 1000n), 1n)
  r = go(lim, 0n)
  IO.print(Nat.show(r))
