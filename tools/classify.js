const fs=require('fs');
const stubs={
 'LIB.S':'LIB','COBOLSYS.S':'COBOLSYS','EDIT.S':'EDIT','FORMAT.S':'FORMAT',
 'QUERY.S':'QUERY','REPORT.S':'REPORT','VM.S':'VM','COMPILE1.S':'COMPILE1','COMPILE2.S':'COMPILE2'};
const harness=['QRYTEST.S','KEYTEST.S','OBJTEST.S','LEXTEST.S','AXTEST.S','PG2TEST.S','BCDTEST.S','PICTEST.S'];
const owner={};
for(const s of Object.keys(stubs).concat(harness)){
  if(!fs.existsSync(s))continue;
  fs.readFileSync(s,'utf8').split(/\r?\n/).forEach(l=>{
    const m=l.match(/^\s+PUT\s+([A-Z0-9]+)/);
    if(m){const f=m[1]+'.S';(owner[f]=owner[f]||[]).push(stubs[s]||s.replace('.S',''));}});
}
const all=fs.readdirSync('.').sort();
const out={stub:[],lib:[],shared:[],prog:{},harn:[],data:[],orphan:[]};
for(const f of all){
  if(/\.COB$/.test(f)){out.data.push(f);continue;}
  if(!/\.S$/.test(f))continue;
  if(stubs[f]){out.stub.push(f);continue;}
  if(harness.includes(f)){out.harn.push(f);continue;}
  const o=owner[f];
  if(!o){out.orphan.push(f);continue;}
  const u=[...new Set(o)];
  if(u.length>1){out.shared.push(f+'  ['+u.join(' ')+']');continue;}
  (out.prog[u[0]]=out.prog[u[0]]||[]).push(f);
}
console.log('STUBS ('+out.stub.length+'):  '+out.stub.join(' '));
console.log();
for(const [k,v] of Object.entries(out.prog))
  console.log(k.padEnd(9)+'('+v.length+'):  '+v.join(' '));
console.log();
console.log('SHARED by >1 program ('+out.shared.length+'):');
out.shared.forEach(x=>console.log('   '+x));
console.log();
console.log('HARNESSES ('+out.harn.length+'):  '+out.harn.join(' '));
console.log('DATA ('+out.data.length+'):  '+out.data.join(' '));
console.log('PUT BY NOTHING ('+out.orphan.length+'):  '+out.orphan.join(' '));
