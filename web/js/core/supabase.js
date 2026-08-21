import { humanError } from './utils.js';

const AUTH_STORAGE = 'uw2_supabase_session';

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
  headers(extra={},useAuth=true){
    const h={apikey:this.key,'Content-Type':'application/json',Prefer:'return=representation',...extra};
    if(useAuth&&this.session?.access_token)h.Authorization=`Bearer ${this.session.access_token}`;
    return h;
  }
  async request(path, options={}, retry=true){
    const opts={...options}; const useAuth=opts.useAuth!==false; delete opts.useAuth;
    const authPath=path.startsWith('/auth/v1/token')||path.startsWith('/auth/v1/signup');
    if(useAuth&&!authPath)await this.fresh();
    const ctrl=new AbortController(); const timeout=setTimeout(()=>ctrl.abort(),Number(opts.timeoutMs||25000));
    let res;
    try{res=await fetch(`${this.url}${path}`,{...opts,signal:opts.signal||ctrl.signal,headers:this.headers(opts.headers,useAuth)});}
    catch(e){if(e?.name==='AbortError')throw new Error('La operación ha superado el tiempo de espera y no se considera confirmada.');throw e;}
    finally{clearTimeout(timeout)}
    const text=await res.text(); let body=null; if(text){try{body=JSON.parse(text)}catch{body=text}}
    if(!res.ok){
      const message=body&&typeof body==='object'?[body.message,body.details,body.hint,body.msg,body.error_description,body.error].filter(Boolean).join(' · '):String(body||`HTTP ${res.status}`);
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
  async signOut(){try{if(this.session)await this.request('/auth/v1/logout',{method:'POST'},false)}catch(e){console.warn('Logout remoto:',humanError(e))}finally{this.clear()}}
  async select(table,query='select=*',useAuth=true){return this.request(`/rest/v1/${table}?${query}`,{method:'GET',useAuth})}
  async rpc(name,payload={}){return this.request(`/rest/v1/rpc/${name}`,{method:'POST',body:JSON.stringify(payload)})}
  async invokeFunction(name,payload={}){return this.request(`/functions/v1/${encodeURIComponent(name)}`,{method:'POST',body:JSON.stringify(payload),timeoutMs:30000})}
  async upload(bucket,path,file,upsert=false){
    await this.fresh(); if(!this.session?.access_token)throw new AuthExpiredError();
    const url=`${this.url}/storage/v1/object/${encodeURIComponent(bucket)}/${path.split('/').map(encodeURIComponent).join('/')}`;
    const ctrl=new AbortController();const timeoutMs=Math.min(120000,Math.max(30000,30000+Math.ceil(Number(file.size||0)/262144)*1000));const timeout=setTimeout(()=>ctrl.abort(),timeoutMs);let res;
    try{res=await fetch(url,{method:'POST',headers:{apikey:this.key,Authorization:`Bearer ${this.session.access_token}`,'Content-Type':file.type||'application/octet-stream','x-upsert':upsert?'true':'false'},body:file,signal:ctrl.signal});}
    catch(error){if(error?.name==='AbortError')throw new Error('La subida ha superado el tiempo de espera y no se considera confirmada.');throw new Error('No se pudo conectar con Storage para subir el archivo. Comprueba la conexión e inténtalo de nuevo.');}
    finally{clearTimeout(timeout);}
    const body=await res.json().catch(()=>({})); if(!res.ok)throw new Error(body.message||body.error||`Storage HTTP ${res.status}`);return body;
  }
  async remove(bucket,path){await this.fresh();if(!this.session?.access_token)throw new AuthExpiredError();return this.request(`/storage/v1/object/${encodeURIComponent(bucket)}/${path.split('/').map(encodeURIComponent).join('/')}`,{method:'DELETE'});}
  async signedUrl(bucket,path,expiresIn=600){const b=await this.request(`/storage/v1/object/sign/${encodeURIComponent(bucket)}/${path.split('/').map(encodeURIComponent).join('/')}`,{method:'POST',body:JSON.stringify({expiresIn})});const u=b.signedURL||b.signedUrl||b.url;return u?.startsWith('http')?u:`${this.url}/storage/v1${u}`}
  async downloadSigned(bucket,path,expiresIn=600){const url=await this.signedUrl(bucket,path,expiresIn);const res=await fetch(url);if(!res.ok)throw new Error(`No se pudo descargar el archivo (HTTP ${res.status})`);return res.blob()}
  publicUrl(bucket,path){return `${this.url}/storage/v1/object/public/${encodeURIComponent(bucket)}/${path.split('/').map(encodeURIComponent).join('/')}`}
}
