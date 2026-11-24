/* Expert-C pilot comparator: Euclidean recursion lowered to iteration; nested pair enumeration unchanged.
 * No memoization, mathematical pruning, or algorithmic replacement. */
#include <stdio.h>
#include <stdint.h>
static inline int64_t gcd(int64_t a,int64_t b){while(b!=0){int64_t t=a%b;a=b;b=t;}return a;}
int main(void){int64_t n=2000,acc=0;
 for(int64_t i=n;i>0;i--)for(int64_t j=n;j>0;j--)if(gcd(i,j)==1)acc++;
 printf("%lld\n",(long long)acc);}
