use std::hint::black_box;
fn main() {
    let n = 10_000_000usize + std::env::args().count();
    let mut best = f64::MAX;
    let mut c = 0i64;
    for _ in 0..7 {
        let t = std::time::Instant::now();
        c = black_box((0..black_box(n)).find(|i| *i as i64 > 9_999_997).map(|i| i as i64).unwrap_or(-1));
        best = best.min(t.elapsed().as_secs_f64() * 1000.0);
    }
    println!("RESULT {} {:.6}", c, best);
}
