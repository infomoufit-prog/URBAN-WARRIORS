import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const r=p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const [premium,utils,m155,m156,report,config,index,sw,gradle,main,health]=await Promise.all([
  r('web/js/modules/finance-premium.js'),r('web/js/core/utils.js'),r('supabase/migrations/155_kombax_finance_explorer_stability_20087.sql'),r('supabase/migrations/156_kombax_finance_stability_hardening_20087.sql'),r('supabase/functions/finance-report/index.ts'),r('web/config.js'),r('web/index.html'),r('web/service-worker.js'),r('android/app/build.gradle'),r('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),r('supabase/functions/health/index.ts')
]);
assert.match(premium,/PAGE=20/,'Charge page size must be 20');
assert.match(premium,/EXPLORER_PAGE=20/,'Explorer page size must be 20');
assert.match(premium,/Explorador financiero/,'Finance explorer UI missing');
assert.match(premium,/Activos \+ archivados/,'Lifecycle scope selector missing');
assert.match(premium,/Papelera/,'Trash UI missing');
assert.match(premium,/doc-archive/,'Archive actions missing');
assert.match(premium,/doc-restore/,'Restore actions missing');
assert.match(premium,/Rechazar duplicado/,'Duplicate-payment UX missing');
assert.match(premium,/Integridad financiera/,'Integrity panel missing');
assert.match(premium,/app_finance_v2_explorer_v155/,'Explorer RPC missing in frontend');
assert.match(premium,/app_finance_v2_integrity_v155/,'Integrity RPC missing in frontend');
assert.match(utils,/FINANCE_PAYMENT_ALREADY_COVERED/,'Paid charge error mapping missing');
assert.match(utils,/FINANCE_CHARGE_DUPLICATE/,'Duplicate charge error mapping missing');
assert.match(m155,/finance_document_lifecycle_v155/,'Lifecycle table missing');
assert.match(m155,/app_finance_v2_explorer_v155/,'Explorer backend missing');
assert.match(m155,/FINANCE_PAYMENT_DUPLICATE/,'Rapid payment duplicate guard missing');
assert.match(m156,/FINANCE_CHARGE_DUPLICATE/,'Rapid manual charge guard missing');
assert.match(m156,/REPORT_FILE_MISSING/,'Missing report file audit missing');
assert.match(m156,/PENDING_EXCEEDS_REMAINING/,'Pending payment over-balance audit missing');
assert.match(report,/content-type, prefer/,'finance-report must allow Prefer in CORS');
const markers=[['config',config,/build:\s*(\d+)/],['index',index,/v=(\d+)/],['sw',sw,/-(\d+)'/],['gradle',gradle,/versionCode\s+(\d+)/],['main',main,/\/(\d+)\"/],['health',health,/build:(\d+)/]];
for(const [name,txt,re] of markers){const m=txt.match(re);assert.ok(m&&Number(m[1])>=20087,`${name} build marker must be >=20087`);}
console.log('PASS KOMBAX 20087 · finance explorer + lifecycle + stability guards');
