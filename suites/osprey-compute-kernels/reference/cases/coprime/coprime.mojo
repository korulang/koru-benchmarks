# Count coprime pairs (i,j), 1<=i,j<=N — nested iteration + Euclidean gcd.
def gcd(a: Int, b: Int) -> Int:
    if b == 0:
        return a
    return gcd(b, a % b)

def main():
    var n: Int = 2000
    var acc: Int = 0
    var i: Int = n
    while i > 0:
        var j: Int = n
        while j > 0:
            if gcd(i, j) == 1:
                acc += 1
            j -= 1
        i -= 1
    print(acc)
