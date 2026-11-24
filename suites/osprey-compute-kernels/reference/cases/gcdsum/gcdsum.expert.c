/* Expert-C pilot comparator: Euclidean recursion lowered to iteration; independent outer gcd evaluations interleaved for ILP.
 * No memoization, mathematical pruning, or algorithmic replacement. */
#include <stdio.h>
#include <stdint.h>
static inline int64_t gcd(int64_t a,int64_t b){while(b!=0){int64_t t=a%b;a=b;b=t;}return a;}
int main(void){int64_t a0=0,a1=0,a2=0,a3=0;int64_t i=1;
 for(;i+3<2000000;i+=4){a0+=gcd(i,1234567);a1+=gcd(i+1,1234567);a2+=gcd(i+2,1234567);a3+=gcd(i+3,1234567);}
 for(;i<2000000;i++)a0+=gcd(i,1234567);
 printf("%lld\n",(long long)(a0+a1+a2+a3));}
