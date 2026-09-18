# binarytrees — bend-par variant: `makep` forks the two subtree builds
# only above a depth cutoff (`cut`), falling back to sequential `make`
# below it — naive full-fork measured ~4x SLOWER (Tree values crossing
# the fork boundary). cut=4.

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

def makep(+cut: Nat, +d: Nat) -> Tree:
  match cut:
    case 0n:
      make(d)
    case 1n+cp:
      match d:
        case 0n:
          Node{Leaf{}, Leaf{}}
        case 1n+p:
          l r = makep(cp, p) makep(cp, p)
          Node{l, r}

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
      go(p, Nat.add(acc, check(makep(4n, 13n))))

def main() -> IO(Unit):
  IO.print(Nat.show(go(1200n, 0n)))
