import assert from 'node:assert/strict';
import {existsSync,readFileSync,readdirSync,statSync} from 'node:fs';
import {join} from 'node:path';

const read=p=>readFileSync(new URL(`../${p}`,import.meta.url),'utf8');
const shared=read('supabase/functions/_shared/stripe.ts');
const connect=read('supabase/functions/stripe-connect/index.ts');
const checkout=read('supabase/functions/stripe-checkout/index.ts');
const webhook=read('supabase/functions/stripe-webhook/index.ts');
const migration=read('supabase/migrations/20260910175619_kombax_stripe_connect_hardening_federation_r62_4.sql');
const verify=read('supabase/verification/verify_r62_4_stripe_connect.sql');
const repos=read('web/js/core/repositories.js');
const hub=read('web/js/modules/managed-profile-hub.js');
const showcase=read('web/js/modules/showcase.js');
const app=read('web/js/app.js');

for(const path of ['R62_4_STRIPE_CONNECT_QA.md','R62_4_STRIPE_CONNECT_TEST_CHECKLIST.md','PAYMENTS_R61_ENV.example'])assert.ok(existsSync(new URL(`../${path}`,import.meta.url)),`${path} missing`);

// Stable Accounts v2 and hosted onboarding.
assert.match(shared,/STRIPE_CONNECT_V2_DEFAULT_VERSION='2026-07-29\.dahlia'/);
assert.doesNotMatch(shared,/2026-08-26\.preview/);
assert.match(connect,/stripeV2\('core\/accounts'/);
assert.match(connect,/dashboard:'full'/);
assert.match(connect,/fees_collector:'stripe'/);
assert.match(connect,/losses_collector:'stripe'/);
assert.match(connect,/card_payments:\{requested:true\}/);
assert.match(connect,/future_requirements:'include'/);
assert.match(connect,/core\/account_links/);
assert.match(connect,/connect_type=/);
assert.match(app,/paymentsEntry==='refresh'/);
assert.match(app,/connectOnboarding\(connectType,connectId\)/);

// Club + Marca/Showcase + Federation are recognized, but recipient account is backend-resolved.
assert.match(connect,/\['club','showcase_provider','federation'(?:,'event_organizer')?\]/);
assert.match(migration,/subject_type in\('club','showcase_provider','federation'\)/);
assert.match(migration,/federation_profile_id uuid references public\.perfiles_kombax_directos/);
assert.match(migration,/d\.tipo='federacion'/);
assert.match(migration,/role_code='presidencia'/);
assert.match(migration,/federation\.team\.finance/);
assert.match(hub,/connectStatus\('federation',profile\.id\)/);
assert.match(hub,/connectOnboarding\('federation',profile\.id\)/);
assert.match(showcase,/connectStatus\('showcase_provider',brand\.id\)/);
assert.match(showcase,/connectOnboarding\('showcase_provider',brand\.id\)/);

// Direct charges only and platform fee remains zero.
for(const source of [connect,checkout,migration])assert.doesNotMatch(source,/application_fee_amount|transfer_data\]\[destination|on_behalf_of/);
assert.match(migration,/platform_fee_minor/);
assert.match(migration,/charge_model='direct'/);
assert.match(migration,/stripe_fees_payer='account'/);
assert.match(migration,/losses_responsibility='stripe'/);

// Account binding and checkout creation are idempotent/hardened.
assert.match(migration,/CONNECTED_ACCOUNT_REASSIGNMENT_FORBIDDEN/);
assert.match(migration,/CHECKOUT_REQUEST_ID_REUSED/);
assert.match(checkout,/idempotencyKey:`kombax-checkout-\$\{attemptId\}`/);
assert.match(connect,/idempotencyKey:`kombax-connect-\$\{subjectType\}-\$\{subjectId\}`/);
assert.match(migration,/stripe_checkout_session_id/);
assert.match(migration,/stripe_account_id',v_account\.stripe_account_id/);

// Status is synchronized server-side; internal account IDs are not sourced from the browser.
assert.match(repos,/connectStatus:\(subject_type,subject_id\)=>backend\.invokeFunction\('stripe-connect'/);
assert.match(connect,/app_stripe_connect_runtime_internal_v261/);
assert.match(connect,/app_stripe_connect_sync_internal_v261/);
assert.match(shared,/merchant\?\.capabilities\?\.card_payments/);
assert.match(shared,/stripe_balance\?\.payouts/);
assert.match(shared,/requirements\?\.entries/);
assert.match(verify,/R624_STRIPE_ACCOUNT_REUSED_ACROSS_ENTITIES/);
assert.match(verify,/R624_INTERNAL_CONNECT_RPC_EXPOSED/);

// Snapshot webhook remains signed and idempotent; R62 wrapper enforces account ownership.
assert.match(webhook,/crypto\.subtle\.verify/);
assert.match(webhook,/STRIPE_CONNECT_WEBHOOK_SECRET/);
assert.match(webhook,/app_stripe_event_apply_v260/);
assert.match(read('supabase/migrations/20260909183939_kombax_connect_direct_charges_stripe_managed_fees_r62.sql'),/STRIPE_CONNECTED_ACCOUNT_MISMATCH/);

// No Stripe secrets in client-delivered trees.
const root=new URL('../',import.meta.url).pathname;
for(const rel of ['web','dist','android/app/src/main/assets/public']){
  const dir=join(root,rel);if(!existsSync(dir))continue;
  const stack=[dir];
  while(stack.length){const cur=stack.pop();for(const name of readdirSync(cur)){const fp=join(cur,name);const st=statSync(fp);if(st.isDirectory())stack.push(fp);else if(st.size<2_000_000){const text=readFileSync(fp,'utf8');assert.doesNotMatch(text,/sk_(?:live|test)_[A-Za-z0-9]{12,}|whsec_[A-Za-z0-9]{12,}/,`Stripe secret leaked: ${fp}`);}}}
}

console.log('KOMBAX R62.4 STRIPE CONNECT HARDENING: PASS');
