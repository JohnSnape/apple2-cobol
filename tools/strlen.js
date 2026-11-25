// strlen.js  From src/: check every length-prefixed string.
//
// The console routines take a string as one length byte followed by
// that many characters, and the assembler will not notice if the two
// disagree - the message simply prints short, or prints one byte of
// whatever came next.  check.js cannot see this either: both lines
// assemble to exactly the size it expects.  So it gets its own pass.
//
// A length prefix is a DFB holding a single DECIMAL number whose next
// line is an ASC.  Everything after it counts towards the string until
// a label, a comment, a blank line, an instruction, or the next lone
// decimal DFB - which is either the next entry's prefix or the DFB 0
// that terminates a table.  That last rule is what makes a table of
// counted keywords check entry by entry rather than as one enormous
// string.
//
// Interleaved DFBs written in HEX do not end a string: that is how
// FORMATD's command bar puts inverse-video attribute bytes between its
// eight ASC runs, and all of it is one 67-byte string.
//
//   cd src && node ../tools/strlen.js *.S
const fs = require('fs');
const PREFIX = /^([A-Za-z][A-Za-z0-9]*)?\s+DFB\s+(\d+)\s*$/;
const LONE = /^\s+DFB\s+\d+\s*$/;
let bad = 0;
for (const f of process.argv.slice(2)) {
  const L = fs.readFileSync(f, 'utf8').split(/\r?\n/);
  for (let i = 0; i < L.length; i++) {
    const d = L[i].match(PREFIX);
    if (!d || !/^\s+ASC\s+'/.test(L[i + 1] || '')) continue;
    let n = 0;
    for (let j = i + 1; j < L.length; j++) {
      const ln = L[j];
      if (/^\*/.test(ln) || !ln.trim()) break;
      if (/^[A-Za-z]/.test(ln)) break;
      if (LONE.test(ln)) break;
      let m;
      if ((m = ln.match(/^\s+ASC\s+'([^']*)'/))) n += m[1].length;
      else if ((m = ln.match(/^\s+DFB\s+(.+)$/))) n += m[1].split(',').length;
      else if ((m = ln.match(/^\s+HEX\s+([0-9A-Fa-f]+)/))) n += m[1].length / 2;
      else break;
    }
    if (n !== +d[2]) {
      console.log(`${f}:${i + 1}  ${d[1] || '(entry)'} says ${d[2]}, the bytes are ${n}`);
      bad++;
    }
  }
}
console.log(bad ? `${bad} length prefix(es) wrong` : 'all length prefixes agree');
