# Binomial coefficient via naive (un-memoised) Pascal recursion C(n,k)=C(n-1,k-1)+C(n-1,k).
def binom(n: Int, k: Int) -> Int:
    if k == 0:
        return 1
    elif k == n:
        return 1
    return binom(n - 1, k - 1) + binom(n - 1, k)

def main():
    print(binom(27, 13))
