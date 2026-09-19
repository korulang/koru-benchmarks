const n = 10_000_001 + process.argv.length - 2;
const data = new Int32Array(n - 1);
for (let i = 0; i < n - 1; i++) data[i] = i + 1;
let best = Infinity, c = 0;
for (let r = 0; r < 7; r++) {
    const t = performance.now();
    c = 0; for (const v of data) if (v % 2 === 0) c += v * 3;
    best = Math.min(best, performance.now() - t);
}
console.log(`RESULT ${c} ${best.toFixed(6)}`);
