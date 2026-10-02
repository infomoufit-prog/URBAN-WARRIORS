import { getLocale as kxGetLocale, t } from '../i18n/index.js';
import { localeTag as kxLocaleTag } from '../i18n/formatters.js';
// Compatibilidad de regresión 20047 (no ejecutable): UI comunica límite histórico de máximo 15 s por vídeo. R50/R51: límite activo = 60 s.
// R51: "Ajustar miniatura" evoluciona a Ajustar álbum (foto y vídeo) sin perder el contrato R21.
// KOMBAX 20.048 · canonical public identity renderer.
// A Member has one public identity: the KOMBAX Social profile. Sports details are
// optional sections of that same profile; they are not a second profile model.
import { repos } from '../core/repositories.js';
import { esc, dtFmt, humanError } from '../core/utils.js';
import { identityTypeLabel, resolveIdentityMedia, initials } from '../core/identity-context.js';
import { openDetail, openForm, confirmDialog, toast, setError, setMainHtml, pageHeader, openImmersiveMedia } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { openClubPublicProfile } from './club-profile.js';
import { themeDefinition } from '../core/platform.js';
import { openPrivacyConditions } from './help-legal.js';
import { openAuthenticatedPasswordChange } from './account-security.js';
import { openKombaxPostManager, socialQuotaMarkup } from './social-post-management.js';
import { mediaFrameAttrs, openMediaFramingEditor } from '../ui/media-framing.js';
import { openVideoCoverEditor } from '../ui/video-cover.js';
import { requestNetworkConnection } from './social-network.js';
import { contentTranslationAttrs, prewarmUserContentTranslations } from '../i18n/user-content-translation.js';
import { verificationVisual } from '../core/verification-visual.js';

const arr=v=>Array.isArray(v)?v:[];
const PUBLIC_ALBUM_PREVIEW_LIMIT=5;
const url=path=>path?repos.kombaxSocial.mediaUrl(path):'';
const money=(v,c='EUR')=>v==null?'':new Intl.NumberFormat(kxLocaleTag(kxGetLocale()),{style:'currency',currency:c||'EUR'}).format(Number(v));
function safeExternal(value){const s=String(value||'').trim();return /^https:\/\//i.test(s)?s:'';}
function clampPercent(value,fallback=50){const n=Number(value);return Number.isFinite(n)?Math.min(100,Math.max(0,n)):fallback;}
function bannerPosition(profile){return {x:clampPercent(profile?.banner_position_x,50),y:clampPercent(profile?.banner_position_y,50)};}
function bannerPositionStyle(profile){const pos=bannerPosition(profile);return `object-position:${pos.x}% ${pos.y}%`;}
function avatar(profile){const src=resolveIdentityMedia(profile,'avatar');return src?`<img ${mediaFrameAttrs(profile.avatar_media_presentation,'avatar')} src="${esc(src)}" alt="">`:`<span>${esc(initials(profile.nombre_publico))}</span>`;}
function albumTile(m){
  const src=url(m.storage_path);
  const poster=m.media_presentation?.cover_storage_path?url(m.media_presentation.cover_storage_path):'';
  return `<article data-kx-album-kind="${esc(m.tipo)}">${m.tipo==='video'?`<div class="kx-public-video-shell"><video ${mediaFrameAttrs(m.media_presentation,'album')} src="${esc(src)}" ${poster?`poster="${esc(poster)}"`:''} controls preload="metadata" playsinline></video><button type="button" class="kx-profile-media-expand" data-kx-public-video="${esc(m.id)}" aria-label="${esc(t('profile.public.videoFullscreen'))}">${icon('arrowUpRight',{size:18})}</button></div>`:`<button type="button" class="kx-public-photo-open" data-kx-public-photo="${esc(m.id)}" data-kx-public-photo-path="${esc(m.storage_path)}" aria-label="${esc(t('profile.public.openPhoto'))}"><img ${mediaFrameAttrs(m.media_presentation,'album')} src="${esc(src)}" alt="${esc(t('profile.public.profileContent'))}" loading="lazy" decoding="async"></button>`}</article>`;
}
function openProfileAlbumMedia(profile,item){
  if(!item)return null;const src=url(item.storage_path);if(!src)return null;const poster=item.media_presentation?.cover_storage_path?url(item.media_presentation.cover_storage_path):'';
  return openImmersiveMedia({src,type:item.tipo==='video'?'video':'image',poster,alt:t('profile.public.profileMedia',{kind:item.tipo==='video'?t('profile.public.video'):t('profile.public.photo'),profile:profile.nombre_publico})});
}
function fullAlbumMarkup(profile){
  const rows=arr(profile.album).filter(x=>['photo','video'].includes(x.tipo));
  const photos=rows.filter(x=>x.tipo==='photo').length,videos=rows.filter(x=>x.tipo==='video').length;
  const filters=`<div class="kx-public-album-filters" role="group" aria-label="${esc(t('profile.public.filterAlbum'))}"><button type="button" class="active" data-kx-album-filter="all">${t('profile.public.all')} <b>${rows.length}</b></button><button type="button" data-kx-album-filter="photo">${t('profile.public.photos')} <b>${photos}</b></button><button type="button" data-kx-album-filter="video">${t('profile.public.videos')} <b>${videos}</b></button></div>`;
  return `${filters}<div class="kx-public-album kx-public-album-full">${rows.map(albumTile).join('')}</div>`;
}
function gallery(profile){
  const rows=arr(profile.album).filter(x=>['photo','video'].includes(x.tipo));
  if(!rows.length)return `<div class="empty compact"><strong>${t('profile.public.albumEmpty')}</strong><p>${t('profile.public.albumEmptyBody')}</p></div>`;
  const preview=rows.slice(0,PUBLIC_ALBUM_PREVIEW_LIMIT);
  const photos=rows.filter(x=>x.tipo==='photo').length,videos=rows.filter(x=>x.tipo==='video').length;
  const summary=`<div class="kx-profile-section-intro"><span>${t('profile.public.albumSummary',{shown:preview.length,total:rows.length,photos,videos})}</span></div>`;
  return `${summary}<div class="kx-public-album kx-public-album-preview">${preview.map(albumTile).join('')}</div>${rows.length>PUBLIC_ALBUM_PREVIEW_LIMIT?`<div class="kx-profile-post-more"><button type="button" class="btn btn-ghost btn-sm" id="kx-public-album-more">${t('profile.public.viewFullAlbum')}</button></div>`:''}`;
}
function postMedia(p){
  const src=String(p.media_url||'');if(!src)return '';
  const poster=String(p.media_cover_url||'');const type=String(p.media_tipo||'').toLowerCase();
  const media=type==='video'?`<video ${mediaFrameAttrs(p.media_presentation,'feed')} src="${esc(src)}" ${poster?`poster="${esc(poster)}"`:''} controls preload="metadata" playsinline></video>`:`<img ${mediaFrameAttrs(p.media_presentation,'feed')} src="${esc(src)}" alt="${esc(t('profile.public.postContent'))}" loading="lazy" decoding="async">`;
  return `<div class="kx-profile-post-media">${media}<button type="button" class="kx-profile-post-media-open" data-kx-profile-post-media="${esc(p.id)}" data-kx-media-src="${esc(src)}" data-kx-media-type="${type==='video'?'video':'image'}" data-kx-media-poster="${esc(poster)}" aria-label="${esc(t('profile.public.viewFullscreen',{kind:type==='video'?t('profile.public.video').toLowerCase():t('profile.public.image')}))}">${icon('arrowUpRight',{size:18})}</button></div>`;
}
function postRow(p){return `<article data-kx-profile-post="${esc(p.id)}"><span>${esc(p.tipo||t('profile.public.update'))} · ${dtFmt(p.creado_en)}</span>${p.texto?`<p>${esc(p.texto)}</p>`:''}${postMedia(p)}<small>${t('profile.public.likesComments',{likes:Number(p.likes_count||0),comments:Number(p.comentarios_count||0)})}</small></article>`;}
function posts(profile,usage=null){const rows=arr(profile.posts).slice(0,5);return `<div class="kx-profile-activity">${usage?socialQuotaMarkup(usage,{compact:true}):''}${rows.length?`<div class="kx-profile-section-intro"><span>${t('profile.public.latestPosts',{count:rows.length})}</span></div><div class="kx-public-posts" id="kx-profile-post-list">${rows.map(postRow).join('')}</div><div class="kx-profile-post-more"><button type="button" class="btn btn-ghost btn-sm" id="kx-profile-post-more">${t('profile.public.viewAllPosts')}</button></div>`:`<div class="empty compact"><strong>${t('profile.public.noVisiblePosts')}</strong><p>${t('profile.public.noVisiblePostsBody')}</p></div>`}</div>`;}
function eventHistory(profile){
  const rows=arr(profile.event_history);
  if(!rows.length)return `<div class="empty compact"><strong>${t('profile.public.noOfficialResults')}</strong><p>${t('profile.public.noOfficialResultsBody')}</p></div>`;
  return `<div class="kx-public-event-history">${rows.map(x=>`<a href="./?event=${encodeURIComponent(x.evento_slug||'')}" class="kx-public-event-history-row"><div><small>${esc(x.evento_nombre||'KOMBAX Evento')} · ${x.fecha_inicio?dtFmt(x.fecha_inicio):''}</small><strong>${esc(x.rival_nombre?`vs ${x.rival_nombre}`:t('profile.public.officialResult'))}</strong><span>${esc(x.resultado||x.metodo_resultado||(x.resultado_estado==='anulado'?t('profile.public.voided'):t('profile.public.resultPublished')))}</span></div><b class="${x.resultado_estado==='anulado'?'void':x.ganador===true?'win':x.ganador===false?'loss':'neutral'}">${x.resultado_estado==='anulado'?t('profile.public.voidedUpper'):x.ganador===true?t('profile.public.victory'):x.ganador===false?t('profile.public.result'):t('profile.public.official')}</b></a>`).join('')}</div>`;
}
function brandBusinessPublic(profile){
  const data=profile.brand_business||{},settings=data.settings||{},campaigns=arr(data.open_campaigns);
  const facts=[[t('profile.public.sector'),settings.sector],[t('profile.public.territories'),arr(settings.territories).join(' · ')],[t('profile.public.disciplines'),arr(settings.disciplines).join(' · ')]].filter(([,v])=>String(v||'').trim());
  return `<div class="kx-brand-public-business">${settings.public_business_summary?`<p ${contentTranslationAttrs({contentId:profile.id||'brand',contentType:'brand_editorial',fieldName:'public_business_summary',sourceLocale:profile.source_locale||profile.idioma||'',visibility:'public'})}>${esc(settings.public_business_summary)}</p>`:''}${facts.length?`<div class="kx-member-sports-grid">${facts.map(([k,v])=>`<div><small>${esc(k)}</small><strong>${esc(v)}</strong></div>`).join('')}</div>`:''}${settings.collaboration_open===true?`<div class="kx-brand-public-open">${t('profile.public.openCollaborations')}</div>`:''}${campaigns.length?`<div class="kx-brand-public-campaigns"><h5>${t('profile.public.openCampaigns')}</h5>${campaigns.map(c=>`<article><span>${esc(c.campaign_type||t('profile.public.campaign'))}</span><strong ${contentTranslationAttrs({contentId:c.id||`${profile.id||'brand'}-campaign`,contentType:'brand_editorial',fieldName:'campaign_title',sourceLocale:c.source_locale||c.idioma||profile.source_locale||'',visibility:'public'})}>${esc(c.title)}</strong><p ${contentTranslationAttrs({contentId:c.id||`${profile.id||'brand'}-campaign`,contentType:'brand_editorial',fieldName:'campaign_description',sourceLocale:c.source_locale||c.idioma||profile.source_locale||'',visibility:'public'})}>${esc(c.description||'')}</p><small>${esc([c.territory,arr(c.disciplines).join(', '),c.compensation_summary].filter(Boolean).join(' · '))}</small></article>`).join('')}</div>`:''}<small class="kx-member-profile-note">${t('profile.public.brandPrivacyNote')}</small></div>`;
}
function showcase(profile){
  const rows=arr(profile.showcase);
  if(!rows.length)return `<div class="empty compact"><strong>${t('profile.public.noShowcase')}</strong><p>${t('profile.public.noShowcaseBody')}</p></div>`;
  const summary=rows.length===1?t('profile.public.showcaseSummaryOne'):t('profile.public.showcaseSummary',{count:rows.length});
  return `<div class="kx-profile-section-intro"><span>${summary}</span></div><div class="kx-public-showcase" id="kx-public-showcase-list">${rows.map((x,i)=>`<article ${i>=4?'data-kx-showcase-extra hidden':''}>${x.imagen_url?`<div class="kx-public-showcase-media"><img ${mediaFrameAttrs(x.imagen_presentacion,'product')} src="${esc(x.imagen_url)}" alt="${esc(x.nombre)}" loading="lazy"></div>`:''}<div><strong ${contentTranslationAttrs({contentId:x.id||'showcase-item',contentType:'showcase_product_name',fieldName:'name',sourceLocale:x.source_locale||x.idioma||'',visibility:'public'})}>${esc(x.nombre)}</strong><p ${contentTranslationAttrs({contentId:x.id||'showcase-item',contentType:'showcase_product_summary',fieldName:'summary',sourceLocale:x.source_locale||x.idioma||'',visibility:'public'})}>${esc(x.resumen||'')}</p>${x.listing_kind==='professional_service'?`<small>${t('profile.public.professionalService')}</small>`:x.precio_orientativo!=null?`<small>${esc(money(x.precio_orientativo,x.moneda))}</small>`:''}<div class="row-actions">${safeExternal(x.visitar_url)?`<a class="btn btn-ghost btn-sm" href="${esc(x.visitar_url)}" target="_blank" rel="noopener">${t('profile.public.viewWebsite')}</a>`:''}${safeExternal(x.donde_encontrar_url)?`<a class="btn btn-ghost btn-sm" href="${esc(x.donde_encontrar_url)}" target="_blank" rel="noopener">${t('profile.public.whereToFind')}</a>`:''}</div></div></article>`).join('')}</div>${rows.length>4?`<div class="kx-profile-post-more"><button type="button" class="btn btn-showcase btn-sm" id="kx-public-showcase-more">${t('profile.public.viewAllShowcase')}</button></div>`:''}`;
}
function sportsFacts(profile){
  const s=profile.sports||{};
  const rows=[
    [t('profile.public.sportsNickname'),s.apodo_deportivo],[t('profile.public.disciplines'),s.disciplinas_publicas],[t('profile.public.sportsExperience'),s.experiencia_anos!=null?t('profile.public.yearsShort',{count:Number(s.experiencia_anos)}):''],
    [t('profile.public.sportsSpecialty'),s.especialidad],[t('profile.public.sportsStance'),s.guardia],[t('profile.public.sportsFavorite'),s.tecnica_favorita]
  ].filter(([,v])=>String(v??'').trim());
  if(!rows.length&&!s.trayectoria_declarada&&!s.objetivos)return `<div class="empty compact"><strong>${t('profile.public.sportsOptional')}</strong><p>${t('profile.public.sportsOptionalBody')}</p></div>`;
  return `<div class="kx-member-sports">${rows.length?`<div class="kx-member-sports-grid">${rows.map(([k,v])=>`<div><small>${esc(k)}</small><strong>${esc(v)}</strong></div>`).join('')}</div>`:''}${s.trayectoria_declarada?`<div class="kx-member-sports-copy"><small>${t('profile.public.declaredCareer')}</small><p>${esc(s.trayectoria_declarada)}</p></div>`:''}${s.objetivos?`<div class="kx-member-sports-copy"><small>${t('profile.public.sportsGoals')}</small><p>${esc(s.objetivos)}</p></div>`:''}<p class="kx-member-profile-note">${t('profile.public.sportsDeclaredNote')}</p></div>`;
}
function core(profile){
  const c=profile.core||{};const type=profile.perfil_tipo||profile.sujeto_tipo;
  if(type==='club')return `<div class="kx-profile-facts">${c.lema?`<p><strong>${esc(c.lema)}</strong></p>`:''}${c.ciudad||c.provincia?`<p>${icon('mapPin',{size:16})} ${esc([c.ciudad,c.provincia,c.pais].filter(Boolean).join(' · '))}</p>`:''}${c.historia?`<p>${esc(c.historia)}</p>`:''}${c.logros?`<p><strong>${t('profile.public.career')}</strong><br>${esc(c.logros)}</p>`:''}</div>`;
  if(type==='miembro'){
    const a=profile.affiliation||null;const album=arr(profile.album);const photos=album.filter(x=>x.tipo==='photo').length;const videos=album.filter(x=>x.tipo==='video').length;
    return `<div class="kx-member-public-summary"><p ${contentTranslationAttrs({contentId:profile.id||profile.social_profile_id||'profile',contentType:'public_profile_bio',fieldName:'bio',sourceLocale:profile.source_locale||profile.idioma||'',visibility:'public'})}>${esc(c.bio_publica||profile.bio||t('profile.public.memberDefaultBio'))}</p><div class="kx-profile-facts"><span><b>${t('profile.public.memberProfilePublic')}</b></span><span>${t('profile.public.photosCount',{count:photos})}</span><span>${t('profile.public.videosCount',{count:videos})}</span></div>${a?.verificada?`<p class="kx-member-affiliation">${icon('checkCircle',{size:16})} ${t('profile.public.confirmedAffiliation')} · <button type="button" ${a.club_social_id?`data-kx-affiliation-club="${esc(a.club_social_id)}"`:''}>${esc(a.club_nombre)}</button></p>`:''}<small class="kx-member-profile-note">${t('profile.public.memberProfileNote')}</small></div>`;
  }
  return `<div class="kx-profile-facts">${c.descripcion?`<p ${contentTranslationAttrs({contentId:profile.id||profile.social_profile_id||'profile',contentType:'public_profile_bio',fieldName:'description',sourceLocale:profile.source_locale||profile.idioma||'',visibility:'public'})}>${esc(c.descripcion)}</p>`:''}${c.disciplinas?`<p><strong>${t('profile.public.disciplinesLabel')}</strong> ${esc(Array.isArray(c.disciplinas)?c.disciplinas.join(' · '):c.disciplinas)}</p>`:''}${c.club_nombre?`<p>${icon('shield',{size:16})} ${esc(c.club_nombre)}</p>`:''}</div>`;
}
function discoveryAvailability(profile){
  const d=profile?.discovery;if(!d)return '';
  const status={available:t('profile.public.discoveryAvailable'),limited:t('profile.public.discoveryLimited'),unavailable:t('profile.public.discoveryUnavailable')};
  const klass=d.availability_status||'private';
  const label=d.availability_status?status[d.availability_status]||d.availability_status:t('profile.public.discoveryPrivate');
  const tags=[];if(Array.isArray(d.disciplines))tags.push(...d.disciplines.slice(0,5));if(d.profile_type==='competitor'&&d.competition_level)tags.push(d.competition_level);if(d.profile_type==='professional'&&d.specialty)tags.push(d.specialty);if(d.territory)tags.push(d.territory);
  if(d.profile_type==='competitor'&&d.public_weight_min_kg!=null&&d.public_weight_max_kg!=null){const min=Number(d.public_weight_min_kg).toFixed(1),max=Number(d.public_weight_max_kg).toFixed(1);tags.push(min===max?`${min} kg`:`${min}–${max} kg`);}
  const slots=arr(d.slots).filter(x=>x.slot_status==='available').slice(0,4);
  const declared=d.profile_type==='competitor'&&(d.fight_count_declared!=null||d.wins_declared!=null||d.losses_declared!=null||d.draws_declared!=null)?`<small class="kx-discovery-declared">${t('profile.public.declaredCompetition')} · ${d.fight_count_declared!=null?`${t('profile.public.fightsCount',{count:Number(d.fight_count_declared)})} · `:''}${t('profile.public.record',{wins:Number(d.wins_declared||0),losses:Number(d.losses_declared||0),draws:Number(d.draws_declared||0)})}</small>`:'';
  return `<div class="kx-public-discovery"><div class="kx-public-discovery-head"><div><span>KOMBAX DISCOVERY</span><strong>${esc(label)}</strong></div><span class="kx-discovery-status ${esc(klass)}">${esc(label)}</span></div>${d.availability_reason?`<p>${esc(d.availability_reason)}</p>`:''}${tags.length?`<div class="kx-discovery-tags">${tags.map(x=>`<span>${esc(x)}</span>`).join('')}</div>`:''}${declared}${d.max_travel_km!=null?`<small>${t('profile.public.declaredTravel',{km:Number(d.max_travel_km)})}</small>`:''}${slots.length?`<div class="kx-public-discovery-slots"><b>${t('profile.public.publishedDates')}</b>${slots.map(x=>`<span>${esc(dtFmt(x.starts_at))} → ${esc(dtFmt(x.ends_at))}${x.note?` · ${esc(x.note)}`:''}</span>`).join('')}</div>`:''}${profile.own?`<button type="button" class="btn btn-ghost btn-sm" id="kx-public-discovery-edit">${t('profile.public.editAvailability')}</button>`:''}</div>`;
}
function profileArticle(p,{usage=null}={}){
  const banner=resolveIdentityMedia(p,'banner');const type=p.perfil_tipo||p.sujeto_tipo;const profileTheme=type==='club'?themeDefinition(p.theme_id):null;const verification=verificationVisual(type,p.verificado);
  return `<article class="kx-public-profile ${verification==='competitor'?'is-verified-competitor':''} ${verification==='member'?'is-member':''} ${profileTheme?esc(profileTheme.className):''}" ${profileTheme?`data-club-theme="${esc(profileTheme.id)}"`:''}>
    <div class="kx-public-profile-hero">${banner?`<img class="kx-public-banner" src="${esc(banner)}" alt="" style="${esc(bannerPositionStyle(p))}">`:'<div class="kx-public-banner fallback"></div>'}${verification==='competitor'?`<span class="kx-competitor-hero-badge" aria-label="${esc(t('profile.public.verifiedBy',{type:identityTypeLabel[type]||type}))}">${icon('shieldCheck',{size:17})}<span>${esc(t('profile.public.verifiedBy',{type:identityTypeLabel[type]||type}))}</span></span>`:''}${p.own?`<button type="button" class="kx-profile-manage-trigger" id="kx-public-manage-profile" aria-label="${esc(t('profile.public.manageProfile'))}">${icon('settings',{size:17})}<span>${t('profile.public.manage')}</span></button>`:''}<div class="kx-public-avatar">${avatar(p)}</div></div>
    <div class="kx-public-title"><div><span class="page-kicker">${esc(identityTypeLabel[type]||type||'KOMBAX')}</span><h3>${esc(p.nombre_publico)}</h3>${verification==='organization'?`<span class="kx-organization-verified">${icon('shieldCheck',{size:15})}${esc(t('profile.public.verifiedBy',{type:identityTypeLabel[type]||type}))}</span>`:''}${p.bio?`<p ${contentTranslationAttrs({contentId:p.id,contentType:'public_profile_bio',fieldName:'bio',sourceLocale:p.source_locale||p.idioma||'',visibility:'public'})}>${esc(p.bio)}</p>`:''}</div></div>
    ${core(p)}
    ${type==='marca'?`<section><h4>${t('profile.public.brandAndCollaborations')}</h4>${brandBusinessPublic(p)}</section>`:''}
    ${type==='miembro'?`<section><h4>${t('profile.public.sportsInformation')}</h4>${sportsFacts(p)}</section>`:''}
    ${['competidor','profesional'].includes(type)?`<section><h4>${t('profile.public.availabilityDiscovery')}</h4>${discoveryAvailability(p)||`<div class="empty compact"><strong>${t('profile.public.discoveryNotConfigured')}</strong><p>${t('profile.public.discoveryNotConfiguredBody')}</p></div>`}</section>`:''}
    ${type!=='espectador'?`<section><h4>${t('profile.public.album')}</h4>${gallery(p)}</section>`:''}
    <section><h4>Actividad KOMBAX</h4>${posts(p,usage)}</section>
    ${type==='competidor'?`<section><h4>Historial KOMBAX Eventos</h4>${eventHistory(p)}</section>`:''}
    <section><h4>Showcase</h4>${showcase(p)}</section>
  </article>`;
}
function profileActions(p){
  if(p.own)return '';
  return `<button class="btn btn-primary" id="kx-public-network">Añadir a mi red</button>${p.contactable?'<button class="btn btn-ghost" id="kx-public-contact">Contactar</button>':''}<button class="btn btn-ghost" id="kx-public-report">Denunciar</button><button class="btn btn-ghost" id="kx-public-share">Compartir</button>`;
}
function profileManagementActions(p,{legal=false}={}){
  const type=p.perfil_tipo||p.sujeto_tipo;const hasBanner=Boolean(resolveIdentityMedia(p,'banner'));
  const canPublish=p.publication_enabled===true;
  const albumEnabled=type==='miembro'&&p.album_enabled!==false;
  return `<button class="btn btn-ghost" id="kx-public-share">Compartir perfil</button>${p.avatar_media_id?'<button class="btn btn-ghost" id="kx-public-avatar-position">Ajustar avatar</button>':''}${hasBanner?'<button class="btn btn-ghost" id="kx-public-banner-position">Ajustar banner</button>':''}${canPublish?'<button class="btn btn-ghost" id="kx-public-manage-posts">Gestionar publicaciones</button>':''}<button class="btn btn-ghost" id="kx-public-account-security">Seguridad y acceso</button>${type==='miembro'&&p.affiliation?.verificada?'<button class="btn btn-primary" id="kx-public-share-affiliation">Compartir afiliación</button>':''}${albumEnabled?'<button class="btn btn-ghost" id="kx-public-member-album">Gestionar álbum, foto y banner</button><button class="btn btn-ghost" id="kx-public-member-edit">Editar mi perfil</button>':''}${['competidor','profesional'].includes(type)?'<button class="btn btn-ghost" id="kx-public-discovery-manage">Disponibilidad y Discovery</button>':''}<button class="btn btn-ghost" id="kx-public-legal">Privacidad y condiciones</button>${type==='club'?'<button class="btn btn-ghost" id="kx-public-club-manage">Gestionar perfil del club</button>':''}`;
}
function openProfileManagement(p,{onRefresh,legal=false}={}){
  const type=p.perfil_tipo||p.sujeto_tipo;const capabilityCopy=type==='espectador'?'Foto, banner, información pública, privacidad y acceso. El perfil Espectador no dispone de álbum ni publicación en el feed.':type==='miembro'&&p.publication_enabled!==true?'Perfil, avatar, banner y álbum disponibles. La publicación en el feed se habilitará cuando un club confirme tu membresía.':'Avatar, banner, publicaciones, álbum, privacidad y acceso permanecen disponibles desde este espacio.';
  const modal=openDetail({title:'Gestionar perfil',subtitle:'Configura esta identidad sin perder la vista pública de tu perfil.',body:`<div class="kx-profile-manage-intro"><strong>${esc(p.nombre_publico)}</strong><span>${esc(capabilityCopy)}</span></div><div class="kx-profile-manage-grid">${profileManagementActions(p,{legal})}</div>`,actions:'<button type="button" class="btn btn-ghost" id="kx-profile-manage-close">Cerrar</button>',width:'760px',className:'kx-profile-manage-modal'});
  const refresh=async()=>{modal.close?.();await onRefresh?.();};
  bindProfileActions(modal.wrap,p,{onRefresh:refresh,legal});
  modal.wrap.querySelector('#kx-profile-manage-close')?.addEventListener('click',()=>modal.close?.());
  modal.wrap.querySelectorAll('.kx-profile-manage-grid button').forEach(button=>button.addEventListener('click',()=>setTimeout(()=>modal.close?.(),0),{once:true}));
  return modal;
}
async function contact(profile){
  const mine=await repos.kombaxSocial.myProfiles();const eligible=mine.filter(x=>x.contacto_habilitado);
  if(!eligible.length){toast('No tienes una identidad autorizada para iniciar Contacto KOMBAX. Los perfiles personales menores de 18 años no pueden iniciar conversaciones.','error');return;}
  openForm({title:`Contactar con ${profile.nombre_publico}`,subtitle:'Contacto KOMBAX: indica el motivo y un primer mensaje. El chat de texto se habilita únicamente si la otra identidad acepta.',fields:[{name:'from',label:'Solicitar como',type:'select',required:true,options:eligible.map(x=>({value:x.id,label:x.identity_label||x.nombre_publico}))},{name:'motivo',label:'Motivo',type:'select',required:true,options:[{value:'entrenamiento',label:'Entrenamiento'},{value:'competicion',label:'Competición'},{value:'evento',label:'Evento'},{value:'colaboracion',label:'Colaboración'},{value:'patrocinio',label:'Patrocinio'},{value:'informacion',label:'Información'},{value:'otro',label:'Otro'}]},{name:'mensaje',label:'Primer mensaje',type:'textarea',required:true,full:true,rows:5,minLength:10,maxLength:500,help:'Entre 10 y 500 caracteres. Se enviará junto a la solicitud. Sin imágenes, vídeos, audios ni archivos.'}],submitText:'Enviar solicitud',onSubmit:async v=>{await repos.kombaxSocial.contact(v.from,profile.id,v.motivo,v.mensaje);toast('Solicitud de contacto enviada');}});
}
function report(profile){openForm({title:'Denunciar perfil',subtitle:profile.nombre_publico,fields:[{name:'motivo',label:'Motivo',type:'select',required:true,options:[{value:'spam',label:'Spam'},{value:'acoso',label:'Acoso'},{value:'suplantacion',label:'Suplantación'},{value:'privacidad',label:'Privacidad'},{value:'otro',label:'Otro'}]},{name:'detalle',label:'Detalle',type:'textarea',full:true,rows:4,maxLength:1000}],submitText:'Enviar denuncia',onSubmit:async v=>{await repos.kombaxSocial.report('perfil',profile.id,v.motivo,v.detalle||'');toast('Denuncia enviada');}});}

async function openMemberAlbum(profile,{onChanged}={}){
  try{
    const all=arr(await repos.kombaxSocial.media(profile.id)).filter(x=>x.estado==='active');
    const rows=all.filter(x=>x.en_album&&['photo','video'].includes(x.tipo));
    const photos=rows.filter(x=>x.tipo==='photo'),videos=rows.filter(x=>x.tipo==='video');
    const avatar=all.find(x=>x.tipo==='avatar');
    const banner=all.find(x=>x.tipo==='banner');
    const mediaSrc=m=>m?url(m.storage_path):'';
    const tile=m=>{const src=mediaSrc(m);const poster=m.media_presentation?.cover_storage_path?url(m.media_presentation.cover_storage_path):'';return `<article class="kx-album-tile"><div class="kx-album-media">${m.tipo==='video'?`<div class="kx-album-video-shell"><video ${mediaFrameAttrs(m.media_presentation,'album')} src="${esc(src)}" ${poster?`poster="${esc(poster)}"`:''} controls preload="metadata" playsinline></video><button type="button" class="kx-profile-media-expand" data-kx-member-video-open="${esc(m.id)}" aria-label="${esc(t('profile.public.videoFullscreen'))}">${icon('arrowUpRight',{size:18})}</button></div>`:`<button type="button" class="kx-album-photo-open" data-kx-member-photo="${esc(m.id)}" aria-label="${esc(t('profile.public.openPhoto'))}"><img ${mediaFrameAttrs(m.media_presentation,'album')} src="${esc(src)}" alt="Foto del álbum de ${esc(profile.nombre_publico)}" loading="lazy"></button>`}</div><div class="kx-album-meta"><span>${m.tipo==='video'?'VÍDEO':'FOTO'}</span>${m.tipo==='video'?`<small>${Number(m.duration_seconds||0).toFixed(1)} s</small>`:''}<button type="button" class="btn btn-ghost btn-sm" data-kx-member-media-frame="${esc(m.id)}">Ajustar álbum</button>${m.tipo==='video'?`<button type="button" class="btn btn-ghost btn-sm" data-kx-member-video-cover="${esc(m.id)}">Elegir portada</button>`:''}<button type="button" class="btn btn-ghost btn-sm" data-kx-member-media-remove="${esc(m.id)}">Retirar</button></div></article>`;};
    const identityHero=`<div class="kx-album-hero">${avatar?`<div><img ${mediaFrameAttrs(avatar.media_presentation,'avatar').replace('class="kx-media-frame-img"','class="kx-media-frame-img kx-avatar-preview"')} src="${esc(mediaSrc(avatar))}" alt=""><small>Foto de perfil</small></div>`:'<span class="kx-avatar-preview placeholder">KX</span>'}${banner?`<div><img ${mediaFrameAttrs(banner.media_presentation,'banner').replace('class="kx-media-frame-img"','class="kx-media-frame-img kx-banner-preview"')} src="${esc(mediaSrc(banner))}" alt=""><small>Banner</small></div>`:'<div class="kx-banner-preview placeholder">BANNER</div>'}</div>`;
    const modal=openDetail({title:`Perfil y álbum · ${profile.nombre_publico}`,subtitle:`Perfil Miembro · ${photos.length}/10 fotos · ${videos.length}/3 vídeos · máximo 60 s por vídeo`,body:`${identityHero}<div class="kx-member-album-intro"><strong>Tu espacio visual público</strong><p>Avatar, banner y álbum forman parte de tu perfil. Las fotos y vídeos del álbum no se publican automáticamente en el feed Social.</p></div><div class="kx-album-grid">${rows.map(tile).join('')||'<div class="empty"><strong>Álbum vacío</strong><p>Añade fotografías o vídeos para personalizar tu perfil público.</p></div>'}</div>`,actions:`<button type="button" class="btn btn-primary" id="kx-member-album-photo" ${photos.length>=10?'disabled':''}>+ Foto</button><button type="button" class="btn btn-ghost" id="kx-member-album-video" ${videos.length>=3?'disabled':''}>+ Vídeo</button><button type="button" class="btn btn-ghost" id="kx-member-avatar-upload">Foto de perfil</button><button type="button" class="btn btn-ghost" id="kx-member-banner-upload">Banner</button>`,width:'920px',className:'kx-member-album-modal'});
    const upload=(kind)=>openForm({title:kind==='video'?'Añadir vídeo al álbum':kind==='photo'?'Añadir foto al álbum':kind==='avatar'?'Cambiar foto de perfil':'Cambiar banner',subtitle:kind==='video'?'Máximo 60 segundos en MP4/HD recomendado. Se guardará en tu álbum, no como publicación del feed.':kind==='photo'?'La imagen se incorporará al álbum público sin generar una publicación del feed.':kind==='avatar'?'Se utilizará como foto principal de tu perfil público.':'Se utilizará como cabecera de tu perfil público.',fields:[{name:'archivo',label:kind==='video'?'Vídeo':kind==='banner'?'Imagen de banner':'Fotografía',type:'file',required:true,full:true,accept:kind==='video'?'video/mp4,video/webm,video/quicktime':'image/jpeg,image/png,image/webp'}],submitText:'Guardar',onSubmit:async v=>{await repos.kombaxSocial.uploadMedia(profile.id,kind,v.archivo,{enAlbum:['photo','video'].includes(kind),audience:'publica'});toast(kind==='avatar'?'Foto de perfil actualizada':kind==='banner'?'Banner actualizado':'Contenido añadido al álbum');modal.close?.();await onChanged?.();}});
    modal.wrap.querySelector('#kx-member-album-photo')?.addEventListener('click',()=>upload('photo'));
    modal.wrap.querySelector('#kx-member-album-video')?.addEventListener('click',()=>upload('video'));
    modal.wrap.querySelector('#kx-member-avatar-upload')?.addEventListener('click',()=>upload('avatar'));
    modal.wrap.querySelector('#kx-member-banner-upload')?.addEventListener('click',()=>upload('banner'));
    modal.wrap.querySelectorAll('[data-kx-member-photo]').forEach(b=>b.addEventListener('click',()=>openProfileAlbumMedia(profile,rows.find(x=>String(x.id)===String(b.dataset.kxMemberPhoto)))));
    modal.wrap.querySelectorAll('[data-kx-member-video-open]').forEach(b=>b.addEventListener('click',()=>openProfileAlbumMedia(profile,rows.find(x=>String(x.id)===String(b.dataset.kxMemberVideoOpen)))));
    modal.wrap.querySelectorAll('[data-kx-member-media-frame]').forEach(b=>b.addEventListener('click',()=>{const item=rows.find(x=>String(x.id)===String(b.dataset.kxMemberMediaFrame));if(!item)return;openMediaFramingEditor({title:'Ajustar contenido del álbum',subtitle:'Elige Completo, Equilibrado o Rellenar. El original se conserva completo.',src:url(item.storage_path),mediaType:item.tipo==='video'?'video':'image',initial:item.media_presentation,preset:'album',onSave:async presentation=>{await repos.mediaFraming.set('social_media',item.id,presentation);modal.close?.();setTimeout(()=>openMemberAlbum(profile,{onChanged}),120);}});}));
    modal.wrap.querySelectorAll('[data-kx-member-video-cover]').forEach(b=>b.addEventListener('click',()=>{const item=rows.find(x=>String(x.id)===String(b.dataset.kxMemberVideoCover));if(!item||item.tipo!=='video')return;openVideoCoverEditor({src:url(item.storage_path),initial:item.media_presentation,title:'Portada del vídeo · álbum KOMBAX Social',subtitle:'Automática, fotograma elegido o imagen propia. El vídeo original no se modifica.',onSave:async({file,mode,time})=>{await repos.kombaxSocial.setVideoCover(item,file,{presentation:item.media_presentation||{},mode,time});modal.close?.();setTimeout(()=>openMemberAlbum(profile,{onChanged}),120);}});}));
    modal.wrap.querySelectorAll('[data-kx-member-media-remove]').forEach(b=>b.addEventListener('click',()=>{const item=rows.find(x=>String(x.id)===String(b.dataset.kxMemberMediaRemove));if(!item)return;confirmDialog('Retirar del álbum','El contenido dejará de mostrarse en tu perfil público. Se conserva la trazabilidad técnica necesaria.',async()=>{await repos.kombaxSocial.removeMedia(item);toast('Contenido retirado');modal.close?.();await onChanged?.();},{confirmText:'Retirar',danger:true});}));
  }catch(error){setError(error);}
}

function bindBannerFocalStage(stage,xInput,yInput,initial={x:50,y:50},onChange=()=>{}){
  if(!stage)return ()=>bannerPosition(initial);
  const image=stage.querySelector('img'),marker=stage.querySelector('.kx-banner-focal-marker');
  let x=clampPercent(initial.x,50),y=clampPercent(initial.y,50),dragging=false;
  const render=()=>{
    if(image)image.style.objectPosition=`${x}% ${y}%`;
    if(marker){marker.style.left=`${x}%`;marker.style.top=`${y}%`;}
    if(xInput)xInput.value=String(Math.round(x));
    if(yInput)yInput.value=String(Math.round(y));
    onChange({x,y});
  };
  const fromPointer=e=>{const r=stage.getBoundingClientRect();if(!r.width||!r.height)return;x=clampPercent(((e.clientX-r.left)/r.width)*100,50);y=clampPercent(((e.clientY-r.top)/r.height)*100,50);render();};
  stage.addEventListener('pointerdown',e=>{dragging=true;stage.classList.add('dragging');stage.setPointerCapture?.(e.pointerId);fromPointer(e);e.preventDefault();});
  stage.addEventListener('pointermove',e=>{if(!dragging)return;fromPointer(e);e.preventDefault();});
  const stop=e=>{dragging=false;stage.classList.remove('dragging');if(e?.pointerId!=null)stage.releasePointerCapture?.(e.pointerId);};
  stage.addEventListener('pointerup',stop);stage.addEventListener('pointercancel',stop);
  xInput?.addEventListener('input',()=>{x=clampPercent(xInput.value,50);render();});
  yInput?.addEventListener('input',()=>{y=clampPercent(yInput.value,50);render();});
  render();
  return ()=>({x,y});
}

function bannerFocalMarkup(src,position){
  return `<div class="kx-banner-focal-editor"><div class="kx-banner-focal-stage" id="kx-banner-focal-stage" aria-label="Arrastra la imagen para elegir la zona visible"><img src="${esc(src)}" alt="Vista previa del banner" style="object-position:${position.x}% ${position.y}%"><span class="kx-banner-focal-marker" aria-hidden="true"></span><span class="kx-banner-focal-hint">Arrastra para encuadrar</span></div><div class="kx-banner-focal-controls"><label>Horizontal <input id="kx-banner-focal-x" type="range" min="0" max="100" step="1" value="${Math.round(position.x)}"></label><label>Vertical <input id="kx-banner-focal-y" type="range" min="0" max="100" step="1" value="${Math.round(position.y)}"></label></div><p class="muted">KOMBAX conserva la foto original. Solo guardamos el punto de encuadre que quieres mostrar en el banner.</p></div>`;
}

export function openBannerPositionEditor(profile,{onSaved,srcOverride=null,socialIdOverride=null}={}){
  const src=srcOverride||resolveIdentityMedia(profile,'banner');if(!src){toast('Primero añade una imagen de banner.','error');return;}
  const socialId=socialIdOverride||profile.id;if(!socialId){toast('No se pudo identificar el perfil KOMBAX asociado.','error');return;}
  const initial=bannerPosition(profile);
  const modal=openDetail({title:'Ajustar banner',subtitle:'Mueve la imagen hasta dejar visible exactamente la zona que quieres mostrar.',body:bannerFocalMarkup(src,initial),actions:'<button type="button" class="btn btn-ghost" id="kx-banner-focal-center">Centrar</button><button type="button" class="btn btn-primary" id="kx-banner-focal-save">Guardar encuadre</button>',width:'900px',className:'kx-banner-focal-modal'});
  const stage=modal.wrap.querySelector('#kx-banner-focal-stage'),xInput=modal.wrap.querySelector('#kx-banner-focal-x'),yInput=modal.wrap.querySelector('#kx-banner-focal-y');
  const getPosition=bindBannerFocalStage(stage,xInput,yInput,initial);
  modal.wrap.querySelector('#kx-banner-focal-center')?.addEventListener('click',()=>{xInput.value='50';yInput.value='50';xInput.dispatchEvent(new Event('input',{bubbles:true}));yInput.dispatchEvent(new Event('input',{bubbles:true}));});
  modal.wrap.querySelector('#kx-banner-focal-save')?.addEventListener('click',async e=>{const b=e.currentTarget;b.disabled=true;const original=b.textContent;b.textContent='Guardando…';try{const pos=getPosition();await repos.kombaxSocial.setBannerPosition(socialId,pos.x,pos.y);profile.banner_position_x=pos.x;profile.banner_position_y=pos.y;toast('Encuadre del banner guardado');modal.close?.();await onSaved?.();}catch(error){b.disabled=false;b.textContent=original;setError(error);}});
}

async function editMemberPublicProfile(profile,{onSaved}={}){
  const bio=profile?.core?.bio_publica||profile?.bio||'';const sports=profile?.sports||{};
  const media=await repos.kombaxSocial.media(profile.id).catch(()=>[]);const avatarMedia=media.find(x=>x.tipo==='avatar'&&x.estado==='active')||null;const bannerMedia=media.find(x=>x.tipo==='banner'&&x.estado==='active')||null;
  let pendingBannerPosition=bannerPosition(profile),bannerPreviewUrl='';
  const formModal=openForm({
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
      {name:'banner',label:'Portada pública',type:'file',accept:'image/jpeg,image/png,image/webp',full:true,help:'Elige una imagen y después arrástrala en la vista previa para seleccionar exactamente qué zona debe verse en el banner.'},
      ...(bannerMedia?[{name:'eliminar_banner',label:'Eliminar portada pública actual',type:'checkbox',value:false,full:true}]:[])
    ],submitText:'Guardar perfil',onSubmit:async v=>{
      await repos.kombaxIdentity.updateMemberProfile(v);await repos.kombaxSocial.setAffiliationVisibility(profile.id,v.afiliacion_visible===true);if(profile.id&&v.bio_publica)void prewarmUserContentTranslations({contentId:profile.id,contentType:'public_profile_bio',fieldName:'bio',text:v.bio_publica,visibility:'public'});
      if(v.avatar)await repos.kombaxSocial.uploadMedia(profile.id,'avatar',v.avatar,{enAlbum:false});else if(v.eliminar_avatar&&avatarMedia)await repos.kombaxSocial.removeMedia(avatarMedia);
      if(v.banner){await repos.kombaxSocial.uploadMedia(profile.id,'banner',v.banner,{enAlbum:false});await repos.kombaxSocial.setBannerPosition(profile.id,pendingBannerPosition.x,pendingBannerPosition.y);}else if(v.eliminar_banner&&bannerMedia)await repos.kombaxSocial.removeMedia(bannerMedia);
      if(v.avatar||v.banner||v.eliminar_avatar||v.eliminar_banner)window.dispatchEvent(new CustomEvent('uw-kombax-social-profile-media-changed',{detail:{social_profile_id:profile.id,kind:'profile_media'}}));
      if(bannerPreviewUrl)URL.revokeObjectURL(bannerPreviewUrl);
      toast('Perfil KOMBAX actualizado');await onSaved?.();
    }
  });
  const bannerInput=formModal.form.elements.banner,bannerField=bannerInput?.closest('.field');
  if(bannerInput&&bannerField){
    const preview=document.createElement('div');preview.className='kx-banner-upload-position';preview.hidden=true;bannerField.appendChild(preview);
    bannerInput.addEventListener('change',()=>{
      const file=bannerInput.files?.[0]||null;if(bannerPreviewUrl)URL.revokeObjectURL(bannerPreviewUrl);bannerPreviewUrl='';preview.innerHTML='';preview.hidden=true;
      if(!file)return;bannerPreviewUrl=URL.createObjectURL(file);pendingBannerPosition={x:50,y:50};preview.innerHTML=`<div class="kx-banner-upload-label"><strong>Encuadra tu banner</strong><span>Arrastra directamente la foto o utiliza los controles.</span></div>${bannerFocalMarkup(bannerPreviewUrl,pendingBannerPosition)}`;preview.hidden=false;
      const stage=preview.querySelector('#kx-banner-focal-stage'),xInput=preview.querySelector('#kx-banner-focal-x'),yInput=preview.querySelector('#kx-banner-focal-y');bindBannerFocalStage(stage,xInput,yInput,pendingBannerPosition,pos=>{pendingBannerPosition=pos;});
    });
  }
}

function bindProfilePostMedia(root){
  root.querySelectorAll('[data-kx-profile-post-media]').forEach(b=>{if(b.dataset.kxBound==='1')return;b.dataset.kxBound='1';b.addEventListener('click',()=>openImmersiveMedia({src:b.dataset.kxMediaSrc||'',type:b.dataset.kxMediaType==='video'?'video':'image',poster:b.dataset.kxMediaPoster||'',alt:'Contenido de la publicación KOMBAX'}));});
}
function bindPublicAlbum(root,p){
  const rows=arr(p.album).filter(x=>['photo','video'].includes(x.tipo));
  root.querySelectorAll('[data-kx-public-photo]').forEach(b=>b.addEventListener('click',()=>openProfileAlbumMedia(p,rows.find(x=>String(x.id)===String(b.dataset.kxPublicPhoto)))));
  root.querySelectorAll('[data-kx-public-video]').forEach(b=>b.addEventListener('click',()=>openProfileAlbumMedia(p,rows.find(x=>String(x.id)===String(b.dataset.kxPublicVideo)))));
  root.querySelectorAll('[data-kx-album-filter]').forEach(button=>button.addEventListener('click',()=>{const filter=button.dataset.kxAlbumFilter||'all';root.querySelectorAll('[data-kx-album-filter]').forEach(x=>x.classList.toggle('active',x===button));root.querySelectorAll('[data-kx-album-kind]').forEach(tile=>{tile.hidden=filter!=='all'&&tile.dataset.kxAlbumKind!==filter;});}));
}
function openPublicAlbum(p){
  const rows=arr(p.album).filter(x=>['photo','video'].includes(x.tipo));
  const modal=openDetail({title:`Álbum · ${p.nombre_publico}`,subtitle:`${rows.length} elementos públicos · fotos y vídeos`,body:fullAlbumMarkup(p),actions:'<button type="button" class="btn btn-ghost" id="kx-public-album-close">Volver al perfil</button>',width:'980px',className:'kx-public-album-modal'});
  bindPublicAlbum(modal.wrap,p);
  modal.wrap.querySelector('#kx-public-album-close')?.addEventListener('click',()=>modal.close?.());
  return modal;
}

function bindProfileActions(root,p,{onRefresh,legal=false}={}){
  bindPublicAlbum(root,p);bindProfilePostMedia(root);
  root.querySelector('#kx-public-manage-profile')?.addEventListener('click',()=>openProfileManagement(p,{onRefresh,legal}));
  root.querySelector('#kx-public-album-more')?.addEventListener('click',()=>openPublicAlbum(p));
  root.querySelector('#kx-public-network')?.addEventListener('click',async e=>{const b=e.currentTarget;b.disabled=true;try{await requestNetworkConnection(p,{onSent:()=>{b.textContent='Solicitud enviada';}});}finally{if(b.isConnected&&b.textContent!=='Solicitud enviada')b.disabled=false;}});
  root.querySelector('#kx-public-contact')?.addEventListener('click',()=>contact(p));root.querySelector('#kx-public-report')?.addEventListener('click',()=>report(p));
  root.querySelector('#kx-public-share')?.addEventListener('click',async()=>{const text=`${p.nombre_publico} · KOMBAX`;try{if(navigator.share)await navigator.share({title:p.nombre_publico,text});else await navigator.clipboard.writeText(location.href);toast(navigator.share?'Compartido':'Enlace copiado');}catch{}});
  root.querySelector('#kx-public-showcase-more')?.addEventListener('click',e=>{root.querySelectorAll('[data-kx-showcase-extra]').forEach(x=>x.hidden=false);e.currentTarget.closest('.kx-profile-post-more')?.remove();});
  let postCursor=(()=>{const first=arr(p.posts).slice(0,5);const last=first.at(-1);return last?{created:last.creado_en,id:last.id}:null;})();
  root.querySelector('#kx-profile-post-more')?.addEventListener('click',async e=>{const b=e.currentTarget;b.disabled=true;b.textContent='Cargando…';try{const page=await repos.kombaxSocial.profilePosts(p.id,postCursor,10);const list=root.querySelector('#kx-profile-post-list');if(list&&page.length){list.insertAdjacentHTML('beforeend',page.map(postRow).join(''));bindProfilePostMedia(root);}const last=page.at(-1);if(last)postCursor={created:last.creado_en,id:last.id};if(page.length<10)b.remove();else{b.disabled=false;b.textContent='Cargar publicaciones anteriores';}}catch(error){b.disabled=false;b.textContent='Ver todas las publicaciones';setError(error);}});
  root.querySelector('#kx-public-manage-posts')?.addEventListener('click',()=>openKombaxPostManager(p,{onChanged:onRefresh}));
  root.querySelector('#kx-public-account-security')?.addEventListener('click',()=>openAuthenticatedPasswordChange({onComplete:()=>location.reload()}));
  root.querySelector('[data-kx-affiliation-club]')?.addEventListener('click',()=>openKombaxPublicProfile(p.affiliation?.club_social_id));
  root.querySelector('#kx-public-share-affiliation')?.addEventListener('click',async()=>{const b=root.querySelector('#kx-public-share-affiliation');b.disabled=true;try{await repos.kombaxSocial.shareAffiliation(p.id);toast(`Afiliación con ${p.affiliation?.club_nombre||'tu club'} publicada`);await onRefresh?.();}catch(error){b.disabled=false;setError(error);}});
  root.querySelector('#kx-public-avatar-position')?.addEventListener('click',()=>{const src=resolveIdentityMedia(p,'avatar');if(!p.avatar_media_id||!src)return;openMediaFramingEditor({title:'Ajustar avatar',subtitle:'Centra el rostro sin modificar la fotografía original.',src,initial:p.avatar_media_presentation,preset:'avatar',onSave:async presentation=>{await repos.mediaFraming.set(p.avatar_media_scope||'social_media',p.avatar_media_id,presentation);await onRefresh?.();}});});
  root.querySelector('#kx-public-banner-position')?.addEventListener('click',()=>openBannerPositionEditor(p,{onSaved:onRefresh}));
  root.querySelector('#kx-public-member-album')?.addEventListener('click',()=>openMemberAlbum(p,{onChanged:onRefresh}));
  root.querySelector('#kx-public-member-edit')?.addEventListener('click',()=>editMemberPublicProfile(p,{onSaved:onRefresh}));
  const openDiscoveryEditor=()=>import('./kombax-discovery.js').then(m=>m.openDiscoveryAvailabilityEditor({id:p.perfil_directo_id||p.discovery?.profile_id,tipo:p.perfil_tipo||p.sujeto_tipo,ubicacion:p.core?.ubicacion||''},{onDone:onRefresh})).catch(setError);
  root.querySelector('#kx-public-discovery-manage')?.addEventListener('click',openDiscoveryEditor);root.querySelector('#kx-public-discovery-edit')?.addEventListener('click',openDiscoveryEditor);
  root.querySelector('#kx-public-legal')?.addEventListener('click',openPrivacyConditions);
  root.querySelector('#kx-public-club-manage')?.addEventListener('click',()=>openClubPublicProfile(p.club_id));
}

export async function openKombaxPublicProfile(socialId){
  try{
    const p=await repos.kombaxSocial.publicProfile(socialId);if(!p?.id)throw new Error('El perfil público no está disponible.');const type=p.perfil_tipo||p.sujeto_tipo;const usage=p.own?await repos.kombaxSocial.quota(p.id).catch(()=>null):null;
    if(['competidor','profesional'].includes(type))p.discovery=await repos.discovery.publicProfile(p.id).catch(()=>null);
    if(type==='competidor')p.event_history=await repos.kombaxEvents.history(p.id,60).catch(()=>[]);
    if(type==='marca'&&p.perfil_directo_id)p.brand_business=await repos.brandBusiness.publicProfile(p.perfil_directo_id).catch(()=>null);
    const modal=openDetail({title:p.nombre_publico,subtitle:`Perfil público KOMBAX · ${identityTypeLabel[type]||type}`,body:profileArticle(p,{usage}),actions:profileActions(p),width:'980px',className:'kx-public-profile-modal'});
    bindProfileActions(modal.wrap,p,{onRefresh:async()=>{modal.close?.();setTimeout(()=>openKombaxPublicProfile(p.id),120);}});return p;
  }catch(error){setError(error);return null;}
}

export async function renderOwnKombaxProfilePage(socialId,{extraHtml='',bindExtra}={}){
  try{
    const p=await repos.kombaxSocial.publicProfile(socialId);if(!p?.id)throw new Error('Tu perfil KOMBAX no está disponible.');const usage=await repos.kombaxSocial.quota(p.id).catch(()=>null);const type=p.perfil_tipo||p.sujeto_tipo;
    if(['competidor','profesional'].includes(type))p.discovery=await repos.discovery.publicProfile(p.id).catch(()=>null);
    if(type==='competidor')p.event_history=await repos.kombaxEvents.history(p.id,60).catch(()=>[]);
    if(type==='marca'&&p.perfil_directo_id)p.brand_business=await repos.brandBusiness.publicProfile(p.perfil_directo_id).catch(()=>null);
    const refresh=()=>renderOwnKombaxProfilePage(p.id,{extraHtml,bindExtra});
    setMainHtml(`${profileArticle(p,{usage})}${extraHtml}`);
    const root=document.getElementById('main-view');if(root){bindProfileActions(root,p,{onRefresh:refresh,legal:true});await bindExtra?.(root,p,refresh);}return p;
  }catch(error){setError(error);setMainHtml(`${pageHeader('Mi perfil')}<div class="empty"><strong>No se pudo abrir tu perfil KOMBAX</strong><p>${esc(humanError(error)||'Inténtalo de nuevo.')}</p></div>`);return null;}
}
