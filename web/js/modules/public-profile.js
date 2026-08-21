// KOMBAX 20.048 · canonical public identity renderer.
// A Member has one public identity: the KOMBAX Social profile. Sports details are
// optional sections of that same profile; they are not a second profile model.
import { repos } from '../core/repositories.js';
import { esc, dtFmt, humanError } from '../core/utils.js';
import { identityTypeLabel, resolveIdentityMedia, initials } from '../core/identity-context.js';
import { openDetail, openForm, confirmDialog, toast, setError, setMainHtml, pageHeader } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { openClubPublicProfile } from './club-profile.js';
import { themeDefinition } from '../core/platform.js';
import { openPrivacyConditions } from './help-legal.js';
import { openAuthenticatedPasswordChange } from './account-security.js';
import { openKombaxPostManager, socialQuotaMarkup } from './social-post-management.js';

const arr=v=>Array.isArray(v)?v:[];
const url=path=>path?repos.kombaxSocial.mediaUrl(path):'';
const money=(v,c='EUR')=>v==null?'':new Intl.NumberFormat('es-ES',{style:'currency',currency:c||'EUR'}).format(Number(v));
function safeExternal(value){const s=String(value||'').trim();return /^https:\/\//i.test(s)?s:'';}
function avatar(profile){const src=resolveIdentityMedia(profile,'avatar');return src?`<img src="${esc(src)}" alt="">`:`<span>${esc(initials(profile.nombre_publico))}</span>`;}
function gallery(profile){
  const rows=arr(profile.album).filter(x=>['photo','video'].includes(x.tipo));
  if(!rows.length)return '<div class="empty compact"><strong>Álbum todavía vacío</strong><p>El avatar y la portada se gestionan por separado.</p></div>';
  return `<div class="kx-public-album">${rows.map(m=>{const src=url(m.storage_path);return `<article>${m.tipo==='video'?`<video src="${esc(src)}" controls preload="metadata" playsinline></video>`:`<button type="button" class="kx-public-photo-open" data-kx-public-photo="${esc(m.id)}" data-kx-public-photo-path="${esc(m.storage_path)}" aria-label="Abrir foto completa"><img src="${esc(src)}" alt="Contenido del perfil" loading="lazy"></button>`}</article>`}).join('')}</div>`;
}
function postRow(p){return `<article data-kx-profile-post="${esc(p.id)}"><span>${esc(p.tipo||'Actualización')} · ${dtFmt(p.creado_en)} · ${esc(p.audiencia_label||'Público')}</span><p>${esc(p.texto)}</p><small>${Number(p.likes_count||0)} likes · ${Number(p.comentarios_count||0)} comentarios</small></article>`;}
function posts(profile,usage=null){const rows=arr(profile.posts).slice(0,10);return `<div class="kx-profile-activity">${usage?socialQuotaMarkup(usage,{compact:true}):''}${rows.length?`<div class="kx-public-posts" id="kx-profile-post-list">${rows.map(postRow).join('')}</div><div class="kx-profile-post-more"><button type="button" class="btn btn-ghost btn-sm" id="kx-profile-post-more">Ver publicaciones anteriores</button></div>`:'<div class="empty compact"><strong>Sin publicaciones visibles para ti</strong></div>'}</div>`;}
function showcase(profile){const rows=arr(profile.showcase);return rows.length?`<div class="kx-public-showcase">${rows.map(x=>`<article>${x.imagen_url?`<div class="kx-public-showcase-media"><img src="${esc(x.imagen_url)}" alt="${esc(x.nombre)}" loading="lazy"></div>`:''}<div><strong>${esc(x.nombre)}</strong><p>${esc(x.resumen||'')}</p>${x.precio_orientativo!=null?`<small>${esc(money(x.precio_orientativo,x.moneda))}</small>`:''}<div class="row-actions">${safeExternal(x.visitar_url)?`<a class="btn btn-ghost btn-sm" href="${esc(x.visitar_url)}" target="_blank" rel="noopener">Ver web</a>`:''}${safeExternal(x.donde_encontrar_url)?`<a class="btn btn-ghost btn-sm" href="${esc(x.donde_encontrar_url)}" target="_blank" rel="noopener">Dónde encontrar</a>`:''}</div></div></article>`).join('')}</div>`:'<div class="empty compact"><strong>Sin fichas Showcase activas</strong></div>';}
function sportsFacts(profile){
  const s=profile.sports||{};
  const rows=[
    ['Apodo deportivo',s.apodo_deportivo],['Disciplinas',s.disciplinas_publicas],['Experiencia',s.experiencia_anos!=null?`${Number(s.experiencia_anos)} años`:''],
    ['Especialidad',s.especialidad],['Guardia',s.guardia],['Técnica favorita',s.tecnica_favorita]
  ].filter(([,v])=>String(v??'').trim());
  if(!rows.length&&!s.trayectoria_declarada&&!s.objetivos)return '<div class="empty compact"><strong>Información deportiva opcional</strong><p>Este miembro todavía no ha añadido detalles deportivos públicos.</p></div>';
  return `<div class="kx-member-sports">${rows.length?`<div class="kx-member-sports-grid">${rows.map(([k,v])=>`<div><small>${esc(k)}</small><strong>${esc(v)}</strong></div>`).join('')}</div>`:''}${s.trayectoria_declarada?`<div class="kx-member-sports-copy"><small>Trayectoria declarada</small><p>${esc(s.trayectoria_declarada)}</p></div>`:''}${s.objetivos?`<div class="kx-member-sports-copy"><small>Objetivos</small><p>${esc(s.objetivos)}</p></div>`:''}<p class="kx-member-profile-note">Información declarada por el miembro. No equivale a resultados oficiales ni a verificación competitiva KOMBAX.</p></div>`;
}
function core(profile){
  const c=profile.core||{};const type=profile.perfil_tipo||profile.sujeto_tipo;
  if(type==='club')return `<div class="kx-profile-facts">${c.lema?`<p><strong>${esc(c.lema)}</strong></p>`:''}${c.ciudad||c.provincia?`<p>${icon('mapPin',{size:16})} ${esc([c.ciudad,c.provincia,c.pais].filter(Boolean).join(' · '))}</p>`:''}${c.historia?`<p>${esc(c.historia)}</p>`:''}${c.logros?`<p><strong>Trayectoria</strong><br>${esc(c.logros)}</p>`:''}</div>`;
  if(type==='miembro'){
    const a=profile.affiliation||null;const album=arr(profile.album);const photos=album.filter(x=>x.tipo==='photo').length;const videos=album.filter(x=>x.tipo==='video').length;
    return `<div class="kx-member-public-summary"><p>${esc(c.bio_publica||profile.bio||'Miembro de la comunidad KOMBAX.')}</p><div class="kx-profile-facts"><span><b>Perfil Miembro</b> · público</span><span>${photos}/10 fotos</span><span>${videos}/3 vídeos</span></div>${a?.verificada?`<p class="kx-member-affiliation">${icon('checkCircle',{size:16})} Afiliación confirmada · <button type="button" ${a.club_social_id?`data-kx-affiliation-club="${esc(a.club_social_id)}"`:''}>${esc(a.club_nombre)}</button></p>`:''}<small class="kx-member-profile-note">Tu perfil KOMBAX es tu única ficha pública. La insignia KOMBAX y el dossier competitivo avanzado pertenecen al perfil Competidor verificado.</small></div>`;
  }
  return `<div class="kx-profile-facts">${c.descripcion?`<p>${esc(c.descripcion)}</p>`:''}${c.disciplinas?`<p><strong>Disciplinas</strong> ${esc(Array.isArray(c.disciplinas)?c.disciplinas.join(' · '):c.disciplinas)}</p>`:''}${c.club_nombre?`<p>${icon('shield',{size:16})} ${esc(c.club_nombre)}</p>`:''}</div>`;
}
function profileArticle(p,{usage=null}={}){
  const banner=resolveIdentityMedia(p,'banner');const type=p.perfil_tipo||p.sujeto_tipo;const profileTheme=type==='club'?themeDefinition(p.theme_id):null;
  return `<article class="kx-public-profile ${profileTheme?esc(profileTheme.className):''}" ${profileTheme?`data-club-theme="${esc(profileTheme.id)}"`:''}>
    <div class="kx-public-profile-hero">${banner?`<img class="kx-public-banner" src="${esc(banner)}" alt="">`:'<div class="kx-public-banner fallback"></div>'}<div class="kx-public-avatar">${avatar(p)}</div></div>
    <div class="kx-public-title"><div><span class="page-kicker">${esc(identityTypeLabel[type]||type||'KOMBAX')}</span><h3>${esc(p.nombre_publico)} ${p.verificado?`<span class="kombax-verified" title="${esc(identityTypeLabel[type]||type)} verificado por KOMBAX">${icon('shieldCheck',{size:16})}</span>`:''}</h3>${p.bio?`<p>${esc(p.bio)}</p>`:''}</div></div>
    ${core(p)}
    ${type==='miembro'?`<section><h4>Información deportiva</h4>${sportsFacts(p)}</section>`:''}
    <section><h4>Álbum</h4>${gallery(p)}</section>
    <section><h4>Actividad KOMBAX</h4>${posts(p,usage)}</section>
    ${(type==='club'||type==='marca')?`<section><h4>Showcase</h4>${showcase(p)}</section>`:''}
  </article>`;
}
function profileActions(p,{legal=false}={}){const type=p.perfil_tipo||p.sujeto_tipo;return `${p.contactable&&!p.own?'<button class="btn btn-primary" id="kx-public-contact">Contactar</button>':''}${!p.own?'<button class="btn btn-ghost" id="kx-public-report">Denunciar</button>':''}<button class="btn btn-ghost" id="kx-public-share">Compartir</button>${p.own?'<button class="btn btn-ghost" id="kx-public-manage-posts">Gestionar publicaciones</button><button class="btn btn-ghost" id="kx-public-account-security">Seguridad y acceso</button>':''}${p.own&&type==='miembro'&&p.affiliation?.verificada?'<button class="btn btn-primary" id="kx-public-share-affiliation">Compartir afiliación</button>':''}${p.own&&type==='miembro'?'<button class="btn btn-ghost" id="kx-public-member-album">Gestionar álbum</button><button class="btn btn-ghost" id="kx-public-member-edit">Editar mi perfil</button>':''}${legal&&p.own?'<button class="btn btn-ghost" id="kx-public-legal">Privacidad y condiciones</button>':''}${p.own&&type==='club'?'<button class="btn btn-ghost" id="kx-public-club-manage">Gestionar perfil del club</button>':''}`;}
async function contact(profile){
  const mine=await repos.kombaxSocial.myProfiles();const eligible=mine.filter(x=>x.contacto_habilitado);
  if(!eligible.length){toast('No tienes una identidad autorizada para iniciar Contacto KOMBAX. Los perfiles personales menores de 18 años no pueden iniciar conversaciones.','error');return;}
  openForm({title:`Contactar con ${profile.nombre_publico}`,subtitle:'Contacto KOMBAX: indica el motivo y un primer mensaje. El chat de texto se habilita únicamente si la otra identidad acepta.',fields:[{name:'from',label:'Solicitar como',type:'select',required:true,options:eligible.map(x=>({value:x.id,label:x.identity_label||x.nombre_publico}))},{name:'motivo',label:'Motivo',type:'select',required:true,options:[{value:'entrenamiento',label:'Entrenamiento'},{value:'competicion',label:'Competición'},{value:'evento',label:'Evento'},{value:'colaboracion',label:'Colaboración'},{value:'patrocinio',label:'Patrocinio'},{value:'informacion',label:'Información'},{value:'otro',label:'Otro'}]},{name:'mensaje',label:'Primer mensaje',type:'textarea',required:true,full:true,rows:5,minLength:10,maxLength:500,help:'Entre 10 y 500 caracteres. Se enviará junto a la solicitud. Sin imágenes, vídeos, audios ni archivos.'}],submitText:'Enviar solicitud',onSubmit:async v=>{await repos.kombaxSocial.contact(v.from,profile.id,v.motivo,v.mensaje);toast('Solicitud de contacto enviada');}});
}
function report(profile){openForm({title:'Denunciar perfil',subtitle:profile.nombre_publico,fields:[{name:'motivo',label:'Motivo',type:'select',required:true,options:[{value:'spam',label:'Spam'},{value:'acoso',label:'Acoso'},{value:'suplantacion',label:'Suplantación'},{value:'privacidad',label:'Privacidad'},{value:'otro',label:'Otro'}]},{name:'detalle',label:'Detalle',type:'textarea',full:true,rows:4,maxLength:1000}],submitText:'Enviar denuncia',onSubmit:async v=>{await repos.kombaxSocial.report('perfil',profile.id,v.motivo,v.detalle||'');toast('Denuncia enviada');}});}

async function openMemberAlbum(profile,{onChanged}={}){
  try{
    const rows=arr(await repos.kombaxSocial.media(profile.id)).filter(x=>x.estado==='active'&&x.en_album&&['photo','video'].includes(x.tipo));
    const photos=rows.filter(x=>x.tipo==='photo'),videos=rows.filter(x=>x.tipo==='video');
    const tile=m=>{const src=url(m.storage_path);return `<article class="kx-album-tile"><div class="kx-album-media">${m.tipo==='video'?`<video src="${esc(src)}" controls preload="metadata" playsinline></video>`:`<button type="button" class="kx-album-photo-open" data-kx-member-photo="${esc(m.id)}" aria-label="Abrir foto completa"><img src="${esc(src)}" alt="Foto del álbum de ${esc(profile.nombre_publico)}" loading="lazy"></button>`}</div><div class="kx-album-meta"><span>${m.tipo==='video'?'VÍDEO':'FOTO'}</span>${m.tipo==='video'?`<small>${Number(m.duration_seconds||0).toFixed(1)} s</small>`:''}<button type="button" class="btn btn-ghost btn-sm" data-kx-member-media-remove="${esc(m.id)}">Retirar</button></div></article>`;};
    const modal=openDetail({title:`Álbum · ${profile.nombre_publico}`,subtitle:`Perfil Miembro · ${photos.length}/10 fotos · ${videos.length}/3 vídeos · máximo 15 s por vídeo`,body:`<div class="kx-member-album-intro"><strong>Tu espacio visual público</strong><p>Estas fotos y vídeos forman parte de tu ficha KOMBAX. Avatar y banner se gestionan por separado y no cuentan dentro del límite.</p></div><div class="kx-album-grid">${rows.map(tile).join('')||'<div class="empty"><strong>Álbum vacío</strong><p>Añade fotografías o vídeos para personalizar tu perfil público.</p></div>'}</div>`,actions:`<button type="button" class="btn btn-primary" id="kx-member-album-photo" ${photos.length>=10?'disabled':''}>+ Foto</button><button type="button" class="btn btn-ghost" id="kx-member-album-video" ${videos.length>=3?'disabled':''}>+ Vídeo</button>`,width:'920px',className:'kx-member-album-modal'});
    const upload=(kind)=>openForm({title:kind==='video'?'Añadir vídeo al álbum':'Añadir foto al álbum',subtitle:kind==='video'?'Máximo 15 segundos. Se conservará como contenido público de tu perfil Miembro.':'La imagen se incorporará a tu álbum público sin sustituir avatar ni banner.',fields:[{name:'archivo',label:kind==='video'?'Vídeo':'Fotografía',type:'file',required:true,full:true,accept:kind==='video'?'video/mp4,video/webm,video/quicktime':'image/jpeg,image/png,image/webp'}],submitText:'Añadir al álbum',onSubmit:async v=>{await repos.kombaxSocial.uploadMedia(profile.id,kind,v.archivo,{enAlbum:true,audience:'publica'});toast('Contenido añadido al álbum');modal.close?.();await onChanged?.();}});
    modal.wrap.querySelector('#kx-member-album-photo')?.addEventListener('click',()=>upload('photo'));
    modal.wrap.querySelector('#kx-member-album-video')?.addEventListener('click',()=>upload('video'));
    modal.wrap.querySelectorAll('[data-kx-member-photo]').forEach(b=>b.addEventListener('click',()=>{const item=rows.find(x=>String(x.id)===String(b.dataset.kxMemberPhoto));if(!item)return;const detail=openDetail({title:`Foto · ${profile.nombre_publico}`,subtitle:'Vista completa',body:`<div class="kx-media-viewer"><img src="${esc(url(item.storage_path))}" alt="Foto completa del álbum"></div>`,actions:'<button type="button" class="btn btn-ghost" id="kx-member-photo-back">Volver al álbum</button>',width:'980px',className:'kx-media-viewer-modal'});detail.wrap.querySelector('#kx-member-photo-back')?.addEventListener('click',()=>openMemberAlbum(profile,{onChanged}));}));
    modal.wrap.querySelectorAll('[data-kx-member-media-remove]').forEach(b=>b.addEventListener('click',()=>{const item=rows.find(x=>String(x.id)===String(b.dataset.kxMemberMediaRemove));if(!item)return;confirmDialog('Retirar del álbum','El contenido dejará de mostrarse en tu perfil público. Se conserva la trazabilidad técnica necesaria.',async()=>{await repos.kombaxSocial.removeMedia(item);toast('Contenido retirado');modal.close?.();await onChanged?.();},{confirmText:'Retirar',danger:true});}));
  }catch(error){setError(error);}
}

async function editMemberPublicProfile(profile,{onSaved}={}){
  const bio=profile?.core?.bio_publica||profile?.bio||'';const sports=profile?.sports||{};
  const media=await repos.kombaxSocial.media(profile.id).catch(()=>[]);const avatarMedia=media.find(x=>x.tipo==='avatar'&&x.estado==='active')||null;const bannerMedia=media.find(x=>x.tipo==='banner'&&x.estado==='active')||null;
  openForm({
    title:'Editar mi perfil',subtitle:'Esta es tu única ficha pública KOMBAX. Los datos administrativos, financieros y documentos del club nunca forman parte de este perfil.',width:'860px',
    fields:[
      {name:'bio_publica',label:'Presentación pública',type:'textarea',value:bio,full:true,rows:4,maxLength:800,help:'Cuenta quién eres y qué quieres mostrar a la comunidad.'},
      {name:'apodo_deportivo',label:'Apodo deportivo',value:sports.apodo_deportivo||'',maxLength:60},
      {name:'disciplinas_publicas',label:'Disciplinas que quieres mostrar',value:sports.disciplinas_publicas||'',maxLength:240,help:'Texto público y voluntario. No se publica automáticamente tu matrícula privada del club.'},
      {name:'experiencia_anos',label:'Años de experiencia',type:'number',value:sports.experiencia_anos??'',min:0,max:80,step:0.5},
      {name:'especialidad',label:'Especialidad',value:sports.especialidad||'',maxLength:120},
      {name:'guardia',label:'Guardia',value:sports.guardia||'',maxLength:40},
      {name:'tecnica_favorita',label:'Técnica favorita',value:sports.tecnica_favorita||'',maxLength:120},
      {name:'trayectoria_declarada',label:'Trayectoria declarada',type:'textarea',value:sports.trayectoria_declarada||'',full:true,rows:3,maxLength:1200,help:'Información declarada por ti. No se presentará como resultado oficial verificado.'},
      {name:'objetivos',label:'Objetivos',type:'textarea',value:sports.objetivos||'',full:true,rows:3,maxLength:800},
      {name:'afiliacion_visible',label:'Mostrar públicamente mi afiliación confirmada al club',type:'checkbox',value:profile.affiliation_visible!==false,full:true,help:'La pertenencia se valida contra tu alta real en el club; no es un texto editable.'},
      {name:'avatar',label:'Foto pública de perfil',type:'file',accept:'image/jpeg,image/png,image/webp',full:true,help:'Opcional. Si eliges una imagen sustituirá tu avatar público de KOMBAX.'},
      ...(avatarMedia?[{name:'eliminar_avatar',label:'Eliminar foto pública actual',type:'checkbox',value:false,full:true}]:[]),
      {name:'banner',label:'Portada pública',type:'file',accept:'image/jpeg,image/png,image/webp',full:true,help:'Opcional. La portada llena el banner y puede recortarse proporcionalmente para ocupar toda el área.'},
      ...(bannerMedia?[{name:'eliminar_banner',label:'Eliminar portada pública actual',type:'checkbox',value:false,full:true}]:[])
    ],submitText:'Guardar perfil',onSubmit:async v=>{
      await repos.kombaxIdentity.updateMemberProfile(v);await repos.kombaxSocial.setAffiliationVisibility(profile.id,v.afiliacion_visible===true);
      if(v.avatar)await repos.kombaxSocial.uploadMedia(profile.id,'avatar',v.avatar,{enAlbum:false});else if(v.eliminar_avatar&&avatarMedia)await repos.kombaxSocial.removeMedia(avatarMedia);
      if(v.banner)await repos.kombaxSocial.uploadMedia(profile.id,'banner',v.banner,{enAlbum:false});else if(v.eliminar_banner&&bannerMedia)await repos.kombaxSocial.removeMedia(bannerMedia);
      if(v.avatar||v.banner||v.eliminar_avatar||v.eliminar_banner)window.dispatchEvent(new CustomEvent('uw-kombax-social-profile-media-changed',{detail:{social_profile_id:profile.id,kind:'profile_media'}}));
      toast('Perfil KOMBAX actualizado');await onSaved?.();
    }
  });
}

function bindProfileActions(root,p,{onRefresh,legal=false}={}){
  root.querySelectorAll('[data-kx-public-photo]').forEach(b=>b.addEventListener('click',()=>{const src=url(b.dataset.kxPublicPhotoPath);const detail=openDetail({title:`Foto · ${p.nombre_publico}`,subtitle:'Vista completa · sin recorte',body:`<div class="kx-media-viewer"><img src="${esc(src)}" alt="Foto completa del perfil"></div>`,actions:'<button type="button" class="btn btn-ghost" id="kx-public-photo-back">Volver al perfil</button>',width:'980px',className:'kx-media-viewer-modal'});detail.wrap.querySelector('#kx-public-photo-back')?.addEventListener('click',()=>openKombaxPublicProfile(p.id));}));
  root.querySelector('#kx-public-contact')?.addEventListener('click',()=>contact(p));root.querySelector('#kx-public-report')?.addEventListener('click',()=>report(p));
  root.querySelector('#kx-public-share')?.addEventListener('click',async()=>{const text=`${p.nombre_publico} · KOMBAX`;try{if(navigator.share)await navigator.share({title:p.nombre_publico,text});else await navigator.clipboard.writeText(location.href);toast(navigator.share?'Compartido':'Enlace copiado');}catch{}});
  let postCursor=(()=>{const first=arr(p.posts).slice(0,10);const last=first.at(-1);return last?{created:last.creado_en,id:last.id}:null;})();
  root.querySelector('#kx-profile-post-more')?.addEventListener('click',async e=>{const b=e.currentTarget;b.disabled=true;b.textContent='Cargando…';try{const page=await repos.kombaxSocial.profilePosts(p.id,postCursor,10);const list=root.querySelector('#kx-profile-post-list');if(list&&page.length)list.insertAdjacentHTML('beforeend',page.map(postRow).join(''));const last=page.at(-1);if(last)postCursor={created:last.creado_en,id:last.id};if(page.length<10)b.remove();else{b.disabled=false;b.textContent='Ver publicaciones anteriores';}}catch(error){b.disabled=false;b.textContent='Ver publicaciones anteriores';setError(error);}});
  root.querySelector('#kx-public-manage-posts')?.addEventListener('click',()=>openKombaxPostManager(p,{onChanged:onRefresh}));
  root.querySelector('#kx-public-account-security')?.addEventListener('click',()=>openAuthenticatedPasswordChange({onComplete:()=>location.reload()}));
  root.querySelector('[data-kx-affiliation-club]')?.addEventListener('click',()=>openKombaxPublicProfile(p.affiliation?.club_social_id));
  root.querySelector('#kx-public-share-affiliation')?.addEventListener('click',async()=>{const b=root.querySelector('#kx-public-share-affiliation');b.disabled=true;try{await repos.kombaxSocial.shareAffiliation(p.id);toast(`Afiliación con ${p.affiliation?.club_nombre||'tu club'} publicada`);await onRefresh?.();}catch(error){b.disabled=false;setError(error);}});
  root.querySelector('#kx-public-member-album')?.addEventListener('click',()=>openMemberAlbum(p,{onChanged:onRefresh}));
  root.querySelector('#kx-public-member-edit')?.addEventListener('click',()=>editMemberPublicProfile(p,{onSaved:onRefresh}));
  root.querySelector('#kx-public-legal')?.addEventListener('click',openPrivacyConditions);
  root.querySelector('#kx-public-club-manage')?.addEventListener('click',()=>openClubPublicProfile(p.club_id));
}

export async function openKombaxPublicProfile(socialId){
  try{
    const p=await repos.kombaxSocial.publicProfile(socialId);if(!p?.id)throw new Error('El perfil público no está disponible.');const type=p.perfil_tipo||p.sujeto_tipo;const usage=p.own?await repos.kombaxSocial.quota(p.id).catch(()=>null):null;
    const modal=openDetail({title:p.nombre_publico,subtitle:`Perfil público KOMBAX · ${identityTypeLabel[type]||type}`,body:profileArticle(p,{usage}),actions:profileActions(p),width:'980px',className:'kx-public-profile-modal'});
    bindProfileActions(modal.wrap,p,{onRefresh:async()=>{modal.close?.();setTimeout(()=>openKombaxPublicProfile(p.id),120);}});return p;
  }catch(error){setError(error);return null;}
}

export async function renderOwnKombaxProfilePage(socialId,{extraHtml='',bindExtra}={}){
  try{
    const p=await repos.kombaxSocial.publicProfile(socialId);if(!p?.id)throw new Error('Tu perfil KOMBAX no está disponible.');const usage=await repos.kombaxSocial.quota(p.id).catch(()=>null);
    const refresh=()=>renderOwnKombaxProfilePage(p.id,{extraHtml,bindExtra});
    setMainHtml(`${pageHeader('Mi perfil','Esta es la misma ficha pública que ven los demás usuarios de KOMBAX.',profileActions(p,{legal:true}),'KOMBAX SOCIAL')}<section class="kx-canonical-profile-notice"><div>${icon('user',{size:20})}</div><div><strong>Una identidad, un perfil</strong><span>Banner, avatar, información deportiva, álbum y publicaciones viven en esta única ficha. Tu expediente privado del club permanece separado.</span></div></section>${profileArticle(p,{usage})}${extraHtml}`);
    const root=document.getElementById('main-view');if(root){bindProfileActions(root,p,{onRefresh:refresh,legal:true});await bindExtra?.(root,p,refresh);}return p;
  }catch(error){setError(error);setMainHtml(`${pageHeader('Mi perfil')}<div class="empty"><strong>No se pudo abrir tu perfil KOMBAX</strong><p>${esc(humanError(error)||'Inténtalo de nuevo.')}</p></div>`);return null;}
}
