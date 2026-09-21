import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const root=resolve(import.meta.dirname,'..');
const read=(p)=>readFile(resolve(root,p),'utf8');
const [sql,registry,identity,repos,app,showcase,gateway,gradle,config,sw]=await Promise.all([
  read('supabase/migrations/249_kombax_identity_memberships_media_r58.sql'),
  read('web/js/core/profile-registry.js'),read('web/js/core/identity-context.js'),read('web/js/core/repositories.js'),
  read('web/js/app.js'),read('web/js/modules/showcase.js'),read('web/js/modules/gateway.js'),read('android/app/build.gradle'),read('web/config.js'),read('web/service-worker.js')
]);
const ok=(cond,msg)=>{assert.ok(cond,msg);console.log('PASS',msg)};
const currentBuild=Number((config.match(/build:\s*(\d+)/)||[])[1]||0);
ok(sql.includes("kombax_acceso_estado")&&sql.includes("sin_activar")&&sql.includes("invitacion_pendiente")&&sql.includes("vinculacion_pendiente")&&sql.includes("activo"),'administrative student access lifecycle');
ok(sql.includes('app_kombax_guard_socio_account_r58')&&sql.includes('KOMBAX_DUPLICATE_STUDENT_ACCOUNT_IN_CLUB'),'same-account duplicate guard inside one club');
ok(sql.includes('app_kombax_alumno_aceptar_r58')&&sql.includes('socio_id'),'bound invitation activates existing student record');
ok(sql.includes('app_kombax_mis_membresias_r58')&&sql.includes('app_kombax_membresias_pendientes_r58'),'independent multi-club membership queries');
ok(sql.includes("new.estado in ('baja','suspendido')"),'membership access is revoked per club on exit/suspension');
ok(sql.includes('app_kombax_club_interest_send_r58'),'spectator can contact clubs as future student');
ok(sql.includes('app_kombax_showcase_inquiry_request_r58')&&sql.includes('app_kombax_showcase_inquiry_send_r58'),'spectator has Showcase product-only inquiry channel');
ok(sql.includes("'media'")&&sql.includes('app_kombax_media_entitlements_r58'),'Media / Creator backend profile and entitlements');
ok(sql.includes("'social.publish'")&&sql.includes("'showcase.publish'")&&sql.includes("new.tipo='media'"),'verified Media gains Social + Showcase publishing');
ok(sql.includes('No se insertan social.publish/showcase.publish para Auth global ni para tipo espectador'),'spectator has no publishing entitlement by default');
ok(registry.includes("id:'media'")&&registry.includes('baseOnly:true'),'frontend exposes Media and keeps Spectator as base-only state');
ok(identity.includes("media:'Media / Creador'"),'identity context labels Media');
ok(repos.includes('kombaxMemberships')&&repos.includes('inviteAccess')&&repos.includes('inquiryRequest'),'repositories expose memberships, activation and inquiry flows');
ok(app.includes('openBoundStudentActivation')&&app.includes('uw2_pending_student_membership'),'existing imported student can activate without duplicate');
ok(showcase.includes("media:'Media / Creador'"),'Showcase accepts Media provider UI');
ok(gateway.includes('baseOnly'),'gateway does not offer Spectator as a requested profile');
ok(currentBuild>=20108&&new RegExp(`versionCode\\s+${currentBuild}`).test(gradle),'Android preserves R58+ monotonic identity');
ok(currentBuild>=20108,'web preserves R58+ monotonic build identity');
ok(currentBuild===20108?sw.includes('20108-r58'):(/20110-r60/.test(sw)||/historical cache marker:.*20108/i.test(sw)),'service worker preserves R58 lineage through current release');
console.log('OK KOMBAX 20.108 R58 focused QA');
