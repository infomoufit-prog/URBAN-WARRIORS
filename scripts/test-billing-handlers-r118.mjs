import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {subscriptionIdForEvent,verifyBillingSignature,validateRecurringPrice} from '../supabase/functions/_shared/billing-policy.js';
let passed=0,handler;const check=(name,value)=>{assert.ok(value,name);passed++;};
const json=(status,body)=>new Response(JSON.stringify(body),{status});
let authorized=true,configured=true,tax=true,prior=null,days=30,fail=false,syncCalls=[],forms=[],userCalls=0;
const deps={json,cors:{},env:()=>({appUrl:'https://example.invalid'}),authenticatedUser:async()=>authorized?{id:'fixture',email:'test@example.invalid'}:null,billingConfigured:()=>configured,billingAccount:async()=>({id:'acct_fixture'}),validateRecurringPrice,subscriptionIdForEvent,verifyBillingSignature,
 userRpc:async(r,name)=>{userCalls++;return name.includes('portal')?{customer_id:'cus_fixture'}:{request_id:'00000000-0000-4000-8000-000000000001',price_id:'price_fixture',amount_minor:2390,currency:'eur',livemode:false,trial_days:days,session_id:prior?'cs_fixture':null};},
 serviceRpc:async(name,body)=>{if(fail)throw Error('retry');syncCalls.push({name,body});return {ok:true};},
 billingStripe:async(path,method,form,key)=>{if(method==='POST'){forms.push({path,form,key});return {id:'cs_fixture',url:'https://checkout.stripe.com/fixture'};}if(path.startsWith('checkout/'))return prior;if(path.startsWith('prices/'))return {active:true,type:'recurring',recurring:{interval:'month',interval_count:1},unit_amount:2390,currency:'eur',livemode:false};return {id:'sub_fixture',customer:{id:'cus_fixture'},metadata:{kombax_request_id:'00000000-0000-4000-8000-000000000001',kombax_billing:'r118'},default_payment_method:{id:'pm_fixture'},status:'active'};},
 Deno:{env:{get:name=>name==='STRIPE_BILLING_TAX_READY'?String(tax):'whsec_fixture'},serve:fn=>handler=fn}};
async function load(name){let source=await readFile(`supabase/functions/${name}/index.ts`,'utf8');source=source.replace(/^import .*;\r?\n/gm,'').replace(':Record<string,unknown>','');new Function(...Object.keys(deps),source)(...Object.values(deps));}
const body={action:'checkout',subject_type:'club',subject_id:'00000000-0000-4000-8000-000000000003',consent:true,plan_code:'club',terms_version:'billing-r118-v1'};
const request=b=>new Request('https://example.invalid',{method:'POST',body:JSON.stringify(b)});
await load('stripe-subscriptions');authorized=false;check('Authentication required',(await handler(request(body))).status===401);authorized=true;configured=false;check('No keys cannot start checkout',(await handler(request(body))).status===503);configured=true;tax=false;check('Tax readiness gate',(await handler(request(body))).status===503);tax=true;
check('Explicit consent required',(await handler(request({...body,consent:false}))).status===400);
check('Checkout created',(await handler(request(body))).status===200);
const first=forms.at(-1);check('Trial and card collection',first.form['subscription_data[trial_period_days]']===30&&first.form.payment_method_collection==='always');check('No forced card-only method',!('payment_method_types' in first.form));check('Fixed server redirect',first.form.success_url.startsWith('https://example.invalid/'));check('Stable attempt idempotency',first.key.endsWith('00000000-0000-4000-8000-000000000001'));
prior={status:'open',id:'cs_fixture',url:'https://checkout.stripe.com/prior'};const count=forms.length;await handler(request(body));check('Retry reuses checkout',forms.length===count);
prior={status:'complete'};check('Completed checkout waits for webhook',(await handler(request(body))).status===409);prior=null;days=0;await handler(request(body));check('No second trial',!('subscription_data[trial_period_days]' in forms.at(-1).form));
await handler(request({...body,action:'portal'}));check('Portal uses owned customer',forms.at(-1).form.customer==='cus_fixture');
await load('stripe-billing-webhook');check('Forged webhook rejected',(await handler(request({id:'evt_fixture'}))).status===400);
async function signed(event){const raw=JSON.stringify(event),stamp=Math.floor(Date.now()/1000),key=await crypto.subtle.importKey('raw',new TextEncoder().encode('whsec_fixture'),{name:'HMAC',hash:'SHA-256'},false,['sign']),signature=Buffer.from(await crypto.subtle.sign('HMAC',key,new TextEncoder().encode(`${stamp}.${raw}`))).toString('hex');return new Request('https://example.invalid',{method:'POST',body:raw,headers:{'stripe-signature':`t=${stamp},v1=${signature}`}});}
const event={id:'evt_fixture',type:'invoice.paid',data:{object:{subscription:'sub_fixture'}}};check('Authenticated webhook syncs',(await handler(await signed(event))).status===200);check('Authoritative subscription normalized',syncCalls.at(-1).body.p_subscription.customer==='cus_fixture'&&syncCalls.at(-1).body.p_subscription.default_payment_method==='pm_fixture');
check('Connect events rejected',(await handler(await signed({...event,account:'acct_other'}))).status===400);fail=true;check('Database failure retries webhook',(await handler(await signed(event))).status===500);
console.log(JSON.stringify({passed,failed:0,mode:'isolated actual-handler mocks'},null,2));
