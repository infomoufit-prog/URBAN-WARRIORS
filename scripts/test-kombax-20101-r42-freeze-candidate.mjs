import {readFile,access} from 'node:fs/promises';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(fileURLToPath(new URL('..',import.meta.url)));let pass=0;
function ok(cond,msg){if(!cond)throw new Error(`FAIL R42: ${msg}`);pass++;console.log(`PASS ${pass}: ${msg}`)}
async function txt(p){return readFile(resolve(root,p),'utf8')}
async function exists(p){try{await access(resolve(root,p));return true}catch{return false}}
const overview=await txt('web/css/kombax-public-overview.css');
const appCss=await txt('web/css/app.css');
const ui=await txt('web/js/ui/components.js');
const clubProfile=await txt('web/js/modules/club-profile.js');
const index=await txt('web/index.html');
const sw=await txt('web/service-worker.js');
const pkg=JSON.parse(await txt('package.json'));

ok(await exists('PLAN_IMPLEMENTACION_R42.md'),'plan R42 existe');
ok(await exists('CHANGELOG_20101_R42.md'),'changelog R42 existe');
ok(!overview.includes('.kx-explainer-dialog{width:100vw;height:100dvh'),'modal explicador ya no fuerza 100vw x 100dvh en móvil');
ok(overview.includes('inset-block-start:max(8px,env(safe-area-inset-top,0px))'),'modal respeta safe area superior');
ok(overview.includes('inset-block-end:max(8px,env(safe-area-inset-bottom,0px))'),'modal respeta safe area inferior');
ok(overview.includes('inset-inline-start:max(8px,env(safe-area-inset-left,0px))'),'modal respeta safe area izquierda');
ok(overview.includes('inset-inline-end:max(8px,env(safe-area-inset-right,0px))'),'modal respeta safe area derecha');
ok(overview.includes('.kx-explainer-scroll{min-width:0;min-height:0;overflow-x:hidden;overflow-y:auto'),'contenido del explicador no desborda horizontalmente');
ok(overview.includes('.kx-explainer-shell{width:100%;height:100%;min-width:0;min-height:0'),'shell del explicador puede encoger dentro del viewport');
ok(overview.includes('overflow-wrap:anywhere'),'títulos largos pueden envolver en móvil');
ok(overview.includes('border-radius:20px'),'modal móvil conserva margen visual y esquinas contenidas');

ok(ui.includes("const shellBrand=String(KOMBAX_BRAND.symbolWhite||KOMBAX_BRAND.symbol"),'shell resuelve asset estructural desde marca KOMBAX');
ok(ui.includes("--kx-shell-image:url('${esc(shellBrand)}')"),'shell inyecta fondo estructural KOMBAX');
ok(ui.includes('--uw-logo-image:${logo?'),'logo del club se conserva como identidad explícita');
ok(appCss.includes(".content-shell::before")&&appCss.includes("background-image:var(--kx-shell-image,url('../assets/brand/kombax-symbol-white.png'))"),'fondo general de herramienta usa KOMBAX');
ok(appCss.includes(".sidebar::before")&&appCss.includes("--kx-shell-image"),'navegación lateral usa marca de agua KOMBAX');
ok(appCss.includes(".hero::after")&&appCss.includes("background-image:var(--kx-shell-image"),'héroes estructurales usan KOMBAX y no el club como fondo');
ok(appCss.includes(".store-hero::after")&&appCss.includes("background-image:var(--uw-logo-image)"),'branding de club se conserva en contenido explícitamente propio del club');
ok(clubProfile.includes('club-public-cover-media')&&clubProfile.includes('p.portada_url'),'portada pública del club sigue siendo configurable y no se elimina');
ok(ui.includes("globalIds=[personalId,'social','kombax-events','showcase']"),'navegación global KOMBAX permanece intacta');

ok(/20101r42/.test(index)&&/historical-cache-marker:20101r40/.test(index),'PWA avanza a R42 preservando R40');
ok(/media-r42/.test(sw)&&/historical cache marker: media-r40/.test(sw),'service worker avanza a R42 preservando cache R40');
ok((pkg.scripts['test:20101:r42']||'').includes('test-kombax-20101-r42-freeze-candidate.mjs'),'package expone test R42');
ok((pkg.scripts.test||'').includes('test-kombax-20101-r42-freeze-candidate.mjs'),'regresión completa incorpora R42');

if(pass!==24)throw new Error(`FAIL R42: se esperaban 24 comprobaciones y hubo ${pass}`);
console.log(`R42 MOBILE SHELL + NEUTRAL BRANDING: PASS ${pass}/${pass}`);
