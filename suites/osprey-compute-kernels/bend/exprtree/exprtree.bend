# Bend 2 port of the Osprey compute-kernel reference (see reference/cases).
# Faithful naive algorithm; oracle-gated by expected.txt.
# caveat: Bend Nat is a 48-bit immediate; (a*b) mod 1e9+7 overflows it, so
# the product is emulated by a 30-step doubling mulmod — same result, ~30x ops.
# caveat: no stdin in Bend IO; seed fixed to 1 (the reference's mode-0 path).

import Base

type Expr is Data:
  Lit{v: Nat}
  Add{l: Expr, r: Expr}
  Mul{l: Expr, r: Expr}

def A() -> Nat:
  Nat.mul(49n, 343n)

def P() -> Nat:
  Nat.sub(Nat.mul(Nat.mul(1024n, 1024n), 2048n), 1n)

def MD() -> Nat:
  Nat.add(Nat.mul(Nat.mul(1000n, 1000n), 1000n), 7n)

def r1(x: Nat) -> Nat:
  Nat.mod(Nat.mul(x, A()), P())

def hashAt(+seed: Nat, i: Nat) -> Nat:
  r1(r1(Nat.add(seed, i)))

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

def addM(a: Nat, b: Nat) -> Nat:
  Nat.mod(Nat.add(a, b), MD())

def mulM(a: Nat, b: Nat) -> Nat:
  mulmod(a, b, MD())

def build(+depth: Nat, +seed: Nat, +idx: Nat, which: Nat) -> Expr:
  match depth:
    case 0n:
      Lit{Nat.mod(hashAt(seed, idx), 1000n)}
    case 1n+p:
      match which:
        case 0n:
          Add{build(p, seed, Nat.add(Nat.mul(idx, 2n), 1n), Nat.mod(hashAt(seed, Nat.add(Nat.mul(idx, 2n), 1n)), 2n)),
              build(p, seed, Nat.add(Nat.mul(idx, 2n), 2n), Nat.mod(hashAt(seed, Nat.add(Nat.mul(idx, 2n), 2n)), 2n))}
        case 1n+w:
          Mul{build(p, seed, Nat.add(Nat.mul(idx, 2n), 1n), Nat.mod(hashAt(seed, Nat.add(Nat.mul(idx, 2n), 1n)), 2n)),
              build(p, seed, Nat.add(Nat.mul(idx, 2n), 2n), Nat.mod(hashAt(seed, Nat.add(Nat.mul(idx, 2n), 2n)), 2n))}

def eval(e: Expr) -> Nat:
  match e:
    case Lit{v}:
      v
    case Add{l, r}:
      addM(eval(l), eval(r))
    case Mul{l, r}:
      mulM(eval(l), eval(r))

def runOne(+seed: Nat, +t: Nat) -> Nat:
  eval(build(14n, Nat.add(seed, Nat.mul(t, 7n)), 1n,
             Nat.mod(hashAt(Nat.add(seed, Nat.mul(t, 7n)), 1n), 2n)))

def go(+t: Nat, +seed: Nat, acc: Nat) -> Nat:
  match t:
    case 0n:
      addM(acc, runOne(seed, 0n))
    case 1n+p:
      go(p, seed, addM(acc, runOne(seed, t)))

def main() -> IO(Unit):
  r = go(9n, 1n, 0n)
  IO.print(Nat.show(r))
