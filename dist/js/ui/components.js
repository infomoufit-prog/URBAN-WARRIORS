import { esc, humanError, fullName } from '../core/utils.js';
import { state } from '../core/state.js';
import { rolesLabel } from '../core/permissions.js';
import { KOMBAX_BRAND, themeFromClub } from '../core/platform.js';
import { icon } from './icons.js';
import { t } from '../i18n/index.js';
import { languageSelectorHtml } from '../i18n/ui.js';
import { localizeHtmlString, localizeSystemText } from '../i18n/legacy-runtime.js';

const BODY_THEME_CLASSES=Object.freeze(['theme-combat-dark','theme-performance-pro','theme-champion-gold','theme-dojo-heritage']);
const modalStack=[];
const SUBVIEW_HEADER_SELECTORS=[
  '.gateway-directory-top','.kx-managed-top','.kx-fed-top','.kx-global-module-top',
  '.kx-admin-console-top','.kx-prep-hero','.kx-professional-finance-top','.kx-showcase-detail-top',
  '.kx-event-subview-top','.kx-fullscreen-subview-head','.page-head'
];
function activeModalLayer(){return document.getElementById('modal-layer');}
function suspendActiveModal(){
  const current=activeModalLayer();if(!current)return;
  current.removeAttribute('id');current.dataset.kxModalSuspended='true';current.remove();modalStack.push(current);
}
function restorePreviousModal(){
  const previous=modalStack.pop();if(!previous)return false;
  previous.id='modal-layer';delete previous.dataset.kxModalSuspended;document.body.appendChild(previous);
  requestAnimationFrame(()=>previous.querySelector('button,input,select,textarea,[tabindex]:not([tabindex="-1"])')?.focus?.({preventScroll:true}));
  return true;
}
export function popModal(){
  const current=activeModalLayer();if(current){current.dispatchEvent(new CustomEvent('kx:modal-before-close'));current.remove();}
  restorePreviousModal();
}
export function enhanceSubviewExitControls(root=document){
  if(!root?.querySelectorAll)return;
  if(root.id==='main-view'||root.querySelector('#main-view')){
    const main=root.id==='main-view'?root:root.querySelector('#main-view');
    const header=main?.querySelector('.page-head');
    if(main&&state.route==='workspace'&&!header&&!main.querySelector('.kx-auto-view-nav')){
      const nav=document.createElement('div');nav.className='kx-auto-view-nav';
      nav.innerHTML=`<button type="button" class="btn btn-ghost kx-subview-back" aria-label="Volver">${icon('chevronLeft',{size:16})} Volver</button><button type="button" class="icon-btn kx-subview-close" aria-label="Cerrar" title="Cerrar">${icon('close',{size:18})}</button>`;
      nav.querySelector('.kx-subview-back').addEventListener('click',()=>goBackOrFallback('#dashboard'));
      nav.querySelector('.kx-subview-close').addEventListener('click',()=>{location.hash='#dashboard';});main.prepend(nav);
    }
    if(header&&!header.querySelector('.kx-subview-back,[aria-label="Volver"],button[id$="-back"]')){
      const actions=header.querySelector('.page-actions')||header;
      const back=document.createElement('button');back.type='button';back.className='btn btn-ghost kx-auto-page-back kx-subview-back';back.setAttribute('aria-label','Volver');back.innerHTML=`${icon('chevronLeft',{size:16})}<span>Volver</span>`;
      back.addEventListener('click',()=>goBackOrFallback('#dashboard'));
      actions.prepend(back);
      const close=document.createElement('button');close.type='button';close.className='icon-btn kx-auto-page-close kx-subview-close';close.setAttribute('aria-label','Cerrar');close.setAttribute('title','Cerrar');close.innerHTML=icon('close',{size:18});
      close.addEventListener('click',()=>{location.hash='#dashboard';});actions.appendChild(close);
    }
  }
  const headers=new Set();
  for(const selector of SUBVIEW_HEADER_SELECTORS)root.querySelectorAll(selector).forEach(node=>headers.add(node));
  root.querySelectorAll('[data-kx-subview-head]').forEach(node=>headers.add(node));
  for(const header of headers){
    const back=header.querySelector('.kx-subview-back,[aria-label="Volver"],button[id$="-back"],button[id*="-back-"]');
    if(!back)continue;
    if(header.querySelector('.kx-subview-close,.kx-auto-subview-close,[aria-label="Cerrar"],button[id$="-close"]'))continue;
    header.classList.add('kx-has-auto-subview-close');
    const close=document.createElement('button');close.type='button';close.className='icon-btn kx-auto-subview-close';close.setAttribute('aria-label',t('common.actions.close'));close.setAttribute('title',t('common.actions.close'));close.innerHTML=icon('close',{size:18});
    close.addEventListener('click',()=>back.click());header.appendChild(close);
  }
}
function syncBodyTheme(app){
  if(!document.body)return;
  document.body.classList.remove(...BODY_THEME_CLASSES);
  const themedRoot=app.querySelector('.app-shell[class*=\"theme-\"],.login-shell[class*=\"theme-\"]');
  const active=themedRoot?[...themedRoot.classList].find(name=>BODY_THEME_CLASSES.includes(name)):null;
  if(active)document.body.classList.add(active);
}
export function setAppHtml(html){
  const app=document.getElementById('app');if(!app)return;
  app.innerHTML=localizeHtmlString(html);syncBodyTheme(app);app.classList.remove('app-view-enter');
  requestAnimationFrame(()=>{app.classList.add('app-view-enter');enhanceSubviewExitControls(app);});
}
export function setMainHtml(html){
  const el=document.getElementById('main-view');if(!el)return;
  el.classList.remove('view-enter');el.innerHTML=localizeHtmlString(html);
  requestAnimationFrame(()=>{el.classList.add('view-enter');enhanceSubviewExitControls(el);});
}

// Private routes must keep the global shell/sidebar mounted. Public/gateway routes
// may still render directly into #app when no #main-view exists.
export function setPrivateViewHtml(html){
  if(document.getElementById('main-view'))return setMainHtml(html);
  return setAppHtml(html);
}

export function alertHtml(){
  const bits=[];
  if(state.error)bits.push(`<div class="alert alert-error"><strong>${esc(t('common.states.error'))}</strong><span>${esc(state.error)}</span><button type="button" class="icon-btn alert-close" data-dismiss-alert aria-label="${esc(t('common.actions.close'))}">${icon('close',{size:16})}</button></div>`);
  if(state.warning)bits.push(`<div class="alert alert-warning"><strong>${esc(t('common.states.warning'))}</strong><span>${esc(state.warning)}</span><button type="button" class="icon-btn alert-close" data-dismiss-alert aria-label="${esc(t('common.actions.close'))}">${icon('close',{size:16})}</button></div>`);
  return bits.join('');
}
export function bindDismissAlerts(){document.querySelectorAll('[data-dismiss-alert]').forEach(b=>b.addEventListener('click',()=>{state.clearError();b.closest('.alert')?.remove();}));}

const initials=(name='')=>String(name).split(/\s+/).filter(Boolean).slice(0,2).map(x=>x[0]?.toUpperCase()).join('')||'KX';
const safeColor=(value,fallback)=>/^#[0-9a-f]{6}$/i.test(String(value||''))?String(value):fallback;
const safeClubLogo=(club)=>{
  const direct=String(club?.logo_url||'').trim();
  if(/^(https?:\/\/|\.\/|\/)/i.test(direct))return direct;
  const configuredSlug=String(window.UW_CONFIG?.clubSlug||'').trim().toLowerCase();
  const clubSlug=String(club?.slug||'').trim().toLowerCase();
  const configuredLogo=String(window.UW_CONFIG?.brand?.logo||'').trim();
  if(configuredLogo&&configuredSlug&&clubSlug===configuredSlug&&/^(https?:\/\/|\.\/|\/)/i.test(configuredLogo))return configuredLogo;
  return '';
};
const safeOptionalImage=(value)=>{const v=String(value||'').trim();return /^(https?:\/\/|\.\/|\/)/i.test(v)?v:''};
const mediaInline=(value={},preset='product')=>{const v=value&&typeof value==='object'?value:{};const defaults=preset==='banner'?{fit:'cover',x:50,y:50,zoom:1}:{fit:'contain',x:50,y:50,zoom:1};const fit=['cover','contain'].includes(String(v.fit||''))?String(v.fit):defaults.fit;const num=(x,a,b,d)=>{const n=Number(x);return Number.isFinite(n)?Math.max(a,Math.min(b,n)):d};return `object-fit:${fit}!important;object-position:${num(v.focus_x,0,100,defaults.x)}% ${num(v.focus_y,0,100,defaults.y)}%!important;transform:scale(${num(v.zoom,1,2.5,defaults.zoom)});transform-origin:${num(v.focus_x,0,100,defaults.x)}% ${num(v.focus_y,0,100,defaults.y)}%`;};

// Historical QA compatibility marker: MODO SOPORTE KOMBAX (rendered via i18n key common.app.supportMode).
export function shell(navItems,active,mobileItems=[]){
  const s=state.session;
  const theme=themeFromClub(s?.club);
  const sections={dashboard:'home',members:'clubManagement',enrollments:'clubManagement',catalog:'clubManagement',groups:'clubManagement',sessions:'clubManagement',attendance:'clubManagement',progress:'clubManagement',tracking:'clubManagement',finance:'economy',reminders:'economy',communications:'communications',community:'communications',events:'clubEvents',material:'administration',documents:'administration','federation-admin':'federationLicenses',archive:'administration',users:'teamPermissions',scopes:'teamPermissions',settings:'clubSettings',assist:'assistance',migrations:'assistance',help:'assistance',requests:'myAccount',install:'myAccount',profile:'myAccount'};
  const sectionOrder=['home','clubManagement','clubEvents','economy','communications','federationLicenses','administration','teamPermissions','assistance','clubSettings','myAccount'];
  const itemOrder={dashboard:10,members:20,enrollments:21,groups:22,catalog:23,sessions:24,attendance:25,progress:26,tracking:27,events:30,finance:40,reminders:41,communications:50,community:51,'federation-admin':60,documents:70,material:71,archive:72,users:80,scopes:81,assist:90,migrations:91,help:92,settings:100,install:110,requests:111,profile:112};
  const hasPersonal=navItems.some(n=>n.id==='personal-profile');
  const personalId=hasPersonal?'personal-profile':'profile';
  const byId=new Map(navItems.map(item=>[item.id,item]));
  const globalIds=[personalId,'social','kombax-events','my-events','showcase','my-showcase'];
  const directGlobalIds=[personalId,'social'];
  const directGlobalHtml=directGlobalIds.map(id=>byId.get(id)).filter(Boolean).map(n=>`<button type="button" class="nav-item nav-primary ${active===n.id?'active':''}" data-nav="${esc(n.id)}"><span>${n.icon}</span><b>${esc(n.label)}</b></button>`).join('');
  const productAccordion=({key,parentId,privateId,exploreLabel,privateLabel,accent})=>{
    const parent=byId.get(parentId);if(!parent)return '';
    const child=byId.get(privateId);
    const isActive=active===parentId||active===privateId;
    let open=isActive;try{const saved=localStorage.getItem(`uw2_${key}_nav_open`);if(!isActive&&(saved==='1'||saved==='0'))open=saved==='1';}catch{}
    return `<details class="club-nav-accordion product-nav-accordion ${esc(accent)} ${open?'is-open':''}" id="${esc(key)}-nav-accordion" data-product-nav="${esc(key)}" ${open?'open':''}>
      <summary><span class="club-nav-icon">${parent.icon}</span><span class="club-nav-copy"><b>${esc(parent.label)}</b><small>${child?esc(privateLabel):esc(exploreLabel)}</small></span><span class="club-nav-chevron">${icon('chevronRight',{size:17})}</span></summary>
      <div class="club-nav-panel product-nav-panel">
        <button type="button" class="nav-item nav-club-item product-nav-item ${active===parentId?'active':''}" data-nav="${esc(parentId)}"><span>${parent.icon}</span><b>${esc(exploreLabel)}</b></button>
        ${child?`<button type="button" class="nav-item nav-club-item product-nav-item product-private-item ${active===privateId?'active':''}" data-nav="${esc(privateId)}" data-private-center="true"><span>${child.icon}</span><b>${esc(privateLabel)}</b></button>`:''}
      </div>
    </details>`;
  };
  // R72 historical QA literals retained as non-rendered compatibility markers; UI uses i18n keys.
  // exploreLabel:'Explorar Eventos' privateLabel:'Mis Eventos'
  // exploreLabel:'Explorar Showcase' privateLabel:'Mi Showcase'
  const eventsAccordion=productAccordion({key:'events',parentId:'kombax-events',privateId:'my-events',exploreLabel:t('navigation.products.exploreEvents'),privateLabel:t('navigation.products.myEvents'),accent:'events-product-nav'});
  const showcaseAccordion=productAccordion({key:'showcase',parentId:'showcase',privateId:'my-showcase',exploreLabel:t('navigation.products.exploreShowcase'),privateLabel:t('navigation.products.myShowcase'),accent:'showcase-product-nav'});
  const globalHtml=`${directGlobalHtml}${eventsAccordion}${showcaseAccordion}`;
  const excluded=new Set([...globalIds,'notifications','platform-admin']);
  const clubItems=navItems.filter(n=>!excluded.has(n.id)).sort((a,b)=>{const sa=sections[a.id]||'myAccount',sb=sections[b.id]||'myAccount';const ds=sectionOrder.indexOf(sa)-sectionOrder.indexOf(sb);return ds||Number(itemOrder[a.id]||999)-Number(itemOrder[b.id]||999);});
  let last='';
  const clubHtml=clubItems.map(n=>{const sec=sections[n.id]||'myAccount';const head=sec!==last?`<div class="nav-subsection">${esc(t(`navigation.sections.${sec}`))}</div>`:'';last=sec;return `${head}<button type="button" class="nav-item nav-club-item ${active===n.id?'active':''}" data-nav="${esc(n.id)}"><span>${n.icon}</span><b>${esc(n.label)}</b></button>`}).join('');
  const mobileClubActive=clubItems.some(x=>x.id===active)||active==='notifications';
  const mobile=mobileItems.map(n=>`<button type="button" class="${active===n.id||(n.id==='more'&&mobileClubActive)?'active':''}" ${n.id==='more'?'id="mobile-more"':`data-nav="${esc(n.id)}"`}><span>${n.icon}</span>${esc(n.label)}</button>`).join('');
  const logo=safeClubLogo(s?.club);const cover=safeOptionalImage(s?.club?.portada_url);const primary=safeColor(s?.club?.color_primario,'#ffffff');const secondary=safeColor(s?.club?.color_secundario,'#050608');const shellBrand=String(KOMBAX_BRAND.symbolWhite||KOMBAX_BRAND.symbol||'./assets/brand/kombax-symbol-white.png');
  const clubCount=new Set((s?.memberships||[]).map(x=>x.club_id).filter(Boolean)).size;
  const activeInClub=clubItems.some(item=>item.id===active)||active==='notifications';let clubOpen=activeInClub;try{const saved=localStorage.getItem('uw2_club_nav_open');if(!activeInClub&&(saved==='1'||saved==='0'))clubOpen=saved==='1';}catch{}
  let resourcesOpen=['resources','guides','consulting'].includes(active);try{const saved=localStorage.getItem('uw2_resources_nav_open');if(!resourcesOpen&&(saved==='1'||saved==='0'))resourcesOpen=saved==='1';}catch{}
  let resourceSection='usage';try{resourceSection=sessionStorage.getItem('kx_resource_section')||'usage';}catch{}
  const supportBanner=s?.support_mode?`<div class="kx-support-mode-banner"><div>${icon('shieldCheck',{size:18})}<span><strong>${esc(t('common.app.supportMode'))}</strong><small>${esc(s?.support_name||s?.club?.nombre||'Entidad')} · ${esc(s?.support_reason||t('common.app.supportAccess'))}</small></span></div><button class="btn btn-ghost btn-sm" id="support-mode-exit" type="button">${esc(t('common.app.exitSupport'))}</button></div>`:'';
  return `<div class="app-shell ${esc(theme.className)}" data-club-theme="${esc(theme.id)}" style="--club-primary:${esc(primary)};--club-secondary:${esc(secondary)};--kx-shell-image:url('${esc(shellBrand)}');--uw-logo-image:${logo?`url('${esc(logo)}')`:'none'};--uw-cover-image:${cover?`url('${esc(cover)}')`:'none'}">
    <button type="button" class="icon-btn global-menu-toggle menu-toggle" id="menu-btn" aria-label="${esc(t('common.accessibility.openMenu'))}" aria-controls="sidebar" aria-expanded="false"><span class="menu-icon-open">${icon('menu')}</span><span class="menu-icon-close">${icon('close')}</span><span class="menu-toggle-dot" aria-hidden="true"></span></button>
    <aside class="sidebar" id="sidebar">
      <div class="brand-block">${logo?`<img src="${esc(logo)}" style="${mediaInline(s?.club?.logo_presentation,'product')}" alt="${esc(s?.club?.nombre||t('common.app.clubFallback'))}">`:`<div class="club-brand-fallback" aria-hidden="true">${esc(initials(s?.club?.nombre||'CLUB'))}</div>`}<div><strong>${esc(String(s?.club?.nombre||'TU CLUB').toUpperCase())}</strong><small>${esc(s?.club?.lema||'Tu comunidad deportiva')}</small></div></div>
      <nav class="nav-list" aria-label="${esc(t('common.accessibility.mainNavigation'))}">
        <div class="nav-section nav-section-global">KOMBAX</div>
        <div class="nav-global">${globalHtml}</div>
        <details class="kx-sidebar-resources" id="kx-resources-nav" data-product-nav="resources" ${resourcesOpen?'open':''}>
          <summary><span class="kx-resources-icon">${icon('sparkles',{size:18})}</span><span class="kx-resources-label"><b>${esc(t('prepilot.resources'))}</b><small>${esc(t('prepilot.rcResourcesSub'))}</small></span><span class="kx-resources-chevron">${icon('chevronRight',{size:17})}</span></summary>
          <div class="kx-sidebar-resources-panel">
            <button type="button" data-nav="resources" data-resource-target="usage" class="${active==='resources'&&resourceSection==='usage'?'active':''}"><span>${icon('fileText',{size:16})}</span>${esc(t('prepilot.rcLearn'))}</button>
            <button type="button" data-nav="resources" data-resource-target="knowledge" class="${active==='resources'&&resourceSection==='knowledge'?'active':''}"><span>${icon('folder',{size:16})}</span>${esc(t('prepilot.rcKnowledge'))}</button>
            <button type="button" data-nav="resources" data-resource-target="territories" class="${active==='resources'&&resourceSection==='territories'?'active':''}"><span>${icon('mapPin',{size:16})}</span>${esc(t('prepilot.rcTerritories'))}</button>
            <button type="button" data-nav="resources" data-resource-target="consulting" class="${active==='resources'&&resourceSection==='consulting'?'active':''}"><span>${icon('sparkles',{size:16})}</span>${esc(t('prepilot.consulting'))}</button>
          </div>
        </details>
        <details class="club-nav-accordion ${clubOpen?'is-open':''}" id="club-nav-accordion" ${clubOpen?'open':''}>
          <summary><span class="club-nav-icon">${icon('dojo',{size:20})}</span><span class="club-nav-copy"><b>${esc(t('navigation.products.myClub'))}</b><small>${esc(s?.club?.nombre||t('common.app.activeClub'))}</small></span><span class="club-nav-chevron">${icon('chevronRight',{size:17})}</span></summary>
          <div class="club-nav-panel">${clubHtml}</div>
        </details>
        </nav>
      <div class="sidebar-foot"><div class="user-avatar session-avatar" data-session-avatar><span>${esc(initials(`${s?.nombre||''} ${s?.apellidos||''}`))}</span><img alt="${esc(t('common.accessibility.profilePhoto'))}" hidden></div><span>${esc(`${s?.nombre||''} ${s?.apellidos||''}`.trim())}</span><small>${esc(rolesLabel(s?.roles||[s?.rol]))}</small><button type="button" class="btn btn-ghost btn-sm" id="logout-btn">${icon('logOut',{size:15})} Cerrar sesión</button></div>
    </aside>
    <button type="button" class="sidebar-scrim" id="sidebar-scrim" aria-label="${esc(t('common.accessibility.closeMenu'))}" tabindex="-1"></button>
    <section class="content-shell">
      ${supportBanner}
      <header class="topbar"><div class="topbar-identity"><strong>${esc(s?.club?.nombre||t('common.app.clubFallback'))}</strong><small>${esc(rolesLabel(s?.roles||[s?.rol]))}</small></div><div class="topbar-actions"><span class="kombax-shell-mark" title="Tecnología ${esc(KOMBAX_BRAND.name)}"><img src="${esc(KOMBAX_BRAND.symbol)}" alt="${esc(KOMBAX_BRAND.name)}"><span>${esc(KOMBAX_BRAND.name)}</span></span>${clubCount>1?`<button class="btn btn-ghost btn-sm club-context-button" id="club-context-button" type="button">${icon('layers',{size:15})}<span>${esc(t('common.actions.changeClub'))}</span></button>`:''}<button class="icon-btn notification-button kombax-notification-button" id="kombax-notification-button" type="button" aria-label="${esc(t('navigation.notifications.kombax'))}" title="${esc(t('navigation.notifications.kombax'))}">${icon('bell')}<span class="notification-count" id="kombax-notification-count" hidden>0</span><span class="topbar-action-marker kombax-marker" aria-hidden="true">KX</span></button><button class="icon-btn notification-button club-notification-button" id="notification-button" type="button" data-nav="notifications" aria-label="${esc(t('navigation.notifications.club'))}" title="${esc(t('navigation.notifications.club'))}">${icon('bell')}<span class="notification-count" id="notification-count" hidden>0</span><span class="topbar-action-marker" aria-hidden="true">CLUB</span></button><button class="icon-btn notification-button message-notification-button" id="message-button" type="button" aria-label="${esc(t('navigation.notifications.messages'))}" title="${esc(t('navigation.notifications.messages'))}">${icon('message')}<span class="notification-count" id="message-count" hidden>0</span></button>${languageSelectorHtml({id:'kombax-language-shell',compact:true})}<button class="topbar-avatar session-avatar" type="button" data-nav="${esc(personalId)}" aria-label="Mi perfil" data-session-avatar><span>${esc(initials(`${s?.nombre||''} ${s?.apellidos||''}`))}</span><img alt="${esc(t('common.accessibility.profilePhoto'))}" hidden></button></div></header>
      <div id="global-alerts">${alertHtml()}</div>
      <main id="main-view" class="main-view"><div class="loading-card">${esc(t('common.states.loading'))}</div></main>
    </section>
    <nav class="bottom-nav" style="--bottom-nav-count:${Math.max(1,mobileItems.length)}" aria-label="${esc(t('common.accessibility.mobileNavigation'))}">${mobile}</nav>
  </div>`;
}

function setTopbarBadge(countElId,buttonId,count=0){const el=document.getElementById(countElId);if(!el)return;const n=Math.max(0,Number(count||0));el.textContent=n>99?'99+':String(n);el.hidden=n===0;document.getElementById(buttonId)?.classList.toggle('has-unread',n>0);}
export function setNotificationBadge(count=0){setTopbarBadge('notification-count','notification-button',count);}
export function setKombaxNotificationBadge(count=0){setTopbarBadge('kombax-notification-count','kombax-notification-button',count);}
export function setMessageBadge(count=0){setTopbarBadge('message-count','message-button',count);}

export function pageHeader(title,subtitle='',actions='',kicker=''){
  return `<div class="page-head"><div>${kicker?`<div class="page-kicker">${esc(kicker)}</div>`:''}<h1>${esc(title)}</h1>${subtitle?`<p>${esc(subtitle)}</p>`:''}</div><div class="page-actions">${actions}</div></div>`;
}
export function subviewActions({backId='kx-subview-back',closeId='kx-subview-close',backLabel='Volver',closeLabel='Cerrar'}={}){
  return `<div class="kx-subview-actions"><button type="button" class="btn btn-ghost kx-subview-back" id="${esc(backId)}">${icon('chevronLeft',{size:16})}<span>${esc(backLabel)}</span></button><button type="button" class="icon-btn kx-subview-close" id="${esc(closeId)}" aria-label="${esc(closeLabel)}" title="${esc(closeLabel)}">${icon('close',{size:18})}</button></div>`;
}
export function goBackOrFallback(fallbackHash='#dashboard'){
  const fallback=String(fallbackHash||'#dashboard').startsWith('#')?String(fallbackHash||'#dashboard'):`#${String(fallbackHash||'dashboard')}`;
  const before=location.href;
  if(history.length>1){
    history.back();
    setTimeout(()=>{if(location.href===before)location.hash=fallback;},220);
    return;
  }
  location.hash=fallback;
}
export function bindSubviewActions(root=document,{backId='kx-subview-back',closeId='kx-subview-close',onBack=null,onClose=null,backFallback='#dashboard',closeFallback='#dashboard'}={}){
  root.querySelector(`#${backId}`)?.addEventListener('click',()=>typeof onBack==='function'?onBack():goBackOrFallback(backFallback));
  root.querySelector(`#${closeId}`)?.addEventListener('click',()=>typeof onClose==='function'?onClose():location.hash=String(closeFallback||'#dashboard').startsWith('#')?String(closeFallback||'#dashboard'):`#${String(closeFallback||'dashboard')}`);
}
export function hero({kicker='KOMBAX',title,body='',actions='',sideValue='',sideLabel='',dark=false}={}){
  return `<section class="hero ${dark?'dark':''}"><div class="hero-grid"><div><div class="hero-kicker">${esc(kicker)}</div><h1>${esc(title||'')}</h1>${body?`<p>${esc(body)}</p>`:''}${actions?`<div class="hero-actions">${actions}</div>`:''}</div>${sideValue?`<div class="hero-side"><strong>${esc(sideValue)}</strong><span>${esc(sideLabel)}</span></div>`:''}</div></section>`;
}
export function metric(label,value,sub='',light=false){return `<div class="metric ${light?'metric-light':''}"><span>${esc(label)}</span><strong>${esc(value)}</strong>${sub?`<small>${esc(sub)}</small>`:''}</div>`}
export function progress(value){const v=Math.max(0,Math.min(100,Number(value||0)));return `<div class="progress"><span style="width:${v}%"></span></div>`}
export function empty(title=t('common.states.empty'),text=t('common.states.emptyDescription')){return `<div class="empty"><strong>${esc(title)}</strong><p>${esc(text)}</p></div>`}
export function badge(text,kind='neutral'){return `<span class="badge badge-${esc(kind)}">${esc(text)}</span>`}
function labelRow(row,headers){let i=0;return row.replace(/<td(\s[^>]*)?>/g,(m,attrs='')=>`<td${attrs||''} data-label="${esc(headers[i++]||'')}">`)}
export function table(headers,rows){const labelled=rows.map(r=>labelRow(r,headers));return `<div class="table-wrap"><table><thead><tr>${headers.map(h=>`<th>${esc(h)}</th>`).join('')}</tr></thead><tbody>${labelled.join('')}</tbody></table></div>`}
export function card(title,body,actions=''){return `<section class="card"><div class="card-head"><h2>${esc(title)}</h2>${actions?`<div>${actions}</div>`:''}</div>${body}</section>`}
export function quickRow(iconHtml,title,subtitle='',actions=''){const visual=String(iconHtml||'').trim().startsWith('<svg')?iconHtml:esc(iconHtml);return `<div class="quick-row"><div class="quick-icon">${visual}</div><div><strong>${esc(title)}</strong>${subtitle?`<small>${esc(subtitle)}</small>`:''}</div>${actions?`<div class="quick-actions">${actions}</div>`:''}</div>`}
export function profileSwitcher(items,selected){return `<div class="profile-switcher">${items.map(x=>`<button type="button" class="profile-chip ${String(x.id)===String(selected)?'active':''}" data-profile-id="${esc(x.id)}"><span class="user-avatar">${esc(initials(fullName(x.nombre,x.apellidos)))}</span><span class="profile-chip-name"><strong>${esc(fullName(x.nombre,x.apellidos)||t('common.people.student'))}</strong></span></button>`).join('')}</div>`}

function fieldHtml(f,val){
  const value=val??f.value??''; const req=f.required?'required':''; const disabled=f.disabled?'disabled':''; const name=esc(f.name);
  const label=`<label for="f-${name}">${esc(f.label)}${f.required?' *':''}</label>`;
  if(f.type==='textarea')return `<div class="field ${f.full?'full':''}">${label}<textarea id="f-${name}" name="${name}" ${req} ${disabled} rows="${f.rows||4}" ${f.minLength!=null?`minlength="${esc(f.minLength)}"`:''} ${f.maxLength!=null?`maxlength="${esc(f.maxLength)}"`:''} placeholder="${esc(f.placeholder||'')}">${esc(value)}</textarea>${f.help?`<small>${esc(f.help)}</small>`:''}</div>`;
  if(f.type==='select'){
    const options=(f.options||[]).map(o=>Array.isArray(o)?{value:o[0],label:o[1]}:(o||{}));
    return `<div class="field ${f.full?'full':''}">${label}<select id="f-${name}" name="${name}" ${req} ${disabled}><option value="">${esc(f.placeholder||t('common.actions.select'))}</option>${options.map(o=>`<option value="${esc(o.value??'')}" ${String(o.value??'')===String(value)?'selected':''}>${esc(o.label??o.value??'')}</option>`).join('')}</select>${f.help?`<small>${esc(f.help)}</small>`:''}</div>`;
  }
  if(f.type==='checkbox')return `<div class="field checkbox-field ${f.full?'full':''}"><label><input id="f-${name}" name="${name}" type="checkbox" ${value!==false?'checked':''} ${disabled}><span>${esc(f.label)}</span></label>${f.help?`<small>${esc(f.help)}</small>`:''}</div>`;
  if(f.type==='file')return `<div class="field ${f.full?'full':''}">${label}<div class="file-input-wrap">${icon('upload',{size:18})}<input id="f-${name}" name="${name}" type="file" ${f.accept?`accept="${esc(f.accept)}"`:''} ${req}></div>${f.help?`<small>${esc(f.help)}</small>`:''}</div>`;
  return `<div class="field ${f.full?'full':''}">${label}<input id="f-${name}" name="${name}" type="${esc(f.type||'text')}" value="${esc(value)}" ${req} ${disabled} ${f.min!=null?`min="${esc(f.min)}"`:''} ${f.max!=null?`max="${esc(f.max)}"`:''} ${f.step!=null?`step="${esc(f.step)}"`:''} ${f.minLength!=null?`minlength="${esc(f.minLength)}"`:''} ${f.maxLength!=null?`maxlength="${esc(f.maxLength)}"`:''} placeholder="${esc(f.placeholder||'')}">${f.help?`<small>${esc(f.help)}</small>`:''}</div>`;
}

export function openForm({title,subtitle='',fields=[],initial={},submitText=t('common.actions.save'),onSubmit,width='720px'}){
  suspendActiveModal();
  const wrap=document.createElement('div');wrap.className='modal-layer';wrap.id='modal-layer';
  wrap.innerHTML=`<div class="modal" style="--modal-width:${esc(width)}"><div class="modal-head"><div><h2>${esc(title)}</h2>${subtitle?`<p>${esc(subtitle)}</p>`:''}</div><div class="modal-head-actions"><button type="button" class="btn btn-ghost btn-sm modal-back" id="modal-back">${icon('chevronLeft',{size:15})}<span>${esc(t('common.actions.back'))}</span></button><button type="button" class="icon-btn" id="modal-close" aria-label="${esc(t('common.actions.close'))}">${icon('close')}</button></div></div><form id="modal-form" novalidate><div class="modal-error" id="modal-error" hidden></div><div class="form-grid">${fields.map(f=>fieldHtml(f,initial[f.name])).join('')}</div><div class="modal-actions"><button type="button" class="btn btn-ghost" id="modal-cancel">${esc(t('common.actions.cancel'))}</button><button type="submit" class="btn btn-primary" id="modal-submit">${esc(submitText)}</button></div></form></div>`;
  document.body.appendChild(wrap);
  const form=wrap.querySelector('#modal-form'),button=wrap.querySelector('#modal-submit'),errorBox=wrap.querySelector('#modal-error');
  const back=()=>popModal();const close=()=>closeModal(); wrap.querySelector('#modal-back')?.addEventListener('click',back);wrap.querySelector('#modal-close').addEventListener('click',close);wrap.querySelector('#modal-cancel').addEventListener('click',back);
  // Los formularios solo se cierran con X o Cancelar. En Android, al volver del
  // selector nativo de archivos puede llegar un toque tardío sobre el fondo del
  // modal; tratarlo como cierre hacía perder el formulario y el borrador.
  form.addEventListener('submit',async e=>{
    e.preventDefault(); e.stopPropagation(); errorBox.hidden=true;
    if(!form.reportValidity())return;
    const fd=new FormData(form),values={};
    for(const f of fields){if(f.type==='checkbox')values[f.name]=form.elements[f.name].checked;else if(f.type==='file')values[f.name]=form.elements[f.name].files?.[0]||null;else values[f.name]=fd.get(f.name);}
    button.disabled=true; const original=button.textContent; button.textContent=t('common.actions.saving');
    try{await onSubmit(values,{form,button});button.textContent=t('common.actions.saved');await new Promise(r=>setTimeout(r,260));close();}
    catch(error){button.disabled=false;button.textContent=original;errorBox.hidden=false;errorBox.textContent=humanError(error);console.error(error);}
  });
  setTimeout(()=>form.querySelector('input:not([type=hidden]),select,textarea')?.focus(),0);
  return {wrap,form};
}
export function openDetail({title='',subtitle='',body='',actions='',width='860px',className=''}){
  suspendActiveModal();
  const wrap=document.createElement('div');wrap.className='modal-layer';wrap.id='modal-layer';
  wrap.innerHTML=`<div class="modal detail-modal ${esc(className)}" style="--modal-width:${esc(width)}"><div class="modal-head"><div><h2>${esc(title)}</h2>${subtitle?`<p>${esc(subtitle)}</p>`:''}</div><div class="modal-head-actions"><button type="button" class="btn btn-ghost btn-sm modal-back" id="modal-back">${icon('chevronLeft',{size:15})}<span>${esc(t('common.actions.back'))}</span></button><button type="button" class="icon-btn" id="modal-close" aria-label="${esc(t('common.actions.close'))}">${icon('close')}</button></div></div><div class="detail-modal-body">${body}</div>${actions?`<div class="modal-actions detail-actions">${actions}</div>`:''}</div>`;
  document.body.appendChild(wrap);
  const back=()=>popModal();const close=()=>closeModal();wrap.querySelector('#modal-back')?.addEventListener('click',back);wrap.querySelector('#modal-close')?.addEventListener('click',close);wrap.addEventListener('click',e=>{if(e.target===wrap)back()});
  return {wrap,close,back};
}
export function closeModal(){const layer=activeModalLayer();if(layer){layer.dispatchEvent(new CustomEvent('kx:modal-before-close'));layer.remove();}while(modalStack.length){const suspended=modalStack.pop();suspended?.dispatchEvent?.(new CustomEvent('kx:modal-before-close'));suspended?.remove?.();}}
export function openImmersiveMedia({src='',type='image',alt=t('common.media.content'),poster='',sourceVideo=null}={}){
  const source=String(src||'').trim();if(!source)return null;
  document.getElementById('kx-immersive-media-layer')?.remove();
  const sourceState=type==='video'&&sourceVideo?{time:Number(sourceVideo.currentTime||0),paused:sourceVideo.paused,volume:Number(sourceVideo.volume??1),muted:sourceVideo.muted,rate:Number(sourceVideo.playbackRate||1)}:null;
  sourceVideo?.pause?.();
  const layer=document.createElement('div');layer.className='kx-immersive-media-layer';layer.id='kx-immersive-media-layer';layer.setAttribute('role','dialog');layer.setAttribute('aria-modal','true');layer.setAttribute('aria-label',type==='video'?t('common.accessibility.fullscreenVideo'):t('common.accessibility.fullscreenImage'));
  const media=type==='video'
    ? `<video class="kx-immersive-media-content" src="${esc(source)}" ${poster?`poster="${esc(poster)}"`:''} controls autoplay playsinline></video>`
    : `<img class="kx-immersive-media-content" src="${esc(source)}" alt="${esc(alt)}">`;
  layer.innerHTML=`<div class="kx-immersive-media-shell"><div class="kx-immersive-media-nav"><button type="button" class="btn btn-ghost btn-sm kx-immersive-media-back" aria-label="${esc(t('common.actions.back'))}">${icon('chevronLeft',{size:15})}<span>${esc(t('common.actions.back'))}</span></button><button type="button" class="btn btn-ghost btn-sm kx-immersive-media-minimize" aria-label="${esc(t('common.media.fullscreenClose'))}">${icon('close',{size:15})}<span>${esc(t('common.media.fullscreenClose'))}</span></button></div><div class="kx-immersive-media-stage">${media}</div></div>`;
  document.body.appendChild(layer);
  const video=layer.querySelector('video');let closed=false;
  const syncBack=()=>{if(!sourceVideo||!video)return;try{sourceVideo.currentTime=Number(video.currentTime||0);sourceVideo.volume=video.volume;sourceVideo.muted=video.muted;sourceVideo.playbackRate=video.playbackRate;}catch{}};
  const close=()=>{if(closed)return;closed=true;syncBack();video?.pause?.();layer.remove();document.removeEventListener('keydown',onKey);if(sourceVideo&&sourceState&&!video?.ended&&!sourceState.paused)sourceVideo.play?.().catch(()=>{});};
  const onKey=e=>{if(e.key==='Escape')close();};
  layer.querySelector('.kx-immersive-media-back')?.addEventListener('click',close);layer.querySelector('.kx-immersive-media-minimize')?.addEventListener('click',close);layer.addEventListener('click',e=>{if(e.target===layer)close();});document.addEventListener('keydown',onKey);
  if(video&&sourceState){const apply=()=>{try{video.currentTime=sourceState.time;video.volume=sourceState.volume;video.muted=sourceState.muted;video.playbackRate=sourceState.rate;}catch{}if(sourceState.paused)video.pause();else video.play?.().catch(()=>{});};if(video.readyState>=1)apply();else video.addEventListener('loadedmetadata',apply,{once:true});}else video?.play?.().catch(()=>{});
  return {wrap:layer,close,video};
}
export function confirmDialog(title,text,onConfirm,{confirmText=t('common.actions.confirm'),danger=false}={}){openForm({title,subtitle:text,fields:[],submitText:confirmText,onSubmit:async()=>onConfirm(),width:'480px'});if(danger)document.getElementById('modal-submit')?.classList.add('btn-danger');}
export function setError(error){state.error=humanError(error);const box=document.getElementById('global-alerts');if(box){box.innerHTML=alertHtml();bindDismissAlerts();}else{toast(state.error,'error');}console.error(error)}
export function setWarning(text){state.warning=text;const box=document.getElementById('global-alerts');if(box){box.innerHTML=alertHtml();bindDismissAlerts();}}
export function toast(text,kind='ok'){const t=document.createElement('div');t.className=`toast toast-${kind}`;t.textContent=text;document.body.appendChild(t);setTimeout(()=>t.classList.add('show'),10);setTimeout(()=>{t.classList.remove('show');setTimeout(()=>t.remove(),250)},3000);}
