# Bend 2 fork/join variant of the Osprey compute-kernel reference.
# 8-way split over the 200k index range; per-chunk C8 counts merged
# fieldwise. Reference counts array indices, so the honest shape is a record.
# caveat: no stdin in Bend IO; seed fixed to 1 (the reference's mode-0 path).

import Base

type C8 is Data:
  C8{c0: Nat, c1: Nat, c2: Nat, c3: Nat, c4: Nat, c5: Nat, c6: Nat, c7: Nat}

def A() -> Nat:
  Nat.mul(49n, 343n)

def P() -> Nat:
  Nat.sub(Nat.mul(Nat.mul(1024n, 1024n), 2048n), 1n)

def r1(x: Nat) -> Nat:
  Nat.mod(Nat.mul(x, A()), P())

def hashAt(+seed: Nat, i: Nat) -> Nat:
  r1(r1(Nat.add(seed, i)))

def inc(+m: C8, +k: Nat) -> C8:
  match m:
    case C8{+c0, +c1, +c2, +c3, +c4, +c5, +c6, +c7}:
      match k:
        case 0n:
          C8{Nat.add(c0, 1n), c1, c2, c3, c4, c5, c6, c7}
        case 1n:
          C8{c0, Nat.add(c1, 1n), c2, c3, c4, c5, c6, c7}
        case 2n:
          C8{c0, c1, Nat.add(c2, 1n), c3, c4, c5, c6, c7}
        case 3n:
          C8{c0, c1, c2, Nat.add(c3, 1n), c4, c5, c6, c7}
        case 4n:
          C8{c0, c1, c2, c3, Nat.add(c4, 1n), c5, c6, c7}
        case 5n:
          C8{c0, c1, c2, c3, c4, Nat.add(c5, 1n), c6, c7}
        case 6n:
          C8{c0, c1, c2, c3, c4, c5, Nat.add(c6, 1n), c7}
        case 1n+p:
          C8{c0, c1, c2, c3, c4, c5, c6, Nat.add(c7, 1n)}

def c8add(+x: C8, +y: C8) -> C8:
  match x:
    case C8{+a0, +a1, +a2, +a3, +a4, +a5, +a6, +a7}:
      match y:
        case C8{+b0, +b1, +b2, +b3, +b4, +b5, +b6, +b7}:
          C8{Nat.add(a0, b0), Nat.add(a1, b1), Nat.add(a2, b2), Nat.add(a3, b3),
             Nat.add(a4, b4), Nat.add(a5, b5), Nat.add(a6, b6), Nat.add(a7, b7)}

def go(+n: Nat, +i: Nat, +seed: Nat, m: C8) -> C8:
  match n:
    case 0n:
      m
    case 1n+p:
      go(p, Nat.sub(i, 1n), seed, inc(m, Nat.mod(hashAt(seed, i), 8n)))

def psum(+k: Nat, +n: Nat, +i: Nat, +seed: Nat) -> C8:
  match k:
    case 0n:
      go(n, i, seed, C8{0n, 0n, 0n, 0n, 0n, 0n, 0n, 0n})
    case 1n+kp:
      a b = psum(kp, Nat.sub(n, Nat.div(n, 2n)), i, seed)  psum(kp, Nat.div(n, 2n), Nat.sub(i, Nat.sub(n, Nat.div(n, 2n))), seed)
      c8add(a, b)

def wsum(+m: C8) -> Nat:
  match m:
    case C8{+c0, +c1, +c2, +c3, +c4, +c5, +c6, +c7}:
      Nat.add(Nat.mul(1n, c0), Nat.add(Nat.mul(2n, c1), Nat.add(Nat.mul(3n, c2),
      Nat.add(Nat.mul(4n, c3), Nat.add(Nat.mul(5n, c4), Nat.add(Nat.mul(6n, c5),
      Nat.add(Nat.mul(7n, c6), Nat.mul(8n, c7))))))))

def main() -> IO(Unit):
  IO.print(Nat.show(wsum(psum(3n, Nat.mul(200n, 1000n), Nat.sub(Nat.mul(200n, 1000n), 1n), 1n))))
