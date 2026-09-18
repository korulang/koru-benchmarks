# Bend 2 port of the Osprey compute-kernel reference (see reference/cases).
# Faithful naive algorithm; oracle-gated by expected.txt.
# caveat: Bend Nat is a 48-bit immediate; acc*base overflows it, so the product
# is emulated by a 20-step doubling mulmod — same result, ~20x ops.

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
  mm(20n, Nat.mod(a, m), b, m, 0n, Nat.is_eq(Nat.mod(b, 2n), 1n))

def pm(+b: Nat, +e: Nat, acc: Nat) -> Nat:
  match e:
    case 0n:
      acc
    case 1n+ep:
      pm(b, ep, mulmod(acc, b, MD()))

def go(+i: Nat, acc: Nat) -> Nat:
  match i:
    case 0n:
      acc
    case 1n+p:
      go(p, Nat.mod(Nat.add(acc, pm(i, 20n, 1n)), MD()))

def main() -> IO(Unit):
  lim = Nat.sub(Nat.mul(1000n, 1000n), 1n)
  r = go(lim, 0n)
  IO.print(Nat.show(r))
