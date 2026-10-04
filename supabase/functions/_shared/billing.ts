import {env} from './stripe.ts';
export async function billingStripe(path:string,method='GET',form:Record<string,unknown>={},idempotencyKey=''){
 const key=Deno.env.get('STRIPE_BILLING_SECRET_KEY')||'';
 const account=Deno.env.get('STRIPE_BILLING_ACCOUNT_ID')||'';
 if(!key||!account)throw new Error('BILLING_NOT_CONFIGURED');
 const response=await fetch(`https://api.stripe.com/v1/${path}`,{method,headers:{authorization:`Bearer ${key}`,'Stripe-Version':Deno.env.get('STRIPE_BILLING_API_VERSION')||'2026-09-30.endive',...(method==='GET'?{}:{'content-type':'application/x-www-form-urlencoded'}),...(idempotencyKey?{'Idempotency-Key':idempotencyKey}:{})},...(method==='GET'?{}:{body:new URLSearchParams(Object.entries(form).filter(([,v])=>v!==undefined&&v!==null).map(([k,v])=>[k,String(v)]))}),signal:AbortSignal.timeout(20000)});
 const data=await response.json();if(!response.ok)throw new Error('BILLING_STRIPE_REQUEST_FAILED');return data;
}
export function billingConfigured(){return Boolean(Deno.env.get('STRIPE_BILLING_SECRET_KEY')&&Deno.env.get('STRIPE_BILLING_ACCOUNT_ID')&&env().appUrl);}
export async function billingAccount(){const account=await billingStripe('account');if(account.id!==Deno.env.get('STRIPE_BILLING_ACCOUNT_ID'))throw new Error('BILLING_ACCOUNT_MISMATCH');return account;}
