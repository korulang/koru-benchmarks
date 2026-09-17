# Ackermann–Péter function — deep, non-tail mutual self-recursion.
def add(a: Int, b: Int) -> Int:
    return a + b

def sub(a: Int, b: Int) -> Int:
    return a - b

def ack(m: Int, n: Int) -> Int:
    if m == 0:
        return add(n, 1)
    elif n == 0:
        return ack(sub(m, 1), 1)
    else:
        return ack(sub(m, 1), ack(m, sub(n, 1)))

def main():
    print(ack(3, 10))
