// datamap.js  From src/: the data region, address by address.
//
// $0C00-$1FFF is handed out by EQUATES.S alone, and EQUATES.S does not
// say how big anything is - QSPEC is one address and twenty bytes, ROWBUF
// is one address and eighty.  So nothing can prove two allocations do not
// overlap.  What this does prove is the half of it a machine can:
//
//   * two symbols on exactly the same address - which is what happened
//     when CLASS and ABORT were given $0CE8 and $0CDD, both of which
//     PICTURE already had
//   * the gaps, so the next module has somewhere to be put that is not
//     in the middle of something
//
// The gaps are measured to the NEXT symbol, so a gap of 8 after a
// symbol that needs 8 bytes is not free - read the map, not just the
// number.  Anything under sixteen bytes is not reported as a gap at
// all; it is almost certainly the previous symbol's own extent.
//
//   cd src && node ../tools/datamap.js
const fs = require('fs');
const at = {};
for (const EQF of ['EQUATES.S', 'EQUATES2.S']) fs.readFileSync(EQF, 'utf8').split(/\r?\n/).forEach((l, i) => {
  const m = l.match(/^([A-Za-z][A-Za-z0-9]*)\s+EQU\s+\$([0-9A-Fa-f]{3,4})\s*$/);
  if (!m) return;
  const a = parseInt(m[2], 16);
  if (a < 0x0200 || a > 0x1fff) return;
  // AXBASE is where usable space starts inside an AUXILIARY bank, and
  // RUNMAX is a length rather than an address.  Neither is main memory
  // and neither can collide with anything here.
  if (m[1] === 'AXBASE' || m[1] === 'RUNMAX') return;
  (at[a] = at[a] || []).push(`${m[1]} (${EQF}:${i + 1})`);
});
const ks = Object.keys(at).map(Number).sort((x, y) => x - y);
const hex = a => '$' + a.toString(16).toUpperCase().padStart(4, '0');
let dup = 0;
for (const k of ks)
  if (at[k].length > 1) { console.log('SAME ADDRESS ' + hex(k) + '  ' + at[k].join('  ')); dup++; }
console.log(dup ? `${dup} address(es) with more than one owner` : 'no two symbols share an address');
console.log();
for (let i = 0; i < ks.length; i++) {
  const gap = i + 1 < ks.length ? ks[i + 1] - ks[i] : 0;
  console.log(hex(ks[i]).padEnd(7) + at[ks[i]].join(' ').padEnd(46) +
    (gap >= 16 ? `  ${gap} bytes to the next symbol` : ''));
}
