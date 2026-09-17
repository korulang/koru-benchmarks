# Sum of modular exponentiation: sum of i^20 mod P for i in 1..N, naive repeated multiply.
def powmod(base: Int, e: Int, acc: Int) -> Int:
    var P: Int = 1000000007
    if e == 0:
        return acc
    return powmod(base, e - 1, (acc * base) % P)

def main():
    var P: Int = 1000000007
    var acc: Int = 0
    var i: Int = 1
    while i < 1000000:
        acc = (acc + powmod(i, 20, 1)) % P
        i += 1
    print(acc)
