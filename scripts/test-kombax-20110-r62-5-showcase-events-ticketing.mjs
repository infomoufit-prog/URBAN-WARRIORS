import assert from 'node:assert/strict';
import {existsSync,readFileSync,readdirSync,statSync} from 'node:fs';
import {join} from 'node:path';
const read=p=>readFileSync(new URL(`../${p}`,import.meta.url),'utf8');
const sql=[
  'supabase/migrations/20260910180156_kombax_r625_connect_event_organizer.sql',
  'supabase/migrations/20260910180332_kombax_r625_ticketing_schema_seller.sql',
  'supabase/migrations/20260910180404_kombax_r625_ticketing_rpcs.sql',
  'supabase/migrations/20260910180447_kombax_r625_checkout_showcase_orders.sql',
  'supabase/migrations/20260910180521_kombax_r625_webhook_privileges.sql',
  'supabase/migrations/20260910180842_kombax_r625_pilot_security_performance_hardening.sql'
].map(read).join('\n');
const verify=read('supabase/verification/verify_r62_5_showcase_events_ticketing.sql');
const checkout=read('supabase/functions/stripe-checkout/index.ts');
const connect=read('supabase/functions/stripe-connect/index.ts');
const repos=read('web/js/core/repositories.js');
const events=read('web/js/modules/kombax-events.js');
const showcase=read('web/js/modules/showcase.js');

for(const path of ['R62_5_SHOWCASE_EVENTS_TICKETING_QA.md','R62_5_TEST_CHECKLIST.md','CHANGELOG_R62_5.md'])assert.ok(existsSync(new URL(`../${path}`,import.meta.url)),`${path} missing`);

assert.match(sql,/^\s*(?:--[^\n]*\n)*\s*begin;/i);
assert.match(sql,/commit;\s*$/i);
assert.equal((sql.match(/\$\$/g)||[]).length%2,0,'SQL dollar quotes unbalanced');
assert.match(sql,/subject_type in\('club','showcase_provider','federation','event_organizer'\)/);
assert.match(sql,/ticketing_mode text not null default 'none'/);
assert.match(sql,/ticketing_mode in\('none','external','kombax'\)/);
assert.match(sql,/create table if not exists kombax_payments\.event_ticket_orders/);
assert.match(sql,/create table if not exists kombax_payments\.event_tickets/);
assert.match(sql,/event_ticket_order_id uuid references kombax_payments\.event_ticket_orders/);
assert.match(sql,/kind in\('club_fee','showcase_order','event_ticket','setup_method'\)/);
assert.match(sql,/EVENT_TICKETS_SOLD_OUT/);
assert.match(sql,/pending_payment' and o\.expires_at>now\(\)/);
assert.match(sql,/app_kombax_event_ticketing_public_r625/);
assert.match(sql,/app_kombax_my_event_tickets_r625/);
assert.match(sql,/app_kombax_event_ticket_sales_r625/);
assert.match(sql,/app_kombax_event_ticket_mutate_r625/);
assert.match(sql,/app_stripe_event_apply_v260/);
assert.match(sql,/insert into kombax_payments\.event_tickets/);
assert.match(sql,/status='refunded'/);
assert.match(sql,/status='disputed'/);
assert.match(sql,/platform_fee_minor/);
assert.doesNotMatch(sql,/application_fee_amount|transfer_data\]\[destination|on_behalf_of/);
assert.doesNotMatch(sql,/auth\.role\s*\(/i);
assert.doesNotMatch(sql,/user_metadata|raw_user_meta_data/i);

assert.match(checkout,/\['club_fee','showcase_order','event_ticket'\]/);
assert.match(checkout,/shipping_address_collection\[allowed_countries\]/);
assert.match(checkout,/phone_number_collection\[enabled\]/);
assert.match(checkout,/idempotencyKey:`kombax-checkout-\$\{attemptId\}`/);
assert.match(connect,/event_organizer/);

assert.match(repos,/app_kombax_event_ticketing_public_r625/);
assert.match(repos,/app_kombax_event_ticketing_mutate_r625/);
assert.match(repos,/app_kombax_my_event_tickets_r625/);
assert.match(repos,/app_kombax_event_ticket_sales_r625/);
assert.match(events,/Mis entradas/);
assert.match(events,/Entradas y cobros/);
assert.match(events,/data-kx-buy-ticket/);
assert.match(events,/checkout\('event_ticket',event\.id,quantity\)/);
assert.match(events,/Venta interna KOMBAX · Stripe Connect/);
assert.match(showcase,/Me interesa/);
assert.match(showcase,/Pago confirmado/);
assert.match(showcase,/Preparando/);
assert.match(showcase,/Enviado/);
assert.match(showcase,/Entregado/);
assert.match(showcase,/showcase-order-progress/);
assert.match(showcase,/shippingLine/);

assert.match(verify,/R625_PLATFORM_TRANSACTION_FEE_MUST_BE_ZERO/);
assert.match(verify,/R625_STRIPE_ACCOUNT_REUSED_ACROSS_ENTITIES/);
assert.match(verify,/R625_TICKET_TABLE_DIRECT_ACCESS_EXPOSED/);

const root=new URL('../',import.meta.url).pathname;
for(const rel of ['web','dist','android/app/src/main/assets/public']){
  const dir=join(root,rel);if(!existsSync(dir))continue;const stack=[dir];
  while(stack.length){const cur=stack.pop();for(const name of readdirSync(cur)){const fp=join(cur,name),st=statSync(fp);if(st.isDirectory())stack.push(fp);else if(st.size<2_000_000){const text=readFileSync(fp,'utf8');assert.doesNotMatch(text,/sk_(?:live|test)_[A-Za-z0-9]{12,}|whsec_[A-Za-z0-9]{12,}/,`Stripe secret leaked: ${fp}`);}}}
}
console.log('KOMBAX R62.5 SHOWCASE + EVENTS TICKETING: PASS');
