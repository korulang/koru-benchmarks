/* Expert-C pilot comparator: Newton iteration retained exactly; independent outer evaluations interleaved for ILP.
 * No memoization, mathematical pruning, or algorithmic replacement. */
#include <stdio.h>
#include <stdint.h>
static inline int64_t isqrt(int64_t n){if(n<2)return n;int64_t x=n;for(;;){int64_t y=(x+n/x)/2;if(y<x)x=y;else return x;}}
int main(void){int64_t a0=0,a1=0,a2=0,a3=0;int64_t i=1;
 for(;i+3<1000001;i+=4){a0+=isqrt(i);a1+=isqrt(i+1);a2+=isqrt(i+2);a3+=isqrt(i+3);}
 for(;i<1000001;i++)a0+=isqrt(i);
 printf("%lld\n",(long long)(a0+a1+a2+a3));}
