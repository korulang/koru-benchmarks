/* Expert-C comparator: persistent linked-list data structure, unlike the
 * reference's contiguous-array artifact. Same generated values and reductions. */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#define MINSTD 16807
#define MODULUS 2147483647
#define BIG_MOD 1000000007
#define N 4000
typedef struct Node { int64_t v; struct Node *next; } Node;
static int64_t r1(int64_t x) { return (x * MINSTD) % MODULUS; }
static int64_t hash_at(int64_t s, int64_t i) { return r1(r1(s + i)); }
static int64_t read_seed(void) {
    char line[256]; int64_t m = 0;
    if (fgets(line, sizeof line, stdin) != NULL) { char *end = NULL; long long p = strtoll(line, &end, 10); if (end != line) m = (int64_t)p; }
    if (m == 0) return 1;
    uint64_t val = 0; FILE *f = fopen("/dev/urandom", "rb");
    if (f) { if (fread(&val, sizeof val, 1, f) != 1) val = 0; fclose(f); }
    return (int64_t)(val % 2147483646) + 1;
}
int main(void) {
    int64_t seed=read_seed(), acc=0;
    for (int64_t t=0;t<8;t++) {
        int64_t s=seed+t*131; Node *head=NULL;
        for (int64_t i=N-1;i>=0;i--) { Node *n=malloc(sizeof *n); n->v=hash_at(s,i)%1000; n->next=head; head=n; }
        int64_t sum=0,below=0;
        for (Node *n=head;n;n=n->next) { sum+=n->v; below += n->v < 500; }
        while (head) { Node *n=head->next; free(head); head=n; }
        acc=(acc+sum+below)%BIG_MOD;
    }
    printf("%lld\n",(long long)acc);
}
