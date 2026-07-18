// Contender: Rust `serde_json` — a SPECIALIZED JSON deserializer. This is the
// koru-RIVAL category (same bucket as zig std.json / python json.loads), NOT
// koru's general-library peer. Included as a specialized reference point,
// labeled as such; never a naked "we beat serde". FULL-TREE lane: it
// deserializes the document into serde_json::Value (allocates + builds the
// whole tree) — strictly more work than the recognizer lane.
//
// Protocol identical to every contender: read the doc from the LAST argv, 3s
// in-process timed-pass loop, print `passes=<n> seconds=<s>`; on an invalid
// doc print `INVALID` and exit 1 (the suite's reject gate).
use std::time::{Duration, Instant};

fn main() {
    let path = std::env::args().nth(1).expect("usage: serde_build <doc.json>");
    let doc = std::fs::read(&path).expect("read doc");

    match serde_json::from_slice::<serde_json::Value>(&doc) {
        Ok(_) => {}
        Err(_) => {
            println!("INVALID");
            std::process::exit(1);
        }
    }

    let start = Instant::now();
    let deadline = Duration::from_secs(3);
    let mut passes: u64 = 0;
    let mut sink: u64 = 0;
    while start.elapsed() < deadline {
        let v: serde_json::Value = serde_json::from_slice(&doc).expect("valid");
        // Force tree materialization work: count top-level members/elements.
        sink = sink.wrapping_add(match &v {
            serde_json::Value::Object(m) => m.len() as u64,
            serde_json::Value::Array(a) => a.len() as u64,
            _ => 1,
        });
        passes += 1;
    }
    let secs = start.elapsed().as_secs_f64();
    println!("passes={} seconds={:.6} sink={}", passes, secs, sink);
}
