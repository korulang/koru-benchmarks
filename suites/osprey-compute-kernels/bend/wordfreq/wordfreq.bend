# Bend 2 port of the Osprey compute-kernel reference (see reference/cases).
# Faithful naive algorithm; oracle-gated by expected.txt.
# note: the reference counts array indices 0..7 (its vocab is `(void)`-unused),
# so the honest shape is an 8-field record, not a string-keyed map.
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

def go(+i: Nat, +seed: Nat, m: C8) -> C8:
  match i:
    case 0n:
      m
    case 1n+p:
      go(p, seed, inc(m, Nat.mod(hashAt(seed, p), 8n)))

def wsum(+m: C8) -> Nat:
  match m:
    case C8{+c0, +c1, +c2, +c3, +c4, +c5, +c6, +c7}:
      Nat.add(Nat.mul(1n, c0), Nat.add(Nat.mul(2n, c1), Nat.add(Nat.mul(3n, c2),
      Nat.add(Nat.mul(4n, c3), Nat.add(Nat.mul(5n, c4), Nat.add(Nat.mul(6n, c5),
      Nat.add(Nat.mul(7n, c6), Nat.mul(8n, c7))))))))

def main() -> IO(Unit):
  lim = Nat.mul(200n, 1000n)
  IO.print(Nat.show(wsum(go(lim, 1n, C8{0n, 0n, 0n, 0n, 0n, 0n, 0n, 0n}))))
