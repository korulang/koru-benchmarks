# Bend 2 port of the Osprey compute-kernel reference (see reference/cases).
# Faithful naive algorithm; oracle-gated by expected.txt.
# caveat: Bend cannot match a local binder; the list fold carries (sum,below)
# as a Nat & Nat pair destructured via a param helper (pairSum).
# caveat: no stdin in Bend IO; seed fixed to 1 (the reference's mode-0 path).

import Base

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

def addM(a: Nat, b: Nat) -> Nat:
  Nat.mod(Nat.add(a, b), MD())

def bld(+c: Nat, +i: Nat, +s: Nat, xs: List<Nat>) -> List<Nat>:
  match c:
    case 0n:
      xs
    case 1n+p:
      bld(p, Nat.add(i, 1n), s, Con{Nat.mod(hashAt(s, i), 1000n), xs})

def sumBelow(xs: List<Nat>, acc: Nat & Nat) -> Nat & Nat:
  match xs:
    case Nil{}:
      acc
    case Con{+h, t}:
      (s, b) = acc
      sumBelow(t, (Nat.add(s, h), Nat.add(b, Bool.pick(Nat, Nat.is_lt(h, 500n), 1n, 0n))))

def pairSum(p: Nat & Nat) -> Nat:
  (sm, bw) = p
  Nat.add(sm, bw)

def runOne(+s: Nat) -> Nat:
  pairSum(sumBelow(bld(4000n, 0n, s, Nil{}), (0n, 0n)))

def go(+t: Nat, +seed: Nat, acc: Nat) -> Nat:
  match t:
    case 0n:
      addM(acc, runOne(seed))
    case 1n+p:
      go(p, seed, addM(acc, runOne(Nat.add(seed, Nat.mul(t, 131n)))))

def main() -> IO(Unit):
  r = go(7n, 1n, 0n)
  IO.print(Nat.show(r))
