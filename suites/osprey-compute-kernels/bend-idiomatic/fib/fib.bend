# fib — naive recursive Fibonacci, fib(35). Faithful oracle-gated port.
# Idiomatic Bend: independent tree recursion is written with Bend's parallel
# call notation. No memoization or algebraic shortcut; both recursive branches
# are still evaluated.

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
