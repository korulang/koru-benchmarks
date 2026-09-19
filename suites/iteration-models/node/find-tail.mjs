const n = 10_000_001 + process.argv.length - 2;
function* range() { for (let i = 0; i < n; i++) yield i; }
let best = Infinity, c = -1;
for (let r = 0; r < 7; r++) {
    const t = performance.now();
    c = -1; for (const v of range()) if (v > 9_999_997) { c = v; break; }
    best = Math.min(best, performance.now() - t);
}
console.log(`RESULT ${c} ${best.toFixed(6)}`);
