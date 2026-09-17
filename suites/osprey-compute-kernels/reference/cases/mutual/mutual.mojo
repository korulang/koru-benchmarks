def is_even(n: Int) -> Bool:
    if n == 0:
        return True
    return is_odd(n - 1)

def is_odd(n: Int) -> Bool:
    if n == 0:
        return False
    return is_even(n - 1)

def main():
    var acc: Int = 0
    var i: Int = 1
    while i < 130000:
        if is_even(i % 1000):
            acc += 1
        i += 1
    print(acc)
