import {readFile,readdir} from 'node:fs/promises';import {resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const sql=await readFile(resolve(root,'supabase/migrations/015_mutation_governance_v160.sql'),'utf8');
const blocks=[...sql.matchAll(/if p_operation not in \(([\s\S]*?)\) then/g)].map(m=>m[1]);
const allowedBlock=blocks.sort((a,b)=>b.length-a.length)[0];if(!allowedBlock)throw new Error('No se pudo leer allowlist SQL');
const allowed=new Set([...allowedBlock.matchAll(/'([^']+)'/g)].map(m=>m[1]));
async function files(dir){const out=[];for(const e of await readdir(dir,{withFileTypes:true})){const p=resolve(dir,e.name);if(e.isDirectory())out.push(...await files(p));else if(p.endsWith('.js'))out.push(p)}return out}
const used=new Set();for(const file of await files(resolve(root,'web/js'))){const text=await readFile(file,'utf8');for(const rx of [/mutation\('([^']+)'/g,/bootstrapMutate\('([^']+)'/g,/backend\.mutate\('([^']+)'/g])for(const m of text.matchAll(rx))used.add(m[1]);}
for(const op of used)if(!allowed.has(op))throw new Error(`Operación frontend fuera del contrato: ${op}`);
const missing=[...allowed].filter(op=>!used.has(op));if(missing.length)throw new Error(`Operaciones del contrato sin implementación 2.0: ${missing.join(', ')}`);
console.log(`OK contrato completo: ${used.size}/${allowed.size} operaciones app_mutate_v160 implementadas en el frontend 2.0`);
