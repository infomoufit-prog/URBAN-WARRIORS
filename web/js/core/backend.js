import { SupabaseClient, AuthExpiredError } from './supabase.js';
import { state } from './state.js';
import { uuid, humanError } from './utils.js';
import { selectedClubSlug, selectClubSlug } from './platform.js';
import { invalidateCache } from './query-cache.js';

const APP_SESSION='uw2_app_session';
const cfg=window.UW_CONFIG;
export const client=new SupabaseClient(cfg.supabase);
const readInflight=new Map();
const READ_CONCURRENCY=6;
const CONTRACT_TTL_MS=5*60*1000;
let activeReads=0;
const readQueue=[];
const contractCache=new Map();
const readContext=()=>`${state.session?.id||client.session?.user?.id||'anonymous'}:${state.session?.club_id||'global'}`;
const stableArgs=args=>JSON.stringify(Object.keys(args||{}).sort().reduce((out,key)=>(out[key]=args[key],out),{}));
async function withReadSlot(loader){
  if(activeReads>=READ_CONCURRENCY)await new Promise(resolve=>readQueue.push(resolve));
  activeReads++;
  try{return await loader();}
  finally{activeReads=Math.max(0,activeReads-1);readQueue.shift()?.();}
}
function dedupeRead(key,loader){
  const scoped=`${readContext()}:${key}`,existing=readInflight.get(scoped);if(existing)return existing;
  let promise;promise=Promise.resolve().then(()=>withReadSlot(loader)).finally(()=>{if(readInflight.get(scoped)===promise)readInflight.delete(scoped)});
  readInflight.set(scoped,promise);return promise;
}
function contractKey(session){return `${session?.id||'anonymous'}:${session?.club_id||'global'}:${cfg.release.backendVersion}:${cfg.release.schemaEpoch}:${cfg.release.mutationEndpoint}`}
function clearContractCache(){contractCache.clear();}

function persistSession(session){
  state.session=session||null;
  if(session)localStorage.setItem(APP_SESSION,JSON.stringify(session)); else localStorage.removeItem(APP_SESSION);
}
function readAppSession(){try{return JSON.parse(localStorage.getItem(APP_SESSION)||'null')}catch{return null}}
const isTransientNetworkError=error=>/failed to fetch|networkerror|network request failed|load failed|internet|tiempo de espera|timeout/i.test(String(error?.message||''));
function qs(value){return encodeURIComponent(String(value??''));}
async function platformContext(){
  try{const value=await client.rpc('app_kombax_platform_context_v055',{});return value&&typeof value==='object'?value:{authorized:false};}
  catch{return {authorized:false};}
}

async function globalIdentityFromAuth(authUser){
  const userId=authUser.id;
  const profiles=await client.select('perfiles',`select=*&id=eq.${qs(userId)}&limit=1`).catch(()=>[]);
  const profile=profiles?.[0]||{};
  const directProfiles=await client.rpc('app_kombax_mis_perfiles_v072',{}).catch(()=>[]);
  const applications=await client.rpc('app_kombax_mis_solicitudes_v072',{}).catch(()=>[]);
  const platform=await platformContext();
  return {
    scope:'kombax',id:userId,email:authUser.email||'',nombre:profile.nombre||authUser.user_metadata?.nombre||authUser.email||'',
    apellidos:profile.apellidos||authUser.user_metadata?.apellidos||'',telefono:profile.telefono||authUser.user_metadata?.telefono||'',
    club_id:null,club:null,rol:'kombax',roles:['kombax'],directProfiles:Array.isArray(directProfiles)?directProfiles:[],applications:Array.isArray(applications)?applications:[],platform_admin:platform.authorized===true,platform_level:platform.nivel||null
  };
}

async function identityFromAuth(authUser,requestedSlug=selectedClubSlug()){
  const userId=authUser.id;
  let memberships;
  try{
    memberships=await client.select('miembros_club',`select=club_id,rol,coordinacion,clubes(id,nombre,slug,lema,logo_url,portada_url,color_primario,color_secundario,theme_id,branding_version)&perfil_id=eq.${qs(userId)}&activo=eq.true`);
  }catch(error){
    // Compatibilidad temporal si RC9 se abre antes de aplicar la migración 021.
    memberships=await client.select('miembros_club',`select=club_id,rol,clubes(id,nombre,slug,lema,logo_url,portada_url,color_primario,color_secundario)&perfil_id=eq.${qs(userId)}&activo=eq.true`);
  }
  if(!memberships?.length)throw new Error('El usuario no pertenece a ningún club activo.');
  const priority=['direccion','secretaria','economia','comunicacion','monitor','familia','alumno'];
  memberships.sort((a,b)=>priority.indexOf(a.rol)-priority.indexOf(b.rol));
  const candidate=memberships.find(m=>m.clubes?.slug===requestedSlug)||memberships[0];
  if(candidate?.clubes?.slug)selectClubSlug(candidate.clubes.slug,candidate.clubes);
  const clubMemberships=memberships.filter(m=>m.club_id===candidate.club_id);
  const isCoordination=clubMemberships.some(m=>m.coordinacion===true);
  const chosen=isCoordination?(clubMemberships.find(m=>m.rol==='secretaria')||candidate):candidate;
  const profiles=await client.select('perfiles',`select=*&id=eq.${qs(userId)}&limit=1`).catch(()=>[]);
  const profile=profiles?.[0]||{};
  const effectiveRole=isCoordination?'coordinacion':chosen.rol;
  const effectiveRoles=isCoordination?['coordinacion']:[...new Set(clubMemberships.map(m=>m.rol))];
  const platform=await platformContext();
  return {
    id:userId,email:authUser.email||'',nombre:profile.nombre||authUser.user_metadata?.nombre||authUser.email||'',
    apellidos:profile.apellidos||authUser.user_metadata?.apellidos||'',telefono:profile.telefono||authUser.user_metadata?.telefono||'',avatar_path:profile.avatar_path||'',
    rol:effectiveRole,roles:effectiveRoles,club_id:chosen.club_id,club:chosen.clubes||null,coordinacion:isCoordination,
    memberships:memberships.map(m=>({club_id:m.club_id,rol:m.rol,coordinacion:m.coordinacion===true,club:m.clubes||null})),platform_admin:platform.authorized===true,platform_level:platform.nivel||null
  };
}

export const backend={
  async contract(session=state.session,{force=false}={}){
    if(!session?.club_id)throw new AuthExpiredError();
    const key=contractKey(session),now=Date.now(),cachedContract=contractCache.get(key);
    if(!force&&cachedContract?.value&&cachedContract.expires>now){
      state.setCapabilities(cachedContract.value.operations||[]);
      return cachedContract.value;
    }
    if(!force&&cachedContract?.promise)return cachedContract.promise;
    const promise=withReadSlot(async()=>{
      const c=await client.rpc(cfg.release.contractEndpoint,{p_club_id:session.club_id});
      const operations=new Set(Array.isArray(c?.operations)?c.operations:[]);
      const missingOperations=(cfg.release.requiredOperations||[]).filter(op=>!operations.has(op));
      if(!c?.ok||!c?.write_ready||c.backend_version!==cfg.release.backendVersion||Number(c.schema_epoch)!==Number(cfg.release.schemaEpoch)||c.mutation_endpoint!==cfg.release.mutationEndpoint||missingOperations.length){
        const missing=missingOperations.length?` Operaciones RC13 ausentes: ${missingOperations.join(', ')}.`:'';
        throw new Error(`Contrato backend incompatible: esperado ${cfg.release.backendVersion}/epoch ${cfg.release.schemaEpoch}/${cfg.release.mutationEndpoint}; recibido ${c?.backend_version||'—'}/epoch ${c?.schema_epoch||'—'}/${c?.mutation_endpoint||'—'}.${missing}`);
      }
      state.setCapabilities(c.operations||[]);
      contractCache.set(key,{value:c,expires:Date.now()+CONTRACT_TTL_MS});
      return c;
    }).catch(error=>{contractCache.delete(key);throw error;});
    contractCache.set(key,{promise,expires:0});
    return promise;
  },
  async probe(){if(!state.session?.club_id)throw new AuthExpiredError();return client.rpc(cfg.release.probeEndpoint,{p_club_id:state.session.club_id})},
  async diagnostic(){return client.rpc(cfg.release.diagnosticEndpoint,{})},
  async bootstrapMutate(operation,payload={}){
    const requestId=uuid();
    const response=await client.rpc(cfg.release.mutationEndpoint,{p_operation:operation,p_payload:payload,p_request_id:requestId});
    if(response?.ok===false&&response?.error_code)throw new Error(response.message||`Operación rechazada: ${response.error_code}`);
    if(!response?.ok||response.operation!==operation||response.request_id!==requestId)throw new Error(`Respuesta bootstrap inválida para ${operation}.`);
    state.pushTrace({kind:'mutation',stage:'response',ok:true,label:operation,requestId,response});
    return response.data;
  },
  async requestPasswordRecovery(email){
    state.clearError();
    const normalized=String(email||'').trim().toLowerCase();
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized))throw new Error('Indica un correo electrónico válido.');
    try{await client.requestPasswordRecovery(normalized);}
    catch(error){
      const message=String(error?.message||'');
      if(/rate.?limit|too many|frequent|seconds|429/i.test(message)||Number(error?.status)===429)throw new Error('Has solicitado códigos demasiado rápido. Espera un momento antes de volver a intentarlo.');
      if(/user.*not found|email.*not found|does not exist|not registered/i.test(message))return {accepted:true,email:normalized};
      throw error;
    }
    return {accepted:true,email:normalized};
  },
  async completePasswordRecovery({email,token,password}){
    state.clearError();
    const normalized=String(email||'').trim().toLowerCase();
    const code=String(token||'').replace(/\s+/g,'');
    const next=String(password||'');
    if(!/^\d{6}$/.test(code))throw new Error('El código debe tener 6 dígitos.');
    if(next.length<8)throw new Error('La nueva contraseña debe tener al menos 8 caracteres.');
    try{
      await client.verifyPasswordRecovery(normalized,code);
      await client.updatePassword(next);
    }catch(error){
      const message=String(error?.message||'');
      if(/otp|token|code|expired|invalid/i.test(message))throw new Error('El código no es válido o ha caducado. Solicita uno nuevo e inténtalo otra vez.');
      throw error;
    }finally{
      if(client.session)await client.signOut();
      persistSession(null);
      state.setCapabilities([]);
    }
    return {ok:true,email:normalized};
  },
  async changeOwnPassword({currentPassword,password}){
    state.clearError();
    const email=String(state.session?.email||'').trim().toLowerCase();
    const expectedUserId=String(state.session?.id||'');
    const current=String(currentPassword||'');
    const next=String(password||'');
    if(!client.session?.access_token||!email||!expectedUserId)throw new AuthExpiredError('Inicia sesión de nuevo antes de cambiar la contraseña.');
    if(!current)throw new Error('Introduce tu contraseña actual.');
    if(next.length<8)throw new Error('La nueva contraseña debe tener al menos 8 caracteres.');
    if(current===next)throw new Error('La nueva contraseña debe ser distinta de la actual.');
    try{
      // Reautenticación explícita: no confiamos solo en que exista una sesión abierta.
      // Un login válido con la contraseña actual genera además una sesión reciente,
      // compatible con la protección de cambio seguro de contraseña de Supabase.
      const auth=await client.signIn(email,current);
      if(String(auth?.user?.id||'')!==expectedUserId){
        await client.signOut();persistSession(null);state.setCapabilities([]);
        throw new AuthExpiredError('No se pudo verificar de forma segura la identidad de la cuenta.');
      }
      await client.updatePassword(next);
    }catch(error){
      const message=String(error?.message||'');
      if(/invalid login credentials|invalid credentials|email or password|wrong password|bad password/i.test(message))throw new Error('La contraseña actual no es correcta.');
      if(/weak password|password.*weak|password.*short|password.*characters/i.test(message))throw new Error('La nueva contraseña no cumple los requisitos de seguridad configurados para KOMBAX.');
      throw error;
    }
    await client.signOut();
    persistSession(null);
    state.setCapabilities([]);
    return {ok:true,email};
  },
  async signInGlobal(email,password){
    state.clearError();
    const auth=await client.signIn(email,password);
    const pendingTeam=localStorage.getItem('uw2_pending_team_access');
    if(pendingTeam){
      try{
        const p=JSON.parse(pendingTeam)||{};
        if(!p.email||String(p.email).toLowerCase()===String(auth.user.email||'').toLowerCase()){
          await client.rpc('app_kombax_equipo_solicitar_v060',{p_club_slug:p.club_slug,p_codigo:p.code});
          localStorage.removeItem('uw2_pending_team_access');
        }
      }catch(error){console.warn('Solicitud de equipo pendiente:',humanError(error));}
    }
    const session=await globalIdentityFromAuth(auth.user);
    persistSession(session);
    state.setCapabilities([]);
    state.pushTrace({kind:'auth',ok:true,label:'Login KOMBAX validado',detail:session.email});
    return session;
  },
  async registerGlobalAccount({email,password,nombre='',apellidos=''}){
    state.clearError();
    const auth=await client.signUp(email,password,{nombre,apellidos,tipo_cuenta:'kombax_global'});
    if(!auth?.access_token){localStorage.setItem('uw2_pending_kombax_global',JSON.stringify({email}));return {confirmationRequired:true};}
    const session=await globalIdentityFromAuth(auth.user);persistSession(session);state.setCapabilities([]);return {confirmationRequired:false,session};
  },
  async signIn(email,password){
    state.clearError();
    const auth=await client.signIn(email,password);
    const pendingRegistration=localStorage.getItem('uw2_pending_registration');
    if(pendingRegistration){
      const p=JSON.parse(pendingRegistration);
      if(!p.email||String(p.email).toLowerCase()===String(auth.user.email||'').toLowerCase()){await this.bootstrapMutate('cuenta.registrar',p.payload);localStorage.removeItem('uw2_pending_registration');}
    }
    const session=await identityFromAuth(auth.user);
    await this.contract(session);
    persistSession(session);
    const pendingLegal=localStorage.getItem('uw2_pending_legal');
    if(pendingLegal){try{const entries=JSON.parse(pendingLegal)||[];for(const item of entries)await this.mutate('legal.aceptar',{tipo:item.tipo,version:item.version||'2.0.0',aceptado:item.aceptado!==false,socio_id:item.socio_id||null,user_agent:navigator.userAgent});localStorage.removeItem('uw2_pending_legal');}catch(error){console.warn('Aceptaciones legales pendientes:',humanError(error));}}
    state.pushTrace({kind:'auth',ok:true,label:'Login validado',detail:`${session.email} · ${session.rol}`});
    return session;
  },
  async registerAccount(input){
    const clubSlug=input.club_slug||selectedClubSlug()||cfg.clubSlug;
    const auth=await client.signUp(input.email,input.password,{nombre:input.adulto_nombre,apellidos:input.adulto_apellidos,telefono:input.telefono,tipo_cuenta:input.tipo_cuenta,club_slug:clubSlug});
    const payload={club_slug:clubSlug,tipo_cuenta:input.tipo_cuenta,adulto_nombre:input.adulto_nombre,adulto_apellidos:input.adulto_apellidos,telefono:input.telefono||'',fecha_nacimiento_adulto:input.adulto_fecha_nacimiento||null,menor_nombre:input.menor_nombre||null,menor_apellidos:input.menor_apellidos||null,fecha_nacimiento_menor:input.menor_fecha_nacimiento||null,disciplina_id:input.disciplina_id||null,grupo_id:input.grupo_id||null,tarifa_id:input.tarifa_id||null,invite_code:input.invite_code||null};
    const legalEntries=input.legal_acceptances||[];
    if(!auth?.access_token){localStorage.setItem('uw2_pending_registration',JSON.stringify({email:input.email,payload}));if(legalEntries.length)localStorage.setItem('uw2_pending_legal',JSON.stringify(legalEntries));return {confirmationRequired:true};}
    await this.bootstrapMutate('cuenta.registrar',payload);
    const session=await identityFromAuth(auth.user);await this.contract(session);persistSession(session);
    for(const item of legalEntries){await this.mutate('legal.aceptar',{tipo:item.tipo,version:item.version||'2.0.0',aceptado:item.aceptado!==false,socio_id:item.socio_id||null,user_agent:navigator.userAgent});}
    return {confirmationRequired:false,session};
  },
  async requestTeamAccess(clubSlug,code,email=''){
    if(!client.session?.access_token){localStorage.setItem('uw2_pending_team_access',JSON.stringify({club_slug:clubSlug,code:String(code||'').trim(),email}));return {loginRequired:true};}
    const result=await this.globalWriteRpc('app_kombax_equipo_solicitar_v060',{p_club_slug:clubSlug,p_codigo:String(code||'').trim()});
    if(result?.ok===false)throw new Error(result.message||'Código de equipo no válido.');
    return {loginRequired:false,result};
  },
  async restore(){
    const saved=readAppSession(); if(!saved||!client.session?.access_token){persistSession(null);return null;}
    try{
      await client.fresh();
      const authUser=client.session?.user||{id:saved.id,email:saved.email,user_metadata:{nombre:saved.nombre,apellidos:saved.apellidos}};
      if(saved.scope==='kombax'){
        const session=await globalIdentityFromAuth(authUser);persistSession(session);state.setCapabilities([]);return session;
      }
      const session=await identityFromAuth(authUser);
      await this.contract(session); persistSession(session); return session;
    }catch(error){
      // Una pérdida puntual de red no invalida una sesión que sigue almacenada.
      // Conservamos el contexto local y dejamos que las lecturas reintenten al recuperar conexión.
      if(isTransientNetworkError(error)&&client.session?.access_token){console.warn('Sesión conservada sin conexión:',humanError(error));persistSession(saved);return saved;}
      const authExpired=error instanceof AuthExpiredError||error?.code==='AUTH_EXPIRED';
      // Una cuenta KOMBAX puede existir sin membresía de club. No debe expulsarse por ello.
      if(!authExpired)try{
        const authUser=client.session?.user||{id:saved.id,email:saved.email,user_metadata:{nombre:saved.nombre,apellidos:saved.apellidos}};
        if(client.session?.access_token){const session=await globalIdentityFromAuth(authUser);persistSession(session);state.setCapabilities([]);return session;}
      }catch(globalError){
        if(isTransientNetworkError(globalError)&&client.session?.access_token){console.warn('Identidad KOMBAX pendiente de red:',humanError(globalError));persistSession(saved);return saved;}
        console.warn('No se restaura la identidad KOMBAX:',humanError(globalError));
      }
      console.warn('No se restaura la sesión:',humanError(error));await client.signOut().catch(()=>{});persistSession(null);
      if(authExpired)throw new AuthExpiredError();
      return null;
    }
  },
  async switchClub(slug){
    if(!client.session?.access_token)throw new AuthExpiredError();
    const previous=state.session;
    try{
      if(previous?.club_id)invalidateCache(`${previous.club_id}:${previous.id}:`);clearContractCache();selectClubSlug(slug);state.clearTenantState();
      const authUser=client.session.user||{id:previous?.id,email:previous?.email,user_metadata:{nombre:previous?.nombre,apellidos:previous?.apellidos}};
      const session=await identityFromAuth(authUser,slug);
      if(session.club?.slug!==slug)throw new Error('No perteneces a este club o la membresía no está activa.');
      await this.contract(session);persistSession(session);return session;
    }catch(error){
      if(previous?.club?.slug)selectClubSlug(previous.club.slug);persistSession(previous);throw error;
    }
  },
  hasCapability(operation){return state.can(operation)},
  async signOut({preserveTrace=false}={}){await client.signOut();persistSession(null);clearContractCache();state.moduleCache.clear();if(!preserveTrace)state.trace=[];},
  async select(table,query='select=*'){
    return dedupeRead(`select:${table}:${query}`,async()=>{
      const t0=performance.now();
      try{const data=await client.select(table,query);state.pushTrace({kind:'read',ok:true,label:`SELECT ${table}`,ms:Math.round(performance.now()-t0),count:Array.isArray(data)?data.length:undefined});return data;}
      catch(error){state.pushTrace({kind:'read',ok:false,label:`SELECT ${table}`,ms:Math.round(performance.now()-t0),error:humanError(error)});throw error;}
    });
  },
  async globalReadRpc(name,args={}){
    if(!client.session?.access_token)throw new AuthExpiredError();
    return dedupeRead(`globalReadRpc:${name}:${stableArgs(args)}`,async()=>{
      const t0=performance.now();
      try{const data=await client.rpc(name,args);state.pushTrace({kind:'read',ok:true,label:`GLOBAL RPC ${name}`,ms:Math.round(performance.now()-t0),count:Array.isArray(data)?data.length:undefined});return data;}
      catch(error){state.pushTrace({kind:'read',ok:false,label:`GLOBAL RPC ${name}`,ms:Math.round(performance.now()-t0),error:humanError(error)});throw error;}
    });
  },
  async invokeFunction(name,payload={}){
    if(!client.session?.access_token)throw new AuthExpiredError();
    const t0=performance.now();state.pushTrace({kind:'mutation',stage:'request',ok:null,label:`EDGE ${name}`});
    try{const data=await client.invokeFunction(name,payload);state.pushTrace({kind:'mutation',stage:'response',ok:true,label:`EDGE ${name}`,ms:Math.round(performance.now()-t0)});return data;}
    catch(error){state.pushTrace({kind:'mutation',stage:'response',ok:false,label:`EDGE ${name}`,ms:Math.round(performance.now()-t0),error:humanError(error)});throw error;}
  },
  async publicRpc(name,args={}){
    const t0=performance.now();
    try{const data=await withReadSlot(()=>client.rpc(name,args));state.pushTrace({kind:'read',ok:true,label:`PUBLIC RPC ${name}`,ms:Math.round(performance.now()-t0)});return data;}
    catch(error){state.pushTrace({kind:'read',ok:false,label:`PUBLIC RPC ${name}`,ms:Math.round(performance.now()-t0),error:humanError(error)});throw error;}
  },
  async globalWriteRpc(name,args={}){
    if(!client.session?.access_token)throw new AuthExpiredError();
    const t0=performance.now();state.pushTrace({kind:'mutation',stage:'request',ok:null,label:`GLOBAL RPC ${name}`});
    try{const data=await client.rpc(name,args);state.pushTrace({kind:'mutation',stage:'response',ok:true,label:`GLOBAL RPC ${name}`,ms:Math.round(performance.now()-t0)});return data;}
    catch(error){state.pushTrace({kind:'mutation',stage:'response',ok:false,label:`GLOBAL RPC ${name}`,ms:Math.round(performance.now()-t0),error:humanError(error)});throw new Error(`No se guardó (${name}): ${humanError(error)}`);}
  },
  async readRpc(name,args={}){
    if(!state.session?.club_id)throw new AuthExpiredError();
    return dedupeRead(`readRpc:${name}:${stableArgs(args)}`,async()=>{
      const t0=performance.now();
      try{const data=await client.rpc(name,args);state.pushTrace({kind:'read',ok:true,label:`RPC ${name}`,ms:Math.round(performance.now()-t0),count:Array.isArray(data)?data.length:undefined});return data;}
      catch(error){state.pushTrace({kind:'read',ok:false,label:`RPC ${name}`,ms:Math.round(performance.now()-t0),error:humanError(error)});throw error;}
    });
  },
  async writeRpc(name,args={}){
    if(!state.session?.club_id)throw new AuthExpiredError();
    const t0=performance.now();
    state.pushTrace({kind:'mutation',stage:'request',ok:null,label:`RPC ${name}`});
    try{const data=await client.rpc(name,args);state.pushTrace({kind:'mutation',stage:'response',ok:true,label:`RPC ${name}`,ms:Math.round(performance.now()-t0)});return data;}
    catch(error){state.pushTrace({kind:'mutation',stage:'response',ok:false,label:`RPC ${name}`,ms:Math.round(performance.now()-t0),error:humanError(error)});throw new Error(`No se guardó (${name}): ${humanError(error)}`);}
  },
  async mutate(operation,payload={},options={}){
    if(!state.session?.club_id)throw new AuthExpiredError();
    if(options.contract!==false)await this.contract();
    const requestId=options.requestId||uuid();
    const body={...payload}; if(body.club_id==null)body.club_id=state.session.club_id;
    const request={p_operation:operation,p_payload:body,p_request_id:requestId};
    const t0=performance.now();
    state.pushTrace({kind:'mutation',stage:'request',ok:null,label:operation,requestId,payload:body});
    try{
      const response=await client.rpc(cfg.release.mutationEndpoint,request);
      const valid=response?.ok&&response.backend_version===cfg.release.backendVersion&&response.operation===operation&&response.request_id===requestId;
      if(!valid)throw new Error(`Respuesta de guardado no verificable para ${operation}.`);
      state.pushTrace({kind:'mutation',stage:'response',ok:true,label:operation,requestId,ms:Math.round(performance.now()-t0),response});
      return response.data;
    }catch(error){
      state.pushTrace({kind:'mutation',stage:'response',ok:false,label:operation,requestId,ms:Math.round(performance.now()-t0),error:humanError(error)});
      throw new Error(`No se guardó (${operation}): ${humanError(error)}`);
    }
  },
  async upload(bucket,path,file,upsert=false){const out=await client.upload(bucket,path,file,upsert);state.pushTrace({kind:'storage',ok:true,label:`UPLOAD ${bucket}`,detail:path});return out;},
  async remove(bucket,path){const out=await client.remove(bucket,path);state.pushTrace({kind:'storage',ok:true,label:`DELETE ${bucket}`,detail:path});return out;},
  async signedUrl(bucket,path,expires=600){return client.signedUrl(bucket,path,expires)},
  async download(bucket,path,expires=600){const blob=await client.downloadSigned(bucket,path,expires);state.pushTrace({kind:'storage',ok:true,label:`DOWNLOAD ${bucket}`,detail:path});return blob;},
  publicUrl(bucket,path){return client.publicUrl(bucket,path)}
};
