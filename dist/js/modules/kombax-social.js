import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { backend } from '../core/backend.js';
import { esc, dtFmt, humanError } from '../core/utils.js';
import { KOMBAX_BRAND } from '../core/platform.js';
import { pageHeader, empty, badge, openForm, openDetail, openImmersiveMedia, closeModal, confirmDialog, toast, setError, setMainHtml, subviewActions, bindSubviewActions, goBackOrFallback } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { chooseDefaultIdentity, setActiveIdentity, identityLabel } from '../core/identity-context.js';
import { openKombaxPublicProfile } from './public-profile.js';
import { openKombaxPostManager, socialQuotaMarkup } from './social-post-management.js';
import { createAdaptivePoller } from '../core/adaptive-poller.js';
import { brandHero } from '../ui/brand-hero.js';
import { mediaFrameAttrs, openMediaFramingEditor } from '../ui/media-framing.js';
import { openVideoCoverEditor } from '../ui/video-cover.js';
import { renderKombaxDiscovery, openKombaxDiscovery } from './kombax-discovery.js';
import { RELATION_LABEL, possibleRelations, requestNetworkConnection } from './social-network.js';
import { conversationChannelTabs, bindConversationChannelTabs } from '../ui/conversation-ui.js';
import { t } from '../i18n/index.js';
import { contentTranslationAttrs, prewarmUserContentTranslations } from '../i18n/user-content-translation.js';
import { verificationVisual } from '../core/verification-visual.js';

const PAGE_SIZE=20;
const TYPE_LABEL={actualizacion:t('social.types.update'),resultado:t('social.types.result'),evento:t('social.types.event'),oportunidad:t('social.types.opportunity')};
const PROFILE_LABEL={club:t('social.profiles.club'),miembro:t('social.profiles.member'),perfil_directo:t('social.profiles.kombaxProfile')};
const PUBLIC_TYPE_LABEL={club:t('social.profiles.club'),miembro:t('social.profiles.member'),competidor:t('social.types.fighter'),marca:t('social.types.brand'),federacion:t('social.types.federation'),profesional:t('social.types.professional'),media:'Media / Creador',espectador:t('social.types.spectator')};
const AUDIENCE_PROFILE_TYPES=[['miembro',t('social.profiles.member')],['club',t('social.profiles.clubs')],['competidor',t('social.profiles.fighters')],['federacion',t('social.profiles.federations')],['marca',t('social.profiles.brands')],['profesional',t('social.profiles.professionals')],['espectador',t('social.profiles.spectators')]];
const COMPLEX_AUDIENCE_MODES=new Set(['clubes_seleccionados','kombax_excepto','perfiles_seleccionados','tipos_perfil']);
window.addEventListener('uw-kombax-social-profile-media-changed',()=>{if(document.querySelector('.kombax-social-page'))renderKombaxSocial().catch(()=>{});});

const CONTACT_LABEL={entrenamiento:t('social.contact.training'),competicion:t('social.contact.competition'),evento:t('social.contact.event'),colaboracion:t('social.contact.collaboration'),patrocinio:t('social.contact.sponsorship'),informacion:t('social.contact.information'),otro:t('social.contact.other')};
let activeView='feed';
let posts=[];
let socialPromotions=[];
let cursor=null;
let done=false;
let loading=false;
let ownProfiles=[];
let networkProfiles=[];
let socialStatus=null;
let activeIdentityId='';
let feedObserver=null;
let audiencesByProfile=new Map();
let activeQuota=null;
let expandedCommentPostId='';
let contactLimit=50;
let relationLimit=50;
let contactFilter='all';
let minorConsentStatus={mine:[],approvals:[]};

const initials=name=>String(name||'K').split(/\s+/).filter(Boolean).slice(0,2).map(x=>x[0]?.toUpperCase()).join('');
const isOwn=id=>ownProfiles.some(p=>p.id===id);
const profileAvatar=p=>{const path=p?.autor_avatar_path||p?.avatar_path;const src=path?mediaUrl(path):(p?.autor_avatar_url||p?.avatar_url||'');return src?`<img src="${esc(src)}" alt="" loading="lazy" decoding="async">`:`<span>${esc(initials(p?.autor_nombre||p?.nombre_publico))}</span>`;};
const verified=(value,type='')=>{const visual=verificationVisual(type,value);if(visual==='none'||visual==='member')return '';const label=PUBLIC_TYPE_LABEL[type]||PROFILE_LABEL[type]||t('social.profiles.profile');const title=esc(t('social.verified',{profile:label}));if(visual==='competitor')return `<span class="kx-competitor-verified-mini" title="${title}" aria-label="${title}">${icon('shieldCheck',{size:13})}<span>${esc(t('common.states.verified'))}</span></span>`;return `<span class="kombax-verified" title="${title}" aria-label="${title}">${icon('shieldCheck',{size:14})}</span>`;};
const audienceKey=a=>`${a?.audiencia||'publica'}|${a?.target_social_id||''}|${a?.target_club_id||''}`;
const audienceOptions=id=>audiencesByProfile.get(String(id))||[{audiencia:'publica',target_social_id:null,target_club_id:null,label:t('social.audience.publicAll'),descripcion:t('social.audience.publicDescription'),predeterminada:true}];
const simpleAudienceOptions=id=>audienceOptions(id).filter(a=>!COMPLEX_AUDIENCE_MODES.has(a.audiencia));
const audienceSelectOptions=id=>audienceOptions(id).map(a=>`<option value="${esc(audienceKey(a))}">${esc(a.label)}</option>`).join('');
const parseAudience=value=>{const [audiencia='publica',social='',club='']=String(value||'publica||').split('|');return {audiencia,audiencia_federacion_social_id:social||null,audiencia_club_id:club||null};};
const audienceChip=p=>`<span class="kx-audience-chip ${p?.audiencia&&p.audiencia!=='publica'?'restricted':'public'}" title="${esc(p?.audiencia==='publica'?t('social.audience.publicDescription'):t('social.audience.restricted'))}">${icon(p?.audiencia==='publica'?'globe':'lock',{size:13})} ${esc(p?.audiencia_label||t('social.audience.public'))}</span>`;

const affiliationChip=p=>{
  const clubId=p?.autor_club_social_id||p?.club_social_id;
  const clubName=p?.autor_club_nombre||p?.club_nombre;
  const ok=p?.autor_afiliacion_verificada===true||p?.afiliacion_verificada===true;
  return ok&&clubName?`<button type="button" class="kx-affiliation-chip" ${clubId?`data-social-affiliation-club="${esc(clubId)}"`:''} title="${esc(t('social.affiliationConfirmed'))}">${icon('checkCircle',{size:13})} ${t('social.affiliation')} · ${esc(clubName)}</button>`:'';
};

function socialHeader(){
  return brandHero({area:'social',headline:t('social.hero.headline'),accent:t('social.hero.accent'),body:t('social.hero.body'),features:[{icon:'users',label:t('social.features.community')},{icon:'activity',label:t('social.features.feed')},{icon:'network',label:t('social.features.network')},{icon:'message',label:t('social.features.messages')}]});
}

function tabBar(){
  return `<div class="kombax-social-tabs" role="tablist">
    <button type="button" data-social-view="feed" class="${activeView==='feed'?'active':''}">${icon('activity',{size:17})} ${t('social.tabs.feed')}</button>
    <button type="button" data-social-view="profiles" class="${activeView==='profiles'?'active':''}">${icon('users',{size:17})} ${t('social.tabs.profiles')}</button>
    <button type="button" data-social-view="discovery" class="${activeView==='discovery'?'active':''}">${icon('search',{size:17})} ${t('social.tabs.discover')}</button>
    <button type="button" data-social-view="saved" class="${activeView==='saved'?'active':''}">${icon('archive',{size:17})} ${t('social.tabs.saved')}</button>
    <button type="button" data-social-view="relations" class="${activeView==='relations'?'active':''}">${icon('network',{size:17})} ${t('social.tabs.network')}</button>
    <button type="button" data-social-view="contacts" class="${activeView==='contacts'?'active':''}">${icon('message',{size:17})} ${t('social.tabs.messages')}</button>
    <button type="button" data-social-view="safety" class="${activeView==='safety'?'active':''}">${icon('shield',{size:17})} ${t('social.tabs.safety')}</button>
  </div>`;
}

function activeIdentity(){return ownProfiles.find(x=>String(x.id)===String(activeIdentityId))||chooseDefaultIdentity(ownProfiles)||null;}
function identitySwitcher(){
  if(!ownProfiles.length)return '';
  const current=activeIdentity();
  return `<section class="kx-identity-context" data-legacy-label="ACTUAR COMO"><div>${icon('idCard',{size:22})}<div><small>${t('social.identity.active')}</small><strong>${esc(identityLabel(current))}</strong></div></div>${ownProfiles.length>1?`<label><span>${t('social.identity.change')}</span><select id="kx-active-identity">${ownProfiles.map(x=>`<option value="${esc(x.id)}" ${x.id===current?.id?'selected':''}>${esc(identityLabel(x))}</option>`).join('')}</select></label>`:''}</section>`;
}
function socialInfoTrigger(){
  return `<button type="button" class="icon-btn kx-social-info-trigger" id="kx-social-info" aria-label="${esc(t('social.info.title'))}" title="${esc(t('social.info.title'))}">${icon('info',{size:20})}</button>`;
}
function socialHeaderActions(primary=''){return `${primary||''}${socialInfoTrigger()}`;}
function openSocialInfoPanel(){
  const modal=openDetail({title:t('social.info.title'),subtitle:t('social.info.subtitle'),body:`<div class="kx-social-info-panel">${identitySwitcher()}${socialTopicPolicyNotice()}${socialRulesCard()}</div>`,actions:'',width:'680px',className:'kx-social-info-modal'});
  modal.wrap.querySelector('#kx-active-identity')?.addEventListener('change',e=>{activeIdentityId=e.target.value;setActiveIdentity(activeIdentityId);closeModal();renderKombaxSocial();});
}

function activationPanel(){
  if(socialStatus?.status==='activa')return '';
  const eligible=socialStatus?.eligible===true;
  return `<section class="kombax-social-notice"><div>${icon('shieldCheck',{size:28})}</div><div><strong>${eligible?t('social.activation.eligible'):t('social.activation.unavailable')}</strong><p>${esc(socialStatus?.reason||t('social.activation.defaultReason'))}</p>${eligible?`<button type="button" class="btn btn-primary btn-sm" id="kombax-social-activate">${t('social.actions.reviewActivate')}</button>`:''}</div></section>`;
}

function guardianConsentPanel(){
  const approvals=Array.isArray(minorConsentStatus?.approvals)?minorConsentStatus.approvals:[];
  const managed=Array.isArray(minorConsentStatus?.managed)?minorConsentStatus.managed:[];
  const mine=Array.isArray(minorConsentStatus?.mine)?minorConsentStatus.mine:[];
  const pendingMine=mine.find(x=>x.estado==='pending');
  const approvedMine=mine.find(x=>x.estado==='approved');
  let html='';
  if(pendingMine)html+=`<section class="kombax-social-notice guardian"><div>${icon('shield',{size:28})}</div><div><strong>${t('social.guardian.pending')}</strong><p>${t('social.guardian.pendingBody')}</p></div></section>`;
  else if(approvedMine)html+=`<section class="kombax-social-notice guardian ok"><div>${icon('shieldCheck',{size:28})}</div><div><strong>${t('social.guardian.approved')}</strong><p>${t('social.guardian.approvedBody')}</p></div></section>`;
  if(approvals.length)html+=`<section class="kx-social-guardian-approvals"><div><span class="page-kicker">CONTROL ADULTO</span><h3>Solicitudes de menores vinculados</h3><p>Aprueba solo si eres su padre, madre o tutor responsable y entiendes que KOMBAX Social crea una identidad pública deportiva.</p></div>${approvals.map(a=>`<article><div><strong>${esc(a.minor_name||'Menor vinculado')}</strong><small>Solicitud ${dtFmt(a.solicitado_en)}</small></div><div class="row-actions"><button class="btn btn-primary btn-sm" data-kx-minor-consent="approved" data-consent-id="${esc(a.consent_id)}">Autorizar Social</button><button class="btn btn-ghost btn-sm" data-kx-minor-consent="rejected" data-consent-id="${esc(a.consent_id)}">Rechazar</button></div></article>`).join('')}</section>`;
  const approvedManaged=managed.filter(x=>x.estado==='approved');
  if(approvedManaged.length)html+=`<section class="kx-social-guardian-approvals"><div><span class="page-kicker">CONTROL ADULTO ACTIVO</span><h3>Menores con Social autorizado</h3><p>Puedes retirar la autorización en cualquier momento. La retirada oculta el perfil y bloquea nuevas publicaciones hasta una nueva autorización y reactivación del menor.</p></div>${approvedManaged.map(a=>`<article><div><strong>${esc(a.minor_name||'Menor vinculado')}</strong><small>Autorización activa</small></div><div class="row-actions"><button class="btn btn-danger btn-sm" data-kx-minor-consent="revoked" data-consent-id="${esc(a.consent_id)}">Desactivar Social</button></div></article>`).join('')}</section>`;
  return html;
}

const mediaUrl=path=>path?backend.publicUrl('kombax-public-media',path):'';
function openSocialMediaViewer(post,sourceVideo=null){
  const url=post?.media_url||mediaUrl(post?.media_path);if(!url)return;
  const caption=`${post?.autor_nombre||'KOMBAX'} · ${TYPE_LABEL[post?.tipo]||post?.tipo||'Publicación'}`;
  return openImmersiveMedia({src:url,type:post?.media_tipo==='video'?'video':'image',poster:post?.media_cover_url||'',alt:caption,sourceVideo});
}
function postMedia(p){
  if(!p.media_path)return '';
  const url=p.media_url||mediaUrl(p.media_path);
  return p.media_tipo==='video'
    ? `<div class="kombax-post-media kx-social-video" data-kx-media-shell="video"><video ${mediaFrameAttrs(p.media_presentation,"social")} src="${esc(url)}" ${p.media_cover_url?`poster="${esc(p.media_cover_url)}"`:''} controls preload="metadata" playsinline data-kx-orientation-source="video"></video><button type="button" class="kx-social-expand-media" data-social-video-open="${esc(p.id)}" aria-label="Ver vídeo a pantalla completa">${icon('arrowUpRight',{size:18})}</button></div>`
    : `<button type="button" class="kombax-post-media kx-social-image-button" data-kx-media-shell="image" data-social-media-open="${esc(p.id)}" aria-label="Ver imagen a pantalla completa"><img ${mediaFrameAttrs(p.media_presentation,"social")} data-kx-orientation-source="image" src="${esc(url)}" alt="Multimedia de la publicación" loading="lazy"></button>`;
}
function socialRulesCard(){
  return `<section class="kx-social-rules-card"><div class="kx-social-rules-summary"><div>${icon('info',{size:22})}<div><strong>Cómo funciona KOMBAX Social</strong><span>Norma general actual para Miembro, Competidor, Club, Federación y Marca.</span></div></div><details><summary>Ver normas de publicación</summary><ul><li>Máximo <b>30 publicaciones activas</b> por identidad.</li><li>Máximo <b>3 publicaciones nuevas al día</b>.</li><li>Máximo <b>10 vídeos activos</b> por identidad.</li><li>Vídeos: <b>MP4 recomendado</b>, HD hasta 1080p, máximo <b>60 segundos</b> y 100 MB.</li><li>El perfil muestra primero las <b>10 publicaciones más recientes</b> y permite cargar las anteriores de 10 en 10.</li><li>KOMBAX <b>no elimina automáticamente</b> tus publicaciones al llegar a 30: tú decides cuál borrar.</li><li>El Álbum es independiente: borrar una publicación no elimina una foto o vídeo que también hayas guardado en el Álbum.</li></ul><p>Estos límites son la norma general actual y podrán variar en el futuro según tipo de perfil o plan KOMBAX.</p></details></div></section>`;
}

function socialTopicPolicyNotice(){
  return `<section class="kx-social-topic-policy" role="note" aria-label="Política temática de KOMBAX Social"><div class="kx-social-topic-policy-icon">${icon('shieldCheck',{size:24})}</div><div><span>KOMBAX SOCIAL · COMUNIDAD TEMÁTICA</span><strong>Mantén el contenido dentro del mundo del combate.</strong><p>Publica artes marciales y deportes de contacto: entrenamiento, técnica, competición, peleadores, clubes, eventos, resultados, preparación, equipamiento y cultura de combate. KOMBAX Social no es una red de vida cotidiana general. El contenido claramente ajeno a esta temática puede ser revisado y retirado por moderación KOMBAX con trazabilidad.</p><small>${icon('info',{size:13})} La moderación debe valorar texto, imagen y contexto; una escena cotidiana puede ser válida si forma parte real de una historia deportiva.</small></div></section>`;
}

function competitorFoundersPromo(){
  return `<section class="kx-founders-promo competitor" aria-label="Competidores fundadores"><div class="kx-founders-promo-mark">${icon('fighter',{size:28})}</div><div><span>KOMBAX SOCIAL · COMUNIDAD</span><strong>COMPETIDORES FUNDADORES</strong><p>Construye tu perfil deportivo, muestra tu trayectoria y forma parte de los primeros competidores verificados en KOMBAX.</p><small>La verificación se solicita desde tu perfil y se revisa antes de mostrar la insignia.</small></div></section>`;
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
    <textarea id="kx-social-quick-text" maxlength="1500" rows="3" placeholder="${esc(t('social.composer.placeholder'))}" aria-label="${esc(t('social.composer.aria'))}"></textarea>
    <div class="kx-social-publish-topic-hint">${icon('fighter',{size:15})}<span><b>Solo contenido de combate.</b> Artes marciales, deportes de contacto, clubes, peleadores, eventos, entrenamiento y cultura deportiva.</span></div>
    <div class="kx-quick-audience"><label><span>${t('social.audience.label')}</span><select id="kx-social-quick-audience">${simpleAudienceOptions(current.id).map(a=>`<option value="${esc(audienceKey(a))}">${esc(a.label)}</option>`).join('')}</select></label><small>${t('social.audience.defaultPublic')}</small></div>
    <footer><span id="kx-social-quick-count">0/1500</span><div><button type="button" class="btn btn-ghost" id="kx-social-add-media">${icon('image',{size:17})} ${t('social.actions.addMedia')}</button><button type="button" class="btn btn-primary" id="kx-social-quick-publish" disabled>${icon('arrowUpRight',{size:17})} ${t('social.actions.publish')}</button></div></footer>
  </section>`;
}



function attachAudienceSelectors({form,audience,clubIds=new Set(),excludedClubIds=new Set(),profileIds=new Set(),profileTypes=new Set(),initialClubs=[],initialProfiles=[]}={}){
  const grid=form?.querySelector('.form-grid');if(!grid||!audience)return {clubIds,excludedClubIds,profileIds,profileTypes,refresh:()=>{}};
  grid.insertAdjacentHTML('beforeend',`<section class="kx-audience-club-picker" id="kx-audience-club-picker" hidden><div class="kx-audience-picker-head"><div><strong id="kx-audience-club-title">Clubes</strong><small id="kx-audience-club-help">Selecciona los clubes de esta publicación.</small></div><span id="kx-audience-selected-count">0 seleccionados</span></div><label class="field full"><span>Buscar club KOMBAX</span><input id="kx-audience-club-query" type="search" placeholder="Nombre del club"></label><div id="kx-audience-club-results" class="kx-audience-club-results"></div></section>
  <section class="kx-audience-club-picker" id="kx-audience-profile-picker" hidden><div class="kx-audience-picker-head"><div><strong>Perfiles concretos</strong><small>Selecciona identidades KOMBAX concretas. Máximo 50.</small></div><span id="kx-audience-profile-count">0 seleccionados</span></div><label class="field full"><span>Buscar perfil KOMBAX</span><input id="kx-audience-profile-query" type="search" placeholder="Nombre, club o perfil"></label><div id="kx-audience-profile-results" class="kx-audience-club-results"></div></section>
  <section class="kx-audience-club-picker" id="kx-audience-type-picker" hidden><div class="kx-audience-picker-head"><div><strong>Tipos de perfil</strong><small>Solo las identidades de los tipos seleccionados podrán ver esta publicación.</small></div><span id="kx-audience-type-count">0 seleccionados</span></div><div class="kx-audience-type-grid">${AUDIENCE_PROFILE_TYPES.map(([value,label])=>`<label class="kx-audience-club-option"><input type="checkbox" data-kx-audience-type="${esc(value)}" ${profileTypes.has(value)?'checked':''}><span><strong>${esc(label)}</strong><small>KOMBAX Social</small></span></label>`).join('')}</div></section>`);
  const clubPicker=grid.querySelector('#kx-audience-club-picker'),clubTitle=grid.querySelector('#kx-audience-club-title'),clubHelp=grid.querySelector('#kx-audience-club-help'),clubCount=grid.querySelector('#kx-audience-selected-count'),clubQuery=grid.querySelector('#kx-audience-club-query'),clubResults=grid.querySelector('#kx-audience-club-results');
  const profilePicker=grid.querySelector('#kx-audience-profile-picker'),profileCount=grid.querySelector('#kx-audience-profile-count'),profileQuery=grid.querySelector('#kx-audience-profile-query'),profileResults=grid.querySelector('#kx-audience-profile-results');
  const typePicker=grid.querySelector('#kx-audience-type-picker'),typeCount=grid.querySelector('#kx-audience-type-count');
  const clubLabels=new Map((initialClubs||[]).map(x=>[String(x.id),String(x.name||'Club KOMBAX')]));
  const profileLabels=new Map((initialProfiles||[]).map(x=>[String(x.id),{name:String(x.name||'Perfil KOMBAX'),type:String(x.type||'')}]))
  const mode=()=>parseAudience(audience.value).audiencia;
  const activeClubSet=()=>mode()==='kombax_excepto'?excludedClubIds:clubIds;
  const updateCounts=()=>{const set=activeClubSet();if(clubCount)clubCount.textContent=`${set.size} seleccionado${set.size===1?'':'s'}`;if(profileCount)profileCount.textContent=`${profileIds.size} seleccionado${profileIds.size===1?'':'s'}`;if(typeCount)typeCount.textContent=`${profileTypes.size} seleccionado${profileTypes.size===1?'':'s'}`;};
  const renderClubResults=(rows=[])=>{const set=activeClubSet();const normalized=[];for(const x of rows){if(x?.perfil_tipo==='club'&&x.club_id){clubLabels.set(String(x.club_id),x.nombre_publico||'Club KOMBAX');normalized.push({id:String(x.club_id),name:x.nombre_publico||'Club KOMBAX',verified:x.verificado===true});}}for(const id of set){if(!normalized.some(x=>x.id===String(id)))normalized.unshift({id:String(id),name:clubLabels.get(String(id))||'Club seleccionado',verified:false});}clubResults.innerHTML=normalized.length?normalized.map(x=>`<label class="kx-audience-club-option"><input type="checkbox" data-kx-audience-club="${esc(x.id)}" ${set.has(String(x.id))?'checked':''}><span><strong>${esc(x.name)}</strong><small>Club KOMBAX${x.verified?' · Verificado':''}</small></span></label>`).join(''):'<p>Escribe al menos dos caracteres para buscar clubes.</p>';clubResults.querySelectorAll('[data-kx-audience-club]').forEach(input=>input.addEventListener('change',()=>{const id=String(input.dataset.kxAudienceClub);if(input.checked)set.add(id);else set.delete(id);updateCounts();}));updateCounts();};
  const renderProfileResults=(rows=[])=>{const normalized=[];for(const x of rows){if(x?.id&&!isOwn(x.id)){profileLabels.set(String(x.id),{name:x.nombre_publico||'Perfil KOMBAX',type:x.perfil_tipo||x.sujeto_tipo||''});normalized.push({id:String(x.id),name:x.nombre_publico||'Perfil KOMBAX',type:x.perfil_tipo||x.sujeto_tipo||'',verified:x.verificado===true});}}for(const id of profileIds){if(!normalized.some(x=>x.id===String(id))){const meta=profileLabels.get(String(id))||{name:'Perfil seleccionado',type:''};normalized.unshift({id:String(id),name:meta.name,type:meta.type,verified:false});}}profileResults.innerHTML=normalized.length?normalized.map(x=>`<label class="kx-audience-club-option"><input type="checkbox" data-kx-audience-profile="${esc(x.id)}" ${profileIds.has(String(x.id))?'checked':''}><span><strong>${esc(x.name)}</strong><small>${esc(PUBLIC_TYPE_LABEL[x.type]||PROFILE_LABEL[x.type]||x.type||'Perfil KOMBAX')}${x.verified?' · Verificado':''}</small></span></label>`).join(''):'<p>Escribe al menos dos caracteres para buscar perfiles.</p>';profileResults.querySelectorAll('[data-kx-audience-profile]').forEach(input=>input.addEventListener('change',()=>{const id=String(input.dataset.kxAudienceProfile);if(input.checked)profileIds.add(id);else profileIds.delete(id);updateCounts();}));updateCounts();};
  let clubTimer=null;clubQuery?.addEventListener('input',()=>{clearTimeout(clubTimer);clubTimer=setTimeout(async()=>{const q=clubQuery.value.trim();if(q.length<2){renderClubResults([]);return;}clubResults.innerHTML='<p>Buscando clubes…</p>';renderClubResults(await repos.kombaxSocial.directory(q,50).catch(()=>[]));},250);});
  let profileTimer=null;profileQuery?.addEventListener('input',()=>{clearTimeout(profileTimer);profileTimer=setTimeout(async()=>{const q=profileQuery.value.trim();if(q.length<2){renderProfileResults([]);return;}profileResults.innerHTML='<p>Buscando perfiles…</p>';renderProfileResults(await repos.kombaxSocial.directory(q,50).catch(()=>[]));},250);});
  typePicker?.querySelectorAll('[data-kx-audience-type]').forEach(input=>input.addEventListener('change',()=>{const value=String(input.dataset.kxAudienceType);if(input.checked)profileTypes.add(value);else profileTypes.delete(value);updateCounts();}));
  const refresh=()=>{const m=mode(),showClubs=['clubes_seleccionados','kombax_excepto'].includes(m);clubPicker.hidden=!showClubs;profilePicker.hidden=m!=='perfiles_seleccionados';typePicker.hidden=m!=='tipos_perfil';if(showClubs){clubTitle.textContent=m==='kombax_excepto'?'Excluir estos clubes':'Visible para estos clubes';clubHelp.textContent=m==='kombax_excepto'?'La publicación seguirá visible en KOMBAX excepto para los clubes seleccionados. No rompe relaciones, mensajes ni Events.':'Solo las cuentas vinculadas a los clubes seleccionados podrán verla.';renderClubResults([]);}if(m==='perfiles_seleccionados')renderProfileResults([]);updateCounts();};
  audience.addEventListener('change',refresh);refresh();
  return {clubIds,excludedClubIds,profileIds,profileTypes,refresh};
}

function bindMediaOrientation(){
  document.querySelectorAll('[data-kx-orientation-source]').forEach(media=>{const apply=()=>{const w=media.tagName==='VIDEO'?media.videoWidth:media.naturalWidth,h=media.tagName==='VIDEO'?media.videoHeight:media.naturalHeight;if(!w||!h)return;const ratio=w/h;const orientation=ratio<.86?'portrait':ratio>1.16?'landscape':'square';media.dataset.kxMediaOrientation=orientation;media.closest('[data-kx-media-shell]')?.setAttribute('data-kx-media-orientation',orientation);};if(media.tagName==='VIDEO'){media.addEventListener('loadedmetadata',apply,{once:true});if(media.readyState>=1)apply();}else{media.addEventListener('load',apply,{once:true});if(media.complete)apply();}});
}

function socialPromotionCard(p){
  if(!p?.campaign_id)return '';
  const isEvent=String(p.content_type)==='event';
  const image=String(p.image_url||'').trim();
  return `<article class="kx-social-promotion" data-kx-promotion="${esc(p.campaign_id)}"><div class="kx-social-promotion-media">${image?`<img src="${esc(image)}" alt="" loading="lazy" decoding="async">`:`<span>${icon(isEvent?'arena':'shoppingBag',{size:30})}</span>`}</div><div class="kx-social-promotion-copy"><small>${esc(p.label||t('social.promotion.featured'))} · ${t('social.promotion.promoted')}</small><strong>${esc(p.title||t('social.promotion.featuredContent'))}</strong><p>${esc(p.subtitle||t('social.promotion.discover'))}</p><button type="button" class="btn btn-primary btn-sm" ${isEvent?`data-social-promoted-event="${esc(p.target_slug||'')}"`:`data-social-promoted-showcase="${esc(p.content_id)}"`}>${isEvent?t('social.promotion.viewEvent'):t('social.promotion.viewProduct')}</button></div></article>`;
}

function eventLinkCard(link){
  if(!link)return '';
  const hasFight=Boolean(link.combate_id);const aPhoto=String(link.a_foto_url||'').trim();const bPhoto=String(link.b_foto_url||'').trim();
  const fight=hasFight?`<div class="kx-social-event-fight"><span>${esc(link.a_nombre||t('social.event.fighterA'))}</span><b>VS</b><span>${esc(link.b_nombre||t('social.event.fighterB'))}</span></div>`:'';
  const result=link.link_tipo==='resultado'&&link.resultado?`<strong class="kx-social-event-result">${esc(link.resultado)}</strong>`:'';
  const fightVisual=hasFight?`<div class="kx-social-event-duel"><span class="a">${aPhoto?`<img src="${esc(aPhoto)}" alt="">`:'<i></i>'}</span><b>VS</b><span class="b">${bPhoto?`<img src="${esc(bPhoto)}" alt="">`:'<i></i>'}</span></div>`:'';
  return `<button type="button" class="kx-social-event-link ${hasFight?'has-fighters':''}" data-social-event-slug="${esc(link.evento_slug)}"${link.combate_id?` data-social-event-fight="${esc(link.combate_id)}"`:''}><div class="kx-social-event-art"><img src="${esc(link.cartel_url||`./assets/events/templates/event-poster-${['arena','federation','seminar'].includes(link.tema_visual)?link.tema_visual:'fight'}.svg`)}" alt="">${fightVisual}</div><div class="kx-social-event-copy"><small>${t('social.event.label')} · ${esc(link.evento_tipo||t('social.types.event'))}</small><strong>${esc(link.evento_nombre)}</strong>${fight}${result}<span>${esc([link.lugar_nombre,link.municipio].filter(Boolean).join(' · ')||t('social.event.view'))}</span></div><i>${icon('chevronRight',{size:18})}</i></button>`;
}

function feedCards(){
  if(!posts.length)return `${empty('Todavía no hay publicaciones','Los clubes, miembros y perfiles KOMBAX autorizados pueden compartir aquí su actividad pública.')}${done?'':'<span id="kombax-social-sentinel" class="kx-feed-sentinel" aria-hidden="true"></span>'}`;
  return `<div class="kombax-social-feed">${posts.map((p,index)=>`<article class="kombax-social-post">
    <header class="kx-social-post-head"><div class="kx-social-author-open" data-social-profile-open="${esc(p.autor_id)}" tabindex="0" role="button" aria-label="Ver perfil público de ${esc(p.autor_nombre)}"><div class="kombax-social-avatar">${profileAvatar(p)}</div><div class="kx-social-author-copy"><strong>${esc(p.autor_nombre)} ${verified(p.autor_verificado,p.autor_tipo)}</strong><small>${dtFmt(p.creado_en)} · ${esc(PUBLIC_TYPE_LABEL[p.autor_tipo]||PROFILE_LABEL[p.autor_tipo]||p.autor_tipo)}</small>${affiliationChip(p)}<span class="kx-social-profile-cue">Ver perfil</span></div></div><details class="kx-post-menu"><summary aria-label="Opciones de la publicación">${icon('more',{size:20})}</summary><div class="kx-post-menu-popover">
      <button type="button" data-social-save="${esc(p.id)}" data-active="${p.saved_by_me?'true':'false'}">${icon('archive',{size:16})} ${p.saved_by_me?'Quitar de guardados':'Guardar publicación'}</button>
      ${p.contactable&&!isOwn(p.autor_id)?`<button type="button" data-social-contact="${esc(p.autor_id)}" data-social-name="${esc(p.autor_nombre)}">${icon('message',{size:16})} Contactar</button>`:''}
      ${isOwn(p.autor_id)&&p.social_media_id?`<button type="button" data-social-frame="${esc(p.id)}">${icon('image',{size:16})} Ajustar encuadre</button>`:''}${isOwn(p.autor_id)&&p.social_media_id&&p.media_tipo==='video'?`<button type="button" data-social-cover="${esc(p.id)}">${icon('image',{size:16})} Elegir portada del vídeo</button>`:''}
      ${!isOwn(p.autor_id)?`<button type="button" data-social-report-post="${esc(p.id)}">${icon('alert',{size:16})} Denunciar</button><button type="button" data-social-block="${esc(p.autor_id)}" data-social-name="${esc(p.autor_nombre)}">${icon('shield',{size:16})} Bloquear perfil</button>`:`<button type="button" data-social-visibility="${esc(p.id)}">${icon('eye',{size:16})} Visibilidad</button><button type="button" data-social-delete="${esc(p.id)}">${icon('trash',{size:16})} Eliminar publicación</button>`}
    </div></details></header>
    <div class="kx-social-post-meta">${audienceChip(p)}${badge(TYPE_LABEL[p.tipo]||p.tipo,p.tipo==='oportunidad'?'warn':'neutral')}</div>
    <p class="kx-social-post-text" ${contentTranslationAttrs({contentId:p.id,contentType:'social_post',fieldName:'text',sourceLocale:p.source_locale||p.idioma||'',visibility:'public'})}>${esc(p.texto).replace(/\n/g,'<br>')}</p>${postMedia(p)}${eventLinkCard(p.event_link)}
    <div class="kx-social-engagement-summary"><span class="kx-social-like-count">${icon('heart',{size:14})}<b>${Number(p.likes_count||0)}</b> ${Number(p.likes_count||0)===1?'Me gusta':'Me gusta'}</span><button type="button" data-social-comments="${esc(p.id)}" aria-expanded="${expandedCommentPostId===String(p.id)?'true':'false'}"><span data-social-comments-count="${esc(p.id)}">${Number(p.comentarios_count||0)}</span> comentarios</button></div>
    ${!isOwn(p.autor_id)?`<footer class="kx-social-primary-actions">
      <button type="button" class="social-like ${p.liked_by_me?'active':''}" data-social-like="${esc(p.id)}" data-active="${p.liked_by_me?'true':'false'}" aria-pressed="${p.liked_by_me?'true':'false'}">${icon('heart',{size:19})}<span>Me gusta</span></button>
      <details class="kx-interest-control"><summary class="${Number(p.interest_by_me||0)===1?'positive':Number(p.interest_by_me||0)===-1?'negative':''}" aria-label="Preferencia privada de contenido">${icon(Number(p.interest_by_me||0)===-1?'thumbsDown':'thumbsUp',{size:19})}<span>${Number(p.interest_by_me||0)===-1?'No me interesa':Number(p.interest_by_me||0)===1?'Me interesa':'Interés'}</span></summary><div class="kx-interest-popover"><button type="button" data-social-preference="${esc(p.id)}" data-value="1" class="${Number(p.interest_by_me||0)===1?'active':''}">${icon('thumbsUp',{size:17})}<span><b>Me interesa</b><small>Señal privada · ver más contenido parecido</small></span></button><button type="button" data-social-preference="${esc(p.id)}" data-value="-1" class="${Number(p.interest_by_me||0)===-1?'active':''}">${icon('thumbsDown',{size:17})}<span><b>No me interesa</b><small>Señal privada · reducir contenido parecido</small></span></button>${Number(p.interest_by_me||0)!==0?`<button type="button" data-social-preference="${esc(p.id)}" data-value="0">${icon('refresh',{size:17})}<span><b>Sin preferencia</b><small>Volver al ranking neutral</small></span></button>`:''}</div></details>
      <button type="button" data-social-comments="${esc(p.id)}" aria-expanded="${expandedCommentPostId===String(p.id)?'true':'false'}">${icon('message',{size:19})}<span>Comentar</span></button>
      ${p.audiencia==='publica'?`<button type="button" data-social-share="${esc(p.id)}" data-social-share-text="${esc(`${p.autor_nombre}: ${p.texto}`)}">${icon('arrowUpRight',{size:19})}<span>Compartir</span></button>`:'<span class="kx-action-disabled">'+icon('lock',{size:18})+' Restringida</span>'}
    </footer>`:''}
    <section class="kx-inline-comments" data-kx-comments-panel="${esc(p.id)}" ${expandedCommentPostId===String(p.id)?'':'hidden'}><div class="loading-card">Cargando comentarios…</div></section>
  </article>${index===1&&socialPromotions[0]?socialPromotionCard(socialPromotions[0]):index===5&&socialPromotions[1]?socialPromotionCard(socialPromotions[1]):''}`).join('')}</div>${done?'':'<div class="kx-feed-more"><button type="button" class="btn btn-ghost kombax-load-more" id="kombax-social-more">Cargar más</button><span id="kombax-social-sentinel" class="kx-feed-sentinel" aria-hidden="true"></span></div>'}`;
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
  const audienceClubIds=new Set(),audienceExcludedClubIds=new Set(),audienceProfileIds=new Set(),audienceProfileTypes=new Set();
  const modal=openForm({
    title:'Publicar en KOMBAX Social',
    subtitle:'Elige identidad y audiencia. KOMBAX Social es exclusivo de artes marciales y deportes de contacto; el contenido fuera de temática puede ser retirado por moderación.',
    width:'860px',
    fields:[
      {name:'autor',label:'Publicar como',type:'select',required:true,value:initial.id,options:ownProfiles.map(p=>({value:p.id,label:identityLabel(p)}))},
      {name:'tipo',label:'Tipo',type:'select',required:true,value:'actualizacion',options:Object.entries(TYPE_LABEL).map(([value,label])=>({value,label}))},
      {name:'comentarios_estado',label:'Comentarios',type:'select',required:true,value:'open',options:[{value:'open',label:'Abiertos'},{value:'verified_only',label:'Solo perfiles verificados'},{value:'closed',label:'Cerrados'}]},
      {name:'audiencia',label:'Audiencia',type:'select',required:true,value:audienceKey(audienceOptions(initial.id)[0]),options:audienceOptions(initial.id).map(a=>({value:audienceKey(a),label:a.label})),help:'El perfil seguirá siendo público. Esta opción solo restringe esta publicación.'},
      {name:'archivo',label:'Subir foto o vídeo',type:'file',accept:'image/jpeg,image/png,image/webp,video/mp4,video/webm,video/quicktime',full:true,help:'Opcional. Vídeo MP4 recomendado · HD hasta 1080p · máximo 60 segundos y 100 MB. Se mostrará únicamente a la audiencia elegida para esta publicación.'},
      {name:'guardar_album',label:'Guardar también este archivo en el álbum de la identidad',type:'checkbox',value:true,full:true},
      {name:'media_id',label:'O elegir del álbum',type:'select',options:[],full:true,help:'Si subes un archivo nuevo, tendrá prioridad sobre esta selección.'},
      {name:'texto',label:'Contenido',type:'textarea',required:true,full:true,rows:7,maxLength:1500,help:'Máximo 1.500 caracteres. Publica solo contenido relacionado con artes marciales/deportes de contacto. No publiques teléfonos, direcciones ni datos privados de terceros.'}
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
            newSocialMedia=await repos.kombaxSocial.attachAlbumMedia(profile.id,'club',newClubMedia.id,newClubMedia.media_presentation||{});socialMediaId=newSocialMedia.id;
          }else if(v.guardar_album===true&&profile.sujeto_tipo==='perfil_directo'){
            newDirectMedia=await repos.kombaxProfiles.uploadMedia(profile.perfil_directo_id,mediaType,v.archivo);
            newSocialMedia=await repos.kombaxSocial.attachAlbumMedia(profile.id,'perfil_directo',newDirectMedia.id,newDirectMedia.media_presentation||{});socialMediaId=newSocialMedia.id;
          }else{
            newSocialMedia=await repos.kombaxSocial.uploadMedia(profile.id,mediaType,v.archivo,{enAlbum:v.guardar_album===true,audience:aud.audiencia});socialMediaId=newSocialMedia.id;
          }
        }else if(v.media_id){
          const source=(mediaByProfile.get(profile.id)||[]).find(x=>String(x.id)===String(v.media_id));
          if(source){
            if(source._source_type==='social')socialMediaId=source.id;
            else{
              const alreadyAttached=(await repos.kombaxSocial.media(profile.id)).find(x=>x.estado==='active'&&x.storage_path===source.storage_path);
              if(alreadyAttached){socialMediaId=alreadyAttached.id;if(source.media_presentation&&Object.keys(source.media_presentation).length)await repos.mediaFraming.set('social_media',alreadyAttached.id,source.media_presentation).catch(()=>{});}
              else{newSocialMedia=await repos.kombaxSocial.attachAlbumMedia(profile.id,source._source_type,source.id,source.media_presentation||{});socialMediaId=newSocialMedia.id;}
            }
          }
        }
        const published=await repos.kombaxSocial.publish(profile.id,v.tipo,v.texto,{comentarios_estado:v.comentarios_estado,social_media_id:socialMediaId,...aud,audiencia_club_ids:[...audienceClubIds],audiencia_excluded_club_ids:[...audienceExcludedClubIds],audiencia_profile_ids:[...audienceProfileIds],audiencia_profile_types:[...audienceProfileTypes]});const publishedId=published?.id||published?.post_id||published?.data?.id;if(publishedId)void prewarmUserContentTranslations({contentId:publishedId,contentType:'social_post',fieldName:'text',text:v.texto,visibility:aud.audiencia==='publica'?'public':'tenant'});
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
  let audienceControls=attachAudienceSelectors({form:modal.form,audience,clubIds:audienceClubIds,excludedClubIds:audienceExcludedClubIds,profileIds:audienceProfileIds,profileTypes:audienceProfileTypes});
  const refreshAudience=()=>{const rows=audienceOptions(author.value);audience.innerHTML=rows.map(a=>`<option value="${esc(audienceKey(a))}">${esc(a.label)}</option>`).join('');audience.value=audienceKey(rows[0]);audienceClubIds.clear();audienceExcludedClubIds.clear();audienceProfileIds.clear();audienceProfileTypes.clear();audienceControls.refresh();};
  const refreshMedia=()=>{const rows=mediaByProfile.get(author.value)||[];const restricted=parseAudience(audience.value).audiencia!=='publica';media.innerHTML='<option value="">Sin multimedia del álbum</option>'+rows.map(x=>`<option value="${esc(x.id)}">${x.tipo==='video'?'Vídeo':'Foto'}${x.tipo==='video'?` · ${Number(x.duration_seconds||0).toFixed(1)} s`:''}</option>`).join('');media.disabled=restricted||!rows.length;if(restricted){media.value='';album.checked=false;album.disabled=true;}else album.disabled=false;};
  author.addEventListener('change',()=>{refreshAudience();refreshMedia();});audience.addEventListener('change',refreshMedia);refreshAudience();refreshMedia();

}

async function activateSocial(){
  let rules=null;try{rules=await repos.socialGeneral.rules();}catch{}
  const minorSafety=socialStatus?.minor===true?`<div class="alert alert-warning"><strong>Seguridad para menores</strong><span>No compartas teléfono, dirección, centro educativo, documentos, contraseñas ni ubicación en tiempo real. No quedes a solas con personas conocidas únicamente por Internet sin conocimiento de un adulto responsable. Bloquea y denuncia cualquier interacción incómoda. El chat privado permanece desactivado hasta los 18 años. <a href="./child-safety.html" target="_blank" rel="noopener">Ver estándares de seguridad infantil</a>.</span></div><label class="kombax-social-consent"><input type="checkbox" id="social-minor-safety-ok"> <span>He leído este recordatorio de seguridad, sé cómo bloquear y denunciar y entiendo que mi tutor puede desactivar Social.</span></label>`:'';
  const {wrap}=openDetail({title:'Activar KOMBAX Social',subtitle:`Normas ${esc(rules?.version||'1.1.0')} · Perfil público opcional`,body:`<div class="legal-document"><p>${esc(rules?.cuerpo||'Lee y acepta las normas de KOMBAX Social.').replace(/\n\n/g,'</p><p>').replace(/\n/g,'<br>')}</p></div>${minorSafety}<label class="kombax-social-consent"><input type="checkbox" id="social-rules-ok"> <span>He leído y acepto las normas.</span></label><label class="kombax-social-consent"><input type="checkbox" id="social-privacy-ok"> <span>Entiendo que se crea una identidad pública separada de mi expediente privado.</span></label>`,actions:'<button type="button" class="btn btn-primary" id="social-activate-confirm">Activar perfil</button>',width:'820px'});
  wrap.querySelector('#social-activate-confirm')?.addEventListener('click',async()=>{const button=wrap.querySelector('#social-activate-confirm');const safetyOk=socialStatus?.minor!==true||wrap.querySelector('#social-minor-safety-ok')?.checked;if(!wrap.querySelector('#social-rules-ok')?.checked||!wrap.querySelector('#social-privacy-ok')?.checked||!safetyOk){toast(socialStatus?.minor===true?'Debes aceptar las normas, la privacidad y el recordatorio de seguridad.':'Debes aceptar ambas condiciones.','error');return;}button.disabled=true;try{const consent={acepta_normas:true,acepta_privacidad:true,acepta_seguridad_menor:socialStatus?.minor===true};if(socialStatus?.scope==='global'&&socialStatus?.direct_profile_id)await repos.kombaxSocial.activateDirect(socialStatus.direct_profile_id,consent);else await repos.kombaxIdentity.activateMember(consent);closeModal();toast('Perfil KOMBAX Social activado');await renderKombaxSocial();}catch(error){button.disabled=false;const msg=String(error?.message||error||'');if(/KOMBAX_SOCIAL_GUARDIAN_CONSENT_REQUIRED|KOMBAX_SOCIAL_GUARDIAN_LINK_REQUIRED/.test(msg)){try{await repos.kombaxSocial.requestMinorConsent();closeModal();toast('Solicitud enviada a tu tutor vinculado');await renderKombaxSocial();}catch(requestError){setError(requestError);}return;}setError(error);}});
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
  const msgHtml=m=>{const report=!m.propio&&!/^\[Mensaje retirado/.test(String(m.texto||''))?(isShowcase()?`<button type="button" class="kx-message-report kx-message-options" data-kx-message-report="${esc(m.id)}" aria-label="Opciones del mensaje" title="Opciones del mensaje">${icon('more',{size:16})}</button>`:`<button type="button" class="kx-message-report" data-kx-message-report="${esc(m.id)}" aria-label="Denunciar mensaje">${icon('alert',{size:13})} Denunciar</button>`):'';return `<article class="kx-contact-message ${m.propio?'own':'other'}" data-message-id="${esc(m.id)}" data-ordinal="${Number(m.ordinal)||0}"><small>${esc(m.autor_nombre)} · ${dtFmt(m.creado_en)}</small><p ${contentTranslationAttrs({contentId:m.id,contentType:'social_message',fieldName:'text',sourceLocale:m.source_locale||m.idioma||'',visibility:'private',auto:false})}>${esc(m.texto).replace(/\n/g,'<br>')}</p><footer>${receiptHtml(m)}${report}</footer></article>`;};
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
    root.querySelectorAll('[data-kx-message-report]').forEach(b=>b.addEventListener('click',()=>openForm({title:'Denunciar mensaje',subtitle:'Moderación recibirá únicamente este mensaje y el contexto que añadas, no acceso general a tu conversación.',fields:[{name:'motivo',label:'Motivo',type:'select',required:true,value:'acoso',options:[{value:'acoso',label:'Acoso'},{value:'odio_discriminacion',label:'Odio o discriminación'},{value:'violencia',label:'Violencia o amenaza'},{value:'sexual_menores',label:'Riesgo o sexualización de menores'},{value:'privacidad',label:'Privacidad'},{value:'spam',label:'Spam'},{value:'suplantacion',label:'Suplantación'},{value:'otro',label:'Otro'}]},{name:'detalle',label:'Contexto adicional',type:'textarea',full:true,rows:4,maxLength:1500}],submitText:'Enviar denuncia',onSubmit:async v=>{await repos.kombaxSocial.reportMessage(b.dataset.kxMessageReport,v.motivo,v.detalle||'');toast('Mensaje denunciado. Moderación recibirá solo la evidencia asociada.');}})));
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
  const reasons=[...(type==='publicacion'?[{value:'fuera_tematica',label:'Contenido fuera de temática · no relacionado con deportes de contacto'}]:[]),{value:'acoso',label:'Acoso'},{value:'odio_discriminacion',label:'Odio o discriminación'},{value:'violencia',label:'Violencia ilícita'},{value:'sexual_menores',label:'Riesgo o sexualización de menores'},{value:'privacidad',label:'Privacidad'},{value:'spam',label:'Spam'},{value:'suplantacion',label:'Suplantación'},{value:'otro',label:'Otro'}];
  openForm({title:'Denunciar en KOMBAX Social',subtitle:type==='publicacion'?'Moderación revisará también si el contenido respeta la temática exclusiva de artes marciales y deportes de contacto.':'La denuncia será revisada por moderación global.',fields:[{name:'motivo',label:'Motivo',type:'select',required:true,value:type==='publicacion'?'fuera_tematica':'spam',options:reasons},{name:'detalle',label:'Contexto',type:'textarea',full:true,rows:4,maxLength:1500}],submitText:'Enviar denuncia',onSubmit:async v=>{if(type==='publicacion'&&v.motivo==='fuera_tematica')await repos.kombaxSocial.reportOffTopic(id,v.detalle||'');else await repos.kombaxSocial.report(type,id,v.motivo,v.detalle||'');toast('Denuncia enviada');}});
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
    const one=c=>`<article class="kx-comment ${c.parent_id?'reply':''}"><button type="button" class="kombax-social-avatar kx-comment-author-open" data-social-profile-open="${esc(c.autor_id)}" aria-label="Ver perfil público de ${esc(c.autor_nombre)}">${c.autor_avatar_url||c.autor_avatar_path?`<img src="${esc(c.autor_avatar_url||mediaUrl(c.autor_avatar_path))}" alt="">`:`<span>${esc(initials(c.autor_nombre))}</span>`}</button><div><header><button type="button" class="kx-comment-author-name" data-social-profile-open="${esc(c.autor_id)}">${esc(c.autor_nombre)} ${verified(c.autor_verificado,c.autor_tipo)}</button><small>${dtFmt(c.creado_en)}</small></header><p ${contentTranslationAttrs({contentId:c.id,contentType:'social_comment',fieldName:'text',sourceLocale:c.source_locale||c.idioma||'',visibility:'public'})}>${esc(c.texto)}</p><footer>${!c.parent_id&&post.comentarios_estado!=='closed'&&allowedProfiles.length?`<button class="btn btn-ghost btn-sm" data-kx-reply="${esc(c.id)}">Responder</button>`:''}${c.propio?`<button class="btn btn-ghost btn-sm" data-kx-comment-remove="${esc(c.id)}">Eliminar</button>`:`<button class="btn btn-ghost btn-sm" data-kx-comment-report="${esc(c.id)}">${icon('alert',{size:14})} Denunciar</button>`}</footer></div></article>`;
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
    panel.querySelector('[data-kx-comment-form]')?.addEventListener('submit',async e=>{e.preventDefault();const form=e.currentTarget,button=form.querySelector('button[type="submit"]'),text=String(form.elements.texto?.value||'').trim(),author=form.elements.autor?.value;if(!text||!author)return;button.disabled=true;try{const created=await repos.kombaxSocial.comment(postId,author,text,form.dataset.parentId||null);const commentId=created?.id||created?.comment_id||created?.data?.id;if(commentId)void prewarmUserContentTranslations({contentId:commentId,contentType:'social_comment',fieldName:'body',text,visibility:'public'});toast(form.dataset.parentId?'Respuesta publicada':'Comentario publicado');await renderInlineComments(postId,null);}catch(error){button.disabled=false;setError(error);}});
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
  const base=String(window.UW_CONFIG?.release?.webUrl||'https://kombax.es').replace(/\/+$/,'');
  const url=`${base}/#social`;
  try{
    if(navigator.share)await navigator.share({title:'KOMBAX Social',text,url});
    else if(navigator.clipboard){await navigator.clipboard.writeText(`${text}\n${url}`);toast('Enlace copiado');}
    else toast('Comparte la URL de KOMBAX Social desde el navegador.');
  }catch(error){if(error?.name!=='AbortError')setError(error);}
}

function requestRelation(target){return requestNetworkConnection(target,{onSent:()=>{if(activeView==='relations')return renderRelations();}});}


async function openVisibilityEditor(post){
  if(!post||!isOwn(post.autor_id))return;
  let config;try{config=await repos.kombaxSocial.visibilityConfig(post.id);}catch(error){setError(error);return;}
  const rows=audienceOptions(post.autor_id);const current=rows.find(a=>a.audiencia===config.audiencia&&String(a.target_social_id||'')===String(config.audiencia_federacion_social_id||'')&&String(a.target_club_id||'')===String(config.audiencia_club_id||''))||rows.find(a=>a.audiencia===config.audiencia)||rows[0];
  const clubIds=new Set((config.club_ids||[]).map(String)),excludedClubIds=new Set((config.excluded_club_ids||[]).map(String)),profileIds=new Set((config.profile_ids||[]).map(String)),profileTypes=new Set((config.profile_types||[]).map(String));
  let controls=null;
  const modal=openForm({title:'Visibilidad de la publicación',subtitle:'Decide quién puede ver este contenido. Cambiar la audiencia no elimina relaciones, mensajes ni participación en Events.',width:'760px',fields:[{name:'audiencia',label:'Visible para',type:'select',required:true,value:audienceKey(current),options:rows.map(a=>({value:audienceKey(a),label:a.label})),help:'Puedes dirigir el contenido a toda KOMBAX, tu red, clubes, federaciones, perfiles concretos o tipos de perfil.'}],submitText:'Guardar visibilidad',onSubmit:async v=>{const aud=parseAudience(v.audiencia);const targetPublic=aud.audiencia==='publica';if(config.media_bucket&&((targetPublic&&config.media_bucket!=='kombax-public-media')||(!targetPublic&&config.media_bucket!=='kombax-restricted-media')))throw new Error(targetPublic?'Esta publicación usa multimedia privada. Para hacerla pública, vuelve a publicar el archivo como contenido público.':'Esta publicación usa multimedia pública. Para restringirla de forma segura, vuelve a publicar el archivo con la audiencia privada elegida.');await repos.kombaxSocial.setVisibility(post.id,{...aud,audiencia_club_ids:[...controls.clubIds],audiencia_excluded_club_ids:[...controls.excludedClubIds],audiencia_profile_ids:[...controls.profileIds],audiencia_profile_types:[...controls.profileTypes]});toast('Visibilidad actualizada');await loadFeed(false);}});
  const audience=modal.form.elements.audiencia;controls=attachAudienceSelectors({form:modal.form,audience,clubIds,excludedClubIds,profileIds,profileTypes,initialClubs:config.club_selections||[],initialProfiles:config.profile_selections||[]});
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
    try{const aud=parseAudience(document.getElementById('kx-social-quick-audience')?.value);const published=await repos.kombaxSocial.publish(profile.id,'actualizacion',text,{comentarios_estado:'open',...aud});const publishedId=published?.id||published?.post_id||published?.data?.id;if(publishedId)void prewarmUserContentTranslations({contentId:publishedId,contentType:'social_post',fieldName:'text',text,visibility:aud.audiencia==='publica'?'public':'tenant'});input.value='';toast(`Publicado como ${profile.nombre_publico}`);await refreshActiveQuota();update();await loadFeed(false);document.getElementById('kombax-social-feed-top')?.scrollIntoView({behavior:'smooth',block:'start'});}
    catch(error){const msg=String(humanError(error)||'');if(msg.includes('KOMBAX_POST_ACTIVE_LIMIT_30')){toast('Has alcanzado tus 30 publicaciones activas. Elimina una para poder publicar otra.','error');openKombaxPostManager(profile,{onChanged:async()=>{await refreshActiveQuota();await loadFeed(false);}});}else if(msg.includes('KOMBAX_POST_DAILY_LIMIT_3'))toast('Has alcanzado el máximo de 3 publicaciones de hoy. Podrás volver a publicar mañana.','error');else{setError(error);toast(msg||'No se pudo publicar.','error');}}
    finally{if(button){button.innerHTML=original;update();}}
  });
}

function isBackendVersionMismatch(error){const raw=String(error?.message||error||'');return /PGRST202|schema cache|could not find the function|app_kombax_.*_v147/i.test(raw)}
function socialUnavailable(error){return isBackendVersionMismatch(error)?'<div class="alert alert-danger"><strong>KOMBAX Social pendiente de sincronización</strong><span>La interfaz y el backend no están en la misma versión. El acceso Social queda bloqueado para evitar mezclar identidades o clubes hasta completar la actualización segura.</span></div>':empty('KOMBAX Social no disponible',humanError(error)||'No se pudo completar la operación.')}

function bindCommon(){
  document.querySelectorAll('[data-social-view]').forEach(b=>b.addEventListener('click',()=>{const next=b.dataset.socialView;if(next==='contacts'){try{sessionStorage.setItem('kombax_conversation_channel','social')}catch{};location.hash='#conversations';return;}activeView=next;renderKombaxSocial();}));
  document.getElementById('kombax-social-publish')?.addEventListener('click',openPublisher);
  document.getElementById('kombax-social-activate')?.addEventListener('click',activateSocial);
  document.getElementById('kx-social-info')?.addEventListener('click',openSocialInfoPanel);
}

function bindFeed(){
  document.querySelectorAll('[data-social-profile-open]').forEach(el=>{const open=()=>openKombaxPublicProfile(el.dataset.socialProfileOpen);el.addEventListener('click',e=>{if(e.target.closest('button,a')&&e.currentTarget!==e.target)return;open();});el.addEventListener('keydown',e=>{if((e.key==='Enter'||e.key===' ')&&!e.target.closest('button,a')){e.preventDefault();open();}});});
  document.querySelectorAll('[data-social-affiliation-club]').forEach(b=>b.addEventListener('click',e=>{e.stopPropagation();openKombaxPublicProfile(b.dataset.socialAffiliationClub);}));
  document.querySelectorAll('[data-social-media-open]').forEach(b=>b.addEventListener('click',()=>{const post=posts.find(x=>String(x.id)===String(b.dataset.socialMediaOpen));if(post)openSocialMediaViewer(post);}));
  document.querySelectorAll('[data-social-video-open]').forEach(b=>b.addEventListener('click',e=>{e.stopPropagation();const post=posts.find(x=>String(x.id)===String(b.dataset.socialVideoOpen));if(post)openSocialMediaViewer(post,b.closest('[data-kx-media-shell]')?.querySelector('video')||null);}));
  document.querySelectorAll('[data-social-frame]').forEach(b=>b.addEventListener('click',()=>{const post=posts.find(x=>String(x.id)===String(b.dataset.socialFrame));if(!post?.social_media_id)return;const src=post.media_url||mediaUrl(post.media_path);const mediaType=post.media_tipo==='video'?'video':'image';openMediaFramingEditor({title:'Ajustar encuadre de la publicación',subtitle:'Elige entre ver el contenido completo o rellenar el marco. El original completo seguirá disponible al abrirlo.',src,mediaType,initial:post.media_presentation,preset:'social',onSave:async presentation=>{await repos.mediaFraming.set('social_media',post.social_media_id,presentation);post.media_presentation=presentation;await loadFeed(false);}});}));
  document.querySelectorAll('[data-social-cover]').forEach(b=>b.addEventListener('click',()=>{const post=posts.find(x=>String(x.id)===String(b.dataset.socialCover));if(!post?.social_media_id||post.media_tipo!=='video')return;const src=post.media_url||mediaUrl(post.media_path);openVideoCoverEditor({src,initial:post.media_presentation,title:'Portada del vídeo · KOMBAX Social',subtitle:'Usa la automática, elige un fotograma exacto o sube una imagen propia.',onSave:async({file,mode,time})=>{const media={id:post.social_media_id,storage_bucket:post.media_bucket||'kombax-public-media',social_profile_id:post.autor_id};const saved=await repos.kombaxSocial.setVideoCover(media,file,{presentation:post.media_presentation||{},mode,time});post.media_presentation=saved.presentation;post.media_cover_url=await repos.kombaxSocial.mediaAccessUrl(saved.path,saved.bucket).catch(()=> '');await loadFeed(false);}});}));
  document.querySelectorAll('[data-social-save]').forEach(b=>b.addEventListener('click',async()=>{if(b.disabled)return;b.disabled=true;const active=b.dataset.active==='true';try{await repos.kombaxSocial.save(b.dataset.socialSave,!active);await loadFeed(false);}catch(error){b.disabled=false;setError(error);}}));
  document.querySelectorAll('[data-social-like]').forEach(b=>b.addEventListener('click',async()=>{if(b.disabled)return;b.disabled=true;const active=b.dataset.active==='true';try{await repos.kombaxSocial.like(b.dataset.socialLike,!active);await loadFeed(false);}catch(error){b.disabled=false;setError(error);}}));
  document.querySelectorAll('[data-social-preference]').forEach(b=>b.addEventListener('click',async()=>{if(b.disabled)return;b.disabled=true;try{await repos.kombaxSocial.preference(b.dataset.socialPreference,Number(b.dataset.value));toast(Number(b.dataset.value)===1?'Me interesa · señal privada guardada para mejorar tu feed':Number(b.dataset.value)===-1?'No me interesa · señal privada para reducir contenido parecido':'Preferencia eliminada');await loadFeed(false);}catch(error){b.disabled=false;setError(error);}}));
  document.querySelectorAll('[data-social-visibility]').forEach(b=>b.addEventListener('click',()=>{const post=posts.find(x=>String(x.id)===String(b.dataset.socialVisibility));if(post)openVisibilityEditor(post);}));
  document.querySelectorAll('[data-social-comments]').forEach(b=>b.addEventListener('click',()=>toggleInlineComments(b.dataset.socialComments)));
  document.querySelectorAll('[data-social-event-slug]').forEach(button=>button.addEventListener('click',()=>{const u=new URL(location.href);u.search='';u.hash='';u.searchParams.set('event',button.dataset.socialEventSlug);if(button.dataset.socialEventFight)u.searchParams.set('fight',button.dataset.socialEventFight);location.href=u.toString();}));
  document.querySelectorAll('[data-social-promoted-event]').forEach(button=>button.addEventListener('click',()=>{const slug=button.dataset.socialPromotedEvent;if(!slug)return;const u=new URL(location.href);u.search='';u.hash='';u.searchParams.set('event',slug);location.href=u.toString();}));
  document.querySelectorAll('[data-social-promoted-showcase]').forEach(button=>button.addEventListener('click',()=>{try{sessionStorage.setItem('kombax_showcase_open_item',String(button.dataset.socialPromotedShowcase||''));}catch{};location.hash='#showcase';}));
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
  bindMediaOrientation();
  if(expandedCommentPostId)renderInlineComments(expandedCommentPostId,null).catch(setError);
}

async function loadFeed(append=false){
  if(loading)return;loading=true;
  try{
    if(!append){posts=[];cursor=null;done=false;socialPromotions=[];await refreshActiveQuota();}
    const [raw,promotions]=await Promise.all([
      repos.kombaxSocial.feed(cursor,PAGE_SIZE),
      append?Promise.resolve(socialPromotions):repos.kombaxSocial.promotions(2)
    ]);
    if(!append){socialPromotions=Array.isArray(promotions)?promotions:[];}
    const page=await Promise.all((raw||[]).map(async p=>{if(!p.media_path)return p;try{const media_url=await repos.kombaxSocial.mediaAccessUrl(p.media_path,p.media_bucket||'kombax-public-media');const coverPath=String(p.media_presentation?.cover_storage_path||'');let media_cover_url='';if(p.media_tipo==='video'&&coverPath)media_cover_url=await repos.kombaxSocial.mediaAccessUrl(coverPath,p.media_presentation?.cover_storage_bucket||p.media_bucket||'kombax-public-media').catch(()=> '');return {...p,media_url,media_cover_url};}catch{return {...p,media_url:'',media_cover_url:''}}}));
    posts=append?[...posts,...page]:page;
    const last=page.at(-1);if(last)cursor={score:last.relevance_score??null,created:last.creado_en,id:last.id};done=page.length<PAGE_SIZE;
    renderFeedView();
    if(!append&&posts.length>=2&&socialPromotions.length){
      const visiblePromotions=socialPromotions.slice(0,posts.length>=6?2:1);
      await Promise.all(visiblePromotions.map(p=>repos.kombaxSocial.promotionImpression(p.campaign_id).catch(()=>null)));
    }
  }catch(error){setError(error);setMainHtml(`${socialHeader()}${pageHeader('KOMBAX Social','No se pudo cargar KOMBAX Social.','','Red profesional global')}<section class="card">${socialUnavailable(error)}</section>`);}finally{loading=false;}
}

function renderFeedView(){
  setMainHtml(`<div class="kombax-social-page">${socialHeader()}${pageHeader('Actualidad profesional','Los perfiles son públicos. Las publicaciones son públicas por defecto y, si el autor lo elige, pueden limitarse a su club o federación sin convertir el perfil en privado.',socialHeaderActions(ownProfiles.length?'<button type="button" class="btn btn-primary" id="kombax-social-publish">+ Publicar con multimedia</button>':''),'KOMBAX Social')}${tabBar()}${competitorFoundersPromo()}${activationPanel()}${quickComposer()}${feedCards()}</div>`);bindCommon();bindFeed();
}

async function renderProfiles(){
  setMainHtml(`<div class="kombax-social-page">${socialHeader()}${pageHeader('Perfiles públicos','Miembro muestra su comunidad y afiliación al club. Competidor es una identidad deportiva distinta, con verificación y Discovery. Media / Creador publica desde su espacio de contenido.',socialHeaderActions('<button type="button" class="btn btn-ghost" id="kx-social-discovery-open">Descubrir competidores y profesionales</button>'),'KOMBAX Social')}${tabBar()}<div class="kombax-social-search"><input id="kombax-profile-query" type="search" placeholder="Buscar por nombre, club o presentación"><button class="btn btn-primary" id="kombax-profile-search">Buscar</button></div><div id="kombax-profile-results"><div class="loading-card">Buscando perfiles…</div></div></div>`);bindCommon();
  const run=async()=>{const box=document.getElementById('kombax-profile-results'),q=document.getElementById('kombax-profile-query')?.value||'';try{const rows=await repos.kombaxSocial.directory(q,40);box.innerHTML=rows.length?`<div class="kombax-profile-grid">${rows.map(p=>`<article class="kx-profile-card" data-social-profile-open="${esc(p.id)}" tabindex="0" role="button"><div class="kombax-social-avatar large">${profileAvatar(p)}</div><div><strong>${esc(p.nombre_publico)} ${verified(p.verificado,p.perfil_tipo||p.sujeto_tipo)}</strong><small>${esc(PUBLIC_TYPE_LABEL[p.perfil_tipo]||PROFILE_LABEL[p.sujeto_tipo]||p.sujeto_tipo)}</small>${affiliationChip(p)}</div><p>${esc(p.bio||(p.perfil_tipo==='miembro'?'Miembro de la comunidad KOMBAX':'Perfil público KOMBAX'))}</p><div class="row-actions">${p.contactable&&!isOwn(p.id)?`<button class="btn btn-ghost btn-sm" data-social-contact="${esc(p.id)}" data-social-name="${esc(p.nombre_publico)}">Contactar</button>`:''}${!isOwn(p.id)&&ownProfiles.some(x=>possibleRelations(x.perfil_tipo||x.sujeto_tipo,p.perfil_tipo||p.sujeto_tipo).length)?`<button class="btn btn-ghost btn-sm" data-social-relation="${esc(p.id)}">Añadir a mi red</button>`:''}${!isOwn(p.id)?`<button class="btn btn-ghost btn-sm" data-social-report-profile="${esc(p.id)}">Denunciar</button>`:''}</div></article>`).join('')}</div>`:empty('Sin coincidencias','Prueba con otro término.');
    box.querySelectorAll('[data-social-profile-open]').forEach(card=>{const open=()=>openKombaxPublicProfile(card.dataset.socialProfileOpen);card.addEventListener('click',e=>{if(e.target.closest('button,a'))return;open();});card.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();open();}});});
    box.querySelectorAll('[data-social-affiliation-club]').forEach(b=>b.addEventListener('click',e=>{e.stopPropagation();if(b.dataset.socialAffiliationClub)openKombaxPublicProfile(b.dataset.socialAffiliationClub);}));
    box.querySelectorAll('[data-social-contact]').forEach(b=>b.addEventListener('click',()=>openContact(b.dataset.socialContact,b.dataset.socialName)));
    box.querySelectorAll('[data-social-relation]').forEach(b=>b.addEventListener('click',()=>{const target=rows.find(x=>String(x.id)===String(b.dataset.socialRelation));if(target)requestRelation(target);}));
    box.querySelectorAll('[data-social-report-profile]').forEach(b=>b.addEventListener('click',()=>openReport('perfil',b.dataset.socialReportProfile)));
  }catch(error){box.innerHTML=empty('No se pudo buscar',humanError(error)||'Revisa la conexión.');}};
  document.getElementById('kx-social-discovery-open')?.addEventListener('click',()=>openKombaxDiscovery({preset:'all'}));document.getElementById('kombax-profile-search')?.addEventListener('click',run);document.getElementById('kombax-profile-query')?.addEventListener('keydown',e=>{if(e.key==='Enter')run();});await run();
}

async function renderDiscovery(){
  setMainHtml(`<div class="kombax-social-page">${socialHeader()}${pageHeader('Descubrir','Encuentra competidores y profesionales por disciplina, territorio y disponibilidad. Gratis como parte de KOMBAX Social.',socialHeaderActions(),'KOMBAX Social')}${tabBar()}<div id="kx-social-discovery-root"></div></div>`);bindCommon();
  renderKombaxDiscovery(document.getElementById('kx-social-discovery-root'),{preset:'all'});
}

async function renderContacts({standalone=false}={}){
  if(standalone){try{const requested=sessionStorage.getItem('kombax_conversation_channel');if(['social','showcase'].includes(requested))contactFilter=requested;}catch{};if(contactFilter==='all')contactFilter='social';}
  const canOrgAssist=Boolean(state.session?.club_id&&['direccion','coordinacion','secretaria','economia'].includes(String(state.session?.rol||'')));
  const head=standalone?`${pageHeader('Conversaciones KOMBAX','Mensajes y asistencia en una capa propia. Cada canal conserva sus permisos y su contexto.',subviewActions({backId:'kx-conversations-back',closeId:'kx-conversations-close',backLabel:'Volver'}),'Conversaciones')}${conversationChannelTabs(contactFilter,{showAssist:canOrgAssist,showMigrations:canOrgAssist})}`:`${socialHeader()}${pageHeader('Mensajes KOMBAX','Conversaciones privadas de Social y consultas comerciales de Showcase.',socialHeaderActions(),'KOMBAX Social')}${tabBar()}`;
  const filterTabs=standalone?'':`<div class="kx-message-filters" role="tablist" aria-label="Filtrar mensajes"><button type="button" data-message-filter="social" class="${contactFilter==='social'?'active':''}">${icon('users',{size:15})} Social</button><button type="button" data-message-filter="showcase" class="${contactFilter==='showcase'?'active':''}">${icon('shoppingBag',{size:15})} Showcase</button></div>`;
  setMainHtml(`<div class="${standalone?'kx-conversations-page':'kombax-social-page'}">${head}${filterTabs}<div id="kombax-contact-list"><div class="loading-card">Cargando mensajes…</div></div></div>`);
  if(standalone){bindConversationChannelTabs(document,{onSocial:()=>{contactFilter='social';renderContacts({standalone:true})},onShowcase:()=>{contactFilter='showcase';renderContacts({standalone:true})}});bindSubviewActions(document,{backId:'kx-conversations-back',closeId:'kx-conversations-close',onBack:()=>goBackOrFallback('#social'),onClose:()=>{location.hash='#dashboard';}});}else bindCommon();
  const box=document.getElementById('kombax-contact-list');
  try{
    const rows=await repos.kombaxSocial.contacts(contactLimit);
    const visible=rows.filter(c=>contactFilter==='all'||String(c.canal||'social')===contactFilter);
    box.innerHTML=(visible.length?`<div class="kombax-contact-list">${visible.map(c=>{const showcase=String(c.canal||'social')==='showcase';return `<article class="kx-message-card ${showcase?'showcase':'social'}"><header><div><span class="page-kicker">${showcase?'SHOWCASE':esc(c.direccion==='recibida'?'SOCIAL · RECIBIDA':c.direccion==='enviada'?'SOCIAL · ENVIADA':'SOCIAL')} ${showcase&&c.showcase_marca_nombre?`· ${esc(c.showcase_marca_nombre)}`:`· ${esc(CONTACT_LABEL[c.motivo]||c.motivo)}`}</span><strong>${esc(c.remitente_nombre)} → ${esc(c.destinatario_nombre)}</strong></div>${badge(c.estado,c.estado==='aceptada'?'ok':c.estado==='rechazada'||c.estado==='cerrada'?'warn':'neutral')}</header>${showcase?`<div class="kx-message-product">${c.showcase_producto_imagen_url?`<img src="${esc(c.showcase_producto_imagen_url)}" alt="">`:`<span>${icon('shoppingBag',{size:20})}</span>`}<div><small>Producto / servicio</small><strong>${esc(c.showcase_producto_nombre||'Ficha Showcase')}</strong></div></div>`:''}<p>${esc(c.ultimo_mensaje||'Solicitud de contacto')}</p><div class="kx-contact-meta"><small>${dtFmt(c.ultimo_mensaje_en||c.creado_en)}</small><span>${c.estado==='aceptada'?'Conversación abierta':c.estado==='pendiente'?'Pendiente de aceptación':'Conversación finalizada'}</span>${Number(c.no_leidos||0)>0?`<b>${Number(c.no_leidos)} nuevo${Number(c.no_leidos)===1?'':'s'}</b>`:''}</div><div class="row-actions">${c.gestionable?`<button class="btn btn-primary btn-sm" data-contact-state="aceptada" data-contact-id="${esc(c.id)}">Aceptar</button><button class="btn btn-ghost btn-sm" data-contact-state="rechazada" data-contact-id="${esc(c.id)}">Rechazar</button>`:''}<button class="btn btn-ghost btn-sm" data-contact-open="${esc(c.id)}">Abrir conversación</button><button class="btn btn-danger btn-sm" data-contact-delete="${esc(c.id)}">${icon('trash',{size:14})} Eliminar</button></div></article>`;}).join('')}</div>`:empty(contactFilter==='all'?'Sin mensajes':`Sin mensajes ${contactFilter==='showcase'?'Showcase':'Social'}`,contactFilter==='showcase'?'Las consultas iniciadas desde una ficha de Showcase aparecerán aquí con la imagen y el producto asociado.':'Las conversaciones iniciadas desde KOMBAX Social aparecerán aquí.'))+`${rows.length>=contactLimit&&contactLimit<200?'<div class="load-more-wrap"><button class="btn btn-ghost" id="load-more-contacts">Cargar conversaciones anteriores</button></div>':''}`;
    document.getElementById('load-more-contacts')?.addEventListener('click',()=>{contactLimit=Math.min(200,contactLimit+50);renderContacts({standalone});});
    document.querySelectorAll('[data-message-filter]').forEach(b=>b.addEventListener('click',()=>{contactFilter=b.dataset.messageFilter||'social';try{sessionStorage.setItem('kombax_conversation_channel',contactFilter)}catch{};renderContacts({standalone});}));
    box.querySelectorAll('[data-contact-state]').forEach(b=>b.addEventListener('click',async()=>{b.disabled=true;try{await repos.kombaxSocial.contactStatus(b.dataset.contactId,b.dataset.contactState);toast(b.dataset.contactState==='aceptada'?'Solicitud aceptada · contacto abierto':'Solicitud rechazada');await renderContacts({standalone});}catch(error){b.disabled=false;setError(error);}}));
    box.querySelectorAll('[data-contact-open]').forEach(b=>b.addEventListener('click',()=>{const c=rows.find(x=>String(x.id)===String(b.dataset.contactOpen));if(c)openContactThread(c);}));
    box.querySelectorAll('[data-contact-delete]').forEach(b=>b.addEventListener('click',()=>{const c=rows.find(x=>String(x.id)===String(b.dataset.contactDelete));if(!c)return;const actor=ownProfiles.find(p=>p.id===c.remitente_id||p.id===c.destinatario_id);if(!actor){toast('No se puede identificar tu identidad en esta conversación.','error');return;}confirmDialog('Eliminar conversación','Se eliminará de tu bandeja y dejará de admitir nuevos mensajes. La contraparte conservará su historial hasta que también lo elimine.',async()=>{await repos.kombaxSocial.deleteContact(c.id,actor.id);toast('Conversación eliminada');await renderContacts({standalone});},{confirmText:'Eliminar conversación',danger:true});}));
    const pendingOpen=sessionStorage.getItem('kombax_social_open_contact');if(pendingOpen){const c=rows.find(x=>String(x.id)===String(pendingOpen));sessionStorage.removeItem('kombax_social_open_contact');if(c)setTimeout(()=>openContactThread(c),0);}
  }catch(error){box.innerHTML=empty('No se pudieron cargar los contactos',humanError(error)||'Revisa la conexión.');}
}

export async function renderKombaxConversations(){
  setMainHtml('<div class="loading-card">Abriendo Conversaciones KOMBAX…</div>');
  try{[socialStatus,ownProfiles]=await Promise.all([repos.kombaxSocial.status(),repos.kombaxSocial.myProfiles()]);const preferred=chooseDefaultIdentity(ownProfiles);activeIdentityId=preferred?.id||activeIdentityId||'';}catch(error){setMainHtml(`${pageHeader('Conversaciones KOMBAX')}<div class="empty-card"><strong>No se pudieron cargar las conversaciones</strong><p>${esc(humanError(error)||'Revisa la conexión.')}</p></div>`);return;}
  return renderContacts({standalone:true});
}

async function renderSaved(){
  setMainHtml(`<div class="kombax-social-page">${socialHeader()}${pageHeader('Guardados','Colección privada: solo tú puedes ver lo que has guardado.',socialHeaderActions(),'KOMBAX Social')}${tabBar()}<div id="kombax-saved-list"><div class="loading-card">Cargando guardados…</div></div></div>`);bindCommon();
  const box=document.getElementById('kombax-saved-list');
  try{
    const rows=await repos.kombaxSocial.saved(160);
    box.innerHTML=rows.length?`<div class="kombax-saved-list">${rows.map(x=>`<article><div><span class="page-kicker">${esc(TYPE_LABEL[x.tipo]||x.tipo)} · ${dtFmt(x.creado_en)} · ${esc(x.audiencia_label||'Público')}</span><button type="button" class="kx-saved-author" data-social-profile-open="${esc(x.autor_id)}">${esc(x.autor_nombre)}</button><p>${esc(x.texto)}</p></div><button class="btn btn-ghost btn-sm" data-kx-unsave="${esc(x.id)}">Quitar de guardados</button></article>`).join('')}</div>`:empty('Sin guardados','Las publicaciones que guardes aparecerán aquí y no se muestran públicamente.');
    box.querySelectorAll('[data-social-profile-open]').forEach(b=>b.addEventListener('click',()=>openKombaxPublicProfile(b.dataset.socialProfileOpen)));
    box.querySelectorAll('[data-kx-unsave]').forEach(b=>b.addEventListener('click',async()=>{b.disabled=true;try{await repos.kombaxSocial.save(b.dataset.kxUnsave,false);toast('Eliminado de guardados');await renderSaved();}catch(error){b.disabled=false;setError(error);}}));
  }catch(error){box.innerHTML=empty('No se pudieron cargar los guardados',humanError(error)||'Revisa la conexión.');}
}

async function renderRelations(selectedProfileId=''){
  setMainHtml(`<div class="kombax-social-page">${socialHeader()}${pageHeader('Mi red','Contactos y conexiones KOMBAX. Tu red es privada: solo tú y las identidades que gestionas ven esta lista. Ni tu red ni su tamaño se muestran públicamente.',socialHeaderActions(`<button type="button" class="btn btn-primary" id="kx-add-network">${icon('plus',{size:16})} Añadir a mi red</button>`),'KOMBAX Social')}${tabBar()}<div id="kombax-relations-list"><div class="loading-card">Cargando tu red…</div></div></div>`);bindCommon();
  document.getElementById('kx-add-network')?.addEventListener('click',async()=>{activeView='profiles';await renderProfiles();setTimeout(()=>document.getElementById('kombax-profile-query')?.focus(),0);});
  const box=document.getElementById('kombax-relations-list');
  if(!networkProfiles.length){box.innerHTML=empty('Sin identidad de red disponible','Tu perfil Social debe estar activo para gestionar Mi red. Si acabas de verificar tu afiliación, vuelve a entrar en Social.');return;}
  const selected=networkProfiles.find(x=>String(x.id)===String(selectedProfileId))||networkProfiles.find(x=>String(x.id)===String(activeIdentityId))||networkProfiles[0];
  try{
    const rows=await repos.kombaxSocial.relations(selected.id,relationLimit);
    const identityChoice=networkProfiles.length>1?`<div class="kx-network-identities" role="group" aria-label="Identidad para Mi red">${networkProfiles.map(x=>`<button type="button" class="${x.id===selected.id?'active':''}" data-kx-network-profile="${esc(x.id)}">${esc(x.nombre_publico)}</button>`).join('')}</div>`:'';
    box.innerHTML=`${identityChoice}<div class="kx-relations-toolbar"><button type="button" class="btn btn-ghost btn-sm" id="kx-add-network-inline">${icon('plus',{size:14})} Buscar contactos</button></div>${rows.length?`<div class="kx-relations-list">${rows.map(r=>`<article><header><div><span class="page-kicker">${esc(RELATION_LABEL[r.tipo]||r.tipo)}</span><strong>${esc(r.origen_nombre)} ↔ ${esc(r.destino_nombre)}</strong></div>${badge(r.estado,r.estado==='confirmed'?'ok':r.estado==='rejected'||r.estado==='suspended'?'warn':'neutral')}</header>${r.nota?`<p>${esc(r.nota)}</p>`:''}<small>Solicitud ${dtFmt(r.creado_en)}${r.confirmado_en?` · aceptada ${dtFmt(r.confirmado_en)}`:''}</small><div class="row-actions">${r.gestionable?`<button class="btn btn-primary btn-sm" data-kx-relation-state="confirmed" data-kx-relation-id="${esc(r.id)}">Aceptar en mi red</button><button class="btn btn-ghost btn-sm" data-kx-relation-state="rejected" data-kx-relation-id="${esc(r.id)}">Rechazar</button>`:''}${r.estado==='confirmed'?`<button class="btn btn-ghost btn-sm" data-kx-relation-state="ended" data-kx-relation-id="${esc(r.id)}">Eliminar de mi red</button>`:''}</div></article>`).join('')}</div>`:empty('Tu red está vacía','Las solicitudes y conexiones aceptadas aparecerán aquí de forma privada.')}${rows.length>=relationLimit&&relationLimit<150?'<div class="load-more-wrap"><button class="btn btn-ghost" id="load-more-relations">Cargar relaciones anteriores</button></div>':''}`;
    document.getElementById('load-more-relations')?.addEventListener('click',()=>{relationLimit=Math.min(150,relationLimit+50);renderRelations(selected.id);});
    document.getElementById('kx-add-network-inline')?.addEventListener('click',async()=>{activeView='profiles';await renderProfiles();setTimeout(()=>document.getElementById('kombax-profile-query')?.focus(),0);});
    box.querySelectorAll('[data-kx-network-profile]').forEach(b=>b.addEventListener('click',()=>renderRelations(b.dataset.kxNetworkProfile)));
    box.querySelectorAll('[data-kx-relation-state]').forEach(b=>b.addEventListener('click',()=>confirmDialog(
      b.dataset.kxRelationState==='confirmed'?'Aceptar en mi red':b.dataset.kxRelationState==='rejected'?'Rechazar solicitud':'Eliminar de mi red',
      'Mi red es privada, requiere consentimiento y conserva la trazabilidad necesaria para seguridad.',
      async()=>{await repos.kombaxSocial.relationState(b.dataset.kxRelationId,b.dataset.kxRelationState);toast('Mi red actualizada');await renderRelations(selected.id);},
      {confirmText:b.dataset.kxRelationState==='confirmed'?'Aceptar':'Continuar',danger:b.dataset.kxRelationState!=='confirmed'}
    )));
  }catch(error){box.innerHTML=empty('No se pudo cargar tu red',humanError(error)||'No se pudo comprobar esta conexión.');}
}

function moderationAction(report,decision){
  const labels={allowed:'Permitir / restaurar',review:'Mantener en revisión',hidden:'Ocultar contenido',warning:'Registrar advertencia',suspended:'Suspender perfil',escalated:'Escalar al Owner'};
  openForm({title:labels[decision]||'Decisión de moderación',subtitle:`${report.objetivo_tipo} · ${report.motivo}. La decisión queda registrada con motivo, evidencia y nivel de confianza.`,fields:[{name:'reason_code',label:'Código de motivo',required:true,value:report.motivo||'policy_review',help:'Minúsculas y guion bajo; permite decisiones futuras de IA controlada.'},{name:'confidence',label:'Confianza (0–1)',type:'number',min:0,max:1,step:'0.01',value:'1'},{name:'reason_text',label:'Motivo / resolución',type:'textarea',required:true,full:true,rows:5,maxLength:1500,help:'Describe el criterio y la evidencia revisada.'},{name:'evidence',label:'Referencia de evidencia',type:'textarea',full:true,rows:3,maxLength:1000,help:'Opcional: enlaces internos, observaciones o contexto; nunca contraseñas.'}],submitText:labels[decision]||'Registrar decisión',onSubmit:async v=>{const code=String(v.reason_code||'').trim().toLowerCase().replace(/[^a-z0-9_]+/g,'_');await repos.kombaxSocial.moderationDecide(report.id,decision,code,v.reason_text,v.confidence===''?null:Number(v.confidence),{note:v.evidence||''});toast('Decisión de moderación aplicada y auditada');await renderSafety();}});
}

async function renderSafety(){
  setMainHtml(`<div class="kombax-social-page">${socialHeader()}${pageHeader(t('social.safety.title'),t('social.safety.subtitle'),socialHeaderActions(),'KOMBAX Social')}${tabBar()}${guardianConsentPanel()}<div class="kombax-safety-grid"><article>${icon('shieldCheck',{size:30})}<strong>${t('social.safety.separation')}</strong><p>KOMBAX Social no muestra expedientes, cuotas, asistencia, teléfonos, correos, domicilios ni relaciones familiares.</p></article><article>${icon('message',{size:30})}<strong>${t('social.safety.contact')}</strong><p>El chat solo se habilita tras aceptar una solicitud con motivo previo. El historial permanece abierto y es solo texto: sin imágenes, vídeos, audios ni archivos en esta fase.</p></article><article>${icon('users',{size:30})}<strong>${t('social.safety.minors')}</strong><p>Los perfiles personales menores de 18 requieren consentimiento de un tutor vinculado para activar Social. El contacto privado permanece bloqueado hasta los 18 años.</p></article><article>${icon('alert',{size:30})}<strong>${t('social.safety.moderation')}</strong><p>Publicaciones, comentarios, perfiles y mensajes concretos pueden denunciarse. También existe el motivo “fuera de temática” para contenido ajeno a artes marciales/deportes de contacto. Las decisiones de moderación conservan trazabilidad sin alterar la membresía del club.</p></article></div><section id="kx-moderation-console"></section></div>`);bindCommon();
  document.querySelectorAll('[data-kx-minor-consent]').forEach(b=>b.addEventListener('click',async()=>{b.disabled=true;try{await repos.kombaxSocial.decideMinorConsent(b.dataset.consentId,b.dataset.kxMinorConsent);toast(b.dataset.kxMinorConsent==='approved'?'Acceso Social autorizado':'Solicitud rechazada');await renderKombaxSocial();}catch(error){b.disabled=false;setError(error);}}));
  const consoleBox=document.getElementById('kx-moderation-console');
  let reports=[];
  try{reports=await repos.kombaxSocial.moderationQueue(120);}catch{return;}
  if(!Array.isArray(reports))return;
  consoleBox.innerHTML=`<div class="kx-moderation-head"><div><span class="page-kicker">MODERACIÓN KOMBAX</span><h3>${t('social.safety.queue')}</h3><p>Rol separado del Owner: puede moderar contenido, pero no Finanzas, documentos privados, roles críticos ni configuración.</p></div>${badge(String(reports.length),reports.length?'warn':'ok')}</div>${reports.length?`<div class="kx-moderation-list">${reports.map(r=>`<article><header><div><span class="page-kicker">${esc(String(r.objetivo_tipo||'').toUpperCase())} · ${esc(r.motivo)}</span><strong>${esc(r.autor_objetivo||'Contenido denunciado')}</strong></div>${badge(r.last_decision||r.estado,'warn')}</header><p>${esc(r.objetivo_resumen||'Sin resumen disponible')}</p>${r.detalle?`<blockquote>${esc(r.detalle)}</blockquote>`:''}<small>${dtFmt(r.creado_en)}${r.last_confidence!=null?` · confianza ${esc(r.last_confidence)}`:''}</small><div class="row-actions"><button class="btn btn-ghost btn-sm" data-kx-moderate="${esc(r.id)}" data-kx-decision="review">Revisar</button>${['publicacion','comentario','mensaje'].includes(r.objetivo_tipo)?`<button class="btn btn-primary btn-sm" data-kx-moderate="${esc(r.id)}" data-kx-decision="hidden">Ocultar</button><button class="btn btn-ghost btn-sm" data-kx-moderate="${esc(r.id)}" data-kx-decision="allowed">Restaurar / permitir</button>`:''}<button class="btn btn-ghost btn-sm" data-kx-moderate="${esc(r.id)}" data-kx-decision="warning">Advertir</button>${r.objetivo_tipo==='perfil'?`<button class="btn btn-danger btn-sm" data-kx-moderate="${esc(r.id)}" data-kx-decision="suspended">Suspender</button>`:''}<button class="btn btn-ghost btn-sm" data-kx-moderate="${esc(r.id)}" data-kx-decision="escalated">Escalar al Owner</button></div></article>`).join('')}</div>`:empty(t('social.safety.queueDone'),t('social.safety.queueEmpty'))}`;
  consoleBox.querySelectorAll('[data-kx-moderate]').forEach(b=>b.addEventListener('click',()=>{const report=reports.find(r=>String(r.id)===String(b.dataset.kxModerate));if(report)moderationAction(report,b.dataset.kxDecision);}));
}

export async function renderKombaxSocial(){
  setMainHtml(`<div class="loading-card">${t('common.states.loading')} KOMBAX Social…</div>`);
  try{[socialStatus,ownProfiles,networkProfiles,minorConsentStatus]=await Promise.all([repos.kombaxSocial.status(),repos.kombaxSocial.myProfiles(),repos.kombaxSocial.networkProfiles().catch(()=>repos.kombaxSocial.myProfiles()),repos.kombaxSocial.minorConsentStatus().catch(()=>({mine:[],approvals:[]}))]);audiencesByProfile=new Map();await Promise.all(ownProfiles.map(async p=>{const rows=await repos.kombaxSocial.audiences(p.id).catch(()=>[]);audiencesByProfile.set(String(p.id),rows?.length?rows:[{audiencia:'publica',target_social_id:null,target_club_id:null,label:t('social.audience.publicAll'),descripcion:t('social.audience.publicDescription'),predeterminada:true}]);}));const preferred=chooseDefaultIdentity(ownProfiles);activeIdentityId=preferred?.id||'';await refreshActiveQuota();const requested=sessionStorage.getItem('kombax_social_view');if(requested&&['feed','profiles','discovery','saved','relations','contacts','safety'].includes(requested)){activeView=requested;sessionStorage.removeItem('kombax_social_view');}}
  catch(error){setError(error);setMainHtml(`${pageHeader(t('social.empty.unavailableTitle'),t('social.empty.unavailableBody'),'','KOMBAX Social')}${socialUnavailable(error)}`);return;}
  if(activeView==='profiles')return renderProfiles();
  if(activeView==='discovery')return renderDiscovery();
  if(activeView==='saved')return renderSaved();
  if(activeView==='relations')return renderRelations();
  if(activeView==='contacts')return renderContacts({standalone:true});
  if(activeView==='safety')return renderSafety();
  return loadFeed(false);
}

