import { state } from '../core/state.js';
import { esc } from '../core/utils.js';
import { setAppHtml, setMainHtml } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { KOMBAX_BRAND } from '../core/platform.js';
import { t } from '../i18n/index.js';

const asset=(relative)=>new URL(relative,import.meta.url).href;
const HOME_ASSETS=Object.freeze({
  stage:asset('../../assets/brand-heroes/gateway-kombax-community.webp'),
  social:asset('../../assets/brand-heroes/hero-social.webp'),
  showcase:asset('../../assets/brand-heroes/hero-showcase.webp'),
  events:asset('../../assets/brand-heroes/hero-events.webp'),
  workspace:asset('../../assets/brand-heroes/smoke-alpha-neutral.webp'),
  guides:asset('../../assets/brand-heroes/hero-guides-card.webp'),
  consulting:asset('../../assets/brand-heroes/hero-consulting-card.webp'),
  training:asset('../../assets/brand-heroes/hero-training-card.webp')
});

function contextLabel(){
  const s=state.session||{};
  return s.support_name||s.club?.nombre||s.active_identity_name||s.nombre||s.email||'KOMBAX';
}
function primaryCard(c,i){
  return `<button type="button" class="kx-prepilot-home-card is-${esc(c.tone)}" data-kx-home-target="${esc(c.id)}" style="--kx-home-card-image:url('${esc(c.image)}')">
    <span class="kx-prepilot-home-card-media" aria-hidden="true"></span>
    <span class="kx-prepilot-home-card-shade" aria-hidden="true"></span>
    <span class="kx-prepilot-home-index">0${i+1}</span>
    <span class="kx-prepilot-home-icon">${icon(c.icon,{size:28})}</span>
    <span class="kx-prepilot-home-card-copy"><strong>${esc(c.title)}</strong><p>${esc(c.body)}</p><em>${esc(t('prepilot.open'))} →</em></span>
    <span class="kx-prepilot-home-card-edge" aria-hidden="true"></span>
  </button>`;
}
function resourceCard({id,title,body,image,iconName,tone}){
  return `<button type="button" class="kx-prepilot-resource-card is-${esc(tone)}" data-kx-home-target="${esc(id)}" style="--kx-resource-image:url('${esc(image)}')">
    <span class="kx-prepilot-resource-media" aria-hidden="true"></span><span class="kx-prepilot-resource-shade" aria-hidden="true"></span>
    <span class="kx-prepilot-resource-copy"><i>${icon(iconName,{size:22})}</i><span><strong>${esc(title)}</strong><small>${esc(body)}</small></span><b>→</b></span>
  </button>`;
}
export async function renderKombaxHome({onNavigate=()=>{},standalone=false,contextName='',onBack=()=>{}}={}){
  const name=contextName||contextLabel();
  const cards=[
    {id:'social',title:t('prepilot.socialTitle'),body:t('prepilot.socialBody'),icon:'network',tone:'social',image:HOME_ASSETS.social},
    {id:'showcase',title:t('prepilot.showcaseTitle'),body:t('prepilot.showcaseBody'),icon:'spotlight',tone:'showcase',image:HOME_ASSETS.showcase},
    {id:'kombax-events',title:t('prepilot.eventsTitle'),body:t('prepilot.eventsBody'),icon:'arena',tone:'events',image:HOME_ASSETS.events},
    {id:'workspace',title:`${t('prepilot.spaceTitle')} · ${name}`,body:t('prepilot.spaceBody'),icon:'home',tone:'space',image:HOME_ASSETS.workspace}
  ];
  const html=`<section class="kx-prepilot-home">
    <section class="kx-prepilot-home-stage" style="--kx-home-stage-image:url('${esc(HOME_ASSETS.stage)}')">
      <div class="kx-prepilot-home-stage-media" aria-hidden="true"></div><div class="kx-prepilot-home-stage-grid" aria-hidden="true"></div><div class="kx-prepilot-home-stage-glow" aria-hidden="true"></div>
      <div class="kx-prepilot-home-stage-copy">
        <div class="kx-prepilot-home-lockup"><img src="${esc(KOMBAX_BRAND.symbolWhite||KOMBAX_BRAND.symbol)}" alt=""><div><span>KOMBAX</span><small>${esc(t('prepilot.homeClaim'))}</small></div></div>
        <h1>${esc(t('prepilot.homeTitle'))}</h1><p>${esc(t('prepilot.homeLead'))}</p>
        <div class="kx-prepilot-context"><i>${icon('layers',{size:16})}</i><span><small>${esc(t('prepilot.activeContext'))}</small><strong>${esc(name)}</strong></span></div>
      </div>
      <div class="kx-prepilot-home-stage-sparks" aria-hidden="true"><i></i><i></i><i></i><i></i></div>
    </section>
    <div class="kx-prepilot-home-grid">${cards.map(primaryCard).join('')}</div>
    <section class="kx-prepilot-resource-zone"><header><span>${icon('sparkles',{size:18})}</span><div><strong>${esc(t('prepilot.resources'))}</strong><small>${esc(t('prepilot.resourcesLead'))}</small></div></header><div class="kx-prepilot-resource-grid">
      ${resourceCard({id:'guides',title:t('prepilot.guides'),body:t('prepilot.guidesLead'),image:HOME_ASSETS.guides,iconName:'fileText',tone:'guides'})}
      ${resourceCard({id:'consulting',title:t('prepilot.consulting'),body:t('prepilot.consultingLead'),image:HOME_ASSETS.consulting,iconName:'sparkles',tone:'consulting'})}
      ${resourceCard({id:'training',title:t('prepilot.training'),body:t('prepilot.trainingLead'),image:HOME_ASSETS.training,iconName:'medal',tone:'training'})}
    </div></section>
  </section>`;
  if(standalone)setAppHtml(`<main class="kx-standalone-home"><header class="kx-standalone-home-nav"><button type="button" class="btn btn-ghost" id="kx-standalone-home-back" aria-label="Volver">${icon('chevronLeft',{size:16})} Volver</button><button type="button" class="icon-btn" id="kx-standalone-home-close" aria-label="Cerrar" title="Cerrar">${icon('close',{size:18})}</button></header>${html}</main>`);
  else setMainHtml(html);
  if(standalone){document.getElementById('kx-standalone-home-back')?.addEventListener('click',onBack);document.getElementById('kx-standalone-home-close')?.addEventListener('click',onBack);}
  document.querySelectorAll('[data-kx-home-target]').forEach(b=>b.addEventListener('click',()=>onNavigate(b.dataset.kxHomeTarget)));
}
