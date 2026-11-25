// mkproc.js DRIVER.drv OUT.cob SNP...
// Builds a test program from library procedures: in the driver, a line
// "@DATA" becomes piece 1 (the data) of every .SNP named, and "@PROCS"
// becomes piece 2 (the paragraphs).  A .SNP's pieces are split by lines
// that are a lone "*", exactly as the editor's SA-P PLACE splits them:
// piece 0 is the notes at the top, which PLACE never places.  So the test
// compiles the very text a programmer would place.
const fs = require('fs');
const [, , drv, out, ...snps] = process.argv;
const pieces = snps.map(f => {
  const lines = fs.readFileSync(f, 'latin1').split(/\r?\n/);
  const p = [[]];
  for (const l of lines) { if (l.trimEnd() === '*') p.push([]); else p[p.length - 1].push(l); }
  if (p.length !== 3) throw new Error(f + ': ' + p.length + ' pieces, want 3');
  return p.slice(1).map(x => { while (x.length && x[x.length - 1] === '') x.pop(); return x; });
});
const res = [];
for (const l of fs.readFileSync(drv, 'latin1').split(/\r?\n/)) {
  if (l.trim() === '@DATA') pieces.forEach(p => res.push(...p[0]));
  else if (l.trim() === '@PROCS') pieces.forEach(p => res.push(...p[1]));
  else res.push(l);
}
while (res.length && res[res.length - 1] === '') res.pop();
for (const [i, l] of res.entries()) if (l.length > 80) throw new Error(`line ${i + 1} over 80: ${l}`);
fs.writeFileSync(out, res.join('\n') + '\n', 'latin1');
console.log(out + ': ' + res.length + ' lines');
