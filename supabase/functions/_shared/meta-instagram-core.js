// Pure Web APIs; dependencies injected for isolated tests. No provider secrets in logs.
export const META_PERMISSIONS=['business_management','instagram_basic','instagram_content_publish','pages_read_engagement','pages_show_list'];
// Origin used by this repository's Android WebViewAssetLoader (MainActivity.java).
const ANDROID_ORIGIN='https://appassets.androidplatform.net';
const hex=b=>Array.from(new Uint8Array(b),x=>x.toString(16).padStart(2,'0')).join('');
export const randomSecret=()=>hex(crypto.getRandomValues(new Uint8Array(32)));
export const sha256=async s=>hex(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s)));
const enc=new TextEncoder(),dec=new TextDecoder();
const b64=b=>{const bytes=new Uint8Array(b);let s='';for(let i=0;i<bytes.length;i+=16384)s+=String.fromCharCode(...bytes.subarray(i,i+16384));return btoa(s);};
const unb64=s=>Uint8Array.from(atob(s),c=>c.charCodeAt(0));
const unurl=s=>unb64(s.replaceAll('-','+').replaceAll('_','/').padEnd(Math.ceil(s.length/4)*4,'='));
const uuid=s=>/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(s||''));
const digits=s=>/^[0-9]{1,40}$/.test(String(s||''));
class MetaError extends Error{constructor(code){super(code);this.code=code;}}
export function configFrom(read){
 const get=k=>String(read(k)||'').trim();
 const base=get('SUPABASE_URL').replace(/\/+$/,'');
 const app=get('KOMBAX_APP_URL').replace(/\/+$/,'');
 let appURL,baseURL;try{appURL=new URL(app);baseURL=new URL(base);}catch{throw new MetaError('configuration');}
 if(appURL.protocol!=='https:'||appURL.pathname!=='/'||appURL.search||appURL.hash||appURL.username||appURL.password||baseURL.protocol!=='https:'||baseURL.username||baseURL.password||baseURL.search||baseURL.hash)throw new MetaError('configuration');
 const cfg={base,app,appId:get('META_APP_ID'),configId:get('META_LOGIN_CONFIG_ID'),secret:get('META_APP_SECRET'),version:get('META_GRAPH_API_VERSION'),key:get('META_TOKEN_ENCRYPTION_KEY')};
 if(!digits(cfg.appId)||!digits(cfg.configId)||!cfg.secret||!/^v\d+\.\d+$/.test(cfg.version)||!/^[0-9a-f]{64}$/i.test(cfg.key))throw new MetaError('configuration');
 return {...cfg,redirect:`${base}/functions/v1/meta-instagram-callback`};
}
export async function seal(value,keyHex,aad){
 const key=await crypto.subtle.importKey('raw',Uint8Array.from(keyHex.match(/../g),x=>parseInt(x,16)),{name:'AES-GCM'},false,['encrypt']);
 const iv=crypto.getRandomValues(new Uint8Array(12));
 return `v1.${b64(iv)}.${b64(await crypto.subtle.encrypt({name:'AES-GCM',iv,additionalData:enc.encode(aad)},key,enc.encode(JSON.stringify(value))))}`;
}
export async function unseal(value,keyHex,aad){
 const [v,iv,data]=String(value||'').split('.');if(v!=='v1'||!iv||!data)throw new MetaError('credential');
 const key=await crypto.subtle.importKey('raw',Uint8Array.from(keyHex.match(/../g),x=>parseInt(x,16)),{name:'AES-GCM'},false,['decrypt']);
 return JSON.parse(dec.decode(await crypto.subtle.decrypt({name:'AES-GCM',iv:unb64(iv),additionalData:enc.encode(aad)},key,unb64(data))));
}
export async function verifySignedRequest(raw,secret,now=Date.now()){
 if(typeof raw!=='string'||raw.length>12000)throw new MetaError('signed_request');
 const [sig,payload,...rest]=raw.split('.');if(!sig||!payload||rest.length)throw new MetaError('signed_request');
 let data;try{data=JSON.parse(dec.decode(unurl(payload)));}catch{throw new MetaError('signed_request');}
 if(data.algorithm!=='HMAC-SHA256'||!digits(data.user_id)||!Number.isFinite(data.issued_at)||data.issued_at*1000>now+60000||data.issued_at*1000<now-86400000)throw new MetaError('signed_request');
 const key=await crypto.subtle.importKey('raw',enc.encode(secret),{name:'HMAC',hash:'SHA-256'},false,['verify']);
 if(!await crypto.subtle.verify('HMAC',key,unurl(sig),enc.encode(payload)))throw new MetaError('signed_request');
 return data;
}
export function createMetaIntegration({config,rpc,userContext,authenticate,fetcher=fetch,log=()=>{}}){
 const internal=(action,actor=null,id=null,data={})=>rpc({p_action:action,p_actor:actor,p_id:id,p_data:data});
 const safeLog=(event,actor=null,social=null,object=null)=>log({event,actor_id:actor,social_id:social,object_id:object});
 const headers={'cache-control':'no-store','referrer-policy':'no-referrer','x-content-type-options':'nosniff'};
 function json(request,status,data,cfg){
  const h={...headers,'content-type':'application/json; charset=utf-8'};
  const origin=request.headers.get('origin');
  if(cfg&&[cfg.app,ANDROID_ORIGIN].includes(origin)){h['access-control-allow-origin']=origin;h['vary']='Origin';h['access-control-allow-headers']='authorization,apikey,content-type,x-client-info';h['access-control-allow-methods']='POST, OPTIONS';}
  return new Response(JSON.stringify(data),{status,headers:h});
 }
 async function graph(cfg,path,token='',method='GET',params={}){
  const url=new URL(`https://graph.facebook.com/${cfg.version}/${path}`);
  const form=new URLSearchParams(params),h={};
  if(token){h.authorization=`Bearer ${token}`;
   const key=await crypto.subtle.importKey('raw',enc.encode(cfg.secret),{name:'HMAC',hash:'SHA-256'},false,['sign']);
   form.set('appsecret_proof',hex(await crypto.subtle.sign('HMAC',key,enc.encode(token))));}
  if(method==='GET')url.search=form.toString();else h['content-type']='application/x-www-form-urlencoded';
  let response;try{response=await fetcher(url.toString(),{method,headers:h,...(method==='GET'?{}:{body:form}),signal:AbortSignal.timeout(15000),redirect:'error'});}catch{throw new MetaError('network');}
  let data;try{data=await response.json();}catch{throw new MetaError('provider');}
  if(!response.ok||data.error){const code=Number(data?.error?.code);throw new MetaError(code===190?'revoked':code===10||code===200?'permissions':'provider');}
  return data;
 }
 async function accounts(cfg,userToken){
  const granted=await graph(cfg,'me/permissions',userToken),permissions=(granted.data||[]).filter(x=>x.status==='granted').map(x=>x.permission);
  if(!META_PERMISSIONS.every(p=>permissions.includes(p)))throw new MetaError('permissions');
  const me=await graph(cfg,'me',userToken,'GET',{fields:'id'});if(!digits(me.id))throw new MetaError('provider');
  const rows=[];let after='';
  // Follow cursor values on a fixed Meta endpoint, never an untrusted paging.next URL.
  for(let page=0;page<10;page++){
   const data=await graph(cfg,'me/accounts',userToken,'GET',{fields:'id,name,access_token,instagram_business_account{id,username}',limit:'100',...(after?{after}:{})});
   for(const item of data.data||[]){const ig=item.instagram_business_account;
    if(digits(item.id)&&digits(ig?.id)&&typeof item.access_token==='string'&&item.access_token)rows.push({page_id:item.id,page_name:String(item.name||''),instagram_id:ig.id,username:String(ig.username||''),page_token:item.access_token});}
   if(!data.paging?.next)break;
   after=String(data.paging?.cursors?.after||'');if(!after||page===9)throw new MetaError('accounts_limit');
  }
  if(!rows.length)throw new MetaError('no_instagram');
  return {accounts:rows,meta_user_id:me.id,permissions,user_token:userToken};
 }
 async function credential(cfg,actor,social){
  const connection=await internal('credential',actor,social);
  return {...connection,tokens:await unseal(connection.encrypted_token,cfg.key,`connection:${social}`)};
 }
 async function revalidate(cfg,actor,social,c,persist=true){
  try{
   const permissions=await graph(cfg,'me/permissions',c.tokens.user_token);
   const granted=(permissions.data||[]).filter(x=>x.status==='granted').map(x=>x.permission);
   if(!META_PERMISSIONS.every(p=>granted.includes(p)))throw new MetaError('permissions');
   const page=await graph(cfg,c.page_id,c.tokens.page_token,'GET',{fields:'id,instagram_business_account{id,username}'});
   if(page.instagram_business_account?.id!==c.instagram_id)throw new MetaError('revoked');
   if(persist)await internal('connection_state',actor,social,{status:'connected'});
  }catch(e){if(persist&&['revoked','permissions'].includes(e.code))await internal('connection_state',actor,social,{status:'revoked'});throw e;}
 }
 async function executePublication(cfg,request,actor,social,job){
  if(['published','failed','uncertain','publishing','creating'].includes(job.status))return job;
  const c=await credential(cfg,actor,social);await revalidate(cfg,actor,social,c);
  const status=await graph(cfg,job.container_id,c.tokens.page_token,'GET',{fields:'status_code'});
  if(status.status_code==='PUBLISHED'){
   // A previous request may have reached Meta but not saved its response. Never publish twice.
   return internal('job_update',actor,job.id,{status:'uncertain',error_code:'review_required'});
  }
  if(['ERROR','EXPIRED'].includes(status.status_code))return internal('job_update',actor,job.id,{status:'failed',error_code:'container'});
  if(status.status_code!=='FINISHED')return job;
  const access=await userContext(request,social);if(access.can_publish!==true)throw new MetaError('permissions');
  const locked=await internal('job_update',actor,job.id,{status:'publishing'});if(locked.busy)return internal('job',actor,job.id);
  try{
   const media=await graph(cfg,`${c.instagram_id}/media_publish`,c.tokens.page_token,'POST',{creation_id:job.container_id});
   if(!digits(media.id))throw new MetaError('provider');
   const result=await internal('job_update',actor,job.id,{status:'published',media_id:media.id});
   safeLog('meta_publish_success',actor,social,job.id);return result;
  }catch(e){
   // A timeout/5xx can happen after Meta published. Mark uncertain, never retry automatically.
   const result=await internal('job_update',actor,job.id,{status:'uncertain',error_code:e.code==='revoked'?'revoked':'review_required'});
   safeLog('meta_publish_failed',actor,social,job.id);return result;
  }
 }
 async function control(request){
  let cfg;try{cfg=config();}catch{return json(request,503,{ok:false,error:'configuration_pending'});}
  if(request.method==='OPTIONS')return json(request,200,{ok:true},cfg);
  if(request.method!=='POST')return json(request,405,{ok:false,error:'method'},cfg);
  const origin=request.headers.get('origin');if(origin&&![cfg.app,ANDROID_ORIGIN].includes(origin))return json(request,403,{ok:false,error:'operation_failed'},cfg);
  let actor,body;try{actor=await authenticate(request);}catch{}
  if(!actor?.id)return json(request,401,{ok:false,error:'auth_required'},cfg);
  try{const raw=await request.text();if(raw.length>16000)throw new Error();body=JSON.parse(raw);}catch{return json(request,400,{ok:false,error:'invalid_request'},cfg);}
  try{
   if(body.action==='begin'){
    if(origin===ANDROID_ORIGIN)throw new MetaError('web_connection_required');
    if(!uuid(body.social_id)||!/^[0-9a-f]{64}$/i.test(body.proof_hash||''))throw new MetaError('invalid_request');
    await userContext(request,body.social_id);
    const state=randomSecret(),flow=await internal('begin',actor.id,body.social_id,{state_hash:await sha256(state),proof_hash:body.proof_hash});
    const url=new URL(`https://www.facebook.com/${cfg.version}/dialog/oauth`);
    url.search=new URLSearchParams({client_id:cfg.appId,config_id:cfg.configId,redirect_uri:cfg.redirect,response_type:'code',state}).toString();
    safeLog('meta_auth_started',actor.id,body.social_id,flow.id);
    return json(request,200,{ok:true,flow_id:flow.id,url:url.toString()},cfg);
   }
   if(body.action==='finish'){
    if(!uuid(body.flow_id)||!/^[0-9a-f]{64}$/i.test(body.proof||'')||!/^[0-9a-f]{64}$/i.test(body.handoff||''))throw new MetaError('state');
    const flow=await internal('finish',actor.id,body.flow_id,{proof_hash:await sha256(body.proof),handoff_hash:await sha256(body.handoff)});
    const {code}=await unseal(flow.encrypted_code,cfg.key,'oauth-code');
    const short=await graph(cfg,'oauth/access_token','','GET',{client_id:cfg.appId,client_secret:cfg.secret,redirect_uri:cfg.redirect,code});
    if(!short.access_token)throw new MetaError('provider');
    const long=await graph(cfg,'oauth/access_token','','GET',{grant_type:'fb_exchange_token',client_id:cfg.appId,client_secret:cfg.secret,fb_exchange_token:short.access_token});
    if(!long.access_token||!Number.isFinite(Number(long.expires_in))||Number(long.expires_in)<=0)throw new MetaError('provider');
    const result=await accounts(cfg,long.access_token);result.expires_at=new Date(Date.now()+Number(long.expires_in)*1000).toISOString();
    await internal('candidates',actor.id,body.flow_id,{encrypted:await seal(result,cfg.key,`flow:${body.flow_id}`),meta_user_id:result.meta_user_id});
    return json(request,200,{ok:true,social_id:flow.social_id,accounts:result.accounts.map(({page_id,page_name,instagram_id,username})=>({page_id,page_name,instagram_id,username}))},cfg);
   }
   if(body.action==='select'){
    if(!uuid(body.flow_id)||!digits(body.page_id))throw new MetaError('invalid_request');
    const flow=await internal('select',actor.id,body.flow_id);
    const pending=await unseal(flow.encrypted,cfg.key,`flow:${body.flow_id}`),selected=pending.accounts.find(a=>a.page_id===body.page_id);
    if(!selected)throw new MetaError('account');
    await userContext(request,flow.social_id);
    await revalidate(cfg,actor.id,flow.social_id,{...selected,tokens:{user_token:pending.user_token,page_token:selected.page_token}},false);
    await internal('attach',actor.id,body.flow_id,{...selected,page_token:undefined,meta_user_id:pending.meta_user_id,permissions:pending.permissions,expires_at:pending.expires_at,
     encrypted_token:await seal({page_token:selected.page_token,user_token:pending.user_token},cfg.key,`connection:${flow.social_id}`)});
    safeLog('meta_account_connected',actor.id,flow.social_id);
    return json(request,200,{ok:true},cfg);
   }
   if(!uuid(body.social_id))throw new MetaError('invalid_request');
   const access=await userContext(request,body.social_id);
   if(body.action==='status')return json(request,200,{ok:true,...await internal('status',actor.id,body.social_id)},cfg);
   if(body.action==='disconnect'){
    // Local disconnect removes only this entity's credentials. Do not revoke app-wide
    // /me/permissions here: that would break the same person's other entity connections.
    await internal('disconnect',actor.id,body.social_id);safeLog('meta_account_disconnected',actor.id,body.social_id);
    return json(request,200,{ok:true},cfg);
   }
   if(body.action==='verify'){
    const c=await credential(cfg,actor.id,body.social_id);await revalidate(cfg,actor.id,body.social_id,c);
    return json(request,200,{ok:true,...await internal('status',actor.id,body.social_id)},cfg);
   }
   if(body.action==='publish'){
    if(access.can_publish!==true||body.confirm!==true||!uuid(body.post_id))throw new MetaError('permissions');
    const c=await credential(cfg,actor.id,body.social_id);await revalidate(cfg,actor.id,body.social_id,c);
    const claim=await internal('claim',actor.id,body.social_id,{post_id:body.post_id});
    if(claim.existing)return json(request,200,{ok:true,job:claim.job},cfg);
    const job=claim.job;safeLog('meta_publish_started',actor.id,body.social_id,job.id);
    try{
     const source=claim.source;if(source.mime!=='image/jpeg'||!['kombax-public-media','club-public-media'].includes(source.bucket)||!source.path||source.path.split('/').includes('..'))throw new MetaError('image');
     const image=`${cfg.base}/storage/v1/object/public/${source.bucket}/${source.path.split('/').map(encodeURIComponent).join('/')}`;
     const caption=String(source.text||'');if([...caption].length>2200)throw new MetaError('caption');
     const container=await graph(cfg,`${c.instagram_id}/media`,c.tokens.page_token,'POST',{image_url:image,caption});
     if(!digits(container.id))throw new MetaError('provider');
     await internal('job_update',actor.id,job.id,{status:'processing',container_id:container.id});
     const result=await executePublication(cfg,request,actor.id,body.social_id,{...job,status:'processing',container_id:container.id});
     return json(request,200,{ok:true,job:result},cfg);
    }catch(e){await internal('job_update',actor.id,job.id,{status:'failed',error_code:e.code||'operation_failed'});safeLog('meta_publish_failed',actor.id,body.social_id,job.id);throw e;}
   }
   if(body.action==='publication_status'){
    if(!uuid(body.job_id))throw new MetaError('invalid_request');
    const job=await internal('job',actor.id,body.job_id);if(job.social_id!==body.social_id)throw new MetaError('permissions');
    return json(request,200,{ok:true,job:await executePublication(cfg,request,actor.id,body.social_id,job)},cfg);
   }
   throw new MetaError('invalid_request');
  }catch(e){
   const known=['no_instagram','permissions','revoked','image','caption','accounts_limit'];
   return json(request,400,{ok:false,error:known.includes(e.code)?e.code:'operation_failed'},cfg);
  }
 }
 async function callback(request){
  let cfg;try{cfg=config();}catch{return new Response('Configuración pendiente.',{status:503,headers});}
  if(request.method!=='GET')return new Response('Método no permitido.',{status:405,headers});
  const url=new URL(request.url),state=url.searchParams.get('state'),code=url.searchParams.get('code');
  const destination=new URL(`${cfg.app}/meta-instagram.html`);
  try{
   if(!/^[0-9a-f]{64}$/i.test(state||'')||!code||code.length>4096||url.searchParams.has('error'))throw new MetaError('state');
   const handoff=randomSecret(),flow=await internal('callback',null,null,{state_hash:await sha256(state),handoff_hash:await sha256(handoff),encrypted_code:await seal({code},cfg.key,'oauth-code')});
   destination.search=new URLSearchParams({flow:flow.id,handoff}).toString();safeLog('meta_auth_callback',null,null,flow.id);
  }catch{destination.search='result=failed';}
  return new Response(null,{status:303,headers:{...headers,location:destination.toString()}});
 }
 async function metaNotice(request,kind){
  let cfg;try{cfg=config();}catch{return json(request,503,{error:'configuration_pending'});}
  if(kind==='delete_data'&&request.method==='GET'){
   const code=new URL(request.url).searchParams.get('confirmation_code')||'';
   if(!/^[0-9a-f]{64}$/.test(code))return json(request,404,{error:'not_found'});
   const result=await internal('deletion_status',null,null,{confirmation_code:code});
   return json(request,result.completed?200:404,result.completed?{status:'completed'}:{error:'not_found'});
  }
  if(request.method!=='POST')return json(request,405,{error:'method'});
  try{
   const raw=await request.text();if(raw.length>16000)throw new MetaError('signed_request');
   const data=await verifySignedRequest(new URLSearchParams(raw).get('signed_request'),cfg.secret);
   const confirmation=randomSecret();await internal(kind,null,null,{meta_user_id:data.user_id,confirmation_code:confirmation});
   return json(request,200,kind==='delete_data'?{url:`${cfg.base}/functions/v1/meta-instagram-data-deletion?confirmation_code=${confirmation}`,confirmation_code:confirmation}:{success:true});
  }catch{return json(request,400,{error:'invalid_request'});}
 }
 return {control,callback,deauthorize:r=>metaNotice(r,'deauthorize'),dataDeletion:r=>metaNotice(r,'delete_data')};
}
