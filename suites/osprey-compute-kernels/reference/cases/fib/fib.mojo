# Naive recursive Fibonacci — exercises raw function-call + recursion overhead.
def add(a: Int, b: Int) -> Int:
    return a + b

def sub(a: Int, b: Int) -> Int:
    return a - b

def fib(n: Int) -> Int:
    if n == 0:
        return 0
    elif n == 1:
        return 1
    return add(fib(sub(n, 1)), fib(sub(n, 2)))

def main():
    print(fib(35))
