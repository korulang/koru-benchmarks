/* Expert-C pilot comparator: recursive helper structure flattened to direct counted loops; trip count and arithmetic unchanged.
 * No memoization, mathematical pruning, or algorithmic replacement. */
#include <stdio.h>
#include <stdint.h>
#define P 1000000007LL
int main(void){int64_t acc=0;
 for(int64_t i=250;i!=0;i--)for(int64_t j=250;j!=0;j--)for(int64_t k=250;k!=0;k--)acc=(acc+i*j*k)%P;
 printf("%lld\n",(long long)acc);}
