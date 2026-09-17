from std.collections import Dict
from std.io import input
from std.io.file import open

def r1(x: Int) -> Int:
    return (x * 16807) % 2147483647

def hash_at(s: Int, i: Int) -> Int:
    return r1(r1(s + i))

def read_seed() -> Int:
    var m = 0
    try:
        m = Int(input().strip())
    except:
        m = 0
    if m == 0:
        return 1
    try:
        var f = open("/dev/urandom", "r")
        var bytes = f.read(8).as_bytes()
        var v: UInt64 = 0
        for i in range(8):
            v |= UInt64(bytes[i]) << UInt64(8 * i)
        return Int(v % 2147483646) + 1
    except:
        return 1

def main():
    var vocab = ["the", "quick", "brown", "fox", "jumps", "over", "lazy", "dog"]
    var seed = read_seed()
    var counts = Dict[String, Int]()
    for i in range(200000):
        var w = vocab[hash_at(seed, i) % 8]
        counts[w] = counts.get(w, 0) + 1
    var result: Int = 0
    for k in range(8):
        result += (k + 1) * counts.get(vocab[k], 0)
    print(result)
