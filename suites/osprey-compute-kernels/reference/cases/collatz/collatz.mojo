# Collatz (3n+1) stopping time summed over 1..N — integer division (n/2) in deep recursion.
def collatz(n: Int) -> Int:
    if n == 1:
        return 0
    elif n % 2 == 0:
        return 1 + collatz(n / 2)
    else:
        return 1 + collatz(3 * n + 1)

def main():
    var acc: Int = 0
    var i: Int = 1
    while i < 100001:
        acc += collatz(i)
        i += 1
    print(acc)
