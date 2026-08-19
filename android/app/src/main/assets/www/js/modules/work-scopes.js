import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { esc } from '../core/utils.js';
import { pageHeader, card, empty, badge, openForm, confirmDialog, toast, setError, setMainHtml } from '../ui/components.js';

const financeLabel=value=>({none:'Sin acceso financiero',status:'Solo estado de pago',portfolio:'Mi cartera (importes)',collect:'Cartera + registrar cobros',receipts:'Cartera + cobros + recibos'}[value]||value||'Sin acceso financiero');
const memberName=row=>{const p=Array.isArray(row?.perfiles)?row.perfiles[0]:row?.perfiles;return `${p?.nombre||''} ${p?.apellidos||''}`.trim()||row?.perfil_id||'Miembro del equipo';};
const option=(value,label)=>({value,label});

export async function renderWorkScopes(){
  setMainHtml('<div class="loading-card">Cargando ámbitos y privacidad…</div>');
  try{
    const manager=['direccion','coordinacion'].includes(state.session?.rol);
    if(!manager){
      const ctx=await repos.scopes.context();
      const items=Array.isArray(ctx?.ambitos)?ctx.ambitos:[];
      setMainHtml(`${pageHeader('Mi ámbito','Alumnos, grupos y permisos asignados a tu cuenta','','Privacidad')}
        <div class="metrics"><div class="metric"><small>Nivel financiero</small><strong>${esc(financeLabel(ctx?.finance_level))}</strong></div><div class="metric"><small>Ámbitos</small><strong>${items.length}</strong></div><div class="metric"><small>Grupos heredados</small><strong>${Number(ctx?.legacy_groups||0)}</strong></div></div>
        ${items.length?items.map(a=>card(a.nombre,`<p>${badge(financeLabel(a.finance_level),a.finance_level==='none'?'neutral':'ok')}</p><p class="muted">${Number(a.alumnos||0)} alumnos · ${Number(a.grupos||0)} grupos</p>`)).join(''):empty('Sin ámbitos explícitos','Tus grupos principales antiguos siguen funcionando, pero el Gestor puede organizarte en ámbitos desde Configuración.')}`);
      return;
    }
    const [scopes,team,students,groups]=await Promise.all([repos.scopes.list(),repos.users.members(),repos.members.list(),repos.groups.list()]);
    const rows=Array.isArray(scopes)?scopes:[];
    const teamOptions=(team||[]).filter(x=>x.activo!==false&&(['direccion','secretaria','economia','comunicacion','monitor'].includes(x.rol)||x.coordinacion===true)).map(x=>option(x.perfil_id,`${memberName(x)} · ${x.coordinacion?'Coordinación':x.rol||'equipo'}`));
    const studentOptions=(students||[]).filter(x=>x.estado==='activo'||x.estado==='prealta').map(x=>option(x.id,`${x.apellidos||''}, ${x.nombre||''}`));
    const groupOptions=(groups||[]).filter(x=>x.activo!==false).map(x=>option(x.id,x.nombre));
    const scopeCard=a=>{
      const people=Array.isArray(a.equipo)?a.equipo:[],members=Array.isArray(a.socios)?a.socios:[],linkedGroups=Array.isArray(a.grupos)?a.grupos:[];
      return `<section class="card work-scope-card ${a.activo?'':'is-muted'}" data-scope="${esc(a.id)}">
        <div class="card-head"><div><div class="page-kicker">${esc(a.tipo||'monitor')}</div><h2 style="font-size:21px">${esc(a.nombre)}</h2><p class="muted">${esc(a.descripcion||'Ámbito operativo del club')}</p></div><div class="row-actions">${badge(a.activo?'Activo':'Archivado',a.activo?'ok':'neutral')}<button class="btn btn-ghost btn-sm edit-scope" data-id="${esc(a.id)}">Editar</button></div></div>
        <div class="grid-3">
          <div><small class="muted">EQUIPO</small>${people.length?people.map(p=>`<div class="scope-line"><span><strong>${esc(p.nombre||'Equipo')}</strong><small>${esc(financeLabel(p.finance_level))}${p.ver_contacto?' · contacto':''}</small></span><button class="icon-btn remove-scope-team" data-scope="${esc(a.id)}" data-target="${esc(p.perfil_id)}" title="Quitar">×</button></div>`).join(''):empty('Sin equipo')}</div>
          <div><small class="muted">ALUMNOS</small>${members.length?members.map(m=>`<div class="scope-line"><span><strong>${esc(m.nombre)}</strong><small>${m.principal?'Principal':'Compartido'}</small></span><button class="icon-btn remove-scope-student" data-scope="${esc(a.id)}" data-target="${esc(m.socio_id)}" title="Quitar">×</button></div>`).join(''):empty('Sin alumnos directos')}</div>
          <div><small class="muted">GRUPOS</small>${linkedGroups.length?linkedGroups.map(g=>`<div class="scope-line"><span><strong>${esc(g.nombre)}</strong><small>Incluye sus matrículas activas</small></span><button class="icon-btn remove-scope-group" data-scope="${esc(a.id)}" data-target="${esc(g.grupo_id)}" title="Quitar">×</button></div>`).join(''):empty('Sin grupos')}</div>
        </div>
        <div class="row-actions" style="margin-top:16px"><button class="btn btn-primary btn-sm add-scope-team" data-id="${esc(a.id)}">+ Equipo</button><button class="btn btn-ghost btn-sm add-scope-student" data-id="${esc(a.id)}">+ Alumno</button><button class="btn btn-ghost btn-sm add-scope-group" data-id="${esc(a.id)}">+ Grupo</button></div>
      </section>`;
    };
    setMainHtml(`${pageHeader('Ámbitos y privacidad','Separa alumnos, grupos y cartera financiera por monitor o equipo','<button class="btn btn-primary" id="new-scope">Nuevo ámbito</button>','Club')}
      <div class="alert alert-info"><strong>Privacidad por defecto</strong><span>Un monitor solo accede a alumnos/grupos asignados. Finanzas está desactivado hasta que el Gestor lo habilite expresamente por ámbito.</span></div>
      <div class="grid-2">${rows.length?rows.map(scopeCard).join(''):empty('Aún no hay ámbitos','Crea uno para separar las carteras de tus monitores.')}</div>`);
    const reload=()=>renderWorkScopes();
    const openScope=(a={activo:true,tipo:'monitor'})=>openForm({title:a.id?'Editar ámbito':'Nuevo ámbito',fields:[{name:'nombre',label:'Nombre',required:true,placeholder:'Ej. Equipo Bryan'},{name:'tipo',label:'Tipo',type:'select',value:'monitor',options:['monitor','equipo','sede','personalizado'].map(x=>option(x,x))},{name:'descripcion',label:'Descripción',type:'textarea',full:true},{name:'activo',label:'Ámbito activo',type:'checkbox',value:a.activo!==false}],initial:a,onSubmit:async v=>{await repos.scopes.mutate('ambito.save',{...v,id:a.id||null});toast('Ámbito guardado');await reload();}});
    document.getElementById('new-scope')?.addEventListener('click',()=>openScope());
    document.querySelectorAll('.edit-scope').forEach(b=>b.addEventListener('click',()=>openScope(rows.find(x=>x.id===b.dataset.id)||{})));
    document.querySelectorAll('.add-scope-team').forEach(b=>b.addEventListener('click',()=>openForm({title:'Asignar miembro del equipo',fields:[{name:'perfil_id',label:'Miembro',type:'select',required:true,options:teamOptions},{name:'finance_level',label:'Acceso financiero',type:'select',value:'none',options:['none','status','portfolio','collect','receipts'].map(x=>option(x,financeLabel(x)))},{name:'ver_contacto',label:'Puede ver teléfono/email operativo',type:'checkbox',value:false},{name:'gestionar_asistencia',label:'Puede gestionar asistencia',type:'checkbox',value:true},{name:'gestionar_seguimiento',label:'Puede registrar seguimiento',type:'checkbox',value:true},{name:'responsable',label:'Responsable del ámbito',type:'checkbox',value:false}],onSubmit:async v=>{await repos.scopes.mutate('ambito.team.set',{ambito_id:b.dataset.id,...v});toast('Permisos del equipo actualizados');await reload();}})));
    document.querySelectorAll('.add-scope-student').forEach(b=>b.addEventListener('click',()=>openForm({title:'Asignar alumno',fields:[{name:'socio_id',label:'Alumno',type:'select',required:true,options:studentOptions},{name:'principal',label:'Este es su ámbito principal',type:'checkbox',value:false}],onSubmit:async v=>{await repos.scopes.mutate('ambito.student.set',{ambito_id:b.dataset.id,...v});toast('Alumno asignado');await reload();}})));
    document.querySelectorAll('.add-scope-group').forEach(b=>b.addEventListener('click',()=>openForm({title:'Asignar grupo completo',subtitle:'Todos los alumnos con matrícula activa en este grupo quedarán dentro del alcance operativo.',fields:[{name:'grupo_id',label:'Grupo',type:'select',required:true,options:groupOptions}],onSubmit:async v=>{await repos.scopes.mutate('ambito.group.set',{ambito_id:b.dataset.id,...v});toast('Grupo asignado');await reload();}})));
    const bindRemove=(selector,operation,label)=>document.querySelectorAll(selector).forEach(b=>b.addEventListener('click',()=>confirmDialog(`Quitar ${label}`,`Se retirará el acceso derivado de este ámbito. Si la persona/alumno/grupo está asignado en otro ámbito, conservará ese acceso.`,async()=>{const payload={ambito_id:b.dataset.scope};payload[label==='miembro'?'perfil_id':label==='alumno'?'socio_id':'grupo_id']=b.dataset.target;await repos.scopes.mutate(operation,payload);toast('Asignación retirada');await reload();},{confirmText:'Quitar',danger:true})));
    bindRemove('.remove-scope-team','ambito.team.remove','miembro');bindRemove('.remove-scope-student','ambito.student.remove','alumno');bindRemove('.remove-scope-group','ambito.group.remove','grupo');
  }catch(error){setError(error);setMainHtml(`${pageHeader('Ámbitos y privacidad')} ${empty('No se pudieron cargar los ámbitos',error.message)}`);}
}
