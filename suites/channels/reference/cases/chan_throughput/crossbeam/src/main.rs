// chan_throughput — the nearest semantic peer to std/channel in another
// language: crossbeam's bounded(1024) MPMC channel driven entirely with
// try_send/try_recv on ONE thread — non-blocking, | full | / | none |
// semantics, same pass schedule as the Koru kernel (feed up to 128,
// then four one-dequeue consumers). crossbeam's bounded channel is an
// array-based lock-free queue — the same family as the Vyukov ring.
use crossbeam_channel::{bounded, TryRecvError, TrySendError};

fn main() {
    const TOTAL: i64 = 1_000_000;
    const BATCH: i64 = 128;
    const CONSUMERS: usize = 4;
    let (tx, rx) = bounded::<i64>(1024);

    let mut sent: i64 = 0;
    let mut got: i64 = 0;
    let mut sum: i64 = 0;
    while got < TOTAL {
        // producer step: bounded batch, ends early on full
        let mut fed: i64 = 0;
        while fed < BATCH && sent < TOTAL {
            match tx.try_send(sent) {
                Ok(()) => {
                    sent += 1;
                    fed += 1;
                }
                Err(TrySendError::Full(_)) => break,
                Err(TrySendError::Disconnected(_)) => unreachable!(),
            }
        }
        // consumer steps: four competing units, one dequeue each
        for _ in 0..CONSUMERS {
            match rx.try_recv() {
                Ok(v) => {
                    sum += v;
                    got += 1;
                }
                Err(TryRecvError::Empty) | Err(TryRecvError::Disconnected) => {}
            }
        }
    }
    println!("{}", sum);
}
