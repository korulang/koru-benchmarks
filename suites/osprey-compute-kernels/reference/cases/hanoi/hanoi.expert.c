/* Expert-C comparator: expert review retains the reference shape as canonical for this kernel.
 * No memoization, algebraic shortcut, recursion elimination, or benchmark-specific special case. */
#include <stdint.h>
#include <stdio.h>

int64_t hanoi(int64_t n, int64_t acc) {
    if (n == 0) {
        return acc;
    }
    return hanoi(n - 1, hanoi(n - 1, acc) + 1);
}

int main(void) {
    printf("%lld\n", (long long)hanoi(25, 0));
    return 0;
}
