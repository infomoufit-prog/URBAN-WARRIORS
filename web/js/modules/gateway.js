import { getLocale as kxGetLocale, t } from '../i18n/index.js';
import { languageSelectorHtml, bindLanguageSelectors } from '../i18n/ui.js';
import { backend, client } from '../core/backend.js';
import { DEMO_CLUBS } from '../core/demo-directory.js';
import { KOMBAX_BRAND, platformFeatures, publicPlatformIntroduction, themeDefinition } from '../core/platform.js';
import { esc } from '../core/utils.js';
import { setAppHtml, openDetail, openForm, closeModal, setError, toast, confirmDialog, openImmersiveMedia } from '../ui/components.js';
import { icon, featureIcon } from '../ui/icons.js';
import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { mediaFrameAttrs, openMediaFramingEditor } from '../ui/media-framing.js';
import { openVideoCoverEditor } from '../ui/video-cover.js';

const GATEWAY_HERO_IMAGE=new URL('../../assets/brand-heroes/gateway-kombax-community.webp',import.meta.url).href;
const GATEWAY_LEGAL_LABELS=Object.freeze({
  es:['Privacidad','Condiciones','Contacto'],en:['Privacy','Terms','Contact'],fr:['Confidentialité','Conditions','Contact'],
  pt:['Privacidade','Condições','Contacto'],it:['Privacy','Condizioni','Contatti'],de:['Datenschutz','Bedingungen','Kontakt'],
  th:['ความเป็นส่วนตัว','ข้อกำหนด','ติดต่อ'],fil:['Privacy','Mga tuntunin','Makipag-ugnayan']
});
const isInternalDirectoryClub=club=>/^\s*(?:qa[-_ ]club|\[qa(?:\s+test)?\])/i.test(String(club?.nombre||''))||/^qa[-_]/i.test(String(club?.slug||''));
const gatewayLazyModules=new Map();
function gatewayLazy(path){if(!gatewayLazyModules.has(path))gatewayLazyModules.set(path,import(path).catch(error=>{gatewayLazyModules.delete(path);throw error;}));return gatewayLazyModules.get(path);}
const renderKombaxSocial=(...args)=>gatewayLazy('./kombax-social.js').then(m=>m.renderKombaxSocial(...args));
const renderShowcase=(...args)=>gatewayLazy('./showcase.js').then(m=>m.renderShowcase(...args));
const renderMyShowcase=(...args)=>gatewayLazy('./showcase.js').then(m=>m.renderMyShowcase(...args));
const renderKombaxEvents=(...args)=>gatewayLazy('./kombax-events.js').then(m=>m.renderKombaxEvents(...args));
import { renderManagedProfileHub, managedHubTitle } from './managed-profile-hub.js';
import { renderProfessionalOperations } from './professional-operations.js';
import { renderPendingFederationInvitations } from './federation-licenses.js';
import { openPasswordRecovery } from './auth-recovery.js';
import { openAuthenticatedPasswordChange } from './account-security.js';
import { openKombaxPublicProfile } from './public-profile.js';
import { showPlatformLegalGate } from './platform-legal.js';
import { SUPPORT_EMAIL, openSupportPrivacyCenter } from './support-privacy.js';
import { DIRECT_PROFILE_TYPES, PROFILE_TYPE_LABEL, PROFESSIONAL_SPECIALTIES } from '../core/profile-registry.js';
import { accountProfilePolicy, canRequestAccountProfile } from '../core/account-profile-policy.js';
import { FALLBACK_COMMERCIAL_CATALOG } from '../core/commercial-pricing.js';
import { renderPlanServices, renderCommercialDiscovery } from './plan-services.js';
import { renderResourceCenter } from './resource-center.js';
import { renderKombaxHome } from './kombax-home.js';
// Compatibilidad de regresión histórica 20023–20055: «Entrar con mi club» · «Crear o acceder a un perfil KOMBAX» · «Solicitar o gestionar un perfil KOMBAX» · «ALTA + VERIFICACIÓN» · «Crear perfil» · «Espectador continúa cerrado».
// Taxonomía histórica preservada para contratos estáticos · Profesional / Representante: id:'competidor' · id:'marca' · id:'federacion' · id:'profesional' · id:'espectador'.
// Contrato legacy 20044 (no ejecutable): {id:'profesional',disabled:true} · {id:'espectador',disabled:true}. R28 los habilita en profile-registry.js.
// Contrato legacy 20052 (no ejecutable): {id:'club',label:'Club',icon:'club',applicationOnly:true}. El registro activo vive en profile-registry.js.
// Fixtures legacy 20055 (no ejecutables): {id:'competidor',benefits:[]} · {id:'club',applicationOnly:true,benefits:[]} · {id:'marca',benefits:[]} · {id:'federacion',benefits:[]}
// Contrato legacy 20062 (no ejecutable): {id:'competidor',label:'Competidor',icon:'fighter',benefits:['Insignia KOMBAX','Perfil deportivo avanzado','Trayectoria y oportunidades']} · ['competidor','marca','federacion'].includes(pendingType) · Club, Competidor, Marca o Federación · Competidor ya admite solicitud y verificación KOMBAX.

const directTypes=DIRECT_PROFILE_TYPES.map(x=>({...x}));
const MEMBER_FAMILY_ONBOARDING=Object.freeze({
  id:'miembro_familia',label:'Miembro / Familiar',icon:'identity',accent:'#5B8CFF',
  description:'Vincula tu cuenta con un club como practicante/miembro o familiar/tutor. La publicación Social como Miembro solo se habilita cuando el club confirma la membresía.',
  benefits:['Buscar o invitar a mi club','Membresía aprobada por el club','Evolución de Miembro a Competidor']
});
const ONBOARDING_PROFILE_ORDER=Object.freeze(['espectador','miembro_familia','competidor','club','federacion','marca','profesional','media']);
function onboardingProfileTypes(){
  const byId=new Map(directTypes.map(x=>[x.id,x]));
  byId.set(MEMBER_FAMILY_ONBOARDING.id,MEMBER_FAMILY_ONBOARDING);
  return ONBOARDING_PROFILE_ORDER.map(id=>byId.get(id)).filter(Boolean);
}
let activeAccountPolicy=null;
function requireProfileChoice(type){
  if(!activeAccountPolicy||canRequestAccountProfile(type,activeAccountPolicy))return true;
  toast('Esta cuenta ya tiene un tipo de perfil. Solo una cuenta de miembro puede solicitar Competidor.','warning');
  return false;
}
const TYPE_LABEL=PROFILE_TYPE_LABEL;
const WORKFLOW_LABEL={
  draft:t('marketing.gateway.workflow.draft'),submitted:t('marketing.gateway.workflow.submitted'),under_review:t('marketing.gateway.workflow.underReview'),needs_information:t('marketing.gateway.workflow.needsInformation'),
  verified:t('marketing.gateway.workflow.verified'),limited:t('marketing.gateway.workflow.limited'),suspended:t('marketing.gateway.workflow.suspended'),rejected:t('marketing.gateway.workflow.rejected'),withdrawn:t('marketing.gateway.workflow.withdrawn')
};
const workflowTone=stateValue=>stateValue==='verified'?'ok':stateValue==='rejected'||stateValue==='suspended'?'danger':stateValue==='needs_information'||stateValue==='limited'?'warn':'neutral';
const reviewStatusCopy=stateValue=>({
  submitted:t('marketing.gateway.review.submitted'),
  under_review:t('marketing.gateway.review.underReview'),
  needs_information:t('marketing.gateway.review.needsInformation'),
  verified:t('marketing.gateway.review.verified'),
  rejected:t('marketing.gateway.review.rejected')
}[stateValue]||'');

const COMMERCIAL_TYPE_AUDIENCE=Object.freeze({club:'club',marca:'brand',federacion:'federation'});
const commercialAudienceForType=type=>COMMERCIAL_TYPE_AUDIENCE[String(type||'')]||null;
const commercialKeys=type=>({plan:`kombax_${type}_plan_selection`,billing:`kombax_${type}_billing_selection`});
function rememberCommercialSelection(type,plan,billing='monthly'){const keys=commercialKeys(type);sessionStorage.setItem(keys.plan,String(plan||''));sessionStorage.setItem(keys.billing,String(billing||'monthly'));}
function clearCommercialSelection(type){const keys=commercialKeys(type);sessionStorage.removeItem(keys.plan);sessionStorage.removeItem(keys.billing);}
function selectedCommercialPlan(type){const keys=commercialKeys(type);return {plan_code:sessionStorage.getItem(keys.plan)||'',billing_cycle:sessionStorage.getItem(keys.billing)||'monthly'};}
const commercialPlansForType=type=>FALLBACK_COMMERCIAL_CATALOG.plans.filter(p=>p.audience===commercialAudienceForType(type));
const commercialPlanOptions=type=>commercialPlansForType(type).map(p=>({value:p.plan_code,label:p.name}));

const identityI18nKey=type=>({club:'club',marca:'brand',federacion:'federation',competidor:'fighter',profesional:'professional',media:'media',espectador:'spectator'}[type]||type);
const IDENTITY_META=Object.freeze({
  club:{icon:'club',commercial:true},marca:{icon:'brand',commercial:true},federacion:{icon:'federation',commercial:true},competidor:{icon:'fighter',commercial:false},profesional:{icon:'professional',commercial:false},media:{icon:'sparkles',commercial:false},espectador:{icon:'spectator',commercial:false}
});
const translatedList=(base,count)=>Array.from({length:count},(_,i)=>t(`${base}.${i}`)).filter(Boolean);
const identityCopy=type=>{const key=identityI18nKey(type),base=`marketing.gateway.identity.${key}`;return {
  ...IDENTITY_META[type],
  eyebrow:t(`${base}.eyebrow`),headline:t(`${base}.headline`),lead:t(`${base}.lead`),forWho:t(`${base}.forWho`),privateNote:t(`${base}.privateNote`),
  benefits:translatedList(`${base}.benefits`,5),steps:translatedList(`${base}.steps`,4)
};};

function identityPresentation(type){
  const profile=directTypes.find(x=>x.id===type)||DIRECT_PROFILE_TYPES.find(x=>x.id===type);
  const extra=identityCopy(type)||{};
  return {...profile,...extra,id:type,label:profile?.label||TYPE_LABEL[type]||type};
}

export function renderIdentityPresentation(type,{onBack,memberProfiles=[],profile=null,application=null}={}){
  const item=identityPresentation(type);if(!item?.id)return;
  const isCommercial=Boolean(item.commercial&&commercialAudienceForType(type));
  const action=type==='espectador'?t('marketing.gateway.actions.continueSpectator'):profile?t('marketing.gateway.actions.continueProfile'):isCommercial?`Crear identidad ${item.label} gratuita`:t('marketing.gateway.actions.createProfile',{profile:item.label});
  setAppHtml(`<main class="kombax-gateway direct-mode gateway-premium kx-identity-intro-page" data-kombax-view="identity-intro" data-identity-type="${esc(type)}">
    <div class="gateway-ambient" aria-hidden="true"><i></i><i></i><i></i></div>
    <section class="gateway-directory premium-surface kx-identity-intro-shell" style="--identity-accent:${esc(item.accent||'#E21D2D')}">
      <div class="gateway-directory-top"><button class="gateway-icon-button" id="kx-identity-intro-back" type="button" aria-label="${t('marketing.gateway.actions.back')}">${icon('chevronLeft',{size:22})}</button>${mark({compact:true})}<span class="gateway-directory-step">${t('marketing.gateway.identity.common.profileIntro')}</span></div>
      <section class="kx-identity-intro-hero"><div class="kx-identity-intro-icon">${featureIcon(item.icon||'identity',{size:76})}</div><div><span>${esc(item.eyebrow||item.label)}</span><h1>${esc(item.headline||item.label)}</h1><p>${esc(item.lead||item.description||'')}</p><div class="kx-identity-intro-tags"><b>${t('marketing.gateway.identity.common.account')}</b><b>${isCommercial?'Identidad pública gratuita · plan opcional':t('marketing.gateway.identity.common.noOrgPlan')}</b>${type==='espectador'?`<b>${t('marketing.gateway.identity.common.free')}</b>`:''}</div></div></section>
      <section class="kx-identity-intro-grid"><article><small>${t('marketing.gateway.identity.common.forWho')}</small><h2>${esc(item.label)}</h2><p>${esc(item.forWho||item.description||'')}</p></article><article><small>${t('marketing.gateway.identity.common.whatYouGet')}</small><ul>${(item.benefits||[]).map(x=>`<li>${icon('checkCircle',{size:16})}<span>${esc(x)}</span></li>`).join('')}</ul></article></section>
      <section class="kx-identity-intro-privacy"><span>${icon('shieldCheck',{size:24})}</span><div><small>${t('marketing.gateway.identity.common.privacy')}</small><strong>${t('marketing.gateway.identity.common.privacyTitle')}</strong><p>${esc(item.privateNote||t('marketing.gateway.identity.common.privacyFallback'))}</p></div></section>
      <section class="kx-identity-intro-steps"><div class="kx-section-title"><div><span>${t('marketing.gateway.identity.common.journey')}</span><h2>${t('marketing.gateway.identity.common.howStart')}</h2></div></div><div>${(item.steps||[]).map((x,i)=>`<article><b>${i+1}</b><span>${esc(x)}</span></article>`).join('')}</div></section>
      <footer class="kx-identity-intro-actions"><button class="btn btn-ghost" id="kx-identity-intro-back-bottom" type="button">${t('marketing.gateway.identity.common.notNow')}</button>${isCommercial?`<button class="btn btn-ghost" id="kx-identity-intro-pricing" type="button">${t('marketing.gateway.identity.common.comparePlans')}</button>`:''}<button class="btn btn-primary" id="kx-identity-intro-continue" type="button">${esc(action)}</button></footer>
    </section>
  </main>`);
  const back=()=>typeof onBack==='function'&&onBack();
  document.getElementById('kx-identity-intro-back')?.addEventListener('click',back);
  document.getElementById('kx-identity-intro-back-bottom')?.addEventListener('click',back);
  document.getElementById('kx-identity-intro-pricing')?.addEventListener('click',()=>renderPlanServices({audience:commercialAudienceForType(type),onBack:()=>renderIdentityPresentation(type,{onBack,memberProfiles,profile,application}),onSelectPlan:selection=>{rememberCommercialSelection(type,selection.plan_code,selection.billing_cycle);if(!globalAuthenticated()){sessionStorage.setItem('kombax_pending_profile_type',type);authChoice({onBack,pendingType:type});return;}if(type==='club'||profile){saveAndSubmitApplication(type,{profile,application,onBack});return;}profileEditor(type,{onBack,memberProfiles});}}));
  document.getElementById('kx-identity-intro-continue')?.addEventListener('click',()=>{
    if(type==='espectador'){if(globalAuthenticated())profileEditor(type,{onBack,memberProfiles});else{sessionStorage.setItem('kombax_pending_profile_type',type);authChoice({onBack,pendingType:type});}return;}
    if(isCommercial){if(!globalAuthenticated()){sessionStorage.setItem('kombax_pending_profile_type',type);authChoice({onBack,pendingType:type});return;}if(type==='club'||profile){saveAndSubmitApplication(type,{profile,application,onBack});return;}profileEditor(type,{onBack,memberProfiles});return;}
    if(globalAuthenticated())profileEditor(type,{profile,onBack,memberProfiles});else authChoice({onBack,pendingType:type});
  });
}



const mark=({compact=false}={})=>`<div class="gateway-brand ${compact?'compact':''}"><span class="gateway-brand-symbol"><img src="${esc(KOMBAX_BRAND.symbolWhite||KOMBAX_BRAND.symbol)}" alt=""></span><div><strong>${esc(KOMBAX_BRAND.name)}</strong><small>${esc(KOMBAX_BRAND.tagline)}</small></div></div>`;

function bindHiddenAdminTrigger(onAdminAccess){
  if(typeof onAdminAccess!=='function')return;
  const target=document.querySelector('.gateway-directory-top .gateway-brand-symbol');if(!target)return;
  let taps=[];
  target.setAttribute('role','presentation');
  target.addEventListener('click',event=>{
    const now=Date.now();taps=taps.filter(at=>now-at<=5000);taps.push(now);
    if(taps.length<8)return;
    taps=[];event.preventDefault();event.stopPropagation();onAdminAccess();
  });
}

export function renderMemberFamilyPresentation({onBack}={}){
  setAppHtml(`<main class="kombax-gateway direct-mode gateway-premium kx-identity-intro-page" data-kombax-view="member-family-intro">
    <div class="gateway-ambient" aria-hidden="true"><i></i><i></i><i></i></div>
    <section class="gateway-directory premium-surface kx-identity-intro-shell" style="--identity-accent:#5B8CFF">
      <div class="gateway-directory-top"><button class="gateway-icon-button" id="kx-member-family-back" type="button" aria-label="${t('marketing.gateway.actions.back')}">${icon('chevronLeft',{size:22})}</button>${mark({compact:true})}<span class="gateway-directory-step">MIEMBRO / FAMILIAR</span></div>
      <section class="kx-identity-intro-hero"><div class="kx-identity-intro-icon">${featureIcon('identity',{size:76})}</div><div><span>PERFIL PÚBLICO + VINCULACIÓN CON CLUB</span><h1>Miembro, practicante o familiar</h1><p>Tu cuenta KOMBAX es gratuita. Como Miembro/Practicante puedes crear tu perfil público aunque tu club todavía no use KOMBAX: foto, banner, información deportiva y álbum propio. La publicación en el feed Social permanece bloqueada hasta que un club confirme una membresía real y activa.</p><div class="kx-identity-intro-tags"><b>Perfil público gratuito</b><b>Álbum sin publicar en el feed</b><b>Club confirma la publicación</b></div></div></section>
      <section class="kx-identity-intro-body"><div class="kx-identity-intro-panel"><span>QUÉ PUEDES HACER DESDE EL PRINCIPIO</span><ul><li>Crear y compartir tu perfil público de Miembro/Practicante.</li><li>Añadir foto de perfil, banner, bio e información deportiva.</li><li>Subir fotos y vídeos a tu álbum: forman parte de tu perfil y no se publican automáticamente en el feed.</li><li>Explorar Social, Showcase y Events y buscar tu club cuando quieras vincularte.</li></ul></div><div class="kx-identity-intro-panel"><span>PUBLICACIÓN SOCIAL</span><ul><li>Crear el perfil o subir contenido al álbum no concede publicación en el feed.</li><li>El club debe confirmar una membresía real y activa.</li><li>Después se habilita la capacidad de publicar como Miembro, respetando edad y consentimientos.</li><li>Desde Miembro puedes evolucionar a Competidor conservando la misma identidad.</li></ul></div></section>
      <div class="kx-identity-intro-actions"><button class="btn btn-primary" id="kx-member-public-profile" type="button">Crear / abrir mi perfil público</button><button class="btn btn-ghost" id="kx-member-family-link" type="button">Buscar y vincular mi club</button><button class="btn btn-ghost" id="kx-member-family-competitor" type="button">Solicitar perfil Competidor</button><button class="btn btn-ghost" id="kx-member-family-explore" type="button">Explorar KOMBAX</button></div>
    </section>
  </main>`);
  document.getElementById('kx-member-family-back')?.addEventListener('click',onBack);
  document.getElementById('kx-member-public-profile')?.addEventListener('click',()=>openMemberPublicProfileSetup({onBack}));
  document.getElementById('kx-member-family-link')?.addEventListener('click',()=>renderClubDirectory({onBack:()=>renderMemberFamilyPresentation({onBack}),mode:'member'}));
  document.getElementById('kx-member-family-competitor')?.addEventListener('click',()=>renderIdentityPresentation('competidor',{onBack:()=>renderMemberFamilyPresentation({onBack})}));
  document.getElementById('kx-member-family-explore')?.addEventListener('click',()=>globalAuthenticated()?renderGlobalHome({onBack}):authChoice({onBack}));
}

async function openMemberPublicProfileSetup({onBack}={}){
  if(!globalAuthenticated()){
    sessionStorage.setItem('kombax_pending_profile_type','miembro_familia');
    authChoice({onBack,pendingType:'miembro_familia'});
    return;
  }
  try{
    const existing=await repos.kombaxIdentity.memberPublicProfile().catch(()=>({}));
    if(existing?.id){openKombaxPublicProfile(existing.id);return;}
    openForm({
      title:'Crear mi perfil público',
      subtitle:'No necesitas pertenecer a un club. El perfil y el álbum son independientes del permiso para publicar en el feed.',
      width:'720px',
      fields:[
        {name:'fecha_nacimiento',label:'Fecha de nacimiento',type:'date',required:true,full:true,help:'Se usa de forma privada para aplicar las reglas de edad. Si eres menor de 18 años, el chat directo y las compras sujetas a mayoría de edad seguirán bloqueados.'},
        {name:'acepta_normas',label:'Acepto las normas de uso del espacio público KOMBAX',type:'checkbox',required:true,value:false,full:true},
        {name:'acepta_privacidad',label:'He leído la información de privacidad aplicable al perfil público',type:'checkbox',required:true,value:false,full:true}
      ],
      submitText:'Crear perfil público',
      onSubmit:async v=>{
        if(!v.acepta_normas||!v.acepta_privacidad)throw new Error('Debes aceptar las normas y la información de privacidad.');
        const result=await repos.kombaxIdentity.activateMember({fecha_nacimiento:v.fecha_nacimiento,acepta_normas:true,acepta_privacidad:true});
        const socialId=result?.data?.social_profile_id||result?.social_profile_id;
        closeModal();toast('Perfil público de Miembro/Practicante creado. La publicación Social seguirá bloqueada hasta que un club confirme tu membresía.');
        if(socialId)openKombaxPublicProfile(socialId);else await renderDirectProfileHub({onBack});
      }
    });
  }catch(error){setError(error);}
}

export function renderKombaxGateway({onClubDirectory,onDirectProfiles}){
  setAppHtml(`<main class="kombax-gateway gateway-premium" data-kombax-view="gateway">
    <div class="gateway-ambient" aria-hidden="true"><i></i><i></i><i></i></div>
    <section class="gateway-hero premium-surface gateway-brand-stage">
      <div class="gateway-brand-watermark gateway-brand-watermark-legacy" aria-hidden="true" hidden>
        <span class="gateway-brand-watermark-symbol"><img src="${esc(KOMBAX_BRAND.symbolRed||KOMBAX_BRAND.symbolWhite||KOMBAX_BRAND.symbol)}" alt=""></span>
        <span class="gateway-brand-watermark-word">${esc(KOMBAX_BRAND.name)}</span>
        <span class="gateway-brand-watermark-tagline">${esc(KOMBAX_BRAND.tagline)}</span>
      </div>
      <div class="gateway-entry-visual" aria-hidden="true">
        <div class="gateway-entry-media"><img src="${esc(GATEWAY_HERO_IMAGE)}" alt="" loading="eager" decoding="async" fetchpriority="high"></div>
        <span class="gateway-entry-smoke smoke-red"></span>
        <span class="gateway-entry-smoke smoke-blue"></span>
        <span class="gateway-entry-smoke smoke-neutral"></span>
        <span class="gateway-entry-vignette"></span>
      </div>
      <header class="gateway-topline">${mark()}<div class="gateway-onboarding-language" data-kx-onboarding-language>${languageSelectorHtml({id:'kombax-language-onboarding',compact:true})}<small>${t('common.language.onboardingHint')}</small></div></header>
      <div class="gateway-intro">
        <span class="gateway-eyebrow">${t('marketing.gateway.home.eyebrow')}</span>
        <h1>${t('marketing.gateway.home.title')}</h1>
        <p>${esc(publicPlatformIntroduction())}</p>
        <p class="gateway-intro-secondary">${t('marketing.gateway.home.secondary')}</p>
      </div>
      <div class="gateway-paths" role="group" aria-label="${esc(t('marketing.gateway.home.accessAria'))}">
        <button class="gateway-path primary" id="gateway-club" type="button">
          <span class="gateway-path-icon">${featureIcon('club',{size:68})}</span>
          <span class="gateway-path-copy"><em>${t('marketing.gateway.home.clubEyebrow')}</em><strong>${t('marketing.gateway.home.clubTitle')}</strong><small>${t('marketing.gateway.home.clubBody')}</small></span>
          <span class="gateway-path-arrow">${icon('arrowUpRight',{size:22})}</span>
        </button>
        <button class="gateway-path" id="gateway-direct" type="button">
          <span class="gateway-path-icon">${featureIcon('identity',{size:68})}</span>
          <span class="gateway-path-copy"><em>${t('marketing.gateway.home.identityEyebrow')}</em><strong>${t('marketing.gateway.home.identityTitle')}</strong><small>${t('marketing.gateway.home.identityBody')}</small></span>
          <span class="gateway-path-arrow">${icon('arrowUpRight',{size:22})}</span>
        </button>
        <button class="gateway-path spectator" id="gateway-spectator" type="button">
          <span class="gateway-path-icon">${featureIcon('spectator',{size:68})}</span>
          <span class="gateway-path-copy"><em>${t('marketing.gateway.home.spectatorEyebrow')}</em><strong>${t('marketing.gateway.home.spectatorTitle')}</strong><small>${t('marketing.gateway.home.spectatorBody')}</small></span>
          <span class="gateway-path-arrow">${icon('arrowUpRight',{size:22})}</span>
        </button>
      </div>
      <div id="gateway-pilot-entry" class="gateway-pilot-entry" hidden></div>
      <div class="gateway-commercial-entry"><button class="btn btn-ghost" id="gateway-pricing" type="button">${t('marketing.gateway.home.pricing')}</button><small>${t('marketing.gateway.home.pricingHint')}</small></div>
      <footer class="gateway-footer" aria-label="CONNECT · COMPETE · GROW"><span>CONNECT</span><i></i><span>COMPETE</span><i></i><span>GROW</span><b>Built for combat sports</b><nav class="gateway-footer-legal" aria-label="Legal">${[["./privacy.html",GATEWAY_LEGAL_LABELS[kxGetLocale()]?.[0]||GATEWAY_LEGAL_LABELS.es[0]],["./terms.html",GATEWAY_LEGAL_LABELS[kxGetLocale()]?.[1]||GATEWAY_LEGAL_LABELS.es[1]],[`mailto:${SUPPORT_EMAIL}`,GATEWAY_LEGAL_LABELS[kxGetLocale()]?.[2]||GATEWAY_LEGAL_LABELS.es[2]]].map(([href,label])=>`<a href="${esc(href)}" ${href.startsWith('mailto:')?'':'target="_blank" rel="noopener noreferrer"'}>${esc(label)}</a>`).join('')}</nav></footer>
    </section>
  </main>`);
  bindLanguageSelectors(document,{onChange:()=>renderKombaxGateway({onClubDirectory,onDirectProfiles})});
  document.getElementById('gateway-club')?.addEventListener('click',onClubDirectory);
  document.getElementById('gateway-direct')?.addEventListener('click',onDirectProfiles);
  document.getElementById('gateway-spectator')?.addEventListener('click',()=>renderIdentityPresentation('espectador',{onBack:()=>renderKombaxGateway({onClubDirectory,onDirectProfiles})}));
  document.getElementById('gateway-pricing')?.addEventListener('click',()=>renderCommercialDiscovery({onBack:()=>renderKombaxGateway({onClubDirectory,onDirectProfiles}),onSelectPlan:selection=>startCommercialOnboarding(selection,{onBack:()=>renderKombaxGateway({onClubDirectory,onDirectProfiles})})}));
  hydratePilotClubEntry({onBack:()=>renderKombaxGateway({onClubDirectory,onDirectProfiles})}).catch(()=>{});
}

async function searchClubs(query=''){
  let remote=[];
  try{const rows=await client.rpc('app_buscar_clubes_kombax_v040',{p_query:query,p_limit:40});if(Array.isArray(rows))remote=rows;}catch(error){if(!/404|schema cache|could not find|app_buscar_clubes_kombax_v040/i.test(String(error?.message||'')))throw error;}
  const local=platformFeatures().demoDirectory?DEMO_CLUBS:DEMO_CLUBS.filter(x=>!x.demo);
  const term=String(query||'').trim().toLowerCase();
  const filtered=local.filter(c=>!term||[c.nombre,c.slug,c.ciudad,c.provincia,...(c.disciplinas||[])].some(x=>String(x||'').toLowerCase().includes(term)));
  const bySlug=new Map(filtered.map(c=>[c.slug,c]));for(const row of remote)bySlug.set(row.slug,{...bySlug.get(row.slug),...row,demo:false});
  return [...bySlug.values()].filter(club=>!isInternalDirectoryClub(club)).sort((a,b)=>Number(a.demo)-Number(b.demo)||String(a.nombre).localeCompare(String(b.nombre),'es'));
}

function demoDetail(club){
  const {wrap}=openDetail({title:club.nombre,subtitle:t('marketing.gateway.directory.demoSubtitle'),body:`<div class="demo-club-detail ${esc(themeDefinition(club.theme_id).className)}"><span>${t('marketing.gateway.directory.demoLabel')}</span><h3>${esc(club.lema||'')}</h3><p>${esc([club.ciudad,club.provincia].filter(Boolean).join(', '))}</p><div>${(club.disciplinas||[]).map(x=>`<b>${esc(x)}</b>`).join('')}</div><small>${t('marketing.gateway.directory.demoBody')}</small></div>`,actions:`<button class="btn btn-primary" id="close-demo-club">${t('marketing.gateway.directory.understood')}</button>`});
  wrap.querySelector('#close-demo-club')?.addEventListener('click',closeModal);
}

async function openMemberClubLink(club,{onBack,onSelect,onAdminAccess}){
  if(!globalAuthenticated()){
    toast('Accede con tu cuenta KOMBAX para solicitar la vinculación con un club.','warning');
    openGlobalAuth({onBack:()=>renderClubDirectory({onBack,onSelect,onAdminAccess,mode:'member'}),onAuthenticated:()=>openMemberClubLink(club,{onBack,onSelect,onAdminAccess})});
    return;
  }
  const clubId=club.club_id||club.id;
  if(!clubId){toast('Este club todavía no admite solicitudes desde KOMBAX.','warning');return;}
  try{
    const pending=await repos.kombaxMemberships.pending();
    const match=(Array.isArray(pending)?pending:[]).find(row=>String(row.club_id)===String(clubId));
    if(match){
      confirmDialog('Solicitar vinculación',`Hemos encontrado una ficha de ${club.nombre} asociada a tu correo verificado. El club deberá aprobar la vinculación antes de activar tu acceso y tu publicación como miembro.`,async()=>{await repos.kombaxMemberships.requestClaim(match.socio_id);toast('Solicitud enviada al club para su revisión.');},{confirmText:'Solicitar vinculación'});
      return;
    }
    openForm({title:`Solicitar vinculación con ${club.nombre}`,subtitle:'No necesitas código. Puedes pedir al club que autorice directamente tu acceso. El código o la invitación personal siguen disponibles como vías alternativas.',fields:[{name:'request_kind',label:'Quiero vincularme como',type:'select',required:true,value:'member',options:[{value:'member',label:'Miembro / Practicante'},{value:'family',label:'Familiar / Tutor'}]},{name:'mensaje',label:'Mensaje para el club',type:'textarea',rows:4,required:true,full:true,value:'Quiero vincular mi cuenta KOMBAX con el club. ¿Podéis revisar y autorizar mi acceso?'}],submitText:'Solicitar autorización',onSubmit:async values=>{await repos.kombaxMemberships.contactClub(clubId,values.mensaje,values.request_kind||'member');toast('Solicitud enviada. El club puede autorizarla directamente; no necesitas un código.');closeModal();}});
  }catch(error){setError(error);toast('No se pudo comprobar la vinculación. Revisa que tu correo esté confirmado.','error');}
}

export async function renderClubDirectory({onBack,onSelect,onAdminAccess,mode='manage'}){
  setAppHtml(`<main class="kombax-gateway directory-mode gateway-premium" data-kombax-view="directory">
    <div class="gateway-ambient" aria-hidden="true"><i></i><i></i><i></i></div>
    <section class="gateway-directory premium-surface">
      <div class="gateway-directory-top"><button class="gateway-icon-button" id="directory-back" type="button" aria-label="${t('marketing.gateway.actions.back')}">${icon('chevronLeft',{size:22})}</button>${mark({compact:true})}<span class="gateway-directory-step">${t('marketing.gateway.directory.access')}</span></div>
      <header><span class="gateway-eyebrow">${t('marketing.gateway.directory.eyebrow')}</span><h1>${t('marketing.gateway.directory.title')}</h1><p>${t('marketing.gateway.directory.lead')}</p></header>
      <div class="row-actions" role="group" aria-label="Acceso al club"><button class="btn ${mode==='manage'?'btn-primary':'btn-ghost'}" id="club-directory-manage" type="button">Gestiono un club</button><button class="btn ${mode==='member'?'btn-primary':'btn-ghost'}" id="club-directory-member" type="button">Formo parte de un club</button></div>
      <div class="directory-search">
        <label class="directory-search-field"><span>${icon('search',{size:20})}</span><input id="club-search" type="search" autocomplete="off" placeholder="${esc(t('marketing.gateway.directory.placeholder'))}" aria-label="${esc(t('marketing.gateway.directory.searchAria'))}"></label>
        <button class="btn btn-primary" id="club-search-button" type="button">${icon('search',{size:17})} ${t('marketing.gateway.directory.search')}</button>
        <button class="btn btn-ghost" id="club-link-button" type="button">${icon('qr',{size:17})} ${t('marketing.gateway.directory.openQr')}</button>
      </div>
      <div class="directory-meta"><span><b class="live-dot"></b> ${t('marketing.gateway.directory.directory')}</span><span>${t('marketing.gateway.directory.selectClub')}</span></div>
      <div class="kx-club-onboarding-cta"><div><strong>${mode==='member'?'¿Tu club aún no aparece?':t('marketing.gateway.directory.notYet')}</strong><span>${mode==='member'?'Puedes invitarlo a KOMBAX y solicitar después tu vinculación.':t('marketing.gateway.directory.notYetBody')}</span></div><button class="btn btn-ghost" id="club-register-new" type="button">${mode==='member'?'Invitar a mi club':t('marketing.gateway.directory.knowClub')}</button></div>
      <div id="club-directory-results" class="club-directory-results"><div class="gateway-skeleton"><i></i><i></i><i></i></div></div>
      
    </section>
  </main>`);
  document.getElementById('directory-back')?.addEventListener('click',onBack);
  document.getElementById('club-directory-manage')?.addEventListener('click',()=>renderClubDirectory({onBack,onSelect,onAdminAccess,mode:'manage'}));
  document.getElementById('club-directory-member')?.addEventListener('click',()=>renderClubDirectory({onBack,onSelect,onAdminAccess,mode:'member'}));
  document.getElementById('club-register-new')?.addEventListener('click',()=>{
    if(mode!=='member'){renderIdentityPresentation('club',{onBack:()=>renderClubDirectory({onBack,onSelect,onAdminAccess})});return;}
    openForm({title:'Invitar a mi club',subtitle:'Prepararemos un correo para que tú mismo se lo envíes al club.',fields:[{name:'email',label:'Correo del club',type:'email',required:true},{name:'nombre',label:'Nombre del club',required:true}],submitText:'Preparar invitación',onSubmit:async values=>{const subject='Invitación a KOMBAX para mi club',body=`Hola, ${values.nombre}. Me gustaría vincular mi cuenta con vuestro club en KOMBAX. Podéis conocer la plataforma y solicitar vuestro perfil público gratuito en ${window.UW_CONFIG?.release?.webUrl||'https://kombax.es'}.`;window.location.href=`mailto:${encodeURIComponent(values.email)}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;closeModal();}});
  });
  bindHiddenAdminTrigger(onAdminAccess);
  const input=document.getElementById('club-search'),box=document.getElementById('club-directory-results');
  const load=async()=>{box.innerHTML='<div class="gateway-skeleton"><i></i><i></i><i></i></div>';try{const clubs=await searchClubs(input.value);box.innerHTML=clubs.length?clubs.map(c=>`<button class="club-directory-card ${esc(themeDefinition(c.theme_id).className)} ${c.demo?'is-demo':'is-real'}" type="button" data-slug="${esc(c.slug)}"><span class="club-directory-logo">${c.logo_url?`<img src="${esc(c.logo_url)}" alt="">`:esc(String(c.nombre||'K').slice(0,2).toUpperCase())}</span><span class="club-directory-copy"><span class="club-card-heading"><strong>${esc(c.nombre)}</strong>${c.demo?`<b>${t('marketing.gateway.directory.example')}</b>`:`<b class="real-club">${t('marketing.gateway.directory.available')}</b>`}</span><small>${esc([c.ciudad,c.provincia].filter(Boolean).join(' · ')||c.lema||'')}</small><em>${esc((c.disciplinas||[]).join(' · '))}</em></span><span class="club-directory-arrow">${icon('chevronRight',{size:20})}</span></button>`).join(''):`<div class="empty premium-empty"><strong>${t('marketing.gateway.directory.noResults')}</strong><p>${t('marketing.gateway.directory.noResultsBody')}</p></div>`;box.querySelectorAll('[data-slug]').forEach(button=>button.addEventListener('click',()=>{const club=clubs.find(c=>c.slug===button.dataset.slug);if(club?.demo)demoDetail(club);else if(club){if(mode==='member')openMemberClubLink(club,{onBack,onSelect,onAdminAccess});else onSelect(club);}}));}catch(error){box.innerHTML=`<div class="empty premium-empty"><strong>${t('marketing.gateway.directory.loadError')}</strong><p>${t('marketing.gateway.directory.loadErrorBody')}</p><button class="btn btn-ghost btn-sm" id="directory-retry" type="button">${t('marketing.gateway.directory.retry')}</button></div>`;document.getElementById('directory-retry')?.addEventListener('click',load);setError(error);}};
  document.getElementById('club-search-button')?.addEventListener('click',load);input.addEventListener('keydown',e=>{if(e.key==='Enter')load();});
  document.getElementById('club-link-button')?.addEventListener('click',()=>openForm({title:t('marketing.gateway.directory.qrTitle'),subtitle:t('marketing.gateway.directory.qrSubtitle'),fields:[{name:'value',label:t('marketing.gateway.directory.qrField'),required:true}],submitText:t('marketing.gateway.directory.locate'),onSubmit:async v=>{let slug=String(v.value||'').trim().toLowerCase();try{const url=new URL(slug,location.href);slug=url.searchParams.get('club')||url.pathname.split('/').filter(Boolean).pop()||slug;}catch{}slug=slug.replace(/[^a-z0-9-]/g,'');const clubs=await searchClubs(slug),club=clubs.find(c=>c.slug===slug);if(!club)throw new Error(t('marketing.gateway.directory.notFound'));if(club.demo){closeModal();demoDetail(club);}else onSelect(club);}}));
  await load();
}

function globalAuthenticated(){return state.session?.scope==='kombax'&&Boolean(state.session?.id);}

async function hydratePilotClubEntry({onBack}={}){
  const host=document.getElementById('gateway-pilot-entry');if(!host)return;
  let pilot;try{pilot=await repos.pilot.window();}catch{return;}
  if(!pilot?.open||Number(pilot?.slots_remaining||0)<=0){host.hidden=true;host.innerHTML='';return;}
  host.hidden=false;
  host.innerHTML=`<button type="button" class="gateway-path kx-pilot-club-path" id="gateway-pilot-club"><span class="gateway-path-icon">${featureIcon('club',{size:54})}</span><span class="gateway-path-copy"><em>VENTANA TEMPORAL · ${metricPilotSlots(pilot)}</em><strong>Alta como Club Piloto</strong><small>Alta directa sin código de invitación. El Club se activa como Premium para el piloto y continúa después como Club fundador.</small></span><span class="gateway-path-arrow">${icon('arrowUpRight',{size:22})}</span></button>`;
  host.querySelector('#gateway-pilot-club')?.addEventListener('click',()=>openPilotClubActivation({onBack}));
}

function metricPilotSlots(pilot){const remaining=Math.max(0,Number(pilot?.slots_remaining||0));return `${remaining} ${remaining===1?'plaza disponible':'plazas disponibles'}`;}

function pilotAuthChoice({onBack}={}){
  sessionStorage.setItem('kombax_pending_pilot_club','1');
  const {wrap}=openDetail({title:'Alta Club Piloto',subtitle:'Alta directa durante la ventana temporal del piloto.',width:'640px',body:'<div class="gateway-auth-explain"><strong>No necesitas código de invitación</strong><p>Crea o utiliza tu cuenta KOMBAX de Club. Tras confirmar el correo, completarás los datos básicos y, mientras la ventana tenga plazas, el sistema activará directamente el Club Piloto Premium.</p></div>',actions:'<button class="btn btn-primary" id="kx-pilot-login">Ya tengo cuenta</button><button class="btn btn-ghost" id="kx-pilot-register">Crear cuenta Club</button>'});
  wrap.querySelector('#kx-pilot-login')?.addEventListener('click',()=>openGlobalAuth({onBack,pendingType:'club',mode:'login',onAuthenticated:()=>openPilotClubActivation({onBack})}));
  wrap.querySelector('#kx-pilot-register')?.addEventListener('click',()=>openGlobalAuth({onBack,pendingType:'club',mode:'register',onAuthenticated:()=>openPilotClubActivation({onBack})}));
}

async function openPilotClubActivation({onBack}={}){
  let pilot;try{pilot=await repos.pilot.window();}catch(error){setError(error);return;}
  if(!pilot?.open||Number(pilot?.slots_remaining||0)<=0){sessionStorage.removeItem('kombax_pending_pilot_club');toast('La ventana de alta Club Piloto está cerrada o ya no quedan plazas.','warning');return;}
  if(!globalAuthenticated()){pilotAuthChoice({onBack});return;}
  if(state.session?.platform_legal_required===true){sessionStorage.setItem('kombax_pending_pilot_club','1');toast('Revisa primero las Condiciones y la Política de Privacidad de KOMBAX.','warning');renderDirectProfileHub({onBack,pendingType:'club'});return;}
  openForm({
    title:'Alta Club Piloto',subtitle:'Alta directa · sin código de invitación · Premium piloto · sin documentación inicial.',width:'820px',
    fields:[
      {name:'nombre_publico',label:'Nombre del Club',required:true,full:true},
      {name:'lema',label:'Lema público'},
      {name:'descripcion',label:'Presentación pública',type:'textarea',rows:4,maxLength:1600,full:true},
      {name:'ubicacion',label:'Ubicación pública',required:true},{name:'ciudad',label:'Ciudad'},
      {name:'provincia',label:'Provincia / región'},{name:'pais',label:'País',value:'España'},
      {name:'disciplinas',label:'Disciplinas',required:true,full:true,help:'Separadas por comas; máximo 12.'},
      {name:'telefono',label:'Teléfono de contacto del Club',required:true},
      {name:'web_publica',label:'Web pública HTTPS',type:'url',full:true},{name:'instagram',label:'Instagram público',full:true},
      {name:'declaration',label:'Confirmo que estoy autorizado para dar de alta este Club en el programa piloto KOMBAX',type:'checkbox',required:true,value:false,full:true}
    ],
    submitText:'Activar Club Piloto',
    onSubmit:async v=>{
      if(!v.declaration)throw new Error('Debes confirmar que estás autorizado para registrar el Club.');
      const disciplinas=String(v.disciplinas||'').split(',').map(x=>x.trim()).filter(Boolean).slice(0,12);if(!disciplinas.length)throw new Error('Indica al menos una disciplina.');
      const result=await repos.pilot.activateClub({...v,disciplinas,declaration:true});
      sessionStorage.removeItem('kombax_pending_pilot_club');sessionStorage.removeItem('kombax_pending_profile_type');
      await backend.restore().catch(()=>null);closeModal();toast('Club Piloto activado. Premium piloto y vinculación de miembros disponibles.');
      await renderDirectProfileHub({onBack});
      return result;
    }
  });
}

function openGlobalAuth({onBack,pendingType='',mode='login',onAuthenticated=null}={}){
  if(mode==='register'){
    const registerModal=openForm({
      title:t('marketing.gateway.auth.registerTitle'),subtitle:t('marketing.gateway.auth.registerSubtitle'),
      width:'720px',
      fields:[
        {name:'nombre',label:t('marketing.gateway.auth.firstName'),required:true},{name:'apellidos',label:t('marketing.gateway.auth.lastName'),required:true},
        {name:'email',label:'Email',type:'email',required:true},{name:'password',label:t('marketing.gateway.auth.password'),type:'password',required:true,help:t('marketing.gateway.auth.passwordHelp')},
        {name:'age',label:t('marketing.gateway.auth.ageConfirm'),type:'checkbox',value:false,required:true,full:true},
        {name:'terms',label:t('marketing.gateway.auth.termsConfirm'),type:'checkbox',value:false,required:true,full:true},
        {name:'privacy',label:t('marketing.gateway.auth.privacyConfirm'),type:'checkbox',value:false,required:true,full:true}
      ],
      submitText:t('marketing.gateway.auth.create'),
      onSubmit:async v=>{
        if(!v.age)throw new Error(t('marketing.gateway.auth.ageError'));
        if(!v.terms||!v.privacy)throw new Error(t('marketing.gateway.auth.legalError'));
        if(String(v.password||'').length<8)throw new Error(t('marketing.gateway.auth.passwordError'));
        const result=await backend.registerGlobalAccount({...v,accountType:pendingType});
        activeAccountPolicy=null;
        if(result.confirmationRequired){
          sessionStorage.setItem('kombax_pending_profile_type',pendingType||'');
          toast(t('marketing.gateway.auth.confirmationToast'));
          renderDirectProfiles({onBack});
          return;
        }
        toast(t('marketing.gateway.auth.createdToast'));
        renderGlobalHome({onBack,pendingType});
        if(onAuthenticated)setTimeout(()=>Promise.resolve(onAuthenticated()).catch(setError),350);
      }
    });
    const grid=registerModal.form.querySelector('.form-grid');
    const legal=document.createElement('div');legal.className='registration-legal-links field full';legal.innerHTML=`<strong>${t('marketing.gateway.auth.readBefore')}</strong><div class="row-actions"><a class="btn btn-ghost btn-sm" href="./terms.html" target="_blank" rel="noopener noreferrer">${t('marketing.gateway.auth.terms')}</a><a class="btn btn-ghost btn-sm" href="./privacy.html" target="_blank" rel="noopener noreferrer">${t('marketing.gateway.auth.privacy')}</a></div><small>${t('marketing.gateway.auth.privacyNote')}</small>`;grid?.appendChild(legal);
    return;
  }
  const authModal=openForm({
    title:t('marketing.gateway.auth.loginTitle'),subtitle:t('marketing.gateway.auth.loginSubtitle'),
    fields:[
      {name:'email',label:'Email',type:'email',required:true},
      {name:'password',label:t('marketing.gateway.auth.password'),type:'password',required:true}
    ],
    submitText:t('marketing.gateway.auth.enter'),
    onSubmit:async v=>{await backend.signInGlobal(v.email,v.password);activeAccountPolicy=null;toast(t('marketing.gateway.auth.sessionStarted'));renderGlobalHome({onBack,pendingType:pendingType||sessionStorage.getItem('kombax_pending_profile_type')||''});if(onAuthenticated)setTimeout(()=>Promise.resolve(onAuthenticated()).catch(setError),350);}
  });
  const recover=document.createElement('button');recover.type='button';recover.className='btn btn-ghost';recover.textContent=t('marketing.gateway.auth.forgotPassword');
  recover.addEventListener('click',()=>openPasswordRecovery({prefillEmail:authModal.form.elements.email?.value||'',onComplete:()=>openGlobalAuth({onBack,pendingType,mode:'login',onAuthenticated})}));
  authModal.form.querySelector('.modal-actions')?.prepend(recover);
}

function authChoice({onBack,pendingType=''}) {
  const type=TYPE_LABEL[pendingType]||(pendingType?t('marketing.gateway.auth.profileFallback'):t('marketing.gateway.auth.spectator'));
  const {wrap}=openDetail({
    title:pendingType?t('marketing.gateway.auth.continueAs',{type}):t('marketing.gateway.auth.accountTitle'),
    subtitle:pendingType?t('marketing.gateway.auth.profileAccountSubtitle'):t('marketing.gateway.auth.freeAccountSubtitle'),
    width:'620px',
    body:pendingType?`<div class="gateway-auth-explain"><strong>${t('marketing.gateway.auth.notVerifiedTitle')}</strong><p>${t('marketing.gateway.auth.notVerifiedBody')}</p></div>`:`<div class="gateway-auth-explain"><strong>${t('marketing.gateway.auth.spectatorStartsTitle')}</strong><p>${t('marketing.gateway.auth.spectatorStartsBody')}</p></div>`,
    actions:`<button class="btn btn-primary" id="kx-auth-login">${t('marketing.gateway.auth.haveAccount')}</button><button class="btn btn-ghost" id="kx-auth-register">${t('marketing.gateway.auth.createKombax')}</button>`
  });
  wrap.querySelector('#kx-auth-login')?.addEventListener('click',()=>openGlobalAuth({onBack,pendingType,mode:'login'}));
  wrap.querySelector('#kx-auth-register')?.addEventListener('click',()=>openGlobalAuth({onBack,pendingType,mode:'register'}));
}

function profileFields(type,profile={},memberProfiles=[]){
  const fields=[
    {name:'nombre_publico',label:type==='marca'?'Nombre oficial':type==='federacion'?'Nombre institucional':'Nombre público',required:true,full:true,value:profile.nombre_publico||''},
    {name:'descripcion',label:'Presentación pública',type:'textarea',rows:5,maxLength:1600,full:true,value:profile.descripcion||'',help:'No incluyas teléfono, email, domicilio, fecha de nacimiento ni documentación privada.'},
    {name:'ubicacion',label:'Ubicación pública',value:profile.ubicacion||''},
    {name:'disciplinas',label:'Disciplinas',value:(profile.disciplinas||[]).join(', '),help:'Separadas por comas; máximo 12.'},
    {name:'categoria',label:type==='competidor'?'Categoría / nivel':'Especialidad / categoría',value:profile.categoria||''},
    {name:'club_declarado',label:type==='competidor'?'Club deportivo declarado':'Entidad o vínculo principal',value:profile.club_declarado||''},
    {name:'web_publica',label:'Web pública HTTPS',type:'url',full:true,value:profile.web_publica||''}
  ];
  if(type==='competidor'&&memberProfiles.length)fields.splice(2,0,{name:'miembro_social_id',label:'Mi perfil de Miembro',type:'select',required:true,value:memberProfiles.find(x=>String(x.identidad_social_id||'')===String(profile.origen_identidad_social_id||''))?.id||memberProfiles[0].id,options:memberProfiles.map(x=>({value:x.id,label:`Convertir ${x.nombre_publico} en Competidor (conserva Social)`})),full:true,help:'KOMBAX conservará tu perfil Social, publicaciones y Mi red al activar Competidor.'});
  if(type==='profesional'){
    fields.splice(1,0,{name:'fecha_nacimiento',label:'Fecha de nacimiento · privada',type:'date',required:!profile.id,value:'',help:'Perfil Profesional: alta autónoma 18+. Nunca se muestra públicamente.'});
    fields.splice(2,0,{name:'especialidad_principal',label:'Especialidad principal',type:'select',required:true,value:profile.profesional_especialidad_principal||'entrenador',options:PROFESSIONAL_SPECIALTIES.map(x=>({value:x.code,label:x.name})),full:true});
    fields.splice(3,0,{name:'especialidades_secundarias',label:'Especialidades secundarias',value:(profile.profesional_especialidades_secundarias||[]).join(', '),full:true,help:'Opcional. Usa códigos separados por comas; máximo 4 y nunca repitas la principal.'});
  }
  if(type==='espectador'){
    fields.splice(1,0,{name:'fecha_nacimiento',label:'Fecha de nacimiento · privada',type:'date',required:!profile.id,value:'',help:'Espectador: alta autónoma 16+. Perfil público básico, sin álbum ni publicación Social.'});
  }
  return fields;
}

function applicationFields(type,profile=null,application=null){
  const data=application?.datos_publicos||{};
  const verify=application?.datos_verificacion||{};
  const fields=[{name:'nombre_publico',label:type==='club'?'Nombre del club':`Nombre público de ${TYPE_LABEL[type]||type}`,required:true,full:true,value:application?.nombre_publico||profile?.nombre_publico||''}];
  if(type==='competidor')fields.push(
    {name:'ubicacion',label:'Ubicación pública',value:data.ubicacion||profile?.ubicacion||''},
    {name:'disciplinas',label:'Disciplina(s)',required:true,value:Array.isArray(data.disciplinas)?data.disciplinas.join(', '):(profile?.disciplinas||[]).join(', ')},
    {name:'categoria',label:'Categoría / nivel',value:data.categoria||profile?.categoria||''},
    {name:'club_declarado',label:'Club',value:data.club_declarado||profile?.club_declarado||''},
    {name:'nombre_legal',label:'Nombre legal · privado',required:true,value:verify.nombre_legal||''},
    {name:'fecha_nacimiento',label:'Fecha de nacimiento · privada',type:'date',value:verify.fecha_nacimiento||'',help:profile?.origen_identidad_social_id?'Si vienes de un Club, prevalece la edad verificada por el Club.':'Alta autónoma de Competidor: 16+.'},
    {name:'email',label:'Email de verificación · privado',type:'email',required:true,value:verify.email||''}
  );
  if(type==='marca')fields.push(
    {name:'categoria',label:'Categoría comercial',required:true,value:data.categoria||profile?.categoria||''},
    {name:'web_publica',label:'Web corporativa HTTPS',type:'url',required:true,value:data.web_publica||profile?.web_publica||''},
    {name:'razon_social',label:'Razón social · privada',required:true,value:verify.razon_social||''},
    {name:'tax_id',label:'CIF / VAT · privado',value:verify.tax_id||''},
    {name:'email_corporativo',label:'Email corporativo · privado',type:'email',required:true,value:verify.email_corporativo||''},
    {name:'responsable',label:'Responsable autorizado',required:true,value:verify.responsable||''},
    {name:'rol_responsable',label:'Cargo',required:true,value:verify.rol_responsable||''}
  );
  if(type==='federacion')fields.push(
    {name:'pais',label:'País',required:true,value:data.pais||''},{name:'territorio',label:'Territorio / ámbito',required:true,value:data.territorio||profile?.ubicacion||''},
    {name:'disciplinas',label:'Disciplina(s)',required:true,value:Array.isArray(data.disciplinas)?data.disciplinas.join(', '):(profile?.disciplinas||[]).join(', ')},
    {name:'web_publica',label:'Web institucional HTTPS',type:'url',required:true,value:data.web_publica||profile?.web_publica||''},
    {name:'nombre_legal',label:'Nombre legal de la entidad · privado',required:true,value:verify.nombre_legal||''},
    {name:'email_oficial',label:'Email oficial · privado',type:'email',required:true,value:verify.email_oficial||''},
    {name:'registro_entidad',label:'Registro / número oficial · privado',required:true,value:verify.registro_entidad||''},
    {name:'responsable',label:'Representante autorizado',required:true,value:verify.responsable||''},{name:'rol_responsable',label:'Cargo',required:true,value:verify.rol_responsable||''}
  );
  if(type==='marca'||type==='federacion'){
    const selected=selectedCommercialPlan(type);
    fields.push(
      {name:'plan_codigo',label:'Plan opcional',type:'select',value:verify.plan_codigo||selected.plan_code||'',options:[{value:'',label:'Solo identidad pública gratuita'},...commercialPlanOptions(type)],full:true,help:'Puedes solicitar la identidad pública sin plan. La verificación no realiza ningún cobro ni activa funciones de pago.'},
      {name:'billing_cycle',label:'Modalidad si eliges un plan',type:'select',value:verify.billing_cycle||selected.billing_cycle||'monthly',options:[{value:'monthly',label:'Mensual'},{value:'annual',label:'Anual'}],full:true}
    );
  }
  if(type==='profesional')fields.push(
    {name:'especialidad_principal',label:'Especialidad profesional',type:'select',required:true,value:data.especialidad_principal||profile?.profesional_especialidad_principal||'entrenador',options:PROFESSIONAL_SPECIALTIES.map(x=>({value:x.code,label:x.name})),full:true},
    {name:'especialidades_secundarias',label:'Especialidades secundarias',value:Array.isArray(data.especialidades_secundarias)?data.especialidades_secundarias.join(', '):(profile?.profesional_especialidades_secundarias||[]).join(', '),full:true},
    {name:'nombre_legal',label:'Nombre legal · privado',required:true,value:verify.nombre_legal||''},
    {name:'fecha_nacimiento',label:'Fecha de nacimiento · privada',type:'date',value:verify.fecha_nacimiento||'',help:'Debe acreditar 18+; si ya se validó en el perfil puede dejarse sin cambios.'},
    {name:'email',label:'Email profesional · privado',type:'email',required:true,value:verify.email||''}
  );
  if(type==='club')fields.push(
    {name:'lema',label:'Lema público',value:data.lema||''},{name:'descripcion',label:'Presentación pública',type:'textarea',rows:4,maxLength:1600,full:true,value:data.descripcion||'',help:'Será la presentación inicial del perfil público del Club.'},
    {name:'ubicacion',label:'Ubicación pública',required:true,value:data.ubicacion||''},{name:'ciudad',label:'Ciudad',value:data.ciudad||''},{name:'provincia',label:'Provincia / región',value:data.provincia||''},{name:'pais',label:'País',required:true,value:data.pais||'España'},
    {name:'disciplinas',label:'Disciplina(s)',required:true,value:Array.isArray(data.disciplinas)?data.disciplinas.join(', '):String(data.disciplinas||''),help:'Separadas por comas; máximo 12.'},
    {name:'web_publica',label:'Web HTTPS',type:'url',value:data.web_publica||''},{name:'instagram',label:'Instagram público',value:data.instagram||''},{name:'tiktok',label:'TikTok público',value:data.tiktok||''},{name:'youtube',label:'YouTube público',value:data.youtube||''},
    {name:'forma_entidad',label:'Tipo de club / entidad · privado',type:'select',value:verify.forma_entidad||'club_deportivo',options:[{value:'club_deportivo',label:'Club deportivo'},{value:'asociacion',label:'Asociación'},{value:'autonomo',label:'Profesional / autónomo'},{value:'gimnasio',label:'Gimnasio / centro deportivo'},{value:'escuela',label:'Escuela deportiva'},{value:'otro',label:'Otro'}]},
    {name:'nombre_legal',label:'Nombre legal · privado',required:true,value:verify.nombre_legal||''},{name:'cif',label:'CIF / identificación fiscal · privado',value:verify.cif||verify.tax_id||'',help:'Opcional en la verificación inicial. No todos los clubes operan con la misma forma jurídica.'},
    {name:'email_oficial',label:'Email oficial · privado',type:'email',required:true,value:verify.email_oficial||''},{name:'telefono',label:'Teléfono oficial · privado',required:true,value:verify.telefono||''},{name:'direccion',label:'Dirección administrativa o zona de actividad · privada',value:verify.direccion||'',full:true,help:'Puede ser la dirección del centro o una referencia de zona. La ubicación pública ya identifica la población.'},
    {name:'responsable',label:'Responsable del club',required:true,value:verify.responsable||''},{name:'rol_responsable',label:'Cargo / relación con el club',required:true,value:verify.rol_responsable||''},
    {name:'plan_codigo',label:'Plan opcional',type:'select',value:verify.plan_codigo||selectedCommercialPlan('club').plan_code||'',options:[{value:'',label:'Solo perfil público gratuito'},...commercialPlanOptions('club')],full:true,help:'Puedes solicitar el perfil público sin contratar la gestión privada. La verificación del Club no realiza ningún cobro.'},
    {name:'billing_cycle',label:'Modalidad si eliges un plan',type:'select',value:verify.billing_cycle||selectedCommercialPlan('club').billing_cycle||'monthly',options:[{value:'monthly',label:'Mensual'},{value:'annual',label:'Anual'}],full:true}
  );
  if(type==='club')fields.push({name:'tipo_acreditacion',label:'Tipo de acreditación',type:'select',required:true,value:'Documento del club / centro',options:[{value:'Licencia / acreditación federativa',label:'Licencia / acreditación federativa'},{value:'Registro de club o asociación',label:'Registro de club o asociación'},{value:'Documento fiscal o legal',label:'Documento fiscal o legal'},{value:'Documento del club / centro',label:'Documento del club / centro'},{value:'Otro documento acreditativo',label:'Otro documento acreditativo'}],full:true});
  const mediaVerification=type==='media';
  fields.push(
    {name:'evidencia',label:type==='club'?'Cómo podemos comprobar que el club existe y que puedes representarlo':mediaVerification?'Portfolio / referencias / actividad verificable':'Cómo podemos verificar esta identidad',type:'textarea',rows:4,maxLength:1200,required:true,full:true,value:verify.evidencia||'',help:type==='club'?'Indica web, red social oficial, federación, registro, centro deportivo u otra referencia contrastable. Estos datos son privados.':mediaVerification?'Indica portfolio, web, perfiles públicos, trabajos, acreditaciones o referencias suficientes para revisar tu actividad. Estos datos no se publican automáticamente.':'Describe fuentes verificables. KOMBAX no publica estos datos.'},
    {name:'documento',label:type==='club'?'Documento acreditativo privado':mediaVerification?'Documento adicional · opcional':'Documento acreditativo',type:'file',accept:'.pdf,image/jpeg,image/png,image/webp',required:!mediaVerification&&!application,full:true,help:type==='club'?'Necesario para enviar una solicitud nueva. Puede ser una licencia, registro, documento del centro u otra acreditación razonable; no tiene que ser documentación empresarial compleja. PDF/JPG/PNG/WEBP, máximo 15 MB.':mediaVerification?'Opcional. Úsalo si ayuda a acreditar tu actividad; KOMBAX puede solicitar información adicional durante la revisión. PDF/JPG/PNG/WEBP, máximo 15 MB.':'Es obligatorio disponer de al menos un documento antes del envío. PDF/JPG/PNG/WEBP, máximo 15 MB; almacenamiento privado.'},
    {name:'declaration',label:'Declaro que la información es correcta y que estoy autorizado para representar esta identidad',type:'checkbox',value:application?.declaracion_aceptada===true,required:true,full:true}
  );
  return fields;
}

async function saveAndSubmitApplication(type,{profile=null,application=null,onBack}={}){
  if(!profile&&!application&&!requireProfileChoice(type))return;
  openForm({
    title:application?.estado==='needs_information'?'Completar solicitud':`Solicitar perfil ${TYPE_LABEL[type]||type}`,
    subtitle:'La solicitud se estudia antes de conceder la identidad oficial. Pagar nunca concede la insignia automáticamente.',
    width:'900px',fields:applicationFields(type,profile,application),submitText:'Guardar y enviar',
    onSubmit:async v=>{
      if(!v.declaration)throw new Error('Debes confirmar la declaración de identidad y representación.');
      const list=String(v.disciplinas||'').split(',').map(x=>x.trim()).filter(Boolean).slice(0,12);
      const datos_publicos={ubicacion:v.ubicacion||'',ciudad:v.ciudad||'',provincia:v.provincia||'',disciplinas:list,categoria:v.categoria||'',club_declarado:v.club_declarado||'',territorio:v.territorio||'',pais:v.pais||'',web_publica:v.web_publica||'',lema:v.lema||'',descripcion:v.descripcion||'',instagram:v.instagram||'',tiktok:v.tiktok||'',youtube:v.youtube||'',especialidad_principal:v.especialidad_principal||profile?.profesional_especialidad_principal||'',especialidades_secundarias:String(v.especialidades_secundarias||'').split(',').map(x=>x.trim()).filter(Boolean).slice(0,4)};
      const datos_verificacion={responsable:v.responsable||'',rol_responsable:v.rol_responsable||'',evidencia:v.evidencia||'',forma_entidad:v.forma_entidad||'',nombre_legal:v.nombre_legal||'',fecha_nacimiento:v.fecha_nacimiento||'',email:v.email||'',razon_social:v.razon_social||'',tax_id:v.tax_id||'',cif:v.cif||'',email_corporativo:v.email_corporativo||'',email_oficial:v.email_oficial||'',telefono:v.telefono||'',direccion:v.direccion||'',registro_entidad:v.registro_entidad||'',plan_codigo:commercialAudienceForType(type)?(v.plan_codigo||selectedCommercialPlan(type).plan_code||''):'',billing_cycle:commercialAudienceForType(type)?(v.billing_cycle||selectedCommercialPlan(type).billing_cycle||'monthly'):''};
      const saved=await repos.kombaxProfiles.saveApplication({solicitud_id:application?.id||null,tipo:type,perfil_directo_id:profile?.id||null,nombre_publico:v.nombre_publico,datos_publicos,datos_verificacion,declaracion_aceptada:true});
      const row=saved?.data||saved;const id=row?.id||application?.id;if(!id)throw new Error('No se pudo verificar el identificador de la solicitud guardada.');
      if(v.documento)await repos.kombaxProfiles.uploadVerificationDocument(id,type==='club'?(v.tipo_acreditacion||'Documento acreditativo'):'acreditacion',v.documento);
      try{await repos.kombaxProfiles.submitApplication(id);}
      catch(error){toast('Borrador guardado. Revisa los requisitos antes de reenviar.','warning');throw error;}
      if(commercialAudienceForType(type))clearCommercialSelection(type);toast('Solicitud enviada a revisión KOMBAX');await renderDirectProfileHub({onBack});
    }
  });
}

function profileEditor(type,{profile=null,onBack,memberProfiles=[]}={}){
  if(!profile&&!requireProfileChoice(type))return;
  openForm({
    title:profile?'Editar perfil KOMBAX':`Preparar solicitud ${TYPE_LABEL[type]||type}`,
    subtitle:type==='competidor'?'Tu cuenta personal puede solicitar Competidor de forma autónoma. No necesitas un Club; si ya eres Miembro puedes conservar publicaciones y Mi red. La condición Competidor exige revisión.':type==='espectador'?'Perfil público básico 16+. Puede usar foto y banner; no dispone de álbum ni publica en el feed Social.':type==='profesional'?'Actividad profesional 18+. La especialidad define elegibilidad; la verificación habilita capacidades sensibles.':type==='media'?'Canal, medio o creador de contenido. La verificación habilita únicamente Social, Showcase y su identidad pública.':'Primero preparas la identidad. La verificación y el servicio se activan por separado.',
    width:'840px',initial:profile||{},fields:profileFields(type,profile||{},memberProfiles),submitText:'Guardar borrador',
    onSubmit:async v=>{
      const disciplinas=String(v.disciplinas||'').split(',').map(x=>x.trim()).filter(Boolean).slice(0,12);
      const result=await repos.kombaxProfiles.saveProfile({perfil_directo_id:profile?.id||null,tipo:type,nombre_publico:v.nombre_publico,descripcion:v.descripcion||'',ubicacion:v.ubicacion||'',disciplinas,categoria:v.categoria||'',club_declarado:v.club_declarado||'',web_publica:v.web_publica||'',miembro_social_id:v.miembro_social_id||null,fecha_nacimiento:v.fecha_nacimiento||null,especialidad_principal:v.especialidad_principal||null,especialidades_secundarias:String(v.especialidades_secundarias||'').split(',').map(x=>x.trim()).filter(Boolean).slice(0,4)});
      toast(profile?'Perfil actualizado':'Borrador de solicitud creado');const saved=result?.data||result;if(!profile&&saved?.id&&commercialAudienceForType(type)&&selectedCommercialPlan(type).plan_code)sessionStorage.setItem('kombax_new_profile_id',saved.id);
      await renderDirectProfileHub({onBack});
    }
  });
}

async function openAlbum(profile,{onBack}={}){
  const rows=await repos.kombaxProfiles.album(profile.id);
  const spectator=profile.tipo==='espectador';
  const photos=spectator?[]:rows.filter(x=>x.tipo==='photo'&&x.estado!=='removed');
  const videos=spectator?[]:rows.filter(x=>x.tipo==='video'&&x.estado!=='removed');
  const avatar=rows.find(x=>x.tipo==='avatar'&&x.estado!=='removed');
  const banner=rows.find(x=>x.tipo==='banner'&&x.estado!=='removed');
  const mediaUrl=m=>m?backend.publicUrl('kombax-public-media',m.storage_path):'';
  const mediaPoster=m=>m?.media_presentation?.cover_storage_path?backend.publicUrl('kombax-public-media',m.media_presentation.cover_storage_path):'';
  const tile=m=>`<article class="kx-album-tile">${m.tipo==='video'?`<div class="kx-album-video-shell"><video ${mediaFrameAttrs(m.media_presentation,'album')} src="${esc(mediaUrl(m))}" ${mediaPoster(m)?`poster="${esc(mediaPoster(m))}"`:''} preload="metadata" controls playsinline></video><button type="button" class="kx-profile-media-expand" data-kx-direct-video-open="${esc(m.id)}" aria-label="Ver vídeo a pantalla completa">${icon('arrowUpRight',{size:18})}</button></div>`:`<button type="button" class="kx-album-photo-open" data-kx-direct-media-open="${esc(m.id)}" aria-label="Ver foto a pantalla completa"><img ${mediaFrameAttrs(m.media_presentation,'album')} src="${esc(mediaUrl(m))}" alt=""></button>`}<footer><span>${esc(m.tipo)}</span>${['photo','video'].includes(m.tipo)?`<button class="btn btn-ghost btn-sm" data-kx-media-frame="${esc(m.id)}">Ajustar álbum</button>`:''}${m.tipo==='video'?`<button class="btn btn-ghost btn-sm" data-kx-direct-video-cover="${esc(m.id)}">Elegir portada</button>`:''}<button class="btn btn-ghost btn-sm" data-kx-media-remove="${esc(m.id)}">Retirar</button></footer></article>`;
  const {wrap}=openDetail({
    title:spectator?`Foto y banner · ${profile.nombre_publico}`:`Álbum · ${profile.nombre_publico}`,
    subtitle:spectator?'El perfil Espectador no dispone de álbum ni de publicación Social.':'${photos.length}/10 fotos · ${videos.length}/3 vídeos · vídeo máximo 60 s',
    width:'980px',
    body:`<div class="kx-album-hero">${avatar?`<div><img ${mediaFrameAttrs(avatar.media_presentation,'avatar').replace('class="kx-media-frame-img"','class="kx-media-frame-img kx-avatar-preview"')} src="${esc(mediaUrl(avatar))}" alt=""><button class="btn btn-ghost btn-sm" data-kx-media-frame="${esc(avatar.id)}" data-kx-frame-preset="avatar">Ajustar avatar</button></div>`:'<span class="kx-avatar-preview placeholder">KX</span>'}${banner?`<div><img ${mediaFrameAttrs(banner.media_presentation,'banner').replace('class="kx-media-frame-img"','class="kx-media-frame-img kx-banner-preview"')} src="${esc(mediaUrl(banner))}" alt=""><button class="btn btn-ghost btn-sm" data-kx-media-frame="${esc(banner.id)}" data-kx-frame-preset="banner">Ajustar banner</button></div>`:'<div class="kx-banner-preview placeholder">BANNER</div>'}</div><div class="row-actions kx-album-actions">${spectator?'':`<button class="btn btn-primary btn-sm" data-kx-upload="photo">+ Foto</button><button class="btn btn-ghost btn-sm" data-kx-upload="video">+ Vídeo</button>`}<button class="btn btn-ghost btn-sm" data-kx-upload="avatar">Avatar</button><button class="btn btn-ghost btn-sm" data-kx-upload="banner">Banner</button></div>${spectator?'<div class="premium-empty compact"><strong>Perfil Espectador</strong><p>Puedes personalizar foto y banner. El álbum y la publicación en el feed Social no están disponibles para esta identidad.</p></div>':`<div class="kx-album-grid">${[...photos,...videos].map(tile).join('')||'<div class="empty"><strong>Álbum vacío</strong><p>Las fotos y vídeos públicos aparecerán aquí.</p></div>'}</div>`}`,
    actions:'<button class="btn btn-ghost" id="kx-album-close">Cerrar</button>'
  });
  wrap.querySelector('#kx-album-close')?.addEventListener('click',closeModal);
  wrap.querySelectorAll('[data-kx-upload]').forEach(button=>button.addEventListener('click',()=>{
    const type=button.dataset.kxUpload;
    openForm({
      title:`Subir ${type==='photo'?'foto':type==='video'?'vídeo':type}`,
      subtitle:type==='video'?'El vídeo se valida antes de guardar: máximo 60 segundos en MP4/HD recomendado.':'Las imágenes se optimizan antes de almacenarse.',
      fields:[{name:'file',label:'Archivo',type:'file',required:true,accept:type==='video'?'video/mp4,video/webm,video/quicktime':'image/jpeg,image/png,image/webp',full:true}],
      submitText:'Subir',
      onSubmit:async v=>{await repos.kombaxProfiles.uploadMedia(profile.id,type,v.file);toast('Multimedia guardada');closeModal();await openAlbum(profile,{onBack});}
    });
  }));
  wrap.querySelectorAll('[data-kx-direct-media-open]').forEach(button=>button.addEventListener('click',()=>{const media=rows.find(x=>String(x.id)===String(button.dataset.kxDirectMediaOpen));if(!media)return;openImmersiveMedia({src:mediaUrl(media),type:'image',alt:`Foto del perfil ${profile.nombre_publico}`});}));
  wrap.querySelectorAll('[data-kx-direct-video-open]').forEach(button=>button.addEventListener('click',()=>{const media=rows.find(x=>String(x.id)===String(button.dataset.kxDirectVideoOpen));if(!media)return;openImmersiveMedia({src:mediaUrl(media),type:'video',poster:mediaPoster(media),alt:`Vídeo del perfil ${profile.nombre_publico}`});}));
  wrap.querySelectorAll('[data-kx-media-frame]').forEach(button=>button.addEventListener('click',()=>{const media=rows.find(x=>String(x.id)===String(button.dataset.kxMediaFrame));if(!media)return;const preset=button.dataset.kxFramePreset||(['photo','video'].includes(media.tipo)?'album':media.tipo);openMediaFramingEditor({title:`Ajustar ${['photo','video'].includes(media.tipo)?'contenido del álbum':media.tipo}`,subtitle:'Completo, Equilibrado o Rellenar. El archivo original se conserva intacto.',src:mediaUrl(media),mediaType:media.tipo==='video'?'video':'image',initial:media.media_presentation,preset,onSave:async presentation=>{await repos.mediaFraming.set('profile_media',media.id,presentation);closeModal();setTimeout(()=>openAlbum(profile,{onBack}),120);}});}));
  wrap.querySelectorAll('[data-kx-direct-video-cover]').forEach(button=>button.addEventListener('click',()=>{const media=rows.find(x=>String(x.id)===String(button.dataset.kxDirectVideoCover));if(!media||media.tipo!=='video')return;openVideoCoverEditor({src:mediaUrl(media),initial:media.media_presentation,title:'Portada del vídeo · álbum KOMBAX',subtitle:'Automática, fotograma elegido o imagen propia. El vídeo original no se modifica.',onSave:async({file,mode,time})=>{await repos.kombaxProfiles.setVideoCover(profile.id,media,file,{presentation:media.media_presentation||{},mode,time});closeModal();setTimeout(()=>openAlbum(profile,{onBack}),120);}});}));
  wrap.querySelectorAll('[data-kx-media-remove]').forEach(button=>button.addEventListener('click',()=>{
    const media=rows.find(x=>x.id===button.dataset.kxMediaRemove);if(!media)return;
    confirmDialog('Eliminar multimedia','Dejará de mostrarse en el perfil. El registro mantiene trazabilidad.',async()=>{await repos.kombaxProfiles.removeMedia(media);toast('Multimedia eliminada');closeModal();await openAlbum(profile,{onBack});},{confirmText:'Eliminar',danger:true});
  }));
}

function applicationCard(app,profile,onBack){
  const stateLabel=WORKFLOW_LABEL[app.estado]||app.estado;
  const statusCopy=reviewStatusCopy(app.estado);
  const planInfo=commercialAudienceForType(app.tipo)&&app.datos_verificacion?.plan_codigo?`<div class="kx-review-status neutral"><strong>Plan solicitado</strong><span>${esc(app.datos_verificacion.plan_codigo)} · ${app.datos_verificacion.billing_cycle==='annual'?'Anual':'Mensual'}</span></div>`:'';
  const pilotInfo=app.tipo==='club'&&app.datos_verificacion?.pilot_requested===true?'<div class="kx-review-status neutral"><strong>Piloto solicitado</strong><span>La plaza y el nivel de acceso requieren confirmación de KOMBAX. No necesitas tarjeta para el piloto.</span></div>':'';
  return `<article class="kx-application-card"><header><div><span>VERIFICACIÓN</span><strong>${esc(TYPE_LABEL[app.tipo]||app.tipo)}</strong></div><b class="kx-state ${esc(workflowTone(app.estado))}">${esc(stateLabel)}</b></header><p>${esc(app.nombre_publico)}</p>${pilotInfo}${planInfo}${statusCopy?`<div class="kx-review-status ${esc(workflowTone(app.estado))}"><strong>${esc(stateLabel)}</strong><span>${esc(statusCopy)}</span></div>`:''}${app.motivo_revision?`<div class="kx-review-note">${esc(app.motivo_revision)}</div>`:''}<footer>${['draft','needs_information'].includes(app.estado)?`<button class="btn btn-primary btn-sm" data-kx-application-edit="${esc(app.id)}">Completar / enviar</button>`:''}${['submitted','under_review','needs_information'].includes(app.estado)?`<button class="btn btn-ghost btn-sm" data-kx-application-withdraw="${esc(app.id)}">Retirar</button>`:''}</footer></article>`;
}

async function openGlobalDeletionCenter(){
  try{
    const rows=await repos.accountDeletion.list().catch(()=>[]);const open=rows.filter(x=>['requested','in_review','needs_information','confirmed'].includes(x.estado));
    const modal=openDetail({title:'Eliminar cuenta KOMBAX',subtitle:'Solicitud trazable de datos y cuenta',width:'720px',body:`<div class="kx-deletion-center"><div class="alert alert-warning"><strong>No se borra trazabilidad legal de forma indiscriminada</strong><span>La solicitud afecta a tu cuenta y datos eliminables. Los registros sujetos a obligaciones legales se conservan únicamente durante el periodo aplicable.</span></div>${open.length?`<div class="kx-deletion-list">${open.map(r=>`<article><strong>${esc(r.alcance==='account'?'Cuenta personal':r.alcance)}</strong><span>${esc(r.estado)}</span>${['requested','needs_information'].includes(r.estado)?`<button class="btn btn-ghost btn-sm" data-kx-delete-cancel="${esc(r.id)}">Cancelar</button>`:''}</article>`).join('')}</div>`:'<p class="muted">No hay solicitudes abiertas.</p>'}<p><a href="./delete-account.html" target="_blank" rel="noopener noreferrer">Ver recurso público de eliminación</a></p></div>`,actions:'<button class="btn btn-danger" id="kx-delete-request">Solicitar eliminación de mi cuenta</button>'});
    modal.wrap.querySelector('#kx-delete-request')?.addEventListener('click',()=>openForm({title:'Solicitar eliminación',subtitle:'Puedes indicar un motivo opcional.',fields:[{name:'motivo',label:'Motivo',type:'textarea',rows:4,full:true,maxLength:1200}],submitText:'Enviar solicitud',onSubmit:async v=>{await repos.accountDeletion.request({alcance:'account',motivo:v.motivo||''});toast('Solicitud registrada');closeModal();setTimeout(openGlobalDeletionCenter,180);}}));
    modal.wrap.querySelectorAll('[data-kx-delete-cancel]').forEach(b=>b.addEventListener('click',()=>confirmDialog('Cancelar solicitud','La solicitud dejará de tramitarse.',async()=>{await repos.accountDeletion.cancel(b.dataset.kxDeleteCancel);toast('Solicitud cancelada');closeModal();setTimeout(openGlobalDeletionCenter,180);},{confirmText:'Cancelar solicitud'})));
  }catch(error){setError(error);}
}

export function renderGlobalHome({onBack=()=>renderDirectProfileHub({onBack:()=>{}}),pendingType='',restoreLast=false}={}){
  if(!globalAuthenticated()){renderDirectProfiles({onBack});return;}
  if(state.session?.platform_legal_required===true){renderDirectProfileHub({onBack,pendingType});return;}
  if(restoreLast){const last=localStorage.getItem('kombax_last_global_view')||'home';if(last==='social')return openGlobalArea(renderKombaxSocial,{onBack:()=>renderGlobalHome({onBack,pendingType}),title:'KOMBAX Social'});if(last==='showcase')return openGlobalArea(renderShowcase,{onBack:()=>renderGlobalHome({onBack,pendingType}),title:'KOMBAX Showcase'});if(last==='events')return openGlobalArea(renderKombaxEvents,{onBack:()=>renderGlobalHome({onBack,pendingType}),title:'KOMBAX Events'});if(last==='workspace')return renderDirectProfileHub({onBack:()=>renderGlobalHome({onBack,pendingType}),pendingType});}
  localStorage.setItem('kombax_last_global_view','home');
  const openHome=()=>renderGlobalHome({onBack,pendingType});
  return renderKombaxHome({standalone:true,contextName:state.session?.active_identity_name||state.session?.nombre||'Mi KOMBAX',onBack,onNavigate:target=>{
    if(target==='workspace')return renderDirectProfileHub({onBack:openHome,pendingType});
    if(target==='social')return openGlobalArea(renderKombaxSocial,{onBack:openHome,title:'KOMBAX Social'});
    if(target==='showcase')return openGlobalArea(renderShowcase,{onBack:openHome,title:'KOMBAX Showcase'});
    if(target==='kombax-events')return openGlobalArea(renderKombaxEvents,{onBack:openHome,title:'KOMBAX Events'});
    if(['guides','consulting','training'].includes(target))return renderResourceCenter({standalone:true,onBack:openHome});
  }});
}

async function openGlobalArea(renderer,{onBack,title}){
  const key=title==='KOMBAX Social'?'social':title==='KOMBAX Showcase'?'showcase':title==='KOMBAX Events'?'events':'';if(key)localStorage.setItem('kombax_last_global_view',key);
  setAppHtml(`<div class="kx-global-module-shell"><header class="kx-global-module-top"><button class="gateway-icon-button" id="kx-global-area-back" type="button" aria-label="${t('marketing.gateway.actions.back')}">${icon('chevronLeft',{size:22})}</button>${mark({compact:true})}<span>${esc(title)}</span></header><main id="main-view" class="main-view"><div class="loading-card">Abriendo ${esc(title)}…</div></main></div>`);
  document.getElementById('kx-global-area-back')?.addEventListener('click',onBack||(()=>renderGlobalHome()));
  try{await renderer();}catch(error){setError(error);}
}

export async function renderDirectProfileHub({onBack,pendingType=''}={}){
  if(!globalAuthenticated()){renderDirectProfiles({onBack});return;}
  if(state.session?.platform_legal_required===true){
    setAppHtml(`<main class="kombax-gateway direct-mode gateway-premium" data-kombax-view="platform-legal-required"><div class="gateway-ambient" aria-hidden="true"><i></i><i></i><i></i></div><section class="gateway-directory premium-surface"><div class="gateway-directory-top">${mark({compact:true})}<span class="gateway-directory-step">CONDICIONES KOMBAX</span></div><div class="premium-empty"><strong>Revisión necesaria antes de continuar</strong><p>Lee y acepta las Condiciones de uso y confirma que has leído la Política de Privacidad global.</p><button class="btn btn-primary" id="kx-open-platform-legal">Revisar ahora</button></div></section></main>`);
    const openGate=()=>showPlatformLegalGate({onAccepted:()=>renderGlobalHome({onBack,pendingType}),onExit:()=>renderDirectProfiles({onBack})});
    document.getElementById('kx-open-platform-legal')?.addEventListener('click',openGate);openGate();return;
  }
  localStorage.setItem('kombax_last_global_view','workspace');
  setAppHtml(`<main class="kombax-gateway direct-mode gateway-premium" data-kombax-view="profile-hub"><div class="gateway-ambient" aria-hidden="true"><i></i><i></i><i></i></div><section class="gateway-directory premium-surface"><div class="gateway-directory-top"><button class="gateway-icon-button" id="kx-hub-back" type="button" aria-label="${t('marketing.gateway.actions.back')}">${icon('chevronLeft',{size:22})}</button>${mark({compact:true})}<span class="gateway-directory-step">MI CUENTA KOMBAX</span></div><div class="kx-hub-loading"><strong>Cargando identidad KOMBAX…</strong></div></section></main>`);
  document.getElementById('kx-hub-back')?.addEventListener('click',onBack);
  try{
    const [rawProfiles,rawApplications,socialProfiles,rawManagedClubs,memberships,memberPublicRaw]=await Promise.all([repos.kombaxProfiles.mine(),repos.kombaxProfiles.applications(),repos.kombaxSocial.myProfiles().catch(()=>[]),repos.kombaxProfiles.clubs().catch(()=>[]),repos.kombaxMemberships.active(),repos.kombaxIdentity.memberPublicProfile().catch(()=>({}))]);
    const supportDirect=state.session?.support_mode===true&&state.session?.support_entity_type&&state.session.support_entity_type!=='club';
    const profiles=supportDirect?(rawProfiles||[]).filter(x=>String(x.id)===String(state.session.support_entity_id)):(rawProfiles||[]);
    const applications=supportDirect?(rawApplications||[]).filter(x=>String(x.perfil_directo_id)===String(state.session.support_entity_id)):(rawApplications||[]);
    const managedClubs=supportDirect?[]:(rawManagedClubs||[]);
    const memberPublicProfile=!supportDirect&&memberPublicRaw?.id?memberPublicRaw:null;
    const memberProfilesBase=supportDirect?[]:(socialProfiles||[]).filter(x=>x.sujeto_tipo==='miembro');
    const memberProfiles=memberPublicProfile&&!memberProfilesBase.some(x=>String(x.id)===String(memberPublicProfile.id))?[...memberProfilesBase,memberPublicProfile]:memberProfilesBase;
    activeAccountPolicy=accountProfilePolicy({profiles:rawProfiles||[],applications:rawApplications||[],managedClubs:rawManagedClubs||[],memberProfiles,memberships:memberships||[]});
    const profileById=new Map(profiles.map(x=>[x.id,x]));
    const clubById=new Map((managedClubs||[]).map(x=>[x.club_id,x]));
    const identityCount=profiles.length+(managedClubs||[]).length;
    const membershipRows=supportDirect?[]:(memberships||[]);
    const memberMemberships=membershipRows.filter(x=>x.modo==='alumno'&&x.estado==='activo');
    const familyMemberships=membershipRows.filter(x=>x.modo==='tutor'&&x.estado==='activo');
    const workspaceCount=identityCount+membershipRows.length+(memberPublicProfile?1:0);
    const freeUnconfiguredAccount=!supportDirect&&workspaceCount===0;
    const membershipCards=membershipRows.map(m=>`<article class="kx-profile-owned kx-member-identity"><header><div class="direct-profile-icon">${featureIcon('identity',{size:44})}</div><div><span>${m.modo==='alumno'?'MIEMBRO / PRACTICANTE':'FAMILIAR / TUTOR'}</span><strong>${esc(m.modo==='alumno'?`${m.alumno_nombre||''} ${m.alumno_apellidos||''}`.trim():(m.club_nombre||'Membresía KOMBAX'))}</strong><small>${esc(m.club_nombre||'Club KOMBAX')}</small></div><b class="kx-state ok">Confirmado</b></header><p>${m.modo==='alumno'?'Tu club ha confirmado esta membresía. Puedes activar o usar tu identidad Social de Miembro si cumples las reglas de edad/consentimiento; también puedes evolucionar a Competidor sin crear otra cuenta.':'Tu vínculo familiar/tutor está activo. Permite gestionar la relación correspondiente, pero no concede publicación Social como Miembro.'}</p><div class="kx-profile-tags"><span>${m.modo==='alumno'?'Membresía activa':'Vínculo familiar activo'}</span><span>${m.modo==='alumno'?'Social sujeto a activación':'Sin publicación como Miembro'}</span></div><footer>${m.club_slug?`<button class="btn btn-primary btn-sm" data-kx-membership-enter="${esc(m.club_slug)}">Entrar en ${esc(m.club_nombre||'mi club')}</button>`:''}${m.modo==='alumno'?`<button class="btn btn-ghost btn-sm" data-kx-membership-social="${esc(m.club_id)}">Abrir Social</button>`:''}</footer></article>`).join('');
    const memberPublicCard=memberPublicProfile?`<article class="kx-profile-owned kx-member-public-identity"><header><div class="direct-profile-icon">${featureIcon('identity',{size:44})}</div><div><span>PERFIL PÚBLICO · MIEMBRO / PRACTICANTE</span><strong>${esc(memberPublicProfile.nombre_publico||state.session?.nombre||'Mi perfil')}</strong><small>${memberPublicProfile.membership_confirmed?'Membresía de club confirmada':'Independiente de club · cuenta gratuita'}</small></div><b class="kx-state ${memberPublicProfile.membership_confirmed?'ok':'neutral'}">${memberPublicProfile.membership_confirmed?'Confirmado':'Perfil activo'}</b></header><p>${memberPublicProfile.membership_confirmed?'Tu perfil público y tu membresía están vinculados. Puedes publicar como Miembro conforme a las reglas de Social.':'Puedes completar tu perfil, avatar, banner y álbum. El contenido del álbum no se publica automáticamente y el feed Social seguirá bloqueado hasta que un club confirme tu membresía.'}</p><div class="kx-profile-tags"><span>Perfil público</span><span>Álbum habilitado</span><span>${memberPublicProfile.publication_enabled?'Publicación habilitada':'Feed bloqueado hasta club'}</span></div><footer><button class="btn btn-primary btn-sm" data-kx-member-public-open="${esc(memberPublicProfile.id)}">Ver / gestionar perfil</button>${memberPublicProfile.membership_confirmed?'':`<button class="btn btn-ghost btn-sm" data-kx-member-public-link>Buscar mi club</button>`}</footer></article>`:'';
    localStorage.setItem('kombax_last_global_view','workspace');
  setAppHtml(`<main class="kombax-gateway direct-mode gateway-premium" data-kombax-view="profile-hub">
      <div class="gateway-ambient" aria-hidden="true"><i></i><i></i><i></i></div>
      <section class="gateway-directory premium-surface">
        <div class="gateway-directory-top"><button class="gateway-icon-button" id="kx-hub-back" type="button" aria-label="${t('marketing.gateway.actions.back')}">${icon('chevronLeft',{size:22})}</button>${mark({compact:true})}<button class="btn btn-ghost btn-sm" id="kx-hub-home" type="button">${icon('home',{size:16})} Inicio</button><span class="gateway-directory-step">${supportDirect?'MODO SOPORTE KOMBAX':'MI CUENTA KOMBAX'}</span></div>
        ${supportDirect?`<div class="kx-support-mode-banner embedded"><div>${icon('shieldCheck',{size:18})}<span><strong>MODO SOPORTE KOMBAX</strong><small>${esc(state.session?.support_name||'Perfil')} · ${esc(state.session?.support_reason||'Acceso administrativo auditado')}</small></span></div><button class="btn btn-ghost btn-sm" id="support-mode-exit" type="button">Salir del modo soporte</button></div>`:''}
        <header class="kx-hub-header"><div><span class="gateway-eyebrow">${supportDirect?'SOPORTE ADMINISTRATIVO':freeUnconfiguredAccount?'CUENTA KOMBAX GRATUITA':memberMemberships.length?'MIEMBRO / PRACTICANTE · CUENTA GRATUITA':familyMemberships.length?'FAMILIAR / TUTOR · CUENTA GRATUITA':'IDENTIDAD GLOBAL'}</span><h1>${esc(supportDirect?(state.session?.support_name||'Perfil KOMBAX'):(state.session?.nombre||'Mi KOMBAX'))}</h1><p>${supportDirect?'Gestionas esta identidad con tu cuenta Owner real. No se cambia la propiedad ni se añade tu cuenta a su equipo.':freeUnconfiguredAccount?'Tu cuenta gratuita ya puede explorar KOMBAX. Crear la cuenta no te asigna automáticamente un perfil: elige Espectador, Miembro/Familiar u otra identidad cuando quieras completarla.':memberMemberships.length?'Tu club ha confirmado tu membresía. La publicación Social como Miembro solo se habilita desde esta relación real y activa.':familyMemberships.length?'Tu vínculo familiar/tutor está activo. Puedes navegar, comprar y gestionar la relación con el club, sin obtener automáticamente publicación Social como Miembro.':'Gestiona perfiles, solicitudes y multimedia sin mezclar los datos administrativos de tus clubes.'}</p></div>${supportDirect?'':`<div class="kx-account-actions"><span>${esc(state.session?.email||'')}</span><button class="btn btn-ghost btn-sm" id="kx-global-change-password">Cambiar contraseña</button><button class="btn btn-ghost btn-sm" id="kx-global-logout">Cerrar sesión</button></div>`}</header>
        ${freeUnconfiguredAccount?`<section class="kx-spectator-home"><div class="kx-spectator-home-head"><div><span>EXPLORA KOMBAX</span><h2>Explora ahora. Completa tu perfil cuando quieras.</h2><p>Tu cuenta gratuita puede conocer la comunidad, los productos y los eventos sin quedar etiquetada automáticamente como Espectador. La publicación Social y la gestión privada aparecen solo cuando una identidad o membresía real las habilita.</p></div><button class="btn btn-ghost" id="kx-spectator-profile-info" type="button">¿Qué perfiles existen?</button></div><div class="kx-spectator-cards"><button type="button" class="kx-spectator-card social" id="kx-spectator-social"><span>${featureIcon('identity',{size:38})}</span><div><small>COMUNIDAD</small><strong>KOMBAX Social</strong><p>Descubre perfiles y publicaciones. Puedes dar like, comentar y compartir según las reglas de Social.</p><b>Entrar en Social ${icon('chevronRight',{size:16})}</b></div></button><button type="button" class="kx-spectator-card showcase" id="kx-spectator-showcase"><span>${featureIcon('brand',{size:38})}</span><div><small>ESCAPARATE</small><strong>KOMBAX Showcase</strong><p>Explora productos y propuestas, guarda intereses y pide información al vendedor. Comprar requiere cumplir los requisitos comerciales y de mayoría de edad.</p><b>Ver Showcase ${icon('chevronRight',{size:16})}</b></div></button><button type="button" class="kx-spectator-card events" id="kx-spectator-events"><span>${featureIcon('club',{size:38})}</span><div><small>AGENDA Y EXPERIENCIAS</small><strong>KOMBAX Events</strong><p>Descubre eventos, carteleras, seminarios y contenidos públicos. Las compras de entradas mantienen sus requisitos de edad y checkout.</p><b>Ver Events ${icon('chevronRight',{size:16})}</b></div></button></div><div class="kx-spectator-identity-cta"><div><small>CUANDO QUIERAS DAR EL SIGUIENTE PASO</small><strong>Elige el recorrido que te corresponde.</strong><span>Espectador, Miembro/Familiar, Competidor, Club, Federación, Marca, Profesional y Media / Creador tienen reglas distintas. Miembro nunca publica por autodeclaración: el club confirma la membresía.</span></div><button class="btn btn-primary" id="kx-spectator-create-profile" type="button">Explorar perfiles</button><button class="btn btn-ghost" id="kx-spectator-plans" type="button">Planes y precios</button></div></section>`:''}
        ${supportDirect?'':`<div class="kx-hub-actions ${freeUnconfiguredAccount?'spectator-minimal':''}">${activeAccountPolicy.canCreate?'<button class="btn btn-primary" id="kx-new-profile">+ Solicitar perfil</button>':''}${freeUnconfiguredAccount?'':`<button class="btn btn-ghost" id="kx-open-social">KOMBAX Social</button><button class="btn btn-ghost" id="kx-open-showcase">Showcase</button><button class="btn btn-ghost" id="kx-open-events">Events</button>`}<button class="btn btn-ghost" id="kx-open-resources">${esc(t('prepilot.resources'))}</button><button class="btn btn-ghost" id="kx-open-plans">Planes y precios</button><button class="btn btn-ghost" id="kx-account-privacy">Privacidad y eliminación</button><button class="btn btn-ghost" id="kx-account-support">Privacidad y soporte</button></div>`}
        ${supportDirect?'':'<div id="kx-fed-account-invitations"></div>'}
        <section class="kx-hub-section"><div class="kx-section-title"><div><span>PERFILES Y MEMBRESÍAS</span><h2>Mi identidad KOMBAX</h2></div><small>${workspaceCount} elemento${workspaceCount===1?'':'s'}</small></div>
          ${workspaceCount?`<div class="kx-profile-owned-grid">${memberPublicCard}${membershipCards}${(managedClubs||[]).map(c=>`<article class="kx-profile-owned kx-club-identity"><header><div class="direct-profile-icon">${featureIcon('club',{size:44})}</div><div><span>CLUB</span><strong>${esc(c.nombre_publico)}</strong><small>${esc([c.ciudad,c.provincia,c.pais].filter(Boolean).join(' · ')||'Perfil oficial de club')}</small></div><b class="kx-state ${c.activo?'ok':'warn'}">${c.activo?'Activo':'Inactivo'}</b></header><p>${esc(c.descripcion||c.lema||'Completa el perfil público de tu Club desde su entorno de gestión.')}</p><div class="kx-profile-tags">${(c.disciplinas||[]).slice(0,4).map(x=>`<span>${esc(x)}</span>`).join('')}<span>Club KOMBAX</span></div><footer><button class="btn btn-primary btn-sm" data-kx-club-enter="${esc(c.club_id)}">Gestionar club</button>${c.social_profile_id?`<button class="btn btn-ghost btn-sm" data-kx-club-public="${esc(c.club_id)}">Ver perfil público</button>`:''}<button class="btn btn-ghost btn-sm" data-kx-club-security="${esc(c.club_id)}">Seguridad y acceso</button><button class="btn btn-ghost btn-sm" data-kx-club-support="${esc(c.club_id)}">Privacidad y soporte</button></footer></article>`).join('')}${profiles.map(p=>`<article class="kx-profile-owned"><header><div class="direct-profile-icon">${featureIcon(directTypes.find(x=>x.id===p.tipo)?.icon||'identity',{size:44})}</div><div><span>${esc(TYPE_LABEL[p.tipo]||p.tipo)}</span><strong>${esc(p.nombre_publico)}</strong><small>${esc(p.ubicacion||'Sin ubicación pública')}</small></div><b class="kx-state ${esc(workflowTone(p.workflow_estado))}">${esc(WORKFLOW_LABEL[p.workflow_estado]||p.workflow_estado)}</b></header><p>${esc(p.descripcion||'Completa la presentación pública de este perfil.')}</p><div class="kx-profile-tags">${(p.disciplinas||[]).slice(0,4).map(x=>`<span>${esc(x)}</span>`).join('')}<span>${esc(p.verificacion_estado==='verificado'?(p.servicio_estado==='activa'||p.servicio_estado==='prueba'?'Insignia activa':'Verificado · pendiente de servicio'):'Sin insignia')}</span></div><footer><button class="btn btn-primary btn-sm" data-kx-profile-open-hub="${esc(p.id)}">Abrir ${esc(managedHubTitle(p.tipo))}</button>${p.social_profile_id?`<button class="btn btn-ghost btn-sm" data-kx-profile-public="${esc(p.id)}">Ver perfil público</button>`:''}<button class="btn btn-ghost btn-sm" data-kx-profile-edit="${esc(p.id)}">Editar</button>${supportDirect?'':`<button class="btn btn-ghost btn-sm" data-kx-profile-security="${esc(p.id)}">Seguridad y acceso</button>`}${supportDirect?'':`<button class="btn btn-ghost btn-sm" data-kx-profile-support="${esc(p.id)}">Privacidad y soporte</button>`}${p.tipo==='espectador'?`<button class="btn btn-ghost btn-sm" data-kx-profile-album="${esc(p.id)}">Foto y banner</button>`:['activa','prueba'].includes(p.servicio_estado)?`<button class="btn btn-ghost btn-sm" data-kx-profile-album="${esc(p.id)}">Álbum</button>`:''}${p.tipo!=='espectador'&&!applications.some(a=>a.perfil_directo_id===p.id&&['submitted','under_review','verified'].includes(a.estado))?`<button class="btn btn-primary btn-sm" data-kx-profile-verify="${esc(p.id)}">Solicitar verificación</button>`:''}</footer></article>`).join('')}</div>`:'<div class="premium-empty compact"><strong>Tu cuenta gratuita está lista</strong><p>Aún no has elegido un perfil ni tienes una membresía confirmada. Puedes explorar KOMBAX y completar tu recorrido cuando lo necesites.</p></div>'}
        </section>
        <section class="kx-hub-section"><div class="kx-section-title"><div><span>REVISIÓN</span><h2>Solicitudes</h2></div><small>${applications.length} solicitud${applications.length===1?'':'es'}</small></div>${applications.length?`<div class="kx-application-grid">${applications.map(a=>applicationCard(a,profileById.get(a.perfil_directo_id),onBack)).join('')}</div>`:'<div class="premium-empty compact"><strong>Sin solicitudes</strong><p>Las verificaciones enviadas aparecerán aquí con su estado.</p></div>'}</section>
        <div class="gateway-safety-note"><span class="gateway-safety-icon">${icon('shieldCheck',{size:22})}</span><div><strong>Verificación separada del autorregistro</strong><p>Crear una cuenta o un perfil nunca concede una insignia, un club ni permisos sensibles. La revisión es explícita y trazable.</p></div></div>
      </section>
    </main>`);
    document.getElementById('kx-hub-back')?.addEventListener('click',onBack);
    const openHome=()=>renderGlobalHome({onBack:()=>renderDirectProfileHub({onBack,pendingType}),pendingType});
    document.getElementById('kx-hub-home')?.addEventListener('click',openHome);
    document.getElementById('support-mode-exit')?.addEventListener('click',onBack);
    document.getElementById('kx-global-change-password')?.addEventListener('click',()=>openAuthenticatedPasswordChange({onComplete:()=>renderDirectProfiles({onBack})}));
    document.getElementById('kx-global-logout')?.addEventListener('click',async()=>{await backend.signOut();toast('Sesión cerrada');renderDirectProfiles({onBack});});
    document.getElementById('kx-new-profile')?.addEventListener('click',()=>chooseProfileType({onBack,memberProfiles,policy:activeAccountPolicy}));
    document.getElementById('kx-open-social')?.addEventListener('click',()=>openGlobalArea(renderKombaxSocial,{onBack,title:'KOMBAX Social'}));
    document.getElementById('kx-open-showcase')?.addEventListener('click',()=>openGlobalArea(renderShowcase,{onBack,title:'KOMBAX Showcase'}));
    document.getElementById('kx-open-events')?.addEventListener('click',()=>openGlobalArea(renderKombaxEvents,{onBack,title:'KOMBAX Events'}));
    document.getElementById('kx-spectator-social')?.addEventListener('click',()=>openGlobalArea(renderKombaxSocial,{onBack,title:'KOMBAX Social'}));
    document.getElementById('kx-spectator-showcase')?.addEventListener('click',()=>openGlobalArea(renderShowcase,{onBack,title:'KOMBAX Showcase'}));
    document.getElementById('kx-spectator-events')?.addEventListener('click',()=>openGlobalArea(renderKombaxEvents,{onBack,title:'KOMBAX Events'}));
    document.getElementById('kx-spectator-create-profile')?.addEventListener('click',()=>chooseProfileType({onBack,memberProfiles,policy:activeAccountPolicy}));
    document.getElementById('kx-spectator-profile-info')?.addEventListener('click',()=>chooseProfileType({onBack,memberProfiles,policy:activeAccountPolicy}));
    document.getElementById('kx-spectator-plans')?.addEventListener('click',()=>renderCommercialDiscovery({onBack:()=>renderDirectProfileHub({onBack}),onSelectPlan:selection=>startCommercialOnboarding(selection,{onBack:()=>renderDirectProfileHub({onBack})})}));
    document.getElementById('kx-open-plans')?.addEventListener('click',()=>renderCommercialDiscovery({onBack:()=>renderDirectProfileHub({onBack}),onSelectPlan:selection=>startCommercialOnboarding(selection,{onBack:()=>renderDirectProfileHub({onBack})})}));
    document.getElementById('kx-open-resources')?.addEventListener('click',()=>renderResourceCenter({standalone:true,onBack:()=>renderDirectProfileHub({onBack})}));
    document.getElementById('kx-account-privacy')?.addEventListener('click',openGlobalDeletionCenter);
    document.getElementById('kx-account-support')?.addEventListener('click',()=>openSupportPrivacyCenter({subjectType:'account',subjectId:state.session?.id,title:'Privacidad y soporte de mi cuenta',canAuthorize:true}));
    if(!supportDirect)renderPendingFederationInvitations({container:'#kx-fed-account-invitations',onChanged:()=>renderDirectProfileHub({onBack})});
    document.querySelectorAll('[data-kx-profile-open-hub]').forEach(b=>{const p=profileById.get(b.dataset.kxProfileOpenHub);b.addEventListener('click',()=>renderManagedProfileHub(p.id,{onBack:()=>renderDirectProfileHub({onBack}),onSocial:()=>openGlobalArea(renderKombaxSocial,{onBack,title:'KOMBAX Social'}),onShowcase:(view)=>openGlobalArea(view==='manage'?renderMyShowcase:renderShowcase,{onBack,title:view==='manage'?'Mi Showcase':'KOMBAX Showcase'}),onEvents:()=>openGlobalArea(renderKombaxEvents,{onBack,title:'KOMBAX Events'}),onProfessionalOps:(profileId)=>renderProfessionalOperations(profileId,{onBack:()=>renderManagedProfileHub(profileId,{onBack:()=>renderDirectProfileHub({onBack}),onSocial:()=>openGlobalArea(renderKombaxSocial,{onBack,title:'KOMBAX Social'}),onShowcase:(view)=>openGlobalArea(view==='manage'?renderMyShowcase:renderShowcase,{onBack,title:view==='manage'?'Mi Showcase':'KOMBAX Showcase'}),onEvents:()=>openGlobalArea(renderKombaxEvents,{onBack,title:'KOMBAX Events'}),onProfessionalOps:(id)=>renderProfessionalOperations(id,{onBack:()=>renderDirectProfileHub({onBack}),onEvents:()=>openGlobalArea(renderKombaxEvents,{onBack,title:'KOMBAX Events'})})}),onEvents:()=>openGlobalArea(renderKombaxEvents,{onBack,title:'KOMBAX Events'})})}));});
    document.querySelectorAll('[data-kx-profile-public]').forEach(b=>{const p=profileById.get(b.dataset.kxProfilePublic);b.addEventListener('click',()=>{if(p?.social_profile_id)openKombaxPublicProfile(p.social_profile_id);});});
    document.querySelectorAll('[data-kx-profile-edit]').forEach(b=>{const p=profileById.get(b.dataset.kxProfileEdit);b.addEventListener('click',()=>profileEditor(p.tipo,{profile:p,onBack,memberProfiles}));});
    document.querySelectorAll('[data-kx-profile-security]').forEach(b=>b.addEventListener('click',()=>openAuthenticatedPasswordChange({onComplete:()=>renderDirectProfiles({onBack})})));
    document.querySelectorAll('[data-kx-profile-support]').forEach(b=>b.addEventListener('click',()=>openSupportPrivacyCenter({subjectType:'direct_profile',subjectId:b.dataset.kxProfileSupport,title:'Privacidad y soporte del perfil',canAuthorize:true})));
    document.querySelectorAll('[data-kx-club-enter]').forEach(b=>b.addEventListener('click',async()=>{const c=clubById.get(b.dataset.kxClubEnter);if(!c)return;try{await backend.switchClub(c.slug);toast(`Entrando en ${c.nombre_publico}`);window.location.reload();}catch(error){setError(error);}}));
    document.querySelectorAll('[data-kx-club-public]').forEach(b=>b.addEventListener('click',()=>{const c=clubById.get(b.dataset.kxClubPublic);if(c?.social_profile_id)openKombaxPublicProfile(c.social_profile_id);}));
    document.querySelectorAll('[data-kx-club-security]').forEach(b=>b.addEventListener('click',()=>openAuthenticatedPasswordChange({onComplete:()=>renderDirectProfiles({onBack})})));
    document.querySelectorAll('[data-kx-club-support]').forEach(b=>b.addEventListener('click',()=>openSupportPrivacyCenter({subjectType:'club',subjectId:b.dataset.kxClubSupport,title:'Privacidad y soporte del club',canAuthorize:true})));
    document.querySelectorAll('[data-kx-membership-enter]').forEach(b=>b.addEventListener('click',async()=>{try{await backend.switchClub(b.dataset.kxMembershipEnter);window.location.reload();}catch(error){setError(error);}}));
    document.querySelectorAll('[data-kx-membership-social]').forEach(b=>b.addEventListener('click',()=>openGlobalArea(renderKombaxSocial,{onBack,title:'KOMBAX Social'})));
    document.querySelectorAll('[data-kx-member-public-open]').forEach(b=>b.addEventListener('click',()=>openKombaxPublicProfile(b.dataset.kxMemberPublicOpen)));
    document.querySelectorAll('[data-kx-member-public-link]').forEach(b=>b.addEventListener('click',()=>renderClubDirectory({onBack:()=>renderDirectProfileHub({onBack}),mode:'member'})));
    document.querySelectorAll('[data-kx-profile-verify]').forEach(b=>{const p=profileById.get(b.dataset.kxProfileVerify);b.addEventListener('click',()=>{if(!p||p.tipo==='espectador')return;saveAndSubmitApplication(p.tipo,{profile:p,onBack});});});
    document.querySelectorAll('[data-kx-profile-album]').forEach(b=>{const p=profileById.get(b.dataset.kxProfileAlbum);b.addEventListener('click',()=>openAlbum(p,{onBack}).catch(setError));});
    document.querySelectorAll('[data-kx-application-edit]').forEach(b=>{const a=applications.find(x=>x.id===b.dataset.kxApplicationEdit),p=profileById.get(a?.perfil_directo_id);b.addEventListener('click',()=>saveAndSubmitApplication(a.tipo,{profile:p,application:a,onBack}));});
    document.querySelectorAll('[data-kx-application-withdraw]').forEach(b=>b.addEventListener('click',()=>confirmDialog('Retirar solicitud','La solicitud dejará de revisarse. El historial no se falsifica ni se elimina.',async()=>{await repos.kombaxProfiles.withdrawApplication(b.dataset.kxApplicationWithdraw);toast('Solicitud retirada');await renderDirectProfileHub({onBack});},{confirmText:'Eliminar',danger:true})));
    const newlyCreatedId=sessionStorage.getItem('kombax_new_profile_id');
    const newlyCreated=newlyCreatedId?profileById.get(newlyCreatedId):null;
    if(newlyCreated&&commercialAudienceForType(newlyCreated.tipo)&&selectedCommercialPlan(newlyCreated.tipo).plan_code){
      sessionStorage.removeItem('kombax_new_profile_id');
      setTimeout(()=>saveAndSubmitApplication(newlyCreated.tipo,{profile:newlyCreated,onBack}),420);
    }else if(sessionStorage.getItem('kombax_pending_pilot_club')==='1'){
      setTimeout(()=>openPilotClubActivation({onBack}),260);
    }else if(pendingType==='miembro_familia'){
      setTimeout(()=>openMemberPublicProfileSetup({onBack}),220);
    }else if(pendingType&&directTypes.some(t=>t.id===pendingType&&!t.disabled&&!t.baseOnly)&&['competidor','marca','federacion','profesional','media','espectador'].includes(pendingType)){
      profileEditor(pendingType,{onBack,memberProfiles});
    }else if(pendingType==='club'&&!applications.some(a=>a.tipo==='club'&&['submitted','under_review','needs_information'].includes(a.estado))){
      saveAndSubmitApplication('club',{onBack});
    }
    sessionStorage.removeItem('kombax_pending_profile_type');
  }catch(error){setError(error);renderDirectProfiles({onBack});}
}

function chooseCommercialPlan(type,{onBack,application=null,profile=null,memberProfiles=[],returnView=null}={}){
  const audience=commercialAudienceForType(type);
  if(!audience){profileEditor(type,{profile,onBack,memberProfiles});return;}
  closeModal();
  renderPlanServices({audience,onBack:returnView||onBack,onSelectPlan:selection=>{
    rememberCommercialSelection(type,selection.plan_code,selection.billing_cycle);
    if(!globalAuthenticated()){sessionStorage.setItem('kombax_pending_profile_type',type);authChoice({onBack,pendingType:type});return;}
    if(type==='club'||profile){saveAndSubmitApplication(type,{profile,application,onBack});return;}
    profileEditor(type,{onBack,memberProfiles});
  }});
}
function chooseClubPlan(options={}){chooseCommercialPlan('club',options);}
function startCommercialOnboarding(selection,{onBack}={}){
  const type=({club:'club',brand:'marca',federation:'federacion'})[selection?.audience];
  if(!type)return;
  rememberCommercialSelection(type,selection.plan_code,selection.billing_cycle);
  if(!globalAuthenticated()){sessionStorage.setItem('kombax_pending_profile_type',type);authChoice({onBack,pendingType:type});return;}
  if(type==='club')saveAndSubmitApplication('club',{onBack});else profileEditor(type,{onBack});
}

function chooseProfileType({onBack,memberProfiles=[],policy=activeAccountPolicy}={}){
  const isNew=!policy||policy.kind==='new';
  const available=isNew?onboardingProfileTypes():directTypes.filter(x=>!x.disabled&&!x.baseOnly&&canRequestAccountProfile(x.id,policy));
  if(!available.length){toast('Esta cuenta ya tiene asignado su tipo de perfil.','warning');return;}
  const subtitle=policy?.kind==='miembro'?'Tu membresía ya está confirmada. Puedes solicitar Competidor sin crear otra cuenta.':'Elige cómo quieres usar KOMBAX. La cuenta es gratuita; Espectador y Miembro/Familiar son recorridos de acceso, y las identidades oficiales mantienen sus verificaciones.';
  const {wrap}=openDetail({title:policy?.kind==='miembro'?'Evolucionar mi perfil':'Elige tu perfil KOMBAX',subtitle,width:'880px',body:`<div class="kx-type-picker">${available.map(t=>`<button type="button" data-kx-pick="${esc(t.id)}"><span>${featureIcon(t.icon,{size:42})}</span><strong>${esc(t.label)}</strong><small>${esc(t.description)}</small>${t.id==='miembro_familia'?'<i class="kx-type-price">Vinculación y aprobación del club</i>':t.id==='espectador'?'<i class="kx-type-price">Explorar sin identidad especializada</i>':commercialAudienceForType(t.id)?'<i class="kx-type-price">Perfil público gratuito · planes opcionales</i>':'<i class="kx-type-price">Solicitud y verificación cuando corresponda</i>'}<em>${(t.benefits||[]).map(x=>`✓ ${esc(x)}`).join(' · ')}</em></button>`).join('')}</div>`});
  wrap.querySelectorAll('[data-kx-pick]').forEach(b=>b.addEventListener('click',()=>{const type=b.dataset.kxPick;closeModal();if(type==='miembro_familia'){renderMemberFamilyPresentation({onBack:()=>renderDirectProfileHub({onBack})});return;}renderIdentityPresentation(type,{onBack:()=>renderDirectProfileHub({onBack}),memberProfiles});}));
}

export function renderDirectProfiles({onBack}){
  if(globalAuthenticated()){renderGlobalHome({onBack});return;}
  const onboardingTypes=onboardingProfileTypes();
  setAppHtml(`<main class="kombax-gateway direct-mode gateway-premium" data-kombax-view="profiles">
    <div class="gateway-ambient" aria-hidden="true"><i></i><i></i><i></i></div>
    <section class="gateway-directory premium-surface">
      <div class="gateway-directory-top"><button class="gateway-icon-button" id="direct-back" type="button" aria-label="${t('marketing.gateway.actions.back')}">${icon('chevronLeft',{size:22})}</button>${mark({compact:true})}<span class="gateway-directory-step">CUENTA GRATUITA KOMBAX</span></div>
      <header><span class="gateway-eyebrow">IDENTIDAD KOMBAX</span><h1>¿Cómo quieres usar KOMBAX?</h1><p>Crea una única cuenta KOMBAX gratuita y elige tu recorrido. Crear la cuenta no te convierte automáticamente en Espectador ni concede una identidad oficial. Podrás explorar Social, Showcase y Events mientras completas el perfil que corresponda.</p><button class="btn btn-ghost btn-sm" id="kx-direct-pricing" type="button">Ver todos los planes y precios</button></header>
      <div class="direct-profile-grid">${onboardingTypes.map(t=>`<button class="direct-profile-card ${t.disabled?'is-disabled':''}" type="button" style="--profile-accent:${t.accent}" data-profile-type="${esc(t.id)}" ${t.disabled?'disabled':''}><div class="direct-profile-icon">${featureIcon(t.icon,{size:58})}</div><div class="direct-profile-copy"><span>${esc(t.id==='espectador'?'EXPLORAR GRATIS':t.id==='miembro_familia'?'VINCULACIÓN CON CLUB':t.applicationOnly?'SOLICITUD + VERIFICACIÓN':'PERFIL + VERIFICACIÓN')}</span><h2>${esc(t.label)}</h2><p>${esc(t.description)}</p></div><footer><b>${t.disabled?`${icon('lock',{size:13})} PENDIENTE`:`${icon('arrowUpRight',{size:13})} CONOCER RECORRIDO`}</b><span>${icon('chevronRight',{size:18})}</span></footer></button>`).join('')}</div>
      <div class="gateway-safety-note"><span class="gateway-safety-icon">${icon('shieldCheck',{size:22})}</span><div><strong>Una cuenta, una identidad principal</strong><p>Miembro/Practicante solo puede publicar en Social cuando un club confirma su membresía. Competidor puede solicitarse directamente o evolucionar desde Miembro y requiere su verificación. Club, Federación y Marca mantienen sus procesos de acreditación.</p></div></div>
      <div class="kx-direct-auth-row"><button class="btn btn-primary" id="kx-free-account">Crear cuenta gratuita</button><button class="btn btn-ghost" id="kx-existing-account">Ya tengo cuenta KOMBAX</button></div>
    </section>
  </main>`);
  document.getElementById('direct-back')?.addEventListener('click',onBack);
  document.querySelectorAll('[data-profile-type]:not(:disabled)').forEach(card=>card.addEventListener('click',()=>{const type=card.dataset.profileType;if(type==='miembro_familia'){renderMemberFamilyPresentation({onBack:()=>renderDirectProfiles({onBack})});return;}renderIdentityPresentation(type,{onBack:()=>renderDirectProfiles({onBack})});}));
  document.getElementById('kx-direct-pricing')?.addEventListener('click',()=>renderCommercialDiscovery({onBack:()=>renderDirectProfiles({onBack}),onSelectPlan:selection=>startCommercialOnboarding(selection,{onBack})}));
  document.getElementById('kx-free-account')?.addEventListener('click',()=>authChoice({onBack:()=>renderDirectProfiles({onBack})}));
  document.getElementById('kx-existing-account')?.addEventListener('click',()=>openGlobalAuth({onBack,mode:'login'}));
}
