import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const has=(txt,frag,msg=frag)=>assert.ok(txt.includes(frag),`Missing ${msg}`);
const not=(txt,frag,msg=frag)=>assert.ok(!txt.includes(frag),`Unexpected ${msg}`);
const tests=[];const test=(name,fn)=>tests.push([name,fn]);

const config=read('web/config.js');
const gradle=read('android/app/build.gradle');
const mainActivity=read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java');
const health=read('supabase/functions/health/index.ts');
const sw=read('web/service-worker.js');
const index=read('web/index.html');
const pricing=read('web/js/core/commercial-pricing.js');
const plans=read('web/js/modules/plan-services.js');
const gateway=read('web/js/modules/gateway.js');
const showcase=read('web/js/modules/showcase.js');
const events=read('web/js/modules/kombax-events.js');
const admin=read('web/js/modules/platform-admin.js');
const r66=read('supabase/migrations/20260913232901_kombax_r66_commercial_discovery_onboarding.sql');
const founderGuard=read('supabase/migrations/20260913233235_kombax_r66_founder_monthly_guard.sql');

// Identity / discovery

test('Historical release functionality remains on a monotonic cumulative build',()=>{
  const webBuild=Number(config.match(/build:\s*(\d+)/)?.[1]||0);const androidBuild=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);
  assert.ok(webBuild>=20134);assert.equal(androidBuild,webBuild);has(mainActivity,`/${webBuild}`);has(health,`build:${webBuild}`);has(sw,`kombax-build-${webBuild}`);has(index,`v=${webBuild}`);
});

test('Global commercial discovery explains free account and organization-scoped plans',()=>{
  has(plans,'export function renderCommercialDiscovery');
  has(plans,'Crear una cuenta KOMBAX es gratuito.');has(plans,'Ser espectador es una forma de uso');
  for(const audience of ["'club'","'brand'","'federation'"])has(plans,audience);
  has(plans,'Cuenta KOMBAX');has(plans,'Identidad');has(plans,'Plan');has(plans,'Verificación');
});

test('Gateway exposes pricing before and after authentication',()=>{
  has(gateway,'gateway-pricing');has(gateway,'Planes y precios');has(gateway,'kx-open-plans');has(gateway,'kx-spectator-plans');
  has(gateway,'renderCommercialDiscovery');
});

test('Club, Brand and Federation preserve optional commercial plans after free identity onboarding',()=>{
  has(gateway,"const COMMERCIAL_TYPE_AUDIENCE=Object.freeze({club:'club',marca:'brand',federacion:'federation'})");
  has(gateway,'chooseCommercialPlan');has(gateway,'startCommercialOnboarding');
  has(gateway,'renderIdentityPresentation(type');has(gateway,'if(isCommercial){if(!globalAuthenticated()');
  not(gateway,'if(isCommercial){chooseCommercialPlan');
});

test('Commercial plan selection survives account/profile creation until verification submission',()=>{
  has(gateway,"kombax_${type}_plan_selection");has(gateway,"kombax_${type}_billing_selection");
  has(gateway,"sessionStorage.setItem('kombax_new_profile_id',saved.id)");
  has(gateway,"const newlyCreatedId=sessionStorage.getItem('kombax_new_profile_id')");
  has(gateway,'saveAndSubmitApplication(newlyCreated.tipo');
});

test('Brand and Federation verification forms carry plan and billing cycle',()=>{
  has(gateway,"{name:'plan_codigo',label:'Plan opcional'");
  has(gateway,"{name:'billing_cycle',label:'Modalidad si eliges un plan'");
  has(gateway,'plan_codigo:commercialAudienceForType(type)');has(gateway,'billing_cycle:commercialAudienceForType(type)');
  has(gateway,'La verificación no realiza ningún cobro');
});

test('Admin review makes selected commercial plan visible without pretending to bill',()=>{
  has(admin,'Identidad y plan siguen separados');
  has(admin,'No realiza ningún cobro ni activa Billing automáticamente');
  has(admin,'Plan solicitado:');
});

test('R66 backend requires valid commercial plan intent for Brand/Federation workflow',()=>{
  has(r66,'app_kombax_direct_commercial_plan_application_guard_r66');
  has(r66,'KOMBAX_COMMERCIAL_PLAN_REQUIRED');has(r66,'KOMBAX_BRAND_PLAN_INVALID');has(r66,'KOMBAX_FEDERATION_PLAN_INVALID');
  has(r66,"new.tipo not in('marca','federacion')");
});

test('Verification creates an auditable plan request but never SaaS Billing',()=>{
  has(r66,'app_kombax_direct_commercial_plan_request_after_verify_r66');
  has(r66,"'billing_activation_performed',false");
  has(r66,"'source','direct_profile_application'");
  not(r66,'stripe_subscription_id');
});

test('Founder server guard remains intact while pilot pricing is publicly locked',()=>{
  has(pricing,'PUBLIC_PRICING_LOCKED=true');
  has(plans,'No disponible hasta lanzamiento');
  has(founderGuard,"v_founder_requested:=v_cycle='monthly'");
  has(founderGuard,"v_founder:=coalesce(v_founder_open,false) and v_cycle='monthly'");
  has(founderGuard,"r.billing_cycle='monthly'");
});

test('Showcase routes Club Basic Commerce into the exact commercial context',()=>{
  has(showcase,'showcaseCommercialDescriptor');has(showcase,'subject_id');
  has(showcase,'Activar Commerce · 12 €/30 días');has(showcase,'renderPlanServices');
  not(showcase,"location.hash='#plans-services'");
});

test('Verified Federation exposes seller onboarding with capacity and Commerce guards',()=>{
  has(showcase,'sellerCapable=!professional');
  has(showcase,"t('marketing.space.sellerEntry')");
  has(showcase,'openSellerCenter(brand)');
  not(showcase,'Federación sin catálogo comercial');
});

test('Events converts plan restrictions into contextual commercial guidance',()=>{
  has(events,'openOrganizerPlanGate');has(events,'Ver plan y servicios');
  has(events,'Publicar un evento, Destacar y Ticketing son capacidades separadas');
  has(events,'renderPlanServices');
});

test('Brand is discoverable as an Event organizer while entitlements remain authoritative',()=>{
  has(r66,"d.tipo in('federacion','marca','profesional','competidor')");
  has(r66,'app_kombax_eventos_sujeto_puede_organizar_v160');
  has(r66,"public.app_kombax_social_tipo_v051(sp.id)='marca'");
});

test('Seller Center only exposes subject identity after manager authorization',()=>{
  has(r66,'kombax_payments.can_manage_provider');has(r66,"raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'");
  has(r66,"'subject_type'");has(r66,"'subject_id'");
});

test('R64.4 commercial prices and limits remain unchanged',()=>{
  for(const frag of ["plan_code:'club'","founder_monthly_minor:2900","standard_monthly_minor:3600","showcase_model_limit:15","plan_code:'premium'","founder_monthly_minor:4700","standard_monthly_minor:5900","showcase_model_limit:25","plan_code:'enterprise'","founder_monthly_minor:7900","standard_monthly_minor:9900","plan_code:'brand_start'","founder_monthly_minor:3900","standard_monthly_minor:4900","plan_code:'brand_growth'","founder_monthly_minor:6900","standard_monthly_minor:8900","plan_code:'brand_enterprise'","founder_monthly_minor:12900","standard_monthly_minor:16100","content_promotion:{7:300,15:500,30:800","commerce_temporary:{30:{price_minor:1200,renewable:true}","event_publication:{7:500,15:800,30:1200,60:1800}","ticketing_buyer_fee_minor:0"])has(pricing,frag);
});

test('R66 migrations match the two live-applied migration versions packaged for Work',()=>{
  assert.ok(fs.existsSync(path.join(root,'supabase/migrations/20260913232901_kombax_r66_commercial_discovery_onboarding.sql')));
  assert.ok(fs.existsSync(path.join(root,'supabase/migrations/20260913233235_kombax_r66_founder_monthly_guard.sql')));
});

test('SaaS Billing remains intentionally out of scope',()=>{
  assert.ok(!fs.existsSync(path.join(root,'supabase/functions/stripe-billing-r66')));
  not(r66,'stripe_subscription_id');not(founderGuard,'stripe_subscription_id');
  has(plans,'Elegir no realiza ningún cobro.');
  has(plans,'Te informaremos de las condiciones y del siguiente paso antes de activar el servicio.');
  not(plans,'Billing automático sigue fuera de esta fase.');
});

let passed=0;
for(const [name,fn] of tests){try{fn();console.log(`✓ ${name}`);passed++;}catch(error){console.error(`✗ ${name}`);console.error(error.message);}}
console.log(`\nR72 COMMERCIAL CONTINUITY: ${passed}/${tests.length} passed`);
if(passed!==tests.length)process.exit(1);
