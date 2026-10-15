import {clubAreas,clubAreaForRoute} from '../core/club-navigation.js';
import {esc} from '../core/utils.js';
import {localizeSystemText} from '../i18n/legacy-runtime.js';
import {icon} from './icons.js';
export function clubAreasHtml(navItems,active){
 return clubAreas(navItems).map(area=>`<button type="button" class="nav-item nav-club-item ${area.items.some(x=>x.id===active)?'active':''}" data-club-area="${esc(area.id)}" data-club-routes="${esc(area.items.map(x=>x.id).join(' '))}" data-nav="${esc(area.items[0].id)}"><span>${icon(area.icon)}</span><b>${esc(localizeSystemText(area.label))}</b></button>`).join('');
}
export function clubAreaNavigationHtml(navItems,route){
 const area=clubAreaForRoute(navItems,route);if(!area||area.items.length<2)return '';
 const label=localizeSystemText(area.label);
 if(area.items.length>6)return `<nav class="kx-club-area-navigation" aria-label="${esc(label)}"><label><span>${esc(label)}</span><select data-kx-club-section aria-label="${esc(label)}">${area.items.map(item=>`<option value="${esc(item.id)}" ${item.id===route?'selected':''}>${esc(item.label)}</option>`).join('')}</select></label></nav>`;
 return `<nav class="kx-club-area-navigation" aria-label="${esc(label)}">${area.items.map(item=>`<button type="button" class="btn btn-ghost btn-sm ${item.id===route?'active':''}" data-kx-club-tab="${esc(item.id)}" ${item.id===route?'aria-current="page"':''}>${esc(item.label)}</button>`).join('')}</nav>`;
}
export function bindClubAreaNavigation(root){
 const open=route=>window.dispatchEvent(new CustomEvent('kx-club-route',{detail:{route}}));
 root.querySelectorAll('[data-kx-club-tab]').forEach(button=>button.addEventListener('click',()=>open(button.dataset.kxClubTab)));
 root.querySelector('[data-kx-club-section]')?.addEventListener('change',event=>open(event.target.value));
}
