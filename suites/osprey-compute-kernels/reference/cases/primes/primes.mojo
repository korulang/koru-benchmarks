# Count primes below a limit by trial division — integer % in a tight loop.
def has_factor(n: Int, d: Int) -> Bool:
    if d * d > n:
        return False
    elif n % d == 0:
        return True
    return has_factor(n, d + 1)

def is_prime(n: Int) -> Bool:
    if n < 2:
        return False
    return not has_factor(n, 2)

def main():
    var acc: Int = 0
    var n: Int = 2
    while n < 200000:
        if is_prime(n):
            acc += 1
        n += 1
    print(acc)
