import { esc } from '../core/utils.js';
import { state } from '../core/state.js';
import { t } from '../i18n/index.js';
import { icon } from './icons.js';
let workspaceNavigation=null;
export function clearPersonalWorkspaceNavigation(){workspaceNavigation=null;}
export function setPersonalWorkspaceNavigation(value){workspaceNavigation={...value,userId:state.session?.id};syncPersonalWorkspaceNavigation(document);}
export function syncPersonalWorkspaceNavigation(root){
  if(!activeWorkspace())return;
  const nav=root.querySelector('.kx-personal-sidebar nav');
  nav?.querySelectorAll('[data-kx-team-inbox],[data-kx-moderation-notices]').forEach(button=>button.remove());
  nav?.querySelectorAll('[data-kx-personal-nav]').forEach(button=>{
    if(!['workspace','logout'].includes(button.dataset.kxPersonalNav))button.remove();
    else if(button.dataset.kxPersonalNav==='workspace')button.querySelector('span:last-child').textContent='Gestionar mi cuenta e identidades';
  });
  root.querySelectorAll('[data-kx-workspace-select]').forEach((button,index)=>{if(index)button.remove();});
}
function activeWorkspace(){if(workspaceNavigation?.userId!==state.session?.id)workspaceNavigation=null;return workspaceNavigation;}
export function bindWorkspaceNavigation(root){
  const ctx=activeWorkspace();
  const selector=root.querySelector('[data-kx-workspace-select]');
  if(selector&&!selector.dataset.kxWorkspaceSelectorBound){selector.dataset.kxWorkspaceSelectorBound='true';selector.addEventListener('click',()=>{const current=activeWorkspace();return current?.onSelect?current.onSelect():import('../modules/gateway.js').then(m=>m.openWorkspaceIdentitySelector());});}
  if(!ctx)return;
  root.querySelectorAll('.kx-personal-sidebar [data-module]').forEach(b=>b.addEventListener('click',()=>{root.querySelector('.kx-personal-shell')?.classList.remove('menu-open');root.querySelector('#kx-personal-menu')?.setAttribute('aria-expanded','false');ctx.onModule?.(b.dataset.module);}));
  root.querySelector('[data-kx-profile-resource]')?.addEventListener('click',()=>ctx.onModule?.('resources'));
}
export function personalNavigationHtml(content){
  const ctx=activeWorkspace();
  const targets=[['home',t('marketing.space.explore')],['workspace',t('marketing.space.title')],['profile',t('marketing.space.profile')],['organizations',t('marketing.space.organizations')],['services',t('marketing.space.services')],['settings',t('marketing.space.settings')]];
  const symbols={home:'home',workspace:'layers',profile:'user',organizations:'users',services:'sparkles',settings:'settings'};
  if(ctx){targets.splice(0,targets.length,['workspace','Gestionar mi cuenta e identidades']);}
  return `<div class="kx-personal-shell"><aside class="kx-personal-sidebar" id="kx-personal-sidebar" aria-label="${esc(t('marketing.space.title'))}"><div class="kx-personal-brand"><span class="kx-personal-brand-symbol" aria-hidden="true">${ctx?.avatar?`<img class="kx-workspace-avatar" src="${esc(ctx.avatar)}" alt="">`:icon('layers',{size:24})}</span><div><strong>${esc(ctx?.name||'KOMBAX')}</strong><small>${esc(ctx?.title||t('marketing.space.title'))}</small></div><button type="button" class="icon-btn kx-personal-close" data-kx-personal-menu-close aria-label="${esc(t('common.accessibility.closeMenu'))}">${icon('close')}</button></div><small class="kx-personal-account">${esc(state.session?.nombre||state.session?.email||'')}</small>${ctx?'<button type="button" class="btn btn-ghost kx-workspace-selector" data-kx-workspace-select>Seleccionar identidad</button>':''}<nav>${ctx?.navigationHtml||''}${targets.map(([target,label])=>`<button class="btn btn-ghost kx-personal-nav-item" type="button" data-kx-personal-nav="${target}"><span class="kx-personal-nav-icon" aria-hidden="true">${icon(symbols[target],{size:19})}</span><span>${esc(label)}</span></button>`).join('')}${!ctx?`<button type="button" class="btn btn-ghost kx-personal-nav-item" data-kx-moderation-notices><span class="kx-personal-nav-icon" aria-hidden="true">${icon('bell',{size:19})}</span><span>${esc(t('admin.moderation.notices'))}</span></button>`:''}<button type="button" class="btn btn-ghost kx-personal-nav-item kx-personal-logout" data-kx-personal-nav="logout"><span class="kx-personal-nav-icon" aria-hidden="true">${icon('logOut',{size:19})}</span><span>Cerrar sesión</span></button></nav></aside><button type="button" class="kx-personal-scrim" data-kx-personal-menu-close aria-label="${esc(t('common.accessibility.closeMenu'))}" tabindex="-1"></button><section class="kx-personal-content"><header class="kx-personal-mobile"><button class="btn btn-ghost" id="kx-personal-menu" type="button" aria-controls="kx-personal-sidebar" aria-expanded="false">${icon('menu',{size:20})}<span>${esc(t('marketing.space.menu'))}</span></button><span>${esc(t('marketing.space.title'))}</span></header>${content}</section></div>`;
}
export function bindPersonalNavigation(root){
  syncPersonalWorkspaceNavigation(root);
  bindWorkspaceNavigation(root);
  const shell=root.querySelector('.kx-personal-shell'),toggle=root.querySelector('#kx-personal-menu');
  const setMenuOpen=(open,{restoreFocus=false}={})=>{
    if(!shell)return;
    shell.classList.toggle('menu-open',open);toggle?.setAttribute('aria-expanded',String(open));
    if(open)shell.querySelector('.kx-personal-sidebar button')?.focus();
    else if(restoreFocus)toggle?.focus();
  };
  const notices=root.querySelector('[data-kx-moderation-notices]');
  const nav=root.querySelector('.kx-personal-sidebar nav');
  if(nav&&!activeWorkspace()&&!nav.querySelector('[data-kx-team-inbox]')){const button=document.createElement('button');button.type='button';button.className='btn btn-ghost kx-personal-nav-item';button.dataset.kxTeamInbox='';button.innerHTML=`<span class="kx-personal-nav-icon" aria-hidden="true">${icon('users',{size:19})}</span><span>Invitaciones a equipos</span>`;nav.insertBefore(button,notices||nav.lastElementChild);button.addEventListener('click',async()=>{setMenuOpen(false);const module=await import('../modules/profile-team.js');await module.openProfileTeamInbox();});}
  notices?.addEventListener('click',async()=>{setMenuOpen(false);const module=await import('../modules/moderation-notices.js');await module.openModerationNotices();});
  root.querySelectorAll('[data-kx-personal-nav]').forEach(button=>button.addEventListener('click',()=>{setMenuOpen(false);window.dispatchEvent(new CustomEvent('kx-personal-navigate',{detail:{target:button.dataset.kxPersonalNav}}));}));
  toggle?.addEventListener('click',()=>setMenuOpen(!shell?.classList.contains('menu-open')));
  root.querySelectorAll('[data-kx-personal-menu-close]').forEach(button=>button.addEventListener('click',()=>setMenuOpen(false,{restoreFocus:true})));
  shell?.addEventListener('keydown',event=>{
    if(!shell.classList.contains('menu-open'))return;
    if(event.key==='Escape'){event.preventDefault();setMenuOpen(false,{restoreFocus:true});return;}
    if(event.key!=='Tab')return;
    const buttons=[...shell.querySelectorAll('.kx-personal-sidebar button')].filter(button=>button.getClientRects().length&&!button.disabled),first=buttons[0],last=buttons.at(-1);
    if(event.shiftKey&&document.activeElement===first){event.preventDefault();last?.focus();}
    else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first?.focus();}
  });
}
