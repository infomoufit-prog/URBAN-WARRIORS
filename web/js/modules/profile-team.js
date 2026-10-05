import {repos} from '../core/repositories.js';
import {esc,dateFmt,humanError} from '../core/utils.js';
import {openDetail,openForm,confirmDialog,toast} from '../ui/components.js';

const roles={admin:'Administración y equipos',editor:'Gestión y edición · operaciones privadas',comunicacion:'Comunicación y contenido'};
const statuses={pending:'Pendiente',accepted:'Aceptada',declined:'Rechazada',revoked:'Revocada',expired:'Vencida'};
const errorHtml=error=>`<div class="alert alert-error" role="alert">${esc(humanError(error))}</div>`;

export async function openProfileTeamInbox(){
 const modal=openDetail({title:'Invitaciones a equipos',subtitle:'Acepta con tu cuenta y tu correo confirmado.',body:'<div class="loading-card">Cargando invitaciones…</div>'});
 const body=modal.wrap.querySelector('.detail-modal-body');
 try{
  const rows=await repos.kombaxProfiles.teamInbox();
  if(!modal.wrap.isConnected)return;
  body.innerHTML=rows.length?rows.map(i=>`<article class="card"><h3>${esc(i.profile_name||'Perfil')}</h3><p>${esc(i.profile_type)} · ${esc(roles[i.role]||i.role)}</p><p>Válida hasta ${dateFmt(i.expires_at)}</p><div class="row-actions"><button type="button" class="btn btn-primary" data-team-accept="${esc(i.id)}">Aceptar invitación</button><button type="button" class="btn btn-ghost" data-team-decline="${esc(i.id)}">Rechazar</button></div><div data-team-result role="status"></div></article>`).join(''):'<p>No tienes invitaciones pendientes para el correo confirmado de esta cuenta.</p>';
  body.querySelectorAll('[data-team-accept],[data-team-decline]').forEach(button=>button.addEventListener('click',async()=>{
   const article=button.closest('article'),buttons=article.querySelectorAll('button');
   buttons.forEach(b=>b.disabled=true);
   try{
    const accepted=Boolean(button.dataset.teamAccept);
    await repos.kombaxProfiles.teamMutate(accepted?'team.accept':'team.decline',{invite_id:button.dataset.teamAccept||button.dataset.teamDecline});
    article.querySelector('[data-team-result]').textContent=accepted?'Invitación aceptada. La identidad aparecerá al volver a abrir Mi Espacio.':'Invitación rechazada.';
    buttons.forEach(b=>b.hidden=true);
   }catch(error){article.querySelector('[data-team-result]').textContent=humanError(error);buttons.forEach(b=>b.disabled=false);}
  }));
 }catch(error){if(modal.wrap.isConnected)body.innerHTML=errorHtml(error);}
}

export async function openProfileTeam(profile){
 const modal=openDetail({title:`Equipo · ${profile.nombre_publico||'Perfil'}`,subtitle:'Accesos propios de esta identidad. No comparte contraseñas ni transfiere su titularidad.',body:'<div class="loading-card">Cargando equipo…</div>'});
 const body=modal.wrap.querySelector('.detail-modal-body');
 const load=async()=>{
  try{
   const w=await repos.kombaxProfiles.teamWorkspace(profile.id);
   if(!modal.wrap.isConnected)return;
   if(w.profile_id!==profile.id)throw new Error('El equipo recibido no corresponde a la identidad seleccionada.');
   body.innerHTML=`<p>Solo administración puede invitar y revocar. Comunicación no incluye las operaciones privadas profesionales. Las funciones de licencias, catálogo y finanzas conservan sus permisos propios.</p><button type="button" class="btn btn-primary" data-team-invite>Invitar por correo</button><h3>Invitaciones</h3>${(w.invites||[]).map(i=>`<article class="card"><strong>${esc(i.email)}</strong><p>${esc(roles[i.role]||i.role)} · ${esc(statuses[i.status]||i.status)} · ${dateFmt(i.expires_at)}</p>${['pending','accepted'].includes(i.status)?`<button type="button" class="btn btn-danger btn-sm" data-team-revoke="${esc(i.id)}">Revocar</button>`:''}</article>`).join('')||'<p>No hay invitaciones.</p>'}<h3>Gestores</h3>${(w.managers||[]).map(m=>`<article class="card"><strong>${esc(m.nombre||'Gestor')}</strong><p>${esc(roles[m.rol]||m.rol)} · ${esc(m.estado)}</p>${m.rol!=='owner'&&m.perfil_id!==profile.perfil_id&&m.estado==='activo'?`<button type="button" class="btn btn-danger btn-sm" data-manager-revoke="${esc(m.perfil_id)}" data-role="${esc(m.rol)}">Retirar acceso</button>`:''}</article>`).join('')||'<p>No hay gestores delegados.</p>'}`;
   body.querySelector('[data-team-invite]')?.addEventListener('click',()=>openForm({title:'Invitar al equipo',subtitle:`${profile.nombre_publico||'Perfil'} · invitación válida durante siete días.`,fields:[{name:'email',label:'Correo del invitado',type:'email',required:true},{name:'role',label:'Permiso',type:'select',required:true,options:Object.entries(roles).map(([value,label])=>({value,label}))}],submitText:'Crear invitación',onSubmit:async values=>{
    await repos.kombaxProfiles.teamMutate('team.invite',{profile_id:profile.id,email:String(values.email).trim().toLowerCase(),role:values.role});
    toast('Invitación creada. El destinatario debe entrar con ese correo y abrir Invitaciones a equipos.');
    setTimeout(()=>openProfileTeam(profile),350);
   }}));
   body.querySelectorAll('[data-team-revoke],[data-manager-revoke]').forEach(button=>button.addEventListener('click',()=>confirmDialog('Retirar acceso','Este acceso dejará de permitir gestionar la identidad. No se elimina la cuenta del invitado.',async()=>{
    if(button.dataset.teamRevoke)await repos.kombaxProfiles.teamMutate('team.revoke',{invite_id:button.dataset.teamRevoke});
    else await repos.kombaxProfiles.setManager(profile.id,button.dataset.managerRevoke,button.dataset.role,'revocado');
    toast('Acceso revocado');setTimeout(()=>openProfileTeam(profile),350);
   },{confirmText:'Revocar acceso',danger:true})));
  }catch(error){if(modal.wrap.isConnected)body.innerHTML=errorHtml(error);}
 };
 await load();
}
