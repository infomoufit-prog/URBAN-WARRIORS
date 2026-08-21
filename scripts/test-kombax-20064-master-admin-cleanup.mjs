import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const root=path.resolve(path.dirname(new URL(import.meta.url).pathname),'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const app=read('web/js/app.js');
const gateway=read('web/js/modules/gateway.js');
const components=read('web/js/ui/components.js');
const admin=read('web/js/modules/admin.js');
const access=read('web/js/modules/platform-admin-access.js');
const backend=read('web/js/core/backend.js');
const supabase=read('web/js/core/supabase.js');
const utils=read('web/js/core/utils.js');
const css=read('web/css/app.css');
const config=read('web/config.js');
const gradle=read('android/app/build.gradle');
const sql=read('supabase/migrations/108_kombax_master_admin_otp_20064.sql');

const currentBuild=Number(config.match(/build:\s*(\d+)/)?.[1]);
const androidBuild=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]);
assert.ok(currentBuild>=20064&&androidBuild===currentBuild,'web/Android must preserve 20064+ master admin baseline');
assert.match(css,/grid-template-columns:repeat\(var\(--bottom-nav-count,4\),minmax\(0,1fr\)\)/,'mobile bottom nav must distribute the real button count');
assert.match(components,/--bottom-nav-count:\$\{Math\.max\(1,mobileItems\.length\)\}/,'bottom nav must expose its real item count');

assert.doesNotMatch(app,/ids\.push\(['"]platform-admin['"]\)/,'ordinary nav must not expose platform admin');
assert.doesNotMatch(components,/id=["']nav-platform|data-nav=["']platform-admin/,'sidebar must not expose platform admin');
assert.doesNotMatch(admin,/Herramientas técnicas/,'club settings must not expose technical tools');
assert.ok(app.includes('const adminPath=')&&app.includes('location.pathname'),'PWA must support the private /admin route');
assert.match(gateway,/taps\.length<8/,'mobile hidden entry requires 8 taps');
assert.match(gateway,/now-at<=5000/,'hidden tap sequence must be time-bounded');
assert.doesNotMatch(gateway,/No recibe insignia KOMBAX en 20\.044|CLUB ACCESS \/ 01|KOMBAX ID \/ CUENTA|KOMBAX ID \/ 02/,'gateway must not expose internal release labels');

assert.match(access,/ACCESO MAESTRO/);
assert.match(access,/SEGUNDO FACTOR/);
assert.match(access,/código de un solo uso/i);
assert.match(backend,/beginPlatformAdminAccess/);
assert.match(backend,/completePlatformAdminAccess/);
assert.match(supabase,/requestEmailOtp/);
assert.match(supabase,/verifyEmailOtp/);
assert.match(backend,/app_kombax_platform_admin_session_end_v108/);

assert.match(sql,/kombax_platform_admin_challenges/);
assert.match(sql,/kombax_platform_admin_sessions/);
assert.match(sql,/app_kombax_auth_method_recent_v108\('password',600\)/);
assert.match(sql,/app_kombax_auth_method_recent_v108\('otp',600\)/);
assert.match(sql,/auth_session_id=\(auth\.jwt\(\)->>'session_id'\)/);
assert.match(sql,/alter table public\.kombax_platform_admin_challenges enable row level security/);
assert.match(sql,/alter table public\.kombax_platform_admin_sessions enable row level security/);
assert.match(sql,/revoke all on public\.kombax_platform_admin_challenges from public,anon,authenticated/);
assert.match(sql,/revoke all on public\.kombax_platform_admin_sessions from public,anon,authenticated/);
assert.match(utils,/TECHNICAL_ERROR_PATTERN/);
assert.match(utils,/KOMBAX_\[A-Z0-9_\]/);
assert.match(utils,/No se ha podido completar la operación\. Inténtalo de nuevo\./);

// Public UX must never render raw backend error fields directly.
const publicModules=fs.readdirSync(path.join(root,'web/js/modules')).filter(f=>f.endsWith('.js')&&!['platform-admin.js','platform-admin-access.js'].includes(f));
for(const file of publicModules){
  const src=read(`web/js/modules/${file}`);
  const renderedRaw=/(?:empty|toast|setMainHtml|openDetail|openForm|textContent|innerHTML)[^\n]{0,260}(?:error|e)\.(?:message|details|hint)|\$\{(?:error|e)\.(?:message|details|hint)\}/;
  assert.doesNotMatch(src,renderedRaw,`${file} renders a raw technical error`);
}

console.log('KOMBAX 20064 master admin + frontend cleanup: PASS');
