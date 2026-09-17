# Sum of integer square roots over 1..N — Newton's method, integer division heavy.
def isqrt(n: Int) -> Int:
    if n < 2:
        return n
    var x = n
    while True:
        var y = (x + n / x) / 2
        if y < x:
            x = y
        else:
            return x

def main():
    var acc: Int = 0
    var i: Int = 1
    while i < 1000001:
        acc += isqrt(i)
        i += 1
    print(acc)
