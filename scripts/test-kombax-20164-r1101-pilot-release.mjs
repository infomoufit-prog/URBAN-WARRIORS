import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const read=p=>readFileSync(new URL(`../${p}`,import.meta.url),'utf8');
const pkg=JSON.parse(read('package.json'));
const release=read('scripts/release-netlify-r104-3.mjs');
const cfg=read('web/config.js');
const sw=read('web/service-worker.js');
const gradle=read('android/app/build.gradle');
const main=read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java');
const health=read('supabase/functions/health/index.ts');

let pass=0;
const test=(name,fn)=>{try{fn();pass++;console.log(`✓ ${name}`)}catch(e){console.error(`✗ ${name}`);throw e}};

test('R110.1 package identity',()=>assert.equal(pkg.version,'2.0.0-rc.13-r1101-pilot-release'));
test('R110.1 web build identity',()=>assert.ok(cfg.includes("version: '2.0.0-rc.13-r1101-pilot-release'")&&cfg.includes('build: 20164')));
test('R110.1 Android identity',()=>assert.ok(gradle.includes('versionCode 20164')&&gradle.includes("versionName '2.0.0-rc.13-r1101-pilot-release'")));
test('R110.1 PWA cache identity',()=>assert.ok(sw.includes('kombax-build-20164')&&sw.includes('20164-r1101-pilot-release')));
test('R110.1 Android UA identity',()=>assert.ok(main.includes('r1101-pilot-release')&&main.includes('/20164')));
test('R110.1 health identity',()=>assert.ok(health.includes('build:20164')&&health.includes("'x-kombax-build':'20164'")));
test('Netlify preserves strict audit in npm test',()=>assert.ok(pkg.scripts.test.includes('i18n-r79-full-product-audit.mjs --strict')));
test('Netlify R79 baseline equals audited R110 debt',()=>assert.ok(release.includes('R79_I18N_UNRESOLVED_BASELINE=255')));
test('Netlify runtime baseline equals audited R110 debt',()=>assert.ok(release.includes('RUNTIME_COPY_UNRESOLVED_BASELINE=242')));
test('Release wrapper blocks increases instead of disabling audits',()=>assert.ok(release.includes('count>0&&count<=max')&&!release.includes("'--strict'")));
test('R110 pilot migration remains cumulative',()=>assert.ok(read('supabase/migrations/297_kombax_pilot_club_activation_owner_r110.sql').includes('app_kombax_pilot_club_activate_r110')));
console.log(`R110.1 pilot release gate: ${pass}/11 PASS`);
