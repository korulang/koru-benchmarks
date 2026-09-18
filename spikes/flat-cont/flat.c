// BendRT-shaped flat evaluator, hand-written minimal prototype.
// Every "function" is a preserve_none segment; calls are musttail jumps;
// continuations are lanes on an explicit stack; results ride r0.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef uint64_t u64;
typedef struct { u64 fid, w0, w1, w2; } Lane;
typedef u64 (Seg)(Lane *sp, u64 r0, u64 r1, u64 r2) __attribute__((preserve_none));

#define SEG  static __attribute__((noinline, preserve_none)) u64
#define TAIL __attribute__((musttail)) return

static Lane *STK;

SEG f_done(Lane *sp, u64 r0, u64 r1, u64 r2) {
  return r0;                       // unwind the whole chain to main
}

/* ── ack(m, n) ─────────────────────────────────────────────── */
SEG f_ack(Lane *sp, u64 r0, u64 r1, u64 r2);
SEG f_ack_k(Lane *sp, u64 r0, u64 r1, u64 r2);

SEG f_ack(Lane *sp, u64 r0, u64 r1, u64 r2) {
  if (r0 == 0) {                    // m == 0 → return n + 1
    Lane *f = --sp;
    TAIL ((Seg*)f->fid)(sp, r1 + 1, r1, r2);
  }
  if (r1 == 0) {                    // n == 0 → tail call ack(m-1, 1)
    TAIL f_ack(sp, r0 - 1, 1, r2);
  }
  sp->fid = (u64)f_ack_k;           // push continuation [K, m]
  sp->w0  = r0;
  ++sp;
  TAIL f_ack(sp, r0, r1 - 1, r2);   // non-tail call ack(m, n-1)
}

SEG f_ack_k(Lane *sp, u64 r0, u64 r1, u64 r2) {
  u64 m = sp->w0;                   // continuation frame sits at sp
  TAIL f_ack(sp, m - 1, r0, r2); // → ack(m-1, inner)
}

/* ── hanoi(n, acc) = hanoi(n-1, hanoi(n-1,acc)+1) ───────────── */
SEG f_hanoi(Lane *sp, u64 r0, u64 r1, u64 r2);
SEG f_hanoi_k(Lane *sp, u64 r0, u64 r1, u64 r2);

SEG f_hanoi(Lane *sp, u64 r0, u64 r1, u64 r2) {
  if (r0 == 0) {
    Lane *f = --sp;
    TAIL ((Seg*)f->fid)(sp, r1, r1, r2);    // return acc
  }
  sp->fid = (u64)f_hanoi_k;
  sp->w0  = r0 - 1;                 // save p
  ++sp;
  TAIL f_hanoi(sp, r0 - 1, r1, r2); // inner hanoi(p, acc)
}

SEG f_hanoi_k(Lane *sp, u64 r0, u64 r1, u64 r2) {
  u64 p = sp->w0;
  TAIL f_hanoi(sp, p, r0 + 1, r2); // hanoi(p, inner+1)
}

int main(int argc, char **argv) {
  STK = malloc(sizeof(Lane) << 26);
  STK[0].fid = (u64)f_done;
  u64 which = argc > 1 ? strtoull(argv[1], 0, 10) : 0;
  if (which == 0) {
    printf("%llu\n", f_ack(STK + 1, 3, 10, 0));
  } else {
    printf("%llu\n", f_hanoi(STK + 1, 25, 0, 0));
  }
  return 0;
}
