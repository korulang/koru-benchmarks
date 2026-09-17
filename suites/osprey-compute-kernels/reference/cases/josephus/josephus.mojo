# Josephus problem — survivor index for n people, step k=7, via the modular recurrence.
def main():
    var acc: Int = 0
    var i: Int = 2
    while i < 10000001:
        acc = (acc + 7) % i
        i += 1
    print(acc)
