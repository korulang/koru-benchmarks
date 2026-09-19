use std::hint::black_box;
struct EvensTo { i: usize, n: usize }
impl Iterator for EvensTo {
    type Item = usize;
    fn next(&mut self) -> Option<usize> {
        loop {
            self.i += 1;
            if self.i >= self.n { return None; }
            if self.i % 2 == 0 { return Some(self.i); }
        }
    }
}
fn main() {
    let n = 10_000_000usize + std::env::args().count();
    let mut best = f64::MAX;
    let mut c = 0i64;
    for _ in 0..7 {
        let t = std::time::Instant::now();
        c = black_box(EvensTo { i: 0, n: black_box(n) }.map(|v| v as i64 * 3).sum());
        best = best.min(t.elapsed().as_secs_f64() * 1000.0);
    }
    println!("RESULT {} {:.6}", c, best);
}
