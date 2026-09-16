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

test('R69 identity is build 20120 across Web Android SW and health',()=>{
  has(config,"version: '2.0.0-rc.13-r69-events-operations-center'");has(config,'build: 20120');
  has(gradle,'versionCode 20120');has(gradle,"versionName '2.0.0-rc.13-r69-events-operations-center'");
  has(sw,'kombax-build-20120');has(health,'build:20120');
});

test('Public gateway offers a profile-free spectator path',()=>{
  has(gateway,'id="gateway-spectator"');has(gateway,'Quiero explorar KOMBAX primero');
  has(gateway,"renderIdentityPresentation('espectador'");
  has(gateway,'Crear cuenta gratuita / Espectador');
});

test('A fresh KOMBAX account is explicitly explained as Spectator',()=>{
  has(gateway,'Tu cuenta empieza como Espectador.');
  has(gateway,'ESPECTADOR · CUENTA GRATUITA');
  has(gateway,'Tu cuenta ya puede explorar KOMBAX');
  has(registry,'Ver Social, Showcase y Events');
});

test('Spectator home exposes Social Showcase and Events as primary discovery cards',()=>{
  for(const id of ['kx-spectator-social','kx-spectator-showcase','kx-spectator-events'])has(gateway,id);
  has(gateway,'Empieza mirando. Decide tu perfil después.');
  has(gateway,'La gestión privada solo aparecerá cuando una identidad o membresía te conceda ese acceso.');
});

test('Spectator home does not surface organization-only Assist or Migrations',()=>{
  const start=gateway.indexOf('spectatorAccount?`<section class="kx-spectator-home"');
  const end=gateway.indexOf("${supportDirect?'':`<div class=\"kx-hub-actions",start);
  assert.ok(start>=0&&end>start,'spectator home template not found');
  const block=gateway.slice(start,end);
  not(block,'KOMBAX Assist');not(block,'KOMBAX Migrations');not(block,'Finanzas');not(block,'Alumnos');
});

test('Every creatable identity has a branded presentation before creation',()=>{
  has(gateway,'const IDENTITY_PRESENTATION=Object.freeze');
  for(const type of ['club','marca','federacion','competidor','profesional','media','espectador'])has(gateway,`${type}:{`);
  for(const label of ['PARA QUIÉN ES','QUÉ TE DA','PERMISOS Y PRIVACIDAD','Cómo empiezas'])has(gateway,label);
  has(gateway,'data-kombax-view="identity-intro"');
});

test('Club onboarding discovers identity before plan selection',()=>{
  has(gateway,'Conocer Mi Club');
  has(gateway,"renderIdentityPresentation('club'");
  has(gateway,'Tu club, organizado por dentro y reconocible por fuera.');
  has(gateway,'Ver planes y solicitar mi Club');
});

test('Commercial profiles still enter plan-first onboarding after presentation',()=>{
  has(gateway,'if(isCommercial){chooseCommercialPlan');
  has(gateway,"commercial:true");
  has(gateway,'Comparar planes');
  has(gateway,'renderPlanServices({audience:commercialAudienceForType(type)');
});

test('Non-commercial profiles continue to their profile editor/auth flow after presentation',()=>{
  has(gateway,'if(globalAuthenticated())profileEditor(type');
  has(gateway,'else authChoice({onBack,pendingType:type})');
});

test('Existing authenticated identities can still open Social Showcase and Events',()=>{
  has(gateway,'id="kx-open-social"');has(gateway,'id="kx-open-showcase"');has(gateway,'id="kx-open-events"');
});

test('Public overview accurately counts the spectator participation mode',()=>{
  has(overview,'<strong>7</strong><span>identidades y formas de participar</span>');
  has(overview,'Quiero crear o gestionar mi identidad');
});

test('Marketing campaigns can deep-link directly to an identity presentation',()=>{
  has(app,"entryParams.get('profile')");has(app,"entryParams.get('discover')");
  has(app,"marketingProfiles=new Set(['club','marca','federacion','competidor','profesional','media','espectador'])");
  has(app,'renderIdentityPresentation(marketingIdentity');
  has(overview,"url.searchParams.set('profile',profile)");
  has(gateway,'export function renderIdentityPresentation');
});

test('R69 preserves responsive presentation/spectator styles',()=>{
  for(const frag of ['.kx-identity-intro-hero','.kx-identity-intro-grid','.kx-spectator-home','.kx-spectator-cards','@media(max-width:720px)'])has(premium,frag);
});

test('R64.4 pricing is untouched by the discovery release',()=>{
  for(const frag of ["plan_code:'club'","founder_monthly_minor:2900","standard_monthly_minor:3600","showcase_model_limit:15","plan_code:'premium'","founder_monthly_minor:4700","standard_monthly_minor:5900","showcase_model_limit:25","plan_code:'enterprise'","founder_monthly_minor:7900","standard_monthly_minor:9900","plan_code:'brand_start'","founder_monthly_minor:3900","standard_monthly_minor:4900","content_promotion:{7:300,15:500,30:800","commerce_temporary:{30:{price_minor:1200,renewable:true}"])has(pricing,frag);
});

test('Founder monthly-only guard and Billing-out-of-scope message remain visible',()=>{
  has(plans,"const useFounder=billing==='monthly'&&founderEligible");
  has(plans,'Billing automático sigue fuera de esta fase.');
});

let passed=0;
for(const [name,fn] of tests){try{fn();console.log(`✓ ${name}`);passed++;}catch(error){console.error(`✗ ${name}`);console.error(error.message);}}
console.log(`\nR69 IDENTITY + SPECTATOR: ${passed}/${tests.length} passed`);
if(passed!==tests.length)process.exit(1);
