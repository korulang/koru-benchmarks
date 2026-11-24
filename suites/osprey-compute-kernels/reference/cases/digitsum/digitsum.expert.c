/* Expert-C pilot comparator: digit recursion lowered to iteration; independent outer digit sums interleaved for ILP.
 * No memoization, mathematical pruning, or algorithmic replacement. */
#include <stdio.h>
#include <stdint.h>
static inline int64_t digsum(int64_t n){int64_t s=0;while(n>=10){s+=n%10;n/=10;}return s+n;}
int main(void){int64_t a0=0,a1=0,a2=0,a3=0;int64_t i=1;
 for(;i+3<2000001;i+=4){a0+=digsum(i);a1+=digsum(i+1);a2+=digsum(i+2);a3+=digsum(i+3);}
 for(;i<2000001;i++)a0+=digsum(i);
 printf("%lld\n",(long long)(a0+a1+a2+a3));}
