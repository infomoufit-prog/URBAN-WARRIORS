import { repos } from '../core/repositories.js';
import { esc, humanError } from '../core/utils.js';
import { openDetail, openForm, closeModal, confirmDialog, toast, setError } from '../ui/components.js';
import { resolveIdentityMedia } from '../core/identity-context.js';

export async function workspacePresentation(profile){
  const rows=await repos.kombaxProfiles.workspaceSettings(profile.id);
  const prefs=rows?.find(x=>x.profile_id===profile.id)||{};
  const [avatar,banner]=await Promise.all(['avatar','banner'].map(async kind=>prefs[`${kind}_path`]
    ?repos.kombaxProfiles.workspaceMediaUrl(prefs[`${kind}_path`]):resolveIdentityMedia(profile,kind)));
  return {...prefs,avatar,banner};
}

export function editWorkspacePresentation(profile,{onRefresh}={}){
  openForm({title:'Personalizar mi espacio',subtitle:'Foto o logo y banner privados del espacio de gestión. No modifican tu perfil público social.',
    fields:[{name:'kind',label:'Imagen',type:'select',required:true,value:'avatar',options:[{value:'avatar',label:'Foto / logo'},{value:'banner',label:'Banner'}]},
      {name:'file',label:'Archivo',type:'file',required:true,accept:'image/jpeg,image/png,image/webp',full:true,help:'JPG, PNG o WEBP de hasta 5 MB.'}],submitText:'Guardar imagen',
    onSubmit:async v=>{await repos.kombaxProfiles.uploadWorkspaceMedia(profile.id,v.kind,v.file);toast('Espacio actualizado');closeModal();await onRefresh?.();}});
}

export async function openProfileAdministration(profile,{onRefresh}={}){
  try{
    const [settings,requests]=await Promise.all([repos.kombaxProfiles.workspaceSettings(profile.id),repos.accountDeletion.list()]);
    const prefs=settings?.find(x=>x.profile_id===profile.id)||{},pending=(requests||[]).filter(x=>x.alcance==='profile'&&x.perfil_directo_id===profile.id&&!['cancelled','completed','rejected'].includes(x.estado));
    const modal=openDetail({title:`Gestionar identidad · ${profile.nombre_publico}`,subtitle:'Esta acción afecta a esta identidad, no a tu cuenta ni al resto de tus perfiles.',
      body:`<p>Archivar en Mi Espacio aparta esta tarjeta de la lista habitual. Puedes recuperarla buscando en «Archivados». No oculta contenido público ni cancela suscripciones.</p><p>La eliminación del perfil se solicita a administración y conserva la trazabilidad que corresponda.</p>${pending.map(x=>`<p><strong>Solicitud de eliminación:</strong> ${esc(x.estado)}</p>${['requested','needs_information'].includes(x.estado)?`<button class="btn btn-ghost" data-cancel-profile-request="${esc(x.id)}">Cancelar solicitud</button>`:''}`).join('')}`,
      actions:`${prefs.can_archive?`<button class="btn btn-ghost" data-archive-profile>${prefs.archived?'Recuperar en Mi Espacio':'Archivar en Mi Espacio'}</button>`:''}${prefs.can_delete&&!pending.length?'<button class="btn btn-danger" data-delete-profile>Solicitar eliminación del perfil</button>':''}<button class="btn btn-ghost" data-close-profile-admin>Cerrar</button>`});
    modal.wrap.querySelector('[data-close-profile-admin]')?.addEventListener('click',closeModal);
    modal.wrap.querySelector('[data-archive-profile]')?.addEventListener('click',()=>confirmDialog(prefs.archived?'Recuperar identidad':'Archivar identidad','Solo cambia la organización de Mi Espacio. El perfil público y los servicios contratados conservan su estado.',async()=>{
      await repos.kombaxProfiles.saveWorkspace(profile.id,'archive',!prefs.archived);toast(prefs.archived?'Identidad recuperada':'Identidad archivada en Mi Espacio');closeModal();await onRefresh?.();},{confirmText:prefs.archived?'Recuperar':'Archivar'}));
    modal.wrap.querySelector('[data-delete-profile]')?.addEventListener('click',()=>openForm({title:'Solicitar eliminación de esta identidad',subtitle:profile.nombre_publico,
      fields:[{name:'motivo',label:'Motivo (opcional)',type:'textarea',maxLength:1200,full:true}],submitText:'Enviar solicitud',
      onSubmit:async v=>{await repos.accountDeletion.request({alcance:'profile',perfil_directo_id:profile.id,motivo:v.motivo||''});toast('Solicitud de eliminación registrada');closeModal();await onRefresh?.();}}));
    modal.wrap.querySelectorAll('[data-cancel-profile-request]').forEach(b=>b.addEventListener('click',()=>confirmDialog('Cancelar solicitud','Esta identidad dejará de estar pendiente de eliminación.',async()=>{
      await repos.accountDeletion.cancel(b.dataset.cancelProfileRequest);toast('Solicitud cancelada');closeModal();await onRefresh?.();},{confirmText:'Cancelar solicitud'})));
  }catch(error){setError(error);}
}

export async function loadWorkspaceSummary(profile,workspace){
  const base=[['Personas del equipo',Array.isArray(workspace.managers)?new Set(workspace.managers.map(x=>x.perfil_id)).size:null],['Capacidades activas',Array.isArray(workspace.capabilities)?workspace.capabilities.length:null]];
  try{
    if(profile.tipo==='marca'){
      const data=await repos.brandBusiness.workspace(profile.id),s=data?.analytics;
      if(!s)throw new Error('Resumen no disponible.');
      return {metrics:[['Campañas',s.campaigns_total],['Campañas activas',s.campaigns_active],['Colaboraciones',s.proposals_total],['Propuestas pendientes',s.proposals_pending]],caption:'Actividad de tu marca',pending:s.proposals_pending};
    }
    if(profile.tipo==='federacion'){
      const data=await repos.federationLicenses.federationContext(profile.id),s=data?.kpis;
      if(!s)throw new Error('Resumen no disponible.');
      return {metrics:[['Federados activos',s.federates_active],['Solicitudes pendientes',s.licenses_pending],['Próximas a vencer',s.licenses_expiring],['Clubes relacionados',s.clubs_active]],caption:'Actividad de tu federación',pending:s.licenses_pending};
    }
    if(profile.tipo==='profesional'){
      const data=await repos.kombaxProfiles.professionalWorkspace(profile.id);
      return {metrics:[['Clientes',Array.isArray(data.clients)?data.clients.length:null],['Sesiones',Array.isArray(data.sessions)?data.sessions.length:null],['Credenciales',Array.isArray(data.credentials)?data.credentials.length:null],base[0]],caption:'Actividad profesional disponible para tu rol'};
    }
    return {metrics:base,caption:'Tu identidad y su equipo'};
  }catch(error){return {metrics:base,caption:'Resumen de identidad',unavailable:humanError(error)||'No se pudo consultar el resumen de actividad.'};}
}

export function workspaceSummaryHtml(summary,profile){
  return `<section class="kx-workspace-summary" aria-label="Resumen de actividad"><h2>${esc(summary.caption)}</h2><div class="kx-workspace-metrics">${summary.metrics.map(([label,value])=>`<article><strong>${Number.isFinite(Number(value))&&value!==null&&value!==undefined?esc(value):'—'}</strong><span>${esc(label)}</span></article>`).join('')}</div>${summary.unavailable?`<p role="status">${esc(summary.unavailable)}</p>`:''}<div class="kx-workspace-next"><strong>Acciones pendientes</strong><p>${profile.verificacion_estado!=='verificado'?'Completa la verificación de tu identidad para habilitar sus capacidades.':Number(summary.pending)>0?`${esc(summary.pending)} solicitudes o propuestas requieren tu revisión.`:'Consulta tus servicios y prepara tu próxima actividad.'}</p>${['marca','federacion'].includes(profile.tipo)?'<button class="btn btn-ghost btn-sm" data-module="plans_services">Ver servicios y activaciones</button>':profile.tipo==='profesional'?'<button class="btn btn-ghost btn-sm" data-module="professional_operations">Ver mi actividad</button>':''}</div></section>`;
}
