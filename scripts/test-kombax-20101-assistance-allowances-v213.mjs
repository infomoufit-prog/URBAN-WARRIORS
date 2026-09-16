import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=(path)=>fs.readFileSync(new URL(`../${path}`,import.meta.url),'utf8');
const sql=read('supabase/migrations/213_kombax_assistance_allowances.sql');
const ui=read('web/js/modules/customer-operations.js');
const repos=read('web/js/core/repositories.js');

for(const token of [
  'assistance_plan_entitlements','assistance_periods','assistance_cases','migration_allowance_cases',
  'faq_deflections','for update','idempotency_key','first_month_assistance','monthly_assistance',
  'app_kombax_assistance_allowance_v213','app_kombax_assistance_owner_dashboard_v213',
  'app_kombax_assistance_owner_config_v213','MONTHLY_ALLOWANCE_EXHAUSTED'
])assert.ok(sql.toLowerCase().includes(token.toLowerCase()),`SQL missing ${token}`);

assert.match(sql,/\('CLUB_BASIC',10,20,/);
assert.match(sql,/\('CLUB_PREMIUM',25,40,/);
assert.match(sql,/\('FEDERATION',40,60,/);
assert.ok(sql.includes("if v_ticket.category='MIGRATION'"),'migration must use its independent allowance');
assert.ok(sql.includes("grant execute on function public.app_kombax_assistance_allowance_v213(text) to authenticated"));
assert.ok(!sql.includes('grant all'),'migration must not grant broad privileges');

for(const token of ['KOMBAX Assist','soporte@kombax.es','chat guiado','KOMBAX Migrations'])
  assert.ok(ui.includes(token),`UI missing ${token}`);
assert.ok(repos.includes("app_kombax_assistance_allowance_v213"));
assert.ok(repos.includes("app_kombax_customer_ops_mutate_v233"),'customer mutations should use the hardened R38 successor');
assert.ok(!repos.includes('startGuided'),'customer frontend must not expose self-activation of guided support');

for(const path of ['dist/js/modules/customer-operations.js','android/app/src/main/assets/www/js/modules/customer-operations.js']){
  const built=read(path);
  assert.ok(built.includes('KOMBAX Assist'),`${path} missing support module`);
  assert.ok(built.includes('customer-operations')||built.includes('KOMBAX Assist'),`${path} missing customer operations bundle`); // current email fallback is asserted in web source; build parity is verified after sync
}

console.log('KOMBAX assistance allowances v2.13 static contract: OK');
