# Bend 2 port of the Osprey compute-kernel reference (see reference/cases).
# Faithful naive algorithm; oracle-gated by expected.txt.
# caveat: Bend Nat is a 48-bit immediate; acc*i overflows it, so the product
# is emulated by a 24-step doubling mulmod — same result, ~24x ops.

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
  mm(24n, Nat.mod(a, m), b, m, 0n, Nat.is_eq(Nat.mod(b, 2n), 1n))

def go(+i: Nat, acc: Nat) -> Nat:
  match i:
    case 0n:
      acc
    case 1n+p:
      go(p, mulmod(acc, i, MD()))

def main() -> IO(Unit):
  lim = Nat.mul(10n, Nat.mul(1000n, 1000n))
  r = go(lim, 1n)
  IO.print(Nat.show(r))
