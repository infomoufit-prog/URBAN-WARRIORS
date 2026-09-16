import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const root=process.cwd();
const read=(p)=>fs.readFileSync(path.join(root,p),'utf8');
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
const migration=r65MigrationFiles.map(read).join('\n');
const refund=read('supabase/functions/stripe-refund/index.ts');
const finance=read('supabase/functions/stripe-account-finance/index.ts');
const webhook=read('supabase/functions/stripe-webhook/index.ts');
const dispatch=read('supabase/functions/notification-dispatch/index.ts');
const repos=read('web/js/core/repositories.js');
const showcase=read('web/js/modules/showcase.js');
const events=read('web/js/modules/kombax-events.js');
const config=read('web/config.js');
const gradle=read('android/app/build.gradle');
const supaConfig=read('supabase/config.toml');

const tests=[];
const test=(name,fn)=>tests.push([name,fn]);
const has=(text,fragment,msg)=>assert.ok(text.includes(fragment),msg||`Missing: ${fragment}`);

test('R65 identity / build 20116',()=>{has(config,"build: 20116");has(config,"r65-commerce-events-operations");has(gradle,'versionCode 20116');has(gradle,"r65-commerce-events-operations");});
test('Private ledgers exist and are RLS protected',()=>{for(const t of ['commerce_refunds_r65','commerce_refund_tickets_r65','showcase_stock_movements_r65','commerce_communications_r65','commerce_analytics_events_r65','event_refund_batches_r65'])has(migration,t);has(migration,'enable row level security');has(migration,'revoke all on kombax_payments.commerce_refunds_r65');});
test('Direct-charge refund uses application fee return and never reverse_transfer',()=>{has(refund,"refund_application_fee:'true'");assert.ok(!/reverse_transfer\s*[:=]/.test(refund),'reverse_transfer must not be sent for direct charges');has(migration,'Direct charges: refund is created on the connected account. No reverse_transfer.');});
test('Refund is idempotent and Stripe pending is not finalized as success',()=>{has(refund,'kombax-r65-refund-${prepared.refund_id}');has(refund,"stripeStatus==='pending'?'processing'");has(migration,"status in('prepared','processing')");});
test('Partial refunds are explicit and event tickets are mapped exactly',()=>{has(migration,"'partially_refunded'");has(migration,'commerce_refund_tickets_r65');has(migration,"update kombax_payments.event_tickets set status='refunded'");has(migration,'amount_succeeded_minor');});
test('Restock is independent and audited',()=>{has(migration,'restock_requested');has(migration,'showcase_stock_movements_r65');has(showcase,'restock_quantity');has(showcase,'Reintegrar unidades recuperadas al stock');});
test('Event cancellation creates resumable refund processing',()=>{has(migration,'PROCESS_REFUNDS_IN_KOMBAX');has(migration,'event_refund_batches_r65');has(refund,"action==='event_batch'");has(refund,'p_limit:25');});
test('Showcase Finance Center and live Stripe balance are wired',()=>{has(migration,'app_kombax_showcase_finance_r65');has(finance,"stripe('balance','GET'");has(repos,'accountFinance');has(showcase,'openSellerFinance');});
test('Events Finance Center and refunds are wired',()=>{has(migration,'app_kombax_event_finance_r65');has(events,'openEventFinance');has(events,'openEventTicketRefund');has(repos,'refundEventBatch');});
test('Transactional communications use the shared outbox and Resend worker',()=>{has(migration,'commerce_communications_r65');has(migration,'queue_communication_r65');has(dispatch,'dispatchCommerceEmails');has(dispatch,'RESEND_API_KEY');has(showcase,'openSellerCommunications');has(events,'openEventCommunications');});
test('Enterprise BI exists for Showcase and Events and uses real QR audit',()=>{has(migration,'app_kombax_showcase_bi_r65');has(migration,'app_kombax_event_bi_r65');has(migration,'event_ticket_checkin_audit');has(showcase,'openSellerBI');has(events,'openEventBI');});
test('QR access history is operationally exposed',()=>{has(migration,'app_kombax_event_checkin_history_r65');has(repos,'checkinHistory');has(events,'openEventAccessHistory');});
test('Seller operational surface contains refunds, finance, stock and comms',()=>{for(const s of ['openSellerRefund','openSellerFinance','openStockMovements','openSellerCommunications'])has(showcase,s);});
test('Events operational surface contains finance, refunds, comms and access history',()=>{for(const s of ['openEventTicketRefund','openEventFinance','openEventCommunications','openEventAccessHistory'])has(events,s);});
test('Webhook uses R65 partial-refund-safe apply function',()=>{has(webhook,'app_stripe_event_apply_v265');has(migration,'app_stripe_event_apply_v265');has(migration,'kombax_refund_id');});
test('Sensitive R65 Edge functions require JWT',()=>{has(supaConfig,'[functions.stripe-refund]');has(supaConfig,'[functions.stripe-account-finance]');const parts=supaConfig.split(/\n(?=\[functions\.)/);for(const name of ['stripe-refund','stripe-account-finance']){const block=parts.find(x=>x.includes(`[functions.${name}]`));assert.ok(block?.includes('verify_jwt = true'),`${name} must require JWT`);}});
test('R65 event sales projection includes refund state',()=>{has(migration,'app_kombax_event_ticket_sales_r65');has(repos,'app_kombax_event_ticket_sales_r65');has(events,'refundStateLabel');});
test('KOMBAX SaaS Stripe Billing phase 10 remains intentionally untouched',()=>{assert.ok(!fs.existsSync(path.join(root,'supabase/functions/stripe-billing-r65')));assert.ok(!migration.includes('stripe_subscription_id'));});

let passed=0;
for(const [name,fn] of tests){try{fn();console.log(`✓ ${name}`);passed++;}catch(err){console.error(`✗ ${name}`);console.error(err.message);}}
console.log(`\nR65 QA: ${passed}/${tests.length} passed`);
if(passed!==tests.length)process.exit(1);
