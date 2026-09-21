import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const has=(txt,frag,msg=frag)=>assert.ok(txt.includes(frag),`Missing ${msg}`);
const not=(txt,frag,msg=frag)=>assert.ok(!txt.includes(frag),`Unexpected ${msg}`);
const pricing=read('web/js/core/commercial-pricing.js');
const events=read('web/js/modules/kombax-events.js');
const showcase=read('web/js/modules/showcase.js');
const migration=read('supabase/migrations/20260913231000_kombax_r644_destacar_accessible.sql');
const stripeCheckout=read('supabase/functions/stripe-checkout/index.ts');
const tests=[]; const test=(n,f)=>tests.push([n,f]);

test('Build 20115 / R64.4 identity',()=>{has(read('web/config.js'),'build: 20115');has(read('web/config.js'),'r64.4-final-pricing');has(read('android/app/build.gradle'),'versionCode 20115');});
test('Destacar fallback is 3/5/8 EUR',()=>has(pricing,'content_promotion:{7:300,15:500,30:800'));
test('Destacar Events selector is 3/5/8 EUR',()=>{has(events,'7 días · 3 €');has(events,'15 días · 5 €');has(events,'30 días · 8 €');not(events,'7 días · 15 €');});
test('Destacar Showcase selector is 3/5/8 EUR',()=>{has(showcase,'7 días · 3 €');has(showcase,'15 días · 5 €');has(showcase,'30 días · 8 €');not(showcase,'7 días · 15 €');});
test('Destacar migration preserves frequency caps',()=>{has(migration,'\"7\":300');has(migration,'\"15\":500');has(migration,'\"30\":800');has(migration,'max_promoted_events_per_user_day');has(migration,'same_event_frequency_hours');has(migration,'no_consecutive_promotions');});
test('Club/Premium/Enterprise current Showcase model preserved',()=>{has(pricing,"plan_code:'club'");has(pricing,'showcase_model_limit:15');has(pricing,"plan_code:'premium'");has(pricing,'showcase_model_limit:25');has(pricing,"plan_code:'enterprise'");});
test('Club Commerce 12 EUR monthly preserved',()=>has(pricing,"commerce_temporary:{30:{price_minor:1200,renewable:true}"));
test('Ticketing tiers preserved',()=>{for(const f of ['50:1000','100:1500','200:2500','500:4500','1000:7500'])has(pricing,f);});
test('Ticketing buyer fee remains zero',()=>has(pricing,'ticketing_buyer_fee_minor:0'));
test('Publication Events pricing preserved',()=>has(pricing,'event_publication:{7:500,15:800,30:1200,60:1800}'));
test('Stripe checkout supports application fee',()=>has(stripeCheckout,"payment_intent_data[application_fee_amount]"));
test('Commercial PDF wired',()=>{has(pricing,"COMMERCIAL_PDF='./assets/docs/commercial/KOMBAX_PLAN_PRECIOS.pdf'");assert.ok(fs.existsSync(path.join(root,'docs/commercial/KOMBAX_PLAN_PRECIOS.pdf')));});

let pass=0;for(const [n,f] of tests){try{f();pass++;console.log(`PASS ${n}`);}catch(e){console.error(`FAIL ${n}: ${e.message}`);process.exitCode=1;}}
console.log(`\nR64.4 Final Pricing QA: ${pass}/${tests.length} passed`);
if(pass!==tests.length)process.exitCode=1;
