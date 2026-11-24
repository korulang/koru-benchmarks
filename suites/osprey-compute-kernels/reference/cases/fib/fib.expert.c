/* Expert C comparator for the same naive Fibonacci recurrence. No memoization,
 * no closed form, no iteration: every nontrivial node still evaluates both
 * recursive children. The only source-level change is an exact small-base-case
 * boundary (fib(2)=1) that removes degenerate frames for fib(1)/fib(0). */
#include <stdio.h>
#include <stdint.h>

static int64_t fib(int64_t n) {
    if (n < 2) return n;
    if (n == 2) return 1;
    return fib(n - 1) + fib(n - 2);
}

int main(void) {
    printf("%lld\n", (long long)fib(35));
    return 0;
}
