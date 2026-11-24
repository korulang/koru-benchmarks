/* Expert C comparator for the same Takeuchi recurrence. No memoization or
 * algorithmic simplification. The outermost self-call is tail-recursive, so
 * it is written as a loop; the three argument recurrences remain recursive. */
#include <stdio.h>
#include <stdint.h>

static int64_t tak(int64_t x, int64_t y, int64_t z) {
    while (x > y) {
        int64_t t1 = tak(x - 1, y, z);
        int64_t t2 = tak(y - 1, z, x);
        int64_t t3 = tak(z - 1, x, y);
        x = t1; y = t2; z = t3;
    }
    return z;
}

int main(void) {
    printf("%lld\n", (long long)tak(32, 16, 8));
    return 0;
}
