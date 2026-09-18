# Bend 2 fork/join variant of the Osprey compute-kernel reference.
# 8-way split over the 200k index range.
# caveat: no stdin in Bend IO; seed fixed to 1 (the reference's mode-0 path).

import Base

def A() -> Nat:
  Nat.mul(49n, 343n)

def P() -> Nat:
  Nat.sub(Nat.mul(Nat.mul(1024n, 1024n), 2048n), 1n)

def r1(x: Nat) -> Nat:
  Nat.mod(Nat.mul(x, A()), P())

def hashAt(+seed: Nat, i: Nat) -> Nat:
  r1(r1(Nat.add(seed, i)))

def word(+k: Nat) -> String:
  match k:
    case 0n:
      "the"
    case 1n:
      "quick"
    case 2n:
      "brown"
    case 3n:
      "fox"
    case 4n:
      "jumps"
    case 5n:
      "over"
    case 6n:
      "lazy"
    case 1n+p:
      "dog"

def score(+w: String) -> Nat:
  Nat.add(Nat.add(String.length(w),
    Bool.pick(Nat, String.contains(w, "o"), 7n, 0n)),
    Bool.pick(Nat, String.starts_with(w, "t"), 3n, 0n))

def go(+n: Nat, +i: Nat, +seed: Nat, acc: Nat) -> Nat:
  match n:
    case 0n:
      acc
    case 1n+p:
      go(p, Nat.sub(i, 1n), seed,
         Nat.add(acc, score(word(Nat.mod(hashAt(seed, i), 8n)))))

def psum(+k: Nat, +n: Nat, +i: Nat, +seed: Nat) -> Nat:
  match k:
    case 0n:
      go(n, i, seed, 0n)
    case 1n+kp:
      a b = psum(kp, Nat.sub(n, Nat.div(n, 2n)), i, seed)  psum(kp, Nat.div(n, 2n), Nat.sub(i, Nat.sub(n, Nat.div(n, 2n))), seed)
      Nat.add(a, b)

def main() -> IO(Unit):
  r = psum(3n, Nat.mul(200n, 1000n), Nat.sub(Nat.mul(200n, 1000n), 1n), 1n)
  IO.print(Nat.show(r))
