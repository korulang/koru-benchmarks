# Bend 2 fork/join variant of the Osprey compute-kernel reference.
# forks the two ways() calls down to fork-depth 14, sequential below.
# caveat: @unsafe — ways() recursion is not structural; neg flag carries
# the reference's amount<0 arm (Bend has no negative Nat).

import Base

def coin(+k: Nat) -> Nat:
  match k:
    case 0n:
      50n
    case 1n:
      1n
    case 2n:
      5n
    case 3n:
      10n
    case 4n:
      25n
    case 1n+p:
      50n

@unsafe
def ways(neg: Bool, +amount: Nat, +kinds: Nat, +d: Nat) -> Nat:
  match neg:
    case True{}:
      0n
    case False{}:
      match amount:
        case 0n:
          1n
        case 1n+ap:
          match kinds:
            case 0n:
              0n
            case 1n+kp:
              match d:
                case 0n:
                  Nat.add(ways(Nat.is_lt(amount, coin(kinds)), Nat.sub(amount, coin(kinds)), kinds, 0n),
                          ways(False{}, amount, kp, 0n))
                case 1n+dp:
                  a b = ways(Nat.is_lt(amount, coin(kinds)), Nat.sub(amount, coin(kinds)), kinds, dp)
                        ways(False{}, amount, kp, dp)
                  Nat.add(a, b)

def main() -> IO(Unit):
  r = ways(False{}, 600n, 5n, 14n)
  IO.print(Nat.show(r))
