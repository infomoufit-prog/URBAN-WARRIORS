import { esc } from '../core/utils.js';
import { state } from '../core/state.js';
import { t } from '../i18n/index.js';
export function personalNavigationHtml(content){
  const targets=[['home',t('marketing.space.explore')],['workspace',t('marketing.space.title')],['profile',t('marketing.space.profile')],['organizations',t('marketing.space.organizations')],['settings',t('marketing.space.settings')]];
  return `<div class="kx-personal-shell"><aside class="kx-personal-sidebar" aria-label="${esc(t('marketing.space.title'))}"><strong>KOMBAX</strong><small>${esc(state.session?.nombre||state.session?.email||'')}</small><nav>${targets.map(([target,label])=>`<button class="btn btn-ghost" type="button" data-kx-personal-nav="${target}">${esc(label)}</button>`).join('')}</nav></aside><section class="kx-personal-content"><header class="kx-personal-mobile"><button class="btn btn-ghost" id="kx-personal-menu" type="button" aria-expanded="false">${esc(t('marketing.space.menu'))}</button><span>${esc(t('marketing.space.title'))}</span></header>${content}</section></div>`;
}
export function bindPersonalNavigation(root){
  root.querySelectorAll('[data-kx-personal-nav]').forEach(button=>button.addEventListener('click',()=>window.dispatchEvent(new CustomEvent('kx-personal-navigate',{detail:{target:button.dataset.kxPersonalNav}}))));
  root.querySelector('#kx-personal-menu')?.addEventListener('click',event=>{
    const shell=root.querySelector('.kx-personal-shell');const open=shell.classList.toggle('menu-open');event.currentTarget.setAttribute('aria-expanded',String(open));
  });
}
