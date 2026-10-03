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

test('R110.1 package lineage is preserved',()=>assert.ok(/^2\.0\.0-rc\.13-r(?:1101-pilot-release|11[2-9].*)$/.test(pkg.version)));
test('R110.1 web build lineage is preserved',()=>{const b=Number(cfg.match(/build:\s*(\d+)/)?.[1]||0);assert.ok(b>=20164)});
test('R110.1 Android lineage is preserved',()=>{const b=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);assert.ok(b>=20164)});
test('R110.1 PWA cache lineage is preserved',()=>{const b=Number(sw.match(/^const BUILD_MARKER='kombax-build-(\d+)'/m)?.[1]||0);assert.ok(b>=20164)});
test('R110.1 Android UA lineage is preserved',()=>{const b=Number(main.match(/settings\.setUserAgentString[\s\S]*?KOMBAXApp\/2\.0\.0-rc\.13\/(\d+)/)?.[1]||0);assert.ok(b>=20164)});
test('R110.1 health lineage is preserved',()=>{const m=health.match(/build:(\d+)/);assert.ok(m&&Number(m[1])>=20164)});
test('Netlify preserves strict audit in npm test',()=>assert.ok(pkg.scripts.test.includes('i18n-r79-full-product-audit.mjs --strict')));
test('Netlify R79 baseline identifies the inherited source commit',()=>{const baseline=JSON.parse(read('scripts/i18n-pilot-baseline.json'));assert.equal(baseline.build,20177);assert.equal(baseline.source_commit,'7dd7c7ed39df13bb67880685c7c2df875b43f267');assert.equal(baseline.r79.entries.length,287);});
test('Netlify runtime baseline records exact inherited phrases',()=>{const baseline=JSON.parse(read('scripts/i18n-pilot-baseline.json'));assert.equal(baseline.runtime.entries.length,268);assert.ok(baseline.runtime.entries.every(row=>row.file&&row.value));});
test('Release wrapper blocks new untranslated phrases instead of disabling audits',()=>{const policy=read('scripts/i18n-pilot-baseline.mjs');assert.ok(release.includes('inheritedI18nOnly'));assert.ok(policy.includes('actual.every(row=>known.has(key(row)))'));assert.ok(release.includes('result.status===1'));});
test('R110 pilot migration remains cumulative',()=>assert.ok(read('supabase/migrations/297_kombax_pilot_club_activation_owner_r110.sql').includes('app_kombax_pilot_club_activate_r110')));
console.log(`R110.1 pilot release gate: ${pass}/11 PASS`);
