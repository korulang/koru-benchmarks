# fib — bend-par variant: `a b = fib(p) fib(pp)` forks both recursive
# calls (balanced-fork contract). Same algorithm, oracle unchanged.

import Base

def fib(+n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n+p:
      match p:
        case 0n:
          1n
        case 1n+pp:
          a b = fib(p) fib(pp)
          Nat.add(a, b)

def main() -> IO(Unit):
  r = fib(35n)
  IO.print(Nat.show(r))
