import { backend } from './backend.js';
import { state } from './state.js';
import {resolveIdentity} from './social-identity-resolution.js';

const STORAGE_PREFIX='kombax_active_identity';
export const identityTypeLabel={club:'Club',miembro:'Miembro',competidor:'Competidor',marca:'Marca',federacion:'Federación',profesional:'Profesional / Representante',media:'Media / Creador',espectador:'Espectador'};

function key(){return `${STORAGE_PREFIX}:${state.session?.id||'guest'}:${state.session?.club_id||'global'}:${state.session?.rol||'global'}`;}
export function resolveIdentityMedia(identity,kind='avatar'){
  const url=kind==='banner'?identity?.banner_url:identity?.avatar_url;
  const path=kind==='banner'?identity?.banner_path:identity?.avatar_path;
  return path?backend.publicUrl('kombax-public-media',path):(url||'');
}
export function identityLabel(identity){
  if(!identity)return 'Identidad KOMBAX';
  if(identity.is_personal===true){const types=identity.facet_types||[identity.perfil_tipo||identity.sujeto_tipo];return `${identity.nombre_publico||'Perfil'} · ${types.map(x=>identityTypeLabel[x]||x).join(' / ')}`;}
  if(identity.identity_label)return identity.identity_label;
  const type=identity.perfil_tipo||identity.sujeto_tipo;
  if(type==='miembro')return `${identity.nombre_publico||'Miembro'}${identity.club_nombre?` · Miembro de ${identity.club_nombre}`:' · Miembro'}`;
  if(type==='club')return `${identity.nombre_publico||identity.club_nombre||'Club'} · Club`;
  return `${identity.nombre_publico||'Perfil'} · ${identityTypeLabel[type]||type||'KOMBAX'}`;
}
export function chooseDefaultIdentity(profiles=[]){
  let storedId='';try{storedId=localStorage.getItem(key())||'';}catch{}
  return resolveIdentity(profiles,{storedId,clubId:state.session?.club_id,role:state.session?.rol});
}
export function setActiveIdentity(id){if(id)localStorage.setItem(key(),String(id));else localStorage.removeItem(key());if(typeof window!=='undefined')window.dispatchEvent(new CustomEvent('kombax-identity-changed',{detail:{id:id||null}}));}
export function getActiveIdentity(profiles=[]){return chooseDefaultIdentity(profiles);}
export function initials(name='K'){return String(name||'K').trim().split(/\s+/).filter(Boolean).slice(0,2).map(x=>x[0]?.toUpperCase()).join('')||'K';}
