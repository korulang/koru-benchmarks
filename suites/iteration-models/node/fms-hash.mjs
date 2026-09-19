const n = 10_000_001 + process.argv.length - 2;
let best = Infinity, c = 0;
for (let r = 0; r < 7; r++) {
    const t = performance.now();
    c = 0; for (let i = 1; i < n; i++) if (i * 89478611 % 97 < 60) c += i * 3;
    best = Math.min(best, performance.now() - t);
}
console.log(`RESULT ${c} ${best.toFixed(6)}`);
