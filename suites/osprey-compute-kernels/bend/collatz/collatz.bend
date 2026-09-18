# Bend 2 port of the Osprey compute-kernel reference (see reference/cases).
# Faithful naive algorithm; oracle-gated by expected.txt.
# caveat: @unsafe — collatz halving/tripling is not a match-exposed decrease,
# so the termination checker cannot prove it (same class as tak).

import Base

@unsafe
def coll(+n: Nat, even: Bool) -> Nat:
  match n:
    case 0n:
      0n
    case 1n:
      0n
    case 2n+pp:
      match even:
        case True{}:
          Nat.add(1n, coll(Nat.div(n, 2n), Nat.is_eq(Nat.mod(n, 4n), 0n)))
        case False{}:
          m = Nat.add(Nat.mul(3n, n), 1n)
          Nat.add(1n, coll(m, True{}))

def collatz(+n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n:
      0n
    case 2n+pp:
      coll(n, Nat.is_eq(Nat.mod(n, 2n), 0n))

def go(+i: Nat, acc: Nat) -> Nat:
  match i:
    case 0n:
      acc
    case 1n+p:
      go(p, Nat.add(acc, collatz(i)))

def main() -> IO(Unit):
  lim = Nat.mul(100n, 1000n)
  r = go(lim, 0n)
  IO.print(Nat.show(r))
