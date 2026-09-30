# channels

`std/channel` benchmarks — message-passing workloads with matching Go
references. Same topology, same message count, same checksum oracle in
both columns.

## What is being measured (and what is not)

The Koru column runs **pump participants on one thread**: the producer is
a `<name>-step`/`<name>-live` unit pair that feeds a bounded batch per
pass, consumers are `std/channel(name) ! kind v` joins that take one
dequeue per pass, and the pump runs until every participant's `live`
answers 0. Nothing blocks; `| full`, `| none`, `| closed` are branches.

The Go column runs **goroutines**: producers and consumers are real
goroutines parked and woken by the runtime, spread across OS threads.
The `go1t` row re-runs the same binary under `GOMAXPROCS=1` — the honest
control that isolates channel machinery from thread scheduling.

The `zig-ring` row is the same-substrate control: the SAME Vyukov
`MpmcRing` `std/channel` emits, driven by the SAME pass schedule
(producer batch-until-`full`, four one-dequeue consumers) in bare Zig —
no pump, no transform. It answers the question "what does the channel
machinery cost over the raw ring?" — and the measured answer on this
machine is within noise (~5%).

**This is not a claim of cross-thread parity.** Koru's spawned-producer
edge (`699_030`) and the futex park/wake tier are unbuilt — a producer on
another OS thread cannot yet send into these channels. What the numbers
show is the shape the language actually ships today: the same program
topology, the same ring, zero parking — measured, not asserted.

## Protocol

`./run.sh` (repo root) builds each `koru/<name>/*.k` through `koruc` and
checks stdout against `expected.txt`. `./bench.sh` (this directory) does
the same and then times oracle-passing binaries with
`hyperfine -N --warmup 3 --min-runs 10`. A binary whose output differs
from the oracle is excluded from timing — a wrong answer is not a result.

Numbers are measured on the local machine only; `bench.json` describes
the workload, not a target.
