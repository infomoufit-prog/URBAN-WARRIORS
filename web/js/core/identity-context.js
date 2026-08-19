import { backend } from './backend.js';
import { state } from './state.js';

const STORAGE_PREFIX='kombax_active_identity';
export const identityTypeLabel={club:'Club',miembro:'Miembro',competidor:'Competidor',marca:'Marca',federacion:'Federación',profesional:'Profesional / Representante',espectador:'Espectador'};

function key(){return `${STORAGE_PREFIX}:${state.session?.id||'guest'}:${state.session?.club_id||'global'}`;}
export function resolveIdentityMedia(identity,kind='avatar'){
  const url=kind==='banner'?identity?.banner_url:identity?.avatar_url;
  const path=kind==='banner'?identity?.banner_path:identity?.avatar_path;
  return path?backend.publicUrl('kombax-public-media',path):(url||'');
}
export function identityLabel(identity){
  if(!identity)return 'Identidad KOMBAX';
  if(identity.identity_label)return identity.identity_label;
  const type=identity.perfil_tipo||identity.sujeto_tipo;
  if(type==='miembro')return `${identity.nombre_publico||'Miembro'}${identity.club_nombre?` · Miembro de ${identity.club_nombre}`:' · Miembro'}`;
  if(type==='club')return `${identity.nombre_publico||identity.club_nombre||'Club'} · Club`;
  return `${identity.nombre_publico||'Perfil'} · ${identityTypeLabel[type]||type||'KOMBAX'}`;
}
export function chooseDefaultIdentity(profiles=[]){
  if(!profiles.length)return null;
  const stored=localStorage.getItem(key());
  const saved=profiles.find(p=>String(p.id)===String(stored));
  if(saved)return saved;
  if(state.session?.club_id&&['direccion','coordinacion'].includes(state.session?.rol)){
    const club=profiles.find(p=>p.sujeto_tipo==='club'&&String(p.club_id)===String(state.session.club_id));
    if(club)return club;
  }
  return profiles[0];
}
export function setActiveIdentity(id){if(id)localStorage.setItem(key(),String(id));else localStorage.removeItem(key());}
export function getActiveIdentity(profiles=[]){return chooseDefaultIdentity(profiles);}
export function initials(name='K'){return String(name||'K').trim().split(/\s+/).filter(Boolean).slice(0,2).map(x=>x[0]?.toUpperCase()).join('')||'K';}
