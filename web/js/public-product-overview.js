import { featureIcon, icon } from './ui/icons.js';
import { t } from './i18n/index.js';

const PROFILE_STORIES=()=>[
  {id:'club',icon:'club',key:'club'},
  {id:'federacion',icon:'federation',key:'federation'},
  {id:'competidor',icon:'fighter',key:'fighter'},
  {id:'profesional',icon:'professional',key:'professional'},
  {id:'marca',icon:'brand',key:'brand'},
  {id:'media',icon:'sparkles',key:'media'},
  {id:'espectador',icon:'spectator',key:'spectator'}
].map(item=>({...item,label:t(`marketing.profiles.${item.key}.label`),title:t(`marketing.profiles.${item.key}.title`),description:t(`marketing.profiles.${item.key}.description`),example:t(`marketing.profiles.${item.key}.example`)}));

const ACTION_STORIES=()=>[
  {id:'manage',icon:'club',key:'manage'},
  {id:'connect',icon:'network',key:'connect'},
  {id:'promote',icon:'shoppingBag',key:'promote'},
  {id:'events',icon:'calendar',key:'events'}
].map(item=>({...item,label:t(`marketing.actions.${item.key}.label`),product:t(`marketing.actions.${item.key}.product`),title:t(`marketing.actions.${item.key}.title`),description:t(`marketing.actions.${item.key}.description`),example:t(`marketing.actions.${item.key}.example`)}));

const profileCard=profile=>`<article class="kx-explainer-profile" data-kx-profile="${profile.id}">
  <div class="kx-explainer-profile-icon" aria-hidden="true">${featureIcon(profile.icon,{size:46})}</div>
  <div><span>${profile.label}</span><h4>${profile.title}</h4><p>${profile.description}</p><small>${profile.example}</small></div>
</article>`;

const actionCard=action=>`<article class="kx-explainer-action" data-kx-action="${action.id}">
  <div class="kx-explainer-action-icon" aria-hidden="true">${icon(action.icon,{size:28})}</div>
  <div class="kx-explainer-action-meta"><span>${action.label}</span><b>${action.product}</b></div><h4>${action.title}</h4><p>${action.description}</p><small>${action.example}</small>
</article>`;

const teaser=()=>`<section class="kx-discovery" data-kx-product-overview aria-labelledby="kx-discovery-title">
  <div class="kx-discovery-glow" aria-hidden="true"></div>
  <div class="kx-discovery-copy">
    <span class="kx-discovery-kicker">${t('marketing.overview.kicker')}</span>
    <h2 id="kx-discovery-title">${t('marketing.overview.title')}</h2>
    <p>${t('marketing.overview.lead')}</p>
    <button class="kx-discovery-cta" type="button" data-kx-explainer-open>
      <span><b>${t('marketing.overview.cta')}</b><small>${t('marketing.overview.ctaHint')}</small></span>
      ${icon('arrowUpRight',{size:21})}
    </button>
  </div>
  <div class="kx-discovery-signals" aria-label="${t('marketing.overview.areasAria')}">
    <div><strong>7</strong><span>${t('marketing.overview.identities')}</span></div>
    <div><strong>4</strong><span>${t('marketing.overview.areasConnected')}</span></div>
    <div class="kx-discovery-areas"><span>${t('marketing.overview.managementLabel')}</span><span>SOCIAL</span><span>SHOWCASE</span><span>EVENTS</span></div>
  </div>
</section>`;

const heroDiscoveryLink=()=>`<button class="kx-hero-discover" type="button" data-kx-explainer-open>
  <span><strong>${t('marketing.overview.firstTime')}</strong><small>${t('marketing.overview.firstTimeHint')}</small></span>
  <b>${t('marketing.overview.knowKombax')} ${icon('arrowUpRight',{size:16})}</b>
</button>`;

const explainer=()=>`<dialog class="kx-explainer-dialog" data-kx-explainer aria-labelledby="kx-explainer-title" aria-describedby="kx-explainer-lead">
  <div class="kx-explainer-shell">
    <header class="kx-explainer-topbar">
      <div class="kx-explainer-brand"><span>${featureIcon('identity',{size:30})}</span><div><strong>KOMBAX</strong><small>${t('marketing.overview.ecosystem')}</small></div></div>
      <button class="kx-explainer-close" type="button" data-kx-explainer-close aria-label="${t('marketing.overview.closeAria')}">${icon('close',{size:20})}</button>
    </header>
    <div class="kx-explainer-scroll">
      <section class="kx-explainer-hero">
        <div class="kx-explainer-hero-orbit" aria-hidden="true"><i></i><i></i><i></i></div>
        <span>${t('marketing.overview.in60')}</span>
        <h2 id="kx-explainer-title">${t('marketing.overview.hero')}</h2>
        <p id="kx-explainer-lead">${t('marketing.overview.heroLead')}</p>
        <div class="kx-explainer-principles"><b>${t('marketing.overview.specialized')}</b><i></i><b>${t('marketing.overview.openEcosystem')}</b></div>
      </section>

      <div class="kx-explainer-accordion">
        <details class="kx-explainer-section" open>
          <summary><span><small>01</small><strong>${t('marketing.overview.whatIs')}</strong></span><i aria-hidden="true">${icon('plus',{size:19})}</i></summary>
          <div class="kx-explainer-section-body kx-explainer-definition">
            <div><p>${t('marketing.overview.definition1')}</p><p>${t('marketing.overview.definition2')}</p></div>
            <aside><span>${t('marketing.overview.simpleIdea')}</span><strong>${t('marketing.overview.simpleIdeaBody')}</strong></aside>
          </div>
        </details>

        <details class="kx-explainer-section">
          <summary><span><small>02</small><strong>${t('marketing.overview.findPlace')}</strong></span><i aria-hidden="true">${icon('plus',{size:19})}</i></summary>
          <div class="kx-explainer-section-body"><div class="kx-explainer-profile-grid">${PROFILE_STORIES().map(profileCard).join('')}</div></div>
        </details>

        <details class="kx-explainer-section">
          <summary><span><small>03</small><strong>${t('marketing.overview.whatCanDo')}</strong></span><i aria-hidden="true">${icon('plus',{size:19})}</i></summary>
          <div class="kx-explainer-section-body">
            <div class="kx-ecosystem-intro">
              <span>${t('marketing.overview.uniqueEcosystem')}</span>
              <h3>${t('marketing.overview.connectedExperiences')}</h3>
              <p>${t('marketing.overview.connectedBody')}</p>
            </div>
            <div class="kx-explainer-action-grid">${ACTION_STORIES().map(actionCard).join('')}</div>
            <div class="kx-ecosystem-flow" aria-label="${t('marketing.overview.ecosystemFlowAria')}">
              <div><span>01</span><strong>${t('marketing.overview.managementLabel')}</strong><small>${t('marketing.overview.manageActivity')}</small></div><i>${icon('chevronRight',{size:17})}</i>
              <div><span>02</span><strong>SOCIAL</strong><small>${t('marketing.overview.buildCommunity')}</small></div><i>${icon('chevronRight',{size:17})}</i>
              <div><span>03</span><strong>SHOWCASE</strong><small>${t('marketing.overview.activateVisibility')}</small></div><i>${icon('chevronRight',{size:17})}</i>
              <div><span>04</span><strong>EVENTS</strong><small>${t('marketing.overview.activityExperience')}</small></div>
            </div>
            <p class="kx-ecosystem-note"><strong>${t('marketing.overview.ecosystemNoteLead')}</strong> ${t('marketing.overview.ecosystemNote')}</p>
            <div class="kx-benefit-intro kx-benefit-inline"><span>${t('marketing.overview.benefitKicker')}</span><h3>${t('marketing.overview.benefitTitle')}</h3><p>${t('marketing.overview.benefitBody')}</p></div>
          </div>
        </details>

      </div>

      <section class="kx-explainer-closing">
        <span>CONNECT · COMPETE · GROW</span>
        <h3>${t('marketing.overview.closing').replace('\n','<br>')}</h3>
      </section>
    </div>
    <footer class="kx-explainer-footer">
      <button class="kx-explainer-route primary" type="button" data-kx-target="gateway-club"><span>${featureIcon('club',{size:28})}</span><b>${t('marketing.overview.manageClub')}</b>${icon('chevronRight',{size:18})}</button>
      <button class="kx-explainer-route" type="button" data-kx-target="gateway-direct"><span>${featureIcon('identity',{size:28})}</span><b>${t('marketing.overview.manageIdentity')}</b>${icon('chevronRight',{size:18})}</button>
    </footer>
  </div>
</dialog>`;

function closeExplainer(dialog){
  if(dialog?.open&&typeof dialog.close==='function')dialog.close();
  else dialog?.removeAttribute('open');
}

function bindOverview(gateway){
  const dialog=gateway.querySelector('[data-kx-explainer]');
  const openers=[...gateway.querySelectorAll('[data-kx-explainer-open]')];
  let lastOpener=openers[0]||null;
  openers.forEach(opener=>opener.addEventListener('click',()=>{
    lastOpener=opener;
    if(typeof dialog?.showModal==='function')dialog.showModal();
    else dialog?.setAttribute('open','');
  }));
  dialog?.querySelector('[data-kx-explainer-close]')?.addEventListener('click',()=>closeExplainer(dialog));
  dialog?.addEventListener('click',event=>{if(event.target===dialog)closeExplainer(dialog);});
  dialog?.addEventListener('close',()=>lastOpener?.focus({preventScroll:true}));
  dialog?.querySelectorAll('.kx-explainer-section').forEach(section=>section.addEventListener('toggle',()=>{
    if(!section.open)return;
    dialog.querySelectorAll('.kx-explainer-section').forEach(other=>{if(other!==section)other.open=false;});
  }));
  gateway.querySelectorAll('[data-kx-target]').forEach(button=>button.addEventListener('click',()=>{
    const target=document.getElementById(button.dataset.kxTarget);
    if(!target)return;
    closeExplainer(dialog);
    requestAnimationFrame(()=>target.click());
  }));
  gateway.querySelectorAll('[data-kx-profile]').forEach(card=>{
    card.setAttribute('role','link');
    card.setAttribute('tabindex','0');
    const openProfile=()=>{
      const profile=String(card.dataset.kxProfile||'').trim().toLowerCase();
      if(!profile)return;
      const url=new URL(location.href);
      url.searchParams.set('profile',profile);
      url.searchParams.delete('discover');
      closeExplainer(dialog);
      location.assign(`${url.pathname}${url.search}${url.hash}`);
    };
    card.addEventListener('click',openProfile);
    card.addEventListener('keydown',event=>{if(event.key==='Enter'||event.key===' '){event.preventDefault();openProfile();}});
  });
}

function mountOverview(){
  const gateway=document.querySelector('[data-kombax-view="gateway"]');
  if(!gateway||gateway.querySelector('[data-kx-product-overview]'))return;
  const hero=gateway.querySelector('.gateway-hero');
  if(!hero)return;
  hero.querySelector('.gateway-paths')?.insertAdjacentHTML('beforeend',heroDiscoveryLink());
  hero.insertAdjacentHTML('afterend',`${teaser()}${explainer()}`);
  bindOverview(gateway);
}

const observer=new MutationObserver(mountOverview);
observer.observe(document.documentElement,{childList:true,subtree:true});
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',mountOverview,{once:true});
else mountOverview();
