// pdis.js - disassemble a compiled COBOL object (PCB1) to p-code listing.
//
//   node tools/pdis.js OBJECTFILE
//
// Operand sizes are COMPILE.md section 3's, plus the 2026-11-07 change:
// PERF is target, return, END-PARAGRAPH byte and RET carries a paragraph
// byte.  Written while chasing MEDIA's "ends at once" run.
const fs = require('fs');
const b = fs.readFileSync(process.argv[2]);
const w = o => b[o] | b[o + 1] << 8;
const H = { dataseg: w(5), items: w(7), descoff: w(9), litoff: w(11), codeoff: w(13), entry: w(15), codelen: w(17) };
if (b.slice(0, 4).toString() !== 'PCB1') { console.log('not a PCB1 object'); process.exit(1); }
console.log(`items ${H.items}  dataseg ${H.dataseg}  code ${H.codelen} bytes at ${H.codeoff}`);
const pool = b.slice(H.litoff, H.codeoff);
const lit = o => { const n = pool[o]; const t = pool.slice(o + 1, o + 1 + n).toString('latin1');
  return /^[\x20-\x7e]*$/.test(t) && n < 60 ? JSON.stringify(t) : `lit@${o}`; };
// [mnemonic, operand kinds]  W=word item, L=word literal, T=word target, B=byte, P=byte paragraph
const OPS = {
  0x00: ['NOP', ''], 0x01: ['HALT', ''], 0x02: ['LINE', 'W'], 0x03: ['ENTER', 'W'],
  0x10: ['MOVA', 'WW'], 0x11: ['MOVN', 'WW'], 0x12: ['MOVE', 'WW'], 0x13: ['MOVG', 'WW'],
  0x14: ['MOVL', 'WL'], 0x15: ['MOVF', 'WB'], 0x16: ['INIT', 'W'],
  0x30: ['ADDP', 'WWB'], 0x32: ['SUBP', 'WWB'], 0x34: ['MULP', 'WWB'], 0x36: ['DIVP', 'WWB'],
  0x50: ['PUSHD', 'W'], 0x51: ['PUSHL', 'L'], 0x52: ['POPD', 'W'], 0x18: ['SUBS', 'BWWBB'], 0x58: ['POPDR', 'W'],
  0x53: ['EADD', ''], 0x54: ['ESUB', ''], 0x55: ['EMUL', ''], 0x56: ['EDIV', ''], 0x57: ['ENEG', ''],
  0x60: ['CMPN', 'WW'], 0x61: ['CMPA', 'WW'], 0x62: ['CLASS', 'WBL'],
  0x63: ['BRA', 'T'], 0x64: ['BEQ', 'T'], 0x65: ['BNE', 'T'], 0x66: ['BLT', 'T'], 0x67: ['BGT', 'T'],
  0x68: ['BLE', 'T'], 0x69: ['BGE', 'T'], 0x6A: ['BSIZ', 'T'], 0x6B: ['BEXC', 'T'],
  0x70: ['PERF', 'TTP'], 0x74: ['RET', 'P'], 0x75: ['GOTO', 'T'],
  0x80: ['DISP', 'W'], 0x81: ['DISPL', 'L'], 0x83: ['ACC', 'W'], 0x84: ['DISPN', 'W'],
  0x86: ['NL', ''], 0x8A: ['DISPLN', 'L'],
};
OPS[0x99] = ['FNAME', ''];
for (let f = 0; f < 7; f++) OPS[0x90 + f] = [['OPEN', 'CLOSE', 'READ', 'WRITE', 'REWRITE', 'DELETE', 'START'][f], 'BWWWT'];
const c = b.slice(H.codeoff, H.codeoff + H.codelen);
let i = 0;
while (i < c.length) {
  const op = c[i], d = OPS[op];
  if (!d) { console.log(String(i).padStart(4), op.toString(16).padStart(2, '0'), '???'); i++; continue; }
  let j = i + 1; const parts = [];
  for (const k of d[1]) {
    if (k === 'B' || k === 'P') { parts.push((k === 'P' ? 'para ' : '') + c[j]); j++; }
    else { const v = c[j] | c[j + 1] << 8; j += 2;
      parts.push(k === 'L' ? lit(v) : k === 'T' ? (v === 0xffff ? '-' : '@' + v) : (v === 0xffff ? '-' : 'item' + v)); }
  }
  console.log(String(i).padStart(4), d[0].padEnd(7), parts.join(', '));
  i = j;
}
