import { repos } from '../core/repositories.js';
import { esc } from '../core/utils.js';
import { setAppHtml, setError } from '../ui/components.js';
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

const HUB_META={
  federacion:{title:'Mi Federación',eyebrow:'ENTORNO INSTITUCIONAL',icon:'federation',description:'Calendario, Events, comunicación y relaciones públicas federativas sin acceso automático a la zona privada de los clubes.'},
  marca:{title:'Mi Marca',eyebrow:'BUSINESS HUB',icon:'brand',description:'Identidad corporativa, catálogo, campañas, colaboraciones, patrocinios, Events y equipo comercial dentro del ecosistema KOMBAX.'},
  profesional:{title:'Mi actividad',eyebrow:'ENTORNO PROFESIONAL',icon:'professional',description:'Servicios, agenda y herramientas profesionales habilitadas por especialidad y capacidades.'},
  competidor:{title:'Mi Competidor',eyebrow:'IDENTIDAD DEPORTIVA',icon:'fighter',description:'Trayectoria, Events, Fight Cards y Social. Competidor sigue separado del Perfil Profesional.'},
  espectador:{title:'Mi perfil',eyebrow:'EXPERIENCIA ESPECTADOR',icon:'spectator',description:'Guardados, intereses y avisos. Es una identidad de consumo privada y no publicadora por defecto.'}
};
const MODULE_LABELS={professional_operations:'Operaciones profesionales',professional_finance:'Finanzas Profesionales',representation_requests:'Representación',overview:'Resumen',public_profile:'Perfil público',federation_admin:'Administración federativa',federates:'Mis federados',licenses:'Licencias',federation_team:'Equipo de Federación',my_licenses:'Mis licencias',account_licenses:'Mis licencias personales',authorized_licenses:'Licencias autorizadas',affiliated_clubs:'Clubes afiliados / relacionados',calendar:'Calendario',events:'KOMBAX Events',documents:'Documentos públicos',communications:'Comunicaciones',social:'KOMBAX Social',managers:'Gestores',showcase:'KOMBAX Showcase',contacts:'Contactos',services:'Servicios',schedule:'Agenda',sport_profile:'Perfil deportivo',fight_cards:'Fight Cards',saved:'Guardados',event_interests:'Intereses en Events',notifications:'Notificaciones',privacy_support:'Privacidad y soporte',preparation:'Mis competiciones',fight_opportunities:'Oportunidades de combate',brand_business:'Business Hub',brand_campaigns:'Campañas',brand_collaborations:'Colaboraciones',brand_sponsorships:'Patrocinios',brand_analytics:'Estadísticas',brand_team:'Equipo de Marca',brand_opportunities:'Colaboraciones con marcas',assist_management:'KOMBAX Assist',migration_guide:'Guía de migración',plans_services:'Plan y servicios',discovery_availability:'Disponibilidad y Discovery'};
const ACTIONABLE=new Set(['brand_business','brand_campaigns','brand_collaborations','brand_sponsorships','brand_analytics','brand_team','brand_opportunities','fight_opportunities','preparation','social','showcase','events','privacy_support','professional_operations','professional_finance','representation_requests','federation_admin','federates','licenses','federation_team','affiliated_clubs','my_licenses','account_licenses','authorized_licenses','migration_guide','assist_management','plans_services','discovery_availability']);

function capabilitySet(rows=[]){return new Set(rows.map(x=>x.clave||x.capacidad_clave).filter(Boolean));}
function moduleAllowed(module,caps){
  if(module==='social')return caps.has('social.read')||caps.has('social.publish');
  if(module==='showcase')return caps.has('showcase.read')||caps.has('showcase.publish');
  if(module==='events')return caps.has('events.public.read')||caps.has('events.public.organize');
  if(module==='authorized_licenses')return caps.has('professional.licenses.read_authorized');
  return true;
}
function specialtyCopy(workspace){
  const p=workspace.professional_specialty||{};if(!p.principal)return '';
  const secondary=Array.isArray(p.secundarias)&&p.secundarias.length?` · ${p.secundarias.join(' · ')}`:'';
  return `<div class="kx-managed-specialty"><span>Especialidad profesional</span><strong>${esc(p.principal)}</strong><small>${esc(secondary.replace(/^ · /,''))}</small></div>`;
}
function requiredIdentityModules(type,caps){
  if(type==='federacion')return ['plans_services','assist_management','federation_admin','federates','licenses','affiliated_clubs','federation_team','migration_guide'];
  if(type==='marca')return ['plans_services','assist_management','migration_guide','brand_business','brand_campaigns','brand_collaborations','brand_sponsorships','brand_analytics','brand_team'];
  if(type==='profesional')return ['discovery_availability','my_licenses','brand_opportunities',...(caps.has('professional.licenses.read_authorized')?['authorized_licenses']:[])];
  if(type==='competidor')return ['discovery_availability','my_licenses','preparation','fight_opportunities','brand_opportunities'];
  return [];
}
function mergeModules(source=[],required=[]){return [...new Set([...(source||[]),...(required||[])])];}
function accountLicenseTool(type){return ['federacion','marca','espectador'].includes(type);}
function federationConnectPanel(connect){
  if(!connect)return '';const active=connect.status==='active'&&connect.charges_enabled&&connect.payouts_enabled;const due=Array.isArray(connect.requirements_due)?connect.requirements_due.length:0;
  const state=active?'Cuenta preparada':connect.status==='action_required'||due?'Acción requerida':'Configuración pendiente';
  return `<section class="kx-managed-account-tools kx-managed-connect"><div><span>COBROS CON TARJETA</span><strong>${esc(state)}</strong><small>${active?'Stripe procesa el cobro en la cuenta conectada de la Federación. KOMBAX solo percibe las tarifas de plataforma o servicios propios que correspondan.':due?`${due} requisito${due===1?'':'s'} pendiente${due===1?'':'s'} en Stripe.`:'Completa el alta segura de la cuenta Stripe de esta Federación.'}</small></div><button class="btn ${active?'btn-ghost':'btn-primary'}" id="kx-federation-connect" type="button">${active?'Revisar en Stripe':'Activar cobros'}</button></section>`;
}

export async function renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps}={}){
  setAppHtml('<main class="kx-managed-hub"><div class="loading-card">Abriendo entorno del perfil…</div></main>');
  try{
    const workspace=await repos.kombaxProfiles.workspace(profileId);const profile=workspace?.profile||{};const meta=HUB_META[profile.tipo]||HUB_META.competidor;
    const connect=profile.tipo==='federacion'?await repos.payments.connectStatus('federation',profile.id).catch(()=>null):null;
    const caps=capabilitySet(workspace?.capabilities);const modules=mergeModules(workspace?.modules,requiredIdentityModules(profile.tipo,caps)).filter(m=>moduleAllowed(m,caps));const boundaries=workspace?.boundaries||{};
    setAppHtml(`<main class="kx-managed-hub" data-profile-type="${esc(profile.tipo||'')}">
      <header class="kx-managed-top"><button class="gateway-icon-button" id="kx-managed-back" type="button" aria-label="Volver">${icon('chevronLeft',{size:22})}</button><div class="kx-managed-title"><span>${esc(meta.eyebrow)}</span><strong>${esc(meta.title)}</strong></div><div class="kx-managed-status">${esc(profile.verificacion_estado||'')}</div></header>
      <section class="kx-managed-hero"><div class="kx-managed-icon">${featureIcon(meta.icon,{size:62})}</div><div><span>${esc(profile.tipo||'PERFIL')}</span><h1>${esc(profile.nombre_publico||meta.title)}</h1><p>${esc(meta.description)}</p><div class="kx-managed-tags">${(profile.disciplinas||[]).slice(0,5).map(x=>`<b>${esc(x)}</b>`).join('')}${caps.size?`<b>${caps.size} capacidades</b>`:''}</div></div></section>
      ${profile.tipo==='profesional'?specialtyCopy(workspace):''}
      ${['federacion','marca'].includes(profile.tipo)?managementAssistBanner({context:{profileId:profile.id,profileType:profile.tipo}}):''}${['federacion','marca'].includes(profile.tipo)?migrationAssistBanner({context:{profileId:profile.id,profileType:profile.tipo}}):''}
      ${profile.tipo==='federacion'?federationConnectPanel(connect):''}
      ${profile.tipo==='federacion'?'<div class="kx-managed-boundary"><strong>Frontera de privacidad federativa</strong><p>La afiliación o relación con un club no concede acceso a alumnos, finanzas, asistencia, documentos privados, comunidad interna ni datos de menores.</p></div>':''}
      ${profile.tipo==='espectador'?'<div class="kx-managed-boundary"><strong>Privado por defecto</strong><p>Espectador puede consumir y guardar contenido, pero no publica Social, Showcase ni Events en esta fase.</p></div>':''}
      <section class="kx-managed-grid">${modules.map(m=>`<button class="kx-managed-module ${ACTIONABLE.has(m)?'actionable':'planned'}" data-module="${esc(m)}" type="button"><span>${esc(MODULE_LABELS[m]||m)}</span><small>${ACTIONABLE.has(m)?'Abrir':'Disponible según capacidades y fase'}</small>${icon('chevronRight',{size:18})}</button>`).join('')}${profile.tipo==='profesional'?`<button class="kx-managed-module actionable" data-module="professional_operations" type="button"><span>Operaciones profesionales</span><small>Clientes, agenda, credenciales y relaciones</small>${icon('chevronRight',{size:18})}</button>`:''}${profile.tipo==='profesional'&&(caps.has('professional.finance.manage')||caps.has('professional.finance.reports'))?`<button class="kx-managed-module actionable" data-module="professional_finance" type="button"><span>Finanzas Profesionales</span><small>Cargos, pagos, gastos e informe básico</small>${icon('chevronRight',{size:18})}</button>`:''}${profile.tipo==='competidor'?`<button class="kx-managed-module actionable" data-module="representation_requests" type="button"><span>Representación</span><small>Solicitudes de Manager y permisos delegados</small>${icon('chevronRight',{size:18})}</button>`:''}</section>
      ${accountLicenseTool(profile.tipo)?`<section class="kx-managed-account-tools"><div><span>MI CUENTA</span><strong>Documentación personal</strong><small>Esta herramienta pertenece a tu cuenta personal; no concede permisos federativos a ${esc(meta.title)}.</small></div><button class="kx-managed-module actionable" data-module="account_licenses" type="button"><span>Mis licencias personales</span><small>Solo licencias vinculadas a tu cuenta</small>${icon('chevronRight',{size:18})}</button></section>`:''}
      <section class="kx-managed-security"><div><strong>Aislamiento activo</strong><p>Perfil directo independiente · acceso privado cruzado: ${boundaries.cross_profile_private_access?'permitido':'bloqueado'} · acceso privado a Club por identidad: ${boundaries.private_club_access?'permitido':'bloqueado'}.</p></div><button class="btn btn-ghost" id="kx-managed-privacy">Privacidad y soporte</button></section>
    </main>`);
    document.getElementById('kx-managed-back')?.addEventListener('click',onBack);
    const openPrivacy=()=>openSupportPrivacyCenter({subjectType:'direct_profile',subjectId:profile.id,title:`Privacidad y soporte · ${profile.nombre_publico||meta.title}`,canAuthorize:true});
    document.getElementById('kx-managed-privacy')?.addEventListener('click',openPrivacy);
    document.getElementById('kx-federation-connect')?.addEventListener('click',async e=>{const button=e.currentTarget;button.disabled=true;try{const out=await repos.payments.connectOnboarding('federation',profile.id);if(!out?.url)throw new Error('STRIPE_CONNECT_URL_MISSING');location.assign(out.url);}catch(error){button.disabled=false;setError(error);}});
    document.querySelector('[data-kx-migration-assist]')?.addEventListener('click',()=>openMigrationPreparation({profileId:profile.id,profileType:profile.tipo,onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps}),onSocial,onShowcase}));
    document.querySelector('[data-kx-management-assist]')?.addEventListener('click',()=>renderKombaxAssistHome({profileId:profile.id,profileType:profile.tipo,onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps}),onSocial,onShowcase}));
    document.querySelectorAll('[data-module]').forEach(button=>button.addEventListener('click',()=>{
      const mod=button.dataset.module;if(mod==='plans_services'&&['federacion','marca'].includes(profile.tipo))return renderPlanServices({audience:profile.tipo==='marca'?'brand':'federation',subjectType:'direct_profile',subjectId:profile.id,onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})});if(mod==='assist_management'&&['federacion','marca'].includes(profile.tipo))return renderKombaxAssistHome({profileId:profile.id,profileType:profile.tipo,onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps}),onSocial,onShowcase});if(mod==='social'&&onSocial)return onSocial();if(mod==='showcase'&&onShowcase)return onShowcase();if(mod==='events'&&onEvents)return onEvents();if((mod==='professional_operations'||mod==='representation_requests')&&onProfessionalOps)return onProfessionalOps(profile.id,profile.tipo);if(mod==='professional_finance')return renderProfessionalFinance(profile.id,{onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})});if(['federation_admin','federates','licenses','federation_team','affiliated_clubs'].includes(mod)&&profile.tipo==='federacion')return renderFederationAdmin(profile.id,{focus:mod,onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})});if(mod==='my_licenses'&&['competidor','profesional'].includes(profile.tipo))return renderSelfLicenses(profile.id,{contextLabel:profile.tipo==='competidor'?'MI COMPETIDOR':'MI ACTIVIDAD',onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})});if(mod==='account_licenses')return renderSelfLicenses(null,{contextLabel:'MI CUENTA',subjectLabel:'Mis licencias personales',onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})});if(mod==='authorized_licenses'&&profile.tipo==='profesional')return renderProfessionalLicenses(profile.id,{onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})});if(mod==='preparation'&&profile.tipo==='competidor')return renderCompetitionPreparation({competitorProfileId:profile.id,title:'Mis competiciones',onBack:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})});if(mod==='discovery_availability'&&['competidor','profesional'].includes(profile.tipo))return openDiscoveryAvailabilityEditor(profile,{onDone:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})});if(mod==='fight_opportunities'&&profile.tipo==='competidor')return openFighterOpportunityCenter(profile,{onDone:()=>renderManagedProfileHub(profileId,{onBack,onSocial,onShowcase,onEvents,onProfessionalOps})});if(['brand_business','brand_campaigns','brand_collaborations','brand_sponsorships','brand_analytics','brand_team'].includes(mod)&&profile.tipo==='marca')return openBrandBusinessHub(profile,{focus:mod==='brand_business'?'overview':mod.replace('brand_','')});if(mod==='brand_opportunities'&&['competidor','profesional'].includes(profile.tipo))return openBrandCollaborationCenter(profile);if(mod==='migration_guide'&&['federacion','marca'].includes(profile.tipo))return openMigrationGuide({profileId:profile.id,profileType:profile.tipo});if(mod==='privacy_support')return openPrivacy();
    }));
  }catch(error){setError(error);onBack?.();}
}

export function managedHubTitle(type){return HUB_META[type]?.title||'Mi perfil KOMBAX';}
