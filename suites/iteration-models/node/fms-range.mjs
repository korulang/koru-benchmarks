const n = 10_000_001 + process.argv.length - 2;
function* evensRange() { for (let i = 1; i < n; i++) if (i % 2 === 0) yield i; }
let best = Infinity, c = 0;
for (let r = 0; r < 7; r++) {
    const t = performance.now();
    c = 0; for (const v of evensRange()) c += v * 3;
    best = Math.min(best, performance.now() - t);
}
console.log(`RESULT ${c} ${best.toFixed(6)}`);
