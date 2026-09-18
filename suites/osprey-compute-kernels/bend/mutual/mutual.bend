# Bend 2 port of the Osprey compute-kernel reference (see reference/cases).
# Faithful naive algorithm; oracle-gated by expected.txt.
# note: is_even/is_odd mutual recursion is folded into eo(n, flag) — same
# semantics, one def (Bend has no forward references).
# caveat: the even-branch is a param flag (Bend cannot match a local binder).

import Base

def eo(+n: Nat, e: Bool) -> Bool:
  match n:
    case 0n:
      e
    case 1n+p:
      eo(p, Bool.not(e))

def go(+i: Nat, acc: Nat, e: Bool) -> Nat:
  match i:
    case 0n:
      acc
    case 1n+p:
      match e:
        case True{}:
          go(p, Nat.add(acc, 1n), eo(Nat.mod(p, 1000n), True{}))
        case False{}:
          go(p, acc, eo(Nat.mod(p, 1000n), True{}))

def main() -> IO(Unit):
  r = go(Nat.sub(Nat.mul(130n, 1000n), 1n), 0n,
         eo(Nat.mod(Nat.sub(Nat.mul(130n, 1000n), 1n), 1000n), True{}))
  IO.print(Nat.show(r))
