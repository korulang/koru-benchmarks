# Bend 2 fork/join variant of the Osprey compute-kernel reference.
# 8-way range split over i; each chunk seeds its own gcd==1 entry flag.
# caveat: @unsafe — gcd(b, a%b) is not a match-exposed decrease.

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

def loopI(+n: Nat, +i: Nat, +hi: Nat, acc: Nat) -> Nat:
  match n:
    case 0n:
      acc
    case 1n+ip:
      c0 = Nat.is_eq(gcd(i, hi), 1n)
      loopI(ip, Nat.sub(i, 1n), hi, loopJ(i, hi, acc, c0))

def psum(+k: Nat, +n: Nat, +i: Nat, +hi: Nat) -> Nat:
  match k:
    case 0n:
      loopI(n, i, hi, 0n)
    case 1n+kp:
      a b = psum(kp, Nat.sub(n, Nat.div(n, 2n)), i, hi)  psum(kp, Nat.div(n, 2n), Nat.sub(i, Nat.sub(n, Nat.div(n, 2n))), hi)
      Nat.add(a, b)

def main() -> IO(Unit):
  r = psum(3n, 2000n, 2000n, 2000n)
  IO.print(Nat.show(r))
