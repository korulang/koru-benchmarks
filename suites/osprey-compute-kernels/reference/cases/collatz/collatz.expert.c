/* Expert-C pilot comparator: stopping-time recursion lowered to iteration; independent outer trajectories interleaved for ILP.
 * No memoization, mathematical pruning, or algorithmic replacement. */
#include <stdio.h>
#include <stdint.h>
static inline int64_t collatz(int64_t n){int64_t s=0;while(n!=1){n=(n%2==0)?n/2:3*n+1;s++;}return s;}
int main(void){int64_t a0=0,a1=0,a2=0,a3=0;int64_t i=1;
 for(;i+3<100001;i+=4){a0+=collatz(i);a1+=collatz(i+1);a2+=collatz(i+2);a3+=collatz(i+3);}
 for(;i<100001;i++)a0+=collatz(i);
 printf("%lld\n",(long long)(a0+a1+a2+a3));}
