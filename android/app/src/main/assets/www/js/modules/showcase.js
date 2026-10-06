import { getLocale as kxGetLocale, t } from '../i18n/index.js';
import { localeTag as kxLocaleTag } from '../i18n/formatters.js';
import { repos } from '../core/repositories.js';
import { esc, money, dtFmt, humanError } from '../core/utils.js';
import { KOMBAX_BRAND, platformFeatures } from '../core/platform.js';
import { pageHeader, empty, openForm, openDetail, confirmDialog, toast, setError, setMainHtml, subviewActions, bindSubviewActions } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { openKombaxPublicProfile } from './public-profile.js';
import { brandHero } from '../ui/brand-hero.js';
import { mediaFrameAttrs, openMediaFramingEditor } from '../ui/media-framing.js';
import { state } from '../core/state.js';
import { renderPlanServices } from './plan-services.js';
import { contentTranslationAttrs, translateUserContentValue, prewarmUserContentTranslations } from '../i18n/user-content-translation.js';
import { paymentCenterSummaryHtml, bindPaymentCenter, openPaymentCenter } from './payments-center.js';
import { analyticsSummaryHtml, openPremiumAnalytics, openReportsCenter } from '../ui/analytics-reports-r77.js';
import { addShowcaseCartItem, cartBadgeHtml, openShowcaseCart, purchaseSelection, variantOptionsHtml } from './showcase-cart.js';
import { openFinanceContext } from './finance-context.js';

const PAGE_SIZE=24;
const CTA_KEYS={info:'common.actions.more',contact:'showcase.actions.contact',shop:'common.actions.open',web:'showcase.actions.web',where:'showcase.actions.where'};
const PROVIDER_LABELS={club:'Club',marca:'Marca',media:'Media / Creador',federacion:'Federación',competidor:'Competidor',profesional:'Profesional'};
const LIMIT_LABELS={15:'máximo 15',30:'máximo 30'};
let items=[];
let categories=[];
let managedBrands=[];
let cursor=null;
let done=false;
let currentQuery='';
let currentCategory='';
let activeView='catalog';
let managementLimit=60;
const PILOT_SHOWCASE_SLUGS=new Set(['urban-warriors-guantes-integrales-elite-r19-demo','urban-warriors-casco-integral-pro-r19-demo','urban-performance-whey-recovery-r19-demo']);
const isPilotShowcaseItem=item=>platformFeatures().showcaseDemo&&PILOT_SHOWCASE_SLUGS.has(String(item?.slug||''));
const isInternalShowcaseItem=item=>!isPilotShowcaseItem(item)&&(item?.demo===true||/(?:\[QA(?:\s+TEST)?\]|QA[-_ ]TEST|\bfictici[oa]\b|\bde demostraci[oó]n\b)/i.test([item?.nombre,item?.resumen].join(' '))||!String(item?.resumen||item?.descripcion||'').trim());

const PRIVATE_CLUB_SHOWCASE_ROLES=new Set(['direccion','coordinacion']);
const hasPrivateClubShowcaseRoute=()=>Boolean(state.session?.club_id&&PRIVATE_CLUB_SHOWCASE_ROLES.has(String(state.session?.rol||'')));
function openPublicShowcaseRoute(){
  activeView='catalog';
  const nav=document.querySelector('.nav-item[data-nav="showcase"], .bottom-nav [data-nav="showcase"]');
  if(nav){nav.click();return;}
  void renderShowcase();
}
function openPrivateShowcaseRoute(){
  const nav=document.querySelector('.nav-item[data-nav="my-showcase"], .bottom-nav [data-nav="my-showcase"]');
  if(nav){nav.click();return;}
  void renderMyShowcase();
}

const categoryIcon=slug=>icon(({equipamiento:'dumbbell',protecciones:'shield',textil:'package',nutricion:'activity',tecnologia:'settings',servicios:'users'})[slug]||'sparkles',{size:28});
const safeExternal=url=>/^https:\/\/[^\s]+$/i.test(String(url||''))?String(url):'';
const slugify=value=>String(value||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'').slice(0,80);
const ctaLabel=item=>String(item?.cta_label||'').trim()||t(CTA_KEYS[item?.cta_tipo]||CTA_KEYS.info);
const isProfessionalService=item=>String(item?.listing_kind||'product')==='professional_service';
const isProfessionalProvider=brand=>String(brand?.sujeto_tipo||'')==='profesional';
const stockStatusLabel=status=>({in_stock:'En stock',low_stock:'Stock bajo',out_of_stock:'Sin stock',not_tracked:'Stock no controlado',not_applicable:'Servicio'})[status]||'Stock';

function showcaseCommercialDescriptor(brand,sellerCenter=null){
  const type=String(brand?.sujeto_tipo||'');
  const subjectId=sellerCenter?.provider?.subject_id||(type==='club'?state.session?.club_id:null);
  if(type==='club')return {audience:'club',subjectType:'club',subjectId};
  if(type==='marca')return {audience:'brand',subjectType:'direct_profile',subjectId};
  if(type==='federacion')return {audience:'federation',subjectType:'direct_profile',subjectId};
  return subjectId?{audience:'individual',subjectType:'direct_profile',subjectId}:null;
}
function openShowcaseCommercialPlans(brand,descriptor){
  if(!descriptor){toast('Este perfil no utiliza un plan comercial de Showcase.','error');return;}
  renderPlanServices({audience:descriptor.audience,subjectType:descriptor.subjectType,subjectId:descriptor.subjectId,onBack:()=>renderManagement(brand.id)});
}
const ORDER_STATUS=Object.freeze({
  received:{label:'Pendiente de pago',tone:'pending',step:0},payment_confirmed:{label:'Pago confirmado',tone:'paid',step:1},preparing:{label:'Preparando',tone:'preparing',step:2},shipped:{label:'Enviado',tone:'shipped',step:3},delivered:{label:'Entregado',tone:'delivered',step:4},cancelled:{label:'Cancelado',tone:'cancelled',step:-1},refunded:{label:'Reembolsado',tone:'refunded',step:-1},incident:{label:'Incidencia abierta',tone:'incident',step:-1}
});
const orderMeta=status=>ORDER_STATUS[String(status||'')]||{label:String(status||'Pendiente'),tone:'pending',step:0};
const orderItemsLabel=o=>(Array.isArray(o?.items)?o.items:[]).map(i=>`${Number(i.quantity||1)}× ${i.name||'Producto'}`).join(' · ')||'Pedido Showcase';
const shippingLine=o=>{const raw=o?.shipping_address||{};const a=raw?.address||raw||{};return [a.line1,a.line2,a.postal_code,a.city,a.state,a.country].filter(Boolean).join(' · ');};
function orderProgress(status){const meta=orderMeta(status);if(meta.step<0)return `<div class="showcase-order-progress is-${esc(meta.tone)}"><span class="active"></span><small>${esc(meta.label)}</small></div>`;const labels=['Pago','Confirmado','Preparando','Enviado','Entregado'];return `<div class="showcase-order-progress">${labels.map((x,i)=>`<span class="${i<=meta.step?'active':''}"><i></i><small>${esc(x)}</small></span>`).join('')}</div>`;}

function statusBadge(ok,label,pending='Pendiente'){return `<span class="kx-market-status ${ok?'ok':'pending'}">${ok?icon('checkCircle',{size:14}):icon('clock',{size:14})} ${esc(ok?label:pending)}</span>`;}
function sellerApplicationEditable(status){return !['verified','suspended'].includes(String(status||''));}

export async function openSellerCenter(brand){
  try{
    const [data,connectSnapshot]=await Promise.all([repos.marketplace.sellerCenter(brand.id),repos.payments.paymentMethodsStatus('showcase_provider',brand.id).catch(()=>null)]),checks=data?.checks||{},base=data?.base_verification||{},app=data?.application||{},policies=Array.isArray(data?.policies)?data.policies:[],stripe=data?.stripe||connectSnapshot||{},sellerAccount=data?.seller_account||{},commercialAccess=data?.commercial_access||{};
    const sellerActive=sellerAccount.active===true||checks.selling_ready===true,commerceAllowed=commercialAccess.commerce_allowed===true,checkoutAvailable=commercialAccess.checkout_available===true||(sellerActive&&commerceAllowed),planCode=commercialAccess.plan_code||'';
    const step=(title,ok,detail)=>`<article class="kx-seller-step ${ok?'complete':''}"><span>${ok?icon('checkCircle',{size:20}):icon('clock',{size:20})}</span><div><strong>${esc(title)}</strong><small>${esc(detail)}</small></div></article>`;
    const policyHtml=policies.map(p=>`<article class="kx-market-policy ${p.accepted?'accepted':''}"><header><div><strong>${esc(p.title)}</strong><small>Versión ${esc(p.version)} · ${p.legal_review_status==='approved'?'Revisión jurídica aprobada':'Borrador QA · revisión jurídica pendiente'}</small></div>${statusBadge(p.accepted,'Aceptada','Pendiente de aceptar')}</header><details><summary>Leer documento</summary><p>${esc(p.body)}</p></details>${!p.accepted?`<button type="button" class="btn btn-primary btn-sm" data-seller-policy="${esc(p.code)}" data-policy-version="${esc(p.version)}">Aceptar documento</button>`:''}</article>`).join('');
    const body=`<div class="kx-seller-center"><div class="kx-seller-center-status">${step('Identidad KOMBAX',checks.identity_verified,'Verificación de la identidad vendedora necesaria')}${step('Vendedor verificado',checks.seller_verified,app.status?`Estado: ${app.status}`:'Solicitud pendiente')}${step('Contrato y políticas',checks.policies_accepted,'Aceptar documentos vigentes')}${step('Stripe Connect',checks.stripe_ready,stripe.status?`Estado Stripe: ${stripe.status}`:'Configurar cuenta de cobro')}${step('Cuenta de vendedor',sellerActive,sellerActive?'ACTIVA · independiente del plan Commerce':'Se activa al completar los cuatro pasos')}</div>
      <div class="alert ${sellerActive?'success':''}"><strong>${sellerActive?'Cuenta de vendedor ACTIVA':'Activa tu cuenta de vendedor'}</strong><span>${sellerActive?(commerceAllowed?'Tu identidad comercial está activada y tu plan permite Commerce. Puedes habilitar checkout en los productos.':'Tu identidad comercial está completamente activada. Puedes gestionar y publicar tu catálogo; Commerce es un derecho comercial separado y no afecta a tu verificación como vendedor.'):'Todo vendedor de productos debe completar esta activación aunque su plan todavía no incluya Commerce. La verificación de vendedor y los derechos del plan son independientes.'}</span></div>
      <section class="kx-seller-commercial-state"><h4>Estado comercial</h4><div class="kx-market-facts"><span>Plan <strong>${esc(planCode||'Sin plan detectado')}</strong></span><span>Centro vendedor <strong>Disponible</strong></span><span>Catálogo <strong>Disponible</strong></span><span>Commerce <strong>${commerceAllowed?'Disponible':'No activo'}</strong></span><span>Checkout <strong>${checkoutAvailable?'Disponible':'Bloqueado'}</strong></span></div>${!isProfessionalProvider(brand)&&!commerceAllowed?`<div class="kx-seller-commerce-cta"><div><strong>${esc(t('marketing.space.sellerPunctual'))}</strong><small>${esc(t('marketing.space.sellerRequestNote'))}</small></div><button type="button" class="btn btn-primary" id="seller-commerce-plan">${esc(t('marketing.space.sellerRequest'))}</button></div>`:''}</section>
      <section><h4>1. Identidad comercial</h4><div class="kx-market-facts"><span>Proveedor <strong>${esc(data?.provider?.name||brand.nombre)}</strong></span><span>Tipo <strong>${esc(PROVIDER_LABELS[data?.provider?.type]||data?.provider?.type||'Vendedor')}</strong></span><span>Verificación KOMBAX <strong>${checks.identity_verified?'Verificada':'Pendiente'}</strong></span>${base.responsible?`<span>Responsable <strong>${esc(base.responsible)}</strong></span>`:''}</div>${!checks.identity_verified?'<p class="muted">Primero debe completarse la verificación KOMBAX de la entidad. No volveremos a pedir documentación ya validada.</p>':''}</section>
      <section><h4>2. Solicitud de vendedor</h4>${app.id?`<div class="kx-market-facts"><span>Estado <strong>${esc(app.status)}</strong></span><span>Razón social <strong>${esc(app.legal_name||'—')}</strong></span><span>NIF/CIF <strong>${esc(app.tax_id||'—')}</strong></span><span>País <strong>${esc(app.country||'—')}</strong></span></div>${app.review_note?`<div class="alert"><strong>Nota de revisión</strong><span>${esc(app.review_note)}</span></div>`:''}`:'<p class="muted">Confirma los datos de actividad comercial y solicita el alta específica para vender.</p>'}${sellerApplicationEditable(app.status)?'<button type="button" class="btn btn-primary" id="seller-application-edit">Completar / enviar solicitud</button>':''}</section>
      <section><h4>3. Contrato y políticas</h4><div class="kx-market-policy-list">${policyHtml||'<p class="muted">No hay documentos activos.</p>'}</div></section>
      <section><h4>4. ${esc(t('payments.title'))}</h4>${paymentCenterSummaryHtml(stripe||{}, {subjectType:'showcase_provider',title:t('payments.title'),compact:true})}</section>
    </div>`;
    const modal=openDetail({title:'Centro de vendedor',subtitle:`${brand.nombre} · activación, verificación, Stripe y derechos comerciales`,body,width:'980px',className:'kx-seller-center-modal'});
    modal.wrap.querySelector('#seller-application-edit')?.addEventListener('click',()=>openForm({title:'Alta de vendedor KOMBAX Showcase',subtitle:checks.identity_verified?'Reutilizamos la identidad KOMBAX ya verificada. Confirma únicamente los datos comerciales necesarios para vender.':'Puedes preparar los datos comerciales. La solicitud se enviará cuando tu identidad esté verificada.',fields:[
      {name:'legal_name',label:'Razón social / nombre legal',required:true,value:app.legal_name||base.legal_name||brand.nombre},{name:'tax_id',label:'NIF / CIF / VAT',required:true,value:app.tax_id||base.tax_id||''},{name:'country',label:'País (código ISO)',required:true,value:app.country||'ES',maxLength:2},{name:'registered_address',label:'Domicilio legal / administrativo',required:true,full:true,value:app.registered_address||base.registered_address||''},{name:'support_email',label:'Email de atención al comprador',type:'email',required:true,value:app.support_email||base.support_email||''},{name:'support_phone',label:'Teléfono de atención',required:true,value:app.support_phone||base.support_phone||''},{name:'returns_contact',label:'Contacto para devoluciones (opcional)',value:app.returns_contact||''},{name:'seller_shipping',label:'Realiza envíos',type:'checkbox',value:(app.shipping_modes||[]).includes('seller_shipping'),full:true},{name:'seller_pickup',label:'Permite recogida',type:'checkbox',value:(app.shipping_modes||[]).includes('seller_pickup'),full:true},{name:'digital',label:'Entrega digital (si aplica)',type:'checkbox',value:(app.shipping_modes||[]).includes('digital'),full:true},{name:'compliance_statement',label:'Declaro que los productos y mi actividad cumplen la normativa aplicable',type:'checkbox',required:true,value:app.compliance_statement===true,full:true},{name:'marketplace_statement',label:'Declaro que actúo como vendedor independiente y soy responsable del producto, entrega, garantía y devoluciones',type:'checkbox',required:true,value:app.marketplace_statement===true,full:true}],submitText:checks.identity_verified?'Enviar solicitud':'Guardar borrador',onSubmit:async v=>{const shipping_modes=['seller_shipping','seller_pickup','digital'].filter(k=>v[k]===true);await repos.marketplace.sellerApplication(brand.id,checks.identity_verified?'submit':'save',{...v,shipping_modes});toast(checks.identity_verified?'Solicitud de vendedor enviada':'Borrador de vendedor guardado');modal.close();await openSellerCenter(brand);}}));
    if(!checks.identity_verified){const button=modal.wrap.querySelector('#seller-application-edit');if(button)button.textContent='Preparar datos de vendedor';}
    modal.wrap.querySelectorAll('[data-seller-policy]').forEach(btn=>btn.addEventListener('click',async()=>{btn.disabled=true;try{await repos.marketplace.acceptSellerPolicy(brand.id,btn.dataset.sellerPolicy,btn.dataset.policyVersion);toast('Documento aceptado');modal.close();await openSellerCenter(brand);}catch(error){btn.disabled=false;setError(error);}}));
    modal.wrap.querySelector('#seller-commerce-plan')?.addEventListener('click',async e=>{if(!sellerActive){toast(t('marketing.space.sellerVerify'),'error');return;}e.currentTarget.disabled=true;try{await repos.commercial.requestActivation(data.provider.subject_type,data.provider.subject_id,'SHOWCASE_COMMERCE',{days:30});toast(t('marketing.space.sellerRequested'));}catch(error){e.currentTarget.disabled=false;toast(humanError(error),'error');}});
    bindPaymentCenter(modal.wrap,{subjectType:'showcase_provider',subjectId:brand.id,onRefresh:async()=>{modal.close();await openSellerCenter(brand);},assistContext:{profileId:data?.provider?.subject_id||brand?.perfil_directo_id||null,profileType:brand?.sujeto_tipo||null}});
  }catch(error){setError(error);}
}

async function ensureBuyerMarketplaceTerms(){
  const trust=await repos.marketplace.buyerTrust();const missing=(trust?.policies||[]).filter(p=>p.required&&!p.accepted);if(!missing.length)return true;
  return new Promise(resolve=>{
    const body=`<div class="kx-buyer-terms"><div class="alert"><strong>Antes de comprar</strong><span>La compraventa se realiza con el vendedor indicado. Stripe procesa el pago. Lee y acepta las condiciones vigentes de KOMBAX Showcase.</span></div>${missing.map(p=>`<article class="kx-market-policy"><header><strong>${esc(p.title)}</strong><small>Versión ${esc(p.version)} · ${p.legal_review_status==='approved'?'Aprobada':'Borrador QA · revisión jurídica pendiente'}</small></header><p>${esc(p.body)}</p></article>`).join('')}<button type="button" class="btn btn-primary" id="accept-buyer-marketplace-terms">Aceptar y continuar</button></div>`;
    const modal=openDetail({title:'Condiciones de compra en Showcase',subtitle:'Protección del comprador y condiciones de marketplace',body,width:'850px'});
    modal.wrap.querySelector('#accept-buyer-marketplace-terms')?.addEventListener('click',async e=>{e.currentTarget.disabled=true;try{for(const p of missing)await repos.marketplace.acceptBuyerPolicy(p.code,p.version);modal.close();resolve(true);}catch(error){e.currentTarget.disabled=false;setError(error);resolve(false);}});
  });
}

async function openBuyerIdentityVerification(onDone){
  const trust=await repos.marketplace.buyerTrust();const current=trust?.identity_request||{};
  openForm({title:'Verificación de identidad del comprador',subtitle:'Opcional para compras normales. Puede utilizarse para reforzar confianza, resolver riesgos o atender una comprobación específica. El documento queda privado para verificación KOMBAX.',fields:[{name:'full_name',label:'Nombre legal completo',required:true,value:current.full_name||''},{name:'country',label:'País (código ISO)',required:true,value:current.country||'ES',maxLength:2},{name:'reason',label:'Motivo / contexto (opcional)',type:'textarea',maxLength:800,full:true,value:current.reason||''},{name:'document_type',label:'Tipo de documento',type:'select',value:'identity',options:[{value:'identity',label:'Identidad'},{value:'residence',label:'Residencia'},{value:'other',label:'Otro'}]},{name:'document',label:'Documento privado',type:'file',accept:'.pdf,.jpg,.jpeg,.png,.webp,application/pdf,image/jpeg,image/png,image/webp',required:current.status!=='needs_information',full:true,help:'PDF/JPG/PNG/WEBP · máximo 15 MB.'}],submitText:'Enviar para revisión',onSubmit:async v=>{const out=await repos.marketplace.buyerIdentitySubmit({full_name:v.full_name,country:v.country,reason:v.reason});const requestId=out?.data?.id||current.id;if(v.document&&requestId)await repos.marketplace.uploadBuyerIdentityDocument(requestId,v.document_type,v.document);toast('Solicitud de identidad enviada');await onDone?.();}});
}

function buyerTrustHtml(trust){const status=trust?.identity_status||'not_requested';return `<section class="kx-buyer-trust"><div><span class="page-kicker">CONFIANZA Y PROTECCIÓN</span><h3>Tu estado como comprador</h3><p>KOMBAX no exige DNI para una compra ordinaria. Stripe valida el pago; la identidad reforzada es opcional salvo que exista una necesidad concreta.</p></div><div class="kx-buyer-trust-badges">${statusBadge(trust?.account_verified===true,'Cuenta KOMBAX','Cuenta pendiente')}${statusBadge(trust?.payment_verified===true,'Pago verificado','Sin pago verificado')}${statusBadge(trust?.identity_verified===true,'Identidad verificada',status==='not_requested'?'Identidad opcional':`Identidad: ${status}`)}</div>${!trust?.identity_verified?'<button type="button" class="btn btn-ghost btn-sm" id="buyer-identity-verify">Solicitar verificación de identidad</button>':''}</section>`;}


function showcaseBrand(){
  return brandHero({area:'showcase',headline:'Muestra. Promociona.',accent:'Destaca.',body:'Escaparate profesional de KOMBAX para presentar perfiles, productos, servicios y oportunidades del mundo del combate.',features:[{icon:'user',label:'Perfiles'},{icon:'package',label:'Productos'},{icon:'professional',label:'Servicios'},{icon:'sparkles',label:'Oportunidades'}]});
}

function controls(){
  return `<div class="showcase-controls"><div class="showcase-search"><input id="showcase-query" type="search" value="${esc(currentQuery)}" placeholder="Buscar perfiles, productos, servicios o categorías"><button class="btn btn-primary" id="showcase-search">Buscar</button></div><div class="showcase-categories"><button type="button" data-showcase-category="" class="${currentCategory?'':'active'}">Todo</button>${categories.map(c=>`<button type="button" data-showcase-category="${esc(c.slug)}" class="${currentCategory===c.slug?'active':''}">${esc(c.nombre)}</button>`).join('')}</div></div>`;
}

function cardHtml(item){
  const image=safeExternal(item.imagen_url),service=isProfessionalService(item);
  return `<article class="showcase-item ${item.destacado?'featured':''} ${service?'is-service':''}" data-content-channel="showcase" data-content-id="${esc(item.id)}" data-showcase-detail="${esc(item.id)}" tabindex="0" role="button" aria-label="Abrir ${esc(item.nombre)}">
    <div class="showcase-item-visual">${image?`<img ${mediaFrameAttrs(item.imagen_presentacion,"product")} src="${esc(image)}" alt="${esc(item.nombre)}" loading="lazy">`:`<div>${categoryIcon(item.categoria_slug)}<span>${esc(item.categoria_nombre||'Showcase')}</span></div>`}${item.etiqueta_destacada?`<b>${esc(item.etiqueta_destacada)}</b>`:''}<button class="showcase-save-icon ${item.guardado?'active':''}" type="button" data-showcase-save="${esc(item.id)}" aria-label="${item.guardado?'Quitar de guardados':'Guardar'}">${icon(item.guardado?'bookmarkCheck':'bookmark',{size:18})}</button></div>
    <div class="showcase-item-body"><span class="page-kicker">${esc(item.marca_nombre)} ${item.marca_verificada?icon('shieldCheck',{size:13}):''}</span><h2 ${contentTranslationAttrs({contentId:item.id,contentType:'showcase_product_name',fieldName:'name',sourceLocale:item.source_locale||item.idioma||'',visibility:'public'})}>${esc(item.nombre)}</h2><p ${contentTranslationAttrs({contentId:item.id,contentType:'showcase_product_summary',fieldName:'summary',sourceLocale:item.source_locale||item.idioma||'',visibility:'public'})}>${esc(item.resumen||'Información disponible en KOMBAX Showcase.')}</p><footer><span>${service?'Servicio profesional':esc(item.product_type||item.categoria_nombre||'Producto')}</span>${!service&&item.commerce_enabled&&item.precio_venta!=null?`<strong>${money(item.precio_venta)}</strong>`:item.precio_orientativo!=null?`<strong>${money(item.precio_orientativo)} <small>orientativo</small></strong>`:`<strong>${service?'Contactar':esc(ctaLabel(item))}</strong>`}</footer></div>
  </article>`;
}

async function buyerCanCheckout(){
  try{const age=await repos.commercialCompliance.purchaseEligibility();if(age?.eligible===false){toast(t('commerce.adultsOnly'),'error');return false;}return await ensureBuyerMarketplaceTerms();}
  catch(error){setError(error);return false;}
}
async function checkoutCartRows(rows){
  if(!Array.isArray(rows)||!rows.length)return;
  if(!await buyerCanCheckout())return;
  const seller=rows[0]?.seller_name||t('commerce.seller');
  const total=rows.reduce((sum,row)=>sum+Number(row.unit_amount||0)*Number(row.quantity||1),0);
  confirmDialog(t('commerce.checkoutTitle'),`${rows.reduce((n,row)=>n+Number(row.quantity||1),0)} · ${money(total)} · ${t('commerce.soldAndChargedBy')} ${seller}.`,async()=>{
    rows.forEach(row=>repos.kombaxShowcase.track('showcase_checkout_start',{provider_id:row.seller_provider_id||null,product_id:row.product_id,source:'showcase_cart'}).catch(()=>{}));
    const out=await repos.payments.checkoutCart(rows);if(!out?.url)throw new Error(t('commerce.checkoutUnavailable'));location.assign(out.url);
  },{confirmText:t('commerce.continuePayment')});
}
async function buyProduct(item,root=document){
  if(isProfessionalService(item)){toast(t('commerce.servicesNoCheckout'),'error');return;}
  if(!item?.commerce_enabled||!item?.seller_account_active){toast(t('commerce.sellerNotReady'),'error');return;}
  const selection=purchaseSelection(item,root);
  if(!await buyerCanCheckout())return;
  const row={product_id:item.id,name:item.nombre||t('commerce.product'),seller_provider_id:item.marca_id,seller_name:item.marca_nombre||'',unit_amount:Number(item.precio_venta||0),currency:item.moneda||'EUR',quantity:selection.quantity,variant:selection.variant||null,stock:item.stock==null?null:Number(item.stock),image_url:item.imagen_url||'',fulfillment:item.fulfillment||''};
  await checkoutCartRows([row]);
}
function addProductToCart(item,root=document){
  try{const selection=purchaseSelection(item,root);addShowcaseCartItem(item,selection);}catch(error){toast(humanError(error)||String(error?.message||error),'error');}
}
function openCart(){openShowcaseCart({onCheckout:checkoutCartRows});}

async function reportShowcaseItem(item){
  openForm({title:'Reportar producto de Showcase',subtitle:'KOMBAX revisará la oferta y conservará la trazabilidad del expediente. Una denuncia no retira automáticamente el producto salvo riesgo grave justificado.',fields:[{name:'reason',label:'Motivo',type:'select',required:true,options:[{value:'dangerous_product',label:'Producto peligroso'},{value:'illegal_product',label:'Producto ilegal'},{value:'counterfeit',label:'Falsificación'},{value:'intellectual_property',label:'Propiedad intelectual'},{value:'fraud',label:'Fraude'},{value:'misleading_information',label:'Información engañosa'},{value:'prohibited_product',label:'Producto prohibido por política KOMBAX'},{value:'other',label:'Otro'}]},{name:'detail',label:'Información adicional',type:'textarea',maxLength:4000,full:true}],submitText:'Enviar reporte',onSubmit:async v=>{await repos.commercialCompliance.report('product',item.id,v.reason,v.detail||'');toast('Reporte enviado para revisión.');}});
}

async function shareItem(item){
  const text=`${item.nombre} · ${item.marca_nombre}`;
  const url=safeExternal(item.visitar_url)||location.href;
  try{
    if(navigator.share){await navigator.share({title:item.nombre,text,url});return;}
    await navigator.clipboard.writeText(`${text} ${url}`);toast('Enlace copiado');
  }catch(error){if(error?.name!=='AbortError')toast('No se pudo compartir esta ficha.','error');}
}

async function toggleSaved(item,force){
  const next=typeof force==='boolean'?force:!item.guardado;
  try{await repos.kombaxShowcase.toggleSaved(item.id,next);item.guardado=next;toast(next?'Guardado en tu Showcase':'Eliminado de guardados');if(activeView==='saved')await renderSaved();else renderCatalog();}
  catch(error){setError(error);toast(humanError(error)||'No se pudo actualizar el guardado.','error');}
}

async function openShowcaseContact(item){
  if(!item?.proveedor_social_id){toast('Este escaparate todavía no tiene un perfil KOMBAX disponible para contacto.','error');return;}
  try{
    const mine=await repos.kombaxSocial.myProfiles();
    const eligible=(Array.isArray(mine)?mine:[]).filter(x=>x.contacto_habilitado&&String(x.id)!==String(item.proveedor_social_id));
    if(!eligible.length){toast('No tienes una identidad autorizada para iniciar esta consulta de Showcase.','error');return;}
    openForm({
      title:`Consultar · ${item.nombre}`,
      subtitle:`KOMBAX Showcase · ${item.marca_nombre||'Proveedor'} · la conversación quedará vinculada a este producto o servicio.`,
      fields:[
        {name:'remitente',label:'Consultar como',type:'select',required:true,value:eligible[0].id,options:eligible.map(x=>({value:x.id,label:x.identity_label||x.nombre_publico}))},
        {name:'mensaje',label:'Primer mensaje',type:'textarea',required:true,full:true,rows:5,minLength:10,maxLength:500,help:'Entre 10 y 500 caracteres. El producto, su imagen y su referencia quedarán visibles dentro del chat.'}
      ],
      submitText:'Abrir consulta Showcase',
      onSubmit:async v=>{
        const out=await repos.kombaxSocial.showcaseContact(v.remitente,item.id,v.mensaje);
        const contactId=out?.id||out?.contacto_id||out?.contact_id||'';
        try{sessionStorage.setItem('kombax_conversation_channel','showcase');if(contactId)sessionStorage.setItem('kombax_social_open_contact',String(contactId));}catch{}
        toast('Consulta Showcase preparada en Conversaciones KOMBAX');
        setTimeout(()=>{location.hash='#conversations';},0);
      }
    });
  }catch(error){setError(error);toast(humanError(error)||'No se pudo iniciar la consulta Showcase.','error');}
}

async function runPrimaryCta(item){
  const type=item.cta_tipo||'info';
  if(type==='contact'&&item.proveedor_social_id){return openShowcaseContact(item);}
  const external=type==='where'?safeExternal(item.donde_encontrar_url):(type==='shop'||type==='web'?safeExternal(item.visitar_url):'');
  if(external){window.open(external,'_blank','noopener,noreferrer');return;}
  if(type==='contact'){
    const contact=safeExternal(item.contacto_url);if(contact){window.open(contact,'_blank','noopener,noreferrer');return;}
  }
  if(item.proveedor_social_id)return openKombaxPublicProfile(item.proveedor_social_id);
  toast('Toda la información disponible está incluida en esta ficha.');
}


const reviewStars=value=>{const n=Math.max(0,Math.min(5,Number(value)||0));return `${'★'.repeat(Math.round(n))}${'☆'.repeat(5-Math.round(n))}`;};
const reviewMediaHtml=media=>Array.isArray(media)&&media.length?`<div class="kx-review-media">${media.slice(0,5).map(m=>{const url=safeExternal(typeof m==='string'?m:m?.url);return url?`<a href="${esc(url)}" target="_blank" rel="noopener"><img src="${esc(url)}" alt="Foto de reseña" loading="lazy"></a>`:'';}).join('')}</div>`:'';
function openProductReviewForm(item,wrap,current=null){
  openForm({title:current?'Editar valoración':'Valorar producto',subtitle:'Tu reseña ayuda a otros usuarios. Si KOMBAX puede vincularla a un pedido entregado aparecerá como Compra verificada.',width:'680px',submitText:current?'Guardar cambios':'Publicar valoración',fields:[
    {name:'rating',label:'Puntuación',type:'select',required:true,value:String(current?.rating||5),options:[5,4,3,2,1].map(v=>({value:String(v),label:`${v} ${v===1?'estrella':'estrellas'}`}))},
    {name:'body',label:'Tu experiencia',type:'textarea',rows:5,maxLength:4000,full:true,value:current?.body||''},
    {name:'photo1',label:'Foto 1 (opcional)',type:'file',accept:'image/jpeg,image/png,image/webp',full:true},{name:'photo2',label:'Foto 2 (opcional)',type:'file',accept:'image/jpeg,image/png,image/webp',full:true},{name:'photo3',label:'Foto 3 (opcional)',type:'file',accept:'image/jpeg,image/png,image/webp',full:true}
  ],onSubmit:async values=>{const media=[...(Array.isArray(current?.media)?current.media:[])];for(const key of ['photo1','photo2','photo3'])if(values[key]){const uploaded=await repos.kombaxShowcase.uploadReviewMedia(item.id,values[key]);media.push({url:uploaded.url,type:'image'});}await repos.kombaxShowcase.reviewUpsert(item.id,Number(values.rating),values.body||'',media.slice(0,5));toast('Valoración guardada');await hydrateProductReviews(wrap,item);}});
}
async function hydrateProductReviews(wrap,item,filter='recent'){
  const zone=wrap?.querySelector?.('#showcase-review-zone');if(!zone)return;
  zone.innerHTML='<div class="loading-card">Cargando valoraciones…</div>';
  try{
    const data=await repos.kombaxShowcase.reviews(item.id,filter,60),summary=data?.summary||{},reviews=Array.isArray(data?.reviews)?data.reviews:[],own=reviews.find(r=>r.own);
    zone.innerHTML=`<div class="kx-review-head"><div><span class="page-kicker">VALORACIONES DEL PRODUCTO</span><div class="kx-rating-score"><strong>${Number(summary.average||0).toLocaleString(kxLocaleTag(kxGetLocale()),{maximumFractionDigits:2})}</strong><span>${reviewStars(summary.average||0)}</span><small>${Number(summary.total||0)} valoraciones · ${Number(summary.verified_total||0)} compras verificadas</small></div></div>${data?.can_review?`<button type="button" class="btn btn-primary" id="showcase-write-review">${own?'Editar mi reseña':'Escribir reseña'}</button>`:''}</div><div class="kx-review-filters">${[['recent','Más recientes'],['best','Mejor valoradas'],['worst','Peor valoradas'],['photos','Con fotos'],['verified','Compra verificada']].map(([v,l])=>`<button type="button" class="${filter===v?'active':''}" data-review-filter="${v}">${l}</button>`).join('')}</div>${reviews.length?`<div class="kx-review-list">${reviews.map(r=>`<article><header><div><strong>${esc(r.author_name||'Usuario KOMBAX')}</strong><span>${reviewStars(r.rating)}</span></div>${r.verified_purchase?`<b class="kx-verified-badge">✓ ${t('showcase.labels.verifiedPurchase')}</b>`:''}</header>${r.body?`<p ${contentTranslationAttrs({contentId:r.id,contentType:'showcase_product_review',fieldName:'body',sourceLocale:r.source_locale||r.idioma||'',visibility:'public'})}>${esc(r.body)}</p>`:''}${reviewMediaHtml(r.media)}${r.seller_response?`<div class="kx-seller-response"><strong>Respuesta del vendedor</strong><p ${contentTranslationAttrs({contentId:r.id,contentType:'showcase_product_review',fieldName:'seller_response',sourceLocale:r.seller_response_locale||'',visibility:'public'})}>${esc(r.seller_response)}</p></div>`:''}<footer><small>${dtFmt(r.created_at)}</small>${r.own?`<button type="button" class="btn btn-ghost btn-sm" data-review-edit="${esc(r.id)}">Editar</button><button type="button" class="btn btn-ghost btn-sm" data-review-withdraw="${esc(r.id)}">Retirar</button>`:`<button type="button" class="btn btn-ghost btn-sm" data-review-report="${esc(r.id)}">Reportar</button>`}</footer></article>`).join('')}</div>`:empty('Todavía no hay valoraciones','Sé la primera persona en valorar este producto.')}`;
    zone.querySelectorAll('[data-review-filter]').forEach(b=>b.addEventListener('click',()=>hydrateProductReviews(wrap,item,b.dataset.reviewFilter)));
    zone.querySelector('#showcase-write-review')?.addEventListener('click',()=>openProductReviewForm(item,wrap,own));
    zone.querySelectorAll('[data-review-edit]').forEach(b=>b.addEventListener('click',()=>openProductReviewForm(item,wrap,reviews.find(r=>r.id===b.dataset.reviewEdit))));
    zone.querySelectorAll('[data-review-withdraw]').forEach(b=>b.addEventListener('click',()=>confirmDialog('Retirar mi reseña','La valoración dejará de mostrarse. El expediente técnico se conserva para integridad y moderación.',async()=>{await repos.kombaxShowcase.reviewWithdraw(b.dataset.reviewWithdraw);toast('Reseña retirada');await hydrateProductReviews(wrap,item);},{confirmText:'Retirar'})));
    zone.querySelectorAll('[data-review-report]').forEach(b=>b.addEventListener('click',()=>openForm({title:'Reportar reseña',fields:[{name:'reason',label:'Motivo',type:'select',required:true,options:[{value:'spam',label:'Spam'},{value:'abuse',label:'Contenido ofensivo'},{value:'fraud',label:'Posible fraude'},{value:'privacy',label:'Privacidad'},{value:'other',label:'Otro'}]},{name:'detail',label:'Detalle',type:'textarea',maxLength:1500,full:true}],submitText:'Enviar reporte',onSubmit:async v=>{await repos.kombaxEvents.reputationReport('product_review',b.dataset.reviewReport,v.reason,v.detail||'');toast('Reporte enviado a moderación.');}})));
  }catch(error){zone.innerHTML=`<div class="alert"><strong>Valoraciones no disponibles</strong><span>${esc(humanError(error)||'No se pudieron cargar.')}</span></div>`;}
}
async function openSellerReviews(brand){
  try{
    const data=await repos.kombaxShowcase.sellerReviews(brand.id,150),summary=data?.summary||{},rows=Array.isArray(data?.reviews)?data.reviews:[],evolution=Array.isArray(data?.evolution)?data.evolution:[],topProducts=Array.isArray(data?.top_products)?data.top_products:[],bottomProducts=Array.isArray(data?.bottom_products)?data.bottom_products:[];
    const trend=evolution.length?`<section class="kx-reputation-trend"><h3>Evolución · últimos 6 meses</h3><div>${evolution.map(x=>`<article><small>${esc(x.month||'')}</small><strong>${Number(x.average||0).toLocaleString(kxLocaleTag(kxGetLocale()),{maximumFractionDigits:2})} ★</strong><span>${Number(x.total??x.reviews??0)} reseñas</span></article>`).join('')}</div></section>`:'';
    const ranking=(topProducts.length||bottomProducts.length)?`<div class="kx-reputation-ranking">${topProducts.length?`<article><small>Productos mejor valorados</small>${topProducts.map((x,i)=>`<div class="kx-reputation-rank-row"><b>${i+1}. ${esc(x.product_name||'—')}</b><span>${Number(x.average||0).toLocaleString(kxLocaleTag(kxGetLocale()),{maximumFractionDigits:2})} ★ · ${Number(x.total||0)} reseñas</span></div>`).join('')}</article>`:''}${bottomProducts.length?`<article><small>Productos con menor valoración</small>${bottomProducts.map((x,i)=>`<div class="kx-reputation-rank-row"><b>${i+1}. ${esc(x.product_name||'—')}</b><span>${Number(x.average||0).toLocaleString(kxLocaleTag(kxGetLocale()),{maximumFractionDigits:2})} ★ · ${Number(x.total||0)} reseñas</span></div>`).join('')}</article>`:''}</div>`:'';
    const modal=openDetail({title:'Valoraciones · Mi Showcase',subtitle:`${brand.nombre} · reputación del catálogo`,width:'1100px',className:'kx-seller-reviews-modal',body:`<div class="kx-seller-dashboard-grid reputation"><article><small>Puntuación media</small><strong>${Number(summary.average||0).toLocaleString(kxLocaleTag(kxGetLocale()),{maximumFractionDigits:2})} ★</strong></article><article><small>Valoraciones</small><strong>${Number(summary.total||0)}</strong></article><article><small>Compra verificada</small><strong>${Number(summary.verified_percent||0).toLocaleString(kxLocaleTag(kxGetLocale()),{maximumFractionDigits:1})} %</strong><span>${Number(summary.verified_total||0)} reseñas</span></article><article><small>Sin responder</small><strong>${Number(summary.unanswered||0)}</strong></article><article><small>Reportes abiertos</small><strong>${Number(summary.pending_reports||0)}</strong></article></div>${ranking}${trend}${rows.length?`<section class="kx-reputation-recent"><h3>${t('showcase.labels.recentReviews')}</h3><div class="kx-review-list seller">${rows.map(r=>`<article><header><div><span class="page-kicker">${esc(r.product_name)}</span><strong>${esc(r.author_name||'Usuario KOMBAX')} · ${reviewStars(r.rating)}</strong></div>${r.verified_purchase?`<b class="kx-verified-badge">✓ ${t('showcase.labels.verifiedPurchase')}</b>`:''}</header>${r.body?`<p ${contentTranslationAttrs({contentId:r.id,contentType:'showcase_product_review',fieldName:'body',sourceLocale:r.source_locale||r.idioma||'',visibility:'public'})}>${esc(r.body)}</p>`:''}${reviewMediaHtml(r.media)}${r.seller_response?`<div class="kx-seller-response"><strong>${t('showcase.labels.yourResponse')}</strong><p ${contentTranslationAttrs({contentId:r.id,contentType:'showcase_product_review',fieldName:'seller_response',sourceLocale:r.seller_response_locale||'',visibility:'public'})}>${esc(r.seller_response)}</p></div>`:''}<footer><button type="button" class="btn btn-primary btn-sm" data-seller-review-response="${esc(r.id)}">${r.seller_response?t('showcase.actions.editResponse'):t('showcase.actions.respond')}</button><button type="button" class="btn btn-ghost btn-sm" data-seller-review-report="${esc(r.id)}">Reportar</button></footer></article>`).join('')}</div></section>`:empty(t('showcase.empty.reviewsTitle'),t('showcase.empty.reviewsBody'))}`});
    modal.wrap.querySelectorAll('[data-seller-review-response]').forEach(b=>b.addEventListener('click',()=>openForm({title:'Responder públicamente',fields:[{name:'response',label:'Respuesta del vendedor',type:'textarea',required:true,maxLength:3000,full:true,value:rows.find(r=>r.id===b.dataset.sellerReviewResponse)?.seller_response||''}],submitText:'Publicar respuesta',onSubmit:async v=>{await repos.kombaxShowcase.reviewRespond(b.dataset.sellerReviewResponse,v.response);toast('Respuesta publicada');modal.close();await openSellerReviews(brand);}})));
    modal.wrap.querySelectorAll('[data-seller-review-report]').forEach(b=>b.addEventListener('click',()=>openForm({title:'Reportar reseña',fields:[{name:'reason',label:'Motivo',required:true},{name:'detail',label:'Detalle',type:'textarea',maxLength:1500,full:true}],submitText:'Reportar',onSubmit:async v=>{await repos.kombaxEvents.reputationReport('product_review',b.dataset.sellerReviewReport,v.reason,v.detail||'');toast('Reporte enviado a moderación.');}})));
  }catch(error){setError(error);toast(humanError(error)||'No se pudieron cargar las valoraciones.','error');}
}

async function openItem(item){
  repos.kombaxShowcase.track('product_view',{provider_id:item?.marca_id||null,product_id:item?.id||null,source:'showcase'}).catch(()=>{});
  const visit=safeExternal(item.visitar_url),where=safeExternal(item.donde_encontrar_url),contact=safeExternal(item.contacto_url),image=safeExternal(item.imagen_url);
  const gallery=(Array.isArray(item.galeria)?item.galeria:[]).map(safeExternal).filter(Boolean).slice(0,3);
  const galleryHtml=gallery.length?`<div class="showcase-detail-gallery">${gallery.map((u,i)=>`<img ${mediaFrameAttrs(item?.galeria_presentacion?.[String(i)]||{},"product")} src="${esc(u)}" alt="${esc(item.nombre)}" loading="lazy">`).join('')}</div>`:'';
  const service=isProfessionalService(item);
  const [nameTranslation,descriptionTranslation]=await Promise.all([
    translateUserContentValue({contentId:item.id,contentType:'showcase_product_name',fieldName:'name',text:item.nombre||'',sourceLocale:item.source_locale||item.idioma||null,visibility:'public'}),
    translateUserContentValue({contentId:item.id,contentType:'showcase_product_description',fieldName:'description',text:item.descripcion||item.resumen||'',sourceLocale:item.source_locale||item.idioma||null,visibility:'public'})
  ]);
  const displayName=nameTranslation?.ok&&nameTranslation?.same_language!==true?String(nameTranslation.translated_text||item.nombre):item.nombre;
  const displayDescription=descriptionTranslation?.ok&&descriptionTranslation?.same_language!==true?String(descriptionTranslation.translated_text||item.descripcion||item.resumen||''):String(item.descripcion||item.resumen||'');
  const commerce=!service&&item.commerce_enabled&&item.precio_venta!=null;
  const maxQty=item.stock==null?99:Math.max(1,Math.min(99,Number(item.stock)||1));
  const sale=`<div class="showcase-reference-price"><span>${esc(t('commerce.finalPrice'))}</span><strong>${money(item.precio_venta)}</strong></div><div class="showcase-commerce-seller"><strong>${esc(t('commerce.soldBy'))}: ${esc(item.marca_nombre)} ${item.marca_verificada?'✓':''}</strong><span>${item.fulfillment==='seller_pickup'?t('commerce.pickupManaged'):t('commerce.shippingManaged')}</span><small>${item.stock==null?t('commerce.stockSellerManaged'):`${Number(item.stock)} ${t('commerce.unitsAvailable')}`}</small></div><div class="kx-product-purchase-options">${variantOptionsHtml(item)}<label class="kx-cart-option"><span>${esc(t('commerce.quantity'))}</span><input id="showcase-quantity" type="number" min="1" max="${maxQty}" value="1"></label></div>`;
  const {wrap}=openDetail({title:displayName,subtitle:`${item.marca_nombre} · ${item.categoria_nombre||'Showcase'}`,className:'showcase-detail',body:`<div class="showcase-detail-grid"><div><div class="showcase-detail-media">${image?`<img ${mediaFrameAttrs(item.imagen_presentacion,"product")} src="${esc(image)}" alt="${esc(item.nombre)}">`:`${categoryIcon(item.categoria_slug)}<span>${esc(item.categoria_nombre||'KOMBAX')}</span>`}</div>${galleryHtml}</div><div><span class="page-kicker">${t('showcase.labels.information')}</span><p ${contentTranslationAttrs({contentId:item.id,contentType:'showcase_product_description',fieldName:'description',sourceLocale:item.source_locale||item.idioma||'',visibility:'public'})}>${esc(displayDescription||'Sin descripción ampliada.')}</p>${commerce?sale:item.precio_orientativo!=null?`<div class="showcase-reference-price"><span>${t('showcase.labels.referencePrice')}</span><strong>${money(item.precio_orientativo)}</strong></div>`:''}<div class="showcase-no-commerce">${commerce?t('showcase.commerce.platformNotice'):service?t('showcase.commerce.serviceNotice'):t('showcase.commerce.externalNotice')}</div></div></div>${commerce?'<section class="kx-reputation-zone" id="showcase-review-zone"><div class="loading-card">Cargando valoraciones…</div></section>':''}`,actions:`${commerce?`<button class="btn btn-primary" id="showcase-buy" ${item.seller_account_active?'':'disabled'}>${esc(t('commerce.buyNow'))}</button><button class="btn btn-showcase" id="showcase-add-cart" ${item.seller_account_active?'':'disabled'}>${esc(t('commerce.addToCart'))}</button>`:`<button class="btn btn-primary" id="showcase-primary-cta">${esc(service?t('showcase.actions.contact'):ctaLabel(item))}</button>`}${item.proveedor_social_id&&item.cta_tipo!=='contact'?`<button class="btn btn-showcase" id="showcase-chat-cta">${icon('message',{size:15})} ${t('showcase.actions.interested')}</button>`:''}<button class="btn btn-ghost" id="showcase-detail-save">${item.guardado?t('showcase.actions.unsave'):t('showcase.actions.save')}</button><button class="btn btn-ghost" id="showcase-detail-share">${t('showcase.actions.share')}</button><button class="btn btn-ghost" id="showcase-detail-report">${t('showcase.actions.report')}</button>${item.proveedor_social_id?`<button class="btn btn-ghost" id="showcase-provider-profile">${t('showcase.actions.viewProfile')}</button>`:''}${visit&&item.cta_tipo!=='shop'&&item.cta_tipo!=='web'?`<a class="btn btn-ghost" href="${esc(visit)}" target="_blank" rel="noopener noreferrer">Web</a>`:''}${where&&item.cta_tipo!=='where'?`<a class="btn btn-ghost" href="${esc(where)}" target="_blank" rel="noopener noreferrer">${t('showcase.actions.where')}</a>`:''}${contact&&item.cta_tipo!=='contact'&&!item.proveedor_social_id?`<a class="btn btn-ghost" href="${esc(contact)}" target="_blank" rel="noopener noreferrer">Contacto</a>`:''}`,width:'900px'});
  wrap.querySelector('#showcase-buy')?.addEventListener('click',()=>buyProduct(item,wrap));
  wrap.querySelector('#showcase-add-cart')?.addEventListener('click',()=>addProductToCart(item,wrap));
  wrap.querySelector('#showcase-primary-cta')?.addEventListener('click',()=>runPrimaryCta(item));
  wrap.querySelector('#showcase-chat-cta')?.addEventListener('click',()=>{repos.kombaxShowcase.track('product_interest',{provider_id:item?.marca_id||null,product_id:item?.id||null,source:'showcase'}).catch(()=>{});openShowcaseContact(item);});
  wrap.querySelector('#showcase-detail-save')?.addEventListener('click',async e=>{const button=e.currentTarget;if(button.dataset.kxBusy==='1')return;button.dataset.kxBusy='1';button.disabled=true;try{await toggleSaved(item);if(button.isConnected)button.textContent=item.guardado?'Quitar de guardados':'Guardar';}finally{if(button.isConnected){button.disabled=false;delete button.dataset.kxBusy;}}});
  wrap.querySelector('#showcase-detail-share')?.addEventListener('click',()=>shareItem(item));wrap.querySelector('#showcase-detail-report')?.addEventListener('click',()=>reportShowcaseItem(item));
  wrap.querySelector('#showcase-provider-profile')?.addEventListener('click',()=>openKombaxPublicProfile(item.proveedor_social_id));
  if(commerce)void hydrateProductReviews(wrap,item);
}

function clubFoundersPromo(){
  return `<section class="kx-founders-promo club" aria-label="Clubes fundadores"><div class="kx-founders-promo-mark">${icon('dojo',{size:28})}</div><div><span>KOMBAX SHOWCASE · COMUNIDAD</span><strong>CLUBES FUNDADORES</strong><p>Presenta tu club, sus servicios y su identidad deportiva en KOMBAX Showcase junto a los primeros clubes verificados.</p><small>La verificación se solicita desde la identidad del club.</small></div></section>`;
}

function bindCatalog(){
  document.getElementById('showcase-search')?.addEventListener('click',()=>{currentQuery=document.getElementById('showcase-query')?.value||'';loadCatalog(false);});
  document.getElementById('showcase-query')?.addEventListener('keydown',e=>{if(e.key==='Enter'){currentQuery=e.currentTarget.value;loadCatalog(false);}});
  document.querySelectorAll('[data-showcase-category]').forEach(b=>b.addEventListener('click',()=>{currentCategory=b.dataset.showcaseCategory||'';loadCatalog(false);}));
  document.querySelectorAll('[data-showcase-detail]').forEach(card=>{const open=()=>{const item=items.find(x=>String(x.id)===String(card.dataset.showcaseDetail));if(item)openItem(item);};card.addEventListener('click',open);card.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();open();}});});
  document.querySelectorAll('[data-showcase-save]').forEach(b=>b.addEventListener('click',e=>{e.preventDefault();e.stopPropagation();const item=items.find(x=>String(x.id)===String(b.dataset.showcaseSave));if(item)toggleSaved(item);}));
  document.getElementById('showcase-more')?.addEventListener('click',()=>loadCatalog(true));
  document.getElementById('showcase-manage')?.addEventListener('click',()=>openPrivateShowcaseRoute());
  document.getElementById('showcase-saved')?.addEventListener('click',()=>{activeView='saved';renderSaved();});
  document.getElementById('showcase-cart')?.addEventListener('click',()=>openCart());
  document.getElementById('showcase-orders')?.addEventListener('click',()=>{activeView='orders';renderOrders();});
}

function renderCatalog(){
  const headActions=`<div class="row-actions">${hasPrivateClubShowcaseRoute()?'<button type="button" class="btn btn-showcase" id="showcase-manage">'+icon('shoppingBag',{size:17})+' Mi Showcase</button>':''}<button type="button" class="btn btn-showcase" id="showcase-cart">${cartBadgeHtml()}</button><button type="button" class="btn btn-ghost" id="showcase-orders">Mis pedidos</button><button type="button" class="btn btn-ghost" id="showcase-saved">${icon('bookmark',{size:17})} Guardados</button></div>`;
  setMainHtml(`<div class="kombax-showcase-page">${showcaseBrand()}${pageHeader(t('showcase.page.title'),t('showcase.page.subtitle'),headActions,'KOMBAX Showcase')}${clubFoundersPromo()}${controls()}${items.length?`<div class="showcase-grid">${items.map(cardHtml).join('')}</div>${done?'':`<button class="btn btn-ghost showcase-more" id="showcase-more">${t('showcase.actions.loadMore')}</button>`}`:empty(t('showcase.empty.catalogTitle'),t('showcase.empty.catalogBody'))}</div>`);bindCatalog();
  if(state.session)items.forEach(item=>repos.kombaxShowcase.track('product_impression',{provider_id:item?.marca_id||null,product_id:item?.id||null,source:'showcase_catalog'}).catch(()=>{}));
}

async function loadCatalog(append=false){
  if(!append){cursor=null;done=false;items=[];setMainHtml('<div class="loading-card">Cargando KOMBAX Showcase…</div>');}
  try{
    const rows=await repos.kombaxShowcase.list(currentQuery,currentCategory,cursor,PAGE_SIZE);
    const publicRows=rows.filter(item=>!isInternalShowcaseItem(item));
    items=append?[...items,...publicRows]:publicRows;const last=rows.at(-1);if(last)cursor={created:last.publicado_en,id:last.id};done=rows.length<PAGE_SIZE;renderCatalog();
    if(!append){
      let pending='';try{pending=sessionStorage.getItem('kombax_showcase_open_item')||'';}catch{}
      if(pending){const item=items.find(x=>String(x.id)===String(pending));if(item){try{sessionStorage.removeItem('kombax_showcase_open_item');}catch{};setTimeout(()=>openItem(item),0);}}
    }
  }catch(error){setError(error);setMainHtml(`${showcaseBrand()}${empty('Showcase no disponible',humanError(error)||'No se ha podido cargar el escaparate. Inténtalo de nuevo.')}`);}
}

async function renderSaved(){
  setMainHtml(`<div class="kombax-showcase-page">${showcaseBrand()}${pageHeader('Guardados','Tus fichas guardadas para consultarlas más tarde.',subviewActions({backId:'showcase-back-catalog',closeId:'showcase-close-catalog',backLabel:'Volver al escaparate'}),'KOMBAX Showcase')}<div id="showcase-saved-list"><div class="loading-card">Cargando guardados…</div></div></div>`);
  bindSubviewActions(document,{backId:'showcase-back-catalog',closeId:'showcase-close-catalog',onBack:()=>{activeView='catalog';loadCatalog(false);},onClose:()=>{activeView='catalog';loadCatalog(false);}});
  const box=document.getElementById('showcase-saved-list');
  try{
    const rows=await repos.kombaxShowcase.saved(100);
    box.innerHTML=rows.length?`<div class="showcase-saved-list">${rows.map(x=>`<article><div>${x.imagen_url?`<img ${mediaFrameAttrs(x.imagen_presentacion,"product")} src="${esc(safeExternal(x.imagen_url))}" alt="">`:icon('bookmark',{size:24})}</div><section><span class="page-kicker">${esc(x.marca_nombre)}</span><strong ${contentTranslationAttrs({contentId:x.id,contentType:'showcase_product_name',fieldName:'name',sourceLocale:x.source_locale||x.idioma||'',visibility:'public'})}>${esc(x.nombre)}</strong><p ${contentTranslationAttrs({contentId:x.id,contentType:'showcase_product_summary',fieldName:'summary',sourceLocale:x.source_locale||x.idioma||'',visibility:'public'})}>${esc(x.resumen||'')}</p><small>Guardado ${dtFmt(x.guardado_en)}</small></section><button class="btn btn-ghost btn-sm" data-saved-remove="${esc(x.id)}">Quitar</button></article>`).join('')}</div>`:empty('Sin guardados','Guarda una ficha para encontrarla rápidamente aquí.');
    box.querySelectorAll('[data-saved-remove]').forEach(b=>b.addEventListener('click',async()=>{await repos.kombaxShowcase.toggleSaved(b.dataset.savedRemove,false);toast('Eliminado de guardados');await renderSaved();}));
  }catch(error){box.innerHTML=empty('No se pudieron cargar tus guardados',humanError(error)||'Inténtalo de nuevo.');}
}

async function renderOrders(){
  setMainHtml(`<div class="kombax-showcase-page">${showcaseBrand()}${pageHeader('Mis pedidos','Tus compras de KOMBAX Showcase en un único espacio: pago, preparación, envío, entrega e incidencias. El vendedor actualiza la preparación, el envío y la entrega.',subviewActions({backId:'showcase-orders-back',closeId:'showcase-orders-close',backLabel:'Volver al escaparate'}),'KOMBAX Showcase')}<div id="showcase-orders-list"><div class="loading-card">Cargando pedidos…</div></div></div>`);
  bindSubviewActions(document,{backId:'showcase-orders-back',closeId:'showcase-orders-close',onBack:()=>{activeView='catalog';loadCatalog(false);},onClose:()=>{activeView='catalog';loadCatalog(false);}});
  const box=document.getElementById('showcase-orders-list');
  try{
    const [rows,trust]=await Promise.all([repos.payments.myOrders(),repos.marketplace.buyerTrust().catch(()=>null)]);let current='all';
    const paint=()=>{const filtered=current==='all'?rows:rows.filter(o=>String(o.status)===current);const counts=Object.fromEntries(Object.keys(ORDER_STATUS).map(k=>[k,rows.filter(o=>o.status===k).length]));box.innerHTML=`${trust?buyerTrustHtml(trust):''}<div class="alert kx-market-order-responsibility"><strong>Seguimiento gestionado por el vendedor</strong><span>Después del pago, el vendedor es responsable de actualizar preparación, envío, seguimiento y entrega. Cada cambio queda registrado en el historial del pedido.</span></div><div class="showcase-order-toolbar"><button type="button" class="${current==='all'?'active':''}" data-order-filter="all">Todos <b>${rows.length}</b></button><button type="button" class="${current==='payment_confirmed'?'active':''}" data-order-filter="payment_confirmed">Pagados <b>${counts.payment_confirmed||0}</b></button><button type="button" class="${current==='preparing'?'active':''}" data-order-filter="preparing">Preparando <b>${counts.preparing||0}</b></button><button type="button" class="${current==='shipped'?'active':''}" data-order-filter="shipped">Enviados <b>${counts.shipped||0}</b></button><button type="button" class="${current==='delivered'?'active':''}" data-order-filter="delivered">Entregados <b>${counts.delivered||0}</b></button></div>${filtered.length?`<div class="showcase-order-portal">${filtered.map(o=>{const meta=orderMeta(o.status);return `<article class="showcase-order-card is-${esc(meta.tone)}"><header><div><span class="page-kicker">${esc(o.order_number)}</span><strong>${esc(orderItemsLabel(o))}</strong><small>Vendido por ${esc(o.seller||'KOMBAX Showcase')} · ${dtFmt(o.created_at)}</small></div><div class="showcase-order-total"><b>${money(o.amount_total)}</b><span>${esc(meta.label)}</span></div></header>${orderProgress(o.status)}${o.status_source==='seller'&&o.status_updated_at?`<div class="kx-order-last-update">Actualizado por el vendedor · ${dtFmt(o.status_updated_at)}</div>`:''}${o.tracking_number?`<div class="showcase-order-shipping"><strong>${icon('package',{size:15})} Seguimiento del envío</strong><span>${esc(o.carrier||'Transportista')} · ${esc(o.tracking_number)}</span>${safeExternal(o.tracking_url)?`<a href="${esc(o.tracking_url)}" target="_blank" rel="noopener noreferrer">Seguir envío</a>`:''}</div>`:''}<details><summary>Historial del pedido</summary><div class="showcase-order-history">${(o.history||[]).map(h=>`<span><i></i><b>${esc(orderMeta(h.to_status).label)}</b><small>${dtFmt(h.created_at)}</small></span>`).join('')||'<small>Sin movimientos adicionales.</small>'}</div></details>${!['cancelled','refunded'].includes(o.status)?`<footer><button class="btn btn-ghost btn-sm" data-order-incident="${esc(o.id)}">Tengo un problema</button></footer>`:''}</article>`;}).join('')}</div>`:empty('Sin pedidos en este estado',rows.length?'Cambia el filtro para consultar el resto de compras.':'Tus compras aparecerán aquí.')}`;box.querySelectorAll('[data-order-filter]').forEach(b=>b.addEventListener('click',()=>{current=b.dataset.orderFilter;paint();}));box.querySelectorAll('[data-order-incident]').forEach(b=>b.addEventListener('click',()=>openForm({title:'Tengo un problema con mi pedido',subtitle:'La incidencia queda vinculada al pedido y al vendedor.',fields:[{name:'message',label:'Describe el problema',type:'textarea',required:true,full:true,minLength:3,maxLength:4000}],submitText:'Abrir incidencia',onSubmit:async v=>{await repos.payments.orderMutate('showcase.incident.open',{order_id:b.dataset.orderIncident,message:v.message});toast('Incidencia abierta');await renderOrders();}})));box.querySelector('#buyer-identity-verify')?.addEventListener('click',()=>openBuyerIdentityVerification(renderOrders));};paint();
  }catch(error){box.innerHTML=empty('No se pudieron cargar los pedidos',humanError(error));}
}

function itemEditor(brand,item=null,{commerceAllowed=true,sellerAccountActive=true}={}){
  const gallery=Array.isArray(item?.galeria)?item.galeria:[];
  const commerceLocked=!commerceAllowed;
  const checkoutLocked=commerceLocked||!sellerAccountActive;
  const professional=isProfessionalProvider(brand),initialKind=professional?'professional_service':(item?.listing_kind||'product');
  const commonFields=[
    {name:'nombre',label:initialKind==='professional_service'?'Nombre del servicio':'Nombre',required:true,full:true},
    {name:'slug',label:'Identificador',value:item?.slug||'',help:'Opcional. Si lo dejas vacío, se genera automáticamente a partir del nombre.'},
    {name:'listing_kind',label:'Tipo de ficha',type:'select',value:initialKind,options:professional?[{value:'professional_service',label:'Servicio profesional · contacto'}]:[{value:'product',label:'Producto · marketplace'},{value:'professional_service',label:'Servicio profesional · contacto'}],help:professional?'Los perfiles profesionales publican servicios sin checkout de producto.':'Los productos pueden activar compra directa; los servicios se publican para contacto.'},
    {name:'categoria_id',label:'Categoría',type:'select',options:categories.map(c=>({value:c.id,label:c.nombre})),value:item?.categoria_id||''},
    {name:'product_type',label:initialKind==='professional_service'?'Tipo de servicio':'Tipo de producto',value:item?.product_type||'',maxLength:80,help:'Clasificación interna para catálogo y estadísticas.'},
    {name:'resumen',label:'Resumen',type:'textarea',rows:3,maxLength:320,full:true},
    {name:'descripcion',label:'Descripción completa',type:'textarea',rows:6,maxLength:3000,full:true},
    {name:'imagen_archivo',label:'Subir imagen principal',type:'file',accept:'image/jpeg,image/png,image/webp,image/heic,image/heif,image/avif',full:true,help:'JPG, PNG, WEBP o foto HEIC/HEIF/AVIF del móvil. KOMBAX optimiza la imagen antes de publicarla.'},
    {name:'imagen_url',label:'O usar imagen principal HTTPS',type:'url',full:true},
    {name:'quitar_imagen',label:'Eliminar imagen principal actual',type:'checkbox',value:false,full:true,help:'Si eliminas o sustituyes una imagen subida a KOMBAX, su archivo anterior también se limpia del almacenamiento.'},
    {name:'galeria_archivo_1',label:'Subir imagen adicional 1',type:'file',accept:'image/jpeg,image/png,image/webp,image/heic,image/heif,image/avif'},
    {name:'galeria_1',label:'O URL adicional 1 HTTPS',type:'url',value:gallery[0]||''},
    {name:'galeria_archivo_2',label:'Subir imagen adicional 2',type:'file',accept:'image/jpeg,image/png,image/webp,image/heic,image/heif,image/avif'},
    {name:'galeria_2',label:'O URL adicional 2 HTTPS',type:'url',value:gallery[1]||''},
    {name:'galeria_archivo_3',label:'Subir imagen adicional 3',type:'file',accept:'image/jpeg,image/png,image/webp,image/heic,image/heif,image/avif'},
    {name:'galeria_3',label:'O URL adicional 3 HTTPS',type:'url',value:gallery[2]||''},
    {name:'precio_orientativo',label:'Precio orientativo opcional',type:'number',min:0,step:'0.01'},
  ];
  const productFields=professional?[]:[
    {name:'sku',label:'SKU / referencia',value:item?.sku||'',maxLength:80,help:'Opcional. Ayuda a clasificar y controlar inventario.'},
    {name:'stock_alert_threshold',label:'Avisar de stock bajo a partir de',type:'number',min:0,step:'1',value:item?.stock_alert_threshold??3},
    {name:'commerce_enabled',label:'Activar venta directa en KOMBAX',type:'checkbox',value:item?.commerce_enabled===true&&!checkoutLocked,disabled:checkoutLocked,full:true,help:commerceLocked?'Tu Showcase y tu cuenta de vendedor siguen activos. Para cobrar y recibir pedidos activa Commerce desde Mi Showcase.':!sellerAccountActive?'Commerce está disponible en tu plan, pero primero debes activar la cuenta de vendedor: verificación, condiciones y Stripe Connect.':'Venta directa disponible: requiere mantener la cuenta de vendedor activa.'},
    {name:'precio_venta',label:'Precio de venta',type:'number',min:0,step:'0.01',value:item?.precio_venta??'',disabled:commerceLocked,help:commerceLocked?'Disponible al activar Commerce. El precio orientativo de la ficha sí puede seguir mostrándose.':''},
    {name:'stock',label:'Stock disponible',type:'number',min:0,step:'1',value:item?.stock??'',disabled:commerceLocked,help:commerceLocked?'El inventario operativo se habilita con Commerce.':''},
    {name:'fulfillment',label:'Entrega',type:'select',value:item?.fulfillment||'seller_shipping',disabled:commerceLocked,options:[{value:'seller_shipping',label:'Envío por el vendedor'},{value:'seller_pickup',label:'Recogida'},{value:'seller_shipping_or_pickup',label:'Envío o recogida'},{value:'digital',label:'Entrega digital'}]},
    {name:'shipping_policy',label:'Política de envío o recogida',type:'textarea',full:true,maxLength:2000,disabled:commerceLocked},
    {name:'returns_policy',label:'Política de devolución',type:'textarea',full:true,maxLength:2000,disabled:commerceLocked},
    {name:'manufacturer_name',label:'Fabricante',value:item?.manufacturer_name||'',maxLength:240,help:'Cuando corresponda al tipo de producto.'},
    {name:'manufacturer_contact',label:'Contacto del fabricante',value:item?.manufacturer_contact||'',maxLength:500},
    {name:'eu_responsible_person',label:'Responsable en la UE',value:item?.eu_responsible_person||'',maxLength:500,help:'Solo cuando sea exigible, por ejemplo para determinados productos de fabricante fuera de la UE.'},
    {name:'model_reference',label:'Modelo / referencia',value:item?.model_reference||'',maxLength:160},
    {name:'product_identifier',label:'Identificador del producto',value:item?.product_identifier||'',maxLength:160},
    {name:'safety_warnings',label:'Advertencias e información de seguridad',type:'textarea',full:true,maxLength:3000},
    {name:'safety_information_url',label:'Información de seguridad (HTTPS)',type:'url',full:true,value:item?.safety_information_url||''},
    {name:'ce_marking_applicable',label:'El marcado CE aplica legalmente a este producto',type:'checkbox',value:item?.ce_marking_applicable===true,full:true,help:'No marques esta opción por defecto: el CE no aplica universalmente.'},
    {name:'ce_marking_declared',label:'Marcado CE declarado / documentado',type:'checkbox',value:item?.ce_marking_declared===true,full:true},
    {name:'safety_status',label:'Estado de seguridad',type:'select',value:item?.safety_status||'allowed',options:[{value:'allowed',label:'Permitido'},{value:'restricted',label:'Restringido'},{value:'requires_review',label:'Requiere revisión'}]}
  ];
  const tailFields=[
    {name:'cta_tipo',label:'Acción principal',type:'select',value:professional?'contact':(item?.cta_tipo||'info'),options:professional?[{value:'contact',label:t(CTA_KEYS.contact)}]:Object.entries(CTA_KEYS).map(([value,key])=>({value,label:t(key)}))},
    {name:'cta_label',label:'Texto personalizado de la acción',maxLength:80,value:item?.cta_label||'',help:'Opcional. Si queda vacío se usa el texto estándar.'},
    {name:'visitar_url',label:'Tienda o web (HTTPS)',type:'url',full:true},
    {name:'donde_encontrar_url',label:'Dónde encontrar (HTTPS)',type:'url',full:true},
    {name:'contacto_url',label:'Contacto externo (HTTPS)',type:'url',full:true}
  ];
  openForm({
    title:item?'Editar ficha de Showcase':'Nueva ficha de Showcase',
    subtitle:`${brand.nombre} · ${PROVIDER_LABELS[brand.sujeto_tipo]||'Perfil'} · ${professional?'servicios profesionales sin checkout':LIMIT_LABELS[Number(brand.limite_visible||30)]||`máximo ${Number(brand.limite_visible||30)}`} `,
    width:'860px',initial:{...(item||{}),listing_kind:initialKind,quitar_imagen:false},fields:[...commonFields,...productFields,...tailFields],submitText:'Guardar borrador',
    onSubmit:async v=>{
      const uploaded=[],oldUrls=[item?.imagen_url,...gallery].filter(Boolean);
      try{
        const service=professional||String(v.listing_kind)==='professional_service';
        let imagen=v.quitar_imagen?'':String(v.imagen_url??item?.imagen_url??'').trim();
        if(v.imagen_archivo){const out=await repos.kombaxShowcase.uploadImage(brand.id,v.imagen_archivo);uploaded.push(out.path);imagen=out.url;}
        if(imagen&&!safeExternal(imagen))throw new Error('La imagen principal debe ser una subida válida o una URL HTTPS.');
        const galeria=[];
        for(let i=1;i<=3;i++){
          const file=v[`galeria_archivo_${i}`];let url=String(v[`galeria_${i}`]??gallery[i-1]??'').trim();
          if(file){const out=await repos.kombaxShowcase.uploadImage(brand.id,file);uploaded.push(out.path);url=out.url;}
          if(url){if(!safeExternal(url))throw new Error(`La imagen adicional ${i} debe usar una URL HTTPS válida.`);galeria.push(url);}
        }
        const ctaTipo=service?'contact':v.cta_tipo;
        const required=ctaTipo==='where'?v.donde_encontrar_url:(ctaTipo==='shop'||ctaTipo==='web'?v.visitar_url:'');
        if(required&&!safeExternal(required))throw new Error('La acción principal seleccionada necesita una URL HTTPS válida.');
        const saved=await repos.kombaxShowcase.saveItem({...v,id:item?.id||null,marca_id:brand.id,slug:v.slug||slugify(v.nombre),imagen_url:imagen,galeria,moneda:'EUR',cta_tipo:ctaTipo});
        const savedId=saved?.id||item?.id;
        if(savedId){
          await repos.kombaxShowcase.saveListingMeta(savedId,{listing_kind:service?'professional_service':'product',product_type:v.product_type||null,sku:service?null:(v.sku||null),stock_alert_threshold:service?0:Number(v.stock_alert_threshold??3)});
          const directCommerce=service?false:(checkoutLocked?false:v.commerce_enabled===true);
          await repos.kombaxShowcase.saveCommerce(savedId,{commerce_enabled:directCommerce,precio_venta:service?null:(commerceLocked?(item?.precio_venta??null):(v.precio_venta===''?null:Number(v.precio_venta))),stock:service?null:(commerceLocked?(item?.stock??null):(v.stock===''?null:Number(v.stock))),variantes:service?[]:(item?.variantes||[]),fulfillment:service?'digital':(commerceLocked?(item?.fulfillment||'seller_shipping'):v.fulfillment),shipping_policy:service?null:(commerceLocked?(item?.shipping_policy||null):(v.shipping_policy||null)),returns_policy:service?null:(commerceLocked?(item?.returns_policy||null):(v.returns_policy||null)),manufacturer_name:service?null:(v.manufacturer_name||null),manufacturer_contact:service?null:(v.manufacturer_contact||null),eu_responsible_person:service?null:(v.eu_responsible_person||null),model_reference:service?null:(v.model_reference||null),product_identifier:service?null:(v.product_identifier||null),safety_warnings:service?null:(v.safety_warnings||null),safety_information_url:service?null:(v.safety_information_url||null),ce_marking_applicable:service?false:v.ce_marking_applicable===true,ce_marking_declared:service?false:v.ce_marking_declared===true,safety_status:service?'allowed':(v.safety_status||'allowed')});
        }
        if(savedId){void Promise.all([prewarmUserContentTranslations({contentId:savedId,contentType:'showcase_product_name',fieldName:'name',text:v.nombre||'',visibility:'public'}),prewarmUserContentTranslations({contentId:savedId,contentType:'showcase_product_summary',fieldName:'summary',text:v.resumen||'',visibility:'public'}),prewarmUserContentTranslations({contentId:savedId,contentType:'showcase_product_description',fieldName:'description',text:v.descripcion||'',visibility:'public'})]);}
        const retained=new Set([imagen,...galeria].filter(Boolean));
        await repos.kombaxShowcase.removeOwnedImages(oldUrls.filter(u=>!retained.has(u))).catch(()=>{});
        toast(service?'Servicio guardado. Se publicará como ficha de contacto, sin checkout.':'Producto guardado. Pulsa Publicar para hacerlo visible en Marketplace.');await renderManagement(brand.id);
      }catch(error){for(const path of uploaded)await repos.kombaxShowcase.removeUploadedImage(path).catch(()=>{});throw error;}
    }
  });
}

async function openSellerOrders(brand){
  try{
    const rows=await repos.payments.sellerOrders(brand.id);let current='open';let modal;
    const group=o=>['delivered','cancelled','refunded'].includes(o.status)?'closed':o.status==='incident'?'incident':'open';
    const body=()=>{const filtered=current==='all'?rows:current==='open'?rows.filter(o=>group(o)==='open'):current==='incident'?rows.filter(o=>o.status==='incident'):rows.filter(o=>o.status===current);const count=k=>k==='open'?rows.filter(o=>group(o)==='open').length:k==='all'?rows.length:rows.filter(o=>o.status===k).length;return `<div class="showcase-seller-orders"><div class="alert kx-market-order-responsibility"><strong>Responsabilidad del vendedor</strong><span>Debes mantener actualizado cada pedido: iniciar preparación, informar el envío y confirmar la entrega/recogida. El comprador ve estos cambios en Mis pedidos.</span></div><div class="showcase-order-toolbar"><button data-seller-filter="open" class="${current==='open'?'active':''}">Pendientes <b>${count('open')}</b></button><button data-seller-filter="payment_confirmed" class="${current==='payment_confirmed'?'active':''}">Pagados <b>${count('payment_confirmed')}</b></button><button data-seller-filter="preparing" class="${current==='preparing'?'active':''}">Preparando <b>${count('preparing')}</b></button><button data-seller-filter="shipped" class="${current==='shipped'?'active':''}">Enviados <b>${count('shipped')}</b></button><button data-seller-filter="incident" class="${current==='incident'?'active':''}">Incidencias <b>${count('incident')}</b></button><button data-seller-filter="all" class="${current==='all'?'active':''}">Todos <b>${rows.length}</b></button></div>${filtered.length?`<div class="showcase-order-portal seller">${filtered.map(o=>{const meta=orderMeta(o.status),address=shippingLine(o);return `<article class="showcase-order-card is-${esc(meta.tone)}"><header><div><span class="page-kicker">${esc(o.order_number)}</span><strong>${esc(orderItemsLabel(o))}</strong><small>${esc(o.buyer_email||'Comprador KOMBAX')} · ${dtFmt(o.created_at)}</small></div><div class="showcase-order-total"><b>${money(o.amount_total)}</b><span>${esc(meta.label)}</span></div></header>${orderProgress(o.status)}${(o.shipping_name||address)?`<div class="showcase-order-address"><strong>${icon('mapPin',{size:15})} Entrega</strong><span>${esc(o.shipping_name||'Destinatario')}${o.shipping_phone?` · ${esc(o.shipping_phone)}`:''}</span>${address?`<small>${esc(address)}</small>`:''}</div>`:''}${o.status_source==='seller'&&o.status_updated_at?`<div class="kx-order-last-update">Actualizado por el vendedor · ${dtFmt(o.status_updated_at)}</div>`:''}${o.tracking_number?`<div class="showcase-order-shipping"><strong>Seguimiento</strong><span>${esc(o.carrier||'Transportista')} · ${esc(o.tracking_number)}</span>${safeExternal(o.tracking_url)?`<a href="${esc(o.tracking_url)}" target="_blank" rel="noopener noreferrer">Abrir seguimiento</a>`:''}</div>`:''}<details><summary>Historial</summary><div class="showcase-order-history">${(o.history||[]).map(h=>`<span><i></i><b>${esc(orderMeta(h.to_status).label)}</b><small>${dtFmt(h.created_at)}</small></span>`).join('')}</div></details><footer class="row-actions">${o.status==='payment_confirmed'?`<button class="btn btn-primary btn-sm" data-order-status="preparing" data-order-id="${esc(o.id)}">Empezar preparación</button>`:''}${o.status==='preparing'?`<button class="btn btn-primary btn-sm" data-order-ship="${esc(o.id)}">Marcar enviado</button><button class="btn btn-ghost btn-sm" data-order-status="delivered" data-order-id="${esc(o.id)}">Entregado / recogido</button>`:''}${o.status==='shipped'?`<button class="btn btn-primary btn-sm" data-order-status="delivered" data-order-id="${esc(o.id)}">Confirmar entrega</button>`:''}${['payment_confirmed','preparing','shipped','delivered'].includes(o.status)?`<button class="btn btn-ghost btn-sm" data-order-refund="${esc(o.id)}">Reembolsar</button>`:''}</footer></article>`;}).join('')}</div>`:empty('Sin pedidos en este estado','Los nuevos pedidos aparecerán aquí tras confirmarse el pago.')}</div>`;};
    const bindModal=()=>{modal.wrap.querySelectorAll('[data-seller-filter]').forEach(b=>b.addEventListener('click',()=>{current=b.dataset.sellerFilter;modal.wrap.querySelector('.detail-modal-body').innerHTML=body();bindModal();}));modal.wrap.querySelectorAll('[data-order-status]').forEach(b=>b.addEventListener('click',async()=>{b.disabled=true;try{await repos.payments.orderMutate('showcase.order.status',{order_id:b.dataset.orderId,status:b.dataset.orderStatus});toast('Pedido actualizado');modal.close();await openSellerOrders(brand);}catch(error){b.disabled=false;setError(error);}}));modal.wrap.querySelectorAll('[data-order-refund]').forEach(b=>b.addEventListener('click',()=>{const order=rows.find(x=>String(x.id)===String(b.dataset.orderRefund));if(order)openSellerRefund(brand,order,()=>{modal.close();setTimeout(()=>openSellerOrders(brand),80);});}));modal.wrap.querySelectorAll('[data-order-ship]').forEach(b=>b.addEventListener('click',()=>openForm({title:'Marcar pedido como enviado',subtitle:'El comprador verá estos datos en Mis pedidos.',fields:[{name:'carrier',label:'Transportista',required:true},{name:'tracking_number',label:'Número de seguimiento',required:true},{name:'tracking_url',label:'URL de seguimiento',type:'url'}],submitText:'Guardar envío',onSubmit:async v=>{await repos.payments.orderMutate('showcase.order.status',{order_id:b.dataset.orderShip,status:'shipped',...v});toast('Envío guardado');modal.close();await openSellerOrders(brand);}})));};
    modal=openDetail({title:'Pedidos del vendedor',subtitle:`${brand.nombre} · preparación, envío y entrega`,width:'1040px',className:'showcase-seller-order-modal',body:body()});bindModal();
  }catch(error){setError(error);}
}

async function openSellerDashboard(brand){
  try{
    const data=await repos.kombaxShowcase.sellerDashboard(brand.id),stats=data?.stats||{},inventory=Array.isArray(data?.inventory)?data.inventory:[],top=Array.isArray(data?.top_products)?data.top_products:[],byType=Array.isArray(data?.by_type)?data.by_type:[];
    const kpi=(label,value,help='')=>`<article><small>${esc(label)}</small><strong>${esc(String(value??0))}</strong>${help?`<span>${esc(help)}</span>`:''}</article>`;
    const modal=openDetail({title:'Showcase · Inventario y estadísticas',subtitle:`${brand.nombre} · ${PROVIDER_LABELS[brand.sujeto_tipo]||'Proveedor'}`,width:'1100px',className:'kx-seller-dashboard-modal',body:`<div class="kx-seller-dashboard-grid">${kpi('Productos',stats.products||0)}${kpi('Servicios',stats.services||0)}${kpi('Stock total',stats.stock_units||0)}${kpi('Stock bajo',stats.low_stock||0)}${kpi('Sin stock',stats.out_of_stock||0)}${kpi('Productos vendidos',stats.sold_products||0)}${kpi('Sin ventas',stats.unsold_products||0)}${kpi('Unidades vendidas',stats.units_sold||0)}${kpi('Pedidos',stats.orders||0)}${kpi('GMV producto',money((Number(stats.product_gmv_minor)||0)/100),'Volumen bruto vendido; no es ingreso KOMBAX.')}</div>
      <section class="kx-seller-dashboard-section"><h4>Inventario y catálogo</h4>${inventory.length?`<div class="kx-seller-inventory">${inventory.map(row=>`<article><div><span class="page-kicker">${row.listing_kind==='professional_service'?'SERVICIO':'PRODUCTO'}${row.product_type?` · ${esc(row.product_type)}`:''}</span><strong>${esc(row.name)}</strong><small>${row.sku?`SKU ${esc(row.sku)} · `:''}${row.listing_kind==='professional_service'?'Sin stock/checkout':`${stockStatusLabel(row.stock_status)} · ${row.stock==null?'sin control':`${Number(row.stock)} uds.`}`} · ${row.sold?'Vendido':'Sin ventas'}</small>${row.listing_kind!=='professional_service'?`<button type="button" class="btn btn-ghost btn-sm" data-stock-adjust="${esc(row.id)}">Ajustar stock</button>`:''}</div><div><b>${Number(row.units_sold||0)} uds.</b><small>${Number(row.orders||0)} pedidos · ${money((Number(row.gmv_minor)||0)/100)}</small></div></article>`).join('')}</div>`:empty('Sin fichas','Crea productos o servicios para empezar a medir el catálogo.')}</section>
      <section class="kx-seller-dashboard-section"><h4>Clasificación</h4><div class="kx-seller-type-chips">${byType.length?byType.map(x=>`<span>${esc(x.type)} <b>${Number(x.count||0)}</b></span>`).join(''):'<span>Sin productos clasificados</span>'}</div></section>
      <section class="kx-seller-dashboard-section"><h4>Productos más vendidos</h4>${top.length?`<div class="kx-seller-top">${top.map((x,i)=>`<article><b>#${i+1}</b><div><strong>${esc(x.name)}</strong><small>${Number(x.units_sold||0)} unidades · ${Number(x.orders||0)} pedidos · ${money((Number(x.gmv_minor)||0)/100)}</small></div></article>`).join('')}</div>`:'<p class="muted">Todavía no hay ventas confirmadas.</p>'}</section>`});
    modal.wrap.querySelectorAll('[data-stock-adjust]').forEach(button=>button.addEventListener('click',()=>{const row=inventory.find(x=>String(x.id)===String(button.dataset.stockAdjust));if(row)openStockAdjustment(brand,row,()=>{modal.close();setTimeout(()=>openSellerDashboard(brand),80);});}));
  }catch(error){setError(error);toast(humanError(error)||'No se pudieron cargar las estadísticas.','error');}
}



async function openSellerRefund(brand,order,onDone=()=>{}){
  const item=(Array.isArray(order?.items)?order.items:[])[0]||{};
  const maxAmount=Math.max(0,Number(order?.amount_total||0));
  openForm({title:`Reembolsar · ${order?.order_number||'Pedido'}`,subtitle:'El vendedor decide la devolución comercial. KOMBAX ejecuta el reembolso sobre su cuenta Stripe Connect y conserva la trazabilidad.',width:'680px',submitText:'Procesar reembolso',fields:[
    {name:'amount',label:'Importe a reembolsar (€)',type:'number',required:true,min:'0.01',max:String(maxAmount||0.01),step:'0.01',value:maxAmount.toFixed(2),help:'Puede ser total o parcial.'},
    {name:'reason',label:'Motivo',type:'textarea',required:true,full:true,rows:3,maxLength:500,value:'Devolución gestionada por el vendedor'},
    {name:'restock',label:'Reintegrar unidades recuperadas al stock',type:'checkbox',value:false,full:true,help:'Un reembolso no repone stock automáticamente.'},
    {name:'restock_quantity',label:'Unidades recuperadas',type:'number',min:'0',max:String(Number(item.quantity||1)),step:'1',value:0,help:`Máximo ${Number(item.quantity||1)} unidad(es) de este pedido.`}
  ],onSubmit:async v=>{
    const amountMinor=Math.round(Number(v.amount||0)*100);if(amountMinor<1)throw new Error('Indica un importe válido.');
    const out=await repos.payments.refund({scope:'showcase',order_id:order.id,amount_minor:amountMinor,reason:v.reason||'',restock:v.restock===true,restock_quantity:v.restock===true?Number(v.restock_quantity||0):0});
    toast(`Reembolso procesado${out?.amount_minor?` · ${money(Number(out.amount_minor)/100)}`:''}.`);onDone(out);
  }});
}

async function openSellerFinance(brand){
  try{
    const [finance,stripe]=await Promise.all([repos.kombaxShowcase.finance(brand.id),repos.payments.accountFinance('showcase',brand.id).catch(()=>null)]);
    const minor=v=>money((Number(v)||0)/100);const available=(stripe?.balance?.available||[]).map(x=>`${minor(x.amount)} ${x.currency||''}`).join(' · ')||'—';const pending=(stripe?.balance?.pending||[]).map(x=>`${minor(x.amount)} ${x.currency||''}`).join(' · ')||'—';
    const refunds=Array.isArray(finance?.recent_refunds)?finance.recent_refunds:[];const payouts=Array.isArray(stripe?.payouts)?stripe.payouts:[];
    const modal=openDetail({title:'Showcase · Centro financiero',subtitle:`${brand.nombre} · ventas, comisiones, reembolsos y liquidaciones Stripe`,width:'1040px',className:'kx-finance-center-modal',actions:`<button type="button" class="btn btn-ghost" id="kx-showcase-finance-context-r84">${esc(t('prepilot.financeContext'))}</button>`,body:`<div class="kx-finance-kpis"><article><small>VENTA BRUTA</small><strong>${minor(finance?.gross_minor)}</strong><span>Valor facial vendido</span></article><article><small>REEMBOLSOS AL COMPRADOR</small><strong>${minor(finance?.buyer_refunds_minor)}</strong><span>Totales + parciales</span></article><article><small>COMISIÓN KOMBAX RETENIDA</small><strong>${minor(finance?.platform_fee_minor)}</strong><span>Tras reembolsos proporcionales</span></article><article><small>NETO ESTIMADO VENDEDOR</small><strong>${minor(finance?.estimated_seller_net_before_stripe_minor)}</strong><span>Antes de costes de procesamiento Stripe</span></article><article><small>SALDO DISPONIBLE STRIPE</small><strong>${esc(available)}</strong><span>Cuenta conectada</span></article><article><small>SALDO PENDIENTE STRIPE</small><strong>${esc(pending)}</strong><span>Pendiente de disponibilidad</span></article></div><div class="alert"><strong>Conciliación</strong><span>${esc(finance?.note||'KOMBAX muestra la operación del marketplace; Stripe mantiene el saldo y los payouts reales de la cuenta conectada.')}</span></div><section class="kx-finance-section"><h4>Reembolsos recientes</h4>${refunds.length?`<div class="kx-finance-ledger">${refunds.map(r=>`<article><div><strong>${esc(String(r.showcase_order_id||''))}</strong><small>${dtFmt(r.created_at)} · ${esc(r.status||'')}</small></div><b>${minor(r.amount_succeeded_minor)}</b></article>`).join('')}</div>`:'<p class="muted">Aún no hay reembolsos registrados en R65.</p>'}</section><section class="kx-finance-section"><h4>Últimos payouts de Stripe</h4>${payouts.length?`<div class="kx-finance-ledger">${payouts.map(x=>`<article><div><strong>${esc(x.status||'payout')}</strong><small>${x.arrival_date?new Date(Number(x.arrival_date)*1000).toLocaleDateString(kxLocaleTag(kxGetLocale())):'Fecha por confirmar'}</small></div><b>${minor(x.amount)} ${esc(x.currency||'')}</b></article>`).join('')}</div>`:'<p class="muted">Sin payouts disponibles o Stripe aún no está conectado.</p>'}</section>`});
    modal.wrap.querySelector('#kx-showcase-finance-context-r84')?.addEventListener('click',()=>openFinanceContext({subjectType:'showcase_provider',subjectId:brand.id,title:`${t('prepilot.financeContext')} · ${brand.nombre}`}));
  }catch(error){setError(error);toast(humanError(error)||'No se pudo abrir el Centro financiero.','error');}
}

async function openSellerCommunications(brand){
  try{const rows=await repos.kombaxShowcase.communications(brand.id,120);openDetail({title:'Showcase · Comunicaciones',subtitle:`${brand.nombre} · mensajes transaccionales automáticos`,width:'900px',body:Array.isArray(rows)&&rows.length?`<div class="kx-commerce-comms">${rows.map(x=>`<article><div><span class="page-kicker">${esc(x.template_code||'OPERACIÓN')}</span><strong>${esc(x.subject||'Actualización')}</strong><p>${esc(x.body_text||'')}</p><small>${esc(x.recipient_email||'Comprador KOMBAX')} · ${dtFmt(x.created_at)}</small></div><b class="kx-comm-status ${esc(x.status||'queued')}">${esc(x.status||'queued')}</b></article>`).join('')}</div>`:empty('Sin comunicaciones todavía','Aquí aparecerán confirmaciones de pago, preparación, envío, entrega y reembolsos.')});}catch(error){setError(error);}
}

async function openShowcaseReports(brand,period=30){
  return openReportsCenter({scope:'showcase',entity:{...brand,name:brand.nombre},period,generate:(type,range)=>repos.kombaxShowcase.report(brand.id,type,range)});
}

async function openShowcaseAnalytics(brand,period=30){
  try{
    const range=period&&typeof period==='object'&&period.from&&period.to?period:null;
    const data=range?await repos.kombaxShowcase.analyticsRange(brand.id,range.from,range.to):await repos.kombaxShowcase.analytics(brand.id,period);
    return openPremiumAnalytics({scope:'showcase',entity:{...brand,name:brand.nombre},data,period:range||period,onReload:next=>openShowcaseAnalytics(brand,next),onReports:current=>openShowcaseReports(brand,current||range||period)});
  }catch(error){setError(error);toast(humanError(error)||t('common.analytics.loadError'),'error');}
}

async function openSellerBI(brand){
  try{const data=await repos.kombaxShowcase.businessIntelligence(brand.id,30);if(data?.locked){openDetail({title:'Business Intelligence · Enterprise',subtitle:'Analítica avanzada de Showcase',body:`<div class="empty-state"><h2>Disponible en Enterprise</h2><p>Tu plan actual es ${esc(data.plan_code||'estándar')}. La operación diaria mantiene sus estadísticas básicas; Enterprise añade embudo, conversión y atribución.</p></div>`});return;}const pct=v=>v==null?'—':`${Number(v).toLocaleString(kxLocaleTag(kxGetLocale()),{maximumFractionDigits:2})} %`;openDetail({title:'Business Intelligence · Showcase',subtitle:`${brand.nombre} · últimos ${Number(data.days||30)} días`,width:'1000px',body:`<div class="kx-bi-funnel"><article><small>IMPRESIONES</small><strong>${Number(data.impressions||0)}</strong></article><article><small>VISITAS</small><strong>${Number(data.views||0)}</strong></article><article><small>INTERÉS</small><strong>${Number(data.interest||0)}</strong></article><article><small>CHECKOUT</small><strong>${Number(data.checkout_starts||0)}</strong></article><article><small>COMPRAS</small><strong>${Number(data.purchases||0)}</strong></article><article><small>CONVERSIÓN</small><strong>${pct(data.conversion_percent)}</strong></article></div><section class="kx-finance-section"><h4>Ingresos atribuidos</h4><strong class="kx-bi-revenue">${money((Number(data.revenue_minor)||0)/100)}</strong></section>`});}catch(error){setError(error);}
}

function openStockAdjustment(brand,row,onDone=()=>{}){
  openForm({title:`Ajustar stock · ${row?.name||'Producto'}`,subtitle:'El ajuste queda registrado en el ledger de inventario.',fields:[{name:'stock',label:'Nuevo stock',type:'number',required:true,min:'0',step:'1',value:Number(row?.stock||0)},{name:'note',label:'Motivo / nota',type:'textarea',full:true,rows:3,maxLength:500}],submitText:'Guardar stock',onSubmit:async v=>{await repos.kombaxShowcase.stockAdjust(row.id,Number(v.stock),v.note||'');toast('Stock actualizado y movimiento registrado.');onDone();}});
}

async function openStockMovements(brand){
  try{
    const inventory=await repos.kombaxShowcase.inventoryCost(brand.id,200);const products=Array.isArray(inventory?.items)?inventory.items:[];const summary=inventory?.summary||{};let offset=0;let movements=[];
    const productOptions=products.map(x=>({value:x.id,label:`${x.nombre} · stock ${Number(x.stock||0)}`}));
    const pricing=(product)=>openForm({title:'Coste y precio · Showcase',subtitle:product.nombre,fields:[{name:'unit_cost',label:t('r89.purchaseAvg'),type:'number',min:0,step:'0.01',value:product.precio_compra_medio??''},{name:'sale_price',label:'Precio de venta',type:'number',min:0,step:'0.01',value:product.precio_venta??''},{name:'minimum_stock',label:t('r89.minStock'),type:'number',min:0,value:product.stock_minimo??''},{name:'supplier',label:'Proveedor',value:product.proveedor??''},{name:'note',label:'Nota',type:'textarea',full:true}],submitText:'Guardar',onSubmit:async v=>{await repos.kombaxShowcase.inventoryMutate('pricing',{product_id:product.id,unit_cost:v.unit_cost,sale_price:v.sale_price,minimum_stock:v.minimum_stock,supplier:v.supplier,note:v.note});toast('Coste y precio actualizados');}});
    const purchase=(product)=>openForm({title:t('r89.showcasePurchaseTitle'),subtitle:'Incrementa stock y recalcula el coste medio ponderado.',fields:[{name:'quantity',label:'Unidades',type:'number',min:1,value:1,required:true},{name:'unit_cost',label:'Coste unitario real',type:'number',min:0,step:'0.01',required:true,value:product.precio_compra_medio??''},{name:'supplier',label:'Proveedor',value:product.proveedor??''},{name:'note',label:'Referencia / nota',type:'textarea',full:true}],submitText:t('r89.registerPurchase'),onSubmit:async v=>{await repos.kombaxShowcase.inventoryMutate('purchase',{product_id:product.id,quantity:v.quantity,unit_cost:v.unit_cost,supplier:v.supplier,note:v.note});toast(t('r89.purchaseRecorded'));}});
    const adjust=(product)=>openForm({title:'Ajustar stock · Showcase',subtitle:t('r89.showcaseAdjustHelp'),fields:[{name:'operation',label:'Tipo',type:'select',value:'manual_adjustment',options:[{value:'manual_adjustment',label:'Ajuste de inventario'},{value:'internal_use',label:'Consumo interno'},{value:'loss',label:t('r89.loss')},{value:'return',label:t('r89.returnStock')}]},{name:'new_stock',label:t('r89.newStock'),type:'number',min:0,value:Number(product.stock||0)},{name:'quantity',label:'Cantidad',type:'number',min:1,value:1},{name:'note',label:'Motivo',type:'textarea',full:true,required:true}],submitText:t('r89.saveMovement'),onSubmit:async v=>{await repos.kombaxShowcase.inventoryMutate(v.operation,{product_id:product.id,new_stock:v.new_stock,quantity:v.quantity,note:v.note});toast('Movimiento registrado');}});
    const draw=async(reset=false)=>{if(reset){offset=0;movements=[];}const page=await repos.financeContext.inventory('showcase_provider',brand.id,{limit:10,offset});movements.push(...(page?.movements||[]));offset=Number(page?.next_offset||movements.length);const body=`<div class="metrics"><div class="metric"><span>Unidades</span><strong>${Number(summary.units||0)}</strong></div><div class="metric"><span>Valor a coste</span><strong>${money(Number(summary.inventory_cost_minor||0)/100)}</strong></div><div class="metric"><span>${esc(t('r89.potentialSale'))}</span><strong>${money(Number(summary.potential_sale_minor||0)/100)}</strong></div><div class="metric"><span>Margen potencial</span><strong>${money((Number(summary.potential_sale_minor||0)-Number(summary.inventory_cost_minor||0))/100)}</strong></div></div><div class="kx-stock-cost-products">${products.map(p=>`<article><div><strong>${esc(p.nombre)}</strong><small>${esc(t('r89.stockLine',{stock:Number(p.stock||0),cost:p.precio_compra_medio!=null?money(p.precio_compra_medio):'—',sale:p.precio_venta!=null?money(p.precio_venta):'—',margin:p.margen_unitario!=null?money(p.margen_unitario):'—'}))}</small></div><div class="row-actions"><button class="btn btn-primary btn-sm" data-stock-purchase="${esc(p.id)}">${esc(t('r89.purchase'))}</button><button class="btn btn-ghost btn-sm" data-stock-pricing="${esc(p.id)}">${esc(t('r89.costSale'))}</button><button class="btn btn-ghost btn-sm" data-stock-adjust="${esc(p.id)}">Ajustar</button></div></article>`).join('')}</div><details class="kx-stock-history" open><summary>Movimientos · ${movements.length}</summary><div class="kx-stock-ledger">${movements.length?movements.map(row=>`<article><div><span class="page-kicker">${esc(row.movement_type||'movimiento')}</span><strong>${esc(row.item_name||'Producto')}</strong><small>${dtFmt(row.created_at)}</small></div><div><b>${Number(row.quantity_delta||0)>0?'+':''}${Number(row.quantity_delta||0)}</b><small>${row.unit_cost_minor!=null?`coste ${money(Number(row.unit_cost_minor)/100)}`:''}${row.unit_sale_minor!=null?` · venta ${money(Number(row.unit_sale_minor)/100)}`:''}${row.gross_margin_minor!=null?` · margen ${money(Number(row.gross_margin_minor)/100)}`:''}</small></div></article>`).join(''):empty('Sin movimientos todavía')}</div>${page?.has_more?`<button class="btn btn-ghost" id="showcase-stock-more">${esc(t('r89.load10'))}</button>`:''}</details>`;const modal=openDetail({title:t('r89.stockMargins'),subtitle:`${brand.nombre} · compras, ventas y ajustes`,width:'1080px',className:'kx-stock-ledger-modal',body});modal.wrap.querySelectorAll('[data-stock-purchase]').forEach(b=>b.addEventListener('click',()=>purchase(products.find(p=>p.id===b.dataset.stockPurchase))));modal.wrap.querySelectorAll('[data-stock-pricing]').forEach(b=>b.addEventListener('click',()=>pricing(products.find(p=>p.id===b.dataset.stockPricing))));modal.wrap.querySelectorAll('[data-stock-adjust]').forEach(b=>b.addEventListener('click',()=>adjust(products.find(p=>p.id===b.dataset.stockAdjust))));modal.wrap.querySelector('#showcase-stock-more')?.addEventListener('click',async()=>{modal.close?.();await draw(false);});};
    await draw(true);
  }catch(error){setError(error);}
}

function requestShowcasePromotion(item){
  return openForm({title:`Destacar · ${item?.nombre||'Producto'}`,subtitle:'Posición destacada en Showcase + amplificación automática en KOMBAX Social.',width:'620px',submitText:'Solicitar Destacar',fields:[{name:'days',label:'Duración',type:'select',required:true,value:'7',options:[{value:'7',label:'7 días · 3 €'},{value:'15',label:'15 días · 5 €'},{value:'30',label:'30 días · 8 €'}],help:'Solo productos publicados. La solicitud no realiza un cobro automáticamente.'}],onSubmit:async values=>{await repos.commercial.requestPromotion('showcase_product',item.id,Number(values.days));toast('Solicitud para Destacar registrada. No se ha realizado ningún cobro.');}});
}

async function renderManagement(selectedBrandId=''){
  const brand=managedBrands.find(x=>x.id===selectedBrandId)||managedBrands[0];
  if(!brand){setMainHtml(empty(t('showcase.privateCenter.unavailableTitle'),t('showcase.privateCenter.unavailableBody')));return;}
  const professional=isProfessionalProvider(brand),federation=String(brand.sujeto_tipo||'')==='federacion',sellerCapable=!professional;
  const [sellerCenter,dashboard,capacity,analytics]=await Promise.all([
    professional?Promise.resolve(null):repos.marketplace.sellerCenter(brand.id).catch(()=>null),
    repos.kombaxShowcase.sellerDashboard(brand.id).catch(()=>null),
    sellerCapable?repos.kombaxShowcase.capacity(brand.id,true).catch(()=>null):Promise.resolve(null),
    repos.kombaxShowcase.analytics(brand.id,30).catch(()=>null)
  ]);
  const commercialDescriptor=showcaseCommercialDescriptor(brand,sellerCenter);
  const commercialContext=commercialDescriptor?.subjectId?await repos.commercial.context(commercialDescriptor.subjectType,commercialDescriptor.subjectId).catch(()=>null):null;
  const checks=sellerCenter?.checks||{},sellerAccount=sellerCenter?.seller_account||{},commercialAccess=sellerCenter?.commercial_access||{};
  const sellerAccountActive=sellerAccount.active===true||checks.selling_ready===true;
  const commerceAllowed=commercialAccess.commerce_allowed===true||commercialContext?.commerce_active===true;
  const checkoutAvailable=commercialAccess.checkout_available===true||(sellerAccountActive&&commerceAllowed);
  const planCode=commercialAccess.plan_code||commercialContext?.plan_code||'';
  const stats=dashboard?.stats||{};
  const capacityUnlimited=capacity?.unlimited===true||capacity?.total_limit==null&&['enterprise','brand_enterprise'].includes(planCode);
  const capacityLimit=capacityUnlimited?null:Number(capacity?.total_limit??brand.limite_visible??0);
  const capacityActive=Number(capacity?.active_products??brand.publicados??0);
  const capacityBase=capacityUnlimited?null:Number(capacity?.base_limit??brand.limite_visible??0);
  const capacityBlocks=Number(capacity?.extra_blocks||0);
  const capacityAvailable=capacityUnlimited?null:Math.max(0,Number(capacity?.available_slots??capacityLimit-capacityActive));
  const capacityLabel=capacityUnlimited?'Ilimitado':`${capacityActive}/${capacityLimit}`;
  const catalogPlusEligible=sellerCapable&&!capacityUnlimited&&Boolean(commercialDescriptor?.subjectId)&&(['club','premium','club_pro','brand_start','brand_growth','marca_profesional','federation','federation_partner','federacion_institucional'].includes(planCode)||!planCode&&sellerAccountActive);
  const sellerStatus=sellerAccountActive
    ?`<span class="kx-market-status ok">${icon('checkCircle',{size:14})} Cuenta vendedor ACTIVA</span>`
    :`<span class="kx-market-status pending">${icon('clock',{size:14})} Cuenta vendedor por activar</span>`;
  const commerceStatus=commerceAllowed
    ?`<span class="kx-market-status ok">${icon('checkCircle',{size:14})} Commerce disponible</span>`
    :`<span class="kx-market-status pending">${icon('lock',{size:14})} Commerce no activo</span>`;
  const commercialActions=professional
    ?`<span class="kx-market-status ok">${icon('checkCircle',{size:14})} Servicios profesionales · sin checkout</span>`
    :`${sellerStatus}${commerceStatus}<button class="btn ${sellerAccountActive?'btn-ghost':'btn-primary'}" id="showcase-seller-center">${sellerAccountActive?'Gestionar cuenta vendedor':'Activar cuenta vendedor'}</button>${catalogPlusEligible?'<button class="btn btn-showcase" id="showcase-catalog-plus">+25 productos · 8 €/30 días</button>':''}${brand.sujeto_tipo==='club'&&!commerceAllowed?'<button class="btn btn-primary" id="showcase-commerce-plan">Activar Commerce · 12 €/30 días</button>':''}<button class="btn btn-ghost" id="showcase-commercial-plan">Plan y servicios</button>`;
  const tool=(id,title,detail,{locked=false,reason='',tone=''}={})=>`<button type="button" class="kx-seller-tool ${locked?'locked':''} ${tone}" data-seller-tool="${esc(id)}" ${locked?`data-lock-reason="${esc(reason)}"`:''}><span>${locked?icon('lock',{size:18}):icon(({products:'package',stats:'activity',orders:'receipt',stock:'layers',finance:'wallet',seller:'shield',communications:'message',reviews:'trophy',capacity:'plus',reports:'receipt',bi:'chart',plan:'sparkles'})[id]||'settings',{size:18})}</span><strong>${esc(title)}</strong><small>${esc(detail)}</small></button>`;
  const lockReason=!sellerAccountActive?'activation':!commerceAllowed?'commerce':'';
  const workspace=sellerCapable?`<section class="kx-seller-workspace" aria-label="Mi Showcase · Centro privado de vendedor"><header><div><span class="page-kicker">MI SHOWCASE · CENTRO DE VENDEDOR</span><h2>${esc(brand.nombre)}</h2><p>Gestiona catálogo, activación de vendedor, estadísticas y, cuando tu plan lo permita, pedidos y finanzas.</p></div><div class="kx-seller-workspace-status">${sellerStatus}${commerceStatus}${planCode?`<span class="kx-market-status">Plan ${esc(planCode)}</span>`:''}</div></header><div class="kx-seller-tools">${tool('products','Productos',capacityUnlimited?'Catálogo ilimitado':`Crear y publicar · ${capacityActive}/${capacityLimit} activos`,{tone:'primary'})}${tool('reviews','Valoraciones','Reseñas, compras verificadas y respuestas')}${tool('capacity','Capacidad de catálogo',capacityUnlimited?'Ilimitada en Enterprise':`${capacityBase} incluidos${capacityBlocks?` + ${capacityBlocks*25} adicionales`:''} · ${capacityAvailable} libres`,{locked:capacityUnlimited,reason:capacityUnlimited?'unlimited':''})}${tool('stats',t('showcase.analytics.title'),t('showcase.navigation.analyticsDetail'))}${tool('reports',t('showcase.reports.title'),t('showcase.navigation.reportsDetail'))}${tool('seller',sellerAccountActive?'Cuenta vendedor activa':'Activar cuenta vendedor',sellerAccountActive?'Verificación, contratos y Stripe':'Obligatoria para cualquier vendedor',{tone:sellerAccountActive?'':'attention'})}${tool('orders','Pedidos',checkoutAvailable?'Gestionar preparación, envío y entrega':commerceAllowed?'Activa primero tu cuenta de vendedor':'Requiere Commerce',{locked:!checkoutAvailable,reason:lockReason})}${tool('stock','Stock operativo',checkoutAvailable?'Inventario y movimientos':'Requiere Commerce y vendedor activo',{locked:!checkoutAvailable,reason:lockReason})}${tool('finance','Finanzas',checkoutAvailable?'Ventas, devoluciones y liquidación':'Requiere Commerce y vendedor activo',{locked:!checkoutAvailable,reason:lockReason})}${tool('communications','Comunicaciones',checkoutAvailable?'Mensajes transaccionales':'Se habilita con Commerce',{locked:!checkoutAvailable,reason:lockReason})}${tool('bi','BI Enterprise',planCode==='enterprise'||planCode==='brand_enterprise'?'Analítica avanzada':'Disponible en Enterprise',{locked:!(planCode==='enterprise'||planCode==='brand_enterprise'),reason:'enterprise'})}${tool('plan','Plan y servicios',capacityUnlimited?'Enterprise · catálogo ilimitado':'+25 productos · 8 €/30 días · Commerce y activaciones')}</div></section>`:'';
  const analyticsStrip=analytics?.ok?analyticsSummaryHtml('showcase',analytics):'';
  const dashboardStrip=`<div class="kx-showcase-management-kpis"><article><small>Productos</small><strong>${Number(stats.products||0)}</strong></article><article><small>Servicios</small><strong>${Number(stats.services||0)}</strong></article><article><small>Activos / capacidad</small><strong>${esc(capacityLabel)}</strong><span>${capacityUnlimited?'Enterprise ilimitado':`${capacityBase} incluidos${capacityBlocks?` · +${capacityBlocks*25}`:''}`}</span></article><article><small>Stock</small><strong>${commerceAllowed?Number(stats.stock_units||0):'—'}</strong></article><article><small>Unidades vendidas</small><strong>${checkoutAvailable?Number(stats.units_sold||0):'—'}</strong></article><article><small>Pedidos</small><strong>${checkoutAvailable?Number(stats.orders||0):'—'}</strong></article></div>`;
  const intro=professional
    ?`<div class="alert success"><strong>Showcase de servicios profesionales</strong><span>Este perfil puede publicar servicios y recibir contactos sin alta como vendedor, sin stock y sin checkout. Si en el futuro vende productos físicos, esa función deberá pasar por Marketplace + Centro de vendedor.</span></div>`
    :!planCode?`<div class="alert"><span>${esc(t('marketing.space.sellerEntry'))}</span></div>`
                    :!sellerAccountActive
            ?`<div class="alert"><strong>Cuenta de vendedor pendiente</strong><span>Tu plan puede incluir Commerce, pero no podrás aceptar pagos hasta completar verificación de vendedor, condiciones vigentes y Stripe Connect.</span></div>`:'';
  const title=professional?'Gestión de Showcase':'Mi Showcase';
  const subtitle=professional?'Publica y clasifica tus servicios profesionales para que otros usuarios puedan encontrarte y contactarte.':brand.sujeto_tipo==='club'&&!commerceAllowed?'Tu espacio privado de vendedor: catálogo y estadísticas siempre disponibles; Commerce se activa aparte cuando necesites cobrar.':'Tu espacio privado de vendedor: productos, estadísticas, activación, pedidos y finanzas según tu plan.';
  setMainHtml(`<div class="kombax-showcase-page">${showcaseBrand()}${pageHeader(title,subtitle,subviewActions({backId:'showcase-back',closeId:'showcase-close',backLabel:'Volver a Showcase'}),'KOMBAX Showcase')}<div class="showcase-management-head"><label>Espacio gestionado<select id="showcase-brand-select">${managedBrands.map(x=>`<option value="${esc(x.id)}" ${x.id===brand.id?'selected':''}>${esc(x.nombre)} · ${esc(PROVIDER_LABELS[x.sujeto_tipo]||'Perfil')}</option>`).join('')}</select></label><div class="showcase-provider-limit"><strong>${esc(capacityLabel)}</strong><span>${capacityUnlimited?'catálogo ilimitado':'productos activos'}</span>${!capacityUnlimited?`<small>${capacityBase} incluidos${capacityBlocks?` · ${capacityBlocks} bloque${capacityBlocks===1?'':'s'} +25`:''}</small>`:''}</div>${commercialActions}<button class="btn btn-ghost" id="showcase-seller-dashboard">Estadísticas</button><button class="btn btn-primary" id="showcase-new-item">+ ${professional?'Nuevo servicio':federation?'Ver capacidades':'Añadir producto'}</button></div><nav class="kx-showcase-private-nav" aria-label="${esc(t('showcase.navigation.label'))}"><button type="button" class="active" data-showcase-nav="summary">${esc(t('showcase.navigation.summary'))}</button><button type="button" data-showcase-nav="products">${esc(t('showcase.navigation.products'))}</button><button type="button" data-showcase-nav="orders" ${!checkoutAvailable?'data-locked="commerce"':''}>${esc(t('showcase.navigation.orders'))}</button><button type="button" data-showcase-nav="stock" ${!checkoutAvailable?'data-locked="commerce"':''}>${esc(t('showcase.navigation.stock'))}</button><button type="button" data-showcase-nav="analytics">${esc(t('showcase.navigation.analytics'))}</button><button type="button" data-showcase-nav="reports">${esc(t('showcase.navigation.reports'))}</button><button type="button" data-showcase-nav="finance" ${!checkoutAvailable?'data-locked="commerce"':''}>${esc(t('showcase.navigation.finance'))}</button><button type="button" data-showcase-nav="commerce">${esc(t('showcase.navigation.commerce'))}</button><button type="button" data-showcase-nav="settings">${esc(t('showcase.navigation.settings'))}</button></nav>${workspace}${intro}${analyticsStrip}${dashboardStrip}<div class="kx-showcase-products-heading" id="showcase-products-section"><div><span class="page-kicker">CATÁLOGO</span><h3>${professional?'Servicios publicados':'Productos y fichas'}</h3></div>${sellerCapable?'<button type="button" class="btn btn-primary btn-sm" id="showcase-new-item-inline">+ Añadir producto</button>':''}</div><div id="showcase-managed-items"><div class="loading-card">Cargando fichas…</div></div></div>`);
  document.querySelector('.kombax-showcase-page')?.classList.add('is-private');
  bindSubviewActions(document,{backId:'showcase-back',closeId:'showcase-close',onBack:openPublicShowcaseRoute,onClose:openPublicShowcaseRoute});
  document.getElementById('showcase-brand-select')?.addEventListener('change',e=>renderManagement(e.target.value));
  const openNewItem=()=>{if(!capacityUnlimited&&capacityAvailable<=0){toast('Has alcanzado la capacidad activa. Archiva una referencia, solicita +25 o cambia de plan.','warning');openSellerCenter(brand);return;}itemEditor(brand,null,{commerceAllowed,sellerAccountActive});};
  document.getElementById('showcase-new-item')?.addEventListener('click',openNewItem);
  document.getElementById('showcase-new-item-inline')?.addEventListener('click',openNewItem);
  document.getElementById('showcase-seller-center')?.addEventListener('click',()=>openSellerCenter(brand));
  document.getElementById('showcase-commerce-plan')?.addEventListener('click',()=>openSellerCenter(brand));
  document.getElementById('showcase-commercial-plan')?.addEventListener('click',()=>openShowcaseCommercialPlans(brand,commercialDescriptor));
  document.getElementById('showcase-catalog-plus')?.addEventListener('click',async e=>{
    if(!commercialDescriptor?.subjectId){openShowcaseCommercialPlans(brand,commercialDescriptor);return;}
    const button=e.currentTarget;button.disabled=true;
    try{await repos.commercial.requestActivation(commercialDescriptor.subjectType,commercialDescriptor.subjectId,'SHOWCASE_CATALOG_PLUS_25',{days:30});toast('Solicitud +25 registrada · 8 €/30 días. No se ha realizado ningún cobro automático.');await renderManagement(brand.id);}catch(error){button.disabled=false;toast(humanError(error)||'No se pudo solicitar la ampliación.','error');}
  });
  document.getElementById('showcase-seller-orders')?.addEventListener('click',()=>openSellerOrders(brand));
  document.getElementById('showcase-seller-dashboard')?.addEventListener('click',()=>openShowcaseAnalytics(brand));
  document.getElementById('showcase-seller-finance')?.addEventListener('click',()=>openSellerFinance(brand));
  document.getElementById('showcase-stock-movements')?.addEventListener('click',()=>openStockMovements(brand));
  document.getElementById('showcase-seller-comms')?.addEventListener('click',()=>openSellerCommunications(brand));
  document.getElementById('showcase-seller-bi')?.addEventListener('click',()=>openSellerBI(brand));
  document.querySelectorAll('[data-showcase-nav]').forEach(button=>button.addEventListener('click',()=>{const id=button.dataset.showcaseNav;if(button.dataset.locked){toast(t('showcase.navigation.commerceRequired'),'warning');openShowcaseCommercialPlans(brand,commercialDescriptor);return;}if(id==='summary'){document.querySelector('.kx-seller-workspace')?.scrollIntoView({behavior:'smooth',block:'start'});}else if(id==='products'){document.getElementById('showcase-products-section')?.scrollIntoView({behavior:'smooth',block:'start'});}else if(id==='orders')openSellerOrders(brand);else if(id==='stock')openStockMovements(brand);else if(id==='analytics')openShowcaseAnalytics(brand);else if(id==='reports')openShowcaseReports(brand);else if(id==='finance')openSellerFinance(brand);else if(id==='commerce')openSellerCenter(brand);else if(id==='settings')openShowcaseCommercialPlans(brand,commercialDescriptor);}));
  document.querySelectorAll('[data-seller-tool]').forEach(button=>button.addEventListener('click',()=>{const toolId=button.dataset.sellerTool,reason=button.dataset.lockReason||'';if(toolId==='products'){document.getElementById('showcase-products-section')?.scrollIntoView({behavior:'smooth',block:'start'});return;}if(toolId==='stats'){openShowcaseAnalytics(brand);return;}if(toolId==='reports'){openShowcaseReports(brand);return;}if(toolId==='reviews'){openSellerReviews(brand);return;}if(toolId==='capacity'){if(reason==='unlimited'){toast('Enterprise ya incluye catálogo ilimitado.');return;}openShowcaseCommercialPlans(brand,commercialDescriptor);return;}if(toolId==='seller'){openSellerCenter(brand);return;}if(toolId==='plan'){openShowcaseCommercialPlans(brand,commercialDescriptor);return;}if(reason){if(reason==='activation'){toast('Primero activa la cuenta de vendedor.','error');openSellerCenter(brand);return;}if(reason==='commerce'){toast('Esta herramienta requiere Commerce. Tu catálogo y tu cuenta de vendedor siguen disponibles.','error');openShowcaseCommercialPlans(brand,commercialDescriptor);return;}if(reason==='enterprise'){toast('Business Intelligence está disponible en Enterprise.','error');openShowcaseCommercialPlans(brand,commercialDescriptor);return;}}if(toolId==='orders')openSellerOrders(brand);else if(toolId==='stock')openStockMovements(brand);else if(toolId==='finance')openSellerFinance(brand);else if(toolId==='communications')openSellerCommunications(brand);else if(toolId==='bi')openSellerBI(brand);}));
  const box=document.getElementById('showcase-managed-items');
  try{
    const rows=await repos.kombaxShowcase.myItems(brand.id,managementLimit),inventoryMap=new Map((dashboard?.inventory||[]).map(x=>[String(x.id),x])),analyticsMap=new Map((analytics?.products||[]).map(x=>[String(x.id),x]));
    box.innerHTML=rows.length?`<div class="showcase-manage-list kx-r77-product-list">${rows.map(x=>{const inv=inventoryMap.get(String(x.id))||x,perf=analyticsMap.get(String(x.id))||{},service=isProfessionalService(x),image=safeExternal(x.imagen_url);return `<article class="kx-showcase-product-row"><div class="kx-showcase-product-thumb">${image?`<img ${mediaFrameAttrs(x.imagen_presentacion||{},'product')} src="${esc(image)}" alt="${esc(x.nombre)}">`:`<span>${icon(service?'users':'package',{size:26})}</span>`}</div><div class="kx-showcase-product-info"><span class="page-kicker">${service?t('showcase.products.service'):t('showcase.products.product')} · ${esc(x.estado)}${x.destacado?` · ${esc(t('showcase.products.featured'))}`:''}</span><strong>${esc(x.nombre)}</strong><small>${esc(x.product_type||x.categoria_nombre||t('showcase.analytics.uncategorized'))} · ${service?t('showcase.products.contactOnly'):`${stockStatusLabel(inv.stock_status)}${x.sku?` · SKU ${esc(x.sku)}`:''}`} · ${dtFmt(x.actualizado_en)}</small></div><div class="kx-showcase-product-performance"><span><small>${esc(t('showcase.analytics.units'))}</small><b>${Number(perf.units??inv.units_sold??0)}</b></span><span><small>${esc(t('showcase.analytics.views'))}</small><b>${Number(perf.views||0)}</b></span><span><small>${esc(t('showcase.analytics.revenue'))}</small><b>${money((Number(perf.revenue_minor??inv.gmv_minor)||0)/100)}</b></span><span><small>${esc(t('showcase.analytics.stock'))}</small><b>${service?'—':(x.stock??inv.stock??'—')}</b></span></div><div class="row-actions">${x.imagen_url?`<button class="btn btn-ghost btn-sm" data-showcase-frame="${esc(x.id)}">${esc(t('showcase.products.adjustImage'))}</button>`:''}${Array.isArray(x.galeria)&&x.galeria.filter(Boolean).length?`<button class="btn btn-ghost btn-sm" data-showcase-gallery-frame="${esc(x.id)}">${esc(t('showcase.products.adjustGallery'))}</button>`:''}<button class="btn btn-ghost btn-sm" data-showcase-edit="${esc(x.id)}">${esc(t('common.actions.edit'))}</button>${x.estado==='publicado'&&!service?`<button class="btn btn-showcase btn-sm" data-showcase-promote="${esc(x.id)}">${esc(t('showcase.products.promote'))}</button>`:''}${x.estado==='publicado'?`<button class="btn btn-ghost btn-sm" data-showcase-state="archivado" data-showcase-id="${esc(x.id)}">${esc(t('showcase.products.archive'))}</button>`:x.estado==='retirado'?`<span class="kx-retired-label">${esc(t('showcase.products.retiredHistory'))}</span>`:`<button class="btn btn-primary btn-sm" data-showcase-state="publicado" data-showcase-id="${esc(x.id)}">${esc(x.estado==='fuera_capacidad'?t('showcase.products.reactivate'):t('showcase.products.publish'))}</button>`}<button class="btn btn-danger btn-sm" data-showcase-delete="${esc(x.id)}">${icon('trash',{size:14})} ${esc(t('common.actions.delete'))}</button></div></article>`;}).join('')}</div>${rows.length>=managementLimit&&managementLimit<200?`<div class="load-more-wrap"><button class="btn btn-ghost" id="load-more-showcase-management">${esc(t('showcase.products.loadOlder'))}</button></div>`:''}`:empty(t('showcase.products.emptyTitle'),professional?t('showcase.products.emptyProfessional'):t('showcase.products.emptyProduct'));
    box.querySelector('#load-more-showcase-management')?.addEventListener('click',()=>{managementLimit=Math.min(200,managementLimit+60);renderManagement(brand.id);});
    box.querySelectorAll('[data-showcase-frame]').forEach(b=>b.addEventListener('click',()=>{const row=rows.find(x=>x.id===b.dataset.showcaseFrame),src=safeExternal(row?.imagen_url);if(!row||!src)return;openMediaFramingEditor({title:`Ajustar · ${row.nombre}`,subtitle:'Conserva el original y elige el encuadre.',src,initial:row.imagen_presentacion,preset:'product',onSave:async presentation=>{await repos.mediaFraming.set('showcase_item',row.id,presentation);row.imagen_presentacion=presentation;setTimeout(()=>renderManagement(brand.id),80);}});}));
    box.querySelectorAll('[data-showcase-gallery-frame]').forEach(b=>b.addEventListener('click',()=>{const row=rows.find(x=>x.id===b.dataset.showcaseGalleryFrame),gallery=(Array.isArray(row?.galeria)?row.galeria:[]).map(safeExternal).filter(Boolean).slice(0,3);if(!row||!gallery.length)return;const modal=openDetail({title:`Ajustar galería · ${row.nombre}`,subtitle:'Cada imagen conserva su original y su encuadre propio.',body:`<div class="showcase-detail-gallery kx-showcase-gallery-editor">${gallery.map((u,i)=>`<article><img ${mediaFrameAttrs(row?.galeria_presentacion?.[String(i)]||{},'product')} src="${esc(u)}" alt="${esc(row.nombre)}"><button type="button" class="btn btn-ghost btn-sm" data-showcase-gallery-slot="${i}">Ajustar imagen ${i+1}</button></article>`).join('')}</div>`,width:'900px'});modal.wrap.querySelectorAll('[data-showcase-gallery-slot]').forEach(btn=>btn.addEventListener('click',()=>{const i=Number(btn.dataset.showcaseGallerySlot),src=gallery[i];openMediaFramingEditor({title:`Ajustar imagen ${i+1} · ${row.nombre}`,subtitle:'Puedes mostrar el producto completo o rellenar el marco.',src,initial:row?.galeria_presentacion?.[String(i)]||{},preset:'product',onSave:async presentation=>{await repos.mediaFraming.set(`showcase_gallery_${i}`,row.id,presentation);row.galeria_presentacion={...(row.galeria_presentacion||{}),[String(i)]:presentation};setTimeout(()=>renderManagement(brand.id),80);}});}));}));
    box.querySelectorAll('[data-showcase-edit]').forEach(b=>b.addEventListener('click',()=>itemEditor(brand,rows.find(x=>x.id===b.dataset.showcaseEdit),{commerceAllowed,sellerAccountActive})));
    box.querySelectorAll('[data-showcase-promote]').forEach(b=>b.addEventListener('click',()=>{const row=rows.find(x=>x.id===b.dataset.showcasePromote);if(row)requestShowcasePromotion(row);}));
    box.querySelectorAll('[data-showcase-state]').forEach(b=>b.addEventListener('click',()=>confirmDialog(b.dataset.showcaseState==='publicado'?'Publicar ficha':'Archivar ficha',b.dataset.showcaseState==='publicado'?'La información será visible en Showcase.':'La ficha dejará de mostrarse sin eliminar su historial.',async()=>{await repos.kombaxShowcase.itemState(b.dataset.showcaseId,b.dataset.showcaseState);toast(b.dataset.showcaseState==='publicado'?'Ficha publicada':'Ficha archivada');await renderManagement(brand.id);},{confirmText:b.dataset.showcaseState==='publicado'?'Publicar':'Archivar'})));
    box.querySelectorAll('[data-showcase-delete]').forEach(b=>b.addEventListener('click',()=>confirmDialog('Eliminar producto','Si la referencia no tiene pedidos ni valoraciones se eliminará definitivamente. Si existe historial comercial o reputación, KOMBAX la retirará del catálogo y conservará la trazabilidad, las ventas y las reseñas.',async()=>{const out=await repos.kombaxShowcase.deleteItem(b.dataset.showcaseDelete);toast(out?.retired?'Producto retirado. Se conserva su historial y reputación.':'Producto eliminado definitivamente.');await renderManagement(brand.id);},{confirmText:'Eliminar / retirar',danger:true})));
  }catch(error){box.innerHTML=empty('No se pudo cargar la gestión',humanError(error)||'Revisa tus permisos.');}
}

export async function openProfileSellerCenter(profileId){
  const brand=await repos.kombaxProfiles.sellerEntry(profileId);
  return openSellerCenter(brand);
}

export async function renderMyShowcase({profileId=null}={}){
  activeView='manage';
  managedBrands=[];
  setMainHtml(`<div class="loading-card">${esc(t('showcase.privateCenter.opening'))}</div>`);
  // Direct profiles (including verified Competitors and Media / Creators) have
  // no club_id. The backend resolves their owned provider with a null club scope.
  try{
    const [loadedCategories,spaces]=await Promise.all([repos.kombaxShowcase.categories(),repos.kombaxShowcase.myBrands()]);
    categories=loadedCategories;
    managedBrands=Array.isArray(spaces)?spaces:[];
  }catch(error){
    setError(error);
    setMainHtml(`${empty(t('showcase.privateCenter.unavailableTitle'),humanError(error)||t('showcase.privateCenter.unavailableBody'))}<div class="row-actions" style="justify-content:center"><button type="button" class="btn btn-ghost" id="showcase-private-explore">${esc(t('navigation.products.exploreShowcase'))}</button><button type="button" class="btn btn-showcase" id="showcase-private-retry">${esc(t('showcase.privateCenter.retry'))}</button></div>`);
    document.getElementById('showcase-private-explore')?.addEventListener('click',openPublicShowcaseRoute);
    document.getElementById('showcase-private-retry')?.addEventListener('click',()=>renderMyShowcase({profileId}));
    return;
  }
  if(profileId){
    const provider=managedBrands.find(x=>String(x.perfil_directo_id)===String(profileId))||await repos.kombaxProfiles.sellerEntry(profileId);
    if(!managedBrands.some(x=>x.id===provider.id))managedBrands.push(provider);
    return renderManagement(provider.id);
  }
  if(managedBrands.length)return renderManagement();
  setMainHtml(`${empty('Mi Showcase aún no está habilitado',state.session?.club_id?t('showcase.privateCenter.unavailableBody'):t('marketing.space.sellerEntry')) }<div class="row-actions" style="justify-content:center"><button type="button" class="btn btn-ghost" id="showcase-private-explore">${esc(t('navigation.products.exploreShowcase'))}</button><button type="button" class="btn btn-showcase" id="showcase-private-retry">${esc(t('showcase.privateCenter.retry'))}</button></div>`);
  document.getElementById('showcase-private-explore')?.addEventListener('click',openPublicShowcaseRoute);
  document.getElementById('showcase-private-retry')?.addEventListener('click',()=>renderMyShowcase({profileId}));
}

export async function renderShowcase(){
  // Public exploration is intentionally independent from any private Seller Center state.
  // Never provision or resolve private workspaces just because the user opens the public catalog.
  activeView='catalog';
  managedBrands=[];
  setMainHtml('<div class="loading-card">Cargando KOMBAX Showcase…</div>');
  try{categories=await repos.kombaxShowcase.categories();}
  catch(error){setError(error);setMainHtml(`${showcaseBrand()}${empty('Showcase no disponible',humanError(error)||'No se ha podido cargar el escaparate. Inténtalo de nuevo.')}`);return;}
  return loadCatalog(false);
}


