// regs.js - find X or Y used after a library call without being reloaded.
//
//   cd src && node ../tools/regs.js [FILE.S ...]
//
// The library keeps no registers: CONPUTC loads X with the cursor row,
// and most routines use X and Y as they please.  So a caller that keeps
// a count or an index in X or Y across JSR <library vector> loses it.
// BCDTEST's TOP1 loop did exactly that (2026-11-07): DEX after
// JSR CONPUTC never reached zero, and the screen scrolled table bytes
// forever.
//
// For every JSR to a name EQUATES defines as LIBBASE+n, this follows the
// straight-line code after it and reports the first instruction that
// READS X or Y before something writes it.  A branch or label ends the
// trace, so a loop is caught only when the use comes before the branch -
// which is where a loop counter's DEX/INY sits.  Heuristic, not proof.
const fs = require('fs');

const vec = new Set();
for (const f of ['EQUATES.S', 'EQUATES2.S'])
  fs.readFileSync(f, 'utf8').split(/\r?\n/).forEach(l => {
    const m = l.match(/^(\w+)\s+EQU\s+LIBBASE\+/); if (m) vec.add(m[1]);
  });
const LIBFILES = new Set(['TEXTDRV', 'FILEIO', 'CATALOG', 'BCD', 'BANKS',
  'CONSOLE', 'DSCREEN', 'AUXMEM', 'NUMFMT', 'PICTURE', 'SELECT', 'SORT',
  'PRINTER', 'DATIME', 'CLOCK', 'RECMAN', 'SCRSHOW', 'SCRINP', 'CLASS', 'ERRMSG', 'PREFIX',
  'ABORT', 'LIB', 'GATE', 'AUXLC', 'SELECT2', 'EQUATES', 'EQUATES2'].map(x => x + '.S'));

const WRITES = { X: /^(LDX|TAX|PLX|TSX)$/, Y: /^(LDY|TAY|PLY)$/ };
const READS = {
  X: (op, arg) => /^(INX|DEX|CPX|TXA|TXS|STX|PHX)$/.test(op) || /,X\)?$/i.test(arg),
  Y: (op, arg) => /^(INY|DEY|CPY|TYA|STY|PHY)$/.test(op) || /\),Y$|,Y$/i.test(arg),
};

// what a vector leaves alone, and what it hands back on purpose
const KEEPS = { CONPUTC: 'XY', PUTC: 'X' };
const RETURNS = { CONGETLN: 'Y', DSACC: 'Y' };

const files = process.argv.length > 2 ? process.argv.slice(2)
  : fs.readdirSync('.').filter(f => /\.S$/.test(f) && !LIBFILES.has(f)).sort();
let total = 0;
for (const f of files) {
  const L = fs.readFileSync(f, 'utf8').split(/\r?\n/).map(t => {
    if (/^\s*$/.test(t) || /^[*;]/.test(t)) return null;
    const label = (t.match(/^(\S+)/) || [])[1] || '';
    const rest = t.slice(label.length).trim().split(/\s+/);
    return { label, op: (rest[0] || '').toUpperCase(), arg: rest[1] || '' };
  });
  L.forEach((r, i) => {
    if (!r || r.op !== 'JSR' || !vec.has(r.arg)) return;
    for (const reg of ['X', 'Y']) {
      if ((KEEPS[r.arg] || '').includes(reg) || (RETURNS[r.arg] || '').includes(reg)) continue;
      for (let j = i + 1; j < L.length; j++) {
        const s = L[j]; if (!s) continue;
        if (s.label) break;
        if (READS[reg](s.op, s.arg)) {
          console.log(`${f}:${i + 1}  JSR ${r.arg}  then ${s.op} ${s.arg} at line ${j + 1} uses ${reg}`);
          total++; break;
        }
        if (WRITES[reg].test(s.op)) break;
        if (/^(RTS|RTI|JMP|BRA|B[A-Z]{2}|JSR)$/.test(s.op)) break;
      }
    }
  });
}
console.log(total ? `${total} suspect(s)` : 'no suspects');
