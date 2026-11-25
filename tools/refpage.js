// refpage.js - build REFERENCE.html, the one-page programmer's reference
// (modelled on the shape of the GnuCOBOL Programmer's Guide: one long page,
// a numbered contents list, chapters by division, appendices of limits and
// messages).  Written 2026-11-22.
//
// Run from the project folder:   node tools/refpage.js
//
// NOTHING ON THE PAGE IS TYPED BY HAND.  Every part comes from a file that is
// already the authority for it, so rebuilding the page is how it stays true:
//
//   Part I, the language   QUICKREF.md, rendered as it stands
//   Appendix A, limits     the EQUs in the 6502 source (file:line shown)
//   Appendix B, errors     the ERTAB strings in src/ERRMSG.S, and the test
//                          programs in tools/emu/progs that raise each one
//   Appendix C, stops      the M... strings in src/VMTAIL.S, found where
//                          they are raised
//   Appendix D, ProDOS     the MLI error codes (ProDOS 8 Technical Reference)
//   Index                  every keyword in backquotes in QUICKREF
//
// The statement entries - a general format, rules and a tested example for
// each verb, the part of the GnuCOBOL guide that is written prose - are NOT
// here.  DECISIONS 8.3 (user, 2026-11-11): no reference-manual chapters until
// the system is complete.  The page says so where they will go.
//
// TO DO (the user, 2026-11-22): an appendix of what is NOT available on
// purpose - ALTER, CALL/LINKAGE, COMP-1/2, SORT/MERGE, SCREEN SECTION, Report
// Writer, INDEXED and the rest (DECISIONS 8.9) - each with what to use
// instead, read from one source list so it cannot drift.  HANDOFF.md has the
// note; add it once the keyword batches are done.
//
// If a symbol this script looks for has gone from the source, the page shows
// "?" in red and the script prints a warning: a stale page should look stale.

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'src');
const PROGS = path.join(ROOT, 'tools', 'emu', 'progs');
const OUT = path.join(ROOT, 'REFERENCE.html');
const warnings = [];

const read = f => fs.readFileSync(f, 'utf8');
const lines = f => read(f).split(/\r?\n/);
const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const slug = s => s.toLowerCase().replace(/<[^>]+>/g, '').replace(/&[a-z]+;/g, '')
  .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

// ---------------------------------------------------------------------------
// A small Markdown renderer: only what QUICKREF uses.  Headings, rules,
// fenced code, tables, block quotes, lists, paragraphs; inline code, bold,
// italic, strike-through.  The ✔ ✘ ◑ marks get a class so they show in colour.

function inline(s) {
  const code = [];
  s = s.replace(/`([^`]+)`/g, (_, c) => { code.push(c); return '\u0000' + (code.length - 1) + '\u0000'; });
  s = esc(s)
    .replace(/~~(.+?)~~/g, '<del>$1</del>')
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/(^|[^*\w])\*([^*\s][^*]*?)\*(?=[^*\w]|$)/g, '$1<em>$2</em>')
    .replace(/✔/g, '<span class="ok" title="works">✔</span>')
    .replace(/✘/g, '<span class="no" title="not built">✘</span>')
    .replace(/◑/g, '<span class="part" title="half built">◑</span>');
  return s.replace(/\u0000(\d+)\u0000/g, (_, i) => '<code>' + esc(code[+i]) + '</code>');
}

function cells(line) {
  const keep = [];
  const m = line.replace(/`[^`]*`/g, x => { keep.push(x); return '\u0001' + (keep.length - 1) + '\u0001'; });
  return m.trim().replace(/^\|/, '').replace(/\|$/, '').split('|')
    .map(c => c.trim().replace(/\u0001(\d+)\u0001/g, (_, i) => keep[+i]));
}
const isSep = l => /^\s*\|[\s:|-]*\|\s*$/.test(l) && /-/.test(l);

// md -> { html, heads: [{level, text, id}] }.  headId(level, text) names
// each heading, so the caller can number them.
function render(md, headId) {
  const src = md.split(/\r?\n/);
  const out = [], heads = [];
  let i = 0;
  while (i < src.length) {
    const l = src[i];
    if (/^\s*```/.test(l)) {
      const lang = l.trim().slice(3);
      const body = [];
      for (i++; i < src.length && !/^\s*```/.test(src[i]); i++) body.push(src[i]);
      i++;
      out.push(`<pre class="${lang === 'cobol' ? 'cobol' : 'plain'}">${esc(body.join('\n'))}</pre>`);
      continue;
    }
    if (!l.trim()) { i++; continue; }
    let m;
    if ((m = /^(#{1,4})\s+(.*)$/.exec(l))) {
      const level = m[1].length, text = inline(m[2]);
      const h = headId(level, text);
      heads.push(h);
      out.push(`<h${h.tag} id="${h.id}">${h.prefix ? `<span class="num">${h.prefix}</span> ` : ''}${text}</h${h.tag}>`);
      i++; continue;
    }
    if (/^\s*-{3,}\s*$/.test(l)) { i++; continue; }        // QUICKREF's page breaks
    if (/^\s*\|/.test(l)) {
      const rows = [];
      for (; i < src.length && /^\s*\|/.test(src[i]); i++) if (!isSep(src[i])) rows.push(cells(src[i]));
      const head = rows.shift();
      const blankHead = head.every(c => !c);
      let t = '<div class="tw"><table>';
      if (!blankHead) t += '<thead><tr>' + head.map(c => `<th>${inline(c)}</th>`).join('') + '</tr></thead>';
      t += '<tbody>' + rows.map(r => '<tr>' + r.map((c, k) =>
        `<td${k === 1 && /^[✔✘◑]$/.test(c) ? ' class="mark"' : ''}>${inline(c)}</td>`).join('') + '</tr>').join('') + '</tbody>';
      out.push(t + '</table></div>');
      continue;
    }
    if (/^\s*>/.test(l)) {
      const body = [];
      for (; i < src.length && /^\s*>/.test(src[i]); i++) body.push(src[i].replace(/^\s*>\s?/, ''));
      out.push(`<blockquote>${inline(body.join(' '))}</blockquote>`);
      continue;
    }
    if (/^\s*([-*+]|\d+\.)\s+/.test(l)) {
      const ordered = /^\s*\d+\./.test(l);
      const items = [];
      for (; i < src.length && src[i].trim(); i++) {
        if (/^\s*([-*+]|\d+\.)\s+/.test(src[i])) items.push(src[i].replace(/^\s*([-*+]|\d+\.)\s+/, ''));
        else items[items.length - 1] += ' ' + src[i].trim();
      }
      const tag = ordered ? 'ol' : 'ul';
      out.push(`<${tag}>` + items.map(x => `<li>${inline(x)}</li>`).join('') + `</${tag}>`);
      continue;
    }
    const para = [];
    for (; i < src.length && src[i].trim() && !/^\s*(```|#|\||>|-{3,}\s*$|[-*+]\s|\d+\.\s)/.test(src[i]); i++) para.push(src[i].trim());
    if (!para.length) { para.push(src[i].trim()); i++; }
    out.push(`<p>${inline(para.join(' '))}</p>`);
  }
  return { html: out.join('\n'), heads };
}

// ---------------------------------------------------------------------------
// Part I: QUICKREF.  Its title and the "print it and keep it by the machine"
// lines are about QUICKREF itself, so the page starts at the legend table.

const contents = [];          // [{level, prefix, text, id}]
let ch = 0, sec = 0;
const quick = lines(path.join(ROOT, 'QUICKREF.md'));
const legendAt = quick.findIndex(l => /^\|\s*Mark\s*\|/.test(l));
const firstH2 = quick.findIndex(l => /^##\s/.test(l));
const legendMd = quick.slice(legendAt, firstH2).join('\n');
const bodyMd = quick.slice(firstH2).join('\n');

const usedIds = new Set();
function uniqueId(base) {
  let id = base || 'x', n = 2;
  while (usedIds.has(id)) id = base + '-' + n++;
  usedIds.add(id);
  return id;
}
const sectionOf = {};          // heading id -> its contents prefix, for the index
let currentHead = null;
const part1 = render(bodyMd, (level, text) => {
  let prefix, tag;
  if (level <= 2) { ch++; sec = 0; prefix = `${ch}.`; tag = 2; }
  else { sec++; prefix = `${ch}.${sec}`; tag = 3; }
  const h = { level: tag, prefix, text, id: uniqueId('q-' + slug(text)), tag };
  contents.push(h);
  return h;
});
const legend = render(legendMd, () => ({ tag: 4, id: uniqueId('legend') }));

// The index: every backquoted word of upper-case letters, by the section it
// is in.  Walk QUICKREF again, tracking which numbered heading we are under.
const index = new Map();       // term -> Set of heading ids
{
  let k = -1, fence = false;
  for (const l of quick.slice(firstH2)) {
    if (/^\s*```/.test(l)) { fence = !fence; continue; }
    if (fence) continue;
    if (/^#{1,4}\s/.test(l)) { k++; continue; }
    for (const m of l.matchAll(/`([^`]+)`/g)) {
      for (let term of m[1].split(/\s*\/\s*|\s*\.\.\.\s*|,\s*/)) {
        term = term.replace(/^\[|\]$/g, '').trim();
        if (!/^[A-Z][A-Z0-9-]*( [A-Z][A-Z0-9-]*)*$/.test(term) || term.length < 2) continue;
        if (!index.has(term)) index.set(term, new Set());
        index.get(term).add(contents[k].id);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Appendix A: the limits, each read from the EQU that sets it.

function findEqu(file, sym) {
  const L = lines(path.join(SRC, file));
  const re = new RegExp('^' + sym + '\\s+EQU\\s+(\\S+)');
  for (let n = 0; n < L.length; n++) {
    const m = re.exec(L[n]);
    if (m) {
      const v = m[1].startsWith('$') ? parseInt(m[1].slice(1), 16) : parseInt(m[1], 10);
      return { v, where: `${file}:${n + 1}`, sym };
    }
  }
  warnings.push(`limit ${sym} not found in ${file}`);
  return null;
}
// ...and the few with no EQU of their own, read from the error text that
// enforces them (ERRMSG.S), so the number is still the machine's own.
function fromError(no, re) {
  const e = errors.find(x => x.no === no);
  const m = e && re.exec(e.text);
  if (!m) { warnings.push(`limit from error ${no} not found`); return null; }
  return { v: +m[1], where: `ERRMSG.S, error ${no}`, sym: '' };
}

// ---------------------------------------------------------------------------
// Appendix B: the compiler errors.  ERTAB is a count byte and the text for
// each number in order; a "* n: why" comment above an entry is kept as its
// note (dates dropped).

const errors = [];
{
  const L = lines(path.join(SRC, 'ERRMSG.S'));
  const start = L.findIndex(l => /^ERTAB\b/.test(l));
  const max = findEqu('ERRMSG.S', 'ERMAX');
  let note = '', range = null;
  for (let n = start; n < L.length && errors.length < (max ? max.v : 99); n++) {
    const l = L[n];
    let m;
    if ((m = /^\*\s*(\d+)(?:-(\d+)|, (\d+))?\s*:?\s*(.*)$/.exec(l))) {
      const lo = +m[1], hi = +(m[2] || m[3] || m[1]);
      note = m[4].replace(/\s*\(([^)]*?)?\d{4}-\d\d-\d\d\)\s*$/, '').replace(/^\s*-\s*/, '');
      range = [lo, hi];
      continue;
    }
    if (/^\*/.test(l)) { if (note) note += ' ' + l.replace(/^\*\s*/, ''); continue; }
    if ((m = /^\s+ASC\s+'(.*)'\s*$/.exec(l))) {
      const no = errors.length + 1;
      const own = range && no >= range[0] && no <= range[1];
      errors.push({ no, text: m[1].trim(), note: own ? note.trim() : '', where: `ERRMSG.S:${n + 1}` });
      if (range && no >= range[1]) { note = ''; range = null; }
    }
  }
  if (!errors.length) warnings.push('no ERTAB entries found');
}
// The comments are written for whoever reads the 6502: drop the dates and the
// "(CMPSET PDAMN)"-style pointers into the source, which mean nothing to a
// programmer.  22, 26 internal; 31, 32 the lexer's (ERRMSG.S header says so).
for (const e of errors) {
  e.note = e.note
    .replace(/\s*\((?:[A-Z0-9.]+(?: [A-Z0-9]+)*)?(?:,?\s*\d{4}-\d\d-\d\d)?\)/g, '')
    .replace(/\s+/g, ' ').trim();
  if (/^INTERNAL ERROR/.test(e.text)) e.note = e.note || 'not raised by anything; the number is kept so the others do not move';
  if (e.no === 31 || e.no === 32) e.note = 'the lexer’s: it reports 30 + its own code';
}

// Which test programs raise which error: the file name (e33.cob, sz49.cob),
// a comment near the top ("error 48 at line 7", "15 at line 10"), or the
// expected-output lines in tools/emu/README.txt ("notat   error 12 ...").
const raisedBy = {};
const addTest = (no, name) => { (raisedBy[no] = raisedBy[no] || new Set()).add(name); };
for (const f of fs.readdirSync(PROGS).filter(f => /\.cob$/i.test(f))) {
  const name = f.replace(/\.cob$/i, '');
  let m;
  if ((m = /^(?:e|sz)(\d+)[a-d]?$/i.exec(name))) addTest(+m[1], name);
  const head = lines(path.join(PROGS, f)).slice(0, 6).filter(l => /^\s*\*/.test(l)).join(' ');
  if ((m = /\berror (\d+)\b/i.exec(head)) || (m = /:\s*(\d+) at line\b/.exec(head))) addTest(+m[1], name);
}
for (const l of lines(path.join(ROOT, 'tools', 'emu', 'README.txt'))) {
  const m = /^\s+([a-z0-9]+)\s+error (\d+)\b/.exec(l);
  if (m) addTest(+m[2], m[1]);
}

// ---------------------------------------------------------------------------
// Appendix C: the run-time messages.  The text is VMTAIL's; where each one
// is raised is found by searching the interpreter for "#<label".  The "when"
// line is the condition at that place, said once here.

const stops = [
  ['MSIG', 'stop', 'The file to run does not start with the object signature PCB1, version 1 - it is not something the compiler made.'],
  ['MLANG', 'stop', 'The object’s header (byte 19) says it was made for a different interpreter.'],
  ['MBIG', 'stop', 'The object’s code and data would reach the file buffers at $B000. The compiler refuses such a program (error 49); this catches one built before that check.'],
  ['MOPC', 'stop', 'A byte that is not an instruction - every unused opcode traps here rather than running on into data.'],
  ['MESTK', 'stop', 'The expression stack overflowed or was popped while empty.'],
  ['MRSTK', 'stop', 'PERFORMs nested past the limit, or a return with no PERFORM pending.'],
  ['MDIV0', 'stop', 'A zero divisor in a statement with no ON SIZE ERROR clause.'],
  ['MSIZE', 'stop', 'A result too big for its receiver (more integer digits than its PICTURE, or over 14 digits) with no ON SIZE ERROR clause.'],
  ['MSUBR', 'stop', 'A subscript below 1 or past the table’s OCCURS.'],
  ['MEND', 'msg', 'The program reached STOP RUN (or GOBACK). Output stays on the screen until a key is pressed.'],
  ['MPAUSE', 'msg', 'SET PRINTER TO SCREEN: a page is full, or DISPLAY ERASE UPON PRINTER started a new one.'],
];
const vmTail = lines(path.join(SRC, 'VMTAIL.S'));
const vmFiles = fs.readdirSync(SRC).filter(f => /^VM.*\.S$/.test(f));
const stopRows = stops.map(([label, kind, when]) => {
  const at = vmTail.findIndex((l, n) => new RegExp('^' + label + '\\s+DFB').test(l));
  let text = '?';
  if (at < 0) warnings.push(`message ${label} not found in VMTAIL.S`);
  else text = (/ASC\s+'(.*)'/.exec(vmTail[at + 1]) || [, '?'])[1].trim();
  const where = [];
  for (const f of vmFiles) lines(path.join(SRC, f)).forEach((l, n) => {
    if (new RegExp('#<' + label + '\\b').test(l)) where.push(`${f}:${n + 1}`);
  });
  if (!where.length) warnings.push(`${label} is raised nowhere`);
  return { label, kind, when, text, where };
});

// ---------------------------------------------------------------------------
// Appendix A's table, now that errors[] exists.

const limitSpec = [
  ['Characters in a name', () => findEqu('SYMAUX.S', 'SYNL'), 'error 48'],
  ['Names in one program (data, condition, paragraph and file names together)', () => findEqu('SYMAUX.S', 'SYMAX'), 'error 5'],
  ['Data items in one program', () => findEqu('CMPCON.S', 'DESCMX'), 'error 2'],
  ['Letters in one word', () => findEqu('CMPCON.S', 'TOKMAX'), 'error 32'],
  ['Bytes in one item or record', () => fromError(33, /OVER (\d+) BYTES/), 'error 33'],
  // DDPUSH said nothing past LVLMAX until this table was built; error 51
  // since 2026-11-22 (FIXLIST A21)
  ['Group levels open at once', () => findEqu('CMPDATA.S', 'LVLMAX'), 'error 51'],
  ['Files SELECTed in one program', () => fromError(17, /\((\d+) MAXIMUM\)/), 'error 17'],
  ['Subscripts in one statement', () => fromError(39, /OVER (\d+) SUBSCRIPTS/), 'error 39'],
  ['IF statements nested', () => findEqu('CMPPROC.S', 'IFMAX'), 'error 14'],
  ['EVALUATE statements nested', () => findEqu('CMPPROC3.S', 'EVMAX'), 'error 27'],
  ['Parentheses nested in one COMPUTE', () => findEqu('CMPPROC3.S', 'CEMAX'), 'error 25'],
  ['Bytes of p-code in one program', () => findEqu('CMPCON.S', 'CODMAX'), 'error 1'],
  ['Bytes of object and data together', () => findEqu('EQUATES2.S', 'RUNMAX'), 'error 49'],
  ['PERFORMs pending at once, at run time', () => findEqu('VM.S', 'VMRDEP'), 'PERFORM stack fault'],
  ['Values on the expression stack, at run time', () => findEqu('VM.S', 'VMEDEP'), 'Expression stack fault'],
  ['Lines in one menu (.MNU)', () => findEqu('FMTMNU.S', 'MNMAX'), 'refused in FORMAT'],
  ['Records one QUERY can hold', () => findEqu('VMQRY.S', 'QMAXE'), ''],
  ['Conditions in one query (QUERY designer)', () => findEqu('QUERY.S', 'MAXCOND'), ''],
  ['Sort keys in one query (QUERY designer)', () => findEqu('QUERY.S', 'MAXKEY'), ''],
];
const limits = limitSpec.map(([what, get, how]) => ({ what, how, r: get() }));

// ---------------------------------------------------------------------------
// Appendix D: ProDOS 8 MLI error codes.  The Utilities print "ProDOS error
// $nn" (UTILD.S) and FILE STATUS "30" stands for any of these.

const prodos = [
  ['$00', 'No error'], ['$01', 'Bad system call number'], ['$04', 'Bad system call parameter count'],
  ['$25', 'Interrupt vector table full'], ['$27', 'I/O error'], ['$28', 'No device detected / connected'],
  ['$2B', 'Disk write protected'], ['$2E', 'Disk switched while a file was open'],
  ['$40', 'Invalid pathname syntax'], ['$42', 'File control block table full (too many files open)'],
  ['$43', 'Invalid reference number'], ['$44', 'Path not found'], ['$45', 'Volume directory not found'],
  ['$46', 'File not found'], ['$47', 'Duplicate filename'], ['$48', 'Overrun error / volume full'],
  ['$49', 'Volume directory full'], ['$4A', 'Incompatible file format'], ['$4B', 'Unsupported storage type'],
  ['$4C', 'End of file encountered'], ['$4D', 'Position out of range'], ['$4E', 'Access error (locked file)'],
  ['$50', 'File is open'], ['$51', 'Directory count error (directory damaged)'], ['$52', 'Not a ProDOS disk'],
  ['$53', 'Invalid parameter'], ['$55', 'Volume control block table full'], ['$56', 'Bad buffer address'],
  ['$57', 'Duplicate volume'], ['$5A', 'Bit map disk address is impossible (damaged volume)'],
];

// ---------------------------------------------------------------------------
// The page.

const appendix = (letter, title) => {
  const id = uniqueId('app-' + letter.toLowerCase());
  contents.push({ level: 2, prefix: `${letter}.`, text: esc(title), id });
  return `<h2 id="${id}"><span class="num">Appendix ${letter}.</span> ${esc(title)}</h2>`;
};
const bad = '<span class="stale">?</span>';
const today = new Date().toISOString().slice(0, 10);

const waitId = uniqueId('statements');
const htmlWait = `<h2 id="${waitId}"><span class="num">${ch + 1}.</span> Statement entries</h2>
<div class="pending"><p><strong>Not written yet, on purpose.</strong> This is where each verb gets the
treatment the GnuCOBOL guide gives it: a boxed general format, the rules, the limits on this machine,
and an example that has been run in AppleWin. DECISIONS §8.3 (user, 2026-11-11) holds these chapters
until the system is complete; <code>MANUALS-MAP.md</code> says which files will feed each one.</p>
<p>Until then the chapters above are the reference: every keyword the compiler accepts, with its
status, as <code>QUICKREF.md</code> has it.</p></div>`;
contents.push({ level: 2, prefix: `${ch + 1}.`, text: 'Statement entries <em>(waiting)</em>', id: waitId });

const htmlA = appendix('A', 'Limits') + `
<p>Each number is read from the source on every rebuild: the symbol and where it is set are in the last
column. “Enforced by” is what you see when a program goes past it.</p>
<div class="tw"><table><thead><tr><th>Limit</th><th class="r">Value</th><th>Enforced by</th><th>Source</th></tr></thead><tbody>
${limits.map(x => `<tr><td>${esc(x.what)}</td><td class="r">${x.r ? x.r.v.toLocaleString('en-US') : bad}</td><td>${esc(x.how)}</td><td class="src">${x.r ? esc((x.r.sym ? x.r.sym + ' ' : '') + x.r.where) : ''}</td></tr>`).join('\n')}
</tbody></table></div>`;

const htmlB = appendix('B', 'Compiler errors') + `
<p>The compiler stops at the first error and shows its number, its text and the source line. These are
the ${errors.length} texts in <code>src/ERRMSG.S</code>, in number order. “Test” names the program in
<code>tools/emu/progs</code> that raises it, where there is one.</p>
<div class="tw"><table><thead><tr><th class="r">No.</th><th>Message</th><th>Note</th><th>Test</th></tr></thead><tbody>
${errors.map(e => `<tr id="err-${e.no}"><td class="r">${e.no}</td><td><code>${esc(e.text)}</code></td><td>${esc(e.note)}</td><td class="src">${raisedBy[e.no] ? [...raisedBy[e.no]].sort().join(', ') : ''}</td></tr>`).join('\n')}
</tbody></table></div>
<p class="small">${Object.keys(raisedBy).length} of the ${errors.length} numbers have a test program of their own.</p>`;

const htmlC = appendix('C', 'Run-time messages') + `
<p>A stop prints its message and <code>at line <var>n</var></code> - the source line that was running -
waits for a key, and goes back to the menu. Open files are closed first. The texts are in
<code>src/VMTAIL.S</code>; “Raised at” is every place in the interpreter that uses each one.</p>
<h3>Stops</h3>
<div class="tw"><table><thead><tr><th>Message</th><th>When</th><th>Raised at</th></tr></thead><tbody>
${stopRows.filter(s => s.kind === 'stop').map(s => `<tr><td><code>${esc(s.text)}</code></td><td>${esc(s.when)}</td><td class="src">${s.where.join('<br>')}</td></tr>`).join('\n')}
</tbody></table></div>
<h3>Messages that are not errors</h3>
<div class="tw"><table><thead><tr><th>Message</th><th>When</th><th>Raised at</th></tr></thead><tbody>
${stopRows.filter(s => s.kind === 'msg').map(s => `<tr><td><code>${esc(s.text)}</code></td><td>${esc(s.when)}</td><td class="src">${s.where.join('<br>')}</td></tr>`).join('\n')}
</tbody></table></div>`;

const htmlD = appendix('D', 'ProDOS errors') + `
<p>The Utilities show a failed disk operation as <code>ProDOS error $<var>nn</var></code>, and a file
verb that meets one with no better name sets <code>FILE STATUS</code> to <code>"30"</code>. The codes are
ProDOS 8’s own (ProDOS 8 Technical Reference Manual).</p>
<div class="tw"><table class="narrow"><thead><tr><th>Code</th><th>Meaning</th></tr></thead><tbody>
${prodos.map(([c, t]) => `<tr><td><code>${c}</code></td><td>${esc(t)}</td></tr>`).join('\n')}
</tbody></table></div>`;

const idxId = uniqueId('index');
contents.push({ level: 2, prefix: '', text: 'Index of keywords', id: idxId });
const terms = [...index.keys()].sort((a, b) => a.localeCompare(b));
const byLetter = {};
for (const t of terms) (byLetter[t[0]] = byLetter[t[0]] || []).push(t);
const prefixOf = id => (contents.find(c => c.id === id) || {}).prefix || '?';
const htmlIdx = `<h2 id="${idxId}">Index of keywords</h2>
<div class="idx">${Object.keys(byLetter).map(L => `<h4>${L}</h4><ul>${byLetter[L].map(t =>
  `<li><code>${esc(t)}</code> ${[...index.get(t)].map(id => `<a href="#${id}">${prefixOf(id)}</a>`).join(', ')}</li>`).join('')}</ul>`).join('')}</div>`;

const toc = '<ol class="toc">' + contents.filter(c => c.level === 2).map(c => {
  const subs = contents.filter(s => s.level === 3 && s.prefix.startsWith(c.prefix) && c.prefix && !/^[A-Z]/.test(c.prefix));
  return `<li><a href="#${c.id}"><span class="num">${c.prefix}</span> ${c.text}</a>` +
    (subs.length ? '<ol>' + subs.map(s => `<li><a href="#${s.id}"><span class="num">${s.prefix}</span> ${s.text}</a></li>`).join('') + '</ol>' : '') + '</li>';
}).join('') + '</ol>';

const page = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Apple IIe COBOL Reference</title>
<meta name="generator" content="tools/refpage.js">
<script>
try { var t = localStorage.getItem('ref-theme'); if (t) document.documentElement.setAttribute('data-theme', t); } catch (e) {}
</script>
<style>
:root {
  --bg: #fdfcf8; --fg: #1d1d1b; --muted: #5d5a52; --rule: #d9d4c7; --box: #f3f0e6;
  --boxrule: #b9b19c; --link: #1f4e8c; --ok: #2c7a3f; --no: #b03a2e; --part: #a06a00;
  --head: #2b2a26; --pend: #fff6dc; --pendrule: #e0c26a;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg: #17181a; --fg: #e4e1d8; --muted: #a3a097; --rule: #3a3a3c; --box: #212224;
    --boxrule: #4b4a46; --link: #8ab4f0; --ok: #6cc583; --no: #f08a7e; --part: #e2b04a;
    --head: #f1eee6; --pend: #2a2618; --pendrule: #7a6624;
  }
}
:root[data-theme="dark"] {
  --bg: #17181a; --fg: #e4e1d8; --muted: #a3a097; --rule: #3a3a3c; --box: #212224;
  --boxrule: #4b4a46; --link: #8ab4f0; --ok: #6cc583; --no: #f08a7e; --part: #e2b04a;
  --head: #f1eee6; --pend: #2a2618; --pendrule: #7a6624;
}
* { box-sizing: border-box; }
html { scroll-padding-top: 1rem; }
body { margin: 0; background: var(--bg); color: var(--fg);
  font: 17px/1.55 Georgia, "Times New Roman", serif; }
main { max-width: 860px; margin: 0 auto; padding: 0 16px 4rem; }
header.top { border-bottom: 3px double var(--rule); padding: 2rem 0 1rem; margin-bottom: 1.5rem; position: relative; }
header.top h1 { font-size: 2rem; margin: 0 0 .25rem; color: var(--head); line-height: 1.2; padding-right: 5.5rem; }
header.top .sub { color: var(--muted); margin: 0; }
#theme { position: absolute; top: 2rem; right: 0; font: 14px system-ui, sans-serif; background: var(--box);
  color: var(--fg); border: 1px solid var(--boxrule); border-radius: 4px; padding: .3rem .6rem; cursor: pointer; }
h2 { font-size: 1.45rem; color: var(--head); border-bottom: 1px solid var(--rule); padding-bottom: .2rem; margin-top: 3rem; }
h3 { font-size: 1.15rem; color: var(--head); margin-top: 2rem; }
h4 { margin: 1.2rem 0 .3rem; }
.num { color: var(--muted); font-weight: normal; }
a { color: var(--link); }
code, pre, .src { font-family: Consolas, "Courier New", monospace; }
code { font-size: .88em; }
pre { background: var(--box); border: 1px solid var(--boxrule); padding: .8rem 1rem; overflow-x: auto;
  font-size: 14px; line-height: 1.4; }
pre.cobol { border-left: 4px solid var(--boxrule); }
.tw { overflow-x: auto; margin: 1rem 0; }
table { border-collapse: collapse; width: 100%; font-size: 15px; }
table.narrow { width: auto; }
th, td { border-bottom: 1px solid var(--rule); padding: .35rem .6rem; text-align: left; vertical-align: top; }
th { border-bottom: 2px solid var(--boxrule); font-family: system-ui, sans-serif; font-size: 13px;
  text-transform: uppercase; letter-spacing: .03em; color: var(--muted); }
td.r, th.r { text-align: right; white-space: nowrap; }
td.mark { text-align: center; width: 2rem; }
td.src { font-size: 12.5px; color: var(--muted); white-space: nowrap; }
.ok { color: var(--ok); font-weight: bold; } .no { color: var(--no); font-weight: bold; }
.part { color: var(--part); font-weight: bold; }
.stale { color: var(--no); font-weight: bold; }
blockquote { margin: 1rem 0; padding: .6rem 1rem; background: var(--box); border-left: 4px solid var(--boxrule); }
.pending, .about { background: var(--pend); border: 1px solid var(--pendrule); padding: .2rem 1rem; border-radius: 4px; }
.about { font-size: 15px; }
.small { font-size: 14px; color: var(--muted); }
ol.toc, ol.toc ol { list-style: none; padding-left: 0; }
ol.toc ol { padding-left: 1.6rem; font-size: 15px; }
ol.toc a { text-decoration: none; }
ol.toc li { margin: .15rem 0; }
.idx { columns: 3 14rem; column-gap: 2rem; font-size: 14px; }
.idx h4 { break-after: avoid; } .idx ul { list-style: none; padding: 0; margin: 0; }
.idx li { break-inside: avoid; }
@media print { #theme { display: none; } body { font-size: 11pt; } h2 { break-before: page; } a { color: inherit; } }
</style>
</head>
<body>
<main>
<header class="top">
<h1>Apple IIe COBOL Reference</h1>
<p class="sub">The language, its limits and its messages, for the COBOL system on a 128K Apple IIe.</p>
<button id="theme" type="button" aria-label="Switch light or dark">Dark</button>
</header>

<div class="about">
<p><strong>About this page.</strong> Built ${today} by <code>tools/refpage.js</code> from the project's own
files - do not edit it by hand; change the source and rebuild. The language chapters are
<code>QUICKREF.md</code>; the limits, the compiler errors and the run-time messages are read out of the
6502 source, so they are the numbers and texts the machine really uses. The statement entries wait
for the system to be complete (DECISIONS §8.3).</p>
</div>
${legend.html}

<h2 id="contents">Contents</h2>
${toc}

${part1.html}
${htmlWait}
${htmlA}
${htmlB}
${htmlC}
${htmlD}
${htmlIdx}
</main>
<script>
(function () {
  var b = document.getElementById('theme'), root = document.documentElement;
  function current() {
    var t = root.getAttribute('data-theme');
    if (t) return t;
    return window.matchMedia && matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }
  function label() { b.textContent = current() === 'dark' ? 'Light' : 'Dark'; }
  b.addEventListener('click', function () {
    var t = current() === 'dark' ? 'light' : 'dark';
    root.setAttribute('data-theme', t);
    try { localStorage.setItem('ref-theme', t); } catch (e) {}
    label();
  });
  label();
})();
</script>
</body>
</html>
`;

fs.writeFileSync(OUT, page);
console.log(`REFERENCE.html: ${contents.length} headings, ${errors.length} errors, ` +
  `${stopRows.length} run-time messages, ${limits.length} limits, ${terms.length} index terms`);
for (const w of warnings) console.log('WARNING: ' + w);
