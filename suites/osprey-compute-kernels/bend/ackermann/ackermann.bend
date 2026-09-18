# ackermann — Ackermann-Péter ack(3,10). Faithful port of
# reference/cases/ackermann (oracle 8189). Checks clean: the
# termination rule (args unchanged until one shrinks, rest free)
# accepts ack(mp, r) because mp shrinks first.

import Base

def ack(+m: Nat, +n: Nat) -> Nat:
  match m:
    case 0n:
      Nat.add(n, 1n)
    case 1n+mp:
      match n:
        case 0n:
          ack(mp, 1n)
        case 1n+np:
          r = ack(m, np)
          ack(mp, r)

def main() -> IO(Unit):
  r = ack(3n, 10n)
  IO.print(Nat.show(r))
