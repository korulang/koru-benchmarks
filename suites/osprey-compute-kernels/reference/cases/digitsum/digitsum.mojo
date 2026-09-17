# Sum of decimal digit-sums over 1..N — integer division (n/10) and modulo in recursion.
def digsum(n: Int) -> Int:
    if n < 10:
        return n
    return n % 10 + digsum(n / 10)

def main():
    var acc: Int = 0
    var i: Int = 1
    while i < 2000001:
        acc += digsum(i)
        i += 1
    print(acc)
