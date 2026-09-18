# Bend 2 fork/join variant of the Osprey compute-kernel reference.
# forks the two binom() calls down to fork-depth 8, sequential below —
# unchecked forking at ~20M-call scale detonates (see binarytrees-par).

import Base

def binom(+n: Nat, +k: Nat, +d: Nat) -> Nat:
  match n:
    case 0n:
      Bool.pick(Nat, Nat.is_eq(k, 0n), 1n, 0n)
    case 1n+p:
      match k:
        case 0n:
          1n
        case 1n+kp:
          match d:
            case 0n:
              Nat.add(binom(p, k, 0n), binom(p, kp, 0n))
            case 1n+dp:
              a b = binom(p, k, dp)  binom(p, kp, dp)
              Nat.add(a, b)

def main() -> IO(Unit):
  r = binom(27n, 13n, 8n)
  IO.print(Nat.show(r))
