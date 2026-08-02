#!/usr/bin/env python3
"""ab_codegen — compare a Koru port built against TWO revisions of the stdlib.

The board's timing runner cannot resolve a 10% effect. It runs every port once
per process-run and repeats the whole board, so the two sides of a before/after
comparison are minutes apart on a machine shared with everything else. On
2026-08-02 that produced a clean-looking 1.12x that was entirely drift: the
UNTOUCHED query-path control moved by the same factor.

Two instruments, in the order they should be reached for:

  1. CODEGEN DIFF (`--diff-only`). Build the port both ways, disassemble both
     binaries, diff. Identical assembly cannot run at different speeds — that
     is a proof, not a measurement, and it costs two compiles and no quiet
     machine. It retired a scheduled 3.91x rung in one call. Reach for this
     FIRST, always: if the codegen is identical there is nothing to time, and
     if it differs you have already read what changed.

  2. INTERLEAVED TIMING. Only when the codegen genuinely differs. Alternate
     the two binaries inside ONE loop (A,B / B,A / A,B ...) so both sides see
     the same second of machine conditions, and report medians and mins.
     Measured noise floor on byte-identical binaries: 1.000x. The same
     instrument reads 1.09x for a three-instruction change, so it resolves
     effects the board's protocol cannot see at all.

Usage:
    ab_codegen.py <port> --a <rev-or-path> --b <rev-or-path> [--reps N] [--diff-only]

<port> is a name under koru/*/, e.g. rf_stripe_1. A rev is anything
`git show <rev>:koru_std/store.kz` accepts, or a path to a stdlib file.
The working tree's koru_std/store.kz is restored on exit.
"""
import argparse, os, re, shutil, statistics, subprocess, sys, tempfile

KORU = os.path.expanduser("~/src/koru")
STDLIB = os.path.join(KORU, "koru_std/store.kz")
SUITE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KORUC = os.environ.get("KORUC", "/usr/local/bin/koruc")


def resolve_stdlib(rev: str, dest: str) -> str:
    """A filesystem path is taken as-is; anything else is a git rev in koru."""
    if os.path.exists(rev):
        shutil.copy(rev, dest)
    else:
        with open(dest, "w") as fh:
            subprocess.run(["git", "show", f"{rev}:koru_std/store.kz"],
                           cwd=KORU, stdout=fh, check=True)
    return dest


def find_port(name: str) -> str:
    for entry in os.listdir(os.path.join(SUITE, "koru")):
        src = os.path.join(SUITE, "koru", entry, f"{name}.k")
        if os.path.isfile(src):
            return src
    sys.exit(f"no port named {name} under {SUITE}/koru/*/")


def build(port_src: str, stdlib: str, outdir: str) -> str:
    shutil.copy(stdlib, STDLIB)
    os.makedirs(outdir, exist_ok=True)
    shutil.copy(port_src, os.path.join(outdir, "prog.k"))
    r = subprocess.run([KORUC, "build", "prog.k"], cwd=outdir, capture_output=True, text=True)
    exe = os.path.join(outdir, "a.out")
    if not os.access(exe, os.X_OK):
        sys.exit(f"build failed in {outdir}:\n{r.stdout[-2000:]}{r.stderr[-2000:]}")
    return exe


def disasm(exe: str) -> list[str]:
    """Instruction stream with the address column stripped.

    Addresses shift whenever anything upstream changes size, which would make
    every diff total the whole binary. What the question actually asks is
    whether the compiler emitted different WORK, so compare mnemonics and
    operands only.
    """
    out = subprocess.run(["otool", "-tV", exe], capture_output=True, text=True).stdout
    # drop the header line (it names the path) and the leading hex address
    return [re.sub(r"^[0-9a-f]+\t", "", l) for l in out.split("\n")[1:]]


def run_once(exe: str) -> float:
    out = subprocess.run([exe], capture_output=True, text=True, cwd=os.path.dirname(exe)).stdout
    total = sum(int(m) for m in re.findall(r"^total_ns (\d+)", out, re.M))
    iters = int(re.search(r"^timed_iters (\d+)", out, re.M).group(1))
    return total / iters


def interleave(a: str, b: str, reps: int) -> tuple[list[float], list[float]]:
    A, B = [], []
    run_once(a), run_once(b)          # warm both, discard
    for i in range(reps):
        pair = (a, A, b, B) if i % 2 == 0 else (b, B, a, A)
        pair[1].append(run_once(pair[0]))
        pair[3].append(run_once(pair[2]))
    return A, B


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("port")
    p.add_argument("--a", required=True, help="baseline stdlib: git rev or path")
    p.add_argument("--b", required=True, help="candidate stdlib: git rev or path")
    p.add_argument("--reps", type=int, default=25)
    p.add_argument("--diff-only", action="store_true",
                   help="stop after the codegen diff; never time")
    args = p.parse_args()

    port_src = find_port(args.port)
    work = tempfile.mkdtemp(prefix="ab_codegen_")
    saved = os.path.join(work, "saved_store.kz")
    shutil.copy(STDLIB, saved)
    try:
        a_lib = resolve_stdlib(args.a, os.path.join(work, "a.kz"))
        b_lib = resolve_stdlib(args.b, os.path.join(work, "b.kz"))
        a_exe = build(port_src, a_lib, os.path.join(work, "a"))
        b_exe = build(port_src, b_lib, os.path.join(work, "b"))

        da, db = disasm(a_exe), disasm(b_exe)
        if da == db:
            print(f"{args.port}: codegen IDENTICAL ({len(da)} lines of asm) — "
                  f"the change cannot affect runtime. No timing is meaningful.")
            return
        import difflib
        delta = sum(1 for l in difflib.unified_diff(da, db, n=0) if l[:1] in "+-")
        print(f"{args.port}: codegen DIFFERS — {delta} changed asm lines")
        if args.diff_only:
            return

        A, B = interleave(a_exe, b_exe, args.reps)
        for name, xs in ((args.a, A), (args.b, B)):
            print(f"  {name:24s} median {statistics.median(xs):9.0f} ns/iter  "
                  f"min {min(xs):9.0f}  n={len(xs)}")
        print(f"  ratio a/b: median {statistics.median(A)/statistics.median(B):.3f}  "
              f"min {min(A)/min(B):.3f}")
    finally:
        shutil.copy(saved, STDLIB)


if __name__ == "__main__":
    main()
