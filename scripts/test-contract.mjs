import {readFile,readdir} from 'node:fs/promises';import {resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const baseSql=await readFile(resolve(root,'supabase/migrations/022_rc10_final_mvp_v166.sql'),'utf8');
const runtime=baseSql.slice(baseSql.indexOf('create or replace function public.app_runtime_contract_v160'),baseSql.indexOf('revoke all on function public.app_runtime_contract_v160'));
const start=runtime.indexOf("'operations',jsonb_build_array(");const end=runtime.indexOf('));',start);const block=start>=0&&end>start?runtime.slice(start,end):'';
if(!block)throw new Error('No se pudo leer el contrato SQL base');
const allowed=new Set([...block.matchAll(/'([^']+)'/g)].map(m=>m[1]).filter(x=>x.includes('.')));
for(const migration of ['032_social_profiles_likes.sql','033_events_competitions.sql','034_notifications_actionable.sql','035_club_public_profile.sql','036_social_access_safety_age.sql']){
  const sql=await readFile(resolve(root,'supabase/migrations',migration),'utf8');
  const wrapper=sql.match(/create or replace function public\.app_runtime_contract_v160\(p_club_id uuid\)[\s\S]*?grant execute on function public\.app_runtime_contract_v160\(uuid\) to authenticated;/)?.[0]||'';
  if(!wrapper)throw new Error(`No se pudo leer la extensión de contrato ${migration}`);
  for(const m of wrapper.matchAll(/'([^']+)'/g)){if(m[1].includes('.'))allowed.add(m[1]);}
}
for(const migration of await readdir(resolve(root,'supabase/migrations'))){
  if(!migration.endsWith('.sql'))continue;
  const sql=await readFile(resolve(root,'supabase/migrations',migration),'utf8');
  for(const m of sql.matchAll(/DEPRECATED_MAIN_OPERATION:\s*([^\s]+)/g))allowed.delete(m[1]);
}
async function files(dir){const out=[];for(const e of await readdir(dir,{withFileTypes:true})){const p=resolve(dir,e.name);if(e.isDirectory())out.push(...await files(p));else if(p.endsWith('.js'))out.push(p)}return out}
const used=new Set();for(const file of await files(resolve(root,'web/js'))){const text=await readFile(file,'utf8');for(const rx of [/mutation\('([^']+)'/g,/optimisticNotificationMutation\('([^']+)'/g,/bootstrapMutate\('([^']+)'/g,/backend\.mutate\('([^']+)'/g])for(const m of text.matchAll(rx))used.add(m[1]);}
for(const op of used)if(!allowed.has(op))throw new Error(`Operación frontend fuera del contrato: ${op}`);
const missing=[...allowed].filter(op=>!used.has(op));if(missing.length)throw new Error(`Operaciones del contrato sin implementación 2.0: ${missing.join(', ')}`);
console.log(`OK contrato RC13 completo: ${used.size}/${allowed.size} operaciones app_mutate_v160 implementadas`);
