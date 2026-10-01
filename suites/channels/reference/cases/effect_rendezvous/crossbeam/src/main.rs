// effect_rendezvous — crossbeam's bounded(0) is the same contract as
// Go's unbuffered channel: a zero-capacity rendezvous where send blocks
// until recv takes. Two threads, 1,000,000 handshakes, same checksum.
use crossbeam_channel::bounded;

fn main() {
    const TOTAL: i64 = 1_000_000;
    let (tx, rx) = bounded::<i64>(0);
    let consumer = std::thread::spawn(move || {
        let mut sum: i64 = 0;
        while let Ok(v) = rx.recv() {
            sum += v;
        }
        sum
    });
    for i in 0..TOTAL {
        tx.send(i).unwrap();
    }
    drop(tx);
    println!("{}", consumer.join().unwrap());
}
