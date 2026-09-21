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
const index=read('web/index.html');
const sw=read('web/service-worker.js');
const commercialCss=read('web/css/kombax-commercial.css');
const components=read('web/js/ui/components.js');
const pricing=read('web/js/core/commercial-pricing.js');
const showcase=read('web/js/modules/showcase.js');
const events=read('web/js/modules/kombax-events.js');
const repos=read('web/js/core/repositories.js');
const checkout=read('supabase/functions/stripe-checkout/index.ts');
const refund=read('supabase/functions/stripe-refund/index.ts');
const financeEdge=read('supabase/functions/stripe-account-finance/index.ts');
const dispatch=read('supabase/functions/notification-dispatch/index.ts');
const webhook=read('supabase/functions/stripe-webhook/index.ts');
const r65MigrationFiles=[
  'supabase/migrations/20260913223620_kombax_r65_commerce_events_operations_part1.sql',
  'supabase/migrations/20260913223644_kombax_r65_commerce_events_operations_part2.sql',
  'supabase/migrations/20260913223707_kombax_r65_refund_prepare.sql',
  'supabase/migrations/20260913223732_kombax_r65_refund_finalize_and_batches.sql',
  'supabase/migrations/20260913223753_kombax_r65_sales_and_finance.sql',
  'supabase/migrations/20260913223819_kombax_r65_bi_qr_order_operations.sql',
  'supabase/migrations/20260913223837_kombax_r65_webhook_v265.sql',
  'supabase/migrations/20260913223848_kombax_r65_outbox_hardening.sql',
]
const r65=r65MigrationFiles.map(read).join('\n');
const r644=read('supabase/migrations/20260913231000_kombax_r644_destacar_accessible.sql');
const r63=read('supabase/migrations/20260912004500_kombax_r63_commercial_compliance_hardening.sql');
const r628Show=read('supabase/migrations/20260911133000_kombax_r628_showcase_orders.sql');
const r628Events=read('supabase/migrations/20260911133100_kombax_r628_events_ticketing_addon.sql');
const supaConfig=read('supabase/config.toml');

test('Release identity is R66 build 20117 everywhere',()=>{
  has(config,"version: '2.0.0-rc.13-r66-commercial-discovery-pilot'");has(config,'build: 20117');
  has(gradle,'versionCode 20117');has(gradle,"versionName '2.0.0-rc.13-r66-commercial-discovery-pilot'");
  has(index,'v=20117');has(sw,"kombax-build-20117");
});

test('R64.1 responsive global navigation is preserved',()=>{
  has(components,'class="icon-btn global-menu-toggle menu-toggle" id="menu-btn"');
  not(components,'class="icon-btn mobile-only menu-toggle" id="menu-btn"');
  has(commercialCss,'.app-shell .global-menu-toggle');has(commercialCss,'.app-shell .sidebar.open');
  has(commercialCss,'@media(min-width:821px)');has(commercialCss,'@media(max-width:820px)');
});

test('R64.4 pricing remains the commercial baseline',()=>{
  has(pricing,'content_promotion:{7:300,15:500,30:800');
  has(pricing,"commerce_temporary:{30:{price_minor:1200,renewable:true}");
  for(const tier of ['50:1000','100:1500','200:2500','500:4500','1000:7500'])has(pricing,tier);
  has(pricing,'ticketing_buyer_fee_minor:0');
  has(pricing,'event_publication:{7:500,15:800,30:1200,60:1800}');
  has(r644,'"7":300');has(r644,'"15":500');has(r644,'"30":800');
});

test('Club/Premium/Enterprise Showcase limits are preserved',()=>{
  has(pricing,"plan_code:'club'");has(pricing,'showcase_model_limit:15');
  has(pricing,"plan_code:'premium'");has(pricing,'showcase_model_limit:25');
  has(pricing,"plan_code:'enterprise'");
});

test('Stripe checkout stays on direct charges with platform application fees',()=>{
  has(checkout,"stripe('checkout/sessions','POST',form,account");
  has(checkout,"payment_intent_data[application_fee_amount]");
  not(checkout,"transfer_data[destination]");not(checkout,"on_behalf_of");
});

test('18+ commercial purchase gate remains server-enforced',()=>{
  has(r63,'KOMBAX_PURCHASE_REQUIRES_18_PLUS');
  has(checkout,'app_kombax_checkout_adult_gate_r629');
});

test('Showcase seller controls preserve stock, fulfillment and order state ownership',()=>{
  has(r628Show,"status_source='seller'");has(r628Show,'seller_responsible_for_fulfillment');
  has(showcase,'Responsabilidad del vendedor');has(showcase,'stock_alert_threshold');has(showcase,'tracking_number');
});

test('Events core/add-on split, ticketing and QR access remain present',()=>{
  has(r628Events,"'events_publish'");has(r628Events,"'events_ticketing'");has(r628Events,'app_event_ticket_checkout_gate_r628');
  has(events,'Solicitar Events + Ticketing');has(events,'Escanear QR');has(events,'Historial accesos');
});

test('R65 migration history matches the eight migrations already applied live',()=>{
  assert.equal(r65MigrationFiles.length,8);
  for(const file of r65MigrationFiles) assert.ok(fs.existsSync(path.join(root,file)),`Missing ${file}`);
  assert.ok(!fs.existsSync(path.join(root,'supabase/migrations/20260914003000_kombax_r65_commerce_events_operations.sql')),'Consolidated R65 migration must not remain in active migrations');
  assert.ok(fs.existsSync(path.join(root,'supabase/migration_archive/R65_CONSOLIDATED_REFERENCE_20260914003000.sql')),'Consolidated reference must be archived');
});

test('R65 private ledgers are service-role only and RLS protected',()=>{
  for(const table of ['commerce_refunds_r65','commerce_refund_tickets_r65','showcase_stock_movements_r65','commerce_communications_r65','commerce_analytics_events_r65','event_refund_batches_r65'])has(r65,table);
  has(r65,'enable row level security');has(r65,'revoke all on kombax_payments.commerce_refunds_r65');
});

test('R65 supports partial refunds without collapsing entire orders',()=>{
  has(r65,"'partially_refunded'");has(r65,'amount_succeeded_minor');has(r65,'commerce_refund_tickets_r65');
  has(webhook,'app_stripe_event_apply_v265');
});

test('Refunds are idempotent and use direct-charge application-fee returns',()=>{
  has(refund,'kombax-r65-refund-${prepared.refund_id}');has(refund,"refund_application_fee:'true'");
  not(refund,'reverse_transfer');has(refund,"stripeStatus==='pending'?'processing'");
});

test('Restock is separate from the financial refund and auditable',()=>{
  has(r65,'restock_requested');has(r65,'showcase_stock_movements_r65');
  has(showcase,'Reintegrar unidades recuperadas al stock');has(showcase,'openStockMovements');
});

test('Showcase Finance Center includes retained platform fee and live Stripe context',()=>{
  has(r65,'app_kombax_showcase_finance_r65');has(r65,'platform_fee_refunded_minor');
  has(r65,"v_fee:=greatest(0,v_fee-coalesce");has(showcase,'openSellerFinance');
  has(financeEdge,"stripe('balance','GET'");has(repos,'accountFinance');
});

test('Events Finance Center and resumable batch refunds are wired',()=>{
  has(r65,'app_kombax_event_finance_r65');has(r65,'event_refund_batches_r65');has(r65,'PROCESS_REFUNDS_IN_KOMBAX');
  has(events,'openEventFinance');has(events,'openEventTicketRefund');has(repos,'refundEventBatch');
});

test('Transactional communication queue and email dispatcher are wired',()=>{
  has(r65,'commerce_communications_r65');has(r65,'queue_communication_r65');
  has(dispatch,'dispatchCommerceEmails');has(dispatch,'RESEND_API_KEY');
  has(showcase,'openSellerCommunications');has(events,'openEventCommunications');
});

test('Enterprise BI is gated and available in Showcase and Events',()=>{
  has(r65,'app_kombax_showcase_bi_r65');has(r65,'app_kombax_event_bi_r65');
  has(showcase,'Business Intelligence · Enterprise');has(events,'BI Enterprise');
});

test('QR access audit is exposed to organizers',()=>{
  has(r65,'app_kombax_event_checkin_history_r65');has(r65,'event_ticket_checkin_audit');
  has(repos,'checkinHistory');has(events,'openEventAccessHistory');
});

test('Sensitive R65 Edge functions require JWT while webhook keeps signature auth',()=>{
  for(const name of ['stripe-refund','stripe-account-finance']){
    const block=supaConfig.split(/\n(?=\[functions\.)/).find(x=>x.includes(`[functions.${name}]`));
    assert.ok(block?.includes('verify_jwt = true'),`${name} must require JWT`);
  }
  const webhookBlock=supaConfig.split(/\n(?=\[functions\.)/).find(x=>x.includes('[functions.stripe-webhook]'));
  assert.ok(webhookBlock?.includes('verify_jwt = false'),'stripe-webhook must stay signature-authenticated');
  has(webhook,'stripe-signature');
});

test('R66 commercial-discovery migrations are additive on top of the closed R65 ledger',()=>{
  for(const file of ['supabase/migrations/20260913232901_kombax_r66_commercial_discovery_onboarding.sql','supabase/migrations/20260913233235_kombax_r66_founder_monthly_guard.sql']) assert.ok(fs.existsSync(path.join(root,file)),`Missing ${file}`);
});

test('KOMBAX SaaS Billing phase 10 remains intentionally out of scope',()=>{
  assert.ok(!fs.existsSync(path.join(root,'supabase/functions/stripe-billing-r65')));
  not(r65,'stripe_subscription_id');
});

test('Commercial PDF remains packaged',()=>{
  has(pricing,"COMMERCIAL_PDF='./assets/docs/commercial/KOMBAX_PLAN_PRECIOS.pdf'");
  assert.ok(fs.existsSync(path.join(root,'docs/commercial/KOMBAX_PLAN_PRECIOS.pdf')));
  assert.ok(fs.existsSync(path.join(root,'web/assets/docs/commercial/KOMBAX_PLAN_PRECIOS.pdf')));
});

let passed=0;
for(const [name,fn] of tests){
  try{fn();console.log(`✓ ${name}`);passed++;}
  catch(error){console.error(`✗ ${name}`);console.error(error.message);}
}
console.log(`\nR66 RELEASE REGRESSION: ${passed}/${tests.length} passed`);
if(passed!==tests.length)process.exit(1);
