def hanoi(n: Int, acc: Int) -> Int:
    if n == 0:
        return acc
    return hanoi(n - 1, hanoi(n - 1, acc) + 1)

def main():
    print(hanoi(25, 0))
