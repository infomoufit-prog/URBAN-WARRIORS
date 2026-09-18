import { getLocale as kxGetLocale, t } from '../i18n/index.js';
import { localeTag as kxLocaleTag } from '../i18n/formatters.js';
import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { esc, humanError } from '../core/utils.js';
import { pageHeader, setMainHtml, setAppHtml, toast, subviewActions, bindSubviewActions } from '../ui/components.js';
import { FALLBACK_COMMERCIAL_CATALOG, COMMERCIAL_PDF } from '../core/commercial-pricing.js';

const eurMinor=v=>`${(Number(v||0)/100).toLocaleString(kxLocaleTag(kxGetLocale()),{minimumFractionDigits:0,maximumFractionDigits:2})} €`;
const titleLevel=v=>({base:'Base',plus:'Plus',pro:'Pro'}[String(v||'').toLowerCase()]||String(v||'—'));
const modeLabel=v=>v==='included'?'✓ Incluido':v==='temporary'?'Puntual':'✕ No incluido';
const modelLabel=v=>v===null||v===undefined?'Ilimitado':Number(v)>0?`${v} productos incluidos`:'✕';
const eventsLabel=v=>v===null||v===undefined?'Ilimitados':Number(v)>0?`${v}/mes`:'Puntual';
export const commercialAudienceName=a=>({club:'Club',brand:'Marca',federation:'Federación'}[a]||a);
const audienceCopy=a=>({
  club:{title:'Clubes',body:'Gestión del club, Showcase, Commerce, Events, Ticketing y herramientas operativas.',badge:'CLUB'},
  brand:{title:'Marcas',body:'Escaparate comercial, venta directa, catálogo, promoción y Events según plan.',badge:'MARCA'},
  federation:{title:'Federaciones',body:'Gestión de red, Events, Ticketing puntual y programa KOMBAX Partner.',badge:'FEDERACIÓN'}
}[a]||{title:a,body:'',badge:String(a||'').toUpperCase()});

function planRows(plan,audience){
  const rows=[];
  if(audience==='club')rows.push(['Gestión Mi Club','✓']);
  rows.push(['Social'+(audience==='club'?' + membresías':''),'✓']);
  rows.push(['Showcase',modelLabel(plan.showcase_model_limit)]);
  if(Number(plan.showcase_model_limit||0)>0)rows.push(['Ampliar catálogo','+25 · 8 €/30 días']);
  rows.push(['Commerce',plan.plan_code==='club'&&plan.commerce_mode==='temporary'?'12 €/mes':modeLabel(plan.commerce_mode)]);
  rows.push(['Events',eventsLabel(plan.events_monthly_limit)]);
  rows.push(['Ticketing',modeLabel(plan.ticketing_mode)]);
  rows.push(['Stripe Connect',t('payments.planAccordingToServices')]);
  rows.push(['Tarjeta','Commerce · Ticketing · cobros inmediatos']);
  if(audience==='club'||audience==='federation')rows.push(['SEPA',t('payments.planSepaRecurring')]);
  rows.push(['Destacar','Extra']);
  rows.push(['Assist',titleLevel(plan.assist_level)]);
  rows.push(['Migrations',titleLevel(plan.migrations_level)]);
  rows.push(['Platform fee',`${Number(plan.platform_fee_percent||0).toLocaleString(kxLocaleTag(kxGetLocale()))} %`]);
  return rows;
}
function planCard(plan,audience,current,billing='monthly',founderOpen=true,{selectMode=false}={}){
  const active=String(current?.plan_code||'')===String(plan.plan_code);
  const founderEligible=Boolean(current?.founder_locked)||founderOpen;
  const standard=billing==='annual'?`${eurMinor(plan.standard_annual_minor)}/año`:`${eurMinor(plan.standard_monthly_minor)}/mes`;
  // Founder is monthly only. Annual always uses the published standard annual price and never stacks Founder.
  const useFounder=billing==='monthly'&&founderEligible;
  const primary=useFounder?eurMinor(plan.founder_monthly_minor):(billing==='annual'?eurMinor(plan.standard_annual_minor):eurMinor(plan.standard_monthly_minor));
  const primarySuffix=useFounder?'/mes Founder':billing==='annual'?'/año':'/mes';
  const secondaryLabel=billing==='annual'?'Mensual estándar':useFounder?'Estándar':'Tarifa vigente';
  const secondary=billing==='annual'?`${eurMinor(plan.standard_monthly_minor)}/mes`:`${eurMinor(plan.standard_monthly_minor)}/mes`;
  const actionLabel=selectMode?`Elegir ${plan.name}`:`Solicitar ${billing==='annual'?'anual':'plan'}`;
  return `<article class="kx-price-card ${active?'current':''}" data-plan-card="${esc(plan.plan_code)}">
    <div class="kx-price-card-head"><div><small>${active?'PLAN ACTUAL':esc(commercialAudienceName(audience).toUpperCase())}</small><h3>${esc(plan.name)}</h3><p>${esc(plan.tagline)}</p></div>${active?'<span class="kx-price-current">Activo</span>':''}</div>
    <div class="kx-price-main"><strong>${primary}</strong><span>${primarySuffix}</span></div>
    <div class="kx-price-standard"><span>${secondaryLabel}</span><b>${secondary}</b>${billing==='annual'?'<small>−16 % sobre tarifa estándar mensual · no acumulable con Founder</small>':''}</div>
    <div class="kx-price-features">${planRows(plan,audience).map(([k,v])=>`<div><span>${esc(k)}</span><b class="${String(v).startsWith('✕')?'off':''}">${esc(v)}</b></div>`).join('')}</div>
    ${active?'':`<button class="btn btn-primary kx-plan-request" data-plan="${esc(plan.plan_code)}">${esc(actionLabel)}</button>`}
  </article>`;
}
function activationGrid(catalog,audience,{canRequest=false,context=null}={}){
  const c=catalog.config||{},commerce=c.commerce_temporary||{},catalogPlus=c.showcase_catalog_plus_25||{slots:25,days:30,price_minor:800},pub=c.event_publication||{},promo=c.content_promotion||{},ticketTiers=c.ticketing_activation_tiers||{};
  const clubCommerceAllowed=canRequest&&String(context?.plan_code||'')==='club';
  const commercePrice=commerce?.[30]?.price_minor||1200;
  const catalogPlan=String(context?.plan_code||'');
  const catalogPlusAllowed=canRequest&&['club','premium','club_pro','brand_start','brand_growth','marca_profesional'].includes(catalogPlan);
  const pubCards=[7,15,30,60].map(d=>pub[d]?`<span>${d} días · <b>${eurMinor(pub[d])}</b></span>`:'').join('');
  const promoCards=[7,15,30].map(d=>promo[d]?`<span>${d} días · <b>${eurMinor(promo[d])}</b></span>`:'').join('');
  const ticketCards=[50,100,200,500,1000].map(limit=>ticketTiers[limit]?`<span>Hasta ${Number(limit).toLocaleString(kxLocaleTag(kxGetLocale()))} · <b>${eurMinor(ticketTiers[limit])}</b></span>`:'').join('');
  return `<section class="kx-commercial-section"><div class="kx-commercial-section-title"><small>SERVICIOS PUNTUALES</small><h2>Activa solo lo que necesites</h2></div>
    <div class="kx-activation-grid">
      ${(audience==='club'||audience==='brand')?`<article><h3>Ampliación Showcase +25</h3><p>Los límites del plan son capacidad incluida, no un límite destructivo. Añade 25 productos activos durante 30 días y conserva referencias, reseñas e historial.</p><div class="kx-activation-options"><span><b>+${Number(catalogPlus.slots||25)} productos</b> · ${eurMinor(catalogPlus.price_minor||800)} / ${Number(catalogPlus.days||30)} días</span><span>Renovable · acumulable · no activa Commerce</span></div>${catalogPlusAllowed?`<button class="btn btn-primary" data-activation="SHOWCASE_CATALOG_PLUS_25" data-days="30">Solicitar +25 · ${eurMinor(catalogPlus.price_minor||800)}</button>`:`<small>${catalogPlan&&['enterprise','brand_enterprise'].includes(catalogPlan)?'Tu plan ya incluye catálogo ilimitado.':'Selecciona un plan compatible para contratar ampliaciones.'}</small>`}</article>`:''}
      ${audience==='club'?`<article><h3>Showcase Commerce</h3><p>Club básico: mantienes hasta 15 productos de escaparate y activas la venta directa cuando la necesitas. Premium y Enterprise ya incluyen Commerce.</p><div class="kx-activation-options"><button type="button" class="kx-activation-option" ${clubCommerceAllowed?'data-activation="SHOWCASE_COMMERCE" data-days="30"':'disabled'}><span>1 mes</span><b>${eurMinor(commercePrice)}</b><small>${clubCommerceAllowed?'Solicitar activación':canRequest?'Incluido en Premium/Enterprise o requiere Club básico':'Selecciona una organización'}</small></button></div><small>Renovable mes a mes. No aplica descuento Founder ni anual al add-on.</small></article>`:''}
      <article><h3>Publicar evento</h3><p>Publicar no es lo mismo que promocionar ni vender entradas.</p><div>${pubCards}</div><small>Se activa desde el evento concreto para que la autorización quede ligada a ese evento.</small></article>
      <article><h3>Destacar</h3><p>Prioridad en Events/Showcase + amplificación automática en KOMBAX Social.</p><div>${promoCards}</div><small>Se contrata desde el evento o producto concreto. Frequency caps protegen el feed Social.</small></article>
      <article><h3>Ticketing</h3><p>Activación puntual según capacidad del evento.</p><div>${ticketCards}</div><small>Incluye checkout, ticket digital, QR, lector y control de acceso. Más de ${Number(c.large_event_threshold||1000).toLocaleString(kxLocaleTag(kxGetLocale()))} entradas: Gran Evento con condiciones específicas.</small></article>
    </div>
  </section>`;
}
function partnerSection(catalog){const p=catalog.config?.partner_program||{};return `<section class="kx-commercial-section kx-partner-panel"><div><small>KOMBAX PARTNER</small><h2>Haz crecer tu red</h2><p>Comisión sobre la base imponible de la suscripción del club referido, sin IVA ni extras.</p></div><div class="kx-partner-stats"><span><b>${p['1_9_percent']||25}%</b> · 1–9 clubes</span><span><b>${p['10_plus_percent']||30}%</b> · 10+ clubes</span><span><b>100%</b> bonificación Federation con ${p.federation_free_active_referrals||5} clubes activos</span></div><p class="kx-commercial-warning">Suscripciones mensuales: cuotas 2–13. Para altas anuales la atribución se registra, pero la liquidación permanece pendiente de regla comercial específica.</p></section>`;}

export function commercialPlanSummary(audience){
  const plans=FALLBACK_COMMERCIAL_CATALOG.plans.filter(p=>p.audience===audience);
  const min=Math.min(...plans.map(p=>Number(p.founder_monthly_minor||p.standard_monthly_minor||0)).filter(Boolean));
  return {audience,plans,from_minor:min||0,copy:audienceCopy(audience)};
}

export function renderCommercialDiscovery({onBack=null,onSelectPlan=null}={}){
  const audiences=['club','brand','federation'].map(commercialPlanSummary);
  const html=`<div class="kx-commercial-page kx-commercial-discovery">
    ${pageHeader('Planes y precios','Consulta las tarifas antes de crear una organización o vuelve aquí desde cualquier cuenta KOMBAX.',onBack?subviewActions({backId:'kx-commercial-discovery-back',closeId:'kx-commercial-discovery-close'}):'','KOMBAX')}
    <section class="kx-commercial-hero kx-commercial-discovery-hero"><div><span class="page-kicker">KOMBAX · CUENTA GRATIS + PLANES POR ORGANIZACIÓN</span><h1>Primero tu cuenta. Después eliges qué quieres hacer.</h1><p>Crear una cuenta KOMBAX y continuar como Espectador es gratuito. Los planes se asocian al Club, Marca o Federación que quieras gestionar; nunca al simple registro de tu email.</p></div><a class="btn btn-ghost" href="${COMMERCIAL_PDF}" target="_blank" rel="noopener">Tabla completa de precios</a></section>
    <section class="kx-commercial-journey" aria-label="Cómo funciona"><article><b>1</b><strong>Cuenta KOMBAX</strong><span>Registro y Espectador gratis.</span></article><article><b>2</b><strong>Identidad</strong><span>Club, Marca o Federación.</span></article><article><b>3</b><strong>Plan</strong><span>Conoces precio y capacidades antes del alta.</span></article><article><b>4</b><strong>Verificación</strong><span>La identidad y los permisos se revisan antes de activarse.</span></article></section>
    <section class="kx-audience-grid">${audiences.map(x=>`<article class="kx-audience-card"><span>${esc(x.copy.badge)}</span><h2>${esc(x.copy.title)}</h2><p>${esc(x.copy.body)}</p><div><small>Desde</small><strong>${eurMinor(x.from_minor)}<em>/mes Founder</em></strong></div><button type="button" class="btn btn-primary" data-kx-commercial-audience="${esc(x.audience)}">Ver planes ${esc(commercialAudienceName(x.audience))}</button></article>`).join('')}</section>
    <section class="kx-commercial-section kx-commercial-account-note"><div><small>CUENTA KOMBAX</small><h2>No tienes que pagar para registrarte</h2><p>Una cuenta sin Club ni perfil comercial funciona como Espectador. Puedes explorar Social, Showcase y Events según sus reglas; cuando quieras gestionar una organización, KOMBAX te mostrará el plan correspondiente antes de solicitarla.</p></div></section>
  </div>`;
  setAppHtml(`<main id="main-view" class="main-view kx-commercial-standalone">${html}</main>`);
  if(onBack)bindSubviewActions(document,{backId:'kx-commercial-discovery-back',closeId:'kx-commercial-discovery-close',onBack,onClose:onBack});
  document.querySelectorAll('[data-kx-commercial-audience]').forEach(button=>button.addEventListener('click',()=>{
    const audience=button.dataset.kxCommercialAudience;
    renderPlanServices({audience,onBack:()=>renderCommercialDiscovery({onBack,onSelectPlan}),onSelectPlan});
  }));
}

export async function renderPlanServices({audience='club',subjectType=null,subjectId=null,onBack=null,onSelectPlan=null}={}){
  const resolvedSubjectType=subjectType||(audience==='club'?'club':'direct_profile');
  const resolvedSubjectId=subjectId||(audience==='club'?state.session?.club_id:null);
  let catalog,context=null,remote=true;
  try{catalog=await repos.commercial.catalog(audience);if(!catalog?.plans?.length)throw new Error('EMPTY_CATALOG');}catch{remote=false;catalog={...FALLBACK_COMMERCIAL_CATALOG,plans:FALLBACK_COMMERCIAL_CATALOG.plans.filter(p=>p.audience===audience)};}
  if(resolvedSubjectId&&remote){try{context=await repos.commercial.context(resolvedSubjectType,resolvedSubjectId);}catch{/* catalog stays readable */}}
  let billing='monthly';
  const render=()=>{
    const plans=(catalog.plans||[]).filter(p=>p.audience===audience);
    const selectMode=!resolvedSubjectId&&typeof onSelectPlan==='function';
    const html=`<div class="kx-commercial-page">
      ${pageHeader('Plan y servicios',selectMode?`Conoce el precio y elige el plan de ${commercialAudienceName(audience)} antes de iniciar el alta.`:`Consulta qué incluye cada plan de ${commercialAudienceName(audience)} y solicita cambios sin perder la arquitectura actual.`,onBack?subviewActions({backId:'kx-commercial-back',closeId:'kx-commercial-close'}):'','KOMBAX')}
      <section class="kx-commercial-hero"><div><span class="page-kicker">KOMBAX · PLANES Y SERVICIOS</span><h1>${selectMode?'Conoce el plan antes de crear la organización':'Elige capacidades, no complejidad'}</h1><p>La cuenta KOMBAX y el estado Espectador son gratuitos. Los precios mostrados son finales con IVA incluido cuando corresponde.</p></div><a class="btn btn-ghost" href="${COMMERCIAL_PDF}" target="_blank" rel="noopener">Ver tabla completa de precios</a></section>
      ${(catalog.config?.founder_sales_open!==false||context?.founder_locked)?'<section class="kx-founder-note"><strong>Precio Founder</strong><span>Si contratas mientras está vigente, lo conservas mientras sigas siendo cliente sin interrupción. Se pierde al causar baja y volver.</span><small>Founder es mensual y no se acumula con el descuento anual.</small></section>':'<section class="kx-founder-note"><strong>Tarifa estándar</strong><span>La ventana de nuevas altas Founder está cerrada. Los clientes que ya la conservan mantienen su condición.</span></section>'}
      <div class="kx-billing-toggle" role="group"><button class="${billing==='monthly'?'active':''}" data-billing="monthly">Mensual${catalog.config?.founder_sales_open!==false?' · Founder disponible':''}</button><button class="${billing==='annual'?'active':''}" data-billing="annual">Anual estándar · −16 %</button></div>
      ${context?.plan_code?`<div class="kx-current-plan"><span>Plan actual</span><strong>${esc(context.plan_code)}</strong><small>Fee: ${Number(context.platform_fee_percent||0).toLocaleString(kxLocaleTag(kxGetLocale()))} % · ${context.founder_locked?'Founder protegido':'Tarifa según contrato vigente'}</small></div>`:''}
      ${selectMode?'<div class="kx-commercial-selection-note"><strong>Elegir no realiza ningún cobro.</strong><span>Guardaremos tu selección para el formulario de alta y la revisión KOMBAX. El Billing automático sigue fuera de esta fase.</span></div>':''}
      <section class="kx-price-grid">${plans.map(p=>planCard(p,audience,context,billing,catalog.config?.founder_sales_open!==false,{selectMode})).join('')}</section>
      ${activationGrid(catalog,audience,{canRequest:Boolean(resolvedSubjectId&&remote),context})}
      ${audience==='federation'?partnerSection(catalog):''}
      <section class="kx-commercial-section kx-payments-subscription-note"><div class="kx-commercial-section-title"><small>${esc(t('payments.planIntegratedKicker'))}</small><h2>${esc(t('payments.planTitle'))}</h2></div><div class="kx-activation-grid"><article><h3>${esc(t('payments.planIdentityTitle'))}</h3><p>${esc(t('payments.planIdentityBody'))}</p></article><article><h3>${esc(t('payments.cardTitle'))}</h3><p>${esc(t('payments.planCardBody'))}</p></article><article><h3>${esc(t('payments.sepaTitle'))}</h3><p>${esc(t('payments.planSepaBody'))}</p></article><article><h3>${esc(t('payments.planGuideTitle'))}</h3><p>${esc(t('payments.planGuideBody'))}</p><a class="btn btn-ghost" href="./assets/docs/GUIA_KOMBAX_COBROS_STRIPE_SEPA_R80.pdf" target="_blank" rel="noopener">${esc(t('payments.planOpenGuide'))}</a></article></div></section>
      <section class="kx-commercial-section kx-economic-rules"><h2>Reglas claras</h2><ul><li><b>Cuenta ≠ identidad ≠ plan.</b> Registrarte no activa una tarifa.</li><li><b>Publicar ≠ Destacar ≠ Ticketing.</b></li><li>Ticketing agrupa QR, lector y control de acceso: no se cobran como servicios separados.</li><li>Los límites Showcase son capacidad incluida. Puedes ampliar en bloques de +25 por 8 €/30 días; archivar libera un slot sin perder reputación ni historial.</li><li>Las variantes de talla, color, peso o formato no consumen productos adicionales.</li><li>Toda compra comercial personal exige 18 años.</li><li>Stripe Connect mantiene direct charges: el vendedor u organizador cobra en su cuenta conectada y KOMBAX percibe únicamente las tarifas aplicables.</li><li><b>Tarjeta y SEPA son métodos independientes.</b> Se activan desde Cobros y Stripe cuando el perfil dispone de un servicio comercial compatible.</li><li><b>Commerce y Ticketing inmediato usan tarjeta.</b> SEPA queda reservado a cuotas y cobros recurrentes o diferidos compatibles, porque su confirmación no es instantánea.</li></ul></section>
    </div>`;
    if(onBack)setAppHtml(`<main id="main-view" class="main-view kx-commercial-standalone">${html}</main>`);else setMainHtml(html);
    if(onBack)bindSubviewActions(document,{backId:'kx-commercial-back',closeId:'kx-commercial-close',onBack,onClose:onBack});
    document.querySelectorAll('[data-billing]').forEach(b=>b.addEventListener('click',()=>{billing=b.dataset.billing||'monthly';render();}));
    document.querySelectorAll('.kx-plan-request').forEach(b=>b.addEventListener('click',async()=>{
      if(!resolvedSubjectId&&typeof onSelectPlan==='function'){
        onSelectPlan({audience,plan_code:b.dataset.plan,billing_cycle:billing});
        return;
      }
      if(!resolvedSubjectId){toast('Primero debes crear o seleccionar la organización.','error');return;}
      b.disabled=true;try{await repos.commercial.requestPlan(resolvedSubjectType,resolvedSubjectId,b.dataset.plan,billing);toast('Solicitud registrada. No se ha realizado ningún cobro.');context=await repos.commercial.context(resolvedSubjectType,resolvedSubjectId).catch(()=>context);render();}catch(e){b.disabled=false;toast(humanError(e),'error');}
    }));
    document.querySelectorAll('[data-activation]').forEach(b=>b.addEventListener('click',async()=>{
      if(!resolvedSubjectId||!remote){toast('Primero debes crear o seleccionar una organización con acceso comercial.','error');return;}
      b.disabled=true;try{await repos.commercial.requestActivation(resolvedSubjectType,resolvedSubjectId,b.dataset.activation,{days:Number(b.dataset.days||0)||null});toast('Solicitud de activación registrada. No se ha realizado ningún cobro.');render();}catch(e){b.disabled=false;toast(humanError(e),'error');}
    }));
  };
  render();
}
