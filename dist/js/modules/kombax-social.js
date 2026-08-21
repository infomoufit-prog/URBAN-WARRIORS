import { repos } from '../core/repositories.js';
import { backend } from '../core/backend.js';
import { esc, dtFmt, humanError } from '../core/utils.js';
import { KOMBAX_BRAND } from '../core/platform.js';
import { pageHeader, empty, badge, openForm, openDetail, closeModal, confirmDialog, toast, setError, setMainHtml } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { chooseDefaultIdentity, setActiveIdentity, identityLabel } from '../core/identity-context.js';
import { openKombaxPublicProfile } from './public-profile.js';
import { openKombaxPostManager, socialQuotaMarkup } from './social-post-management.js';
import { createAdaptivePoller } from '../core/adaptive-poller.js';

const PAGE_SIZE=20;
const TYPE_LABEL={actualizacion:'Actualización',resultado:'Resultado',evento:'Evento',oportunidad:'Oportunidad'};
const PROFILE_LABEL={club:'Club',miembro:'Miembro',perfil_directo:'Perfil KOMBAX'};
const PUBLIC_TYPE_LABEL={club:'Club',miembro:'Miembro',competidor:'Competidor',marca:'Marca',federacion:'Federación',profesional:'Profesional / Representante',espectador:'Espectador'};
window.addEventListener('uw-kombax-social-profile-media-changed',()=>{if(document.querySelector('.kombax-social-page'))renderKombaxSocial().catch(()=>{});});

const CONTACT_LABEL={entrenamiento:'Entrenamiento',competicion:'Competición',evento:'Evento',colaboracion:'Colaboración',patrocinio:'Patrocinio',informacion:'Información',otro:'Otro'};
let activeView='feed';
let posts=[];
let cursor=null;
let done=false;
let loading=false;
let ownProfiles=[];
let socialStatus=null;
let activeIdentityId='';
let feedObserver=null;
let audiencesByProfile=new Map();
let activeQuota=null;
let expandedCommentPostId='';
let contactFilter='all';

const initials=name=>String(name||'K').split(/\s+/).filter(Boolean).slice(0,2).map(x=>x[0]?.toUpperCase()).join('');
const isOwn=id=>ownProfiles.some(p=>p.id===id);
const profileAvatar=p=>{const path=p?.autor_avatar_path||p?.avatar_path;const src=path?mediaUrl(path):(p?.autor_avatar_url||p?.avatar_url||'');return src?`<img src="${esc(src)}" alt="" loading="lazy" decoding="async">`:`<span>${esc(initials(p?.autor_nombre||p?.nombre_publico))}</span>`;};
const verified=(value,type='')=>{if(!value)return '';const label=PUBLIC_TYPE_LABEL[type]||PROFILE_LABEL[type]||'Perfil';return `<span class="kombax-verified" title="${esc(label)} verificado por KOMBAX" aria-label="${esc(label)} verificado por KOMBAX">${icon('shieldCheck',{size:14})}</span>`;};
const audienceKey=a=>`${a?.audiencia||'publica'}|${a?.target_social_id||''}|${a?.target_club_id||''}`;
const audienceOptions=id=>audiencesByProfile.get(String(id))||[{audiencia:'publica',target_social_id:null,target_club_id:null,label:'Público · Todo KOMBAX',descripcion:'Visible para toda la red KOMBAX Social.',predeterminada:true}];
const audienceSelectOptions=id=>audienceOptions(id).map(a=>`<option value="${esc(audienceKey(a))}">${esc(a.label)}</option>`).join('');
const parseAudience=value=>{const [audiencia='publica',social='',club='']=String(value||'publica||').split('|');return {audiencia,audiencia_federacion_social_id:social||null,audiencia_club_id:club||null};};
const audienceChip=p=>`<span class="kx-audience-chip ${p?.audiencia&&p.audiencia!=='publica'?'restricted':'public'}" title="${esc(p?.audiencia==='publica'?'Visible para toda la red KOMBAX Social':'Publicación con audiencia restringida')}">${icon(p?.audiencia==='publica'?'globe':'lock',{size:13})} ${esc(p?.audiencia_label||'Público')}</span>`;

const affiliationChip=p=>{
  const clubId=p?.autor_club_social_id||p?.club_social_id;
  const clubName=p?.autor_club_nombre||p?.club_nombre;
  const ok=p?.autor_afiliacion_verificada===true||p?.afiliacion_verificada===true;
  return ok&&clubName?`<button type="button" class="kx-affiliation-chip" ${clubId?`data-social-affiliation-club="${esc(clubId)}"`:''} title="Afiliación confirmada por el club">${icon('checkCircle',{size:13})} Afiliación · ${esc(clubName)}</button>`:'';
};

function socialHeader(){
  return `<section class="kombax-social-brand"><img src="${esc(KOMBAX_BRAND.symbol)}" alt=""><div><span>KOMBAX</span><strong>SOCIAL</strong><small>CONNECT · COMPETE · GROW</small></div></section>`;
}

function tabBar(){
  return `<div class="kombax-social-tabs" role="tablist">
    <button type="button" data-social-view="feed" class="${activeView==='feed'?'active':''}">${icon('activity',{size:17})} Actualidad</button>
    <button type="button" data-social-view="profiles" class="${activeView==='profiles'?'active':''}">${icon('users',{size:17})} Perfiles</button>
    <button type="button" data-social-view="saved" class="${activeView==='saved'?'active':''}">${icon('archive',{size:17})} Guardados</button>
    <button type="button" data-social-view="relations" class="${activeView==='relations'?'active':''}">${icon('network',{size:17})} Mi red</button>
    <button type="button" data-social-view="contacts" class="${activeView==='contacts'?'active':''}">${icon('message',{size:17})} Mensajes</button>
    <button type="button" data-social-view="safety" class="${activeView==='safety'?'active':''}">${icon('shield',{size:17})} Seguridad</button>
  </div>`;
}

function activeIdentity(){return ownProfiles.find(x=>String(x.id)===String(activeIdentityId))||chooseDefaultIdentity(ownProfiles)||null;}
function identitySwitcher(){
  if(!ownProfiles.length)return '';
  const current=activeIdentity();
  return `<section class="kx-identity-context"><div>${icon('idCard',{size:22})}<div><small>ACTUAR COMO</small><strong>${esc(identityLabel(current))}</strong></div></div>${ownProfiles.length>1?`<label><span>Cambiar identidad</span><select id="kx-active-identity">${ownProfiles.map(x=>`<option value="${esc(x.id)}" ${x.id===current?.id?'selected':''}>${esc(identityLabel(x))}</option>`).join('')}</select></label>`:''}</section>`;
}

function activationPanel(){
  if(socialStatus?.status==='activa')return '';
  const eligible=socialStatus?.eligible===true;
  return `<section class="kombax-social-notice"><div>${icon('shieldCheck',{size:28})}</div><div><strong>${eligible?'Activa tu perfil público de KOMBAX Social':'Tu perfil público todavía no está disponible'}</strong><p>${esc(socialStatus?.reason||'La activación es opcional y está separada de los datos administrativos del club.')}</p>${eligible?'<button type="button" class="btn btn-primary btn-sm" id="kombax-social-activate">Revisar y activar</button>':''}</div></section>`;
}

const mediaUrl=path=>path?backend.publicUrl('kombax-public-media',path):'';
function postMedia(p){
  if(!p.media_path)return '';
  const url=p.media_url||mediaUrl(p.media_path);
  return p.media_tipo==='video'
    ? `<div class="kombax-post-media"><video src="${esc(url)}" controls preload="metadata" playsinline></video><span>Vídeo · ${Number(p.media_duration||0).toFixed(1)} s</span></div>`
    : `<div class="kombax-post-media"><img src="${esc(url)}" alt="Multimedia de la publicación" loading="lazy"></div>`;
}

function socialRulesCard(){
  return `<section class="kx-social-rules-card"><div class="kx-social-rules-summary"><div>${icon('info',{size:22})}<div><strong>Cómo funciona KOMBAX Social</strong><span>Norma general actual para Miembro, Competidor, Club, Federación y Marca.</span></div></div><details><summary>Ver normas de publicación</summary><ul><li>Máximo <b>30 publicaciones activas</b> por identidad.</li><li>Máximo <b>3 publicaciones nuevas al día</b>.</li><li>Máximo <b>10 vídeos activos</b> por identidad.</li><li>El perfil muestra primero las <b>10 publicaciones más recientes</b> y permite cargar las anteriores de 10 en 10.</li><li>KOMBAX <b>no elimina automáticamente</b> tus publicaciones al llegar a 30: tú decides cuál borrar.</li><li>El Álbum es independiente: borrar una publicación no elimina una foto o vídeo que también hayas guardado en el Álbum.</li></ul><p>Estos límites son la norma general actual y podrán variar en el futuro según tipo de perfil o plan KOMBAX.</p></details></div></section>`;
}

function competitorFoundersPromo(){
  return `<section class="kx-founders-promo competitor" aria-label="Promoción de lanzamiento para competidores"><div class="kx-founders-promo-mark">${icon('fighter',{size:28})}</div><div><span>COMBAT SOCIAL · LANZAMIENTO</span><strong>PRIMEROS 20 · COMPETIDORES FUNDADORES</strong><p>Los primeros 20 competidores que completen la verificación KOMBAX quedarán incluidos en una <b>ventaja especial de lanzamiento</b> cuando KOMBAX active su modalidad de suscripción. Próximamente comunicaremos en qué consiste.</p><small>La plaza se determina por el orden de verificación KOMBAX.</small></div></section>`;
}

function quotaAction(){
  const current=activeIdentity();if(!current||!activeQuota)return '';
  const atLimit=Number(activeQuota.active_posts||0)>=Number(activeQuota.active_limit||30);
  return `${socialQuotaMarkup(activeQuota,{compact:true})}${atLimit?'<button type="button" class="btn btn-ghost btn-sm" id="kx-social-manage-posts">Gestionar publicaciones</button>':''}`;
}

async function refreshActiveQuota(){const current=activeIdentity();activeQuota=current?await repos.kombaxSocial.quota(current.id).catch(()=>null):null;return activeQuota;}

function quickComposer(){
  const current=activeIdentity();
  if(!current)return '';
  return `<section class="kx-social-composer" id="kombax-social-feed-top">
    <div class="kx-social-composer-head"><div class="kombax-social-avatar">${profileAvatar(current)}</div><div><small>PUBLICAR EN KOMBAX</small><strong>${esc(identityLabel(current))}</strong></div></div>
    ${quotaAction()}
    <textarea id="kx-social-quick-text" maxlength="1500" rows="3" placeholder="Comparte una actualización, resultado, evento u oportunidad…" aria-label="Texto de la publicación"></textarea>
    <div class="kx-quick-audience"><label><span>Audiencia</span><select id="kx-social-quick-audience">${audienceSelectOptions(current.id)}</select></label><small>Público es la opción predeterminada.</small></div>
    <footer><span id="kx-social-quick-count">0/1500</span><div><button type="button" class="btn btn-ghost" id="kx-social-add-media">${icon('image',{size:17})} Foto / vídeo</button><button type="button" class="btn btn-primary" id="kx-social-quick-publish" disabled>${icon('arrowUpRight',{size:17})} Publicar</button></div></footer>
  </section>`;
}

function feedCards(){
  if(!posts.length)return `${empty('Todavía no hay publicaciones','Los clubes, miembros y perfiles KOMBAX autorizados pueden compartir aquí su actividad pública.')}${done?'':'<span id="kombax-social-sentinel" class="kx-feed-sentinel" aria-hidden="true"></span>'}`;
  return `<div class="kombax-social-feed">${posts.map(p=>`<article class="kombax-social-post">
    <header class="kx-social-author-open" data-social-profile-open="${esc(p.autor_id)}" tabindex="0" role="button" aria-label="Ver perfil público de ${esc(p.autor_nombre)}" title="Ver perfil público"><div class="kombax-social-avatar">${profileAvatar(p)}</div><div class="kx-social-author-copy"><strong>${esc(p.autor_nombre)} ${verified(p.autor_verificado,p.autor_tipo)}</strong><small>${esc(PUBLIC_TYPE_LABEL[p.autor_tipo]||PROFILE_LABEL[p.autor_tipo]||p.autor_tipo)} · ${dtFmt(p.creado_en)}</small>${affiliationChip(p)}<span class="kx-social-profile-cue">Ver perfil</span></div><div class="kx-post-badges">${audienceChip(p)}${badge(TYPE_LABEL[p.tipo]||p.tipo,p.tipo==='oportunidad'?'warn':'neutral')}</div><span class="kx-social-profile-arrow" aria-hidden="true">${icon('chevronRight',{size:16})}</span></header>
    <p>${esc(p.texto).replace(/\n/g,'<br>')}</p>${postMedia(p)}
    <footer>
      <button type="button" class="social-like ${p.liked_by_me?'active':''}" data-social-like="${esc(p.id)}" data-active="${p.liked_by_me?'true':'false'}">${icon('heart',{size:18})}<span>${Number(p.likes_count||0)}</span></button>
      <button type="button" class="${p.saved_by_me?'active':''}" data-social-save="${esc(p.id)}" data-active="${p.saved_by_me?'true':'false'}">${icon('archive',{size:17})} ${p.saved_by_me?'Guardado':'Guardar'}</button>
      <button type="button" data-social-comments="${esc(p.id)}" aria-expanded="${expandedCommentPostId===String(p.id)?'true':'false'}">${icon('message',{size:17})} <span data-social-comments-count="${esc(p.id)}">${Number(p.comentarios_count||0)}</span> comentarios</button>
      ${p.audiencia==='publica'?`<button type="button" data-social-share="${esc(p.id)}" data-social-share-text="${esc(`${p.autor_nombre}: ${p.texto}`)}">${icon('arrowUpRight',{size:17})} Compartir</button>`:''}
      ${p.contactable&&!isOwn(p.autor_id)?`<button type="button" data-social-contact="${esc(p.autor_id)}" data-social-name="${esc(p.autor_nombre)}">${icon('message',{size:17})} Contactar</button>`:''}
      ${!isOwn(p.autor_id)?`<button type="button" data-social-report-post="${esc(p.id)}">${icon('alert',{size:17})} Denunciar</button><button type="button" data-social-block="${esc(p.autor_id)}" data-social-name="${esc(p.autor_nombre)}">${icon('shield',{size:17})} Bloquear</button>`:`<button type="button" data-social-delete="${esc(p.id)}">${icon('trash',{size:17})} Eliminar</button>`}
    </footer>
    <section class="kx-inline-comments" data-kx-comments-panel="${esc(p.id)}" ${expandedCommentPostId===String(p.id)?'':'hidden'}><div class="loading-card">Cargando comentarios…</div></section>
  </article>`).join('')}</div>${done?'':'<div class="kx-feed-more"><button type="button" class="btn btn-ghost kombax-load-more" id="kombax-social-more">Cargar más</button><span id="kombax-social-sentinel" class="kx-feed-sentinel" aria-hidden="true"></span></div>'}`;
}

async function loadIdentityAlbum(profile){
  try{
    if(profile.sujeto_tipo==='club')return (await repos.clubPublic.album(profile.club_id)).filter(x=>x.estado==='active'&&['photo','video'].includes(x.tipo)).map(x=>({...x,_source_type:'club'}));
    if(profile.sujeto_tipo==='perfil_directo')return (await repos.kombaxProfiles.album(profile.perfil_directo_id)).filter(x=>x.estado==='active'&&['photo','video'].includes(x.tipo)).map(x=>({...x,_source_type:'perfil_directo'}));
    return (await repos.kombaxSocial.media(profile.id)).filter(x=>x.estado==='active'&&x.en_album&&['photo','video'].includes(x.tipo)).map(x=>({...x,_source_type:'social'}));
  }catch{return [];}
}

async function openPublisher(){
  if(!ownProfiles.length){toast('No tienes una identidad autorizada para publicar.','error');return;}
  const initial=activeIdentity()||ownProfiles[0];
  const initialQuota=await repos.kombaxSocial.quota(initial.id).catch(()=>null);
  if(initialQuota?.active_limit_reached){toast('Has alcanzado tus 30 publicaciones activas. Elimina una para poder publicar otra.','error');openKombaxPostManager(initial,{onChanged:async()=>{await refreshActiveQuota();await loadFeed(false);}});return;}
  if(initialQuota?.daily_limit_reached){toast('Has alcanzado el máximo de 3 publicaciones de hoy. Podrás volver a publicar mañana.','error');return;}
  const mediaByProfile=new Map();
  await Promise.all(ownProfiles.map(async profile=>mediaByProfile.set(profile.id,await loadIdentityAlbum(profile))));
  const modal=openForm({
    title:'Publicar en KOMBAX Social',
    subtitle:'Elige la identidad y la audiencia. Público es siempre la opción predeterminada; las restricciones se aplican solo a esta publicación.',
    width:'860px',
    fields:[
      {name:'autor',label:'Publicar como',type:'select',required:true,value:initial.id,options:ownProfiles.map(p=>({value:p.id,label:identityLabel(p)}))},
      {name:'tipo',label:'Tipo',type:'select',required:true,value:'actualizacion',options:Object.entries(TYPE_LABEL).map(([value,label])=>({value,label}))},
      {name:'comentarios_estado',label:'Comentarios',type:'select',required:true,value:'open',options:[{value:'open',label:'Abiertos'},{value:'verified_only',label:'Solo perfiles verificados'},{value:'closed',label:'Cerrados'}]},
      {name:'audiencia',label:'Audiencia',type:'select',required:true,value:audienceKey(audienceOptions(initial.id)[0]),options:audienceOptions(initial.id).map(a=>({value:audienceKey(a),label:a.label})),help:'El perfil seguirá siendo público. Esta opción solo restringe esta publicación.'},
      {name:'archivo',label:'Subir foto o vídeo',type:'file',accept:'image/jpeg,image/png,image/webp,video/mp4,video/webm,video/quicktime',full:true,help:'Opcional. Vídeos de máximo 15 segundos. Se mostrará únicamente a la audiencia elegida para esta publicación.'},
      {name:'guardar_album',label:'Guardar también este archivo en el álbum de la identidad',type:'checkbox',value:true,full:true},
      {name:'media_id',label:'O elegir del álbum',type:'select',options:[],full:true,help:'Si subes un archivo nuevo, tendrá prioridad sobre esta selección.'},
      {name:'texto',label:'Contenido',type:'textarea',required:true,full:true,rows:7,maxLength:1500,help:'Máximo 1.500 caracteres. No publiques teléfonos, direcciones ni datos privados de terceros.'}
    ],
    submitText:'Publicar',
    onSubmit:async v=>{
      const profile=ownProfiles.find(x=>x.id===v.autor);if(!profile)throw new Error('La identidad seleccionada ya no está disponible.');
      let socialMediaId=null,newSocialMedia=null,newClubMedia=null,newDirectMedia=null;
      const aud=parseAudience(v.audiencia);
      const restricted=aud.audiencia!=='publica';
      try{
        if(restricted&&(v.media_id||v.guardar_album===true))throw new Error('Las publicaciones restringidas no pueden reutilizar ni guardar multimedia en el álbum público. Sube un archivo nuevo o publica solo texto.');
        if(v.archivo){
          const mediaType=String(v.archivo.type||'').startsWith('video/')?'video':'photo';
          if(v.guardar_album===true&&profile.sujeto_tipo==='club'){
            newClubMedia=await repos.clubPublic.uploadAlbumMedia(profile.club_id,mediaType,v.archivo);
            newSocialMedia=await repos.kombaxSocial.attachAlbumMedia(profile.id,'club',newClubMedia.id);socialMediaId=newSocialMedia.id;
          }else if(v.guardar_album===true&&profile.sujeto_tipo==='perfil_directo'){
            newDirectMedia=await repos.kombaxProfiles.uploadMedia(profile.perfil_directo_id,mediaType,v.archivo);
            newSocialMedia=await repos.kombaxSocial.attachAlbumMedia(profile.id,'perfil_directo',newDirectMedia.id);socialMediaId=newSocialMedia.id;
          }else{
            newSocialMedia=await repos.kombaxSocial.uploadMedia(profile.id,mediaType,v.archivo,{enAlbum:v.guardar_album===true,audience:aud.audiencia});socialMediaId=newSocialMedia.id;
          }
        }else if(v.media_id){
          const source=(mediaByProfile.get(profile.id)||[]).find(x=>String(x.id)===String(v.media_id));
          if(source){
            if(source._source_type==='social')socialMediaId=source.id;
            else{
              const alreadyAttached=(await repos.kombaxSocial.media(profile.id)).find(x=>x.estado==='active'&&x.storage_path===source.storage_path);
              if(alreadyAttached)socialMediaId=alreadyAttached.id;
              else{newSocialMedia=await repos.kombaxSocial.attachAlbumMedia(profile.id,source._source_type,source.id);socialMediaId=newSocialMedia.id;}
            }
          }
        }
        await repos.kombaxSocial.publish(profile.id,v.tipo,v.texto,{comentarios_estado:v.comentarios_estado,social_media_id:socialMediaId,...aud});
      }catch(error){
        if(newSocialMedia)await repos.kombaxSocial.removeMedia(newSocialMedia).catch(()=>{});
        if(newClubMedia)await repos.clubPublic.removeAlbumMedia(profile.club_id,newClubMedia).catch(()=>{});
        if(newDirectMedia)await repos.kombaxProfiles.removeMedia(newDirectMedia).catch(()=>{});
        throw error;
      }
      setActiveIdentity(profile.id);activeIdentityId=profile.id;toast(`Publicado como ${profile.nombre_publico}`);await refreshActiveQuota();await loadFeed(false);
    }
  });
  const author=modal.form.elements.autor,media=modal.form.elements.media_id,audience=modal.form.elements.audiencia,album=modal.form.elements.guardar_album;
  const refreshAudience=()=>{const rows=audienceOptions(author.value);audience.innerHTML=rows.map(a=>`<option value="${esc(audienceKey(a))}">${esc(a.label)}</option>`).join('');audience.value=audienceKey(rows[0]);};
  const refreshMedia=()=>{const rows=mediaByProfile.get(author.value)||[];const restricted=parseAudience(audience.value).audiencia!=='publica';media.innerHTML='<option value="">Sin multimedia del álbum</option>'+rows.map(x=>`<option value="${esc(x.id)}">${x.tipo==='video'?'Vídeo':'Foto'}${x.tipo==='video'?` · ${Number(x.duration_seconds||0).toFixed(1)} s`:''}</option>`).join('');media.disabled=restricted||!rows.length;if(restricted){media.value='';album.checked=false;album.disabled=true;}else album.disabled=false;};
  author.addEventListener('change',()=>{refreshAudience();refreshMedia();});audience.addEventListener('change',refreshMedia);refreshAudience();refreshMedia();
}

async function activateSocial(){
  let rules=null;try{rules=await repos.socialGeneral.rules();}catch{}
  const {wrap}=openDetail({title:'Activar KOMBAX Social',subtitle:`Normas ${esc(rules?.version||'1.1.0')} · Perfil público opcional`,body:`<div class="legal-document"><p>${esc(rules?.cuerpo||'Lee y acepta las normas de KOMBAX Social.').replace(/\n\n/g,'</p><p>').replace(/\n/g,'<br>')}</p></div><label class="kombax-social-consent"><input type="checkbox" id="social-rules-ok"> <span>He leído y acepto las normas.</span></label><label class="kombax-social-consent"><input type="checkbox" id="social-privacy-ok"> <span>Entiendo que se crea una identidad pública separada de mi expediente privado.</span></label>`,actions:'<button type="button" class="btn btn-primary" id="social-activate-confirm">Activar perfil</button>',width:'820px'});
  wrap.querySelector('#social-activate-confirm')?.addEventListener('click',async()=>{const button=wrap.querySelector('#social-activate-confirm');if(!wrap.querySelector('#social-rules-ok')?.checked||!wrap.querySelector('#social-privacy-ok')?.checked){toast('Debes aceptar ambas condiciones.','error');return;}button.disabled=true;try{const consent={acepta_normas:true,acepta_privacidad:true};if(socialStatus?.scope==='global'&&socialStatus?.direct_profile_id)await repos.kombaxSocial.activateDirect(socialStatus.direct_profile_id,consent);else await repos.kombaxIdentity.activateMember(consent);closeModal();toast('Perfil KOMBAX Social activado');await renderKombaxSocial();}catch(error){button.disabled=false;setError(error);}});
}

async function openContact(targetId,targetName){
  const senders=ownProfiles.filter(p=>p.contacto_habilitado);const preferred=activeIdentity();if(preferred){senders.sort((a,b)=>a.id===preferred.id?-1:b.id===preferred.id?1:0);}
  if(!senders.length){toast('No tienes un perfil habilitado para contacto. Los perfiles personales menores de 18 años no pueden usar esta función.','error');return;}
  try{
    const existing=(await repos.kombaxSocial.contacts()).find(c=>{
      if(String(c.canal||'social')!=='social')return false;
      const mine=senders.some(p=>String(p.id)===String(c.remitente_id)||String(p.id)===String(c.destinatario_id));
      const other=String(c.remitente_id)===String(targetId)||String(c.destinatario_id)===String(targetId);
      return mine&&other&&['pendiente','aceptada'].includes(String(c.estado));
    });
    if(existing){
      if(existing.estado==='aceptada')toast('Ya tenéis un chat abierto.');
      else toast('La solicitud de contacto sigue pendiente.');
      await openContactThread(existing);return;
    }
  }catch{}
  openForm({title:`Contactar con ${targetName}`,subtitle:'Indica el motivo y un primer mensaje. La otra persona debe aceptar la solicitud antes de que se habilite el chat.',fields:[{name:'remitente',label:'Enviar como',type:'select',required:true,value:senders[0].id,options:senders.map(p=>({value:p.id,label:p.nombre_publico}))},{name:'motivo',label:'Motivo',type:'select',required:true,value:'informacion',options:Object.entries(CONTACT_LABEL).map(([value,label])=>({value,label}))},{name:'mensaje',label:'Primer mensaje',type:'textarea',required:true,full:true,rows:5,minLength:10,maxLength:500,help:'Entre 10 y 500 caracteres. Se enviará junto a la solicitud. No admite imágenes, vídeos, audios ni archivos.'}],submitText:'Enviar solicitud',onSubmit:async v=>{await repos.kombaxSocial.contact(v.remitente,targetId,v.motivo,v.mensaje);toast('Solicitud de contacto enviada');activeView='contacts';await renderKombaxSocial();}});
}

async function openContactThread(contact){
  let current=contact,disposed=false,syncing=false,syncPoller=null,lastMetaSyncAt=0;
  let messages=[],olderAvailable=false,lastOrdinal=0;
  const PAGE=30;
  const senderFor=()=>ownProfiles.find(p=>p.id===current.remitente_id||p.id===current.destinatario_id)||null;
  const otherName=()=>{const sender=senderFor();if(!sender)return `${current.remitente_nombre} ↔ ${current.destinatario_nombre}`;return sender.id===current.remitente_id?current.destinatario_nombre:current.remitente_nombre;};
  const isShowcase=()=>String(current.canal||'social')==='showcase';
  const modal=openDetail({title:`${isShowcase()?'Showcase':'Chat KOMBAX'} · ${otherName()}`,subtitle:isShowcase()?`${current.showcase_marca_nombre||'KOMBAX Showcase'} · conversación vinculada al producto`:`${CONTACT_LABEL[current.motivo]||current.motivo} · mensajería Social`,body:'<div id="kx-contact-thread-root"><div class="loading-card">Cargando conversación…</div></div>',actions:'<button type="button" class="btn btn-danger" id="kx-contact-delete-thread">Eliminar conversación</button>',width:'760px',className:`kx-contact-thread-modal ${isShowcase()?'kx-showcase-thread-modal':'kx-social-thread-modal'}`});
  const root=modal.wrap.querySelector('#kx-contact-thread-root');
  const refreshMeta=async()=>{const all=await repos.kombaxSocial.contacts();current=all.find(x=>String(x.id)===String(current.id))||current;return current;};
  const receiptState=m=>m?.leido_en?{state:'read',label:'✓✓ Leído',title:`Leído ${dtFmt(m.leido_en)}`}:{state:'sent',label:'✓ Enviado',title:'Enviado'};
  const receiptHtml=m=>{if(!m.propio)return '';const r=receiptState(m);return `<span class="kx-contact-message-status" data-read-state="${r.state}" title="${esc(r.title)}" aria-label="${esc(r.title)}">${r.label}</span>`;};
  const msgHtml=m=>`<article class="kx-contact-message ${m.propio?'own':'other'}" data-message-id="${esc(m.id)}" data-ordinal="${Number(m.ordinal)||0}"><small>${esc(m.autor_nombre)} · ${dtFmt(m.creado_en)}</small><p>${esc(m.texto).replace(/\n/g,'<br>')}</p>${receiptHtml(m)}</article>`;
  const updateReceiptDom=m=>{if(!m?.propio)return;const article=[...root.querySelectorAll('.kx-contact-message[data-message-id]')].find(el=>el.dataset.messageId===String(m.id));const status=article?.querySelector('.kx-contact-message-status');if(!status)return;const r=receiptState(m);status.dataset.readState=r.state;status.textContent=r.label;status.title=r.title;status.setAttribute('aria-label',r.title);};
  const syncState=(text,kind='ok')=>{const el=root.querySelector('#kx-chat-sync-state');if(el){el.textContent=text;el.dataset.state=kind;}};
  const cleanup=()=>{if(disposed)return;disposed=true;syncPoller?.stop();syncPoller=null;};
  const ensureAlive=()=>{if(!root.isConnected){cleanup();return false;}return true;};
  const bindComposer=()=>{
    const sender=senderFor(),send=root.querySelector('#kx-contact-send'),area=root.querySelector('#kx-contact-message-text');
    const submit=async()=>{const text=area?.value.trim()||'';if(!text){toast('Escribe un mensaje.','error');return;}if(!sender||!send)return;send.disabled=true;area.disabled=true;try{await repos.kombaxSocial.sendContactMessage(current.id,sender.id,text);area.value='';syncPoller?.markActive();syncState('Mensaje enviado · sincronizando','sync');await syncNew(true);}catch(error){setError(error);}finally{if(send.isConnected)send.disabled=false;if(area?.isConnected){area.disabled=false;area.focus();}}};
    send?.addEventListener('click',submit);
    area?.addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.shiftKey&&!e.isComposing){e.preventDefault();submit();}});
  };
  const renderThread=(scrollBottom=false)=>{
    if(!ensureAlive())return;
    const sender=senderFor();const chatOpen=current.estado==='aceptada'&&!!sender&&current.puede_chat!==false;
    const product=isShowcase()?`<section class="kx-showcase-chat-product">${current.showcase_producto_imagen_url?`<img src="${esc(current.showcase_producto_imagen_url)}" alt="${esc(current.showcase_producto_nombre||'Producto Showcase')}">`:`<div class="kx-showcase-chat-product-fallback">${icon('shoppingBag',{size:24})}</div>`}<div><small>CONVERSACIÓN SHOWCASE</small><strong>${esc(current.showcase_producto_nombre||'Producto Showcase')}</strong><span>${esc(current.showcase_marca_nombre||'KOMBAX Showcase')}</span></div></section>`:'';
    root.innerHTML=`<section class="kx-contact-thread ${isShowcase()?'showcase-channel':'social-channel'}">${product}<header><div><span class="page-kicker">${isShowcase()?'SHOWCASE':esc(String(current.estado||'').toUpperCase())} · ${esc(isShowcase()?'Consulta de producto':CONTACT_LABEL[current.motivo]||current.motivo)}</span><strong>${esc(current.remitente_nombre)} ↔ ${esc(current.destinatario_nombre)}</strong></div><span class="kx-chat-live-state" id="kx-chat-sync-state" data-state="ok">Actualización automática</span></header>${olderAvailable?'<div class="kx-chat-history"><button type="button" class="btn btn-ghost btn-sm" id="kx-contact-load-older">Cargar mensajes anteriores</button></div>':''}<div class="kx-contact-message-list">${messages.map(msgHtml).join('')}</div>${chatOpen?`<div class="kx-contact-composer"><textarea id="kx-contact-message-text" maxlength="500" rows="3" placeholder="Escribe un mensaje…" aria-label="Mensaje de chat KOMBAX"></textarea><div><small>Enter para enviar · Shift+Enter para salto de línea</small><button type="button" class="btn btn-primary" id="kx-contact-send">Enviar</button></div></div>`:`<div class="kx-contact-closed">${current.estado==='pendiente'?'Solicitud pendiente. El chat se habilitará cuando la otra persona la acepte.':current.estado==='rechazada'?'La solicitud fue rechazada.':'Esta conversación ya no admite nuevos mensajes.'}</div>`}</section>`;
    bindComposer();
    root.querySelector('#kx-contact-load-older')?.addEventListener('click',loadOlder);
    const list=root.querySelector('.kx-contact-message-list');if(list&&scrollBottom)list.scrollTop=list.scrollHeight;
  };
  const loadOlder=async()=>{
    const button=root.querySelector('#kx-contact-load-older');if(button)button.disabled=true;
    const before=messages.length?Math.min(...messages.map(m=>Number(m.ordinal)||Number.MAX_SAFE_INTEGER)):null;
    if(!before){olderAvailable=false;renderThread(false);return;}
    try{
      const rows=await repos.kombaxSocial.contactMessages(current.id,{before,limit:PAGE});
      const known=new Set(messages.map(m=>String(m.id)));const fresh=rows.filter(m=>!known.has(String(m.id)));
      const list=root.querySelector('.kx-contact-message-list'),oldHeight=list?.scrollHeight||0,oldTop=list?.scrollTop||0;
      messages=[...fresh,...messages].sort((a,b)=>Number(a.ordinal)-Number(b.ordinal));
      olderAvailable=rows.length?rows[0].older_available===true:false;
      renderThread(false);
      const next=root.querySelector('.kx-contact-message-list');if(next)next.scrollTop=oldTop+(next.scrollHeight-oldHeight);
    }catch(error){if(button?.isConnected)button.disabled=false;toast(humanError(error)||'No se pudieron cargar mensajes anteriores.','error');}
  };
  const appendRows=async rows=>{
    if(!rows?.length||!ensureAlive())return 0;
    const known=new Set(messages.map(m=>String(m.id)));const fresh=rows.filter(m=>!known.has(String(m.id))).sort((a,b)=>Number(a.ordinal)-Number(b.ordinal));
    if(!fresh.length)return 0;
    const list=root.querySelector('.kx-contact-message-list');if(!list)return;
    const nearBottom=list.scrollHeight-list.scrollTop-list.clientHeight<120;
    fresh.forEach(m=>list.insertAdjacentHTML('beforeend',msgHtml(m)));
    messages.push(...fresh);messages.sort((a,b)=>Number(a.ordinal)-Number(b.ordinal));
    lastOrdinal=Math.max(lastOrdinal,...fresh.map(m=>Number(m.ordinal)||0));
    await repos.kombaxSocial.markContactRead(current.id).catch(()=>{});
    if(nearBottom||fresh.some(m=>m.propio))list.scrollTop=list.scrollHeight;
    return fresh.length;
  };
  const syncReadReceipts=async()=>{
    const rows=await repos.kombaxSocial.contactMessages(current.id,{limit:PAGE});
    if(!rows?.length)return 0;
    const latest=new Map(rows.map(m=>[String(m.id),m]));let changed=0;
    messages=messages.map(m=>{
      const fresh=latest.get(String(m.id));
      if(!fresh||String(fresh.leido_en||'')===String(m.leido_en||''))return m;
      const next={...m,leido_en:fresh.leido_en};changed++;updateReceiptDom(next);return next;
    });
    return changed;
  };
  const syncNew=async(force=false)=>{
    if(!ensureAlive()||syncing||(!force&&document.visibilityState==='hidden'))return 'idle';
    syncing=true;let ok=true,activity=false;
    try{
      let rounds=0;
      while(rounds<10){
        const rows=await repos.kombaxSocial.contactMessages(current.id,{after:lastOrdinal,limit:50});
        if(!rows.length)break;
        const appended=await appendRows(rows);if(appended>0)activity=true;rounds++;
        if(rows.length<50)break;
      }
      const now=Date.now();
      if(force||now-lastMetaSyncAt>=12000){
        lastMetaSyncAt=now;
        if(await syncReadReceipts()>0)activity=true;
        const beforeState=String(current.estado);await refreshMeta();
        if(beforeState!==String(current.estado)){activity=true;renderThread(true);}
      }
      syncState(activity?'Actividad sincronizada':'Actualización automática','ok');
    }catch(error){ok=false;syncState(navigator.onLine?'Reintentando sincronización…':'Sin conexión · reintentando','warn');}
    finally{syncing=false;}
    return ok?(activity?true:'idle'):false;
  };
  const loadInitial=async()=>{
    try{
      await repos.kombaxSocial.markContactRead(current.id).catch(()=>{});await refreshMeta();
      const rows=await repos.kombaxSocial.contactMessages(current.id,{limit:PAGE});
      messages=rows.slice().sort((a,b)=>Number(a.ordinal)-Number(b.ordinal));
      olderAvailable=rows.length?rows[0].older_available===true:false;
      lastOrdinal=messages.reduce((max,m)=>Math.max(max,Number(m.ordinal)||0),0);
      renderThread(true);
    }catch(error){root.innerHTML=empty('No se pudo abrir el chat',humanError(error)||'Revisa la conexión.');}
  };
  syncPoller=createAdaptivePoller(()=>syncNew(false),{activeMs:2500,hiddenMs:0,maxMs:30000,idleMaxMs:30000,idleAfter:2,jitterRatio:.18});
  syncPoller.start({immediate:false});
  modal.wrap.querySelector('#modal-close')?.addEventListener('click',cleanup);
  modal.wrap.addEventListener('click',e=>{if(e.target===modal.wrap)cleanup();});
  modal.wrap.querySelector('#kx-contact-delete-thread')?.addEventListener('click',()=>{const actor=senderFor();if(!actor){toast('No se puede identificar la copia de esta conversación.','error');return;}confirmDialog('Eliminar conversación','Desaparecerá de esta identidad y el hilo quedará cerrado. La otra persona conservará su copia hasta que también la elimine.',async()=>{await repos.kombaxSocial.deleteContact(current.id,actor.id);toast('Conversación eliminada de tu bandeja');cleanup();modal.close();await renderContacts();},{confirmText:'Eliminar conversación',danger:true});});
  await loadInitial();
}

function openReport(type,id){
  openForm({title:'Denunciar en KOMBAX Social',subtitle:'La denuncia será revisada por moderación global.',fields:[{name:'motivo',label:'Motivo',type:'select',required:true,value:'spam',options:[{value:'acoso',label:'Acoso'},{value:'odio_discriminacion',label:'Odio o discriminación'},{value:'violencia',label:'Violencia ilícita'},{value:'sexual_menores',label:'Riesgo o sexualización de menores'},{value:'privacidad',label:'Privacidad'},{value:'spam',label:'Spam'},{value:'suplantacion',label:'Suplantación'},{value:'otro',label:'Otro'}]},{name:'detalle',label:'Contexto',type:'textarea',full:true,rows:4,maxLength:1500}],submitText:'Enviar denuncia',onSubmit:async v=>{await repos.kombaxSocial.report(type,id,v.motivo,v.detalle||'');toast('Denuncia enviada');}});
}

async function renderInlineComments(postId,replyParentId=null){
  const panel=document.querySelector(`[data-kx-comments-panel="${CSS.escape(String(postId))}"]`);if(!panel)return;
  const post=posts.find(x=>String(x.id)===String(postId))||{id:postId,comentarios_estado:'open'};
  panel.hidden=false;panel.innerHTML='<div class="loading-card">Cargando comentarios…</div>';
  document.querySelectorAll('[data-social-comments]').forEach(b=>b.setAttribute('aria-expanded',String(String(b.dataset.socialComments)===String(postId))));
  try{
    const rows=await repos.kombaxSocial.comments(postId,160);
    const count=document.querySelector(`[data-social-comments-count="${CSS.escape(String(postId))}"]`);if(count)count.textContent=String(rows.length);
    const replies=new Map();rows.filter(x=>x.parent_id).forEach(x=>{const arr=replies.get(x.parent_id)||[];arr.push(x);replies.set(x.parent_id,arr);});
    const roots=rows.filter(x=>!x.parent_id);
    const replyTarget=replyParentId?rows.find(x=>String(x.id)===String(replyParentId)):null;
    const allowedProfiles=post.comentarios_estado==='verified_only'?ownProfiles.filter(p=>p.verificado===true):ownProfiles;
    const one=c=>`<article class="kx-comment ${c.parent_id?'reply':''}"><button type="button" class="kombax-social-avatar kx-comment-author-open" data-social-profile-open="${esc(c.autor_id)}" aria-label="Ver perfil público de ${esc(c.autor_nombre)}">${c.autor_avatar_url||c.autor_avatar_path?`<img src="${esc(c.autor_avatar_url||mediaUrl(c.autor_avatar_path))}" alt="">`:`<span>${esc(initials(c.autor_nombre))}</span>`}</button><div><header><button type="button" class="kx-comment-author-name" data-social-profile-open="${esc(c.autor_id)}">${esc(c.autor_nombre)} ${verified(c.autor_verificado,c.autor_tipo)}</button><small>${dtFmt(c.creado_en)}</small></header><p>${esc(c.texto)}</p><footer>${!c.parent_id&&post.comentarios_estado!=='closed'&&allowedProfiles.length?`<button class="btn btn-ghost btn-sm" data-kx-reply="${esc(c.id)}">Responder</button>`:''}${c.propio?`<button class="btn btn-ghost btn-sm" data-kx-comment-remove="${esc(c.id)}">Eliminar</button>`:`<button class="btn btn-ghost btn-sm" data-kx-comment-report="${esc(c.id)}">${icon('alert',{size:14})} Denunciar</button>`}</footer></div></article>`;
    const body=roots.map(c=>`${one(c)}${(replies.get(c.id)||[]).map(one).join('')}`).join('')||'<div class="empty"><strong>Sin comentarios</strong><p>Sé el primero en participar respetando las normas.</p></div>';
    let composer='';
    if(post.comentarios_estado==='closed')composer='<div class="kx-inline-comment-locked">Comentarios cerrados por el autor.</div>';
    else if(!allowedProfiles.length)composer=`<div class="kx-inline-comment-locked">${post.comentarios_estado==='verified_only'?'Esta publicación solo admite comentarios de perfiles verificados.':'Necesitas un perfil autorizado para comentar.'}</div>`;
    else composer=`<form class="kx-inline-comment-composer" data-kx-comment-form="${esc(postId)}" data-parent-id="${esc(replyParentId||'')}"><div class="kx-inline-comment-context">${replyTarget?`<span>Respondiendo a <strong>${esc(replyTarget.autor_nombre)}</strong></span><button type="button" class="btn btn-ghost btn-sm" data-kx-reply-cancel>Cancelar respuesta</button>`:'<span>Escribe un comentario en esta publicación</span>'}</div><div class="kx-inline-comment-controls"><select name="autor" aria-label="Comentar como">${allowedProfiles.map(x=>`<option value="${esc(x.id)}" ${x.id===(activeIdentity()?.id||allowedProfiles[0]?.id)?'selected':''}>${esc(x.nombre_publico)}</option>`).join('')}</select><textarea name="texto" maxlength="800" rows="2" required placeholder="${replyTarget?'Escribe tu respuesta…':'Escribe un comentario…'}" aria-label="Comentario"></textarea><button type="submit" class="btn btn-primary">${replyTarget?'Responder':'Enviar'}</button></div><small>Máximo 800 caracteres.</small></form>`;
    panel.innerHTML=`<div class="kx-inline-comments-head"><strong>Comentarios</strong><button type="button" class="btn btn-ghost btn-sm" data-kx-comments-collapse>Cerrar</button></div><div class="kx-comments">${body}</div>${composer}`;
    panel.querySelector('[data-kx-comments-collapse]')?.addEventListener('click',()=>toggleInlineComments(postId));
    panel.querySelectorAll('[data-social-profile-open]').forEach(el=>el.addEventListener('click',()=>openKombaxPublicProfile(el.dataset.socialProfileOpen).catch(setError)));
    panel.querySelectorAll('[data-kx-reply]').forEach(b=>b.addEventListener('click',()=>renderInlineComments(postId,b.dataset.kxReply)));
    panel.querySelector('[data-kx-reply-cancel]')?.addEventListener('click',()=>renderInlineComments(postId,null));
    panel.querySelectorAll('[data-kx-comment-report]').forEach(b=>b.addEventListener('click',()=>openReport('comentario',b.dataset.kxCommentReport)));
    panel.querySelectorAll('[data-kx-comment-remove]').forEach(b=>b.addEventListener('click',()=>confirmDialog('Eliminar comentario','Se retirará del contenido visible conservando trazabilidad.',async()=>{await repos.kombaxSocial.removeComment(b.dataset.kxCommentRemove);toast('Comentario retirado');await renderInlineComments(postId,null);},{confirmText:'Eliminar',danger:true})));
    panel.querySelector('[data-kx-comment-form]')?.addEventListener('submit',async e=>{e.preventDefault();const form=e.currentTarget,button=form.querySelector('button[type="submit"]'),text=String(form.elements.texto?.value||'').trim(),author=form.elements.autor?.value;if(!text||!author)return;button.disabled=true;try{await repos.kombaxSocial.comment(postId,author,text,form.dataset.parentId||null);toast(form.dataset.parentId?'Respuesta publicada':'Comentario publicado');await renderInlineComments(postId,null);}catch(error){button.disabled=false;setError(error);}});
  }catch(error){panel.innerHTML=empty('No se pudieron cargar los comentarios',humanError(error)||'Revisa la conexión.');}
}

function toggleInlineComments(postId){
  const id=String(postId||'');
  if(expandedCommentPostId===id){const panel=document.querySelector(`[data-kx-comments-panel="${CSS.escape(id)}"]`);if(panel)panel.hidden=true;document.querySelector(`[data-social-comments="${CSS.escape(id)}"]`)?.setAttribute('aria-expanded','false');expandedCommentPostId='';return;}
  const previous=expandedCommentPostId;expandedCommentPostId=id;
  if(previous){const old=document.querySelector(`[data-kx-comments-panel="${CSS.escape(previous)}"]`);if(old)old.hidden=true;document.querySelector(`[data-social-comments="${CSS.escape(previous)}"]`)?.setAttribute('aria-expanded','false');}
  renderInlineComments(id,null).catch(setError);
}

async function shareSocial(button){
  const text=button.dataset.socialShareText||'KOMBAX Social';
  const url=`${location.origin}${location.pathname}#social`;
  try{
    if(navigator.share)await navigator.share({title:'KOMBAX Social',text,url});
    else if(navigator.clipboard){await navigator.clipboard.writeText(`${text}\n${url}`);toast('Enlace copiado');}
    else toast('Comparte la URL de KOMBAX Social desde el navegador.');
  }catch(error){if(error?.name!=='AbortError')setError(error);}
}

const RELATION_LABEL={
  competidor_club:'Competidor ↔ Club',club_federacion:'Club ↔ Federación',competidor_profesional:'Competidor ↔ Profesional',
  marca_club:'Marca ↔ Club',marca_competidor:'Marca ↔ Competidor',profesional_club:'Profesional ↔ Club',profesional_evento:'Profesional ↔ Evento'
};

function possibleRelations(fromType,toType){
  const pair=new Set([fromType,toType]);
  const out=[];
  if(pair.has('competidor')&&pair.has('club'))out.push('competidor_club');
  if(pair.has('club')&&pair.has('federacion'))out.push('club_federacion');
  if(pair.has('competidor')&&pair.has('profesional'))out.push('competidor_profesional');
  if(pair.has('marca')&&pair.has('club'))out.push('marca_club');
  if(pair.has('marca')&&pair.has('competidor'))out.push('marca_competidor');
  if(pair.has('profesional')&&pair.has('club'))out.push('profesional_club');
  return out;
}

function requestRelation(target){
  const senders=ownProfiles.filter(x=>x.id!==target.id);
  if(!senders.length){toast('No tienes un perfil autorizado para añadir a esta persona a tu red.','error');return;}
  const modal=openForm({title:`Añadir a mi red · ${target.nombre_publico}`,subtitle:'Área privada: la otra parte debe aceptar. Ni tu red ni su tamaño se muestran públicamente.',fields:[
    {name:'origen',label:'Solicitar como',type:'select',required:true,value:senders[0].id,options:senders.map(x=>({value:x.id,label:x.nombre_publico}))},
    {name:'tipo',label:'Tipo de vínculo',type:'select',required:true,options:[]},
    {name:'nota',label:'Contexto',type:'textarea',full:true,rows:3,maxLength:500}
  ],submitText:'Añadir a mi red',onSubmit:async v=>{await repos.kombaxSocial.requestRelation(v.origen,target.id,v.tipo,v.nota||'');toast('Solicitud enviada a tu red');}});
  const source=modal.form.elements.origen,type=modal.form.elements.tipo;
  const fill=()=>{
    const from=ownProfiles.find(x=>x.id===source.value);
    const fromType=from?.perfil_tipo||from?.sujeto_tipo||'';
    const choices=possibleRelations(fromType,target.perfil_tipo||target.sujeto_tipo);
    type.innerHTML='<option value="">Selecciona</option>'+choices.map(x=>`<option value="${esc(x)}">${esc(RELATION_LABEL[x]||x)}</option>`).join('');
    type.disabled=!choices.length;
  };
  source.addEventListener('change',fill);fill();
}

function bindQuickComposer(){
  const input=document.getElementById('kx-social-quick-text');
  const button=document.getElementById('kx-social-quick-publish');
  const count=document.getElementById('kx-social-quick-count');
  const update=()=>{const text=String(input?.value||'');if(count)count.textContent=`${text.length}/1500`;const blocked=activeQuota?.active_limit_reached===true||activeQuota?.daily_limit_reached===true;if(button)button.disabled=!text.trim()||loading||blocked;};
  input?.addEventListener('input',update);update();
  document.getElementById('kx-social-add-media')?.addEventListener('click',openPublisher);
  document.getElementById('kx-social-manage-posts')?.addEventListener('click',()=>{const profile=activeIdentity();if(profile)openKombaxPostManager(profile,{onChanged:async()=>{await refreshActiveQuota();await loadFeed(false);}});});
  button?.addEventListener('click',async()=>{
    const profile=activeIdentity();const text=String(input?.value||'').trim();
    if(!profile||!text||button.disabled)return;
    button.disabled=true;const original=button.innerHTML;button.textContent='Publicando…';
    try{const aud=parseAudience(document.getElementById('kx-social-quick-audience')?.value);await repos.kombaxSocial.publish(profile.id,'actualizacion',text,{comentarios_estado:'open',...aud});input.value='';toast(`Publicado como ${profile.nombre_publico}`);await refreshActiveQuota();update();await loadFeed(false);document.getElementById('kombax-social-feed-top')?.scrollIntoView({behavior:'smooth',block:'start'});}
    catch(error){const msg=String(humanError(error)||'');if(msg.includes('KOMBAX_POST_ACTIVE_LIMIT_30')){toast('Has alcanzado tus 30 publicaciones activas. Elimina una para poder publicar otra.','error');openKombaxPostManager(profile,{onChanged:async()=>{await refreshActiveQuota();await loadFeed(false);}});}else if(msg.includes('KOMBAX_POST_DAILY_LIMIT_3'))toast('Has alcanzado el máximo de 3 publicaciones de hoy. Podrás volver a publicar mañana.','error');else{setError(error);toast(msg||'No se pudo publicar.','error');}}
    finally{if(button){button.innerHTML=original;update();}}
  });
}

function bindCommon(){
  document.querySelectorAll('[data-social-view]').forEach(b=>b.addEventListener('click',()=>{activeView=b.dataset.socialView;renderKombaxSocial();}));
  document.getElementById('kombax-social-publish')?.addEventListener('click',openPublisher);
  document.getElementById('kombax-social-activate')?.addEventListener('click',activateSocial);
  document.getElementById('kx-active-identity')?.addEventListener('change',e=>{activeIdentityId=e.target.value;setActiveIdentity(activeIdentityId);renderKombaxSocial();});
}

function bindFeed(){
  document.querySelectorAll('[data-social-profile-open]').forEach(el=>{const open=()=>openKombaxPublicProfile(el.dataset.socialProfileOpen);el.addEventListener('click',e=>{if(e.target.closest('button,a')&&e.currentTarget!==e.target)return;open();});el.addEventListener('keydown',e=>{if((e.key==='Enter'||e.key===' ')&&!e.target.closest('button,a')){e.preventDefault();open();}});});
  document.querySelectorAll('[data-social-affiliation-club]').forEach(b=>b.addEventListener('click',e=>{e.stopPropagation();openKombaxPublicProfile(b.dataset.socialAffiliationClub);}));
  document.querySelectorAll('[data-social-like]').forEach(b=>b.addEventListener('click',async()=>{if(b.disabled)return;b.disabled=true;const active=b.dataset.active==='true';try{await repos.kombaxSocial.like(b.dataset.socialLike,!active);await loadFeed(false);}catch(error){b.disabled=false;setError(error);}}));
  document.querySelectorAll('[data-social-save]').forEach(b=>b.addEventListener('click',async()=>{if(b.disabled)return;b.disabled=true;const active=b.dataset.active==='true';try{await repos.kombaxSocial.save(b.dataset.socialSave,!active);await loadFeed(false);}catch(error){b.disabled=false;setError(error);}}));
  document.querySelectorAll('[data-social-comments]').forEach(b=>b.addEventListener('click',()=>toggleInlineComments(b.dataset.socialComments)));
  document.querySelectorAll('[data-social-share]').forEach(b=>b.addEventListener('click',()=>shareSocial(b)));
  document.querySelectorAll('[data-social-contact]').forEach(b=>b.addEventListener('click',()=>openContact(b.dataset.socialContact,b.dataset.socialName)));
  document.querySelectorAll('[data-social-report-post]').forEach(b=>b.addEventListener('click',()=>openReport('publicacion',b.dataset.socialReportPost)));
  document.querySelectorAll('[data-social-block]').forEach(b=>b.addEventListener('click',()=>confirmDialog('Bloquear perfil',`Dejarás de ver el contenido de ${b.dataset.socialName}.`,async()=>{await repos.kombaxSocial.block(b.dataset.socialBlock,true);toast('Perfil bloqueado');await loadFeed(false);},{confirmText:'Bloquear',danger:true})));
  document.querySelectorAll('[data-social-delete]').forEach(b=>b.addEventListener('click',()=>confirmDialog('Eliminar publicación','Se eliminarán la publicación y sus interacciones. Si la foto o vídeo fue subido solo para esta publicación y no pertenece al álbum, también se eliminará del almacenamiento.',async()=>{await repos.kombaxSocial.deletePost(b.dataset.socialDelete);toast('Publicación eliminada');await loadFeed(false);},{confirmText:'Eliminar definitivamente',danger:true})));
  document.getElementById('kombax-social-more')?.addEventListener('click',()=>loadFeed(true));
  feedObserver?.disconnect?.();feedObserver=null;
  const sentinel=document.getElementById('kombax-social-sentinel');
  if(sentinel&&!done&&'IntersectionObserver' in window){feedObserver=new IntersectionObserver(entries=>{if(entries.some(x=>x.isIntersecting)&&!loading&&!done)loadFeed(true);},{rootMargin:'700px 0px'});feedObserver.observe(sentinel);}
  bindQuickComposer();
  if(expandedCommentPostId)renderInlineComments(expandedCommentPostId,null).catch(setError);
}

async function loadFeed(append=false){
  if(loading)return;loading=true;
  try{
    if(!append){posts=[];cursor=null;done=false;await refreshActiveQuota();}
    const raw=await repos.kombaxSocial.feed(cursor,PAGE_SIZE);
    const page=await Promise.all((raw||[]).map(async p=>{if(!p.media_path)return p;try{return {...p,media_url:await repos.kombaxSocial.mediaAccessUrl(p.media_path,p.media_bucket||'kombax-public-media')}}catch{return {...p,media_url:''}}}));
    posts=append?[...posts,...page]:page;
    const last=page.at(-1);if(last)cursor={created:last.creado_en,id:last.id};done=page.length<PAGE_SIZE;
    renderFeedView();
  }catch(error){setError(error);setMainHtml(`${socialHeader()}${pageHeader('KOMBAX Social','No se pudo cargar KOMBAX Social.','','Red profesional global')}<section class="card">${empty('KOMBAX Social no disponible',humanError(error)||'Inténtalo de nuevo. Si el problema continúa, contacta con el equipo del club.')}</section>`);}finally{loading=false;}
}

function renderFeedView(){
  setMainHtml(`<div class="kombax-social-page">${socialHeader()}${pageHeader('Actualidad profesional','Los perfiles son públicos. Las publicaciones son públicas por defecto y, si el autor lo elige, pueden limitarse a su club o federación sin convertir el perfil en privado.',ownProfiles.length?'<button type="button" class="btn btn-primary" id="kombax-social-publish">+ Publicar con multimedia</button>':'','KOMBAX Social')}${identitySwitcher()}${tabBar()}${competitorFoundersPromo()}${activationPanel()}${socialRulesCard()}${quickComposer()}${feedCards()}</div>`);bindCommon();bindFeed();
}

async function renderProfiles(){
  setMainHtml(`<div class="kombax-social-page">${socialHeader()}${pageHeader('Perfiles públicos','Explora clubes, miembros y perfiles KOMBAX autorizados sin acceder a datos administrativos.','','KOMBAX Social')}${identitySwitcher()}${tabBar()}<div class="kombax-social-search"><input id="kombax-profile-query" type="search" placeholder="Buscar por nombre, club o presentación"><button class="btn btn-primary" id="kombax-profile-search">Buscar</button></div><div id="kombax-profile-results"><div class="loading-card">Buscando perfiles…</div></div></div>`);bindCommon();
  const run=async()=>{const box=document.getElementById('kombax-profile-results'),q=document.getElementById('kombax-profile-query')?.value||'';try{const rows=await repos.kombaxSocial.directory(q,40);box.innerHTML=rows.length?`<div class="kombax-profile-grid">${rows.map(p=>`<article class="kx-profile-card" data-social-profile-open="${esc(p.id)}" tabindex="0" role="button"><div class="kombax-social-avatar large">${profileAvatar(p)}</div><div><strong>${esc(p.nombre_publico)} ${verified(p.verificado,p.perfil_tipo||p.sujeto_tipo)}</strong><small>${esc(PUBLIC_TYPE_LABEL[p.perfil_tipo]||PROFILE_LABEL[p.sujeto_tipo]||p.sujeto_tipo)}</small>${affiliationChip(p)}</div><p>${esc(p.bio||(p.perfil_tipo==='miembro'?'Miembro de la comunidad KOMBAX':'Perfil público KOMBAX'))}</p><div class="row-actions">${p.contactable&&!isOwn(p.id)?`<button class="btn btn-ghost btn-sm" data-social-contact="${esc(p.id)}" data-social-name="${esc(p.nombre_publico)}">Contactar</button>`:''}${!isOwn(p.id)&&ownProfiles.some(x=>possibleRelations(x.perfil_tipo||x.sujeto_tipo,p.perfil_tipo||p.sujeto_tipo).length)?`<button class="btn btn-ghost btn-sm" data-social-relation="${esc(p.id)}">Añadir a mi red</button>`:''}${!isOwn(p.id)?`<button class="btn btn-ghost btn-sm" data-social-report-profile="${esc(p.id)}">Denunciar</button>`:''}</div></article>`).join('')}</div>`:empty('Sin coincidencias','Prueba con otro término.');
    box.querySelectorAll('[data-social-profile-open]').forEach(card=>{const open=()=>openKombaxPublicProfile(card.dataset.socialProfileOpen);card.addEventListener('click',e=>{if(e.target.closest('button,a'))return;open();});card.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();open();}});});
    box.querySelectorAll('[data-social-affiliation-club]').forEach(b=>b.addEventListener('click',e=>{e.stopPropagation();if(b.dataset.socialAffiliationClub)openKombaxPublicProfile(b.dataset.socialAffiliationClub);}));
    box.querySelectorAll('[data-social-contact]').forEach(b=>b.addEventListener('click',()=>openContact(b.dataset.socialContact,b.dataset.socialName)));
    box.querySelectorAll('[data-social-relation]').forEach(b=>b.addEventListener('click',()=>{const target=rows.find(x=>String(x.id)===String(b.dataset.socialRelation));if(target)requestRelation(target);}));
    box.querySelectorAll('[data-social-report-profile]').forEach(b=>b.addEventListener('click',()=>openReport('perfil',b.dataset.socialReportProfile)));
  }catch(error){box.innerHTML=empty('No se pudo buscar',humanError(error)||'Revisa la conexión.');}};
  document.getElementById('kombax-profile-search')?.addEventListener('click',run);document.getElementById('kombax-profile-query')?.addEventListener('keydown',e=>{if(e.key==='Enter')run();});await run();
}

async function renderContacts(){
  setMainHtml(`<div class="kombax-social-page">${socialHeader()}${pageHeader('Mensajes KOMBAX','Una sola bandeja, con separación clara entre conversaciones Social y consultas comerciales de Showcase. Salir con la X conserva el hilo; “Eliminar conversación” es la única acción destructiva.','','KOMBAX Social')}${identitySwitcher()}${tabBar()}<div class="kx-message-filters" role="tablist" aria-label="Filtrar mensajes"><button type="button" data-message-filter="all" class="${contactFilter==='all'?'active':''}">Todos</button><button type="button" data-message-filter="social" class="${contactFilter==='social'?'active':''}">${icon('users',{size:15})} Social</button><button type="button" data-message-filter="showcase" class="${contactFilter==='showcase'?'active':''}">${icon('shoppingBag',{size:15})} Showcase</button></div><div id="kombax-contact-list"><div class="loading-card">Cargando mensajes…</div></div></div>`);bindCommon();
  const box=document.getElementById('kombax-contact-list');
  try{
    const rows=await repos.kombaxSocial.contacts();
    const visible=rows.filter(c=>contactFilter==='all'||String(c.canal||'social')===contactFilter);
    box.innerHTML=visible.length?`<div class="kombax-contact-list">${visible.map(c=>{const showcase=String(c.canal||'social')==='showcase';return `<article class="kx-message-card ${showcase?'showcase':'social'}"><header><div><span class="page-kicker">${showcase?'SHOWCASE':esc(c.direccion==='recibida'?'SOCIAL · RECIBIDA':c.direccion==='enviada'?'SOCIAL · ENVIADA':'SOCIAL')} ${showcase&&c.showcase_marca_nombre?`· ${esc(c.showcase_marca_nombre)}`:`· ${esc(CONTACT_LABEL[c.motivo]||c.motivo)}`}</span><strong>${esc(c.remitente_nombre)} → ${esc(c.destinatario_nombre)}</strong></div>${badge(c.estado,c.estado==='aceptada'?'ok':c.estado==='rechazada'||c.estado==='cerrada'?'warn':'neutral')}</header>${showcase?`<div class="kx-message-product">${c.showcase_producto_imagen_url?`<img src="${esc(c.showcase_producto_imagen_url)}" alt="">`:`<span>${icon('shoppingBag',{size:20})}</span>`}<div><small>Producto / servicio</small><strong>${esc(c.showcase_producto_nombre||'Ficha Showcase')}</strong></div></div>`:''}<p>${esc(c.ultimo_mensaje||'Solicitud de contacto')}</p><div class="kx-contact-meta"><small>${dtFmt(c.ultimo_mensaje_en||c.creado_en)}</small><span>${c.estado==='aceptada'?'Conversación abierta':c.estado==='pendiente'?'Pendiente de aceptación':'Conversación finalizada'}</span>${Number(c.no_leidos||0)>0?`<b>${Number(c.no_leidos)} nuevo${Number(c.no_leidos)===1?'':'s'}</b>`:''}</div><div class="row-actions">${c.gestionable?`<button class="btn btn-primary btn-sm" data-contact-state="aceptada" data-contact-id="${esc(c.id)}">Aceptar</button><button class="btn btn-ghost btn-sm" data-contact-state="rechazada" data-contact-id="${esc(c.id)}">Rechazar</button>`:''}<button class="btn btn-ghost btn-sm" data-contact-open="${esc(c.id)}">Abrir conversación</button><button class="btn btn-danger btn-sm" data-contact-delete="${esc(c.id)}">${icon('trash',{size:14})} Eliminar</button></div></article>`;}).join('')}</div>`:empty(contactFilter==='all'?'Sin mensajes':`Sin mensajes ${contactFilter==='showcase'?'Showcase':'Social'}`,contactFilter==='showcase'?'Las consultas iniciadas desde una ficha de Showcase aparecerán aquí con la imagen y el producto asociado.':'Las conversaciones iniciadas desde KOMBAX Social aparecerán aquí.');
    document.querySelectorAll('[data-message-filter]').forEach(b=>b.addEventListener('click',()=>{contactFilter=b.dataset.messageFilter||'all';renderContacts();}));
    box.querySelectorAll('[data-contact-state]').forEach(b=>b.addEventListener('click',async()=>{b.disabled=true;try{await repos.kombaxSocial.contactStatus(b.dataset.contactId,b.dataset.contactState);toast(b.dataset.contactState==='aceptada'?'Solicitud aceptada · contacto abierto':'Solicitud rechazada');await renderContacts();}catch(error){b.disabled=false;setError(error);}}));
    box.querySelectorAll('[data-contact-open]').forEach(b=>b.addEventListener('click',()=>{const c=rows.find(x=>String(x.id)===String(b.dataset.contactOpen));if(c)openContactThread(c);}));
    box.querySelectorAll('[data-contact-delete]').forEach(b=>b.addEventListener('click',()=>{const c=rows.find(x=>String(x.id)===String(b.dataset.contactDelete));if(!c)return;const actor=ownProfiles.find(p=>p.id===c.remitente_id||p.id===c.destinatario_id);if(!actor){toast('No se puede identificar tu identidad en esta conversación.','error');return;}confirmDialog('Eliminar conversación','Se eliminará de tu bandeja y dejará de admitir nuevos mensajes. La contraparte conservará su historial hasta que también lo elimine.',async()=>{await repos.kombaxSocial.deleteContact(c.id,actor.id);toast('Conversación eliminada');await renderContacts();},{confirmText:'Eliminar conversación',danger:true});}));
    const pendingOpen=sessionStorage.getItem('kombax_social_open_contact');if(pendingOpen){const c=rows.find(x=>String(x.id)===String(pendingOpen));sessionStorage.removeItem('kombax_social_open_contact');if(c)setTimeout(()=>openContactThread(c),0);}
  }catch(error){box.innerHTML=empty('No se pudieron cargar los contactos',humanError(error)||'Revisa la conexión.');}
}

async function renderSaved(){
  setMainHtml(`<div class="kombax-social-page">${socialHeader()}${pageHeader('Guardados','Colección privada: solo tú puedes ver lo que has guardado.','','KOMBAX Social')}${identitySwitcher()}${tabBar()}<div id="kombax-saved-list"><div class="loading-card">Cargando guardados…</div></div></div>`);bindCommon();
  const box=document.getElementById('kombax-saved-list');
  try{
    const rows=await repos.kombaxSocial.saved(160);
    box.innerHTML=rows.length?`<div class="kombax-saved-list">${rows.map(x=>`<article><div><span class="page-kicker">${esc(TYPE_LABEL[x.tipo]||x.tipo)} · ${dtFmt(x.creado_en)} · ${esc(x.audiencia_label||'Público')}</span><button type="button" class="kx-saved-author" data-social-profile-open="${esc(x.autor_id)}">${esc(x.autor_nombre)}</button><p>${esc(x.texto)}</p></div><button class="btn btn-ghost btn-sm" data-kx-unsave="${esc(x.id)}">Quitar de guardados</button></article>`).join('')}</div>`:empty('Sin guardados','Las publicaciones que guardes aparecerán aquí y no se muestran públicamente.');
    box.querySelectorAll('[data-social-profile-open]').forEach(b=>b.addEventListener('click',()=>openKombaxPublicProfile(b.dataset.socialProfileOpen)));
    box.querySelectorAll('[data-kx-unsave]').forEach(b=>b.addEventListener('click',async()=>{b.disabled=true;try{await repos.kombaxSocial.save(b.dataset.kxUnsave,false);toast('Eliminado de guardados');await renderSaved();}catch(error){b.disabled=false;setError(error);}}));
  }catch(error){box.innerHTML=empty('No se pudieron cargar los guardados',humanError(error)||'Revisa la conexión.');}
}

async function renderRelations(selectedProfileId=''){
  setMainHtml(`<div class="kombax-social-page">${socialHeader()}${pageHeader('Mi red','Área privada. Solo tú y las identidades que puedes gestionar ven esta lista; KOMBAX no publica quién forma parte de tu red ni un contador público.','','KOMBAX Social')}${identitySwitcher()}${tabBar()}<div id="kombax-relations-list"><div class="loading-card">Cargando tu red…</div></div></div>`);bindCommon();
  const box=document.getElementById('kombax-relations-list');
  if(!ownProfiles.length){box.innerHTML=empty('Sin perfil autorizado','Necesitas un perfil KOMBAX Social autorizado para gestionar tu red.');return;}
  const selected=ownProfiles.find(x=>String(x.id)===String(selectedProfileId))||activeIdentity()||ownProfiles[0];
  try{
    const rows=await repos.kombaxSocial.relations(selected.id);
    box.innerHTML=`<div class="kx-relations-toolbar"><label>Perfil<select id="kx-relation-profile">${ownProfiles.map(x=>`<option value="${esc(x.id)}" ${x.id===selected.id?'selected':''}>${esc(x.nombre_publico)}</option>`).join('')}</select></label></div>${rows.length?`<div class="kx-relations-list">${rows.map(r=>`<article><header><div><span class="page-kicker">${esc(RELATION_LABEL[r.tipo]||r.tipo)}</span><strong>${esc(r.origen_nombre)} ↔ ${esc(r.destino_nombre)}</strong></div>${badge(r.estado,r.estado==='confirmed'?'ok':r.estado==='rejected'||r.estado==='suspended'?'warn':'neutral')}</header>${r.nota?`<p>${esc(r.nota)}</p>`:''}<small>Solicitud ${dtFmt(r.creado_en)}${r.confirmado_en?` · aceptada ${dtFmt(r.confirmado_en)}`:''}</small><div class="row-actions">${r.gestionable?`<button class="btn btn-primary btn-sm" data-kx-relation-state="confirmed" data-kx-relation-id="${esc(r.id)}">Aceptar en mi red</button><button class="btn btn-ghost btn-sm" data-kx-relation-state="rejected" data-kx-relation-id="${esc(r.id)}">Rechazar</button>`:''}${r.estado==='confirmed'?`<button class="btn btn-ghost btn-sm" data-kx-relation-state="ended" data-kx-relation-id="${esc(r.id)}">Eliminar de mi red</button>`:''}</div></article>`).join('')}</div>`:empty('Tu red está vacía','Las solicitudes y conexiones aceptadas aparecerán aquí de forma privada.')}`;
    document.getElementById('kx-relation-profile')?.addEventListener('change',e=>renderRelations(e.target.value));
    box.querySelectorAll('[data-kx-relation-state]').forEach(b=>b.addEventListener('click',()=>confirmDialog(
      b.dataset.kxRelationState==='confirmed'?'Aceptar en mi red':b.dataset.kxRelationState==='rejected'?'Rechazar solicitud':'Eliminar de mi red',
      'Mi red es privada, requiere consentimiento y conserva la trazabilidad necesaria para seguridad.',
      async()=>{await repos.kombaxSocial.relationState(b.dataset.kxRelationId,b.dataset.kxRelationState);toast('Mi red actualizada');await renderRelations(selected.id);},
      {confirmText:b.dataset.kxRelationState==='confirmed'?'Aceptar':'Continuar',danger:b.dataset.kxRelationState!=='confirmed'}
    )));
  }catch(error){box.innerHTML=empty('No se pudo cargar tu red',humanError(error)||'No se pudo comprobar esta conexión.');}
}

function moderationAction(report,estado,accion){
  const labels={ocultar:'Ocultar contenido',limitar:'Limitar perfil',suspender:'Suspender perfil',ninguna:estado==='descartada'?'Descartar denuncia':'Resolver sin retirar contenido'};
  openForm({title:labels[accion]||'Resolver denuncia',subtitle:`${report.objetivo_tipo} · ${report.motivo}. La acción queda registrada en el historial de moderación.`,fields:[{name:'resolucion',label:'Motivo / resolución',type:'textarea',required:true,full:true,rows:5,maxLength:1500,help:'Describe de forma concreta la revisión y el criterio aplicado.'}],submitText:labels[accion]||'Resolver',onSubmit:async v=>{await repos.kombaxSocial.moderate(report.id,estado,v.resolucion,accion);toast(estado==='descartada'?'Denuncia descartada':'Moderación aplicada');await renderSafety();}});
}

async function renderSafety(){
  setMainHtml(`<div class="kombax-social-page">${socialHeader()}${pageHeader('Seguridad y alcance','Controles claros para una comunidad responsable.','','KOMBAX Social')}${identitySwitcher()}${tabBar()}<div class="kombax-safety-grid"><article>${icon('shieldCheck',{size:30})}<strong>Separación real</strong><p>KOMBAX Social no muestra expedientes, cuotas, asistencia, teléfonos, correos, domicilios ni relaciones familiares.</p></article><article>${icon('message',{size:30})}<strong>Contacto KOMBAX</strong><p>El chat solo se habilita tras aceptar una solicitud con motivo previo. El historial permanece abierto y es solo texto: sin imágenes, vídeos, audios ni archivos en esta fase.</p></article><article>${icon('users',{size:30})}<strong>Protección de menores</strong><p>KOMBAX impide el contacto directo cuando cualquiera de los perfiles personales corresponde a una persona menor de 18 años.</p></article><article>${icon('alert',{size:30})}<strong>Moderación global</strong><p>Publicaciones, comentarios y perfiles pueden denunciarse. Los bloqueos y las acciones de moderación conservan trazabilidad sin alterar la membresía del club.</p></article></div><section id="kx-moderation-console"></section></div>`);bindCommon();
  const consoleBox=document.getElementById('kx-moderation-console');
  let reports=[];
  try{reports=await repos.kombaxSocial.moderationQueue(120);}catch{return;}
  if(!Array.isArray(reports))return;
  consoleBox.innerHTML=`<div class="kx-moderation-head"><div><span class="page-kicker">MODERACIÓN KOMBAX</span><h3>Denuncias pendientes</h3><p>Cola visible exclusivamente para moderadores globales. Cada resolución exige motivo y queda auditada.</p></div>${badge(String(reports.length),reports.length?'warn':'ok')}</div>${reports.length?`<div class="kx-moderation-list">${reports.map(r=>`<article><header><div><span class="page-kicker">${esc(String(r.objetivo_tipo||'').toUpperCase())} · ${esc(r.motivo)}</span><strong>${esc(r.autor_objetivo||'Contenido denunciado')}</strong></div>${badge(r.estado,'warn')}</header><p>${esc(r.objetivo_resumen||'Sin resumen disponible')}</p>${r.detalle?`<blockquote>${esc(r.detalle)}</blockquote>`:''}<small>${dtFmt(r.creado_en)}</small><div class="row-actions">${r.objetivo_tipo==='publicacion'||r.objetivo_tipo==='comentario'?`<button class="btn btn-primary btn-sm" data-kx-moderate="${esc(r.id)}" data-kx-status="resuelta" data-kx-action="ocultar">Ocultar y resolver</button>`:''}${r.objetivo_tipo==='perfil'?`<button class="btn btn-primary btn-sm" data-kx-moderate="${esc(r.id)}" data-kx-status="resuelta" data-kx-action="limitar">Limitar</button><button class="btn btn-danger btn-sm" data-kx-moderate="${esc(r.id)}" data-kx-status="resuelta" data-kx-action="suspender">Suspender</button>`:''}<button class="btn btn-ghost btn-sm" data-kx-moderate="${esc(r.id)}" data-kx-status="resuelta" data-kx-action="ninguna">Resolver sin retirar</button><button class="btn btn-ghost btn-sm" data-kx-moderate="${esc(r.id)}" data-kx-status="descartada" data-kx-action="ninguna">Descartar</button></div></article>`).join('')}</div>`:empty('Cola al día','No hay denuncias pendientes de revisión.')}`;
  consoleBox.querySelectorAll('[data-kx-moderate]').forEach(b=>b.addEventListener('click',()=>{const report=reports.find(r=>String(r.id)===String(b.dataset.kxModerate));if(report)moderationAction(report,b.dataset.kxStatus,b.dataset.kxAction);}));
}

export async function renderKombaxSocial(){
  setMainHtml('<div class="loading-card">Abriendo KOMBAX Social…</div>');
  try{[socialStatus,ownProfiles]=await Promise.all([repos.kombaxSocial.status(),repos.kombaxSocial.myProfiles()]);audiencesByProfile=new Map();await Promise.all(ownProfiles.map(async p=>{const rows=await repos.kombaxSocial.audiences(p.id).catch(()=>[]);audiencesByProfile.set(String(p.id),rows?.length?rows:[{audiencia:'publica',target_social_id:null,target_club_id:null,label:'Público · Todo KOMBAX',descripcion:'Visible para toda la red KOMBAX Social.',predeterminada:true}]);}));const preferred=chooseDefaultIdentity(ownProfiles);activeIdentityId=preferred?.id||'';await refreshActiveQuota();const requested=sessionStorage.getItem('kombax_social_view');if(requested&&['feed','profiles','saved','relations','contacts','safety'].includes(requested)){activeView=requested;sessionStorage.removeItem('kombax_social_view');}}
  catch(error){setError(error);setMainHtml(`${pageHeader('KOMBAX Social','La comunidad pública no está disponible en este momento.','','KOMBAX Social')}${empty('KOMBAX Social no disponible',humanError(error)||'No se pudo comprobar el acceso.')}`);return;}
  if(activeView==='profiles')return renderProfiles();
  if(activeView==='saved')return renderSaved();
  if(activeView==='relations')return renderRelations();
  if(activeView==='contacts')return renderContacts();
  if(activeView==='safety')return renderSafety();
  return loadFeed(false);
}
