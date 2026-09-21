import { backend } from './backend.js';

const cache=new Map();
const inflight=new Map();
const key=id=>String(id||'');

export async function resolveProfileCapabilities(profileId,{refresh=false}={}){
  const id=key(profileId);if(!id)return [];
  if(!refresh&&cache.has(id))return cache.get(id);
  if(!refresh&&inflight.has(id))return inflight.get(id);
  const request=backend.globalReadRpc('app_kombax_profile_capabilities_v196',{p_perfil_directo_id:id})
    .then(rows=>{const list=Array.isArray(rows)?rows:[];cache.set(id,list);inflight.delete(id);return list;})
    .catch(error=>{inflight.delete(id);throw error;});
  inflight.set(id,request);return request;
}

export async function profileHasCapability(profileId,capability,options){
  return (await resolveProfileCapabilities(profileId,options)).some(x=>(x.capacidad_clave||x.clave)===capability);
}

export function clearProfileCapabilityCache(profileId=null){
  if(profileId){cache.delete(key(profileId));inflight.delete(key(profileId));return;}
  cache.clear();inflight.clear();
}

if(typeof window!=='undefined')window.addEventListener('kombax-identity-changed',()=>clearProfileCapabilityCache());
