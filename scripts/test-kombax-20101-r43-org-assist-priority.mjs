import {readFile,access} from 'node:fs/promises';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(fileURLToPath(new URL('..',import.meta.url)));let pass=0;
function ok(cond,msg){if(!cond)throw new Error(`FAIL R43: ${msg}`);pass++;console.log(`PASS ${pass}: ${msg}`)}
async function txt(p){return readFile(resolve(root,p),'utf8')}
async function exists(p){try{await access(resolve(root,p));return true}catch{return false}}
const app=await txt('web/js/app.js');
const managed=await txt('web/js/modules/managed-profile-hub.js');
const ops=await txt('web/js/modules/customer-operations.js');
const sql=await txt('supabase/migrations/235_kombax_org_assist_priority_r43.sql');
const pkg=JSON.parse(await txt('package.json'));
ok(await exists('docs/06_HISTORY/PLANS/PLAN_IMPLEMENTACION_R43.md'),'plan R43 existe');
ok(await exists('docs/06_HISTORY/CHANGELOGS/CHANGELOG_20101_R43.md'),'changelog R43 existe');
ok(app.includes("ORG_ASSIST_ROLES=new Set(['direccion','coordinacion','secretaria','economia'])"),'roles organizativos de Club están explícitos');
ok(app.includes('if(canUseOrgAssist(session)){const accountAnchor'),'Assist/Migrations solo se insertan en navegación Club autorizada');
ok(!managed.includes("['federacion','marca','profesional','competidor'].includes(profile.tipo)?migrationAssistBanner()"),'hub ya no promociona migración a perfiles personales');
ok(/profile\.tipo==='federacion'\?migrationAssistBanner\(\{context:/.test(managed),'Federación conserva acceso directo de migración');
ok(ops.includes("CLUB_ORG_ASSIST_ROLES=new Set(['direccion','coordinacion','secretaria','economia'])"),'banners contextuales comparten política de roles Club');
ok(/function migrationAssistBanner[\s\S]*orgTenantRef\(context\)[\s\S]*if\(!ref/.test(ops),'banners de migración no se renderizan sin contexto organizativo autorizado');
ok(sql.includes('create or replace function kombax_ai_ops.org_assist_access_allowed'),'existe guardrail central backend');
ok(sql.includes("mc.rol::text in ('direccion','coordinacion','secretaria','economia')"),'guardrail backend limita roles Club');
ok(sql.includes("d.tipo='federacion'"),'guardrail backend autoriza perfil Federación');
ok(!sql.includes("d.tipo='marca'"),'Marca no queda activada accidentalmente en R43');
ok(sql.includes("return jsonb_build_object('ok',false,'reason','ORG_ASSIST_ONLY')"),'reserva de turno IA se bloquea fuera de organización');
ok(sql.includes("raise exception 'KOMBAX_ORG_MIGRATION_ONLY'"),'subida de archivos de migración se bloquea fuera de organización');
ok(sql.indexOf('ORG_ASSIST_ONLY')<sql.indexOf('reserve_migration_for_ticket'),'bloqueo de identidad ocurre antes de reservar cupo/consumo');
ok(ops.includes('Soporte KOMBAX')&&ops.includes('revisión humana')&&ops.includes('correo'),'UI explica alternativa formal/humana sin depender de Assist');
ok((pkg.scripts['test:20101:r43']||'').includes('test-kombax-20101-r43-org-assist-priority.mjs'),'package expone test R43');
ok((pkg.scripts.test||'').includes('test-kombax-20101-r43-org-assist-priority.mjs'),'regresión completa incorpora R43');
if(pass!==18)throw new Error(`FAIL R43: se esperaban 18 comprobaciones y hubo ${pass}`);
console.log(`R43 ORGANIZATION ASSIST PRIORITY: PASS ${pass}/${pass}`);
