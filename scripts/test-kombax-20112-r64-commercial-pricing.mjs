import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const root=process.cwd();
const read=(p)=>fs.readFileSync(path.join(root,p),'utf8');
const pricing=read('web/js/core/commercial-pricing.js');
const planUi=read('web/js/modules/plan-services.js');
const repos=read('web/js/core/repositories.js');
const events=read('web/js/modules/kombax-events.js');
const showcase=read('web/js/modules/showcase.js');
const social=read('web/js/modules/kombax-social.js');
const finance=read('web/js/modules/finance.js')+read('web/js/modules/finance-premium.js');
const profileRegistry=read('web/js/core/profile-registry.js');
const stripeFn=read('supabase/functions/stripe-checkout/index.ts');
const m1=read('supabase/migrations/20260912210000_kombax_r64_commercial_pricing_foundation.sql');
const m2=read('supabase/migrations/20260912211000_kombax_r64_connect_platform_fees_ticketing.sql');
const m3=read('supabase/migrations/20260912212000_kombax_r64_events_ai_partner_runtime.sql');
const m4=read('supabase/migrations/20260912213000_kombax_r64_migrations_brand_guide_access.sql');
const m5=read('supabase/migrations/20260912214000_kombax_r64_plan_compat_ticketing_promotion.sql');

const tests=[];
const test=(name,fn)=>tests.push([name,fn]);
const has=(text,fragment,msg=fragment)=>assert.ok(text.includes(fragment),`Missing ${msg}`);

// Version + pricing
test('R64 build identity',()=>{has(read('web/config.js'),'20112');has(read('android/app/build.gradle'),'versionCode 20112');has(read('android/app/build.gradle'),'r64-commercial-pricing');});
test('Club pricing final',()=>{for(const x of ["founder_monthly_minor:2900","standard_monthly_minor:3600","standard_annual_minor:36300","founder_monthly_minor:4700","standard_monthly_minor:5900","standard_annual_minor:59500","founder_monthly_minor:7900","standard_monthly_minor:9900","standard_annual_minor:99800"])has(pricing,x);});
test('Brand + Federation pricing final',()=>{for(const x of ["founder_monthly_minor:3900","standard_monthly_minor:4900","standard_annual_minor:49400","founder_monthly_minor:6900","standard_monthly_minor:8900","standard_annual_minor:89700","founder_monthly_minor:12900","standard_monthly_minor:16100","standard_annual_minor:162300","founder_monthly_minor:1900","standard_monthly_minor:2400","standard_annual_minor:24200"])has(pricing,x);});
test('Annual 16 and Founder rules',()=>{has(pricing,'annual_discount_percent:16');has(pricing,'founder_sales_open:true');has(planUi,'No acumulable con el descuento anual');has(m1,'founder_lost_at');has(m1,'founder_sales_open');});

test('Platform fees 1.5/0',()=>{has(pricing,"plan_code:'premium'");has(pricing,"platform_fee_percent:1.5");has(pricing,"plan_code:'enterprise'");has(pricing,"platform_fee_percent:0");has(stripeFn,'application_fee_amount');has(m2,'platform_fee_minor');});
test('Break-even displayed',()=>{has(planUi,'2.134 €/mes');has(planUi,'2.666,67 €/mes');has(planUi,'26.880 €/año');});

// Commerce / events / ticketing
test('Commerce temporary prices + anti-cannibalization',()=>{for(const x of ['7:{price_minor:900}','30:{price_minor:1900}','90:{price_minor:5900}','rolling_12m_max_days:120','max_consecutive_days:90','cooldown_days:30'])has(pricing,x);});
test('Event publication pricing',()=>{has(pricing,'event_publication:{7:500,15:800,30:1200,60:1800}');});
test('Single promotion pricing and caps',()=>{has(pricing,'content_promotion:{7:1500,15:2400,30:3500');has(pricing,'max_promoted_events_per_user_day:2');has(pricing,'same_event_frequency_hours:72');has(m5,"'CONTENT_PROMOTION'");has(m5,'app_kombax_social_promotions_r64');has(m5,'app_kombax_promoted_events_r64');has(events,'Destacar evento');has(showcase,'Destacar');});
test('No commercial Spotlight product',()=>{assert.ok(!planUi.includes('Spotlight'));assert.ok(!pricing.includes('EVENT_SPOTLIGHT'));});
test('Ticketing buyer fee 1.50 and QR/access included',()=>{has(pricing,'ticketing_buyer_fee_minor:150');has(events,'QR, lector y control de puerta');has(planUi,'QR, lector y control de acceso');has(m2,'ticketing_buyer_fee_minor');has(m2,'buyer_service_fee_minor');});
test('Large event threshold 1000',()=>{has(pricing,'large_event_threshold:1000');has(planUi,'Gran Evento');has(m2,'large_event_threshold');});

// Profiles / onboarding
test('Professional taxonomy reuses Trainer/Organizer specialties',()=>{has(profileRegistry,"{code:'entrenador'");has(profileRegistry,"{code:'promotor_organizador'");has(profileRegistry,"{id:'profesional'");assert.ok(!profileRegistry.includes("{id:'entrenador'"));assert.ok(!profileRegistry.includes("{id:'promotor_organizador'"));});
test('18+ commercial gates remain present',()=>{has(read('supabase/migrations/20260912004500_kombax_r63_commercial_compliance_hardening.sql'),'KOMBAX_PURCHASE_REQUIRES_18_PLUS');});
test('Brand verification/commercial provider protections remain',()=>{has(m2,'can_manage_provider');});

// Assist / migrations / partner
test('Assist and Migrations tiers',()=>{has(pricing,'assist_limits:{base:10,plus:30,pro:100}');has(pricing,'migrations_limits:{base:2,plus:10,pro:30}');has(m3,"('KOMBAX_PRO',100,100");has(m3,"v_type not in('federacion','marca')");has(m4,'migration_access_allowed');});
test('Partner 25/30 and annual pending',()=>{has(pricing,"'1_9_percent':25");has(pricing,"'10_plus_percent':30");has(pricing,'commissioned_installments_start:2');has(pricing,'commissioned_installments_end:13');has(pricing,"annual_billing_reward_rule:'pending'");has(planUi,'cuotas 2–13');has(planUi,'pendiente de regla');});

// UI/documentation
test('Plan & Services and PDF are wired',()=>{has(read('web/index.html'),'kombax-commercial.css');has(repos,'app_kombax_commercial_catalog_r64');has(read('web/js/modules/club-kombax-hub.js'),'plans-services');has(read('web/js/app.js'),'renderPlanServices');has(read('web/js/modules/managed-profile-hub.js'),'renderPlanServices');assert.ok(fs.existsSync(path.join(root,'web/assets/docs/commercial/KOMBAX_PLAN_PRECIOS.pdf')));assert.ok(fs.existsSync(path.join(root,'docs/commercial/KOMBAX_PLAN_PRECIOS.pdf')));});
test('Social amplification UI is interleaved, not consecutive',()=>{has(social,'socialPromotions');has(social,'index===1');has(social,'index===5');has(social,'promotionImpression');has(m5,'promotion_can_serve_r64');});
test('Showcase active promotion dynamically influences listing',()=>{has(m5,'app_kombax_showcase_list_v054');has(m5,"pc.content_type='showcase_product'");has(m5,"'Destacado KOMBAX'");});
test('Events active promotion is prepended to discovery',()=>{has(repos,'app_kombax_promoted_events_r64');has(events,'kombax_promoted');has(events,'repos.kombaxEvents.promoted(6)');});

test('No stale zero-fee user copy',()=>{assert.ok(!finance.includes('KOMBAX no recibe estos fondos'));});

let passed=0;
for(const [name,fn] of tests){try{fn();passed++;console.log(`PASS ${name}`);}catch(err){console.error(`FAIL ${name}: ${err.message}`);process.exitCode=1;}}
console.log(`\nR64 commercial pricing QA: ${passed}/${tests.length} passed`);
if(passed!==tests.length)process.exitCode=1;
