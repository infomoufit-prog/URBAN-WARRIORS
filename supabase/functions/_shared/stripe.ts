export const cors={
  'access-control-allow-origin':'*',
  'access-control-allow-headers':'authorization, apikey, content-type, x-client-info, stripe-signature',
  'access-control-allow-methods':'POST, OPTIONS'
};

export const STRIPE_CONNECT_V2_DEFAULT_VERSION='2026-07-29.dahlia';

type StripeRequestOptions={idempotencyKey?:string};

export function json(status:number,body:Record<string,unknown>){
  return new Response(JSON.stringify(body),{status,headers:{...cors,'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff','referrer-policy':'no-referrer'}});
}

function keyFromMap(raw:string|undefined){
  if(!raw)return '';
  try{const value=JSON.parse(raw);return String(value?.default||Object.values(value||{})[0]||'');}catch{return '';}
}

function normalizedAppUrl(raw:string){
  if(!raw)return '';
  try{
    const url=new URL(raw);
    const local=['localhost','127.0.0.1','::1'].includes(url.hostname.toLowerCase());
    if(url.protocol!=='https:'&&!(url.protocol==='http:'&&local))return '';
    url.username='';url.password='';url.search='';url.hash='';
    return url.toString().replace(/\/+$/,'');
  }catch{return '';}
}

export function env(){
  const supabaseUrl=(Deno.env.get('SUPABASE_URL')||'').replace(/\/+$/,'');
  const publishableKey=keyFromMap(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS'))||Deno.env.get('SUPABASE_ANON_KEY')||'';
  const secretKey=keyFromMap(Deno.env.get('SUPABASE_SECRET_KEYS'))||Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||'';
  const stripeConnectKey=Deno.env.get('STRIPE_CONNECT_SECRET_KEY')||'';
  const stripeConnectApiVersion=Deno.env.get('STRIPE_CONNECT_API_VERSION')||STRIPE_CONNECT_V2_DEFAULT_VERSION;
  const appUrl=normalizedAppUrl(Deno.env.get('KOMBAX_APP_URL')||'');
  return {supabaseUrl,publishableKey,secretKey,stripeConnectKey,stripeConnectApiVersion,appUrl};
}

export async function authenticatedUser(request:Request){
  const {supabaseUrl,publishableKey}=env();
  const bearer=request.headers.get('authorization')||'';
  if(!bearer.toLowerCase().startsWith('bearer '))return null;
  const response=await fetch(`${supabaseUrl}/auth/v1/user`,{headers:{apikey:publishableKey,authorization:bearer},signal:AbortSignal.timeout(8000)});
  if(!response.ok)return null;
  return await response.json().catch(()=>null);
}

export async function serviceRpc(name:string,payload:Record<string,unknown>){
  const {supabaseUrl,secretKey}=env();
  const response=await fetch(`${supabaseUrl}/rest/v1/rpc/${name}`,{method:'POST',headers:{apikey:secretKey,authorization:`Bearer ${secretKey}`,'content-type':'application/json'},body:JSON.stringify(payload),signal:AbortSignal.timeout(15000)});
  const raw=await response.text();let data:any=null;try{data=raw?JSON.parse(raw):null}catch{data=raw}
  if(!response.ok)throw new Error(String(data?.message||data?.code||`RPC_${response.status}`));
  return data;
}

export async function userRpc(request:Request,name:string,payload:Record<string,unknown>){
  const {supabaseUrl,publishableKey}=env();const bearer=request.headers.get('authorization')||'';
  const response=await fetch(`${supabaseUrl}/rest/v1/rpc/${name}`,{method:'POST',headers:{apikey:publishableKey,authorization:bearer,'content-type':'application/json'},body:JSON.stringify(payload),signal:AbortSignal.timeout(15000)});
  const raw=await response.text();let data:any=null;try{data=raw?JSON.parse(raw):null}catch{data=raw}
  if(!response.ok)throw new Error(String(data?.message||data?.code||`RPC_${response.status}`));
  return data;
}

export async function stripe(path:string,method='POST',form:Record<string,unknown>={},connectedAccount='',options:StripeRequestOptions={}){
  const {stripeConnectKey}=env();
  const body=new URLSearchParams();
  for(const [key,value] of Object.entries(form))if(value!==undefined&&value!==null&&value!=='')body.set(key,String(value));
  const headers:Record<string,string>={authorization:`Bearer ${stripeConnectKey}`,...(connectedAccount?{'Stripe-Account':connectedAccount}:{}),...(method==='GET'?{}:{'content-type':'application/x-www-form-urlencoded'})};
  if(options.idempotencyKey&&method!=='GET')headers['Idempotency-Key']=options.idempotencyKey.slice(0,255);
  const response=await fetch(`https://api.stripe.com/v1/${path.replace(/^\/+/, '')}`,{method,headers,...(method==='GET'?{}:{body}),signal:AbortSignal.timeout(20000)});
  const data=await response.json().catch(()=>({}));
  if(!response.ok)throw new Error(String(data?.error?.message||`STRIPE_${response.status}`));
  return data;
}

function addV2Query(url:URL,payload:Record<string,unknown>){
  for(const [key,value] of Object.entries(payload)){
    if(value===undefined||value===null||value==='')continue;
    if(Array.isArray(value)){value.forEach((item,index)=>url.searchParams.set(`${key}[${index}]`,String(item)));continue;}
    url.searchParams.set(key,String(value));
  }
}

export async function stripeV2(path:string,method='POST',payload:Record<string,unknown>={},options:StripeRequestOptions={}){
  const {stripeConnectKey,stripeConnectApiVersion}=env();
  const url=new URL(`https://api.stripe.com/v2/${path.replace(/^\/+/, '')}`);
  if(method==='GET')addV2Query(url,payload);
  const headers:Record<string,string>={authorization:`Bearer ${stripeConnectKey}`,'Stripe-Version':stripeConnectApiVersion};
  if(method!=='GET')headers['content-type']='application/json';
  if(options.idempotencyKey&&method!=='GET')headers['Idempotency-Key']=options.idempotencyKey.slice(0,255);
  const response=await fetch(url,{method,headers,...(method==='GET'?{}:{body:JSON.stringify(payload)}),signal:AbortSignal.timeout(20000)});
  const data=await response.json().catch(()=>({}));
  if(!response.ok)throw new Error(String(data?.error?.message||data?.detail||`STRIPE_V2_${response.status}`));
  return data;
}

function requirementDeadline(entry:any){
  const own=String(entry?.minimum_deadline?.status||'');
  if(own)return own;
  const impacts=Array.isArray(entry?.impact?.restricts_capabilities)?entry.impact.restricts_capabilities:[];
  return String(impacts.map((x:any)=>x?.deadline?.status).find(Boolean)||'');
}

function compactRequirement(entry:any){
  return {
    description:String(entry?.description||'requirement').slice(0,180),
    awaiting_action_from:String(entry?.awaiting_action_from||''),
    deadline_status:requirementDeadline(entry)||null
  };
}

function capabilityReason(capability:any,prefix:string){
  if(!capability||!['restricted','unsupported'].includes(String(capability.status||'')))return [] as string[];
  const details=Array.isArray(capability.status_details)?capability.status_details:[];
  return details.map((x:any)=>`${prefix}:${String(x?.code||capability.status||'restricted')}`).slice(0,4);
}

export function stripeV2AccountState(account:any){
  const merchant=account?.configuration?.merchant||{};
  const card=merchant?.capabilities?.card_payments||{};
  const payouts=merchant?.capabilities?.stripe_balance?.payouts||{};
  const entries=Array.isArray(account?.requirements?.entries)?account.requirements.entries:[];
  const futureEntries=Array.isArray(account?.future_requirements?.entries)?account.future_requirements.entries:[];
  const due=entries.filter((entry:any)=>entry?.awaiting_action_from!=='stripe'&&['currently_due','past_due'].includes(requirementDeadline(entry))).map(compactRequirement);
  const pending=entries.filter((entry:any)=>entry?.awaiting_action_from==='stripe').map(compactRequirement);
  const eventually=[...entries,...futureEntries].filter((entry:any)=>entry?.awaiting_action_from!=='stripe'&&requirementDeadline(entry)==='eventually_due').map(compactRequirement);
  const chargesEnabled=String(card?.status||'')==='active';
  const payoutsEnabled=String(payouts?.status||'')==='active';
  const reasons=[...capabilityReason(card,'card_payments'),...capabilityReason(payouts,'payouts')];
  const disabledReason=account?.closed?'account_closed':(reasons.length?reasons.join(','):null);
  const detailsSubmitted=chargesEnabled&&payoutsEnabled||due.length===0&&pending.length>0;
  return {detailsSubmitted,chargesEnabled,payoutsEnabled,requirementsDue:due,requirementsEventuallyDue:eventually,requirementsPendingVerification:pending,disabledReason};
}

export function safeError(error:unknown){return String(error instanceof Error?error.message:error).replace(/sk_(live|test)_[A-Za-z0-9]+/g,'[secret]').slice(0,300);}
