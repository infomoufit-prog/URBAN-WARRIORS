import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const has=(txt,frag,msg=frag)=>assert.ok(txt.includes(frag),`Missing ${msg}`);
const not=(txt,frag,msg=frag)=>assert.ok(!txt.includes(frag),`Unexpected ${msg}`);
const tests=[]; const test=(name,fn)=>tests.push([name,fn]);
const sourcePath='web/js/i18n/r78-system-source.js';
const runtimePath='web/js/i18n/legacy-runtime.js';
const source=read(sourcePath), runtime=read(runtimePath);
const sourceMatches=[...source.matchAll(/"(r78-[a-f0-9]+)":\s*"((?:\\.|[^"\\])*)"/g)];
const ids=sourceMatches.map(m=>m[1]);
const texts=sourceMatches.map(m=>JSON.parse(`"${m[2]}"`));
const uniq=a=>new Set(a).size;

test('R78 source inventory contains exactly 1086 audited system-copy strings',()=>assert.equal(ids.length,1086));
test('R78 source IDs are unique',()=>assert.equal(uniq(ids),1086));
test('R78 normalized source strings are unique',()=>assert.equal(uniq(texts.map(x=>x.replace(/\s+/g,' ').trim())),1086));
test('R78 runtime imports the audited source catalog',()=>has(runtime,"import { R78_SYSTEM_SOURCE } from './r78-system-source.js';"));
test('R78 cache version is tied to build 20129 phases 1-5',()=>has(runtime,"const R78_CACHE_VERSION='20129-p1-p5-v1';"));
test('R78 runtime derives expected count from the bundled source',()=>has(runtime,'const R78_EXPECTED_COUNT=Object.keys(R78_SYSTEM_SOURCE).length;'));
test('R78 only fetches the fixed precomputed system-copy table rows',()=>{has(runtime,"content_type:'eq.system_copy_r78'");has(runtime,"visibility:'eq.public'");has(runtime,"requester_id:'is.null'");});
test('R78 frontend uses publishable config and contains no service-role credential',()=>{has(runtime,'window.UW_CONFIG?.supabase');has(runtime,'cfg.anonKey');not(runtime,'service_role');not(runtime,'SUPABASE_SERVICE_ROLE_KEY');});
test('R78 requires a complete 1086-row catalog before accepting hydration',()=>has(runtime,'Object.keys(byId).length!==R78_EXPECTED_COUNT'));
test('R78 persists the fixed locale catalog for PWA and Android reuse',()=>{has(runtime,'localStorage.setItem(r78CacheKey(code)');has(runtime,'readR78Cached');});
test('R78 warms all seven non-Spanish locales',()=>{for(const lang of ['en','fr','pt','it','de','th','fil'])has(runtime,`'${lang}'`);has(runtime,'warmR78SystemCopyCatalogs');});
test('R78 exact translation has precedence over legacy catalogs',()=>{const r=runtime.indexOf('const r78Exact=r78.exact.get(source)');const old=runtime.indexOf('const map=catalogMap(locale)');assert.ok(r>=0&&old>r,'R78 exact must precede legacy catalog');});
test('R78 dynamic placeholder templates are supported',()=>{has(runtime,"text.includes('{VAR}')");has(runtime,'compileR78Dynamic');has(runtime,"replace(/\\{VAR\\}/g");});
test('R78 user-generated content remains excluded from system localization',()=>{for(const frag of ["'[data-user-content]'","'[data-i18n-user-content]'","'.kx-social-post-text'","'.kx-comment p'","'.kx-public-event-copy > p'"])has(runtime,frag);});
test('R78 does not include temporary batch/export function URLs or private build tokens in frontend',()=>{not(runtime,'kombax-system-i18n-r78-batch');not(runtime,'kombax-r78-i18n-export-temp');not(source,'x-uw-cron-secret');});
test('R78 hydration reapplies DOM localization only for the active locale',()=>has(runtime,"if(code===getLocale()&&typeof document!=='undefined'&&document.body)"));
test('R78 locale changes trigger hydration for the selected locale',()=>has(runtime,"window.addEventListener('kombax:localechange'"));
test('R78 inventory covers long-form system copy, not just buttons',()=>assert.ok(texts.some(x=>x.length>250),'Expected long-form audited strings'));
test('R78 inventory covers dynamic system copy',()=>assert.ok(texts.some(x=>x.includes('{VAR}')),'Expected dynamic audited strings'));
test('R78 inventory covers Events, Showcase, Social and club operations vocabulary',()=>{for(const token of ['evento','Showcase','Social','club'])assert.ok(texts.some(x=>x.toLowerCase().includes(token.toLowerCase())),`Missing ${token}`);});

let passed=0; for(const [name,fn] of tests){try{fn();console.log(`✓ ${name}`);passed++;}catch(e){console.error(`✗ ${name}`);console.error(e.message);}}
console.log(`\nKOMBAX R78 I18N PHASES 1-5: ${passed}/${tests.length} PASS`); if(passed!==tests.length)process.exit(1);
