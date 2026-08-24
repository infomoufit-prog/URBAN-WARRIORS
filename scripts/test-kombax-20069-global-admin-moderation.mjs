import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const [sql,admin,social,repos,config,gradle,index,worker]=await Promise.all([
  read('supabase/migrations/114_kombax_global_admin_moderation_20069.sql'),read('web/js/modules/platform-admin.js'),
  read('web/js/modules/kombax-social.js'),read('web/js/core/repositories.js'),read('web/config.js'),
  read('android/app/build.gradle'),read('web/index.html'),read('web/service-worker.js')
]);
for(const token of ['kombax_platform_entity_sessions','kombax_platform_privileged_audit','kombax_moderation_decisions_v114','app_kombax_platform_entity_session_start_v114','app_kombax_platform_entity_session_end_v114','app_kombax_moderation_decide_v114'])assert.ok(sql.includes(token),token);
assert.ok(sql.includes("auth.jwt()->>'session_id'")&&sql.includes("interval '15 minutes'"));
assert.ok(sql.includes('enable row level security')&&sql.includes('revoke all on public.kombax_platform_entity_sessions'));
assert.ok(!sql.includes('create or replace function public.app_kombax_platform_admin_password_complete_v110'));
assert.ok(!sql.includes('insert into public.miembros_club')&&!sql.includes('signInWithOtp')&&!sql.includes('verifyOtp'));
for(const state of ['allowed','review','hidden','warning','suspended','escalated'])assert.ok(sql.includes(`'${state}'`));
assert.ok(admin.includes('MODO ADMINISTRADOR KOMBAX')&&admin.includes('No eres miembro')&&admin.includes('entitySessionEnd'));
assert.ok(social.includes('no Finanzas')&&social.includes('moderationDecide'));
assert.ok(!sql.match(/grant execute on function public\.app_kombax_platform_entity_[^(]+\([^;]+ to anon/));
assert.ok(!repos.match(/moderationDecide:[\s\S]{0,300}(finance|document|role)/i));
const currentBuild=Number(config.match(/build:\s*(\d+)/)?.[1]);
assert.ok(currentBuild>=20069);assert.equal(Number(gradle.match(/versionCode\s+(\d+)/)?.[1]),currentBuild);
assert.match(index,new RegExp(`v=${currentBuild}`));assert.match(worker,new RegExp(`rc13-${currentBuild}`));
console.log('KOMBAX 20069 GLOBAL ADMIN + MODERATION: PASS');
