/* Expert-C comparator: arena-backed memory design; same tree construction/check workload, honest bulk lifetime management. */
/* Allocate + traverse many short-lived binary trees — ARENA variant.
 * Same algorithm as binarytrees.c (build 1200 trees of depth 13, sum checks,
 * oracle 19659600) but the memory strategy matches arena-based ports: one
 * backing store allocated once for the worst-case tree, nodes bump-allocated
 * into it, and the bump pointer reset per iteration instead of per-node
 * malloc/free. This is the honest like-for-like comparator for ports whose
 * runtime model is arena/grid-backed (Koru's flat-arena port) — the malloc
 * original measures a memory protocol, not codegen. */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

typedef struct Tree {
    struct Tree *left;
    struct Tree *right;
} Tree;

/* depth-13 perfect tree: 2^14 - 1 = 16383 nodes */
#define ARENA_NODES 16384
static Tree arena[ARENA_NODES];
static size_t arena_used;

static Tree *make(int64_t d) {
    Tree *t = &arena[arena_used++];
    if (d == 0) {
        t->left = NULL;
        t->right = NULL;
    } else {
        t->left = make(d - 1);
        t->right = make(d - 1);
    }
    return t;
}

static int64_t check(const Tree *t) {
    if (t == NULL) {
        return 0;
    }
    return 1 + check(t->left) + check(t->right);
}

int main(void) {
    int64_t acc = 0;
    for (int64_t i = 0; i < 1200; i++) {
        arena_used = 0;
        Tree *t = make(13);
        acc += check(t);
        /* no per-node free: bump pointer resets next iteration */
    }
    printf("%lld\n", (long long)acc);
    return 0;
}
