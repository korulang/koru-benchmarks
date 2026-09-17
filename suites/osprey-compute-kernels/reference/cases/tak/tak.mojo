def sub(a: Int, b: Int) -> Int:
    return a - b

def tak(x: Int, y: Int, z: Int) -> Int:
    if x > y:
        return tak(
            tak(sub(x, 1), y, z),
            tak(sub(y, 1), z, x),
            tak(sub(z, 1), x, y),
        )
    return z

def main():
    print(tak(32, 16, 8))
