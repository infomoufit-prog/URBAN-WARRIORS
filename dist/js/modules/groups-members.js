import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { has } from '../core/permissions.js';
import { esc, byName, dateFmt, isoDate } from '../core/utils.js';
import { pageHeader, progress, quickRow, card, table, empty, badge, openForm, toast, setError, setMainHtml } from '../ui/components.js';
import { icon } from '../ui/icons.js';

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
    const [allGroups,schedules,disciplines,enrollments]=await Promise.all([repos.groups.list(),repos.groups.schedules(),repos.catalog.disciplines(),repos.members.enrollments()]);const groups=state.session?.rol==='monitor'?allGroups.filter(g=>g.monitor_principal_id===state.session?.id):allGroups;groups.sort(byName);const can=has(state.session,'group');
    const cards=groups.map(g=>{const d=disciplines.find(x=>x.id===g.disciplina_id);const hs=schedules.filter(h=>h.grupo_id===g.id).map(h=>`${DAYS[h.dia_semana]} ${String(h.hora_inicio).slice(0,5)}–${String(h.hora_fin).slice(0,5)}`);const count=new Set(enrollments.filter(e=>e.grupo_id===g.id&&e.activa).map(e=>e.socio_id)).size;const cap=Number(g.plazas||0),pct=cap?Math.min(100,Math.round(count/cap*100)):0;return `<section class="card"><div class="card-head"><div><div class="page-kicker">${esc(d?.nombre||'Disciplina')}</div><h2 style="font-size:20px">${esc(g.nombre)}</h2></div><div class="row-actions">${badge(g.activo?'Activo':'Inactivo',g.activo?'ok':'neutral')}${can?`<button class="btn btn-ghost btn-sm edit-group" data-id="${esc(g.id)}">Editar</button>`:''}</div></div><div class="grid-2" style="gap:12px"><div><small class="muted">HORARIOS</small><p style="line-height:1.7;margin:8px 0 0">${hs.length?hs.map(esc).join('<br>'):'—'}</p></div><div><small class="muted">MONITOR / SALA</small><p style="line-height:1.7;margin:8px 0 0">${esc(g.monitor_nombre||'Sin asignar')}<br>${esc(g.sala||'—')}</p></div></div><div style="margin-top:18px;display:flex;justify-content:space-between;align-items:end"><div><small class="muted">OCUPACIÓN</small><strong style="display:block;font-size:24px;margin-top:4px">${count}/${g.plazas||'—'}</strong></div><span class="muted">${pct}%</span></div>${progress(pct)}</section>`}).join('');
    setMainHtml(`${pageHeader(state.session?.rol==='monitor'?'Mis grupos':'Grupos y horarios',state.session?.rol==='monitor'?'Grupos asignados a tu perfil':'Clases regulares, ocupación y responsables',can?'<button class="btn btn-primary" id="new-group">Nuevo grupo</button>':'','Club')}<div class="grid-2">${cards||empty('Sin grupos')}</div>`);
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
    const rowFor=(m)=>{const links=enrollments.filter(x=>x.socio_id===m.id&&x.activa);const names=links.map(l=>relations.disciplines.find(d=>d.id===l.disciplina_id)?.nombre).filter(Boolean).join(', ');const groups=links.map(l=>relations.groups.find(g=>g.id===l.grupo_id)?.nombre).filter(Boolean).join(', ');return `<tr data-member-row data-search="${esc(`${m.nombre} ${m.apellidos} ${m.email||''} ${m.telefono||''} ${names} ${groups}`.toLowerCase())}" data-status="${esc(m.estado)}"><td><strong>${esc(m.apellidos)}, ${esc(m.nombre)}</strong><br><small>${esc(m.email||m.telefono||'')}</small></td><td>${esc(names||'—')}<br><small>${esc(groups||'')}</small></td><td>${badge(m.estado,m.estado==='activo'?'ok':m.estado==='suspendido'?'warn':'neutral')}</td><td>${dateFmt(m.fecha_alta)}</td><td>${documents.filter(d=>d.socio_id===m.id).length}</td><td>${can?`<div class="row-actions"><button class="btn btn-ghost btn-sm edit-member" data-id="${esc(m.id)}">Editar</button><button class="btn btn-ghost btn-sm enroll-member" data-id="${esc(m.id)}">Matrícula</button>${links.length?`<button class="btn btn-ghost btn-sm deactivate-enrollment" data-id="${esc(m.id)}">Baja</button>`:''}<button class="btn btn-ghost btn-sm graduate-member" data-id="${esc(m.id)}">Graduación</button><button class="btn btn-ghost btn-sm document-member" data-id="${esc(m.id)}">Documento</button></div>`:''}</td></tr>`};
    setMainHtml(`${pageHeader('Alumnos','Fichas, matrículas, grados y documentación',can?'<button class="btn btn-primary" id="new-member">Nuevo alumno</button>':'','Gestión')}<div class="filter-bar"><input id="member-search" type="search" placeholder="Buscar por nombre, email, disciplina o grupo…"><select id="member-status"><option value="">Todos los estados</option>${['activo','prealta','suspendido','baja'].map(x=>`<option value="${x}">${x}</option>`).join('')}</select><span class="badge badge-neutral" id="member-count">${members.length} alumnos</span></div>${card('Alumnos',members.length?table(['Alumno','Actividad','Estado','Alta','Docs','Acciones'],members.map(rowFor)):empty('Sin alumnos'))}`);
    const applyFilter=()=>{const q=String(document.getElementById('member-search')?.value||'').trim().toLowerCase(),st=document.getElementById('member-status')?.value||'';let visible=0;document.querySelectorAll('[data-member-row]').forEach(row=>{const show=(!q||row.dataset.search.includes(q))&&(!st||row.dataset.status===st);row.style.display=show?'':'none';if(show)visible++;});const c=document.getElementById('member-count');if(c)c.textContent=`${visible} alumnos`;};document.getElementById('member-search')?.addEventListener('input',applyFilter);document.getElementById('member-status')?.addEventListener('change',applyFilter);
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
    const groups=[{key:'enviada',label:'Nuevas'},{key:'en_revision',label:'En revisión'},{key:'lista_espera',label:'Lista de espera'},{key:'aprobada',label:'Aprobadas'}];
    const col=(g)=>`<section class="pipeline-col"><h3>${esc(g.label)} · ${items.filter(x=>x.estado===g.key).length}</h3>${items.filter(x=>x.estado===g.key).map(p=>`<div class="pipeline-card"><strong>${esc(p.nombre)} ${esc(p.apellidos)}</strong><small>${esc(relations.disciplines.find(d=>d.id===p.disciplina_id)?.nombre||'Sin disciplina')} · ${dateFmt(p.creado_en)}</small>${can&&p.estado==='enviada'?`<div class="row-actions"><button class="btn btn-primary btn-sm approve-pre" data-id="${esc(p.id)}">Aprobar</button><button class="btn btn-ghost btn-sm wait-pre" data-id="${esc(p.id)}">Espera</button><button class="btn btn-ghost btn-sm reject-pre" data-id="${esc(p.id)}">Rechazar</button></div>`:''}</div>`).join('')||'<div class="muted" style="font-size:11px;padding:10px 2px">Sin solicitudes</div>'}</section>`;
    const extras=items.filter(x=>!groups.some(g=>g.key===x.estado));
    setMainHtml(`${pageHeader('Preinscripciones','Pipeline de solicitudes y altas',can?'<button class="btn btn-primary" id="new-pre">Nueva preinscripción</button>':'','Gestión')}<div class="pipeline">${groups.map(col).join('')}</div>${extras.length?card('Otros estados',extras.map(x=>quickRow(icon('userPlus'),`${x.nombre} ${x.apellidos}`,x.estado,badge(x.estado,'neutral'))).join('')):''}`);
    const reload=()=>renderEnrollments();
    document.getElementById('new-pre')?.addEventListener('click',()=>openForm({title:'Nueva preinscripción',fields:[{name:'tipo_solicitud',label:'Tipo',type:'select',required:true,value:'adulto',options:[{value:'adulto',label:'Adulto'},{value:'menor',label:'Menor'}]},{name:'nombre',label:'Nombre',required:true},{name:'apellidos',label:'Apellidos',required:true},{name:'fecha_nacimiento',label:'Fecha de nacimiento',type:'date'},{name:'telefono',label:'Teléfono',required:true},{name:'tutor_nombre',label:'Tutor/a'},{name:'tutor_email',label:'Email tutor',type:'email'},{name:'parentesco',label:'Parentesco'},{name:'disciplina_id',label:'Disciplina',type:'select',options:options(relations.disciplines.filter(d=>d.activa))},{name:'grupo_id',label:'Grupo',type:'select',options:options(relations.groups.filter(g=>g.activo))},{name:'tarifa_id',label:'Tarifa',type:'select',options:options(relations.tariffs.filter(t=>t.activa))},{name:'observaciones',label:'Observaciones',type:'textarea',full:true}],onSubmit:async v=>{await repos.preenrollments.create(v);toast('Preinscripción creada');await reload();}}));
    bind('.approve-pre',async(id,el)=>{el.disabled=true;try{await repos.preenrollments.approve(id);toast('Preinscripción aprobada');await reload();}catch(e){setError(e);el.disabled=false;}});
    const reasonAction=(selector,title,fn)=>bind(selector,id=>openForm({title,fields:[{name:'motivo',label:'Motivo',type:'textarea',full:true,required:title.includes('Rechazar')}],onSubmit:async v=>{await fn(id,v.motivo);toast('Estado actualizado');await reload();}}));reasonAction('.wait-pre','Pasar a lista de espera',repos.preenrollments.wait);reasonAction('.reject-pre','Rechazar preinscripción',repos.preenrollments.reject);
  }catch(e){setError(e);setMainHtml(`${pageHeader('Preinscripciones')} ${empty('No se pudieron cargar las solicitudes',e.message)}`)}
}
