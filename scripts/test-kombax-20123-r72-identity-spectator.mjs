import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const has=(txt,frag,msg=frag)=>assert.ok(txt.includes(frag),`Missing ${msg}`);
const not=(txt,frag,msg=frag)=>assert.ok(!txt.includes(frag),`Unexpected ${msg}`);
const tests=[];const test=(name,fn)=>tests.push([name,fn]);
const gateway=read('web/js/modules/gateway.js');
const registry=read('web/js/core/profile-registry.js');
const overview=read('web/js/public-product-overview.js');
const app=read('web/js/app.js');
const premium=read('web/css/kombax-premium.css');
const pricing=read('web/js/core/commercial-pricing.js');
const plans=read('web/js/modules/plan-services.js');
const config=read('web/config.js');
const gradle=read('android/app/build.gradle');
const sw=read('web/service-worker.js');
const health=read('supabase/functions/health/index.ts');
const marketingEs=read('web/js/i18n/locales/es/marketing.js');

test('Historical release functionality remains on a monotonic cumulative build',()=>{
  const webBuild=Number(config.match(/build:\s*(\d+)/)?.[1]||0);
  const androidBuild=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);
  assert.ok(webBuild>=20134,'web build must stay at or above the certified R81 baseline');
  assert.equal(androidBuild,webBuild,'Android and Web build identifiers must match');
  has(sw,`kombax-build-${webBuild}`);has(health,`build:${webBuild}`);
});

test('Public gateway uses two routes and a shared free account login',()=>{
  has(gateway,'id="gateway-club"');has(gateway,'id="gateway-direct"');has(gateway,'id="gateway-account-login"');not(gateway,'id="gateway-spectator"');
  has(registry,"id:'espectador'");
  has(gateway,'id="kx-free-account">Crear cuenta gratuita');not(gateway,'Crear cuenta gratuita / Espectador');
});

test('A fresh KOMBAX account remains neutral until the user chooses a route',()=>{
  has(gateway,"marketing.gateway.auth.spectatorStartsTitle");has(marketingEs,'Tu cuenta gratuita no asigna un perfil automáticamente.');
  has(gateway,'CUENTA KOMBAX GRATUITA');not(gateway,'ESPECTADOR · CUENTA GRATUITA');
  has(gateway,'Crear la cuenta no te asigna automáticamente un perfil');
  has(registry,'Ver Social, Showcase y Events');
});

test('Free-account discovery home exposes Social Showcase and Events',()=>{
  for(const id of ['kx-spectator-social','kx-spectator-showcase','kx-spectator-events'])has(gateway,id);
  has(gateway,'Explora ahora. Completa tu perfil cuando quieras.');
  has(gateway,'La publicación Social y la gestión privada aparecen solo cuando una identidad o membresía real las habilita.');
});

test('Spectator home does not surface organization-only Assist or Migrations',()=>{
  const start=gateway.indexOf('freeUnconfiguredAccount?`<section class="kx-spectator-home"');
  const end=gateway.indexOf("${supportDirect?'':`<div class=\"kx-hub-actions",start);
  assert.ok(start>=0&&end>start,'spectator home template not found');
  const block=gateway.slice(start,end);
  not(block,'KOMBAX Assist');not(block,'KOMBAX Migrations');not(block,'Finanzas');not(block,'Alumnos');
});

test('Every creatable identity has a branded presentation before creation',()=>{
  has(gateway,'const identityI18nKey');has(gateway,'const identityCopy');
  for(const type of ['club','brand','federation','fighter','professional','media','spectator'])has(marketingEs,`\"${type}\": {`);
  for(const label of ['PARA QUIÉN ES','QUÉ TE DA','PERMISOS Y PRIVACIDAD','Cómo empiezas'])has(marketingEs,label);
  has(gateway,'data-kombax-view="identity-intro"');
});

test('Club onboarding discovers identity before plan selection',()=>{
  has(gateway,"marketing.gateway.directory.knowClub");has(marketingEs,'Conocer Mi Club');
  has(gateway,"renderIdentityPresentation('club'");
  has(gateway,"marketing.gateway.identity.${key}");
  has(marketingEs,'Tu club, organizado por dentro y reconocible por fuera.');
  has(marketingEs,'Ver planes y solicitar mi Club');
});

test('Commercial identities can start free verification without mandatory plan selection',()=>{
  has(gateway,"commercial:true");
  has(gateway,'if(isCommercial){if(!globalAuthenticated()');
  has(gateway,'saveAndSubmitApplication(type');
  has(gateway,'renderPlanServices({audience:commercialAudienceForType(type)');
  not(gateway,'if(isCommercial){chooseCommercialPlan');
});

test('Non-commercial profiles continue to their profile editor/auth flow after presentation',()=>{
  has(gateway,'if(globalAuthenticated())profileEditor(type');
  has(gateway,'else authChoice({onBack,pendingType:type})');
});

test('Existing authenticated identities can still open Social Showcase and Events',()=>{
  has(gateway,'id="kx-open-social"');has(gateway,'id="kx-open-showcase"');has(gateway,'id="kx-open-events"');
});

test('Public overview accurately counts the spectator participation mode',()=>{
  has(overview,"<strong>7</strong><span>${t('marketing.overview.identities')}</span>");
  has(overview,"t('marketing.overview.manageIdentity')");
  has(marketingEs,'identidades y formas de participar');has(marketingEs,'Quiero crear o gestionar mi identidad');
});

test('Marketing campaigns can deep-link directly to an identity presentation',()=>{
  has(app,"entryParams.get('profile')");has(app,"entryParams.get('discover')");
  has(app,"marketingProfiles=new Set(['club','marca','federacion','competidor','profesional','media','espectador'])");
  has(app,'renderIdentityPresentation(marketingIdentity');
  has(overview,"url.searchParams.set('profile',profile)");
  has(gateway,'export function renderIdentityPresentation');
});

test('R72 preserves responsive presentation/spectator styles',()=>{
  for(const frag of ['.kx-identity-intro-hero','.kx-identity-intro-grid','.kx-spectator-home','.kx-spectator-cards','@media(max-width:720px)'])has(premium,frag);
});

test('R64.4 pricing is untouched by the discovery release',()=>{
  for(const frag of ["plan_code:'club'","founder_monthly_minor:2900","standard_monthly_minor:3600","showcase_model_limit:15","plan_code:'premium'","founder_monthly_minor:4700","standard_monthly_minor:5900","showcase_model_limit:25","plan_code:'enterprise'","founder_monthly_minor:7900","standard_monthly_minor:9900","plan_code:'brand_start'","founder_monthly_minor:3900","standard_monthly_minor:4900","content_promotion:{7:300,15:500,30:800","commerce_temporary:{30:{price_minor:1200,renewable:true}"])has(pricing,frag);
});

test('Pilot pricing lock hides paid prices without deleting the catalog',()=>{
  has(pricing,'PUBLIC_PRICING_LOCKED=true');
  has(plans,'No disponible hasta lanzamiento');
  has(plans,'!PUBLIC_PRICING_LOCKED');
});

let passed=0;
for(const [name,fn] of tests){try{fn();console.log(`✓ ${name}`);passed++;}catch(error){console.error(`✗ ${name}`);console.error(error.message);}}
console.log(`\nR72 IDENTITY + SPECTATOR: ${passed}/${tests.length} passed`);
if(passed!==tests.length)process.exit(1);
