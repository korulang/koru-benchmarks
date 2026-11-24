/* Expert-C pilot comparator: trial-division recursion lowered to iteration; divisor enumeration unchanged.
 * No memoization, mathematical pruning, or algorithmic replacement. */
#include <stdio.h>
#include <stdint.h>
static inline int has_factor(int64_t n,int64_t d){while(d*d<=n){if(n%d==0)return 1;d++;}return 0;}
static inline int is_prime(int64_t n){return n>=2&&!has_factor(n,2);}
int main(void){int64_t acc=0;for(int64_t n=2;n<200000;n++)acc+=is_prime(n);printf("%lld\n",(long long)acc);}
