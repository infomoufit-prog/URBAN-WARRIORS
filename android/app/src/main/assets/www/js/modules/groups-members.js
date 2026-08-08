import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { has } from '../core/permissions.js';
import { esc, byName, dateFmt, isoDate } from '../core/utils.js';
import { pageHeader, card, table, empty, badge, openForm, toast, setError, setMainHtml } from '../ui/components.js';

const DAYS=['','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
const bind=(selector,fn)=>document.querySelectorAll(selector).forEach(el=>el.addEventListener('click',()=>fn(el.dataset.id,el)));
const options=(rows,label=(r)=>r.nombre)=>rows.map(r=>({value:r.id,label:label(r)}));

function groupFields(disciplines, schedules=[]){
  const rows=[0,1,2,3,4,5,6].map(i=>schedules[i]||{});
  const f=[
    {name:'disciplina_id',label:'Disciplina',type:'select',required:true,options:options(disciplines.filter(d=>d.activa))},
    {name:'nombre',label:'Nombre',required:true},{name:'monitor_nombre',label:'Monitor/a'},{name:'sala',label:'Sala'},
    {name:'edad_min',label:'Edad mínima',type:'number',min:0},{name:'edad_max',label:'Edad máxima',type:'number',min:0},{name:'plazas',label:'Plazas',type:'number',min:1},{name:'activo',label:'Grupo activo',type:'checkbox',value:true}
  ];
  rows.forEach((r,i)=>{
    const n=i+1; f.push({name:`dia_${n}`,label:`Horario ${n} · día`,type:'select',options:DAYS.slice(1).map((d,j)=>({value:j+1,label:d})),value:r.dia_semana||''});
    f.push({name:`inicio_${n}`,label:`Horario ${n} · inicio`,type:'time',value:r.hora_inicio?.slice(0,5)||''});
    f.push({name:`fin_${n}`,label:`Horario ${n} · fin`,type:'time',value:r.hora_fin?.slice(0,5)||''});
  });
  return f;
}
function collectSchedules(v){
  const out=[];for(let i=1;i<=7;i++){if(v[`dia_${i}`]&&v[`inicio_${i}`]&&v[`fin_${i}`])out.push({dia_semana:Number(v[`dia_${i}`]),hora_inicio:v[`inicio_${i}`],hora_fin:v[`fin_${i}`]});}
  return out;
}

export async function renderGroups(){
  setMainHtml('<div class="loading-card">Cargando grupos…</div>');
  try{
    const [groups,schedules,disciplines]=await Promise.all([repos.groups.list(),repos.groups.schedules(),repos.catalog.disciplines()]);groups.sort(byName);const can=has(state.session,'group');
    const rows=groups.map(g=>{const d=disciplines.find(x=>x.id===g.disciplina_id);const hs=schedules.filter(h=>h.grupo_id===g.id).map(h=>`${DAYS[h.dia_semana]} ${String(h.hora_inicio).slice(0,5)}–${String(h.hora_fin).slice(0,5)}`).join('<br>');return `<tr><td><strong>${esc(g.nombre)}</strong><br><small>${esc(d?.nombre||'')}</small></td><td>${hs||'—'}</td><td>${esc(g.monitor_nombre||'—')}</td><td>${g.plazas??'—'}</td><td>${badge(g.activo?'Activo':'Inactivo',g.activo?'ok':'neutral')}</td><td>${can?`<button class="btn btn-ghost btn-sm edit-group" data-id="${esc(g.id)}">Editar</button>`:''}</td></tr>`});
    setMainHtml(`${pageHeader('Grupos y horarios','Gestión de clases regulares',can?'<button class="btn btn-primary" id="new-group">Nuevo grupo</button>':'')}${card('Grupos',rows.length?table(['Grupo','Horario','Monitor','Plazas','Estado','Acciones'],rows):empty('Sin grupos'))}`);
    const reload=()=>renderGroups(); const open=(g={})=>openForm({title:g.id?'Editar grupo':'Nuevo grupo',fields:groupFields(disciplines,schedules.filter(h=>h.grupo_id===g.id)),initial:g,onSubmit:async v=>{const clean={...g,...v,id:g.id||null,horarios:collectSchedules(v)};await repos.groups.save(clean);toast('Grupo guardado');await reload();},width:'840px'});
    document.getElementById('new-group')?.addEventListener('click',()=>open());bind('.edit-group',id=>open(groups.find(x=>x.id===id)));
  }catch(e){setError(e);setMainHtml(`${pageHeader('Grupos y horarios')} ${empty('No se pudieron cargar los grupos',e.message)}`)}
}

async function loadMemberRelations(){
  const [disciplines,grades,groups,tariffs]=await Promise.all([repos.catalog.disciplines(),repos.catalog.grades(),repos.groups.list(),repos.tariffs.list()]);
  return {disciplines,grades,groups,tariffs};
}
function memberFields(r){return [
  {name:'nombre',label:'Nombre',required:true},{name:'apellidos',label:'Apellidos',required:true},{name:'fecha_nacimiento',label:'Fecha de nacimiento',type:'date'},
  {name:'telefono',label:'Teléfono'},{name:'email',label:'Email',type:'email'},{name:'tutor_nombre',label:'Tutor/a'},
  {name:'disciplina_id',label:'Disciplina',type:'select',options:options(r.disciplines.filter(d=>d.activa))},{name:'grupo_id',label:'Grupo',type:'select',options:options(r.groups.filter(g=>g.activo))},
  {name:'grado_id',label:'Grado',type:'select',options:options(r.grades.filter(g=>g.activo),g=>`${r.disciplines.find(d=>d.id===g.disciplina_id)?.nombre||''} · ${g.nombre}`)},
  {name:'tarifa_id',label:'Tarifa',type:'select',options:options(r.tariffs.filter(t=>t.activa),t=>`${t.nombre} · ${Number(t.importe||0).toFixed(2)} €`)},
  {name:'estado',label:'Estado',type:'select',required:true,options:['prealta','activo','baja','suspendido'].map(x=>({value:x,label:x}))},
  {name:'contacto_emergencia',label:'Contacto de emergencia'},{name:'telefono_emergencia',label:'Teléfono emergencia'},{name:'notas_internas',label:'Notas internas',type:'textarea',full:true}
]}

export async function renderMembers(){
  setMainHtml('<div class="loading-card">Cargando alumnos…</div>');
  try{
    const [members,enrollments,relations,documents]=await Promise.all([repos.members.list(),repos.members.enrollments(),loadMemberRelations(),repos.documents.list().catch(()=>[])]);const can=has(state.session,'member');
    const rows=members.map(m=>{const links=enrollments.filter(x=>x.socio_id===m.id&&x.activa);const names=links.map(l=>relations.disciplines.find(d=>d.id===l.disciplina_id)?.nombre).filter(Boolean).join(', ');return `<tr><td><strong>${esc(m.apellidos)}, ${esc(m.nombre)}</strong><br><small>${esc(m.email||m.telefono||'')}</small></td><td>${esc(names||'—')}</td><td>${badge(m.estado,m.estado==='activo'?'ok':m.estado==='suspendido'?'warn':'neutral')}</td><td>${dateFmt(m.fecha_alta)}</td><td>${documents.filter(d=>d.socio_id===m.id).length}</td><td>${can?`<button class="btn btn-ghost btn-sm edit-member" data-id="${esc(m.id)}">Editar</button> <button class="btn btn-ghost btn-sm enroll-member" data-id="${esc(m.id)}">Matrícula</button> ${links.length?`<button class="btn btn-ghost btn-sm deactivate-enrollment" data-id="${esc(m.id)}">Baja matrícula</button>`:''} <button class="btn btn-ghost btn-sm graduate-member" data-id="${esc(m.id)}">Graduación</button> <button class="btn btn-ghost btn-sm document-member" data-id="${esc(m.id)}">Documento</button>`:''}</td></tr>`});
    setMainHtml(`${pageHeader('Alumnos','Ficha, matrículas y documentación',can?'<button class="btn btn-primary" id="new-member">Nuevo alumno</button>':'')}${card('Alumnos',rows.length?table(['Alumno','Disciplinas','Estado','Alta','Docs','Acciones'],rows):empty('Sin alumnos'))}`);
    const reload=()=>renderMembers();
    const openMember=(m={estado:'activo'})=>openForm({title:m.id?'Editar alumno':'Nuevo alumno',fields:memberFields(relations),initial:m,onSubmit:async v=>{await repos.members.save({...m,...v,id:m.id||null});toast('Alumno guardado');await reload();},width:'900px'});
    document.getElementById('new-member')?.addEventListener('click',()=>openMember());bind('.edit-member',id=>openMember(members.find(x=>x.id===id)));
    bind('.enroll-member',id=>openForm({title:'Añadir matrícula',subtitle:members.find(x=>x.id===id)?.nombre||'',fields:[{name:'disciplina_id',label:'Disciplina',type:'select',required:true,options:options(relations.disciplines.filter(d=>d.activa))},{name:'grupo_id',label:'Grupo',type:'select',required:true,options:options(relations.groups.filter(g=>g.activo))},{name:'tarifa_id',label:'Tarifa',type:'select',options:options(relations.tariffs.filter(t=>t.activa))}],onSubmit:async v=>{await repos.members.requestEnrollment(id,v.disciplina_id,v.grupo_id,v.tarifa_id);toast('Solicitud de matrícula registrada');await reload();}}));
    bind('.deactivate-enrollment',id=>{const links=enrollments.filter(x=>x.socio_id===id&&x.activa);openForm({title:'Desactivar matrícula',fields:[{name:'matricula_id',label:'Matrícula',type:'select',required:true,options:links.map(l=>({value:l.id,label:`${relations.disciplines.find(d=>d.id===l.disciplina_id)?.nombre||'Disciplina'} · ${relations.groups.find(g=>g.id===l.grupo_id)?.nombre||'Grupo'}`}))}],submitText:'Desactivar',onSubmit:async v=>{await repos.members.deactivateEnrollment(v.matricula_id);toast('Matrícula desactivada');await reload();}})});
    bind('.graduate-member',id=>openForm({title:'Registrar graduación',subtitle:members.find(x=>x.id===id)?.nombre||'',fields:[{name:'disciplina_id',label:'Disciplina',type:'select',required:true,options:options(relations.disciplines.filter(d=>d.activa))},{name:'grado_id',label:'Nuevo grado',type:'select',required:true,options:options(relations.grades.filter(g=>g.activo),g=>`${relations.disciplines.find(d=>d.id===g.disciplina_id)?.nombre||''} · ${g.nombre}`)},{name:'fecha',label:'Fecha',type:'date',required:true,value:isoDate()},{name:'examinador',label:'Examinador/a'},{name:'nota',label:'Nota',type:'textarea',full:true}],onSubmit:async v=>{await repos.members.graduation({...v,socio_id:id});toast('Graduación registrada');await reload();}}));
    bind('.document-member',id=>openForm({title:'Subir documento',fields:[{name:'nombre',label:'Nombre del documento'},{name:'tipo',label:'Tipo',type:'select',options:['autorizacion','medico','identidad','otro'].map(x=>({value:x,label:x}))},{name:'archivo',label:'Archivo',type:'file',required:true,accept:'.pdf,.jpg,.jpeg,.png,.webp'},{name:'visible_familia',label:'Visible para familia',type:'checkbox',value:true}],onSubmit:async v=>{await repos.documents.upload(id,v.archivo,{nombre:v.nombre||v.archivo.name,tipo:v.tipo||'otro',visible_familia:v.visible_familia});toast('Documento registrado');await reload();}}));
  }catch(e){setError(e);setMainHtml(`${pageHeader('Alumnos')} ${empty('No se pudieron cargar los alumnos',e.message)}`)}
}

export async function renderEnrollments(){
  setMainHtml('<div class="loading-card">Cargando preinscripciones…</div>');
  try{
    const [items,relations]=await Promise.all([repos.preenrollments.list(),loadMemberRelations()]);const can=has(state.session,'enrollmentManage');
    const rows=items.map(p=>`<tr><td><strong>${esc(p.apellidos)}, ${esc(p.nombre)}</strong><br><small>${esc(p.telefono||'')}</small></td><td>${esc(relations.disciplines.find(d=>d.id===p.disciplina_id)?.nombre||'—')}</td><td>${badge(p.estado,p.estado==='aprobada'?'ok':p.estado==='rechazada'?'danger':p.estado==='lista_espera'?'warn':'neutral')}</td><td>${dateFmt(p.creado_en)}</td><td>${can&&p.estado==='enviada'?`<div class="row-actions"><button class="btn btn-primary btn-sm approve-pre" data-id="${esc(p.id)}">Aprobar</button><button class="btn btn-ghost btn-sm wait-pre" data-id="${esc(p.id)}">Espera</button><button class="btn btn-ghost btn-sm reject-pre" data-id="${esc(p.id)}">Rechazar</button></div>`:''}</td></tr>`);
    setMainHtml(`${pageHeader('Preinscripciones','Solicitudes de alta y matrícula',can?'<button class="btn btn-primary" id="new-pre">Nueva preinscripción</button>':'')}${card('Solicitudes',rows.length?table(['Persona','Disciplina','Estado','Fecha','Acciones'],rows):empty('Sin preinscripciones'))}`);
    const reload=()=>renderEnrollments();
    document.getElementById('new-pre')?.addEventListener('click',()=>openForm({title:'Nueva preinscripción',fields:[{name:'tipo_solicitud',label:'Tipo',type:'select',required:true,value:'adulto',options:[{value:'adulto',label:'Adulto'},{value:'menor',label:'Menor'}]},{name:'nombre',label:'Nombre',required:true},{name:'apellidos',label:'Apellidos',required:true},{name:'fecha_nacimiento',label:'Fecha de nacimiento',type:'date'},{name:'telefono',label:'Teléfono',required:true},{name:'tutor_nombre',label:'Tutor/a'},{name:'tutor_email',label:'Email tutor',type:'email'},{name:'parentesco',label:'Parentesco'},{name:'disciplina_id',label:'Disciplina',type:'select',options:options(relations.disciplines.filter(d=>d.activa))},{name:'grupo_id',label:'Grupo',type:'select',options:options(relations.groups.filter(g=>g.activo))},{name:'tarifa_id',label:'Tarifa',type:'select',options:options(relations.tariffs.filter(t=>t.activa))},{name:'observaciones',label:'Observaciones',type:'textarea',full:true}],onSubmit:async v=>{await repos.preenrollments.create(v);toast('Preinscripción creada');await reload();}}));
    bind('.approve-pre',async(id,el)=>{el.disabled=true;try{await repos.preenrollments.approve(id);toast('Preinscripción aprobada');await reload();}catch(e){setError(e);el.disabled=false;}});
    const reasonAction=(selector,title,fn)=>bind(selector,id=>openForm({title,fields:[{name:'motivo',label:'Motivo',type:'textarea',full:true,required:title.includes('Rechazar')}],onSubmit:async v=>{await fn(id,v.motivo);toast('Estado actualizado');await reload();}}));
    reasonAction('.wait-pre','Pasar a lista de espera',repos.preenrollments.wait);reasonAction('.reject-pre','Rechazar preinscripción',repos.preenrollments.reject);
  }catch(e){setError(e);setMainHtml(`${pageHeader('Preinscripciones')} ${empty('No se pudieron cargar las solicitudes',e.message)}`)}
}
