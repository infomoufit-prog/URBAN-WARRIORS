import fs from 'node:fs';
import path from 'node:path';
const root=path.resolve(new URL('..',import.meta.url).pathname);
const input=path.join(root,'docs/i18n/remediation/RB02_EN_EXACT.tsv');
const out=path.join(root,'web/js/i18n/legacy-copy-en-rb02-exact.js');
const lines=fs.readFileSync(input,'utf8').split(/\r?\n/).filter(Boolean);
const map={};
for(const [idx,line] of lines.entries()){
  const p=line.indexOf('\t');if(p<0)throw new Error(`Line ${idx+1}: expected tab`);
  const es=line.slice(0,p),en=line.slice(p+1);
  if(!es||!en)throw new Error(`Line ${idx+1}: empty source/target`);
  map[es]=en;
}
fs.writeFileSync(out,`export const LEGACY_EN_RB02_EXACT = Object.freeze(${JSON.stringify(map,null,2)});\nexport default LEGACY_EN_RB02_EXACT;\n`);
console.log(`RB02 exact English copy: ${Object.keys(map).length} phrase(s)`);
