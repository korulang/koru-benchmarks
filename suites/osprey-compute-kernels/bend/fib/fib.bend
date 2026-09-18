# fib — naive recursive Fibonacci, fib(35). Faithful port of
# reference/cases/fib (oracle 9227465). Sequential: nested match exposes
# n-1 and n-2; +n keeps the scrutinee reusable so `match p` doesn't
# consume it. Checks clean (no @unsafe).

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
          a = fib(p)
          b = fib(pp)
          Nat.add(a, b)

def main() -> IO(Unit):
  r = fib(35n)
  IO.print(Nat.show(r))
