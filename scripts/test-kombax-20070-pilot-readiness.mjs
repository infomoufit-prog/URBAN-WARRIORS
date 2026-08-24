import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const [migration,cronFix,repos,admin,app,telemetry,netlify,notify,pay,config,index,gradle]=await Promise.all([
  read('supabase/migrations/117_kombax_pilot_readiness_20070.sql'),read('supabase/migrations/118_kombax_cron_service_role_fix_20070.sql'),read('web/js/core/repositories.js'),read('web/js/modules/platform-admin.js'),read('web/js/app.js'),read('web/js/core/telemetry.js'),read('netlify.toml'),read('supabase/functions/notification-dispatch/index.ts'),read('supabase/functions/payment-reminders/index.ts'),read('web/config.js'),read('web/index.html'),read('android/app/build.gradle')
]);
assert.match(migration,/app_kombax_es_verificador_v117/);assert.doesNotMatch(migration,/verification_docs_select_v117[\s\S]{0,300}app_kombax_es_moderador_v041/);
assert.match(migration,/app_kombax_platform_admin_password_complete_v110/);assert.match(migration,/pilot_ready/);assert.match(migration,/access_token.*refresh_token.*password/);
assert.match(cronFix,/auth\.jwt\(\)->>'role'/);assert.match(cronFix,/grant execute[\s\S]*service_role/);
assert.match(repos,/app_kombax_platform_profiles_v117/);assert.match(repos,/setVerifier/);assert.match(admin,/Verificación privada/);assert.match(admin,/PREPARACIÓN DE PILOTO/);
assert.match(app,/installClientTelemetry/);assert.match(telemetry,/\[REDACTED\]/);assert.match(netlify,/Content-Security-Policy/);assert.match(netlify,/Strict-Transport-Security/);
for(const edge of [notify,pay]){assert.match(edge,/supabase-js@2\.112\.3/);assert.match(edge,/jose@6\.2\.9/);assert.match(edge,/authorizeCronRequest/);assert.match(edge,/Error interno/);assert.doesNotMatch(edge,/suppliedSecret\s*!==\s*expectedSecret/)}
const currentBuild=Number(config.match(/build:\s*(\d+)/)?.[1]);assert.ok(currentBuild>=20070);assert.match(index,new RegExp(`v=${currentBuild}`));assert.equal(Number(gradle.match(/versionCode\s+(\d+)/)?.[1]),currentBuild);
for(const source of [repos,admin,app,telemetry]){assert.doesNotMatch(source,/signInWithOtp|verifyOtp/)}
console.log('OK build 20070 · permisos privados, readiness, telemetría, headers y cron hardening');
