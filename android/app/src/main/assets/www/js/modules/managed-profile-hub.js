import { t } from '../i18n/index.js';
import { repos } from '../core/repositories.js';
import { esc } from '../core/utils.js';
import { setAppHtml, setError, openDetail, closeModal } from '../ui/components.js';
import { icon, featureIcon } from '../ui/icons.js';
import { openSupportPrivacyCenter } from './support-privacy.js';
import { renderProfessionalFinance } from './professional-finance.js';
import { renderFederationAdmin, renderSelfLicenses, renderProfessionalLicenses } from './federation-licenses.js';
import { renderCompetitionPreparation, migrationAssistBanner } from './competition-preparation.js';
import { openMigrationPreparation, openMigrationGuide, renderKombaxAssistHome, managementAssistBanner } from './customer-operations.js';
import { openFighterOpportunityCenter } from './fighter-discovery.js';
import { openBrandBusinessHub, openBrandCollaborationCenter } from './brand-business.js';
import { openDiscoveryAvailabilityEditor } from './kombax-discovery.js';
import { renderPlanServices } from './plan-services.js';
import { paymentCenterSummaryHtml, bindPaymentCenter, openPaymentCenter } from './payments-center.js';
import { renderResourceCenter } from './resource-center.js';
import { renderKombaxHome } from './kombax-home.js';
import { renderMediaContentCenter } from './media-content-center.js';
import { openKombaxPublicProfile } from './public-profile.js';
import { openProfileTeam } from './profile-team.js';
import { openProfileOperations } from './profile-operations.js';

const HUB_META={
  federacion:{title:'Mi Federación',eyebrow:'ENTORNO INSTITUCIONAL',icon:'federation',description:'Calendario, Events, comunicación y relaciones públicas federativas sin acceso automático a la zona privada de los clubes.'},
  marca:{title:'Mi Marca',eyebrow:'BUSINESS HUB',icon:'brand',description:'Identidad corporativa, catálogo, campañas, colaboraciones, patrocinios, Events y equipo comercial dentro del ecosistema KOMBAX.'},
  profesional:{title:'Mi actividad',eyebrow:'ENTORNO PROFESIONAL',icon:'professional',description:'Servicios, agenda y herramientas profesionales habilitadas por especialidad y capacidades.'},
  competidor:{title:'Mi Competidor',eyebrow:'IDENTIDAD DEPORTIVA',icon:'fighter',description:'Trayectoria, Events, Fight Cards y Social. Competidor sigue separado del Perfil Profesional.'},
  media:{title:'Mi contenido',eyebrow:'MEDIA / CREADOR',icon:'sparkles',description:'Publicaciones, álbum y presencia de creador dentro de KOMBAX Social y Showcase.'},
  espectador:{title:'Mi perfil',eyebrow:'EXPERIENCIA ESPECTADOR',icon:'spectator',description:'Perfil público básico, foto y banner, además de guardados, intereses y avisos. Espectador no dispone de álbum ni publica en el feed Social.'}
};
const MODULE_LABELS={organization_finance:'Finanzas de mi organización',operational_planning:'Centro de actividad',organizer_events:'Mis eventos · producción y ticketing',content_center:'Mi contenido',seller_center:'Mi Showcase · vendedor',professional_operations:'Operaciones profesionales',professional_finance:'Finanzas Profesionales',representation_requests:'Representación',overview:'Resumen',public_profile:'Perfil público',federation_admin:'Administración federativa',federates:'Mis federados',licenses:'Licencias',federation_team:'Equipo de Federación',my_licenses:'Mis licencias',account_licenses:'Mis licencias personales',authorized_licenses:'Licencias autorizadas',affiliated_clubs:'Clubes afiliados / relacionados',calendar:'Calendario',events:'KOMBAX Events',documents:'Documentos públicos',communications:'Comunicaciones',social:'KOMBAX Social',managers:'Gestores',showcase:'KOMBAX Showcase',contacts:'Contactos',services:'Servicios',schedule:'Agenda',sport_profile:'Perfil deportivo',fight_cards:'Fight Cards',saved:'Guardados',event_interests:'Intereses en Events',notifications:'Notificaciones',privacy_support:'Privacidad y soporte',preparation:'Mis competiciones',fight_opportunities:'Oportunidades de combate',brand_business:'Business Hub',brand_campaigns:'Campañas',brand_collaborations:'Colaboraciones',brand_sponsorships:'Patrocinios',brand_analytics:'Estadísticas',brand_team:'Equipo de Marca',brand_opportunities:'Colaboraciones con marcas',assist_management:'KOMBAX Assist',migration_guide:'Guía de migración',plans_services:'Plan y servicios',discovery_availability:'Disponibilidad y Discovery',payments:'Cobros y Stripe'};
const ACTIONABLE=new Set(['organization_finance','operational_planning','organizer_events','public_profile','content_center','seller_center','brand_business','brand_campaigns','brand_collaborations','brand_sponsorships','brand_analytics','brand_team','brand_opportunities','fight_opportunities','preparation','social','showcase','events','privacy_support','professional_operations','professional_finance','representation_requests','federation_admin','federates','licenses','federation_team','affiliated_clubs','my_licenses','account_licenses','authorized_licenses','migration_guide','assist_management','plans_services','discovery_availability','payments']);

function capabilitySet(rows=[]){return new Set(rows.map(x=>x.clave||x.capacidad_clave).filter(Boolean));}
function moduleAllowed(module,caps,profile){
  if(module==='seller_center')return profile?.verificacion_estado==='verificado'&&caps.has('showcase.publish');
  if(module==='social')return caps.has('social.read')||caps.has('social.publish');
  if(module==='showcase')return caps.has('showcase.read')||caps.has('showcase.publish');
  if(module==='events')return caps.has('events.public.read')||caps.has('events.public.organize');
  if(module==='authorized_licenses')return caps.has('professional.licenses.read_authorized');
  return true;
}
function openBlockedModulePreview(module,profile,{openPlans}={}){
  const details={
    social:{title:'KOMBAX Social',body:'Comparte contenido desde una identidad activa y conecta con tu comunidad. Publicar requiere el vínculo o la verificación correspondiente; explorar perfiles públicos sigue disponible.'},
    showcase:{title:'KOMBAX Showcase',body:'Presenta productos o servicios en un escaparate público. La venta, el carrito y los cobros requieren Commerce y la verificación del vendedor. Una ampliación de catálogo no activa Commerce.'},
    seller_center:{title:'Mi Showcase · vendedor',body:'Primero verifica tu identidad de Competidor o Media / Creador y activa la capacidad Showcase de tu plan. Después podrás solicitar la verificación independiente como vendedor, aceptar las condiciones y configurar Stripe. Cobrar requiere además Commerce activo.'},
    events:{title:'KOMBAX Events',body:'Descubre experiencias y prepara eventos desde tu identidad. Publicar un evento, destacarlo y vender entradas son capacidades independientes; Ticketing incluye entradas y control QR.'},
    authorized_licenses:{title:'Licencias autorizadas',body:'Consulta licencias profesionales únicamente cuando una federación o entidad competente te haya concedido autorización. Tu perfil no obtiene acceso a datos privados de un club por sí solo.'}
  }[module]||{title:MODULE_LABELS[module]||module,body:'Esta función requiere una capacidad activa para la identidad seleccionada.'};
  const modal=openDetail({title:details.title,subtitle:'Vista previa de la función',width:'720px',body:`<div class="kx-module-preview"><p>${esc(details.body)}</p><p><strong>Para usarla:</strong> consulta las capacidades de tu identidad, los límites aplicables y su estado de verificación. Encontrarás pasos y ejemplos en Recursos · Guías.</p><p>Si hay una prueba disponible, aparecerá en Plan y servicios cuando esté habilitada para esta organización.</p></div>`,actions:openPlans?'<button class="btn btn-primary" data-kx-preview-plans>Ver Plan y servicios</button><button class="btn btn-ghost" data-kx-preview-close>Cerrar</button>':'<button class="btn btn-ghost" data-kx-preview-close>Cerrar</button>'});
  modal.wrap.querySelector('[data-kx-preview-close]')?.addEventListener('click',closeModal);
  modal.wrap.querySelector('[data-kx-preview-plans]')?.addEventListener('click',()=>{closeModal();openPlans();});
}
function specialtyCopy(workspace){
  const p=workspace.professional_specialty||{};if(!p.principal)return '';
  const secondary=Array.isArray(p.secundarias)&&p.secundarias.length?` · ${p.secundarias.join(' · ')}`:'';
  return `<div class="kx-managed-specialty"><span>Especialidad profesional</span><strong>${esc(p.principal)}</strong><small>${esc(secondary.replace(/^ · /,''))}</small></div>`;
}
function requiredIdentityModules(type,caps){
  if(type==='federacion')return ['organization_finance','operational_planning','social','events','plans_services','assist_management','federation_admin','federates','licenses','affiliated_clubs','federation_team','migration_guide'];
  if(type==='marca')return ['organization_finance','operational_planning','social','showcase','events','plans_services','assist_management','migration_guide','brand_business','brand_campaigns','brand_collaborations','brand_sponsorships','brand_analytics','brand_team'];
  if(type==='profesional')return [...(caps.has('events.public.organize')?['operational_planning','organizer_events']:[]),'social','events','discovery_availability','my_licenses','brand_opportunities','authorized_licenses',...(caps.has('events.public.organize')?['payments']:[])];
  if(type==='competidor')return ['social','events','discovery_availability','my_licenses','preparation','fight_opportunities','brand_opportunities','seller_center'];
  if(type==='media')return ['content_center','social','showcase','events'];
  return [];
}
function mergeModules(source=[],required=[]){return [...new Set([...(source||[]),...(required||[])])];}
function accountLicenseTool(type){return ['federacion','marca','media','espectador'].includes(type);}
function federationConnectPanel(connect){return connect?paymentCenterSummaryHtml(connect,{subjectType:'federation',title:'Cobros y domiciliaciones',compact:true}):'';}

export async function renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps}={}){
  setAppHtml('<main class="kx-managed-hub"><div class="loading-card">Abriendo entorno del perfil…</div></main>');
  try{
    const workspace=await repos.kombaxProfiles.workspace(profileId);const profile=workspace?.profile||{};const meta=HUB_META[profile.tipo]||HUB_META.competidor;
    const caps=capabilitySet(workspace?.capabilities);const connectType=profile.tipo==='federacion'?'federation':profile.tipo==='profesional'&&caps.has('events.public.organize')?'event_organizer':null;
    const connect=connectType?await repos.payments.paymentMethodsStatus(connectType,profile.id).catch(()=>null):null;
    const modules=mergeModules(workspace?.modules,requiredIdentityModules(profile.tipo,caps));const boundaries=workspace?.boundaries||{};
    setAppHtml(`<main class="kx-managed-hub" data-profile-type="${esc(profile.tipo||'')}">
      <header class="kx-managed-top"><button class="gateway-icon-button" id="kx-managed-back" type="button" aria-label="Volver">${icon('chevronLeft',{size:22})}</button><div class="kx-managed-title"><span>${esc(meta.eyebrow)}</span><strong>${esc(meta.title)}</strong></div><button class="btn btn-ghost btn-sm" id="kx-managed-home" type="button">${icon('home',{size:16})} Inicio</button><div class="kx-managed-status">${esc(profile.verificacion_estado||'')}</div></header>
      <section class="kx-managed-hero"><div class="kx-managed-icon">${featureIcon(meta.icon,{size:62})}</div><div><span>${esc(profile.tipo||'PERFIL')}</span><h1>${esc(profile.nombre_publico||meta.title)}</h1><p>${esc(meta.description)}</p><div class="kx-managed-tags">${(profile.disciplinas||[]).slice(0,5).map(x=>`<b>${esc(x)}</b>`).join('')}${caps.size?`<b>${caps.size} capacidades</b>`:''}</div></div></section>
      ${profile.tipo==='profesional'?specialtyCopy(workspace):''}
      ${['federacion','marca'].includes(profile.tipo)?managementAssistBanner({context:{profileId:profile.id,profileType:profile.tipo}}):''}${['federacion','marca'].includes(profile.tipo)?migrationAssistBanner({context:{profileId:profile.id,profileType:profile.tipo}}):''}
      ${profile.tipo==='federacion'?federationConnectPanel(connect):''}${connectType==='event_organizer'&&connect?paymentCenterSummaryHtml(connect,{subjectType:'event_organizer',title:t('payments.organizerPaymentsTitle'),compact:true}):''}
      ${profile.tipo==='federacion'?'<div class="kx-managed-boundary"><strong>Frontera de privacidad federativa</strong><p>La afiliación o relación con un club no concede acceso a alumnos, finanzas, asistencia, documentos privados, comunidad interna ni datos de menores.</p></div>':''}
      ${profile.tipo==='espectador'?'<div class="kx-managed-boundary"><strong>Perfil público básico</strong><p>Espectador puede tener foto, banner e información pública y consumir/guardar contenido. No dispone de álbum ni publica en el feed Social.</p></div>':''}
      <section class="kx-managed-grid">${modules.map(m=>`<button class="kx-managed-module ${moduleAllowed(m,caps,profile)?ACTIONABLE.has(m)?'actionable':'planned':'planned'}" data-module="${esc(m)}" type="button"><span>${esc(MODULE_LABELS[m]||m)}</span><small>${moduleAllowed(m,caps,profile)?ACTIONABLE.has(m)?'Abrir':'Disponible según capacidades y fase':'Conocer esta capacidad'}</small>${icon('chevronRight',{size:18})}</button>`).join('')}${profile.tipo==='profesional'?`<button class="kx-managed-module actionable" data-module="professional_operations" type="button"><span>Operaciones profesionales</span><small>Clientes, agenda, credenciales y relaciones</small>${icon('chevronRight',{size:18})}</button>`:''}${profile.tipo==='profesional'&&(caps.has('professional.finance.manage')||caps.has('professional.finance.reports'))?`<button class="kx-managed-module actionable" data-module="professional_finance" type="button"><span>Finanzas Profesionales</span><small>Cargos, pagos, gastos e informe básico</small>${icon('chevronRight',{size:18})}</button>`:''}${profile.tipo==='competidor'?`<button class="kx-managed-module actionable" data-module="representation_requests" type="button"><span>Representación</span><small>Solicitudes de Manager y permisos delegados</small>${icon('chevronRight',{size:18})}</button>`:''}</section>
      ${accountLicenseTool(profile.tipo)?`<section class="kx-managed-account-tools"><div><span>MI CUENTA</span><strong>Documentación personal</strong><small>Esta herramienta pertenece a tu cuenta personal; no concede permisos federativos a ${esc(meta.title)}.</small></div><button class="kx-managed-module actionable" data-module="account_licenses" type="button"><span>Mis licencias personales</span><small>Solo licencias vinculadas a tu cuenta</small>${icon('chevronRight',{size:18})}</button></section>`:''}
      <section class="kx-managed-security"><div><strong>Aislamiento activo</strong><p>Perfil directo independiente · acceso privado cruzado: ${boundaries.cross_profile_private_access?'permitido':'bloqueado'} · acceso privado a Club por identidad: ${boundaries.private_club_access?'permitido':'bloqueado'}.</p></div><button class="btn btn-ghost" id="kx-managed-resources">${esc(t('prepilot.resources'))}</button><button class="btn btn-ghost" id="kx-managed-privacy">Privacidad y soporte</button></section>
    </main>`);
    const identityBrand=document.querySelector('.kx-personal-brand');
    if(identityBrand){
      identityBrand.classList.add('kx-profile-brand');
      identityBrand.querySelector('strong').textContent=profile.nombre_publico||meta.title;
      identityBrand.querySelector('small').textContent=meta.title;
      identityBrand.querySelector('.kx-personal-brand-symbol').innerHTML=featureIcon(meta.icon,{size:26});
    }
    document.getElementById('kx-managed-back')?.addEventListener('click',onBack);
    if(['marca','federacion','profesional','competidor','media'].includes(profile.tipo)){
      const header=document.querySelector('.kx-managed-top'),button=document.createElement('button');
      button.type='button';button.className='btn btn-ghost btn-sm';button.dataset.kxProfileTeam='';button.textContent='Equipo y permisos';
      header?.appendChild(button);button.addEventListener('click',()=>openProfileTeam(profile));
    }
    const openHome=()=>renderKombaxHome({standalone:true,contextName:profile.nombre_publico||meta.title,onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps}),onNavigate:target=>{
      if(target==='workspace')return renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps});
      if(target==='social')return onSocial?.();
      if(target==='showcase')return onShowcase?.();
      if(target==='kombax-events')return onEvents?.();
      if(['guides','consulting','training'].includes(target))return renderResourceCenter({standalone:true,onBack:openHome});
    }});
    document.getElementById('kx-managed-home')?.addEventListener('click',openHome);
    const openPrivacy=()=>openSupportPrivacyCenter({subjectType:'direct_profile',subjectId:profile.id,title:`Privacidad y soporte · ${profile.nombre_publico||meta.title}`,canAuthorize:true});
    document.getElementById('kx-managed-privacy')?.addEventListener('click',openPrivacy);
    document.getElementById('kx-managed-resources')?.addEventListener('click',()=>renderResourceCenter({standalone:true,onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})}));
    if(connectType&&connect)bindPaymentCenter(document.querySelector('.kx-managed-hub'),{subjectType:connectType,subjectId:profile.id,onRefresh:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps}),assistContext:{profileId:profile.id,profileType:profile.tipo,onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps}),onSocial,onShowcase}});
    document.querySelector('[data-kx-migration-assist]')?.addEventListener('click',()=>openMigrationPreparation({profileId:profile.id,profileType:profile.tipo,onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps}),onSocial,onShowcase}));
    document.querySelector('[data-kx-management-assist]')?.addEventListener('click',()=>renderKombaxAssistHome({profileId:profile.id,profileType:profile.tipo,onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps}),onSocial,onShowcase}));
    const nav=document.querySelector('.kx-personal-sidebar nav');
    if(nav){
      const group=document.createElement('div');group.className='kx-profile-context-nav';
      const moduleButton=(m)=>`<button class="nav-item nav-club-item kx-profile-module-link" type="button" data-module="${esc(m)}"><span>${icon(m.includes('finance')?'wallet':m.includes('event')?'calendar':'layers',{size:19})}</span><b>${esc(m==='operational_planning'?(profile.tipo==='marca'?'Campañas y Embajadores':profile.tipo==='federacion'?'Centro de Temporada':'Centro de Producción'):MODULE_LABELS[m]||m)}</b></button>`;
      const product=(m,accent,symbol,privateModules=[])=>`<details class="club-nav-accordion product-nav-accordion ${accent}"><summary><span class="club-nav-icon">${icon(symbol,{size:20})}</span><span class="club-nav-copy"><b>${esc(MODULE_LABELS[m])}</b></span><span class="club-nav-chevron">${icon('chevronRight',{size:17})}</span></summary><div class="club-nav-panel product-nav-panel">${[m,...privateModules.filter(n=>modules.includes(n))].map(moduleButton).join('')}</div></details>`;
      const extras=modules.filter(m=>ACTIONABLE.has(m)&&!['public_profile','social','events','showcase','organizer_events','seller_center'].includes(m));
      group.innerHTML=`${modules.includes('public_profile')?moduleButton('public_profile'):''}
        ${modules.includes('social')?`<button type="button" class="nav-item nav-primary kx-profile-product-social" data-module="social"><span>${icon('network',{size:20})}</span><b>${esc(MODULE_LABELS.social)}</b></button>`:''}
        ${modules.includes('events')?product('events','events-product-nav','arena',['organizer_events']):''}
        ${modules.includes('showcase')?product('showcase','showcase-product-nav','spotlight',['seller_center']):''}
        <details class="kx-sidebar-resources"><summary><span class="kx-resources-icon">${icon('sparkles',{size:20})}</span><span class="kx-resources-label"><b>${esc(t('prepilot.resources'))}</b><small>${esc(t('prepilot.rcResourcesSub'))}</small></span><span class="kx-resources-chevron">${icon('chevronRight',{size:17})}</span></summary><div class="kx-sidebar-resources-panel"><button type="button" data-kx-profile-resource>${esc(t('prepilot.resources'))}</button></div></details>
        <details class="club-nav-accordion kx-profile-identity-accordion"><summary><span class="club-nav-icon">${featureIcon(meta.icon,{size:20})}</span><span class="club-nav-copy"><b>${esc(meta.title)}</b><small>${esc(profile.nombre_publico||meta.title)}</small></span><span class="club-nav-chevron">${icon('chevronRight',{size:17})}</span></summary><div class="club-nav-panel">${extras.map(moduleButton).join('')}</div></details>`;
      group.querySelector('[data-kx-profile-resource]')?.addEventListener('click',()=>renderResourceCenter({standalone:true,onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})}));
      nav.prepend(group);
    }
    document.querySelectorAll('[data-module]').forEach(button=>button.addEventListener('click',()=>{
      document.querySelector('.kx-personal-shell')?.classList.remove('menu-open');document.querySelector('#kx-personal-menu')?.setAttribute('aria-expanded','false');
      const mod=button.dataset.module;if(mod==='organization_finance'||mod==='operational_planning')return openProfileOperations(profile,{kind:mod==='organization_finance'?'finance':'tasks'});if(mod==='organizer_events')return import('./kombax-events.js').then(m=>m.renderMyEventsCenter()).catch(setError);if(mod==='public_profile'){if(profile.social_profile_id)return openKombaxPublicProfile(profile.social_profile_id);return openBlockedModulePreview(mod,profile);}if(mod==='content_center'&&profile.tipo==='media')return renderMediaContentCenter(profile,{onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps}),onSocial,onShowcase});if(mod==='seller_center'){if(profile.verificacion_estado!=='verificado'||!caps.has('showcase.publish'))return openBlockedModulePreview(mod,profile);return onShowcase?.('manage');}if(!moduleAllowed(mod,caps,profile))return openBlockedModulePreview(mod,profile,{openPlans:['marca','federacion'].includes(profile.tipo)?()=>renderPlanServices({audience:profile.tipo==='marca'?'brand':'federation',subjectType:'direct_profile',subjectId:profile.id,onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})}):null});if(mod==='payments'&&connectType)return openPaymentCenter({subjectType:connectType,subjectId:profile.id,title:'Cobros y Stripe',assistContext:{profileId:profile.id,profileType:profile.tipo,onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps}),onSocial,onShowcase}}).catch(setError);if(mod==='plans_services'&&['federacion','marca'].includes(profile.tipo))return renderPlanServices({audience:profile.tipo==='marca'?'brand':'federation',subjectType:'direct_profile',subjectId:profile.id,onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})});if(mod==='assist_management'&&['federacion','marca'].includes(profile.tipo))return renderKombaxAssistHome({profileId:profile.id,profileType:profile.tipo,onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps}),onSocial,onShowcase});if(mod==='social'&&onSocial)return onSocial();if(mod==='showcase'&&onShowcase)return onShowcase();if(mod==='events'&&onEvents)return onEvents();if((mod==='professional_operations'||mod==='representation_requests')&&onProfessionalOps)return onProfessionalOps(profile.id,profile.tipo);if(mod==='professional_finance')return renderProfessionalFinance(profile.id,{onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})});if(['federation_admin','federates','licenses','federation_team','affiliated_clubs'].includes(mod)&&profile.tipo==='federacion')return renderFederationAdmin(profile.id,{focus:mod,onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})});if(mod==='my_licenses'&&['competidor','profesional'].includes(profile.tipo))return renderSelfLicenses(profile.id,{contextLabel:profile.tipo==='competidor'?'MI COMPETIDOR':'MI ACTIVIDAD',onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})});if(mod==='account_licenses')return renderSelfLicenses(null,{contextLabel:'MI CUENTA',subjectLabel:'Mis licencias personales',onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})});if(mod==='authorized_licenses'&&profile.tipo==='profesional')return renderProfessionalLicenses(profile.id,{onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})});if(mod==='preparation'&&profile.tipo==='competidor')return renderCompetitionPreparation({competitorProfileId:profile.id,title:'Mis competiciones',onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})});if(mod==='discovery_availability'&&['competidor','profesional'].includes(profile.tipo))return openDiscoveryAvailabilityEditor(profile,{onDone:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})});if(mod==='fight_opportunities'&&profile.tipo==='competidor')return openFighterOpportunityCenter(profile,{onDone:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})});if(['brand_business','brand_campaigns','brand_collaborations','brand_sponsorships','brand_analytics','brand_team'].includes(mod)&&profile.tipo==='marca')return openBrandBusinessHub(profile,{focus:mod==='brand_business'?'overview':mod.replace('brand_','')});if(mod==='brand_opportunities'&&['competidor','profesional'].includes(profile.tipo))return openBrandCollaborationCenter(profile);if(mod==='migration_guide'&&['federacion','marca'].includes(profile.tipo))return openMigrationGuide({profileId:profile.id,profileType:profile.tipo});if(mod==='privacy_support')return openPrivacy();
      return openBlockedModulePreview(mod,profile);
    }));
  }catch(error){setError(error);onBack?.();}
}

export function managedHubTitle(type){return HUB_META[type]?.title||'Mi perfil KOMBAX';}


