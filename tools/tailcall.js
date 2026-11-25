// tailcall.js - jumps and branches into routines that other code CALLS.
//
//   cd src && node ../tools/tailcall.js
//
// Two bugs of one kind on 2026-11-07: BEQ DDLVL in DATDIV and JMP PDPARA
// in PROCDIV.  Both targets are subroutines that end in RTS; reached by a
// jump, that RTS returns from the CALLER'S caller, and the loop that
// jumped simply stops - silently, with carry in whatever state it was.
//
// A JMP to a subroutine is legitimate as a TAIL CALL: the last thing the
// routine does, so the callee's RTS is the right one.  So this lists
// every JMP/branch whose target is also the target of some JSR, and marks
// it TAIL when the next line starts a new routine (a label, or a blank or
// comment line and then a label).  Anything not marked TAIL deserves a
// look: it jumps to a subroutine and expects to keep going.
const fs = require('fs');
// LIB.S is the jump table - a page of JMPs into called routines, by design.
// Expect some survivors that are fine: a routine looping back to its own
// entry (BPL GETCHORD), or a tail exit from inside a subroutine (BEQ
// PDOSTR).  Reviewed 2026-11-07; the two real bugs were jumps from INSIDE
// A LOOP that expected to come back.
const files = fs.readdirSync('.').filter(f => /\.S$/.test(f) && f !== 'LIB.S' && f !== 'AUXLC.S');
const parse = f => fs.readFileSync(f, 'utf8').split(/\r?\n/).map((t, i) => {
  if (/^\s*$/.test(t) || /^[*;]/.test(t)) return { n: i + 1, blank: true };
  const label = (t.match(/^(\S+)/) || [])[1] || '';
  const rest = t.slice(label.length).trim().split(/\s+/);
  return { n: i + 1, label, op: (rest[0] || '').toUpperCase(), arg: rest[1] || '' };
});
const src = Object.fromEntries(files.map(f => [f, parse(f)]));
const called = new Set();
for (const f of files) for (const r of src[f]) if (r.op === 'JSR') called.add(r.arg);
let n = 0;
for (const f of files) {
  const L = src[f];
  L.forEach((r, i) => {
    if (r.blank || !/^(JMP|BRA|B[CEMNPV][CEIQLSCT])$/.test(r.op) || !called.has(r.arg)) return;
    let j = i + 1; while (j < L.length && L[j].blank) j++;
    const tail = r.op === 'JMP' && (j >= L.length || L[j].label);
    if (!tail) { console.log(`${f}:${r.n}  ${r.op} ${r.arg}  - ${r.arg} is JSR'd elsewhere`); n++; }
  });
}
console.log(n ? `${n} to look at` : 'none');
