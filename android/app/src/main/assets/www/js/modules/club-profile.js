import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { esc } from '../core/utils.js';
import { openForm, openDetail, toast, setError } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { openSportsProfile } from './sports-profile.js';

const list=(x)=>Array.isArray(x)?x:[];
function safeHttpsUrl(value){try{const u=new URL(String(value||''));return u.protocol==='https:'?u.href.replaceAll("'",'%27').replaceAll('"','%22'):'';}catch{return '';}}
const link=(url,label)=>{const safe=safeHttpsUrl(url);return safe?`<a class="btn btn-ghost btn-sm" href="${esc(safe)}" target="_blank" rel="noopener noreferrer">${esc(label)}</a>`:'';};

function body(p){
  const disciplines=list(p.disciplinas).map(d=>`<span class="badge badge-neutral">${esc(d.nombre||d)}</span>`).join('');
  const location=[p.ciudad,p.provincia,p.pais].filter(Boolean).join(' · ');
  const links=[link(p.web_publica,'Web'),link(p.instagram,'Instagram'),link(p.tiktok,'TikTok'),link(p.youtube,'YouTube')].filter(Boolean).join('');
  const cover=safeHttpsUrl(p.portada_url),logo=safeHttpsUrl(p.logo_url);
  return `<article class="club-public-profile">
    <div class="club-public-cover ${cover?'has-image':''}" ${cover?`style="background-image:linear-gradient(180deg,rgba(5,6,8,.15),rgba(5,6,8,.92)),url('${esc(cover)}')"`:''}>
      <div class="club-public-logo">${logo?`<img src="${esc(logo)}" alt="Logo de ${esc(p.nombre_publico)}">`:`<span>${icon('shield',{size:52})}</span>`}</div>
      <div><span class="page-kicker">PERFIL DEL CLUB</span><h2>${esc(p.nombre_publico)}</h2>${p.alias?`<strong>${esc(p.alias)}</strong>`:''}${p.lema?`<p class="club-public-motto">${esc(p.lema)}</p>`:''}${location?`<p>${icon('mapPin',{size:14})} ${esc(location)}</p>`:''}</div>
    </div>
    ${p.descripcion?`<section class="club-public-section"><h3>Sobre el club</h3><p>${esc(p.descripcion)}</p></section>`:''}
    ${disciplines?`<section class="club-public-section"><h3>Disciplinas</h3><div class="detail-badges">${disciplines}</div></section>`:''}
    ${p.historia?`<section class="club-public-section"><h3>Trayectoria</h3><p>${esc(p.historia)}</p></section>`:''}
    ${p.logros?`<section class="club-public-section"><h3>Logros destacados</h3><p>${esc(p.logros)}</p></section>`:''}
    ${(p.contacto_publico||links)?`<section class="club-public-section"><h3>Información pública</h3>${p.contacto_publico?`<p>${esc(p.contacto_publico)}</p>`:''}${links?`<div class="row-actions">${links}</div>`:''}</section>`:''}
    ${p.visible===false?'<div class="alert alert-warning"><strong>Perfil no publicado</strong><span>Solo lo ven los responsables autorizados mientras esté desactivado.</span></div>':''}
  </article>`;
}

export async function openClubPublicProfile(clubId=state.session?.club_id){
  try{
    const p=await repos.clubPublic.one(clubId);
    if(!p){toast('El perfil público del club todavía no está disponible.','error');return null;}
    const actions=p.editable?`<button class="btn btn-primary" id="club-public-edit">${icon('edit',{size:15})} Editar perfil público</button>`:'';
    const modal=openDetail({title:p.nombre_publico,subtitle:'Perfil público del club · separado de los datos administrativos',body:body(p),actions,width:'900px',className:'club-public-modal'});
    modal.wrap.querySelector('#club-public-edit')?.addEventListener('click',()=>editClubPublicProfile(p));
    return p;
  }catch(error){setError(error);return null;}
}

export function editClubPublicProfile(profile){
  const p=profile||{};
  openForm({title:'Editar perfil público del club',subtitle:'Publica únicamente información que el club quiera compartir. El email, teléfono y dirección administrativos no se copian automáticamente.',width:'920px',initial:p,fields:[
    {name:'nombre_publico',label:'Nombre público',required:true,maxLength:160},{name:'alias',label:'Nombre corto / alias',maxLength:80},{name:'lema',label:'Lema público',maxLength:180},{name:'slug',label:'Identificador público',required:true,maxLength:120,help:'Minúsculas, números y guiones. No depende del nombre visible.'},
    {name:'descripcion',label:'Presentación',type:'textarea',rows:4,full:true,maxLength:1200},{name:'historia',label:'Trayectoria / historia',type:'textarea',rows:5,full:true,maxLength:4000},
    {name:'ciudad',label:'Ciudad',maxLength:120},{name:'provincia',label:'Provincia / región',maxLength:120},{name:'pais',label:'País',maxLength:120,value:p.pais||'España'},
    {name:'logros',label:'Logros destacados',type:'textarea',rows:4,full:true,maxLength:2500},{name:'contacto_publico',label:'Contacto público voluntario',full:true,maxLength:240,help:'No se rellena desde los datos administrativos.'},
    {name:'web_publica',label:'Web pública (URL HTTPS)'},{name:'instagram',label:'Instagram (URL HTTPS)'},{name:'tiktok',label:'TikTok (URL HTTPS)'},{name:'youtube',label:'YouTube (URL HTTPS)'},
    {name:'logo',label:'Logo del perfil público',type:'file',accept:'image/jpeg,image/png,image/webp,image/gif',help:'Opcional · máximo 5 MB.'},{name:'quitar_logo',label:'Quitar logo público actual',type:'checkbox',value:false},
    {name:'portada',label:'Portada del perfil público',type:'file',accept:'image/jpeg,image/png,image/webp,image/gif',help:'Opcional · máximo 5 MB.'},{name:'quitar_portada',label:'Quitar portada pública actual',type:'checkbox',value:false},
    {name:'visible',label:'Mostrar este perfil a usuarios autenticados que puedan acceder a perfiles públicos',type:'checkbox',full:true,value:p.visible!==false}
  ],submitText:'Guardar perfil público',onSubmit:async v=>{
    const oldLogo=p.logo_url||'',oldCover=p.portada_url||'';let logo=v.quitar_logo?'':oldLogo,cover=v.quitar_portada?'':oldCover;let uploadedLogo='',uploadedCover='';
    try{
      if(v.logo){uploadedLogo=await repos.clubPublic.uploadImage('logo',v.logo);logo=uploadedLogo;}
      if(v.portada){uploadedCover=await repos.clubPublic.uploadImage('cover',v.portada);cover=uploadedCover;}
      await repos.clubPublic.save({...v,logo_url:logo,portada_url:cover});
      if(oldLogo&&oldLogo!==logo)await repos.clubPublic.removeImage(oldLogo).catch(()=>{});
      if(oldCover&&oldCover!==cover)await repos.clubPublic.removeImage(oldCover).catch(()=>{});
      toast('Perfil público del club actualizado');
      setTimeout(()=>openClubPublicProfile(),280);
    }catch(error){
      if(uploadedLogo)await repos.clubPublic.removeImage(uploadedLogo).catch(()=>{});
      if(uploadedCover)await repos.clubPublic.removeImage(uploadedCover).catch(()=>{});
      throw error;
    }
  }});
}

async function hydrateIdentityRows(rows){
  return Promise.all((rows||[]).map(async r=>{
    if(r.tipo==='miembro'&&r.media_path){try{return {...r,media_url:await repos.sportsProfiles.photoUrl(r.media_path)}}catch{}}
    return r;
  }));
}

export async function openPublicDirectory(initialQuery=''){
  try{
    const render=async query=>{
      const rows=await hydrateIdentityRows(await repos.publicIdentity.search(query));
      const html=rows.map(r=>`<button type="button" class="public-identity-row" data-identity-type="${esc(r.tipo)}" data-reference-id="${esc(r.referencia_id)}"><div class="public-identity-avatar">${r.media_url?`<img src="${esc(r.media_url)}" alt="">`:`<span>${r.tipo==='club'?icon('shield',{size:24}):esc((r.nombre||'U').slice(0,1).toUpperCase())}</span>`}</div><div><strong>${esc(r.nombre)}</strong><small>${esc(r.tipo==='club'?'Club':r.subtitulo||'Miembro')}</small></div><span class="public-identity-type">${esc(r.tipo==='club'?'CLUB':'MIEMBRO')}</span>${icon('chevronRight',{size:17})}</button>`).join('');
      return {rows,html};
    };
    const first=await render(initialQuery);
    const modal=openDetail({title:'Perfiles',subtitle:'Directorio preparado para una capa pública común: club y perfiles deportivos del entorno actual',body:`<div class="public-directory-search"><input id="public-directory-query" type="search" value="${esc(initialQuery)}" placeholder="Buscar por nombre, apodo, ciudad o disciplina"><button class="btn btn-primary" id="public-directory-search">Buscar</button></div><div class="public-identity-list" id="public-identity-list">${first.html||'<div class="empty"><strong>Sin resultados</strong><p>No hay perfiles públicos que coincidan.</p></div>'}</div>`,width:'780px',className:'public-directory-modal'});
    const bindRows=()=>modal.wrap.querySelectorAll('[data-identity-type]').forEach(b=>b.addEventListener('click',()=>{if(b.dataset.identityType==='club')openClubPublicProfile(b.dataset.referenceId);else openSportsProfile(b.dataset.referenceId,{onChanged:()=>openPublicDirectory(modal.wrap.querySelector('#public-directory-query')?.value||'')});}));
    bindRows();
    const search=async()=>{const q=modal.wrap.querySelector('#public-directory-query')?.value||'';const result=await render(q);const target=modal.wrap.querySelector('#public-identity-list');if(target)target.innerHTML=result.html||'<div class="empty"><strong>Sin resultados</strong><p>No hay perfiles públicos que coincidan.</p></div>';bindRows();};
    modal.wrap.querySelector('#public-directory-search')?.addEventListener('click',search);
    modal.wrap.querySelector('#public-directory-query')?.addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();search();}});
  }catch(error){setError(error);}
}
