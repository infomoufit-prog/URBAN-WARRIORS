import { getLocale as kxGetLocale } from '../i18n/index.js';
import { localeTag as kxLocaleTag } from '../i18n/formatters.js';
import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { esc } from '../core/utils.js';
import { setAppHtml, setMainHtml, setPrivateViewHtml, openForm, openDetail, toast, setError, confirmDialog } from '../ui/components.js';
import { icon } from '../ui/icons.js';
import { migrationAssistBanner, openMigrationPreparation } from './customer-operations.js';
import { INTERNAL_LICENSE_FEDERATION_ID, isInternalClubLicense, publicClubFederations, federationLicenseLabel } from '../core/internal-club-license.js';

const ROLE_LABEL={presidencia:'Presidencia',secretaria:'Secretaría',tesoreria:'Tesorería',coordinacion:'Coordinación',junta_directiva:'Junta Directiva',colaborador:'Colaborador/a'};
const STATUS_LABEL={draft:'Borrador',pending:'Pendiente',submitted:'Enviada',under_review:'En revisión',needs_information:'Falta documentación',active:'Activa',rejected:'Rechazada',expired:'Vencida',suspended:'Suspendida',cancelled:'Cancelada'};
const STATUS_TONE={active:'ok',verified:'ok',submitted:'warn',under_review:'warn',pending:'warn',needs_information:'warn',expired:'bad',rejected:'bad',suspended:'bad',cancelled:'muted'};
const fmtDate=(v)=>v?new Intl.DateTimeFormat(kxLocaleTag(kxGetLocale()),{day:'2-digit',month:'2-digit',year:'numeric'}).format(new Date(`${String(v).slice(0,10)}T12:00:00`)):'—';
const caps=(rows=[])=>new Set((rows||[]).map(x=>x.clave||x.capacidad_clave).filter(Boolean));
const badge=(status)=>`<span class="kx-fed-state ${STATUS_TONE[status]||''}">${esc(STATUS_LABEL[status]||status||'—')}</span>`;

function shell(title,subtitle,body,onBack){
  setPrivateViewHtml(`<main class="kx-federation-admin"><header class="kx-fed-top"><button class="gateway-icon-button" id="kx-fed-back" type="button" aria-label="Volver">${icon('chevronLeft',{size:22})}</button><div><span>KOMBAX · ADMINISTRACIÓN FEDERATIVA</span><strong>${esc(title)}</strong><small>${esc(subtitle)}</small></div></header>${body}</main>`);
  document.getElementById('kx-fed-back')?.addEventListener('click',onBack);
}
function clubShell(title,subtitle,body,onBack){
  setMainHtml(`<main class="kx-federation-admin"><header class="kx-fed-top"><button class="gateway-icon-button" id="kx-fed-back" type="button" aria-label="Volver">${icon('chevronLeft',{size:22})}</button><div><span>MI CLUB · ADMINISTRACIÓN FEDERATIVA</span><strong>${esc(title)}</strong><small>${esc(subtitle)}</small></div></header>${body}</main>`);
  document.getElementById('kx-fed-back')?.addEventListener('click',onBack);
}
function accountShell(title,subtitle,body,onBack,contextLabel='MI CUENTA'){
  setMainHtml(`<main class="kx-federation-admin"><header class="kx-fed-top"><button class="gateway-icon-button" id="kx-fed-back" type="button" aria-label="Volver">${icon('chevronLeft',{size:22})}</button><div><span>${esc(contextLabel)} · LICENCIAS</span><strong>${esc(title)}</strong><small>${esc(subtitle)}</small></div></header>${body}</main>`);
  document.getElementById('kx-fed-back')?.addEventListener('click',onBack);
}
function kpis(items){return `<section class="kx-fed-kpis">${items.map(([label,value,help])=>`<article><small>${esc(label)}</small><strong>${esc(String(value??0))}</strong><span>${esc(help||'')}</span></article>`).join('')}</section>`;}
function privacyNotice(){return `<div class="kx-managed-boundary"><strong>Privacidad entre Federaciones activa</strong><p>Una Federación solo consulta su propia relación, sus federados, sus licencias y los documentos compartidos expresamente con ella. KOMBAX no revela otras afiliaciones del Club.</p></div>`;}

// F5B: Export exclusively rows returned by the permission-filtered federationContext RPC.
export function federationCsvCell(value){
 const raw=String(value??'').replace(/[\u0000-\u001f\u007f]/g,' ').trim();
 const guarded=/^[=+@-]/.test(raw)?`'${raw}`:raw;
 return `"${guarded.replace(/"/g,'""')}"`;
}
export function federationLicenseCsv(rows=[]){
 const columns=[['Deportista','holder_name'],['Club','club_name'],['Disciplina','discipline'],['Categoria','category'],['Temporada','season'],['Numero','license_number'],['Estado','status'],['Verificacion','verification_status'],['Vencimiento','expires_at']];
 return '\ufeff'+[columns.map(([label])=>federationCsvCell(label)).join(';'),...rows.map(row=>columns.map(([,key])=>federationCsvCell(row[key])).join(';'))].join('\r\n');
}
function downloadFederationCsv(rows,profileId){
 const blob=new Blob([federationLicenseCsv(rows)],{type:'text/csv;charset=utf-8'});
 const url=URL.createObjectURL(blob);
 const anchor=document.createElement('a');anchor.href=url;anchor.download=`kombax-federacion-licencias-${String(profileId).slice(0,8)}.csv`;
 anchor.click();setTimeout(()=>URL.revokeObjectURL(url),5000);
}


async function showLicenseDocuments(license,{federationProfileId=null,canShare=false}={}){
  try{
    const docs=await repos.federationLicenses.documents(license.id);
    const modal=openDetail({title:`Documentos · ${license.holder_name||'Licencia'}`,subtitle:`${license.discipline||''} · ${license.season||''}`,width:'760px',body:`<div class="kx-fed-doc-list">${docs.length?docs.map(d=>`<article><div><strong>${esc(d.file_name)}</strong><small>${esc(d.document_type||'Documento administrativo')} · ${esc(d.mime_type)}</small>${d.shared_with_federation?'<span class="kx-doc-shared">Compartido con Federación</span>':''}</div><div><button class="btn btn-ghost btn-sm" data-fed-doc-open="${esc(d.id)}">Ver documento</button>${canShare&&federationProfileId&&!d.shared_with_federation?`<button class="btn btn-primary btn-sm" data-fed-doc-share="${esc(d.id)}">Compartir con Federación</button>`:''}</div></article>`).join(''):'<p class="muted">No hay documentos adjuntos.</p>'}</div>`});
    modal.wrap.querySelectorAll('[data-fed-doc-open]').forEach(b=>b.addEventListener('click',async()=>{const d=docs.find(x=>String(x.id)===String(b.dataset.fedDocOpen));if(!d)return;try{const url=await repos.federationLicenses.documentUrl(d.storage_path);window.open(url,'_blank','noopener,noreferrer');}catch(e){setError(e);}}));
    modal.wrap.querySelectorAll('[data-fed-doc-share]').forEach(b=>b.addEventListener('click',async()=>{try{await repos.federationLicenses.mutate('federation.document.share',{document_id:b.dataset.fedDocShare,recipient_type:'federation',recipient_id:federationProfileId,purpose:'license_administration'});toast('Documento compartido con la Federación');modal.close?.();}catch(e){setError(e);}}));
  }catch(e){setError(e);}
}

export async function renderFederationAdmin(profileId,{onBack,focus='overview'}={}){
  shell('Mi Federación','Federados, licencias, clubes relacionados, documentación y equipo.',`<div class="loading-card">Cargando administración federativa…</div>`,onBack);
  try{
    const data=await repos.federationLicenses.federationContext(profileId);const c=caps(data.capabilities);const k=data.kpis||{};
    shell(data.profile?.name||'Mi Federación','Administración institucional de tu propia Federación.',`
      ${privacyNotice()}
      ${kpis([['Federados activos',k.federates_active,'Solo de esta Federación'],['Solicitudes pendientes',k.licenses_pending,'Pendientes de revisión'],['Próximas a vencer',k.licenses_expiring,'Siguientes 30 días'],['Clubes relacionados',k.clubs_active,'Solo relación propia']])}
      <section class="kx-fed-actions">${c.has('federation.team.manage')?'<button class="btn btn-primary" id="kx-fed-invite">+ Invitar al equipo</button>':''}<button class="btn btn-ghost" id="kx-fed-refresh">Actualizar</button></section>
      <section class="kx-fed-panel" id="kx-fed-licenses"><div class="kx-fed-heading"><div><span>MI FEDERACIÓN</span><h2>Federados y licencias</h2></div><small>${(data.licenses||[]).length} expedientes</small></div>
        ${c.has('federation.licenses.read')?`<div class="kx-fed-actions kx-fed-search"><label for="kx-fed-filter">Buscar por deportista, club o licencia</label><input id="kx-fed-filter" type="search" placeholder="Nombre, disciplina, club o temporada" autocomplete="off"><select id="kx-fed-status-filter" aria-label="Estado"><option value="">Todos los estados</option>${Object.entries(STATUS_LABEL).map(([code,label])=>`<option value="${esc(code)}">${esc(label)}</option>`).join('')}</select><button class="btn btn-ghost" id="kx-fed-export" type="button">Exportar CSV autorizado</button></div>${(data.licenses||[]).length>=500?'<p class="muted">Esta consulta tiene un límite de 500 licencias. La exportación es parcial; aplica filtros en origen para obtener un informe completo.</p>':''}`:''}

        <div class="kx-fed-table">${(data.licenses||[]).length?(data.licenses||[]).map(l=>`<article><div class="kx-fed-main"><strong>${esc(l.holder_name)}</strong><span>${esc(l.discipline)}${l.category?` · ${esc(l.category)}`:''}</span><small>${esc(l.license_number||'Sin número')} · ${esc(l.season)} · vence ${fmtDate(l.expires_at)}</small></div>${badge(l.status)}<div class="kx-fed-row-actions"><button class="btn btn-ghost btn-sm" data-fed-docs="${esc(l.id)}">Documentos (${Number(l.shared_documents||0)})</button>${c.has('federation.licenses.review')?`<button class="btn btn-ghost btn-sm" data-fed-review="${esc(l.id)}">Revisar</button>`:''}</div></article>`).join(''):'<div class="premium-empty compact"><strong>Sin licencias todavía</strong><p>Las solicitudes enviadas por clubes o deportistas aparecerán aquí.</p></div>'}</div>
      </section>
      ${c.has('federation.federates.read')?`<section class="kx-fed-panel" id="kx-fed-federates"><div class="kx-fed-heading"><div><span>DIRECTORIO AUTORIZADO</span><h2>Federados de mi Federación</h2></div><small>${(data.federates||[]).length} expedientes deportivos agrupados</small></div><div class="kx-fed-card-grid">${(data.federates||[]).length?(data.federates||[]).map(f=>`<article><strong>${esc(f.holder_name||'Deportista')}</strong><span>${Number(f.active_licenses||0)} licencias activas · ${Number(f.total_licenses||0)} históricas</span><small>Próximo vencimiento: ${fmtDate(f.next_expiry)}</small></article>`).join(''):'<p class="muted">Todavía no hay federados vinculados mediante licencias autorizadas.</p>'}</div></section>`:''}
      <section class="kx-fed-panel" id="kx-fed-clubs"><div class="kx-fed-heading"><div><span>RELACIÓN INSTITUCIONAL</span><h2>Clubes relacionados</h2></div><small>${(data.clubs||[]).length}</small></div><div class="kx-fed-card-grid">${(data.clubs||[]).length?(data.clubs||[]).map(x=>`<article><strong>${esc(x.club_name)}</strong><span>${esc(x.relationship_label||'Afiliado')}</span><small>${Number(x.federates||0)} federados activos en esta Federación</small></article>`).join(''):'<p class="muted">No hay clubes relacionados.</p>'}</div></section>
      <section class="kx-fed-panel" id="kx-fed-team"><div class="kx-fed-heading"><div><span>EQUIPO</span><h2>Equipo de Mi Federación</h2></div><small>${(data.team||[]).length} miembros</small></div><div class="kx-fed-team">${(data.team||[]).length?(data.team||[]).map(t=>`<article><div><strong>${esc(t.name||'Miembro')}</strong><span>${esc(ROLE_LABEL[t.role]||t.role)}</span><small>${(t.capabilities||[]).map(x=>esc(x)).join(' · ')}</small></div>${c.has('federation.team.manage')?`<button class="btn btn-ghost btn-sm" data-fed-revoke="${esc(t.perfil_id)}">Revocar</button>`:''}</article>`).join(''):'<p class="muted">No hay miembros adicionales.</p>'}</div>${(data.invitations||[]).some(i=>i.status==='pending')?`<div class="kx-fed-pending"><strong>Invitaciones pendientes</strong>${data.invitations.filter(i=>i.status==='pending').map(i=>`<span>${esc(i.email)} · ${esc(ROLE_LABEL[i.role]||i.role)} · ${esc(i.email_status)}</span>`).join('')}</div>`:''}</section>
    `,onBack);
    const focusTarget=focus==='federation_team'?'kx-fed-team':focus==='affiliated_clubs'?'kx-fed-clubs':focus==='federates'?'kx-fed-federates':focus==='licenses'?'kx-fed-licenses':null;
    if(focusTarget)requestAnimationFrame(()=>document.getElementById(focusTarget)?.scrollIntoView({behavior:'smooth',block:'start'}));
    document.getElementById('kx-fed-refresh')?.addEventListener('click',()=>renderFederationAdmin(profileId,{onBack,focus}));
    const filterFederationRows=()=>{
      const query=String(document.getElementById('kx-fed-filter')?.value||'').trim().toLocaleLowerCase();
      const status=String(document.getElementById('kx-fed-status-filter')?.value||'');
      return (data.licenses||[]).filter(l=>(!status||l.status===status)&&(!query||[l.holder_name,l.club_name,l.discipline,l.season,l.license_number].some(v=>String(v||'').toLocaleLowerCase().includes(query))));
    };
    const filterFederationUi=()=>{
      const ids=new Set(filterFederationRows().map(l=>String(l.id)));
      document.querySelectorAll('#kx-fed-licenses [data-fed-docs]').forEach(b=>{
        const row=b.closest('article');if(row)row.hidden=!ids.has(String(b.dataset.fedDocs));
      });
    };
    document.getElementById('kx-fed-filter')?.addEventListener('input',filterFederationUi);
    document.getElementById('kx-fed-status-filter')?.addEventListener('change',filterFederationUi);
    document.getElementById('kx-fed-export')?.addEventListener('click',()=>{
      const rows=filterFederationRows();if(!rows.length){toast('No hay expedientes autorizados que coincidan con el filtro.','warning');return;}
      downloadFederationCsv(rows,profileId);toast(`Informe de ${rows.length} licencias generado sobre los datos autorizados.`);
    });

    document.getElementById('kx-fed-invite')?.addEventListener('click',()=>openForm({title:'Invitar al equipo de la Federación',subtitle:'La invitación es personal, caduca y cada rol recibe únicamente sus capacidades.',fields:[{name:'name',label:'Nombre'},{name:'email',label:'Email',type:'email',required:true},{name:'role',label:'Rol',type:'select',required:true,options:Object.entries(ROLE_LABEL).map(([value,label])=>({value,label}))}],submitText:'Crear y enviar invitación',onSubmit:async v=>{const out=await repos.federationLicenses.mutate('federation.team.invite',{federation_profile_id:profileId,email:v.email,name:v.name||'',role:v.role});const id=out?.id;let sent=false;if(id){try{await repos.federationLicenses.sendInvitation(id);sent=true;}catch{}}toast(sent?'Invitación enviada':'Invitación creada; el correo queda pendiente de reintento');await renderFederationAdmin(profileId,{onBack,focus});}}));
    document.querySelectorAll('[data-fed-review]').forEach(b=>b.addEventListener('click',()=>{const l=(data.licenses||[]).find(x=>String(x.id)===String(b.dataset.fedReview));openForm({title:'Revisar licencia',subtitle:`${l?.holder_name||''} · ${l?.discipline||''}`,fields:[{name:'status',label:'Nuevo estado',type:'select',required:true,options:[['under_review','En revisión'],['needs_information','Solicitar documentación'],['active','Aprobar / Activa'],['rejected','Rechazar'],['suspended','Suspender'],['expired','Marcar vencida'],['cancelled','Cancelar']].map(([value,label])=>({value,label}))},{name:'administrative_note',label:'Observación administrativa',type:'textarea',rows:3,full:true}],submitText:'Guardar estado',onSubmit:async v=>{await repos.federationLicenses.mutate('federation.license.review',{license_id:l.id,status:v.status,administrative_note:v.administrative_note||''});toast('Licencia actualizada');await renderFederationAdmin(profileId,{onBack,focus});}});}));
    document.querySelectorAll('[data-fed-docs]').forEach(b=>b.addEventListener('click',()=>{const l=(data.licenses||[]).find(x=>String(x.id)===String(b.dataset.fedDocs));if(l)showLicenseDocuments(l,{federationProfileId:profileId,canShare:false});}));
    document.querySelectorAll('[data-fed-revoke]').forEach(b=>b.addEventListener('click',()=>confirmDialog('Revocar acceso federativo','El miembro perderá inmediatamente el acceso derivado de este equipo.',async()=>{await repos.federationLicenses.mutate('federation.team.revoke',{federation_profile_id:profileId,perfil_id:b.dataset.fedRevoke});toast('Acceso revocado');await renderFederationAdmin(profileId,{onBack,focus});},{confirmText:'Revocar',danger:true})));
  }catch(e){setError(e);}
}

export async function renderClubFederationAdmin(clubId,{onBack}={}){
  clubShell('Federaciones y licencias','Gestiona registros internos del club y licencias federativas por separado.',`<div class="loading-card">Cargando licencias del Club…</div>`,onBack);
  try{
    const [data,directory]=await Promise.all([repos.federationLicenses.clubContext(clubId),repos.federationLicenses.directory('',150)]);const rel=publicClubFederations(data.relationships||[]);const licenses=data.licenses||[];const internalLicenses=licenses.filter(isInternalClubLicense);
    clubShell('Federaciones y licencias','Las afiliaciones se administran de forma privada y no se publican automáticamente.',`
      ${migrationAssistBanner({title:'¿Tienes licencias o federados en Excel, PDF o imágenes?',body:'KOMBAX Migrations usa IA asistida para ayudarte a cargar y revisar datos federativos sin empezar de cero. La importación solo se confirma después de una vista previa.'})}
      ${privacyNotice()}
      ${kpis([['Federaciones vinculadas',rel.filter(x=>x.status==='active').length,'Solo federaciones reales'],['Licencias activas',licenses.filter(x=>x.status==='active').length,'Deportistas del Club'],['Pendientes',licenses.filter(x=>['pending','submitted','under_review','needs_information'].includes(x.status)).length,'Necesitan seguimiento'],['Próximas a vencer',licenses.filter(x=>x.status==='active'&&x.expires_at&&new Date(x.expires_at)<=new Date(Date.now()+30*86400000)).length,'Siguientes 30 días']])}
      <section class="kx-fed-actions"><button class="btn btn-primary" id="kx-club-new-internal-license">+ Registro interno del club</button><button class="btn btn-ghost" id="kx-club-add-fed">+ Añadir Federación</button><button class="btn btn-ghost" id="kx-club-new-license" ${rel.some(r=>r.status==='active')?'':'disabled title="Primero vincula una federación real"'}>+ Licencia federativa</button><button class="btn btn-ghost" id="kx-club-my-licenses">Mis licencias personales</button><button class="btn btn-ghost" id="kx-club-fed-refresh">Actualizar</button></section>
      <section class="kx-fed-panel"><div class="kx-fed-heading"><div><span>RELACIONES PRIVADAS</span><h2>Mis Federaciones</h2></div><small>${rel.length}</small></div><div class="kx-fed-card-grid">${rel.length?rel.map(r=>`<article><strong>${esc(r.federation_name)}</strong><span>${esc(r.relationship_label||'Afiliado')}</span>${badge(r.status)}<small>${esc(r.private_note||'Relación administrativa privada')}</small></article>`).join(''):'<p class="muted">Todavía no hay Federaciones relacionadas.</p>'}</div></section>
      <section class="kx-fed-panel"><div class="kx-fed-heading"><div><span>REGISTROS INTERNOS Y FEDERATIVOS</span><h2>Licencias y registros del club</h2></div><small>${licenses.length} expedientes · ${internalLicenses.length} internos</small></div><p class="muted">Los registros internos no acreditan licencias federativas y sus documentos permanecen privados.</p><div class="kx-fed-table">${licenses.length?licenses.map(l=>`<article><div class="kx-fed-main"><strong>${esc(l.holder_name)}</strong><span>${esc(federationLicenseLabel(l))} · ${esc(l.discipline)}</span><small>${esc(l.license_number||'Sin número')} · ${esc(l.season)} · vence ${fmtDate(l.expires_at)}</small></div>${isInternalClubLicense(l)?'<span class="kx-fed-state">Registro interno · Sin verificación federativa</span>':badge(l.status)}<div class="kx-fed-row-actions"><button class="btn btn-ghost btn-sm" data-club-fed-docs="${esc(l.id)}">Documentos</button>${!isInternalClubLicense(l)&&['draft','pending','needs_information'].includes(l.status)?`<button class="btn btn-primary btn-sm" data-club-fed-submit="${esc(l.id)}">Enviar a Federación</button>`:''}<button class="btn btn-ghost btn-sm" data-club-fed-upload="${esc(l.id)}">Adjuntar</button></div></article>`).join(''):'<div class="premium-empty compact"><strong>Sin licencias</strong><p>Crea un registro interno del club o vincula una federación para registrar una licencia federativa.</p></div>'}</div></section>
    `,onBack);
    document.querySelector('[data-kx-migration-assist]')?.addEventListener('click',openMigrationPreparation);
    document.getElementById('kx-club-fed-refresh')?.addEventListener('click',()=>renderClubFederationAdmin(clubId,{onBack}));
    document.getElementById('kx-club-my-licenses')?.addEventListener('click',()=>renderSelfLicenses(null,{embedded:true,contextLabel:'FEDERACIONES Y LICENCIAS',subjectLabel:'Mis licencias',onBack:()=>renderClubFederationAdmin(clubId,{onBack})}));
    document.getElementById('kx-club-add-fed')?.addEventListener('click',()=>openForm({title:'Añadir Federación al Club',subtitle:'Esta relación será privada. Otras Federaciones no podrán descubrirla.',fields:[{name:'federation_profile_id',label:'Federación',type:'select',required:true,options:(directory||[]).filter(f=>!rel.some(r=>String(r.federation_profile_id)===String(f.id))).map(f=>({value:f.id,label:f.nombre_publico}))},{name:'relationship_label',label:'Tipo de relación',value:'afiliado'},{name:'private_note',label:'Nota interna',type:'textarea',rows:3,full:true}],submitText:'Guardar relación',onSubmit:async v=>{await repos.federationLicenses.saveRelationship(v.federation_profile_id,clubId,'active',v.relationship_label||'afiliado',v.private_note||'');toast('Federación añadida de forma privada');await renderClubFederationAdmin(clubId,{onBack});}}));
    const openLicenseCreation=(internal=false)=>{
      const activeRelations=rel.filter(r=>r.status==='active');
      if(!internal&&!activeRelations.length){toast('Primero vincula una federación real para crear una licencia federativa. También puedes registrar una licencia interna sin federación.','warning');return;}
      const eligibleMembers=(data.members||[]).filter(m=>m.socio_id);
      if(!eligibleMembers.length){toast('Primero registra un alumno en Mi Club. No necesita tener grupo ni disciplina asignados.','warning');return;}
      openForm({
        title:internal?'Registrar licencia interna del club':'Crear expediente federativo',
        subtitle:internal?'Registro administrativo propio. No representa una licencia federativa y no se compartirá con federaciones.':'La Federación vinculada valida las licencias federativas. Los documentos no se comparten sin confirmación.',
        fields:[
          ...(!internal?[{name:'federation_profile_id',label:'Federación',type:'select',required:true,options:activeRelations.map(r=>({value:r.federation_profile_id,label:r.federation_name}))}]:[]),
          {name:'holder_club_member_id',label:'Deportista',type:'select',required:true,options:eligibleMembers.map(m=>({value:m.socio_id,label:m.name}))},
          {name:'discipline',label:'Disciplina de la licencia',required:true},
          {name:'category',label:'Categoría (opcional)'},
          {name:'season',label:'Temporada',required:true,value:String(new Date().getFullYear())},
          {name:'license_number',label:'Número o referencia (opcional)'},
          {name:'valid_from',label:'Válida desde (opcional)',type:'date'},
          {name:'expires_at',label:'Vencimiento (opcional)',type:'date'}
        ],
        submitText:internal?'Guardar registro interno':'Crear expediente federativo',
        onSubmit:async v=>{
          const m=eligibleMembers.find(x=>String(x.socio_id)===String(v.holder_club_member_id));
          if(!m)throw new Error('Selecciona un deportista válido.');
          const federationId=internal?INTERNAL_LICENSE_FEDERATION_ID:v.federation_profile_id;
          if(!internal&&!activeRelations.some(r=>String(r.federation_profile_id)===String(federationId)))throw new Error('Selecciona una federación vinculada.');
          await repos.federationLicenses.mutate('federation.license.save',{
            federation_profile_id:federationId,club_id:clubId,
            holder_club_member_id:m.socio_id,holder_profile_id:m.perfil_id||null,
            holder_name:m.name||'Deportista',discipline:v.discipline,
            category:v.category||'',season:v.season,license_number:v.license_number||'',
            valid_from:v.valid_from||null,expires_at:v.expires_at||null,
            status:'draft',verification_status:'pending'
          });
          toast(internal?'Registro interno guardado sin vincular ninguna federación.':'Expediente federativo creado. Pendiente de envío y validación.');
          await renderClubFederationAdmin(clubId,{onBack});
        }
      });
    };
    document.getElementById('kx-club-new-internal-license')?.addEventListener('click',()=>openLicenseCreation(true));
    document.getElementById('kx-club-new-license')?.addEventListener('click',()=>openLicenseCreation(false));
    document.querySelectorAll('[data-club-fed-submit]').forEach(b=>b.addEventListener('click',()=>confirmDialog('Enviar licencia','La Federación recibirá el expediente para revisión.',async()=>{await repos.federationLicenses.mutate('federation.license.submit',{license_id:b.dataset.clubFedSubmit});toast('Expediente enviado a la Federación');await renderClubFederationAdmin(clubId,{onBack});},{confirmText:'Enviar'})));
    document.querySelectorAll('[data-club-fed-upload]').forEach(b=>b.addEventListener('click',()=>{const l=licenses.find(x=>String(x.id)===String(b.dataset.clubFedUpload));if(!l)return;const internal=isInternalClubLicense(l);openForm({title:'Adjuntar documentación',subtitle:`${l.holder_name||''} · los archivos permanecen privados hasta una autorización expresa.`,fields:[{name:'file',label:'PDF o imagen',type:'file',required:true,accept:'application/pdf,image/jpeg,image/png',help:'Máximo 10 MB.'},{name:'document_type',label:'Tipo de documento',value:'license_document'},...(!internal?[{name:'share',label:'Compartir expresamente con esta Federación',type:'checkbox',value:false,full:true}]:[])],submitText:'Subir documento privado',onSubmit:async v=>{const d=await repos.federationLicenses.uploadDocument(l.id,v.file,{documentType:v.document_type||'administrative'});if(!internal&&v.share){await repos.federationLicenses.mutate('federation.document.share',{document_id:d.id,recipient_type:'federation',recipient_id:l.federation_profile_id,purpose:'license_administration'});}toast(!internal&&v.share?'Documento compartido expresamente':'Documento guardado de forma privada');await renderClubFederationAdmin(clubId,{onBack});}});}));
    document.querySelectorAll('[data-club-fed-docs]').forEach(b=>b.addEventListener('click',()=>{const l=licenses.find(x=>String(x.id)===String(b.dataset.clubFedDocs));if(l)showLicenseDocuments(l,{federationProfileId:isInternalClubLicense(l)?null:l.federation_profile_id,canShare:!isInternalClubLicense(l)});}));
  }catch(e){setError(e);}
}

export async function renderSelfLicenses(profileId,{onBack,embedded=false,contextLabel='MI CUENTA',subjectLabel='Mis licencias'}={}){
  const draw=(title,subtitle,body)=>embedded?accountShell(title,subtitle,body,onBack,contextLabel):shell(title,subtitle,body,onBack);
  draw(subjectLabel,'Tus licencias federativas y registros internos permanecen bajo control de las organizaciones autorizadas.',`<div class="loading-card">Cargando tus licencias…</div>`);
  try{
    const data=await repos.federationLicenses.self(profileId);const rows=data.licenses||[];
    draw(subjectLabel,'Consulta estado, origen del registro, temporada, vencimiento y documentación.',`${privacyNotice()}<section class="kx-fed-panel"><div class="kx-fed-heading"><div><span>${esc(contextLabel)}</span><h2>Historial de licencias</h2></div><small>${rows.length}</small></div><div class="kx-fed-table">${rows.length?rows.map(l=>`<article><div class="kx-fed-main"><strong>${esc(federationLicenseLabel(l))}</strong><span>${esc(l.discipline)}${l.category?` · ${esc(l.category)}`:''}</span><small>${esc(l.license_number||'Sin número')} · ${esc(l.season)} · vence ${fmtDate(l.expires_at)}</small></div>${badge(l.status)}<button class="btn btn-ghost btn-sm" data-self-docs="${esc(l.id)}">Documentos</button></article>`).join(''):'<p class="muted">No tienes licencias federativas registradas todavía.</p>'}</div></section>`);
    document.querySelectorAll('[data-self-docs]').forEach(b=>b.addEventListener('click',()=>{const l=rows.find(x=>String(x.id)===String(b.dataset.selfDocs));if(l)showLicenseDocuments(l);}));
  }catch(e){
    if(embedded){
      draw(subjectLabel,'No se han podido cargar tus licencias.',`<section class="kx-fed-panel"><div class="premium-empty compact"><strong>Error al cargar licencias</strong><p>${esc(e?.message||'No se ha podido consultar la documentación federativa.')}</p></div></section>`);
    }else setError(e);
  }
}

export async function renderProfessionalLicenses(profileId,{onBack}={}){
  shell('Licencias autorizadas','Solo aparecen deportistas con compartición explícita o delegación válida.',`<div class="loading-card">Cargando licencias autorizadas…</div>`,onBack);
  try{const data=await repos.federationLicenses.professional(profileId);const rows=data.licenses||[];shell('Licencias autorizadas','Una relación profesional no abre automáticamente las licencias de un deportista.',`${privacyNotice()}<section class="kx-fed-panel"><div class="kx-fed-heading"><div><span>MI ACTIVIDAD</span><h2>Licencias con acceso autorizado</h2></div><small>${rows.length}</small></div><div class="kx-fed-table">${rows.length?rows.map(l=>`<article><div class="kx-fed-main"><strong>${esc(l.holder_name)}</strong><span>${esc(federationLicenseLabel(l))} · ${esc(l.discipline)}</span><small>${esc(l.access_origin==='explicit_share'?'Compartida expresamente':'Delegación de Manager')} · ${esc(l.season)}</small></div>${badge(l.status)}</article>`).join(''):'<p class="muted">No hay licencias autorizadas para este Perfil Profesional.</p>'}</div></section>`,onBack);}catch(e){setError(e);}
}

export async function renderPendingFederationInvitations({container,onChanged}={}){
  const root=typeof container==='string'?document.querySelector(container):container;if(!root)return;
  try{const rows=await repos.federationLicenses.pendingInvitations();if(!rows.length){root.innerHTML='';return;}root.innerHTML=`<section class="kx-fed-account-invites"><div><span>INVITACIONES</span><h2>Equipo federativo pendiente</h2></div>${rows.map(i=>`<article><div><strong>${esc(i.federation_name)}</strong><span>${esc(ROLE_LABEL[i.role]||i.role)} · caduca ${fmtDate(i.expires_at)}</span></div><div><button class="btn btn-primary btn-sm" data-fed-invite-accept="${esc(i.id)}">Aceptar</button><button class="btn btn-ghost btn-sm" data-fed-invite-reject="${esc(i.id)}">Rechazar</button></div></article>`).join('')}</section>`;root.querySelectorAll('[data-fed-invite-accept]').forEach(b=>b.addEventListener('click',async()=>{try{await repos.federationLicenses.mutate('federation.team.respond',{invitation_id:b.dataset.fedInviteAccept,status:'accepted'});toast('Invitación aceptada');await onChanged?.();}catch(e){setError(e);}}));root.querySelectorAll('[data-fed-invite-reject]').forEach(b=>b.addEventListener('click',async()=>{try{await repos.federationLicenses.mutate('federation.team.respond',{invitation_id:b.dataset.fedInviteReject,status:'rejected'});toast('Invitación rechazada');await onChanged?.();}catch(e){setError(e);}}));}catch{root.innerHTML='';}
}
