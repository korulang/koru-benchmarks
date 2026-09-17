# Triple-nested counting loop accumulating (i*j*k) mod P — nested iteration.
def loop_k(i: Int, j: Int, k: Int, acc: Int) -> Int:
    var kk = k
    var a = acc
    var P: Int = 1000000007
    while kk != 0:
        a = (a + i * j * kk) % P
        kk -= 1
    return a

def loop_j(i: Int, j: Int, n: Int, acc: Int) -> Int:
    var jj = j
    var a = acc
    while jj != 0:
        a = loop_k(i, jj, n, a)
        jj -= 1
    return a

def loop_i(i: Int, n: Int, acc: Int) -> Int:
    var ii = i
    var a = acc
    while ii != 0:
        a = loop_j(ii, n, n, a)
        ii -= 1
    return a

def main():
    print(loop_i(250, 250, 0))
