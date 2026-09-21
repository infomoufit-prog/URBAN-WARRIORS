import { humanError } from './utils.js';

const AUTH_STORAGE = 'uw2_supabase_session';
const TUS_VERSION='1.0.0';
const TUS_CHUNK_BYTES=6*1024*1024;
const TUS_RESUME_PREFIX='uw2_tus_resume:';

function storageDirectBase(projectUrl){
  try{
    const u=new URL(projectUrl);
    const match=u.hostname.match(/^([a-z0-9-]+)\.supabase\.co$/i);
    if(match)u.hostname=`${match[1]}.storage.supabase.co`;
    return u.origin;
  }catch{return String(projectUrl||'').replace(/\/$/,'');}
}
function tusBase64(value){
  const bytes=new TextEncoder().encode(String(value??''));let binary='';
  for(const byte of bytes)binary+=String.fromCharCode(byte);
  return btoa(binary);
}
function tusResumeKey(base,bucket,path,file){
  return `${TUS_RESUME_PREFIX}${base}|${bucket}|${path}|${Number(file?.size||0)}|${Number(file?.lastModified||0)}`;
}
function retryableTusStatus(status){return status===0||status===408||status===409||status===425||status===429||status>=500;}

export class AuthExpiredError extends Error {
  constructor(message='Tu sesión ha caducado. Vuelve a iniciar sesión.') { super(message); this.code='AUTH_EXPIRED'; }
}

export class SupabaseClient {
  constructor(config) {
    this.url=(config.url||'').replace(/\/$/,''); this.key=config.anonKey||'';
    this.session=this.#read(); this.refreshPromise=null;
  }
  #read(){ try{return JSON.parse(localStorage.getItem(AUTH_STORAGE)||'null')}catch{return null} }
  #save(s){
    if(!s){this.session=null;localStorage.removeItem(AUTH_STORAGE);return null;}
    const c={...s}; if(!c.expires_at&&c.expires_in)c.expires_at=Math.floor(Date.now()/1000)+Number(c.expires_in);
    this.session=c; localStorage.setItem(AUTH_STORAGE,JSON.stringify(c)); return c;
  }
  clear(){this.#save(null)}
  expiring(){return !!(this.session?.expires_at && Number(this.session.expires_at)<=Math.floor(Date.now()/1000)+75)}
  async refresh(){
    if(!this.session?.refresh_token)throw new AuthExpiredError();
    if(this.refreshPromise)return this.refreshPromise;
    this.refreshPromise=this.request('/auth/v1/token?grant_type=refresh_token',{method:'POST',useAuth:false,body:JSON.stringify({refresh_token:this.session.refresh_token})},false)
      .then(b=>{if(!b?.access_token)throw new AuthExpiredError();return this.#save(b)}).finally(()=>this.refreshPromise=null);
    return this.refreshPromise;
  }
  async fresh(){if(this.expiring())await this.refresh();return this.session}
  headers(extra={},useAuth=true,{prefer=false}={}){
    const h={apikey:this.key,'Content-Type':'application/json',...(prefer?{Prefer:'return=representation'}:{}),...extra};
    if(useAuth&&this.session?.access_token)h.Authorization=`Bearer ${this.session.access_token}`;
    return h;
  }
  async request(path, options={}, retry=true){
    const opts={...options}; const useAuth=opts.useAuth!==false; delete opts.useAuth;
    const authPath=path.startsWith('/auth/v1/token')||path.startsWith('/auth/v1/signup');
    if(useAuth&&!authPath)await this.fresh();
    const ctrl=new AbortController(); const timeout=setTimeout(()=>ctrl.abort(),Number(opts.timeoutMs||25000));
    let res;
    try{res=await fetch(`${this.url}${path}`,{...opts,signal:opts.signal||ctrl.signal,headers:this.headers(opts.headers,useAuth,{prefer:path.startsWith('/rest/v1/')})});}
    catch(e){if(e?.name==='AbortError')throw new Error('La operación ha superado el tiempo de espera y no se considera confirmada.');throw e;}
    finally{clearTimeout(timeout)}
    const text=await res.text(); let body=null; if(text){try{body=JSON.parse(text)}catch{body=text}}
    if(!res.ok){
      const message=body&&typeof body==='object'?[body.message,body.detail,body.details,body.hint,body.msg,body.error_description,body.error].filter(Boolean).join(' · '):String(body||`HTTP ${res.status}`);
      const refreshFailure=path.includes('/auth/v1/token?grant_type=refresh_token')&&/invalid\s*refresh\s*token|refresh\s*token\s*(?:not\s*found|invalid|expired)|refresh_token_not_found|refresh_token.*(?:invalid|expired)/i.test(message);
      const expired=res.status===401||/jwt.*expired|token.*expired|invalid.*jwt/i.test(message)||refreshFailure;
      if(expired&&retry&&this.session?.refresh_token&&!authPath){await this.refresh();return this.request(path,options,false)}
      if(expired){this.clear();throw new AuthExpiredError()}
      const err=new Error(message||`HTTP ${res.status}`);err.status=res.status;err.code=body?.code;err.details=body?.details;err.hint=body?.hint;throw err;
    }
    return body;
  }
  async signIn(email,password){const b=await this.request('/auth/v1/token?grant_type=password',{method:'POST',useAuth:false,body:JSON.stringify({email,password})},false);return this.#save(b)}
  async signUp(email,password,data={}){const b=await this.request('/auth/v1/signup',{method:'POST',useAuth:false,body:JSON.stringify({email,password,data})},false);if(b?.access_token)this.#save(b);return b}
  async requestPasswordRecovery(email){return this.request('/auth/v1/recover',{method:'POST',useAuth:false,body:JSON.stringify({email})},false)}
  async requestEmailOtp(email){return this.request('/auth/v1/otp',{method:'POST',useAuth:false,body:JSON.stringify({email,create_user:false})},false)}
  async verifyEmailOtp(email,token){const b=await this.request('/auth/v1/verify',{method:'POST',useAuth:false,body:JSON.stringify({type:'email',email,token})},false);if(!b?.access_token)throw new Error('No se pudo validar el código de acceso.');return this.#save(b)}
  async verifyPasswordRecovery(email,token){const b=await this.request('/auth/v1/verify',{method:'POST',useAuth:false,body:JSON.stringify({type:'recovery',email,token})},false);if(!b?.access_token)throw new Error('No se pudo validar el código de recuperación.');return this.#save(b)}
  async updatePassword(password){if(!this.session?.access_token)throw new AuthExpiredError('El código de recuperación debe validarse antes de cambiar la contraseña.');return this.request('/auth/v1/user',{method:'PUT',body:JSON.stringify({password})},false)}
  async updateUserMetadata(data={}){if(!this.session?.access_token)throw new AuthExpiredError();const user=await this.request('/auth/v1/user',{method:'PUT',body:JSON.stringify({data})},false);if(this.session){this.#save({...this.session,user:{...(this.session.user||{}),...(user||{}),user_metadata:{...(this.session.user?.user_metadata||{}),...(user?.user_metadata||data)}}});}return user;}
  async signOut(){try{if(this.session)await this.request('/auth/v1/logout',{method:'POST'},false)}catch(e){console.warn('Logout remoto:',humanError(e))}finally{this.clear()}}
  async select(table,query='select=*',useAuth=true){return this.request(`/rest/v1/${table}?${query}`,{method:'GET',useAuth})}
  async rpc(name,payload={}){return this.request(`/rest/v1/rpc/${name}`,{method:'POST',body:JSON.stringify(payload)})}
  async invokeFunction(name,payload={},timeoutMs=30000){return this.request(`/functions/v1/${encodeURIComponent(name)}`,{method:'POST',body:JSON.stringify(payload),timeoutMs})}
  async downloadFunction(name,payload={},timeoutMs=30000,retry=true){
    await this.fresh();if(!this.session?.access_token)throw new AuthExpiredError();
    const ctrl=new AbortController(),timer=setTimeout(()=>ctrl.abort(),Number(timeoutMs||30000));let res;
    try{res=await fetch(`${this.url}/functions/v1/${encodeURIComponent(name)}`,{method:'POST',headers:{apikey:this.key,Authorization:`Bearer ${this.session.access_token}`,'Content-Type':'application/json'},body:JSON.stringify(payload),signal:ctrl.signal});}
    catch(error){if(error?.name==='AbortError')throw new Error('La descarga ha superado el tiempo de espera.');throw error;}
    finally{clearTimeout(timer);}
    if(res.status===401&&retry&&this.session?.refresh_token){await this.refresh();return this.downloadFunction(name,payload,timeoutMs,false);}
    if(!res.ok){const text=await res.text().catch(()=>'');let body=null;try{body=text?JSON.parse(text):null}catch{body=text}const message=body&&typeof body==='object'?[body.message,body.detail,body.error].filter(Boolean).join(' · '):String(body||`HTTP ${res.status}`);if(res.status===401){this.clear();throw new AuthExpiredError();}const err=new Error(message||`HTTP ${res.status}`);err.status=res.status;throw err;}
    return res.blob();
  }
  async upload(bucket,path,file,upsert=false){
    await this.fresh(); if(!this.session?.access_token)throw new AuthExpiredError();
    const url=`${this.url}/storage/v1/object/${encodeURIComponent(bucket)}/${path.split('/').map(encodeURIComponent).join('/')}`;
    const ctrl=new AbortController();const timeoutMs=Math.min(120000,Math.max(30000,30000+Math.ceil(Number(file.size||0)/262144)*1000));const timeout=setTimeout(()=>ctrl.abort(),timeoutMs);let res;
    try{res=await fetch(url,{method:'POST',headers:{apikey:this.key,Authorization:`Bearer ${this.session.access_token}`,'Content-Type':file.type||'application/octet-stream','x-upsert':upsert?'true':'false'},body:file,signal:ctrl.signal});}
    catch(error){if(error?.name==='AbortError')throw new Error('La subida ha superado el tiempo de espera y no se considera confirmada.');throw new Error('No se pudo conectar con Storage para subir el archivo. Comprueba la conexión e inténtalo de nuevo.');}
    finally{clearTimeout(timeout);}
    const body=await res.json().catch(()=>({})); if(!res.ok)throw new Error(body.message||body.error||`Storage HTTP ${res.status}`);return body;
  }
  async uploadResumable(bucket,path,file,{upsert=false,onProgress=null}={}){
    await this.fresh();if(!this.session?.access_token)throw new AuthExpiredError();
    if(!file?.size)throw new Error('El archivo está vacío.');
    const directBase=storageDirectBase(this.url);
    const endpoint=`${directBase}/storage/v1/upload/resumable`;
    const resumeKey=tusResumeKey(directBase,bucket,path,file);
    const authHeaders=()=>({apikey:this.key,Authorization:`Bearer ${this.session?.access_token||''}`,'Tus-Resumable':TUS_VERSION});
    const timedFetch=async(url,options={},timeoutMs=180000)=>{
      const ctrl=new AbortController();const timer=setTimeout(()=>ctrl.abort(),timeoutMs);
      try{return await fetch(url,{...options,signal:options.signal||ctrl.signal});}
      finally{clearTimeout(timer);}
    };
    const readOffset=async(uploadUrl)=>{
      try{
        await this.fresh();
        const res=await timedFetch(uploadUrl,{method:'HEAD',headers:authHeaders()},45000);
        if(res.status===404||res.status===410)return null;
        if(res.status===401&&this.session?.refresh_token){await this.refresh();return readOffset(uploadUrl);}
        if(!res.ok)throw Object.assign(new Error(`TUS HEAD HTTP ${res.status}`),{status:res.status});
        const offset=Number(res.headers.get('Upload-Offset')||0);return Number.isFinite(offset)?Math.max(0,offset):0;
      }catch(error){if(error?.name==='AbortError')return null;throw error;}
    };
    let uploadUrl='';let offset=0;
    try{uploadUrl=localStorage.getItem(resumeKey)||'';}catch{}
    if(uploadUrl){
      const previous=await readOffset(uploadUrl).catch(()=>null);
      if(previous==null){try{localStorage.removeItem(resumeKey);}catch{}uploadUrl='';}
      else offset=Math.min(Number(file.size),previous);
    }
    if(!uploadUrl){
      await this.fresh();
      const metadata=[['bucketName',bucket],['objectName',path],['contentType',file.type||'application/octet-stream'],['cacheControl','3600']].map(([k,v])=>`${k} ${tusBase64(v)}`).join(',');
      const res=await timedFetch(endpoint,{method:'POST',headers:{...authHeaders(),'Upload-Length':String(file.size),'Upload-Metadata':metadata,'x-upsert':upsert?'true':'false'}},60000);
      if(res.status===401&&this.session?.refresh_token){await this.refresh();return this.uploadResumable(bucket,path,file,{upsert,onProgress});}
      if(!res.ok){const text=await res.text().catch(()=>'');throw new Error(text||`TUS CREATE HTTP ${res.status}`);}
      const location=res.headers.get('Location');if(!location)throw new Error('Storage no devolvió una URL de subida reanudable.');
      uploadUrl=new URL(location,endpoint).href;offset=Number(res.headers.get('Upload-Offset')||0)||0;
      try{localStorage.setItem(resumeKey,uploadUrl);}catch{}
    }
    onProgress?.(offset,Number(file.size));
    const delays=[0,3000,5000,10000,20000];
    while(offset<file.size){
      const end=Math.min(file.size,offset+TUS_CHUNK_BYTES);const chunk=file.slice(offset,end);let completed=false;let lastError=null;
      for(const delay of delays){
        if(delay)await new Promise(resolve=>setTimeout(resolve,delay));
        try{
          await this.fresh();
          const res=await timedFetch(uploadUrl,{method:'PATCH',headers:{...authHeaders(),'Upload-Offset':String(offset),'Content-Type':'application/offset+octet-stream'},body:chunk},180000);
          if(res.status===401&&this.session?.refresh_token){await this.refresh();throw Object.assign(new Error('TUS_AUTH_RETRY'),{status:401});}
          if(!res.ok){const text=await res.text().catch(()=>'');throw Object.assign(new Error(text||`TUS PATCH HTTP ${res.status}`),{status:res.status});}
          const next=Number(res.headers.get('Upload-Offset')||end);offset=Number.isFinite(next)?Math.max(offset,next):end;
          onProgress?.(Math.min(offset,Number(file.size)),Number(file.size));completed=true;break;
        }catch(error){
          lastError=error;const status=Number(error?.status||0);if(!retryableTusStatus(status)&&error?.name!=='AbortError')break;
          const remote=await readOffset(uploadUrl).catch(()=>null);if(remote!=null){offset=Math.min(Number(file.size),remote);if(offset>=end){completed=true;onProgress?.(offset,Number(file.size));break;}}
        }
      }
      if(!completed)throw new Error(lastError?.name==='AbortError'?'La conexión se interrumpió durante la subida. El progreso queda preparado para reanudarse.':(lastError?.message||'No se pudo completar la subida reanudable.'));
    }
    try{localStorage.removeItem(resumeKey);}catch{}
    onProgress?.(Number(file.size),Number(file.size));
    return {Key:path,resumable:true};
  }
  async remove(bucket,path){await this.fresh();if(!this.session?.access_token)throw new AuthExpiredError();return this.request(`/storage/v1/object/${encodeURIComponent(bucket)}/${path.split('/').map(encodeURIComponent).join('/')}`,{method:'DELETE'});}
  async signedUrl(bucket,path,expiresIn=600){const b=await this.request(`/storage/v1/object/sign/${encodeURIComponent(bucket)}/${path.split('/').map(encodeURIComponent).join('/')}`,{method:'POST',body:JSON.stringify({expiresIn})});const u=b.signedURL||b.signedUrl||b.url;return u?.startsWith('http')?u:`${this.url}/storage/v1${u}`}
  async downloadSigned(bucket,path,expiresIn=600){const url=await this.signedUrl(bucket,path,expiresIn);const res=await fetch(url);if(!res.ok)throw new Error(`No se pudo descargar el archivo (HTTP ${res.status})`);return res.blob()}
  async localAssetFile(path,{name='',type=''}={}){const res=await fetch(path,{cache:'no-store'});if(!res.ok)throw new Error(`No se pudo leer el asset local (HTTP ${res.status}).`);const blob=await res.blob();const fileName=name||String(path||'asset').split('/').pop()||'asset';return new File([blob],fileName,{type:type||blob.type||'application/octet-stream'});}
  publicUrl(bucket,path){return `${this.url}/storage/v1/object/public/${encodeURIComponent(bucket)}/${path.split('/').map(encodeURIComponent).join('/')}`}
}
