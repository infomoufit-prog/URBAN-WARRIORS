import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const root=process.cwd();const read=p=>fs.readFileSync(path.join(root,p),'utf8');const exists=p=>fs.existsSync(path.join(root,p));let n=0;
const ok=(v,m)=>{assert.ok(v,m);n++;console.log(`PASS ${n}: ${m}`)};
const cfg=read('web/config.js'),gradle=read('android/app/build.gradle'),sw=read('web/service-worker.js');
const build=Number(cfg.match(/build:\s*(\d+)/)?.[1]||0),androidBuild=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);
ok(build>=20142,'R89 uses monotonic build >= 20142');
ok(androidBuild===build,'Android build matches web build');
ok(sw.includes(`kombax-build-${build}`),'service worker matches R89 build');
const migration='supabase/migrations/20260921212710_kombax_r89_inventory_lifecycle_events_sidebar.sql';
ok(exists(migration),'live R89 migration is archived locally');
const sql=read(migration);
for(const token of ['club_stock_movements_r89','app_kombax_material_inventory_r89','app_kombax_showcase_inventory_cost_r89','app_kombax_inventory_finance_r89','app_evento_comunicaciones_r89','app_ciclo_listar_page_r89','app_ciclo_eliminar_preview_r89'])ok(sql.includes(token),`R89 migration contains ${token}`);
ok(/precio_compra_medio/.test(sql)&&/gross_margin/.test(sql),'R89 models purchase cost and margin without invented seed values');
ok(!/insert\s+into\s+public\.material_catalogo/i.test(sql)&&!/insert\s+into\s+public\.kombax_showcase_elementos/i.test(sql),'R89 does not invent material/product costs');
const repos=read('web/js/core/repositories.js');
for(const token of ['app_kombax_material_inventory_r89','app_kombax_material_stock_movements_r89','app_kombax_material_inventory_mutate_r89','app_kombax_showcase_inventory_cost_r89','app_kombax_showcase_inventory_mutate_r89','app_kombax_inventory_finance_r89','app_evento_comunicaciones_r89','app_ciclo_listar_page_r89','app_ciclo_eliminar_preview_r89'])ok(repos.includes(token),`repository is wired to ${token}`);
const materials=read('web/js/modules/comms-material.js'),showcase=read('web/js/modules/showcase.js'),finance=read('web/js/modules/finance-context.js'),events=read('web/js/modules/events.js'),lifecycle=read('web/js/modules/lifecycle.js');
ok(/inventoryMutate\('purchase'/.test(materials)&&/r89\.purchaseAvg/.test(materials),'Club Materials supports purchases and purchase-cost management');
ok(/detail-delete-material/.test(materials)&&/repos\.lifecycle\.action\('material'.*'archivar'/s.test(materials),'Club Materials destructive action routes to lifecycle/archive');
ok(/inventoryMutate\('purchase'/.test(showcase)&&/r89\.stockMargins/.test(showcase),'Showcase exposes cost/margin inventory management');
ok(/Stock y materiales/.test(finance)&&/financeContext\.inventory/.test(finance),'Finance Premium includes shared Stock y materiales analysis');
ok(/limit=10/.test(finance)&&/limit\+10/.test(finance),'Finance progressively loads ten records per step');
ok(/eventStateLimits=\{activo:10,archivado:10,papelera:10\}/.test(events),'Club Events starts active/archive/trash lists at ten');
ok(/repos\.events\.communications/.test(events)&&/repos\.eventConnections\.get/.test(events),'Club Event detail exposes communications and private/public connection');
ok(/hora_inicio|eventSchedule/.test(events)&&/lugar/.test(events),'Club Event UI exposes schedule and location');
ok(/previewDelete/.test(events)&&/deleteForever/.test(events),'Club Event permanent delete uses safe lifecycle preview');
ok(/PAGE=10/.test(lifecycle)&&/listPage/.test(lifecycle),'Archive/trash uses server-side ten-at-a-time pages');
const components=read('web/js/ui/components.js');ok(/export function setPrivateViewHtml/.test(components)&&/(document\.querySelector\('#main-view'\)|document\.getElementById\('main-view'\))/.test(components),'private shell helper preserves sidebar when main-view exists');
for(const f of ['web/js/modules/federation-licenses.js','web/js/modules/professional-operations.js','web/js/modules/professional-finance.js']){const s=read(f);const calls=[...s.matchAll(/\bsetAppHtml\s*\(/g)];ok(calls.length===0,`${f} no longer replaces the private app shell`);ok(/setPrivateViewHtml\s*\(/.test(s),`${f} renders inside the persistent shell`);}
const terminal=read('android/app/src/main/java/com/urbanwarriors/app/KombaxTerminalManager.java');ok(!/BuildConfig\.DEBUG/.test(terminal)&&/ApplicationInfo\.FLAG_DEBUGGABLE/.test(terminal),'Android Terminal BuildConfig regression remains fixed');
const langs=['es','en','fr','pt','it','de','th','fil'];let master=null;for(const lang of langs){const s=read(`web/js/i18n/locales/${lang}/r89.js`);const keys=[...s.matchAll(/^\s*"([^"]+)"\s*:/gm)].map(x=>x[1]).sort();if(!master)master=keys;ok(JSON.stringify(keys)===JSON.stringify(master),`R89 locale ${lang} matches the master keyset`);}

const androidPlay=read('scripts/android-play-bundle.mjs');
const androidDebug=read('scripts/android-debug-qa.mjs');
const androidGradle=read('android/app/build.gradle');
const gitignore=read('.gitignore');
ok(androidPlay.includes('PILOT_GOOGLE_PLAY.aab')&&androidPlay.includes('release-legal-gate.mjs')&&androidPlay.includes('release-netlify-r104-3.mjs'),'Google Play helper certifies current release and emits current AAB name');
ok(androidDebug.includes('PILOT_QA_DEBUG.apk')&&androidDebug.includes('assembleDebug'),'Android QA helper emits current APK name');
ok(/compileSdk\s+36/.test(androidGradle)&&/targetSdk\s+36/.test(androidGradle)&&Number(androidGradle.match(/versionCode\s+(\d+)/)?.[1]||0)>=20142,'R89 Android targets API 36 with monotonic versionCode >= 20142');
ok(gitignore.includes('android/keystore.properties')&&gitignore.includes('*.jks')&&gitignore.includes('*.aab'),'R89 keeps signing keys and generated release bundles out of Git');

console.log(`KOMBAX R89 inventory/lifecycle/sidebar: ${n}/${n} PASS`);
