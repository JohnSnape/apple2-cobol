const fs=require('fs');
const CR='\r';
function isSep(l){return /^\s*\|[\s:|-]*\|\s*$/.test(l)&&/-/.test(l);}
function cells(line){const sp=[];const m=line.replace(/`[^`]*`/g,x=>{sp.push(x);return '\u0000'+(sp.length-1)+'\u0000';});
 return m.trim().replace(/^\|/,'').replace(/\|$/,'').split('|').map(c=>c.trim().replace(/\u0000(\d+)\u0000/g,(_,i)=>sp[+i]));}
for(const f of process.argv.slice(2)){
 const src=fs.readFileSync(f,'utf8').split(/\r?\n/);
 const out=[];let para=[],fence=false;
 const flush=()=>{if(para.length){out.push(para.join(' ').replace(/[ \t]+/g,' ').trim());para=[];}};
 for(const line of src){
  if(/^\s*```/.test(line)){flush();out.push(line.trimEnd());fence=!fence;continue;}
  if(fence){out.push(line.replace(/\s+$/,''));continue;}
  if(!line.trim()){flush();continue;}
  if(isSep(line))continue;
  if(/^\s*\|/.test(line)){flush();out.push(cells(line).join('\t'));continue;}
  if(/^\s*#/.test(line)||/^\s*(-{3,})\s*$/.test(line)){flush();out.push(line.trim());continue;}
  if(/^\s*([-*+]\s+|\d+\.\s+)/.test(line)){flush();para.push(line.trim());continue;}
  para.push(line.trim());}
 flush();
 fs.writeFileSync(f.replace(/\.md$/,'.txt'),out.join(CR)+CR);
 console.log(f,'->',f.replace(/\.md$/,'.txt'));}
