/* Expert-C pilot comparator: same modular multiplication count; four independent congruence-class accumulators expose ILP, then combine exactly.
 * No memoization, mathematical pruning, or algorithmic replacement. */
#include <stdio.h>
#include <stdint.h>
#define P 1000000007ULL
static inline uint64_t mulmod(uint64_t a,uint64_t b){return (a*b)%P;}
int main(void){
 uint64_t a0=1,a1=1,a2=1,a3=1; int64_t i=1;
 for(;i+3<=10000000;i+=4){
  a0=mulmod(a0,i); a1=mulmod(a1,i+1); a2=mulmod(a2,i+2); a3=mulmod(a3,i+3);
 }
 for(;i<=10000000;i++) a0=mulmod(a0,i);
 printf("%llu\n",(unsigned long long)mulmod(mulmod(a0,a1),mulmod(a2,a3)));
}
