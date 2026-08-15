import { readFile, access } from 'node:fs/promises';
import { resolve } from 'node:path';
const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RC13 SQL CHAIN: ${msg}`);console.log(`OK RC13 SQL CHAIN: ${msg}`)};
const migrations={
  31:'031_finance_receipts_breakdown.sql',32:'032_social_profiles_likes.sql',33:'033_events_competitions.sql',
  34:'034_notifications_actionable.sql',35:'035_club_public_profile.sql',36:'036_social_access_safety_age.sql'
};
const verify={
  31:['preflight_031_finance_receipts.sql','verify_031_finance_receipts.sql','test_031_receipts_transactional.sql'],
  32:['preflight_032_social.sql','verify_032_social.sql'],33:['preflight_033_events.sql','verify_033_events.sql'],
  34:['preflight_034_notifications.sql','verify_034_notifications.sql','test_034_notifications_transactional.sql'],35:['preflight_035_club_public_profile.sql','verify_035_club_public_profile.sql'],
  36:['preflight_036_social_access.sql','verify_036_social_access.sql']
};
for(const [n,f] of Object.entries(migrations)){await access(resolve(root,'supabase/migrations',f));assert(true,`migración ${n} existe`);await access(resolve(root,'supabase/rollbacks',f));assert(true,`rollback ${n} existe`);for(const vf of verify[n]){await access(resolve(root,'supabase/verification',vf));assert(true,`${vf} existe`)}}
const sql={};for(const [n,f] of Object.entries(migrations))sql[n]=await read(`supabase/migrations/${f}`);
const rb={};for(const [n,f] of Object.entries(migrations))rb[n]=await read(`supabase/rollbacks/${f}`);
const p32=await read('supabase/verification/preflight_032_social.sql'),p33=await read('supabase/verification/preflight_033_events.sql'),p34=await read('supabase/verification/preflight_034_notifications.sql'),p35=await read('supabase/verification/preflight_035_club_public_profile.sql'),p36=await read('supabase/verification/preflight_036_social_access.sql');
assert(sql[31].includes('app_finance_receipts_audit_v031')&&sql[31].includes('v_estado_cuenta_socio'),'031 separa estado de cuenta y auditoría de recibos');
assert(p32.includes('app_finance_receipts_audit_v031'),'preflight 032 obliga a resolver 031 primero');
assert(sql[32].includes('rename to app_mutate_v160_pre_social_032')&&sql[32].includes('return public.app_mutate_v160_pre_social_032'),'032 encadena y delega gateway anterior');
assert(p33.includes('gateway_032'),'033 exige cadena 032');
assert(sql[33].includes('rename to app_mutate_v160_pre_events_033')&&sql[33].includes('return public.app_mutate_v160_pre_events_033'),'033 encadena y delega gateway 032');
assert(p34.includes('gateway_033'),'034 exige cadena 033');
assert(sql[34].includes('rename to app_mutate_v160_pre_notifications_034')&&sql[34].includes('return public.app_mutate_v160_pre_notifications_034'),'034 encadena y delega gateway 033');
assert(p35.includes('gateway_034'),'035 exige cadena 034');
assert(sql[35].includes('rename to app_mutate_v160_pre_club_profile_035')&&sql[35].includes('return public.app_mutate_v160_pre_club_profile_035'),'035 encadena y delega gateway 034');
assert(p36.includes('gateway_035'),'036 exige cadena 035');
assert(sql[36].includes('rename to app_mutate_v160_pre_social_access_036')&&sql[36].includes('return public.app_mutate_v160_pre_social_access_036'),'036 encadena y delega gateway 035');
for(const n of [32,33,34,35,36])assert(sql[n].includes('rename to app_runtime_contract_v160_pre_')&&sql[n].includes('app_runtime_contract_v160_pre_'),'extensión runtime '+n+' preserva contrato anterior');
function assertDollarTagsBalanced(label,text){
  const tags=text.match(/\$[A-Za-z_][A-Za-z0-9_]*\$/g)||[];const counts=new Map();for(const tag of tags)counts.set(tag,(counts.get(tag)||0)+1);
  for(const [tag,count] of counts)assert(count%2===0,`${label} mantiene delimitador ${tag} equilibrado (${count})`);
  const dollars=(text.match(/\$\$/g)||[]).length;assert(dollars%2===0,`${label} mantiene delimitadores $$ equilibrados (${dollars})`);
}
for(const n of [31,32,33,34,35,36]){
  assert(/^\s*(?:--[^\n]*\n)*\s*begin;/i.test(sql[n]),`migración ${n} empieza en transacción`);
  assert(/notify pgrst,'reload schema';\s*commit;/i.test(sql[n]),`migración ${n} termina con reload + commit`);
  assertDollarTagsBalanced(`migración ${n}`,sql[n]);
  assertDollarTagsBalanced(`rollback ${n}`,rb[n]);
}
assert(sql[34].includes('not public.app_notificacion_requiere_accion_v034'),'034 excluye tareas accionables de lectura masiva');
assert(sql[35].includes('perfiles_club_publicos')&&sql[35].includes('app_buscar_identidades_publicas_v035'),'035 separa perfil público y normaliza identidad');
assert(sql[36].includes('v_age<16')&&sql[36].includes('v_age<v_min_social_age')&&sql[36].includes('edad_min_comunidad_general')&&sql[36].includes('reportes_comunidad')&&sql[36].includes('bloqueos_comunidad'),'036 aplica edades y seguridad UGC');
console.log('RC13 BUILD 20020 SQL MIGRATION CHAIN: PASS');
