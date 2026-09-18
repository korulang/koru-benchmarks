# binarytrees — build + checksum 1200 trees of depth 13 (oracle
# 19659600). Faithful port: recursive ADT `Tree`, `make` recurses on
# match-exposed p, `go` is the range-fold as a countdown (tail call
# compiles to a loop). Checks clean.

import Base

type Tree is Data:
  Leaf{}
  Node{l: Tree, r: Tree}

def make(+d: Nat) -> Tree:
  match d:
    case 0n:
      Node{Leaf{}, Leaf{}}
    case 1n+p:
      Node{make(p), make(p)}

def check(t: Tree) -> Nat:
  match t:
    case Leaf{}:
      0n
    case Node{l, r}:
      Nat.add(1n, Nat.add(check(l), check(r)))

def go(+i: Nat, acc: Nat) -> Nat:
  match i:
    case 0n:
      acc
    case 1n+p:
      go(p, Nat.add(acc, check(make(13n))))

def main() -> IO(Unit):
  IO.print(Nat.show(go(1200n, 0n)))
