# Bend 2 port of the Osprey compute-kernel reference (see reference/cases).
# Faithful naive algorithm; oracle-gated by expected.txt.
# caveat: @unsafe — ways() recursion on amount-coin is not structural.
# Bend has no negative Nat: the reference's amount<0 arm is carried as an
# explicit `neg` flag computed at the call site (amount-coin would underflow).

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
def ways(neg: Bool, +amount: Nat, +kinds: Nat) -> Nat:
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
              a = ways(Nat.is_lt(amount, coin(kinds)), Nat.sub(amount, coin(kinds)), kinds)
              b = ways(False{}, amount, kp)
              Nat.add(a, b)

def main() -> IO(Unit):
  r = ways(False{}, 600n, 5n)
  IO.print(Nat.show(r))
