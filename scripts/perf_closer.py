#!/usr/bin/env python3
"""perf_closer — a mechanical timing verdict that can say "I don't know".

Renders exactly one of three verdicts about a candidate binary against a
reference binary, and proves the verdict against noise measured IN THE SAME
RUN — never against a stored number from a previous board:

  PASS    (exit 0)  candidate/reference is under the bar even if every
                    measured sample got the worst of the noise.
  FAIL    (exit 1)  candidate/reference is over the bar even if every
                    measured sample got the best of the noise. Also the exit
                    for a wrong answer — a wrong answer is not a timing.
  REFUSED (exit 3)  the noise interval straddles the bar: this instrument,
                    on this machine, right now, cannot answer the question.
                    Also the exit when a koru regression suite is live.

Protocol. Four streams run interleaved inside ONE loop, order rotated every
round so every stream sees the same seconds of machine: the candidate under
two labels (byte-identical copies), and the reference under two labels.
The twin pairs are the IDENTITY CONTROL: any spread between two labels of
the same binary is pure instrument noise, measured here and now. Measured
2026-08-07 on the M2 Pro workstation: twin spread 1.000-1.002x quiet, but
1.30x SUSTAINED on a ~10ms binary at load ~18 (macOS parks short processes
on E-cores under load) — which is why the floor must be measured per run,
per binary, and why a closer without REFUSED would lie.

Floor and interval. F = the worse twin spread of the two binaries, taken at
the bootstrap p95 over round-resamples (so one lucky split cannot fake a
tight floor). The ratio R = median(candidate)/median(reference) gets a
bootstrap interval, widened by F on both ends:
    [R_lo / F,  R_hi * F]
Verdict: interval entirely under the bar -> PASS; entirely over -> FAIL;
straddling -> REFUSED. A noisy run widens the interval until only REFUSED
can render — the identity control gating board validity is this mechanism,
not a separate check.

The bar is the CLAIM under test — "candidate within <bar>x of reference" —
and must be stated by the caller. It is the one number the machine cannot
know: what magnitude matters is the question, not a measurement. Everything
else — floor, ratio, interval — is measured in-run.

Usage:
  perf_closer.py --candidate BIN --reference BIN --oracle TEXT --bar X
                 [--oracle-ref TEXT] [--rounds N] [--json PATH]
Oracles are whitespace-stripped expected stdout; --oracle-ref defaults to
--oracle (same-answer benchmarks).
"""
import argparse, json, os, random, shutil, statistics, subprocess, sys, tempfile, time


def suite_live() -> bool:
    return subprocess.run(["pgrep", "-f", "run_regression"],
                          capture_output=True).returncode == 0


def loadavg() -> str:
    return " ".join(f"{x:.2f}" for x in os.getloadavg())


def run_once(exe: str, oracle: str) -> float:
    t0 = time.monotonic_ns()
    r = subprocess.run([exe], stdin=subprocess.DEVNULL, capture_output=True, text=True)
    t1 = time.monotonic_ns()
    got = "".join(r.stdout.split())
    if got != oracle:
        print(f"WRONG ANSWER from {exe}: got {got!r} want {oracle!r} — "
              f"a wrong answer is not a timing.", file=sys.stderr)
        sys.exit(1)
    return (t1 - t0) / 1e9


def spread(x: float, y: float) -> float:
    return max(x / y, y / x)


def bootstrap_twin_spread_p95(a: list, b: list, n: int = 1000) -> float:
    """p95 of the twin median spread over round-resamples: the floor one
    lucky split cannot understate."""
    rng = random.Random(0xF100D)
    k = len(a)
    xs = []
    for _ in range(n):
        idx = [rng.randrange(k) for _ in range(k)]
        xs.append(spread(statistics.median([a[i] for i in idx]),
                         statistics.median([b[i] for i in idx])))
    xs.sort()
    return xs[int(0.95 * (n - 1))]


def bootstrap_ratio_ci(c1, c2, r1, r2, n: int = 1000):
    rng = random.Random(0xCA1C)
    k = len(c1)
    xs = []
    for _ in range(n):
        idx = [rng.randrange(k) for _ in range(k)]
        mc = statistics.median([c1[i] for i in idx] + [c2[i] for i in idx])
        mr = statistics.median([r1[i] for i in idx] + [r2[i] for i in idx])
        xs.append(mc / mr)
    xs.sort()
    return xs[int(0.025 * (n - 1))], xs[int(0.975 * (n - 1))]


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--candidate", required=True)
    p.add_argument("--reference", required=True)
    p.add_argument("--oracle", required=True, help="expected stdout, whitespace-stripped")
    p.add_argument("--oracle-ref", default=None)
    p.add_argument("--bar", type=float, required=True,
                   help="the claim under test: candidate within BAR x of reference")
    p.add_argument("--rounds", type=int, default=40)
    p.add_argument("--json", default=None)
    args = p.parse_args()
    oracle_c = args.oracle
    oracle_r = args.oracle_ref if args.oracle_ref is not None else args.oracle

    if suite_live():
        print("REFUSED: a koru regression suite is live — timing would be noise.")
        sys.exit(3)

    work = tempfile.mkdtemp(prefix="perf_closer_")
    streams = {}  # name -> (exe_copy, oracle, samples)
    for name, src, orc in (("c1", args.candidate, oracle_c), ("c2", args.candidate, oracle_c),
                           ("r1", args.reference, oracle_r), ("r2", args.reference, oracle_r)):
        dst = os.path.join(work, name)
        shutil.copy(src, dst)
        os.chmod(dst, 0o755)
        streams[name] = (dst, orc, [])

    load_before = loadavg()
    order = ["c1", "r1", "c2", "r2"]
    for name in order:                       # warmup, discarded
        run_once(streams[name][0], streams[name][1])
    for i in range(args.rounds):
        for name in order[i % 4:] + order[:i % 4]:   # rotate start point
            exe, orc, xs = streams[name]
            xs.append(run_once(exe, orc))
    load_after = loadavg()
    shutil.rmtree(work, ignore_errors=True)

    if suite_live():
        print("REFUSED: a koru regression suite started during the run — samples discarded.")
        sys.exit(3)

    c1, c2 = streams["c1"][2], streams["c2"][2]
    r1, r2 = streams["r1"][2], streams["r2"][2]
    f_c = max(spread(statistics.median(c1), statistics.median(c2)),
              bootstrap_twin_spread_p95(c1, c2))
    f_r = max(spread(statistics.median(r1), statistics.median(r2)),
              bootstrap_twin_spread_p95(r1, r2))
    floor = max(f_c, f_r)
    med_c = statistics.median(c1 + c2)
    med_r = statistics.median(r1 + r2)
    ratio = med_c / med_r
    r_lo, r_hi = bootstrap_ratio_ci(c1, c2, r1, r2)
    lo, hi = r_lo / floor, r_hi * floor

    if hi <= args.bar:
        verdict, code = "PASS", 0
    elif lo > args.bar:
        verdict, code = "FAIL", 1
    else:
        verdict, code = "REFUSED-TOO-NOISY", 3

    print(f"candidate {os.path.basename(args.candidate)}: median {med_c*1e3:.2f} ms  "
          f"(twin floor {f_c:.4f}x)")
    print(f"reference {os.path.basename(args.reference)}: median {med_r*1e3:.2f} ms  "
          f"(twin floor {f_r:.4f}x)")
    print(f"ratio {ratio:.4f}  noise-honest interval [{lo:.4f}, {hi:.4f}]  "
          f"floor {floor:.4f}x (measured this run)  bar {args.bar}x")
    print(f"load {load_before} -> {load_after}  rounds {args.rounds} x 4 streams interleaved")
    print(f"VERDICT: {verdict}" + (
        f" — the interval straddles the bar; this machine cannot answer right now"
        if code == 3 else ""))

    if args.json:
        with open(args.json, "w") as fh:
            json.dump({
                "verdict": verdict, "bar": args.bar,
                "ratio": ratio, "interval": [lo, hi],
                "floor": floor, "floor_candidate": f_c, "floor_reference": f_r,
                "median_candidate_ms": med_c * 1e3, "median_reference_ms": med_r * 1e3,
                "rounds": args.rounds,
                "load_before": load_before, "load_after": load_after,
                "protocol": "4 streams (candidate x2 labels, reference x2 labels) "
                            "interleaved per round, order rotated; floor = worse "
                            "twin spread at bootstrap p95; interval = bootstrap "
                            "ratio CI widened by floor; all measured in this run",
                "samples_ms": {k: [round(x * 1e3, 3) for x in v[2]]
                               for k, v in streams.items()},
            }, fh, indent=1)
            fh.write("\n")
    sys.exit(code)


if __name__ == "__main__":
    main()
