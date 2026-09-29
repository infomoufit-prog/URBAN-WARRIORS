import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const root=resolve(import.meta.dirname,'..');
const read=(p)=>readFile(resolve(root,p),'utf8');
const [migration,backend,gateway,utils,policy,r100,r58,registry,config,gradle,sw]=await Promise.all([
  read('supabase/migrations/296_kombax_prepilot_identity_permissions_r109.sql'),
  read('web/js/core/backend.js'),read('web/js/modules/gateway.js'),read('web/js/core/utils.js'),
  read('web/js/core/account-profile-policy.js'),read('supabase/migrations/272_kombax_account_type_lock_r100.sql'),
  read('supabase/migrations/249_kombax_identity_memberships_media_r58.sql'),read('web/js/core/profile-registry.js'),read('web/config.js'),
  read('android/app/build.gradle'),read('web/service-worker.js')
]);
const ok=(condition,message)=>{assert.ok(condition,message);console.log('PASS',message)};

const webBuild=Number(config.match(/build:\s*(\d+)/)?.[1]||0);
const androidBuild=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);
ok(webBuild>=20162,'R109 web lineage is preserved in build 20162 or later');
ok(androidBuild>=20162,'R109 Android lineage is preserved in build 20162 or later');
ok(sw.includes(`kombax-build-${webBuild}`),'service worker marker matches the current cumulative build while preserving R109 semantics');

ok(backend.includes("const selectedType=['club','marca','federacion','profesional','media']")&&!backend.includes("const selectedType=['club','competidor','marca','federacion','profesional','media']"),'Competidor signup creates personal account before profile lock');
ok(migration.includes("if v_type in ('club','marca','federacion','profesional','media')")&&!migration.includes("if v_type in ('club','competidor','marca','federacion','profesional','media')"),'backend signup trigger ignores Competidor metadata');
ok(policy.includes("kind:'miembro'")&&policy.includes("allowed:types.has('competidor')?[]:['competidor']"),'Miembro → Competidor compatibility remains');

ok(migration.includes("sp.sujeto_tipo='miembro'")&&migration.includes("extract(year from age(current_date,s.fecha_nacimiento))>=14"),'Miembro Social keeps active membership + 14+ gate');
ok(migration.includes("d.tipo='competidor'")&&migration.includes("d.fecha_nacimiento_verificada<=current_date-interval '16 years'"),'Competidor Social publish uses verified personal age 16+');
ok(migration.includes("d.tipo='profesional'")&&migration.includes('kombax_perfil_persona_privada_v196')&&migration.includes('app_kombax_profile_age_v196'),'Professional Social gate uses private 18+ age, not club membership');
ok(!migration.includes("d.tipo in ('competidor','profesional') and exists(\n              select 1 from public.identidades_sociales"),'direct Competidor/Professional publish no longer depends on member identity');
ok(migration.includes("d.fecha_nacimiento_verificada<=current_date-interval '18 years'")&&migration.includes('app_kombax_social_contactable_v041'),'Competidor contact remains 18+ without Club dependency');
ok(migration.includes('KOMBAX_SOCIAL_COMPETITOR_VERIFIED_AGE_REQUIRED')&&migration.includes('KOMBAX_SOCIAL_PROFESSIONAL_AGE_REQUIRED'),'direct Social activation exposes contextual age gates');
ok(utils.includes('KOMBAX_SOCIAL_COMPETITOR_VERIFIED_AGE_REQUIRED')&&utils.includes('KOMBAX_SOCIAL_PROFESSIONAL_AGE_REQUIRED'),'frontend maps new Social gate errors to contextual messages');

ok(migration.includes("v_req.tipo not in ('club','competidor','marca','federacion','media')"),'Media is accepted by canonical verification validator');
ok(migration.includes("v_req.tipo<>'media' and v_docs<1"),'Media document is optional while other current verified types retain document gate');
ok(migration.includes("v_req.tipo='media'")&&migration.includes("KOMBAX_MEDIA_PROFILE_REQUIRED")&&migration.includes("array_append(v_need,'evidencia')"),'Media verification requires proportional evidence tied to its own profile');
ok(migration.includes("requisitos_version,'media-r109-v1'")||migration.includes("requisitos_version)\n    values")&&migration.includes("'media-r109-v1'"),'Media draft persists R109 verification contract');
ok(gateway.includes("const mediaVerification=type==='media'")&&gateway.includes("Documento adicional · opcional")&&gateway.includes('Portfolio / referencias / actividad verificable'),'Media verification UX is proportional');

ok(r58.includes("new.tipo='media'")&&r58.includes("'social.publish'")&&r58.includes("'showcase.publish'"),'existing Media entitlements are preserved');
ok(migration.includes("d.tipo in ('marca','federacion','media')"),'Brand/Federation/Media existing direct Social behavior preserved');
ok(migration.includes("app_kombax_club_permiso_v051(sp.club_id,'social.publish')")&&migration.includes("app_kombax_club_permiso_v051(sp.club_id,'social.act_as_club')"),'Club acting permissions remain unchanged');
ok(registry.includes("code:'promotor_organizador'")&&registry.includes("name:'Promotor / Organizador'"),'Promotor/Organizador remains a Professional specialty, not a new identity');
ok(!policy.includes("'organizador'")&&!policy.includes('"organizador"'),'account policy does not introduce Organizador identity');
ok(!policy.includes("'practicante'")&&!policy.includes('"practicante"'),'account policy does not introduce Practicante identity');

ok(migration.includes('create or replace function public.app_kombax_account_type_on_signup_r100')&&migration.includes('create or replace function public.app_kombax_social_puede_actuar_v051')&&migration.includes('create or replace function public.app_kombax_social_mutate_v099'),'R109 is incremental over canonical existing functions');
ok(!/drop\s+table|truncate\s+|delete\s+from\s+auth\.|alter\s+table\s+.*drop\s+column/i.test(migration),'R109 migration contains no destructive schema/data operations');

console.log('R109 PRE-PILOT IDENTITY: PASS 25/25');
