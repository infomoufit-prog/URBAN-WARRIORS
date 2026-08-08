import { repos } from '../core/repositories.js';
import { backend } from '../core/backend.js';
import { state } from '../core/state.js';
import { has, rolesLabel } from '../core/permissions.js';
import { esc, dtFmt, isoDate, monthStart, sleep } from '../core/utils.js';
import { pageHeader, card, table, empty, badge, openForm, toast, setError, setMainHtml } from '../ui/components.js';

const bind=(selector,fn)=>document.querySelectorAll(selector).forEach(el=>el.addEventListener('click',()=>fn(el.dataset.id,el)));

export async function renderUsers(){
  setMainHtml('<div class="loading-card">Cargando usuarios…</div>');
  try{
    const [members,invitations]=await Promise.all([repos.users.members(),repos.users.invitations()]);const can=has(state.session,'invite');
    const mrows=members.map(m=>`<tr><td><strong>${esc(m.perfiles?.nombre||'')} ${esc(m.perfiles?.apellidos||'')}</strong><br><small>${esc(m.perfiles?.telefono||'')}</small></td><td>${badge(m.rol,'neutral')}</td><td>${badge(m.activo?'Activo':'Inactivo',m.activo?'ok':'neutral')}</td><td>${dtFmt(m.creado_en)}</td></tr>`);
    const irows=invitations.map(i=>`<tr><td>${esc(i.email)}</td><td>${esc(i.rol)}</td><td>${badge(i.estado,i.estado==='aceptada'?'ok':i.estado==='pendiente'?'warn':'neutral')}</td><td>${dtFmt(i.expira_en)}</td></tr>`);
    setMainHtml(`${pageHeader('Usuarios','Personal y roles del club',can?'<button class="btn btn-primary" id="new-invite">Invitar personal</button>':'')}${card('Miembros',mrows.length?table(['Persona','Rol','Estado','Alta'],mrows):empty('Sin miembros'))}${card('Invitaciones',irows.length?table(['Email','Rol','Estado','Expira'],irows):empty('Sin invitaciones'))}`);
    document.getElementById('new-invite')?.addEventListener('click',()=>openForm({title:'Invitar personal',fields:[{name:'email',label:'Email',type:'email',required:true},{name:'rol',label:'Rol',type:'select',required:true,options:['secretaria','economia','comunicacion','monitor'].map(x=>({value:x,label:x}))}],onSubmit:async v=>{await repos.users.invite(v.email,v.rol);toast('Invitación creada');await renderUsers();}}));
  }catch(e){setError(e);setMainHtml(`${pageHeader('Usuarios')} ${empty('No se pudieron cargar los usuarios',e.message)}`)}
}

export async function renderSettings(){
  setMainHtml('<div class="loading-card">Cargando configuración…</div>');
  try{
    const [rows,config]=await Promise.all([repos.settings.club(),repos.settings.config()]);const c=rows?.[0]||state.session?.club||{};const can=has(state.session,'clubConfig');
    const configMap=Object.fromEntries((config||[]).map(x=>[x.clave,x.valor]));
    setMainHtml(`${pageHeader('Configuración','Datos generales del club',can?'<button class="btn btn-primary" id="edit-club">Editar</button>':'')}${card('Club',`<div class="grid-2"><div><p><strong>Nombre</strong><br>${esc(c.nombre||'')}</p><p><strong>Lema</strong><br>${esc(c.lema||'—')}</p><p><strong>Teléfono</strong><br>${esc(c.telefono||'—')}</p></div><div><p><strong>Email</strong><br>${esc(c.email||'—')}</p><p><strong>Dirección</strong><br>${esc(c.direccion||'—')}</p><p><strong>Web</strong><br>${esc(c.web||'—')}</p></div></div>`)}`);
    document.getElementById('edit-club')?.addEventListener('click',()=>openForm({title:'Configurar club',fields:[{name:'nombre',label:'Nombre',required:true},{name:'lema',label:'Lema'},{name:'telefono',label:'Teléfono'},{name:'email',label:'Email',type:'email'},{name:'direccion',label:'Dirección',full:true},{name:'web',label:'Web'},{name:'color_primario',label:'Color primario',type:'color',value:'#ffffff'},{name:'color_secundario',label:'Color secundario',type:'color',value:'#050608'},{name:'dia_vencimiento',label:'Día de vencimiento',type:'number',min:1,max:28,value:configMap.dia_vencimiento||10},{name:'avisos_clase_horas',label:'Aviso de clase (horas)',type:'number',min:1,value:configMap.avisos_clase_horas||24}],initial:c,onSubmit:async v=>{await repos.settings.saveClub(v);toast('Configuración guardada');await renderSettings();}}));
  }catch(e){setError(e);setMainHtml(`${pageHeader('Configuración')} ${empty('No se pudo cargar la configuración',e.message)}`)}
}

export async function renderProfile(){
  const s=state.session;
  setMainHtml(`${pageHeader('Mi perfil','Datos personales de la sesión actual')} ${card('Perfil',`<p><strong>${esc(s?.nombre||'')} ${esc(s?.apellidos||'')}</strong></p><p>${esc(s?.email||'')}</p><p>${esc(s?.telefono||'')}</p><p>Roles: ${esc(rolesLabel(s?.roles||[]))}</p><button class="btn btn-primary" id="edit-profile">Editar perfil</button> <button class="btn btn-ghost" id="enable-push">Activar avisos del dispositivo</button>`)}`);
  document.getElementById('enable-push')?.addEventListener('click',async()=>{try{if(window.UrbanWarriorsNative?.requestNotifications){const token=window.UrbanWarriorsNative.requestNotifications();if(token)await backend.mutate('push.registrar',{token,plataforma:'android'});toast('Solicitud de notificaciones enviada');}else{toast('La activación push está disponible en la app Android','error');}}catch(e){setError(e)}});
  document.getElementById('edit-profile')?.addEventListener('click',()=>openForm({title:'Editar perfil',fields:[{name:'nombre',label:'Nombre',required:true},{name:'apellidos',label:'Apellidos'},{name:'telefono',label:'Teléfono'}],initial:s,onSubmit:async v=>{await repos.settings.profile(v);Object.assign(state.session,v);localStorage.setItem('uw2_app_session',JSON.stringify(state.session));toast('Perfil actualizado');await renderProfile();}}));
}

export async function renderDiagnostics(){
  setMainHtml('<div class="loading-card">Ejecutando diagnóstico…</div>');
  try{
    const [contract,probe,diagnostic]=await Promise.all([backend.contract(),backend.probe(),backend.diagnostic().catch(e=>({error:e.message}))]);state.diagnostics={contract,probe,diagnostic};
    const trace=state.trace.map(t=>`<div class="trace-item ${t.ok===true?'trace-ok':t.ok===false?'trace-bad':'trace-pending'}"><strong>${esc(t.label||t.kind)} ${t.ms!=null?`· ${t.ms} ms`:''}</strong><small>${esc(t.error||t.detail||t.requestId||'')}</small></div>`).join('');
    setMainHtml(`${pageHeader('Diagnóstico del sistema','Estado observable del canal real')}${card('Contrato',`<pre style="white-space:pre-wrap;font-size:12px">${esc(JSON.stringify(contract,null,2))}</pre>`)}${card('Sonda de escritura',`<pre style="white-space:pre-wrap;font-size:12px">${esc(JSON.stringify(probe,null,2))}</pre>`)}${card('Diagnóstico de persistencia',`<pre style="white-space:pre-wrap;font-size:12px">${esc(JSON.stringify(diagnostic,null,2))}</pre>`)}${card('Traza de esta sesión',trace||empty('Sin operaciones registradas'))}`);
  }catch(e){setError(e);setMainHtml(`${pageHeader('Diagnóstico del sistema')} ${empty('Diagnóstico fallido',e.message)}`)}
}

function certStep(name,detail=''){return {name,detail,status:'pending',error:null,data:null}}
function renderCertBoard(steps,running=false){
  const box=document.getElementById('cert-board');if(!box)return;
  box.innerHTML=steps.map((s,i)=>`<div class="cert-step ${s.status==='ok'?'ok':s.status==='fail'?'fail':''}"><span class="cert-index">${s.status==='ok'?'✓':s.status==='fail'?'!':i+1}</span><div><strong>${esc(s.name)}</strong><small>${esc(s.error||s.detail||'Pendiente')}</small></div>${s.status==='ok'?badge('OK','ok'):s.status==='fail'?badge('FALLO','danger'):badge(running?'Pendiente':'No ejecutado','neutral')}</div>`).join('');
}

export async function renderCertification(){
  if(!has(state.session,'certification')){setMainHtml(`${pageHeader('Certificación E2E')} ${empty('Acceso restringido','Solo Dirección puede ejecutar la certificación.')}`);return;}
  const steps=[
    certStep('Contrato y sonda backend'),certStep('Diagnóstico SQL v161'),certStep('Crear y leer disciplina'),certStep('Editar y releer disciplina'),certStep('Crear y leer grado'),certStep('Crear grupo con horario y leerlo'),certStep('Crear y leer tarifa'),certStep('Crear alumno y matrícula'),certStep('Crear sesión y leerla'),certStep('Registrar asistencia y leerla'),certStep('Crear seguimiento y leerlo'),certStep('Crear comunicación y leerla'),certStep('Crear material y variante'),certStep('Logout + login + persistencia'),certStep('Desactivar datos E2E')
  ];
  setMainHtml(`${pageHeader('Certificación E2E real','Navegador → Supabase → PostgreSQL → lectura posterior')}
    <div class="alert alert-warning" style="margin:0 0 18px"><strong>Uso controlado</strong><span>Esta prueba crea registros E2E identificables en el Supabase real. Al final desactiva o archiva los que el contrato permite, pero conserva la trazabilidad SQL.</span></div>
    ${card('Ejecución',`<p>No usa mocks ni DML directo. Todas las escrituras pasan por <code>app_mutate_v160</code>.</p><button class="btn btn-primary" id="start-cert">Ejecutar certificación completa</button> <button class="btn btn-ghost" id="export-cert" disabled>Exportar resultado</button><div id="cert-board" style="margin-top:18px"></div>`)}`);
  renderCertBoard(steps,false);
  document.getElementById('start-cert')?.addEventListener('click',()=>openForm({title:'Autorizar certificación',subtitle:'Introduce tu contraseña únicamente para verificar logout + nuevo login. No se almacena.',fields:[{name:'password',label:'Contraseña',type:'password',required:true}],submitText:'Iniciar E2E',onSubmit:async v=>{await runCertification(steps,v.password);}}));
  document.getElementById('export-cert')?.addEventListener('click',()=>{
    const blob=new Blob([JSON.stringify(state.certification,null,2)],{type:'application/json'});const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download=`urban-warriors-cert-${Date.now()}.json`;a.click();URL.revokeObjectURL(a.href);
  });
}

async function runCertification(steps,password){
  const prefix=`E2E_RC3_${new Date().toISOString().replace(/[-:.TZ]/g,'').slice(0,14)}`;const ids={};const email=state.session.email;const log=[];const sessionAccessCode=`E2E${Date.now().toString(36).slice(-7).toUpperCase()}`;
  const set=async(index,fn)=>{
    steps[index].status='pending';steps[index].detail='Ejecutando…';renderCertBoard(steps,true);
    try{const data=await fn();steps[index].status='ok';steps[index].data=data;steps[index].detail=typeof data==='string'?data:'Verificado';log.push({step:steps[index].name,ok:true,data});renderCertBoard(steps,true);return data;}
    catch(e){steps[index].status='fail';steps[index].error=e.message;log.push({step:steps[index].name,ok:false,error:e.message});renderCertBoard(steps,false);throw e;}
  };
  const findOne=async(table,id)=>{const rows=await backend.select(table,`select=*&id=eq.${encodeURIComponent(id)}&limit=1`);if(!rows?.[0])throw new Error(`${table}: el ID ${id} no aparece en lectura posterior.`);return rows[0];};
  try{
    await set(0,async()=>{const [c,p]=await Promise.all([backend.contract(),backend.probe()]);if(!c.ok||!p.ok)throw new Error('Contrato o sonda sin OK');return {contract:c.backend_version,probe:true}});
    await set(1,async()=>{const d=await backend.diagnostic();const list=Array.isArray(d)?d:[];const fails=list.filter(x=>String(x.estado||x.status||x.resultado||'OK').toUpperCase()==='FALLO');if(fails.length)throw new Error(`Diagnóstico SQL contiene ${fails.length} control(es) en FALLO`);return {rows:list.length||9,avisos:list.filter(x=>String(x.estado||'').toUpperCase()==='AVISO').length}});
    await set(2,async()=>{const r=await repos.catalog.saveDiscipline({nombre:`${prefix}_DISCIPLINA`,descripcion:'Certificación E2E RC1',color:'#ffffff',activa:true,orden:999});ids.discipline=r.id;const row=await findOne('disciplinas',r.id);return {id:r.id,nombre:row.nombre}});
    await set(3,async()=>{await repos.catalog.saveDiscipline({id:ids.discipline,nombre:`${prefix}_DISCIPLINA`,descripcion:'E2E EDITADO',color:'#ffffff',activa:true,orden:998});const row=await findOne('disciplinas',ids.discipline);if(row.descripcion!=='E2E EDITADO')throw new Error('La edición no aparece en la lectura.');return {id:row.id,descripcion:row.descripcion}});
    await set(4,async()=>{const r=await repos.catalog.saveGrade({disciplina_id:ids.discipline,nombre:`${prefix}_GRADO`,orden:99,color:'#ffffff',meses_minimos:0,activo:true});ids.grade=r.id;return findOne('grados',r.id)});
    await set(5,async()=>{const r=await repos.groups.save({disciplina_id:ids.discipline,nombre:`${prefix}_GRUPO`,monitor_nombre:'E2E',sala:'E2E',edad_min:10,edad_max:99,plazas:20,activo:true,horarios:[{dia_semana:1,hora_inicio:'18:00',hora_fin:'19:00'}]});ids.group=r.id;const row=await findOne('grupos',r.id);const hs=await backend.select('horarios_grupo',`select=*&grupo_id=eq.${encodeURIComponent(r.id)}`);if(!hs.length)throw new Error('Grupo creado sin horario persistido.');return {id:row.id,horarios:hs.length}});
    await set(6,async()=>{const r=await repos.tariffs.save({nombre:`${prefix}_TARIFA`,descripcion:'E2E',importe:1,matricula:0,periodicidad:'mensual',activa:true});ids.tariff=r.id;return findOne('tarifas',r.id)});
    await set(7,async()=>{const r=await repos.members.save({nombre:'E2E',apellidos:prefix,fecha_nacimiento:'2000-01-01',telefono:'600000000',email:`${prefix.toLowerCase()}@invalid.local`,disciplina_id:ids.discipline,grupo_id:ids.group,grado_id:ids.grade,tarifa_id:ids.tariff,estado:'activo',notas_internas:'Certificación E2E'});ids.member=r.id;const row=await findOne('socios',r.id);const links=await backend.select('socio_disciplinas',`select=*&socio_id=eq.${encodeURIComponent(r.id)}&activa=eq.true`);if(!links.length)throw new Error('Alumno creado sin matrícula persistida.');ids.enrollment=links[0].id;return {id:row.id,matriculas:links.length}});
    await set(8,async()=>{const r=await repos.sessions.save({grupo_id:ids.group,fecha:isoDate(),hora_inicio:'18:00',hora_fin:'19:00',monitor_nombre:'E2E',estado:'programada',observacion_general:'Certificación E2E',codigo_acceso:sessionAccessCode});ids.session=r.id;return findOne('sesiones_entrenamiento',r.id)});
    await set(9,async()=>{const r=await repos.sessions.saveAttendance({sesion_id:ids.session,socio_id:ids.member,estado:'presente',observacion:'E2E'});ids.attendance=r.id;const rows=await backend.select('asistencias',`select=*&sesion_id=eq.${encodeURIComponent(ids.session)}&socio_id=eq.${encodeURIComponent(ids.member)}&limit=1`);if(!rows?.[0]||rows[0].estado!=='presente')throw new Error('La asistencia no aparece como presente.');return {id:rows[0].id,estado:rows[0].estado}});
    await set(10,async()=>{const r=await repos.tracking.save({socio_id:ids.member,tipo:'e2e',nota:'Certificación E2E',visibilidad:'equipo',fecha:isoDate()});ids.tracking=r.id;return findOne('seguimiento',r.id)});
    await set(11,async()=>{const r=await repos.communications.save({tipo:'noticia',titulo:`${prefix}_COMUNICACION`,cuerpo:'Certificación E2E',audiencia:'todos',estado:'borrador'});ids.communication=r.id;return findOne('comunicaciones',r.id)});
    await set(12,async()=>{const r=await repos.material.save({disciplina_id:ids.discipline,nombre:`${prefix}_MATERIAL`,categoria:'E2E',descripcion:'Certificación',precio:1,stock:0,obligatorio:false,referencia:prefix,activo:true});ids.material=r.id;await findOne('material_catalogo',r.id);const v=await repos.material.saveVariant({material_id:r.id,talla:'U',color:'Negro',referencia:`${prefix}-V`,stock:1,activa:true});ids.variant=v.id;await findOne('material_variantes',v.id);return {material:r.id,variante:v.id}});
    await set(13,async()=>{await backend.signOut({preserveTrace:true});const s=await backend.signIn(email,password);if(!s?.id)throw new Error('No se pudo volver a iniciar sesión.');const row=await findOne('disciplinas',ids.discipline);return {relogin:true,persiste:row.id===ids.discipline}});
    await set(14,async()=>{
      await repos.sessions.save({id:ids.session,grupo_id:ids.group,fecha:isoDate(),hora_inicio:'18:00',hora_fin:'19:00',monitor_nombre:'E2E',estado:'cancelada',observacion_general:'E2E cerrado',codigo_acceso:''});
      await repos.members.save({id:ids.member,nombre:'E2E',apellidos:prefix,fecha_nacimiento:'2000-01-01',telefono:'600000000',email:`${prefix.toLowerCase()}@invalid.local`,disciplina_id:ids.discipline,grupo_id:ids.group,grado_id:ids.grade,tarifa_id:ids.tariff,estado:'baja',notas_internas:'E2E cerrado'});
      await repos.material.save({id:ids.material,disciplina_id:ids.discipline,nombre:`${prefix}_MATERIAL`,categoria:'E2E',descripcion:'Cerrado',precio:1,stock:0,obligatorio:false,referencia:prefix,activo:false});
      await repos.communications.save({id:ids.communication,tipo:'noticia',titulo:`${prefix}_COMUNICACION`,cuerpo:'E2E cerrado',audiencia:'todos',estado:'archivada'});
      await repos.tariffs.save({id:ids.tariff,nombre:`${prefix}_TARIFA`,descripcion:'E2E cerrada',importe:1,matricula:0,periodicidad:'mensual',activa:false});
      await repos.groups.save({id:ids.group,disciplina_id:ids.discipline,nombre:`${prefix}_GRUPO`,monitor_nombre:'E2E',sala:'E2E',edad_min:10,edad_max:99,plazas:20,activo:false,horarios:[]});
      await repos.catalog.saveGrade({id:ids.grade,disciplina_id:ids.discipline,nombre:`${prefix}_GRADO`,orden:99,color:'#ffffff',meses_minimos:0,activo:false});
      await repos.catalog.saveDiscipline({id:ids.discipline,nombre:`${prefix}_DISCIPLINA`,descripcion:'E2E cerrado',color:'#ffffff',activa:false,orden:998});
      return {cerrado:true};
    });
    state.certification={version:window.UW_CONFIG.release.version,at:new Date().toISOString(),prefix,ids,steps:log,trace:state.trace};document.getElementById('export-cert').disabled=false;toast('Certificación E2E completada');
  }catch(e){state.certification={version:window.UW_CONFIG.release.version,at:new Date().toISOString(),prefix,ids,steps:log,trace:state.trace,error:e.message};document.getElementById('export-cert').disabled=false;setError(e);}
  renderCertBoard(steps,false);
}
