const fs=require('fs');
const zp=new Set();
['EQUATES.S','EQUATES2.S'].map(f=>fs.readFileSync(f,'utf8')).join('\n').split(/\r?\n/).forEach(l=>{
 const m=l.match(/^([A-Za-z][A-Za-z0-9]*)\s+EQU\s+\$([0-9A-Fa-f]{1,2})\s*$/); if(m)zp.add(m[1]);});
fs.readFileSync('VM.S','utf8').split(/\r?\n/).forEach(l=>{
 const m=l.match(/^([A-Za-z][A-Za-z0-9]*)\s+EQU\s+ZPDRV/); if(m)zp.add(m[1]);});
const IMPL=new Set('RTS RTI INX INY DEX DEY TAX TAY TXA TYA TSX TXS CLC SEC CLD SED CLI SEI CLV NOP PHA PLA PHP PLP PHX PLX PHY PLY'.split(' '));
const ACC=new Set('ASL LSR ROL ROR'.split(' '));
const BR=new Set('BCC BCS BEQ BNE BMI BPL BVC BVS BRA'.split(' '));
const OPS=new Set(('LDA LDX LDY STA STX STY STZ ADC SBC AND ORA EOR CMP CPX CPY INC DEC ASL LSR ROL ROR JMP JSR BIT TRB TSB '+[...IMPL].join(' ')+' '+[...BR].join(' ')).split(/\s+/));
function build(name,base,ceil,files,floors){
 const defs=new Map(),rows=[],dup=[],probs0=[];
 for(const f of ['EQUATES.S','EQUATES2.S',...files]){
  fs.readFileSync(f,'utf8').split(/\r?\n/).forEach((ln,i)=>{
   if(/^\*/.test(ln)||!ln.trim())return;
   const m=ln.match(/^([A-Za-z][A-Za-z0-9]*)/);
   const body=ln.replace(/^([A-Za-z][A-Za-z0-9]*)?\s+/,'').trim();
   const op=body.split(/\s+/)[0],arg=body.slice(op.length).trim();
   if(m){if(defs.has(m[1]))dup.push(`${m[1]}: ${defs.get(m[1])} / ${f}:${i+1}`);else defs.set(m[1],`${f}:${i+1}`);}
   if(!/^EQUATES2?\.S$/.test(f))rows.push({f,n:i+1,label:m?m[1]:null,op,arg,raw:ln.trim(),len:ln.length});});}
 // DS sizes are often a symbol (EXPOUT DS EXPMAX is 3,000 bytes).  The
 // first version counted those as zero and put FORMAT's end 2,908 bytes
 // low; Merlin32 caught it on 2026-11-07.  Resolve simple EQU chains -
 // numbers, symbols, + and - - and count what resolves.
 const eq=new Map(),val=new Map();
 for(const f of ['EQUATES.S','EQUATES2.S',...files])
  fs.readFileSync(f,'utf8').split(/\r?\n/).forEach(ln=>{
   const m=ln.match(/^([A-Za-z][A-Za-z0-9]*)\s+(?:EQU|=)\s+(\S+)/);if(m)eq.set(m[1],m[2]);});
 const ev=x=>{const t=x.match(/\$[0-9A-Fa-f]+|\d+|[A-Za-z][A-Za-z0-9]*|[-+]/g);
  if(!t||t.join('')!==x)return null;let v=0,s=1;
  for(const k of t){if(k==='+'){s=1;continue;}if(k==='-'){s=-1;continue;}
   const n=k[0]==='$'?parseInt(k.slice(1),16):/^\d/.test(k)?+k:val.has(k)?val.get(k):null;
   if(n===null)return null;v+=s*n;}return v;};
 for(let p=0;p<20;p++)for(const[k,x]of eq)if(!val.has(k)){const v=ev(x);if(v!==null)val.set(k,v);}
 // DS operands Merlin takes that ev() does not: * as the location
 // counter ($30C0-*, LIB's jump-table fill) and A*B, a product of two
 // terms (QCTXT DS MAXCOND*MAXLIT).  Added 2026-11-20, when the
 // estimate put LIB 57 bytes over a ceiling the real object was under.
 const dsv=(x,here)=>{x=x.replace(/(^|[-+])\*(?=$|[-+])/g,
   (m,p)=>p+'$'+here.toString(16));
  const m=x.match(/^([^*]+)\*([^*]+)$/);
  if(m){const p=ev(m[1]),q=ev(m[2]);return p===null||q===null?null:p*q;}
  return ev(x);};
 let pc=0;const addr=new Map(),brs=[];
 for(const r of rows){
  if(r.label)addr.set(r.label,pc);
  let sz=0;const{op,arg}=r;
  if(op==='DS'){const a0=arg.split(',')[0].trim();
    const v=dsv(a0,base+pc);if(v!==null)sz=v;
    else probs0.push(`DS SIZE UNKNOWN ${r.f}:${r.n}  ${r.raw}`);}
  else if(op==='DFB')sz=arg.split(',').length;
  else if(op==='DA')sz=arg.split(',').length*2;
  else if(op==='ASC'){const t=arg.match(/'([^']*)'/);sz=t?t[1].length:0;}
  else if(!OPS.has(op))sz=0;
  else if(IMPL.has(op))sz=1;
  else if(BR.has(op)){sz=2;brs.push({r,from:pc+2});}
  else if(ACC.has(op)&&!arg)sz=1;
  else if(/^#/.test(arg)||/^\(/.test(arg))sz=2;
  // zero page: a $xx EQU in EQUATES, or (2026-11-20) any symbol whose EQU
  // chain resolves below $100 - STRPTR EQU ZPT1 was counted as 3 bytes
  else{const b=arg.replace(/[()]/g,'').split(',')[0].split('+')[0].split('-')[0].trim();
       sz=(op!=='JMP'&&op!=='JSR'&&(zp.has(b)||(val.has(b)&&val.get(b)<256)||/^\$[0-9A-Fa-f]{1,2}$/.test(b)))?2:3;}
  pc+=sz;}
 const probs=[...probs0];
 dup.forEach(d=>probs.push('DUP '+d));
 rows.filter(r=>r.len>64).forEach(r=>probs.push(`LONG ${r.f}:${r.n}`));
 for(const r of rows){if(!OPS.has(r.op))continue;
  let a=r.arg.replace(/^#[<>]?/,'').replace(/[()]/g,'').split(',')[0].trim();
  if(!a||/^\$/.test(a)||/^\d/.test(a))continue;
  const b=a.split(/[-+*/&!.]/)[0];
  if(!b)continue;
  if(!defs.has(b))probs.push(`UNDEF ${b}  ${r.f}:${r.n}  ${r.raw}`);}
 for(const b of brs){const t=addr.get(b.r.arg.trim());if(t===undefined)continue;
  const d=t-b.from;if(d<-128||d>127)probs.push(`RANGE ${d}  ${b.r.f}:${b.r.n}  ${b.r.raw}`);}
 const end=base+pc, ok=end<=ceil;
 console.log(name.padEnd(9), String(pc).padStart(6),
  ' end $'+end.toString(16).toUpperCase(),
  ' ceil $'+ceil.toString(16).toUpperCase(),
  ok?(' FITS  '+(ceil-end)+' spare'):(' OVER by '+(end-ceil)));
 // floors: [label, lowest address it may have] - SYMAUX must sit above
 // $E000, where the card's $D000 bank switch cannot take it away (2026-11-11)
 for(const [lab,min] of (floors||[])){const a=addr.get(lab);
  if(a===undefined||base+a<min)probs.push('BELOW '+lab+' must be at $'+min.toString(16).toUpperCase()+' or above');}
 probs.forEach(p=>console.log('   '+p));
}
build('LIB',0x3000,0x6000,['LIB.S','TEXTDRV.S','FILEIO.S','CATALOG.S','GATE.S','BANKS.S','CONSOLE.S','DSCREEN.S','AUXMEM.S','NUMFMT.S','SELECT.S','SELECT2.S','SORT.S','PRINTER.S','DATIME.S','CLOCK.S','RECMAN.S','SCRSHOW.S','SCRINP.S','CLASS.S','ABORT.S']);
// COBOL.AUX: runs from the auxiliary language card (GATE.S); must end below
// the prefix table at $F800 (PREFIX.S), and so below the card's interrupt
// vectors at $FFFA.  The symbol table's names are in the card's other $D000
// bank (SYMAUX.S), which is why SYAUX has a floor.
build('AUXLC',0xD000,0xF800,['AUXLC.S','BCD.S','PICTURE.S','ERRMSG.S','PREFIX.S','SYMAUX.S'],[['SYAUX',0xE000]]);
build('COBOLSYS',0x2000,0x3000,['COBOLSYS.S','SYSBOOT.S','SYSLOAD.S','SYSMENU.S','SYSUTIL.S']);
build('UTIL',0xA000,0xB000,['UTIL.S','UTILD.S']);
build('EDIT',0x6000,0x9800,['EDIT.S','EDITENT.S','EDITRNG.S','EDITSHF.S','EDITDRW.S','EDITRUL.S','EDITCUR.S','EDITDSP.S','EDITCMD.S','EDITIO.S','EDITBAR.S','EDITVW.S','EDITPRT.S','EDITPLC.S','EDITCLP.S','EDITVAR.S']);
build('FORMAT',0x8000,0xB000,['FORMAT.S','PRODOS.S','DISKIO.S','PROMPT.S','SCREXP.S','SCRPRV.S','FMTMNU.S','FORMATD.S']);
build('QUERY',0x8000,0xB000,['QUERY.S','PRODOS.S','PROMPT.S','QRYENT.S','QRYADD.S','QRYIO.S','QRYVAR.S']);
build('REPORT',0x6000,0x97E0,['REPORT.S','PROMPT.S','RPTENT.S','RPTDRW.S','RPTADD.S','RPTIO.S','RPTEXP.S','RPTBAR.S','RPTVAR.S']);
build('VM',0x6000,0x8000,['VM.S','VMCORE.S','VMLOOP.S','VMMOVE.S','VMMATH.S','VMFLOW.S','VMSCRN.S','VMQRY.S','VMFILE.S','VMTAIL.S']);
build('COMPILE1',0x6000,0xA500,['COMPILE1.S','CMPCON.S','CMPEMIT.S','CMPCOM.S','CMPLEX.S','CMPSYM.S','CMPPIC.S','CMPDATA.S','CMPDATA2.S','CMPFILE.S','CMPENV.S','CMPVAR.S']);
// COMPILE2 may run to OBCODE ($A500) since the .MNU is streamed (2026-11-11)
build('COMPILE2',0x6000,0xA500,['COMPILE2.S','CMPCON.S','CMPEMIT.S','CMPCOM.S','CMPOBJ.S','CMPLEX.S','CMPSYM.S','CMPPROC.S','CMPPROC2.S','CMPPROC3.S','CMPPROC4.S','CMPARITH.S','CMPSET.S','CMPCOND.S','CMPVAR.S']);
build('QRYTEST',0x8000,0xB000,['QRYTEST.S']);
build('KEYTEST',0x8000,0xB000,['KEYTEST.S']);
build('OBJTEST',0x8000,0xB000,['OBJTEST.S','CMPCON.S','CMPEMIT.S','CMPOBJ.S','CMPVAR.S']);
build('LEXTEST',0x8000,0xB000,['LEXTEST.S','CMPCON.S','CMPLEX.S','CMPVAR.S']);
build('BCDTEST',0x8000,0xB000,['BCDTEST.S']);
build('PICTEST',0x8000,0xB000,['PICTEST.S']);

// The interpreter's dispatch table is two halves of exactly 256 bytes.
// A half that is one entry short shifts every opcode above the mistake
// by one, and the machine then runs the wrong handler for the rest of
// the program.  That is the worst failure mode in the tree and it is
// one a static pass can rule out completely, so it does.
function vmtable() {
  const L = fs.readFileSync('VMTAIL.S', 'utf8').split(/\r?\n/);
  let cur = null; const n = {};
  for (const ln of L) {
    const lb = ln.match(/^(VTLO|VTHI)\s/);
    if (lb) { cur = lb[1]; n[cur] = 0; }
    if (!cur) continue;
    let m;
    if ((m = ln.match(/^(?:VTLO|VTHI)?\s*DFB\s+(.+)$/))) n[cur] += m[1].split(',').length;
    else if ((m = ln.match(/^\s*DS\s+(\d+),/))) n[cur] += +m[1];
    else if (/^\s*$/.test(ln) || /^\*/.test(ln)) continue;
    else if (/^[A-Za-z]/.test(ln)) cur = null;
  }
  for (const h of ['VTLO', 'VTHI'])
    if (n[h] !== 256) console.log(`   TABLE ${h} has ${n[h]} entries, must be 256`);
}
vmtable();

// Merlin 8 cannot PUT a file over about 24K: it fails with MEMORY IN
// USE, blamed on a line inside the file (EQUATES.S at 31K, 2026-11-07;
// DBLAYER.S at 46K before it).  22K has always worked.  Merlin32 has
// no such limit, so this is the only place it gets caught.
for (const f of fs.readdirSync('.').filter(f => /\.S$/.test(f))) {
  const n = fs.statSync(f).size;
  if (n > 24000) console.log(`   TOO BIG FOR MERLIN 8 ${f} ${n} bytes - split it`);
  else if (n > 22000) console.log(`   NEAR MERLIN 8 LIMIT ${f} ${n} bytes`);
}

// Merlin 8 cannot use a label as a DS fill byte.  DS 12,<VBAD gave
// "Unknown label" and two bytes instead of twelve (VMTAIL.S, 2026-11-07,
// 20 lines, VM 332 bytes short).  A number is fine: DS $30C0-*,$60.
for (const f of fs.readdirSync('.').filter(f => /\.S$/.test(f)))
  fs.readFileSync(f, 'utf8').split(/\r?\n/).forEach((l, i) => {
    if (/^[A-Za-z0-9]*\s+DS\s+[^\s,]+,[^\s]*[A-Za-z]/.test(l))
      console.log(`   DS FILL IS A LABEL ${f}:${i + 1}  ${l.trim()} - Merlin 8 cannot`);
  });
