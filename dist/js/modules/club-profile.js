import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { esc } from '../core/utils.js';
import { openForm, openDetail, toast, setError, closeModal, confirmDialog } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { themeDefinition } from '../core/platform.js';

const list=(x)=>Array.isArray(x)?x:[];
function safeHttpsUrl(value){try{const u=new URL(String(value||''));return u.protocol==='https:'?u.href.replaceAll("'",'%27').replaceAll('"','%22'):'';}catch{return '';}}
const link=(url,label)=>{const safe=safeHttpsUrl(url);return safe?`<a class="btn btn-ghost btn-sm" href="${esc(safe)}" target="_blank" rel="noopener noreferrer">${esc(label)}</a>`:'';};

function body(p){
  const disciplines=list(p.disciplinas).map(d=>`<span class="badge badge-neutral">${esc(d.nombre||d)}</span>`).join('');
  const location=[p.ciudad,p.provincia,p.pais].filter(Boolean).join(' · ');
  const links=[link(p.web_publica,'Web'),link(p.instagram,'Instagram'),link(p.tiktok,'TikTok'),link(p.youtube,'YouTube')].filter(Boolean).join('');
  const cover=safeHttpsUrl(p.portada_url),logo=safeHttpsUrl(p.logo_url);
  const theme=themeDefinition(p.theme_id);
  return `<article class="club-public-profile ${esc(theme.className)}" data-club-theme="${esc(theme.id)}">
    <div class="club-public-cover ${cover?'has-image':''}" ${cover?`style="background-image:linear-gradient(180deg,rgba(5,6,8,.15),rgba(5,6,8,.92)),url('${esc(cover)}')"`:''}>
      <div class="club-public-logo">${logo?`<img src="${esc(logo)}" alt="Logo de ${esc(p.nombre_publico)}">`:`<span>${icon('shield',{size:52})}</span>`}</div>
      <div><span class="page-kicker">PERFIL DEL CLUB</span><h2>${esc(p.nombre_publico)}</h2>${p.alias?`<strong>${esc(p.alias)}</strong>`:''}${p.lema?`<p class="club-public-motto">${esc(p.lema)}</p>`:''}${location?`<p>${icon('mapPin',{size:14})} ${esc(location)}</p>`:''}</div>
    </div>
    ${p.descripcion?`<section class="club-public-section"><h3>Sobre el club</h3><p>${esc(p.descripcion)}</p></section>`:''}
    ${disciplines?`<section class="club-public-section"><h3>Disciplinas</h3><div class="detail-badges">${disciplines}</div></section>`:''}
    ${p.historia?`<section class="club-public-section"><h3>Trayectoria</h3><p>${esc(p.historia)}</p></section>`:''}
    ${p.logros?`<section class="club-public-section"><h3>Logros destacados</h3><p>${esc(p.logros)}</p></section>`:''}
    ${(p.contacto_publico||links)?`<section class="club-public-section"><h3>Información pública</h3>${p.contacto_publico?`<p>${esc(p.contacto_publico)}</p>`:''}${links?`<div class="row-actions">${links}</div>`:''}</section>`:''}
  </article>`;
}

export async function openClubPublicProfile(clubId=state.session?.club_id){
  try{
    const p=await repos.clubPublic.one(clubId);
    if(!p){toast('El perfil público del club todavía no está disponible.','error');return null;}
    const actions=`<button class="btn btn-ghost" id="club-public-album">${icon('image',{size:15})} Álbum</button>${p.editable?`<button class="btn btn-primary" id="club-public-edit">${icon('edit',{size:15})} Editar perfil público</button>`:''}`;
    const modal=openDetail({title:p.nombre_publico,subtitle:'Perfil público del club · separado de los datos administrativos',body:body(p),actions,width:'900px',className:'club-public-modal'});
    modal.wrap.querySelector('#club-public-edit')?.addEventListener('click',()=>editClubPublicProfile(p));
    modal.wrap.querySelector('#club-public-album')?.addEventListener('click',()=>openClubAlbum(p));
    return p;
  }catch(error){setError(error);return null;}
}

export async function openClubAlbum(profile){
  const clubId=profile?.club_id||state.session?.club_id;if(!clubId)return;
  try{
    const rows=await repos.clubPublic.album(clubId);const editable=profile?.editable===true||rows?.some(x=>x.editable===true);
    const photos=list(rows).filter(x=>x.tipo==='photo'&&x.estado!=='removed'),videos=list(rows).filter(x=>x.tipo==='video'&&x.estado!=='removed');
    const media=list(rows).filter(x=>x.estado!=='removed').map(m=>{const url=repos.clubPublic.albumUrl(m.storage_path);return `<article class="kx-album-tile"><div class="kx-album-media">${m.tipo==='video'?`<video controls preload="metadata" playsinline src="${esc(url)}"></video>`:`<button type="button" class="kx-album-photo-open" data-club-media-open="${esc(m.id)}" aria-label="Abrir foto completa"><img src="${esc(url)}" alt="Foto del álbum de ${esc(profile?.nombre_publico||'club')}" loading="lazy"></button>`}</div><div class="kx-album-meta"><span>${m.tipo==='video'?'VÍDEO':'FOTO'}</span>${m.tipo==='video'?`<small>${Number(m.duration_seconds||0).toFixed(1)} s</small>`:''}${editable?`<button class="btn btn-ghost btn-sm" data-club-media-remove="${esc(m.id)}">Retirar</button>`:''}</div></article>`}).join('');
    const actions=editable?`<button class="btn btn-primary" id="club-album-add">${icon('plus',{size:15})} Añadir contenido</button>`:'';
    const modal=openDetail({title:`Álbum · ${profile?.nombre_publico||'Club'}`,subtitle:`${photos.length}/10 fotos · ${videos.length}/3 vídeos · máximo 15 s por vídeo`,body:`<div class="kx-album-grid">${media||'<div class="empty"><strong>Álbum vacío</strong><p>El avatar y la portada no cuentan dentro de este límite.</p></div>'}</div>`,actions,width:'920px',className:'club-album-modal'});
    modal.wrap.querySelectorAll('[data-club-media-open]').forEach(b=>b.addEventListener('click',()=>{const item=rows.find(x=>String(x.id)===String(b.dataset.clubMediaOpen));if(!item)return;const url=repos.clubPublic.albumUrl(item.storage_path);const detail=openDetail({title:`Foto · ${profile?.nombre_publico||'Club'}`,subtitle:'Vista completa · sin recorte',body:`<div class="kx-media-viewer"><img src="${esc(url)}" alt="Foto completa del álbum"></div>`,actions:'<button type="button" class="btn btn-ghost" id="club-album-back">Volver al álbum</button>',width:'980px',className:'kx-media-viewer-modal'});detail.wrap.querySelector('#club-album-back')?.addEventListener('click',()=>openClubAlbum(profile));}));
    modal.wrap.querySelector('#club-album-add')?.addEventListener('click',()=>openForm({title:'Añadir al álbum del club',subtitle:'Hasta 10 fotos y 3 vídeos simultáneos. Los vídeos se validan a un máximo de 15 segundos.',fields:[{name:'tipo',label:'Tipo',type:'select',required:true,options:[{value:'photo',label:'Fotografía'},{value:'video',label:'Vídeo · máximo 15 s'}]},{name:'archivo',label:'Archivo',type:'file',required:true,accept:'image/jpeg,image/png,image/webp,video/mp4,video/webm,video/quicktime',full:true}],submitText:'Subir',onSubmit:async v=>{if(!v.archivo)throw new Error('Selecciona un archivo.');await repos.clubPublic.uploadAlbumMedia(clubId,v.tipo,v.archivo);toast('Contenido añadido al álbum');closeModal();setTimeout(()=>openClubAlbum(profile),160);}}));
    modal.wrap.querySelectorAll('[data-club-media-remove]').forEach(b=>b.addEventListener('click',()=>{const media=rows.find(x=>x.id===b.dataset.clubMediaRemove);if(!media)return;confirmDialog('Eliminar del álbum','Dejará de mostrarse públicamente. El registro conserva trazabilidad.',async()=>{await repos.clubPublic.removeAlbumMedia(clubId,media);toast('Contenido eliminado');closeModal();setTimeout(()=>openClubAlbum(profile),150);},{confirmText:'Eliminar',danger:true});}));
  }catch(error){setError(error);}
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
    {name:'portada',label:'Portada del perfil público',type:'file',accept:'image/jpeg,image/png,image/webp,image/gif',help:'Opcional · máximo 5 MB. La portada llena todo el banner y puede recortarse proporcionalmente.'},{name:'quitar_portada',label:'Quitar portada pública actual',type:'checkbox',value:false}
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

export async function openPublicDirectory(initialQuery=''){
  try{
    const render=async query=>{
      const rows=await repos.kombaxSocial.clubDirectory(query,200);
      const html=(rows||[]).map(r=>`<button type="button" class="public-identity-row" data-social-id="${esc(r.social_id)}"><div class="public-identity-avatar">${r.avatar_url?`<img src="${esc(r.avatar_url)}" alt="">`:`<span>${r.tipo==='club'?icon('shield',{size:24}):esc((r.nombre_publico||'U').slice(0,1).toUpperCase())}</span>`}</div><div><strong>${esc(r.apodo_deportivo||r.nombre_publico)}</strong><small>${esc(r.tipo==='club'?'Club KOMBAX':r.affiliation_confirmed?'Miembro · afiliación confirmada':'Miembro')}</small></div><span class="public-identity-type">${esc(r.tipo==='club'?'CLUB':'MIEMBRO')}</span>${icon('chevronRight',{size:17})}</button>`).join('');
      return {rows,html};
    };
    const first=await render(initialQuery);
    const modal=openDetail({title:'Perfiles KOMBAX',subtitle:'Directorio del club con una única identidad pública por miembro',body:`<div class="public-directory-search"><input id="public-directory-query" type="search" value="${esc(initialQuery)}" placeholder="Buscar por nombre o apodo"><button class="btn btn-primary" id="public-directory-search">Buscar</button></div><div class="public-identity-list" id="public-identity-list">${first.html||'<div class="empty"><strong>Sin resultados</strong><p>No hay perfiles KOMBAX que coincidan.</p></div>'}</div>`,width:'780px',className:'public-directory-modal'});
    const bindRows=()=>modal.wrap.querySelectorAll('[data-social-id]').forEach(b=>b.addEventListener('click',async()=>{const {openKombaxPublicProfile}=await import('./public-profile.js');openKombaxPublicProfile(b.dataset.socialId);}));
    bindRows();
    const search=async()=>{const q=modal.wrap.querySelector('#public-directory-query')?.value||'';const result=await render(q);const target=modal.wrap.querySelector('#public-identity-list');if(target)target.innerHTML=result.html||'<div class="empty"><strong>Sin resultados</strong><p>No hay perfiles KOMBAX que coincidan.</p></div>';bindRows();};
    modal.wrap.querySelector('#public-directory-search')?.addEventListener('click',search);
    modal.wrap.querySelector('#public-directory-query')?.addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();search();}});
  }catch(error){setError(error);}
}
