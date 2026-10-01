import { getLocale as kxGetLocale, t } from '../i18n/index.js';
import { localeTag as kxLocaleTag } from '../i18n/formatters.js';
import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { esc, humanError } from '../core/utils.js';
import { pageHeader, setMainHtml, setAppHtml, toast, subviewActions, bindSubviewActions, openDetail } from '../ui/components.js';
import { FALLBACK_COMMERCIAL_CATALOG, COMMERCIAL_PDF, PUBLIC_PRICING_LOCKED } from '../core/commercial-pricing.js';

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
const WORK_OFFERS_FALLBACK=[
  {product_code:'club_profile',audience:'club',name:'Perfil Club',kind:'identity',price_minor:0,price_published:true},
  {product_code:'club',audience:'club',name:'KOMBAX Club',kind:'subscription',legacy_plan_code:'club',price_minor:2390,price_published:true,requestable:false},
  {product_code:'premium',audience:'club',name:'KOMBAX Premium',kind:'subscription',legacy_plan_code:'premium',price_minor:3790,price_published:true,requestable:false},
  {product_code:'multiclub',audience:'club',name:'KOMBAX MultiClub',kind:'subscription',price_minor:2990,starting_price:true,price_published:true},
  {product_code:'enterprise',audience:'club',name:'KOMBAX Enterprise',kind:'subscription',legacy_plan_code:'enterprise',price_minor:null,price_published:false},
  {product_code:'brand_profile',audience:'brand',name:'Perfil Marca',kind:'identity',price_minor:0,price_published:true},
  {product_code:'brand_plan',audience:'brand',name:'Plan Marca',kind:'subscription',price_minor:null,price_published:false},
  {product_code:'federation_profile',audience:'federation',name:'Perfil Federación',kind:'identity',price_minor:0,price_published:true},
  {product_code:'federation_plan',audience:'federation',name:'Plan Federación',kind:'subscription',price_minor:null,price_published:false}
];

function planRows(plan,audience){
  const rows=[];
  if(audience==='club')rows.push(['Gestión Mi Club','✓']);
  rows.push(['Social'+(audience==='club'?' + membresías':''),'✓']);
  rows.push(['Showcase',modelLabel(plan.showcase_model_limit)]);
  if(Number(plan.showcase_model_limit||0)>0)rows.push(['Ampliar catálogo',PUBLIC_PRICING_LOCKED?'Disponible tras lanzamiento':'+25 · 8 €/30 días']);
  rows.push(['Commerce',plan.plan_code==='club'&&plan.commerce_mode==='temporary'?(PUBLIC_PRICING_LOCKED?'Disponible tras lanzamiento':'12 €/mes'):modeLabel(plan.commerce_mode)]);
  rows.push(['Events',eventsLabel(plan.events_monthly_limit)]);
  rows.push(['Ticketing',modeLabel(plan.ticketing_mode)]);
  rows.push(['Destacar','Extra']);
  rows.push(['Assist',titleLevel(plan.assist_level)]);
  rows.push(['Migrations',titleLevel(plan.migrations_level)]);
  rows.push(['Platform fee',PUBLIC_PRICING_LOCKED?'No disponible hasta lanzamiento':`${Number(plan.platform_fee_percent||0).toLocaleString(kxLocaleTag(kxGetLocale()))} %`]);
  return rows;
}
function planCard(plan,audience,current,offer,{selectMode=false}={}){
  const active=String(current?.plan_code||'')===String(plan.plan_code);
  const published=!PUBLIC_PRICING_LOCKED&&offer?.price_published===true&&Number.isInteger(offer?.price_minor);
  const requestable=published&&offer?.requestable===true;
  const primary=PUBLIC_PRICING_LOCKED?'No disponible hasta lanzamiento':published?eurMinor(offer.price_minor):'Precio por definir';
  const actionLabel=selectMode?`Elegir ${plan.name}`:'Solicitar plan';
  return `<article class="kx-price-card ${active?'current':''}" data-plan-card="${esc(plan.plan_code)}">
    <div class="kx-price-card-head"><div><small>${active?'PLAN ACTUAL':esc(commercialAudienceName(audience).toUpperCase())}</small><h3>${esc(plan.name)}</h3><p>${esc(plan.tagline)}</p></div>${active?'<span class="kx-price-current">Activo</span>':''}</div>
    <div class="kx-price-main"><strong>${primary}</strong><span>${published?'/mes + IVA':''}</span></div>
    <div class="kx-price-standard"><span>${PUBLIC_PRICING_LOCKED?'Piloto KOMBAX · condiciones comerciales ocultas':published?'Tarifa pública mensual · España':'Condiciones comerciales pendientes'}</span><b>${PUBLIC_PRICING_LOCKED?'Lanzamiento':published?'Sin IVA':'Consulta disponibilidad'}</b></div>
    <div class="kx-price-features">${planRows(plan,audience).map(([k,v])=>`<div><span>${esc(k)}</span><b class="${String(v).startsWith('✕')?'off':''}">${esc(v)}</b></div>`).join('')}</div>
    ${active?'':PUBLIC_PRICING_LOCKED?'<small>No disponible hasta lanzamiento.</small>':requestable?`<button class="btn btn-primary kx-plan-request" data-plan="${esc(plan.plan_code)}">${esc(actionLabel)}</button>`:published?`<button class="btn btn-ghost kx-plan-preview" data-plan="${esc(plan.plan_code)}" type="button">Ver simulación de activación</button><small>La simulación no solicita tarjeta ni activa el plan.</small>`:'<small>Disponible cuando se publiquen las condiciones definitivas.</small>'}
  </article>`;
}
function additionalOfferCard(offer){
  const free=offer.kind==='identity';
  const priced=!PUBLIC_PRICING_LOCKED&&offer.price_published===true&&Number.isInteger(offer.price_minor);
  const price=free?'Gratis':PUBLIC_PRICING_LOCKED?'No disponible hasta lanzamiento':priced?`${offer.starting_price?'Desde ':''}${eurMinor(offer.price_minor)}/mes + IVA`:'Precio por definir';
  const body=free?'Presencia pública e identidad propia. La gestión privada se activa por separado.':offer.product_code==='multiclub'?'Escala para una organización con varias sedes. Las condiciones finales dependen de la estructura.':'Las condiciones comerciales se publicarán cuando estén definidas.';
  return `<article class="kx-price-card" data-product-card="${esc(offer.product_code)}"><div class="kx-price-card-head"><div><small>${free?'IDENTIDAD PÚBLICA':offer.starting_price?'ESCALA':'PLAN'}</small><h3>${esc(offer.name)}</h3><p>${esc(body)}</p></div></div><div class="kx-price-main"><strong>${price}</strong></div><small>${free?'No exige suscripción. La verificación de identidad y los permisos siguen su propio proceso.':PUBLIC_PRICING_LOCKED?'Las tarifas y contrataciones públicas permanecerán ocultas durante el piloto.':'Consulta disponibilidad y límites antes de activar.'}</small></article>`;
}
function activationGrid(catalog,audience,{canRequest=false,context=null}={}){
  if(PUBLIC_PRICING_LOCKED)return `<section class="kx-commercial-section"><div class="kx-commercial-section-title"><small>SERVICIOS PUNTUALES</small><h2>No disponible hasta lanzamiento</h2></div><div class="kx-activation-grid"><article><h3>Funciones comerciales preservadas</h3><p>Showcase, Commerce, publicación de Events, promoción y Ticketing mantienen sus capacidades y reglas internas, pero durante el piloto no se muestran precios ni se habilita contratación pública desde esta pantalla.</p><small>Los clubes y perfiles autorizados para el piloto se gestionan por el circuito de activación del piloto.</small></article></div></section>`;
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
      <article><h3>Destacar</h3><p>Prioridad en Events/Showcase + amplificación automática en KOMBAX Social.</p><div>${promoCards}</div><small>Se contrata desde el evento o producto concreto. La promoción se muestra con una frecuencia equilibrada para cuidar la experiencia en Social.</small></article>
      <article><h3>Ticketing</h3><p>Activación puntual según capacidad del evento.</p><div>${ticketCards}</div><small>Incluye checkout, ticket digital, QR, lector y control de acceso. Más de ${Number(c.large_event_threshold||1000).toLocaleString(kxLocaleTag(kxGetLocale()))} entradas: Gran Evento con condiciones específicas.</small></article>
    </div>
  </section>`;
}
function partnerSection(catalog){if(PUBLIC_PRICING_LOCKED)return `<section class="kx-commercial-section kx-partner-panel"><div><small>KOMBAX PARTNER</small><h2>Programa preparado para lanzamiento</h2><p>Durante el piloto no se muestran porcentajes, precios ni condiciones económicas públicas del programa Partner.</p></div></section>`;const p=catalog.config?.partner_program||{};return `<section class="kx-commercial-section kx-partner-panel"><div><small>KOMBAX PARTNER</small><h2>Haz crecer tu red</h2><p>Comisión sobre la base imponible de la suscripción del club referido, sin IVA ni extras.</p></div><div class="kx-partner-stats"><span><b>${p['1_9_percent']||25}%</b> · 1–9 clubes</span><span><b>${p['10_plus_percent']||30}%</b> · 10+ clubes</span><span><b>100%</b> bonificación Federation con ${p.federation_free_active_referrals||5} clubes activos</span></div><p class="kx-commercial-warning">Suscripciones mensuales: cuotas 2–13. Para altas anuales la atribución se registra, pero la liquidación permanece pendiente de regla comercial específica.</p></section>`;}

export function commercialPlanSummary(audience){
  const plans=FALLBACK_COMMERCIAL_CATALOG.plans.filter(p=>p.audience===audience);
  const paid=WORK_OFFERS_FALLBACK.filter(p=>p.audience===audience&&p.kind==='subscription'&&p.price_published&&p.price_minor>0);
  const min=PUBLIC_PRICING_LOCKED?null:paid.length?Math.min(...paid.map(p=>p.price_minor)):null;
  return {audience,plans,from_minor:min,copy:audienceCopy(audience)};
}

export function renderCommercialDiscovery({onBack=null,onSelectPlan=null}={}){
  const audiences=['club','brand','federation'].map(commercialPlanSummary);
  const html=`<div class="kx-commercial-page kx-commercial-discovery">
    ${pageHeader('Planes y servicios',PUBLIC_PRICING_LOCKED?'Consulta las capacidades disponibles. Los precios permanecerán ocultos hasta el lanzamiento.':'Consulta las tarifas antes de crear una organización o vuelve aquí desde cualquier cuenta KOMBAX.',onBack?subviewActions({backId:'kx-commercial-discovery-back',closeId:'kx-commercial-discovery-close'}):'','KOMBAX')}
    <section class="kx-commercial-hero kx-commercial-discovery-hero"><div><span class="page-kicker">KOMBAX · CUENTA GRATIS + PLANES POR ORGANIZACIÓN</span><h1>Primero tu cuenta. Después eliges qué quieres hacer.</h1><p>Crear una cuenta KOMBAX es gratuito. Una cuenta puede explorar la plataforma, vincularse a un club y construir una identidad. Ser espectador es una forma de uso, no el nombre de todas las cuentas gratuitas. Los planes corresponden a capacidades operativas de una organización.</p></div>${PUBLIC_PRICING_LOCKED?'':`<a class="btn btn-ghost" href="${COMMERCIAL_PDF}" target="_blank" rel="noopener">Resumen de precios</a>`}</section>
    <section class="kx-commercial-journey" aria-label="Cómo funciona"><article><b>1</b><strong>Cuenta KOMBAX</strong><span>Registro gratuito.</span></article><article><b>2</b><strong>Identidad y vínculo</strong><span>Club, Marca, Federación o miembro de un club.</span></article><article><b>3</b><strong>Capacidades</strong><span>El plan activa servicios de gestión según la organización.</span></article><article><b>4</b><strong>Verificación</strong><span>La identidad y los permisos se revisan antes de activarse.</span></article></section>
    <section class="kx-audience-grid">${audiences.map(x=>`<article class="kx-audience-card"><span>${esc(x.copy.badge)}</span><h2>${esc(x.copy.title)}</h2><p>${esc(x.copy.body)}</p><div><small>Perfil público</small><strong>Gratis</strong></div><div><small>Gestión</small><strong>${PUBLIC_PRICING_LOCKED?'No disponible hasta lanzamiento':x.from_minor!=null?`${eurMinor(x.from_minor)}<em>/mes + IVA</em>`:'Precio por definir'}</strong></div><button type="button" class="btn btn-primary" data-kx-commercial-audience="${esc(x.audience)}">Ver planes ${esc(commercialAudienceName(x.audience))}</button></article>`).join('')}</section>
    <section class="kx-commercial-section kx-commercial-account-note"><div><small>CUENTA KOMBAX</small><h2>No tienes que pagar para registrarte</h2><p>Puedes explorar Social, Showcase y Events según las reglas de cada espacio. Más adelante podrás solicitar la vinculación con un club o crear una identidad. La gestión operativa requiere permisos de esa organización y, cuando corresponda, un plan.</p></div></section>
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
  const offers=await repos.commercial.offers(audience).then(data=>Array.isArray(data?.offers)?data.offers:[]).catch(()=>[]);
  const currentOffers=offers.length?offers:WORK_OFFERS_FALLBACK.filter(offer=>offer.audience===audience);
  if(resolvedSubjectId&&remote){try{context=await repos.commercial.context(resolvedSubjectType,resolvedSubjectId);}catch{/* catalog stays readable */}}
  const billing='monthly';
  const render=()=>{
    const plans=audience==='club'?(catalog.plans||[]).filter(p=>p.audience===audience):[];
    const selectMode=!resolvedSubjectId&&typeof onSelectPlan==='function';
    const html=`<div class="kx-commercial-page">
      ${pageHeader('Plan y servicios',PUBLIC_PRICING_LOCKED?`Consulta la identidad gratuita y las capacidades de ${commercialAudienceName(audience)}. Precios no disponibles durante el piloto.`:`Consulta la identidad gratuita, los planes y las capacidades de ${commercialAudienceName(audience)}.`,onBack?subviewActions({backId:'kx-commercial-back',closeId:'kx-commercial-close'}):'','KOMBAX')}
      <section class="kx-commercial-hero"><div><span class="page-kicker">KOMBAX · PLANES Y SERVICIOS</span><h1>Identidad gratuita y servicios a tu medida</h1><p>${PUBLIC_PRICING_LOCKED?'Durante la fase piloto puedes consultar capacidades y límites funcionales. Los precios y la contratación pública no estarán disponibles hasta el lanzamiento.':'Crear una cuenta y solicitar una identidad pública no exige un plan. La gestión operativa se solicita aparte. Los importes mensuales publicados para España se muestran sin IVA.'}</p></div>${PUBLIC_PRICING_LOCKED?'':`<a class="btn btn-ghost" href="${COMMERCIAL_PDF}" target="_blank" rel="noopener">Resumen de precios</a>`}</section>
      ${context?.founder_locked?'<section class="kx-founder-note"><strong>Condición Founder existente</strong><span>Tu condición anterior se conserva según sus términos y no se sustituye por el nuevo catálogo público.</span></section>':''}
      ${context?.plan_code?`<div class="kx-current-plan"><span>Plan actual</span><strong>${esc(context.plan_code)}</strong><small>${PUBLIC_PRICING_LOCKED?'Condiciones económicas no visibles durante el piloto':`Fee: ${Number(context.platform_fee_percent||0).toLocaleString(kxLocaleTag(kxGetLocale()))} % · ${context.founder_locked?'Founder protegido':'Tarifa según contrato vigente'}`}</small></div>`:''}
      ${selectMode&&!PUBLIC_PRICING_LOCKED?'<div class="kx-commercial-selection-note"><strong>Elegir no realiza ningún cobro.</strong><span>Tu elección se guardará para completar la solicitud. Te informaremos de las condiciones y del siguiente paso antes de activar el servicio.</span></div>':PUBLIC_PRICING_LOCKED?'<div class="kx-commercial-selection-note"><strong>No disponible hasta lanzamiento.</strong><span>Durante el piloto las identidades públicas y las activaciones autorizadas siguen su circuito específico, sin contratación pública desde esta pantalla.</span></div>':''}
      <section class="kx-price-grid">${currentOffers.filter(o=>o.kind==='identity').map(additionalOfferCard).join('')}${plans.map(p=>planCard(p,audience,context,currentOffers.find(o=>o.legacy_plan_code===p.plan_code),{selectMode})).join('')}${currentOffers.filter(o=>!o.legacy_plan_code&&o.kind!=='identity').map(additionalOfferCard).join('')}</section>
      ${activationGrid(catalog,audience,{canRequest:Boolean(resolvedSubjectId&&remote),context})}
      ${audience==='federation'?partnerSection(catalog):''}
      <section class="kx-commercial-section kx-payments-subscription-note"><div class="kx-commercial-section-title"><small>${esc(t('payments.planIntegratedKicker'))}</small><h2>${esc(t('payments.planTitle'))}</h2></div><div class="kx-activation-grid"><article><h3>${esc(t('payments.planIdentityTitle'))}</h3><p>${esc(t('payments.planIdentityBody'))}</p></article><article><h3>${esc(t('payments.cardTitle'))}</h3><p>${esc(t('payments.planCardBody'))}</p></article><article><h3>${esc(t('payments.sepaTitle'))}</h3><p>${esc(t('payments.planSepaBody'))}</p></article><article><h3>${esc(t('payments.planGuideTitle'))}</h3><p>${esc(t('payments.planGuideBody'))}</p><a class="btn btn-ghost" href="./assets/docs/GUIA_KOMBAX_COBROS_TAP_TO_PAY_IPHONE_R81.pdf" target="_blank" rel="noopener">${esc(t('payments.planOpenGuide'))}</a></article></div></section>
      <section class="kx-commercial-section kx-economic-rules"><h2>Reglas claras</h2><ul><li><b>Cuenta ≠ identidad ≠ plan.</b> Registrarte no activa una tarifa.</li><li><b>Publicar ≠ Destacar ≠ Ticketing.</b></li><li>Ticketing agrupa QR, lector y control de acceso: no se cobran como servicios separados.</li><li>Los límites Showcase son capacidad incluida. Las ampliaciones comerciales estarán disponibles tras el lanzamiento; archivar libera un espacio sin perder reputación ni historial.</li><li>Las variantes de talla, color, peso o formato no consumen productos adicionales.</li><li>Toda compra comercial personal exige 18 años.</li><li>Stripe procesa el cobro en la cuenta del vendedor u organizador. KOMBAX recibe únicamente las tarifas aplicables.</li><li><b>Tarjeta y SEPA son métodos independientes.</b> Se activan desde Cobros y Stripe cuando el perfil dispone de un servicio comercial compatible.</li><li><b>Commerce y Ticketing inmediato usan tarjeta.</b> SEPA queda reservado a cuotas y cobros recurrentes o diferidos compatibles, porque su confirmación no es instantánea.</li></ul></section>
    </div>`;
    if(onBack)setAppHtml(`<main id="main-view" class="main-view kx-commercial-standalone">${html}</main>`);else setMainHtml(html);
    if(onBack)bindSubviewActions(document,{backId:'kx-commercial-back',closeId:'kx-commercial-close',onBack,onClose:onBack});
    if(!PUBLIC_PRICING_LOCKED)document.querySelectorAll('.kx-plan-request').forEach(b=>b.addEventListener('click',async()=>{
      if(!resolvedSubjectId&&typeof onSelectPlan==='function'){
        onSelectPlan({audience,plan_code:b.dataset.plan,billing_cycle:billing});
        return;
      }
      if(!resolvedSubjectId){toast('Primero debes crear o seleccionar la organización.','error');return;}
      b.disabled=true;try{await repos.commercial.requestPlan(resolvedSubjectType,resolvedSubjectId,b.dataset.plan,billing);toast('Solicitud registrada. No se ha realizado ningún cobro.');context=await repos.commercial.context(resolvedSubjectType,resolvedSubjectId).catch(()=>context);render();}catch(e){b.disabled=false;toast(humanError(e),'error');}
    }));
    if(!PUBLIC_PRICING_LOCKED)document.querySelectorAll('.kx-plan-preview').forEach(b=>b.addEventListener('click',()=>{
      const plan=plans.find(x=>x.plan_code===b.dataset.plan);
      const offer=currentOffers.find(x=>x.legacy_plan_code===b.dataset.plan);
      if(!plan||!offer)return;
      openDetail({title:`Simulación · ${plan.name}`,subtitle:'Vista previa del futuro proceso de contratación. No se guardan datos de tarjeta ni se activa ningún servicio.',width:'680px',body:`<div class="kx-commercial-selection-note"><strong>15 días de prueba del plan elegido</strong><span>Después: ${esc(eurMinor(offer.price_minor))}/mes + IVA, si no cancelas. La prueba comenzará solo tras confirmar el método de pago en el flujo real.</span></div><ol><li>Revisas las capacidades y límites del plan.</li><li>Introduces facturación y tarjeta en el proveedor de pago.</li><li>KOMBAX confirma la verificación y la fecha final de la prueba.</li><li>Podrás cancelar antes del primer cobro.</li></ol><p>Esta pantalla es una simulación. La verificación de tarjeta y la renovación permanecen cerradas hasta conectar la cuenta Stripe de KOMBAX.</p><p>Los clubes aprobados para el piloto acceden por un circuito independiente, sin tarjeta y hasta el 15 de noviembre de 2026.</p>`});
    }));
    if(!PUBLIC_PRICING_LOCKED)document.querySelectorAll('[data-activation]').forEach(b=>b.addEventListener('click',async()=>{
      if(!resolvedSubjectId||!remote){toast('Primero debes crear o seleccionar una organización con acceso comercial.','error');return;}
      b.disabled=true;try{await repos.commercial.requestActivation(resolvedSubjectType,resolvedSubjectId,b.dataset.activation,{days:Number(b.dataset.days||0)||null});toast('Solicitud de activación registrada. No se ha realizado ningún cobro.');render();}catch(e){b.disabled=false;toast(humanError(e),'error');}
    }));
  };
  render();
}
