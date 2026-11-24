/* Expert C comparator for the same workload: naive repeated multiplication,
 * exponent 20, summed over i=1..999999. No exponentiation-by-squaring, no
 * memoization. Optimizations are representation-level only: fixed-modulus
 * multiply-high reduction emitted by the compiler, an unrolled straight-line exponent chain, and eight
 * independent partial sums to expose ILP. Modular addition is associative;
 * every pow20 chain still performs twenty multiplications in reference order. */
#include <stdio.h>
#include <stdint.h>

#define P 1000000007ULL
static inline uint64_t mulmod(uint64_t a, uint64_t b) {
    return (a * b) % P;
}

static inline uint64_t pow20_naive(uint64_t base) {
    uint64_t acc = 1;
    #pragma unroll
    for (int k = 0; k < 20; k++) {
        acc = mulmod(acc, base);
    }
    return acc;
}

int main(void) {
    uint64_t a0=0,a1=0,a2=0,a3=0,a4=0,a5=0,a6=0,a7=0;
    int64_t i = 1;
    for (; i + 7 < 1000000; i += 8) {
        a0 = (a0 + pow20_naive((uint64_t)i)) % P;
        a1 = (a1 + pow20_naive((uint64_t)i + 1)) % P;
        a2 = (a2 + pow20_naive((uint64_t)i + 2)) % P;
        a3 = (a3 + pow20_naive((uint64_t)i + 3)) % P;
        a4 = (a4 + pow20_naive((uint64_t)i + 4)) % P;
        a5 = (a5 + pow20_naive((uint64_t)i + 5)) % P;
        a6 = (a6 + pow20_naive((uint64_t)i + 6)) % P;
        a7 = (a7 + pow20_naive((uint64_t)i + 7)) % P;
    }
    for (; i < 1000000; i++) {
        a0 = (a0 + pow20_naive((uint64_t)i)) % P;
    }
    printf("%llu\n", (unsigned long long)((a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7) % P));
    return 0;
}
