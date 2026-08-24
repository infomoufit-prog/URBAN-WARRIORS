import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const config=read('web/config.js');
const index=read('web/index.html');
const worker=read('web/service-worker.js');
const deletePage=read('web/delete-account.html');
const backend=read('web/js/core/backend.js');
const access=read('web/js/modules/platform-admin-access.js');
const repos=read('web/js/core/repositories.js');
const notificationUi=read('web/js/modules/comms-material.js');
const manifest=read('android/app/src/main/AndroidManifest.xml');
const main=read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java');
const messaging=read('android/app/src/main/java/com/urbanwarriors/app/UrbanWarriorsMessagingService.java');
const gradle=read('android/app/build.gradle');
const migration=read('supabase/migrations/119_kombax_privacy_deletion_owner_20071.sql');
const pushPolicy=read('supabase/migrations/120_kombax_club_push_mandatory_20071.sql');
const executor=read('supabase/functions/account-deletion-executor/index.ts');
const dispatch=read('supabase/functions/notification-dispatch/index.ts');
const reminders=read('supabase/functions/payment-reminders/index.ts');
const netlify=read('netlify.toml');
const minorConsent=read('supabase/migrations/121_kombax_minor_social_guardian_consent_20071.sql');
const messageReport=read('supabase/migrations/122_kombax_message_reporting_20071.sql');
const minorSafety=read('supabase/migrations/123_kombax_minor_social_safety_controls_20071.sql');
const socialUi=read('web/js/modules/kombax-social.js');
const privacyPage=read('web/privacy.html');
const childSafetyPage=read('web/child-safety.html');
const legalGate=read('scripts/release-legal-gate.mjs');
const readinessTruth=read('supabase/migrations/127_kombax_pilot_readiness_truth_20071.sql');
const pkg=JSON.parse(read('package.json'));

const build=Number(config.match(/build:\s*(\d+)/)?.[1]);
assert.ok(build>=20071);
assert.equal(Number(gradle.match(/versionCode\s+(\d+)/)?.[1]),build);
assert.ok(index.includes(`v=${build}`));
assert.ok(worker.includes(`-${build}`));
assert.ok(deletePage.includes(`v=${build}`));
assert.match(config,/webUrl:\s*'https:\/\/kombax\.es'/);
assert.doesNotMatch(config,/urban01\.netlify\.app/);

if(build>=20077){
  assert.doesNotMatch(access,/SEGUNDO FACTOR|autocomplete="one-time-code"|Reenviar código/);
  assert.match(access,/Abrir Consola Owner/);
  assert.match(backend,/app_kombax_platform_admin_password_session_v139/);
  assert.match(backend,/beginPlatformCriticalAccess/);
  assert.match(backend,/completePlatformCriticalAccess/);
}else{
  assert.match(access,/SEGUNDO FACTOR/);
  assert.match(access,/autocomplete="one-time-code"/);
  assert.match(access,/Reenviar código/);
  assert.match(backend,/app_kombax_platform_admin_challenge_complete_v108/);
}
assert.match(backend,/beginPlatformAdminAccess/);

assert.doesNotMatch(manifest,/android\.permission\.CAMERA/);
assert.match(manifest,/android:host="kombax\.es"/);
assert.match(main,/shouldOverrideUrlLoading/);
assert.match(main,/openExternalUri/);
assert.match(main,/trustedKombaxHost/);
assert.match(main,/access_code/);
assert.match(main,/team_role/);
assert.match(main,/Alertas KOMBAX/);
assert.match(messaging,/VISIBILITY_PRIVATE/);

assert.match(migration,/app_kombax_deletion_queue_v119/);
assert.match(migration,/app_kombax_deletion_plan_v119/);
assert.match(migration,/app_kombax_deletion_finalize_v119/);
assert.match(migration,/PLATFORM_ADMIN_REQUIRED/);
assert.doesNotMatch(migration,/app_kombax_es_moderador_v041\(\)/);
assert.match(executor,/app_kombax_deletion_plan_v119/);
assert.match(executor,/auth\.admin\.deleteUser\(targetProfileId, true\)/);
assert.match(executor,/app_kombax_deletion_finalize_v119/);
assert.doesNotMatch(executor,/service_role.*frontend/i);

// Push del Club: no existe selector personal por categorías en el cliente actual
// y los cron no consultan la tabla histórica de preferencias.
assert.doesNotMatch(notificationUi,/Preferencias push|push_finanzas|push_sesiones|push_comunidad/);
assert.doesNotMatch(repos,/savePreferences/);
assert.match(repos,/enforceClubPush:\(\)=>mutation\('notificaciones\.preferencias',\{push_general:true,push_finanzas:true,push_sesiones:true,push_comunidad:true\}\)/);
assert.match(pushPolicy,/push_finanzas:=true/);
assert.match(pushPolicy,/push_sesiones:=true/);
assert.match(pushPolicy,/push_comunidad:=true/);
assert.match(pushPolicy,/trg_kombax_force_mi_club_push_mandatory_v120/);
assert.doesNotMatch(dispatch,/from\('preferencias_notificacion'\)/);
assert.doesNotMatch(reminders,/from\('preferencias_notificacion'\)/);
assert.match(dispatch,/Tienes una actualización financiera en KOMBAX\./);
assert.match(reminders,/Tienes una actualización financiera en KOMBAX\./);
assert.match(dispatch,/visibility:'PRIVATE'/);
assert.match(reminders,/visibility: 'PRIVATE'/);
assert.doesNotMatch(dispatch,/notification\.titulo\|\|'Urban Warriors'/);

assert.match(netlify,/Permissions-Policy = "camera=\(\), geolocation=\(\), microphone=\(\)"/);
assert.match(netlify,/from = "https:\/\/www\.kombax\.es\/\*"/);
assert.match(netlify,/to = "https:\/\/kombax\.es\/:splat"/);


// Menores: autorización adulta + recordatorio de seguridad + revocación efectiva.
assert.match(minorConsent,/kombax_social_minor_consents_v121/);
assert.match(minorConsent,/app_kombax_social_minor_consent_status_v121/);
assert.match(minorConsent,/KOMBAX_SOCIAL_GUARDIAN_CONSENT_REQUIRED/);
assert.match(minorSafety,/KOMBAX_MINOR_SOCIAL_SAFETY_REMINDER_REQUIRED/);
assert.match(minorSafety,/guardian_revoked_v123/);
assert.match(minorSafety,/app_kombax_social_estado_v123/);
assert.match(repos,/app_kombax_identity_mutate_v123/);
assert.match(repos,/app_kombax_social_mutate_v123/);
assert.match(socialUi,/social-minor-safety-ok/);
assert.match(socialUi,/acepta_seguridad_menor:socialStatus\?\.minor===true/);
assert.match(socialUi,/data-kx-minor-consent="revoked"/);
assert.match(socialUi,/El chat privado permanece desactivado hasta los 18 años/);

// Denuncia de mensajes: evidencia mínima, no acceso global al historial.
assert.match(messageReport,/kombax_message_report_evidence_v122/);
assert.match(messageReport,/app_kombax_contact_message_report_v122/);
assert.match(messageReport,/KOMBAX_REPORT_OWN_MESSAGE_NOT_ALLOWED/);
assert.match(messageReport,/\[Mensaje retirado por moderación\]/);
assert.match(repos,/reportMessage:\(message_id,motivo,detalle=''/);
assert.match(socialUi,/Moderación recibirá únicamente este mensaje/);
assert.match(socialUi,/data-kx-message-report/);
assert.match(messageReport,/'evidence_scope','single_message'/);

// Dominio canónico también al compartir desde la WebView Android.
assert.match(socialUi,/release\?\.webUrl\|\|'https:\/\/kombax\.es'/);
assert.doesNotMatch(socialUi,/location\.origin\}\$\{location\.pathname\}#social/);


const sql125=read('supabase/migrations/125_kombax_minor_trigger_rpc_shutdown_20071.sql');
const sql126=read('supabase/migrations/126_kombax_legacy_anon_code_validator_shutdown_20071.sql');
assert.ok(sql125.includes('kombax_minor_social_consent_guard_v121')&&sql125.includes('from public,anon,authenticated'),'trigger guards de menores no quedan expuestos como RPC');
assert.ok(sql126.includes('app_kombax_codigo_validar_v060')&&sql126.includes('from anon'),'oracle anónimo histórico de códigos queda retirado');


// Recursos públicos de cumplimiento y gate de publicación.
assert.match(privacyPage,/Política de Privacidad/);
assert.match(privacyPage,/BRYAN RIVERA GREY/);
assert.match(privacyPage,/42303973G/);
assert.match(privacyPage,/privacidad@kombax\.es/);
assert.doesNotMatch(privacyPage,/\[\[KOMBAX_/);
assert.match(childSafetyPage,/tolerancia cero/i);
assert.match(childSafetyPage,/BRYAN RIVERA GREY/);
assert.match(childSafetyPage,/childsafety@kombax\.es/);
assert.doesNotMatch(childSafetyPage,/KOMBAX_CHILD_SAFETY_CONTACT_EMAIL/);
assert.match(netlify,/from = "\/privacy"/);
assert.match(netlify,/from = "\/child-safety"/);
assert.equal(pkg.scripts['release:build'],'npm run release:legal-gate && npm run build');
assert.match(legalGate,/RELEASE BLOCKED/);
assert.match(netlify,/command = "npm run release:build"/);

// Readiness 20071 mide el estado efectivo: MFA disponible y password-only no ejecutable.
assert.match(readinessTruth,/'build',20071/);
assert.match(readinessTruth,/'owner_mfa',v_owner_mfa/);
assert.match(readinessTruth,/'owner_password_only_executable',v_password_only_auth/);
assert.match(readinessTruth,/has_function_privilege\('authenticated','public\.app_kombax_platform_admin_password_complete_v110\(uuid\)','EXECUTE'\)/);

console.log('KOMBAX 20071 security/privacy hardening: PASS');
