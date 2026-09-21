import { esc } from '../core/utils.js';
import { KOMBAX_BRAND } from '../core/platform.js';
import { icon } from './icons.js';

const asset=(relative)=>new URL(relative,import.meta.url).href;
const AREA_META=Object.freeze({
  social:{label:'SOCIAL',claim:'CONNECT · COMPETE · GROW',image:asset('../../assets/brand-heroes/hero-social.webp'),tone:'red'},
  events:{label:'EVENTS',claim:'FROM HYPE TO HISTORY',image:asset('../../assets/brand-heroes/hero-events.webp'),tone:'cyan'},
  showcase:{label:'SHOWCASE',claim:'MUESTRA · PROMOCIONA · DESTACA',image:asset('../../assets/brand-heroes/hero-showcase.webp'),tone:'gold'}
});

export function brandHero({area='social',headline='',accent='',body='',features=[],actions=''}={}){
  const meta=AREA_META[area]||AREA_META.social;
  const featureHtml=(features||[]).map(f=>`<span>${icon(f.icon||'sparkles',{size:14})}<b>${esc(f.label||'')}</b></span>`).join('');
  return `<section class="kx-brand-hero kx-brand-hero-${esc(area)}" style="--kx-brand-hero-image:url('${esc(meta.image)}')" aria-label="KOMBAX ${esc(meta.label)}">
    <div class="kx-brand-hero-media" aria-hidden="true"><img class="kx-brand-hero-photo" src="${esc(meta.image)}" alt="" loading="eager" decoding="async"></div>
    <div class="kx-brand-hero-atmosphere" aria-hidden="true"><span class="kx-brand-hero-smoke smoke-a"></span><span class="kx-brand-hero-smoke smoke-b"></span><span class="kx-brand-hero-smoke smoke-c"></span><i></i><i></i><i></i></div>
    <div class="kx-brand-hero-copy">
      <div class="kx-brand-hero-lockup"><img src="${esc(KOMBAX_BRAND.symbol)}" alt=""><div><span>KOMBAX</span><strong>${esc(meta.label)}</strong><small>${esc(meta.claim)}</small></div></div>
      <h1>${esc(headline)}${accent?` <em>${esc(accent)}</em>`:''}</h1>
      <p>${esc(body)}</p>
      ${actions?`<div class="kx-brand-hero-actions">${actions}</div>`:''}
      ${featureHtml?`<div class="kx-brand-hero-features">${featureHtml}</div>`:''}
    </div>
    <div class="kx-brand-hero-edge" aria-hidden="true"></div>
  </section>`;
}
