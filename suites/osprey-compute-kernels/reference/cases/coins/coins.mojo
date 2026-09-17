def coin(k: Int) -> Int:
    if k == 1:
        return 1
    elif k == 2:
        return 5
    elif k == 3:
        return 10
    elif k == 4:
        return 25
    return 50

def ways(amount: Int, kind: Int) -> Int:
    if amount == 0:
        return 1
    elif amount < 0:
        return 0
    elif kind == 0:
        return 0
    else:
        return ways(amount - coin(kind), kind) + ways(amount, kind - 1)

def main():
    print(ways(600, 5))
