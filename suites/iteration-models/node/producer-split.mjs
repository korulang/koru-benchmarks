const n = 10_000_001 + process.argv.length - 2;
function* evens() { for (let i = 2; i < n; i += 2) yield i; }
let best = Infinity, c = 0;
for (let r = 0; r < 7; r++) {
    const t = performance.now();
    c = 0; for (const v of evens()) c += v * 3;
    best = Math.min(best, performance.now() - t);
}
console.log(`RESULT ${c} ${best.toFixed(6)}`);
