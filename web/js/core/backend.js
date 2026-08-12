import { SupabaseClient, AuthExpiredError } from './supabase.js';
import { state } from './state.js';
import { uuid, humanError } from './utils.js';

const APP_SESSION='uw2_app_session';
const cfg=window.UW_CONFIG;
export const client=new SupabaseClient(cfg.supabase);

function persistSession(session){
  state.session=session||null;
  if(session)localStorage.setItem(APP_SESSION,JSON.stringify(session)); else localStorage.removeItem(APP_SESSION);
}
function readAppSession(){try{return JSON.parse(localStorage.getItem(APP_SESSION)||'null')}catch{return null}}
function qs(value){return encodeURIComponent(String(value??''));}

async function identityFromAuth(authUser){
  const userId=authUser.id;
  let memberships;
  try{
    memberships=await client.select('miembros_club',`select=club_id,rol,coordinacion,clubes(id,nombre,slug,lema,logo_url,portada_url,color_primario,color_secundario)&perfil_id=eq.${qs(userId)}&activo=eq.true`);
  }catch(error){
    // Compatibilidad temporal si RC9 se abre antes de aplicar la migración 021.
    memberships=await client.select('miembros_club',`select=club_id,rol,clubes(id,nombre,slug,lema,logo_url,portada_url,color_primario,color_secundario)&perfil_id=eq.${qs(userId)}&activo=eq.true`);
  }
  if(!memberships?.length)throw new Error('El usuario no pertenece a ningún club activo.');
  const priority=['direccion','secretaria','economia','comunicacion','monitor','familia','alumno'];
  memberships.sort((a,b)=>priority.indexOf(a.rol)-priority.indexOf(b.rol));
  const candidate=memberships.find(m=>m.clubes?.slug===cfg.clubSlug)||memberships[0];
  const clubMemberships=memberships.filter(m=>m.club_id===candidate.club_id);
  const isCoordination=clubMemberships.some(m=>m.coordinacion===true);
  const chosen=isCoordination?(clubMemberships.find(m=>m.rol==='secretaria')||candidate):candidate;
  const profiles=await client.select('perfiles',`select=*&id=eq.${qs(userId)}&limit=1`).catch(()=>[]);
  const profile=profiles?.[0]||{};
  const effectiveRole=isCoordination?'coordinacion':chosen.rol;
  const effectiveRoles=isCoordination?['coordinacion']:[...new Set(clubMemberships.map(m=>m.rol))];
  return {
    id:userId,email:authUser.email||'',nombre:profile.nombre||authUser.user_metadata?.nombre||authUser.email||'',
    apellidos:profile.apellidos||authUser.user_metadata?.apellidos||'',telefono:profile.telefono||authUser.user_metadata?.telefono||'',avatar_path:profile.avatar_path||'',
    rol:effectiveRole,roles:effectiveRoles,club_id:chosen.club_id,club:chosen.clubes||null,coordinacion:isCoordination
  };
}

export const backend={
  async contract(session=state.session){
    if(!session?.club_id)throw new AuthExpiredError();
    const c=await client.rpc(cfg.release.contractEndpoint,{p_club_id:session.club_id});
    if(!c?.ok||!c?.write_ready||c.backend_version!==cfg.release.backendVersion||Number(c.schema_epoch)!==Number(cfg.release.schemaEpoch)||c.mutation_endpoint!==cfg.release.mutationEndpoint){
      throw new Error(`Contrato backend incompatible: esperado ${cfg.release.backendVersion}/epoch ${cfg.release.schemaEpoch}/${cfg.release.mutationEndpoint}; recibido ${c?.backend_version||'—'}/epoch ${c?.schema_epoch||'—'}/${c?.mutation_endpoint||'—'}.`);
    }
    return c;
  },
  async probe(){if(!state.session?.club_id)throw new AuthExpiredError();return client.rpc(cfg.release.probeEndpoint,{p_club_id:state.session.club_id})},
  async diagnostic(){return client.rpc(cfg.release.diagnosticEndpoint,{})},
  async bootstrapMutate(operation,payload={}){
    const requestId=uuid();
    const response=await client.rpc(cfg.release.mutationEndpoint,{p_operation:operation,p_payload:payload,p_request_id:requestId});
    if(!response?.ok||response.operation!==operation||response.request_id!==requestId)throw new Error(`Respuesta bootstrap inválida para ${operation}.`);
    state.pushTrace({kind:'mutation',stage:'response',ok:true,label:operation,requestId,response});
    return response.data;
  },
  async signIn(email,password){
    state.clearError();
    const auth=await client.signIn(email,password);
    const pendingRegistration=localStorage.getItem('uw2_pending_registration');
    if(pendingRegistration){
      const p=JSON.parse(pendingRegistration);
      if(!p.email||String(p.email).toLowerCase()===String(auth.user.email||'').toLowerCase()){await this.bootstrapMutate('cuenta.registrar',p.payload);localStorage.removeItem('uw2_pending_registration');}
    }
    const pendingInvitation=localStorage.getItem('uw2_pending_invitation');
    if(pendingInvitation){
      const p=JSON.parse(pendingInvitation);
      if(!p.email||String(p.email).toLowerCase()===String(auth.user.email||'').toLowerCase()){await this.bootstrapMutate('invitacion.aceptar',{token:p.token});localStorage.removeItem('uw2_pending_invitation');}
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
    const auth=await client.signUp(input.email,input.password,{nombre:input.adulto_nombre,apellidos:input.adulto_apellidos,telefono:input.telefono,tipo_cuenta:input.tipo_cuenta,club_slug:cfg.clubSlug});
    const payload={club_slug:cfg.clubSlug,tipo_cuenta:input.tipo_cuenta,adulto_nombre:input.adulto_nombre,adulto_apellidos:input.adulto_apellidos,telefono:input.telefono||'',fecha_nacimiento_adulto:input.adulto_fecha_nacimiento||null,menor_nombre:input.menor_nombre||null,menor_apellidos:input.menor_apellidos||null,fecha_nacimiento_menor:input.menor_fecha_nacimiento||null,disciplina_id:input.disciplina_id||null,grupo_id:input.grupo_id||null,tarifa_id:input.tarifa_id||null};
    const legalEntries=input.legal_acceptances||[];
    if(!auth?.access_token){localStorage.setItem('uw2_pending_registration',JSON.stringify({email:input.email,payload}));if(legalEntries.length)localStorage.setItem('uw2_pending_legal',JSON.stringify(legalEntries));return {confirmationRequired:true};}
    await this.bootstrapMutate('cuenta.registrar',payload);
    const session=await identityFromAuth(auth.user);await this.contract(session);persistSession(session);
    for(const item of legalEntries){await this.mutate('legal.aceptar',{tipo:item.tipo,version:item.version||'2.0.0',aceptado:item.aceptado!==false,socio_id:item.socio_id||null,user_agent:navigator.userAgent});}
    return {confirmationRequired:false,session};
  },
  async acceptInvitation(token,email=''){
    if(!client.session?.access_token){localStorage.setItem('uw2_pending_invitation',JSON.stringify({token,email}));return {loginRequired:true};}
    const result=await this.bootstrapMutate('invitacion.aceptar',{token});return {loginRequired:false,result};
  },
  async restore(){
    const saved=readAppSession(); if(!saved||!client.session?.access_token){persistSession(null);return null;}
    try{
      await client.fresh();
      const authUser=client.session?.user||{id:saved.id,email:saved.email,user_metadata:{nombre:saved.nombre,apellidos:saved.apellidos}};
      const session=await identityFromAuth(authUser);
      await this.contract(session); persistSession(session); return session;
    }catch(error){
      console.warn('No se restaura la sesión:',humanError(error)); await client.signOut().catch(()=>{});persistSession(null);return null;
    }
  },
  async signOut({preserveTrace=false}={}){await client.signOut();persistSession(null);state.moduleCache.clear();if(!preserveTrace)state.trace=[];},
  async select(table,query='select=*'){
    const t0=performance.now();
    try{const data=await client.select(table,query);state.pushTrace({kind:'read',ok:true,label:`SELECT ${table}`,ms:Math.round(performance.now()-t0),count:Array.isArray(data)?data.length:undefined});return data;}
    catch(error){state.pushTrace({kind:'read',ok:false,label:`SELECT ${table}`,ms:Math.round(performance.now()-t0),error:humanError(error)});throw error;}
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
