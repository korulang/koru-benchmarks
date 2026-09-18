# Bend 2 port of the Osprey compute-kernel reference (see reference/cases).
# Faithful naive algorithm; oracle-gated by expected.txt.
# caveat: @unsafe — gcd(b, a%b) is not a match-exposed decrease.
# caveat: gcd==1 branch is a param flag (Bend cannot match a local binder).

import Base

@unsafe
def gcd(+a: Nat, +b: Nat) -> Nat:
  match b:
    case 0n:
      a
    case 1n+bp:
      gcd(b, Nat.mod(a, b))

def loopJ(+i: Nat, +j: Nat, acc: Nat, c: Bool) -> Nat:
  match j:
    case 0n:
      acc
    case 1n+jp:
      match c:
        case True{}:
          loopJ(i, jp, Nat.add(acc, 1n), Nat.is_eq(gcd(i, jp), 1n))
        case False{}:
          loopJ(i, jp, acc, Nat.is_eq(gcd(i, jp), 1n))

def loopI(+i: Nat, +n: Nat, acc: Nat) -> Nat:
  match i:
    case 0n:
      acc
    case 1n+ip:
      c0 = Nat.is_eq(gcd(i, n), 1n)
      loopI(ip, n, loopJ(i, n, acc, c0))

def main() -> IO(Unit):
  r = loopI(2000n, 2000n, 0n)
  IO.print(Nat.show(r))
