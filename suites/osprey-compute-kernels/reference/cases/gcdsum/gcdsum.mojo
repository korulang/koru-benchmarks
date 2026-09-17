# Sum of gcd(i, K) for i in 1..N — Euclidean-algorithm recursion (modulo heavy).
def gcd(a: Int, b: Int) -> Int:
    if b == 0:
        return a
    return gcd(b, a % b)

def main():
    var acc: Int = 0
    var i: Int = 1
    while i < 2000000:
        acc += gcd(i, 1234567)
        i += 1
    print(acc)
