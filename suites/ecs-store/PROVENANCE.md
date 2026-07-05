# ecs-store — reference provenance

The reference for this suite is the rust-gamedev working group's cross-engine
ECS benchmark suite:

- Repo: `https://github.com/rust-gamedev/ecs_bench_suite` (ARCHIVED upstream)
- Commit: `9b4c98d` ("Merge pull request #33 from rust-gamedev/add_status_to_readme")
- Local clone: `~/src/ecs_bench_suite`
- Engines it covers: legion (+packed), bevy_ecs 0.5, hecs, planck_ecs,
  shipyard, specs
- Protocol: **criterion** (`cargo bench`, harness = false) — statistical
  sampling, violin plots, per-group `target/criterion/<group>/` reports.

## NOT vendored — and why

Unlike `osprey-compute-kernels`, the reference corpus is **not** copied into
this repo: the upstream repository carries **no license file**, so verbatim
vendoring is not clearly permitted. The clone + pinned commit above is the
reference; any future re-run of their side happens in the clone, under their
exact protocol (`cargo bench`), never via a re-implementation here.

What this suite holds is entirely ours: the honest board (README.md), the
Koru workload ports as they become expressible, and machine-stamped local
baseline results for the reference engines.

## Why this reference

Their retro on archiving the project: "speed is only one aspect of an ECS."
We take the **protocol as donor and the workloads as gap-flags** — instrument,
never destination. Each entry names a `std/store` capability or performance
gap in the compiler's own terms (see the board); entries go green as a side
effect of the store rungs landing, and no cross-engine claim leaves this repo
unless SHOWN under criterion on the same machine, same workload, same rules.

Design linkage: `koru/tests/regression/600_STDLIB/690_STORE/DESIGN.md` — the
"perf north star" section holds the bucket mapping; O13 (NO ARCHETYPES) is the
ruling two of the seven entries exist to validate or embarrass.
