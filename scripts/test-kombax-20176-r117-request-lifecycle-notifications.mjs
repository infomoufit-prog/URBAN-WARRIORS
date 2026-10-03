import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';

const root=resolve(import.meta.dirname,'..');
const read=rel=>readFile(resolve(root,rel),'utf8');
const [config,gradle,activity,backend,app,repos,comms,m310,m311,m315,m316]=await Promise.all([
  read('web/config.js'),
  read('android/app/build.gradle'),
  read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),
  read('web/js/core/backend.js'),
  read('web/js/app.js'),
  read('web/js/core/repositories.js'),
  read('web/js/modules/comms-material.js'),
  read('supabase/migrations/310_kombax_preenrollment_optional_sport_r117.sql'),
  read('supabase/migrations/311_kombax_progressive_club_enrollment_r117.sql'),
  read('supabase/migrations/315_kombax_team_access_request_notifications_r117.sql'),
  read('supabase/migrations/316_kombax_request_notification_lifecycle_r117.sql')
]);
const checks=[];const ok=(name,v)=>{assert.ok(v,name);checks.push(name)};

const build=Number(config.match(/build:\s*(\d+)/)?.[1]);
const version=config.match(/version:\s*'([^']+)'/)?.[1];
ok('web build preserves 20176 or later',build>=20176);
ok('release preserves R117 or later',Number(version?.match(/-r(\d+)/)?.[1])>=117);
ok('android versionCode matches web',Number(gradle.match(/versionCode\s+(\d+)/)?.[1])===build&&gradle.includes(`versionName '${version}'`));
ok('android UA matches web',activity.includes(`KOMBAXApp/2.0.0-rc.13/${build}`));

ok('club login requires selected membership',/if\(requested&&!candidate\)throw new Error\('Esta cuenta no está vinculada a este club/.test(backend));
ok('club login has no silent fallback',!/memberships\.find\(m=>m\.clubes\?\.slug===requestedSlug\)\|\|memberships\[0\]/.test(backend));
ok('pending team request survives email confirmation',/kombax_pending_team_access/.test(backend)&&/completePendingTeamAccess/.test(backend));
ok('new account team intent is passed to signup',/pendingTeamAccess/.test(app)&&/KOMBAX enviará entonces la solicitud al club/.test(app));

ok('pre-enrollment approval remains progressive',/if v_disciplina_id is not null then/.test(m310));
ok('pre-enrollment approval creates real private membership after club approval',/insert into public\.miembros_club/.test(m311)&&/family_linked/.test(m311));
ok('frontend uses canonical r59 approval first',/app_kombax_preinscripcion_aprobar_r59/.test(repos));

ok('team requests notify authorized club managers',/Nueva solicitud de acceso al equipo/.test(m315)&&/team_request_id/.test(m315));
ok('team notifications are actionable only while pending',/team_request_id/.test(m316)&&/estado='pendiente'/.test(m316));
ok('free club-link requests remain actionable while open',/club_link_request/.test(m316)&&/estado='abierta'/.test(m316));
ok('existing-member claims reach central club notifications',/membership_claim_id/.test(m316)&&/Solicitud de vinculación a ficha existente/.test(m316));
ok('pending payment proofs reach central club notifications',/pago-pendiente-/.test(m316)&&/estado_validacion='pendiente'/.test(m316));
ok('payment validation path remains wired',/communicatePayment/.test(repos)&&/validate:\(pago_id,decision,motivo\)/.test(repos));
ok('resolved actions archive their central notification',/ciclo_estado='archivado'/.test(m316)&&/archivado_en/.test(m316));
ok('review does not clear unresolved action before resolution',!/repos\.notifications\.review\(b\.dataset\.id\)/.test(comms));
ok('notification copy says tasks remain until resolved',/se mantienen hasta resolver la tarea/.test(comms));

console.log(`PASS ${checks.length}/${checks.length} · KOMBAX R117 build 20176 request lifecycle / central notifications`);
for(const name of checks)console.log(`  ✓ ${name}`);
