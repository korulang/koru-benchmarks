/* Word-frequency count over a tiny vocab — exercises hashing + counting.
 * HONEST-hash column: the same naive algorithm as wordfreq.c, but with real
 * Map<string,int> semantics — every token becomes a string key, hashed and
 * looked up in a chained hash table — so it pays what the kernel's own
 * description ("Map<string,int> + HAMT aggregation") implies. wordfreq.c cuts
 * this corner with a fixed counts[8] array keyed by bucket index; this file is
 * the fair comparator to the Rust/C3/Odin/Koru ports, which all hash strings.
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

#define MINSTD 16807
#define MODULUS 2147483647

static int64_t r1(int64_t x) { return (x * MINSTD) % MODULUS; }
static int64_t hash_at(int64_t s, int64_t i) { return r1(r1(s + i)); }

/* naive djb2 string hash */
static size_t str_hash(const char *s) {
    size_t h = 5381;
    while (*s) h = h * 33 + (unsigned char)*s++;
    return h;
}

/* naive chained hash map: string keys -> int64 counts */
#define NBINS 256
typedef struct Node { char key[16]; int64_t count; struct Node *next; } Node;
static Node *table[NBINS];

static void bump(const char *word) {
    size_t b = str_hash(word) % NBINS;
    for (Node *n = table[b]; n; n = n->next)
        if (strcmp(n->key, word) == 0) { n->count++; return; }
    Node *n = malloc(sizeof *n);
    strcpy(n->key, word); n->count = 1; n->next = table[b]; table[b] = n;
}
static int64_t get(const char *word) {
    size_t b = str_hash(word) % NBINS;
    for (Node *n = table[b]; n; n = n->next)
        if (strcmp(n->key, word) == 0) return n->count;
    return 0;
}

static int64_t read_seed(void) {
    char line[256]; int64_t m = 0;
    if (fgets(line, sizeof line, stdin) != NULL) {
        char *end = NULL;
        long long parsed = strtoll(line, &end, 10);
        if (end != line) m = (int64_t)parsed;
    }
    return m == 0 ? 1 : m; /* urandom reseed branch omitted — oracle feeds "0" -> 1 */
}

int main(void) {
    const char *vocab[8] = {"the", "quick", "brown", "fox",
                            "jumps", "over", "lazy", "dog"};
    int64_t seed = read_seed();
    for (int64_t i = 0; i < 200000; i++)
        bump(vocab[hash_at(seed, i) % 8]);
    int64_t result = 0;
    for (int k = 0; k < 8; k++) result += (k + 1) * get(vocab[k]);
    printf("%lld\n", (long long)result);
    return 0;
}
