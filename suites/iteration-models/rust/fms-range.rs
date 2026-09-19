use std::hint::black_box;
fn main() {
    let n = 10_000_000usize + std::env::args().count();
    let mut best = f64::MAX;
    let mut c = 0i64;
    for _ in 0..7 {
        let t = std::time::Instant::now();
        c = black_box((1..black_box(n)).filter(|i| i % 2 == 0).map(|i| i as i64 * 3).sum());
        best = best.min(t.elapsed().as_secs_f64() * 1000.0);
    }
    println!("RESULT {} {:.6}", c, best);
}
