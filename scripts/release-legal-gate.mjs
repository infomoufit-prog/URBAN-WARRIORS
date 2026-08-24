import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const files=['web/privacy.html','web/terms.html','web/child-safety.html','CHILD_SAFETY_RESPONSE_RUNBOOK_20071.md','PRIVACY_PROCESSING_REGISTER_DRAFT_20071.md','PILOT_LEGAL_CONTROLLER_TEMPLATE_20070.md'];
const unresolved=new Map();
for(const rel of files){
  const text=fs.readFileSync(path.join(root,rel),'utf8');
  for(const match of text.matchAll(/\[\[(KOMBAX_[A-Z0-9_]+)\]\]/g)){
    const token=match[1],list=unresolved.get(token)||[];
    if(!list.includes(rel))list.push(rel);
    unresolved.set(token,list);
  }
}
if(unresolved.size){
  console.error(`RELEASE BLOCKED: faltan ${unresolved.size} datos legales/contacto obligatorios:`);
  for(const [token,refs] of unresolved)console.error(` - [[${token}]] · ${refs.join(', ')}`);
  process.exit(2);
}
console.log('KOMBAX release legal gate: PASS');
