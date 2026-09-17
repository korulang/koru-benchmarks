# Factorial-style product 1*2*...*N taken mod 1000000007 (matches factorial.osp).
def main():
    var MOD: Int = 1000000007
    var acc: Int = 1
    var i: Int = 1
    while i <= 10000000:
        acc = (acc * i) % MOD
        i += 1
    print(acc)
