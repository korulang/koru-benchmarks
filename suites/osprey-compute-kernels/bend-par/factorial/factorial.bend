# Bend 2 fork/join variant of the Osprey compute-kernel reference.
# 8-way range split; partial products combined by mulmod.
# caveat: 48-bit Nat — products emulated by 30-step doubling mulmod.

import Base

def MD() -> Nat:
  Nat.add(Nat.mul(Nat.mul(1000n, 1000n), 1000n), 7n)

def mm(+k: Nat, +a: Nat, +b: Nat, +m: Nat, r: Nat, odd: Bool) -> Nat:
  match k:
    case 0n:
      r
    case 1n+kp:
      match odd:
        case True{}:
          mm(kp, Nat.mod(Nat.add(a, a), m), Nat.div(b, 2n), m,
             Nat.mod(Nat.add(r, a), m), Nat.is_eq(Nat.mod(Nat.div(b, 2n), 2n), 1n))
        case False{}:
          mm(kp, Nat.mod(Nat.add(a, a), m), Nat.div(b, 2n), m,
             r, Nat.is_eq(Nat.mod(Nat.div(b, 2n), 2n), 1n))

def mulmod(a: Nat, +b: Nat, +m: Nat) -> Nat:
  mm(30n, Nat.mod(a, m), b, m, 0n, Nat.is_eq(Nat.mod(b, 2n), 1n))

def go(+n: Nat, +i: Nat, acc: Nat) -> Nat:
  match n:
    case 0n:
      acc
    case 1n+p:
      go(p, Nat.sub(i, 1n), mulmod(acc, i, MD()))

def psum(+k: Nat, +n: Nat, +i: Nat) -> Nat:
  match k:
    case 0n:
      go(n, i, 1n)
    case 1n+kp:
      a b = psum(kp, Nat.sub(n, Nat.div(n, 2n)), i)  psum(kp, Nat.div(n, 2n), Nat.sub(i, Nat.sub(n, Nat.div(n, 2n))))
      mulmod(a, b, MD())

def main() -> IO(Unit):
  r = psum(3n, Nat.mul(10n, Nat.mul(1000n, 1000n)), Nat.mul(10n, Nat.mul(1000n, 1000n)))
  IO.print(Nat.show(r))
