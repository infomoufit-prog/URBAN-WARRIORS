import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(new URL('..', import.meta.url).pathname);
const app = fs.readFileSync(path.join(root,'web/js/data-store.js'),'utf8');
const migrations = fs.readdirSync(path.join(root,'supabase/migrations')).filter(f=>f.endsWith('.sql')).sort().map(f=>fs.readFileSync(path.join(root,'supabase/migrations',f),'utf8')).join('\n');

// Última definición efectiva de cada RPC y parámetros declarados.
const defs = new Map();
const re = /create\s+or\s+replace\s+function\s+public\.([a-zA-Z0-9_]+)\s*\(([^)]*)\)/gsi;
let m;
while ((m=re.exec(migrations))) {
  const params = [...m[2].matchAll(/\b(p_[a-zA-Z0-9_]+)\s+[a-zA-Z]/g)].map(x=>x[1]);
  defs.set(m[1], new Set(params));
}
const calls=[];
const callRe=/supabase\.rpc\(\s*['"]([a-zA-Z0-9_]+)['"]\s*,\s*\{([\s\S]*?)\}\s*\)/g;
while((m=callRe.exec(app))){
  const keys=[...m[2].matchAll(/\b(p_[a-zA-Z0-9_]+)\s*:/g)].map(x=>x[1]);
  calls.push([m[1],keys]);
}
const errors=[];
for(const [name,keys] of calls){
  if(!defs.has(name)){ errors.push(`RPC sin definición SQL: ${name}`); continue; }
  const declared=defs.get(name);
  for(const key of keys) if(!declared.has(key)) errors.push(`${name}: parámetro frontend no declarado ${key}`);
  for(const key of declared) if(!keys.includes(key) && !['p_observaciones','p_parentesco','p_horas','p_fecha','p_motivo'].includes(key)) {
    // Solo advertimos parámetros obligatorios sin DEFAULT; comprobación textual aproximada.
    const signature=[...migrations.matchAll(new RegExp(`create\\s+or\\s+replace\\s+function\\s+public\\.${name}\\s*\\(([^)]*)\\)`,'gsi'))].at(-1)?.[1]||'';
    const line=signature.split(',').find(x=>x.includes(key))||'';
    if(!/default/i.test(line)) errors.push(`${name}: posible parámetro obligatorio no enviado ${key}`);
  }
}
if(errors.length){ console.error(errors.join('\n')); process.exit(1); }
console.log(`OK: ${calls.length} contratos RPC del frontend coinciden con las migraciones efectivas.`);
