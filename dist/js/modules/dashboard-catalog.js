import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { has } from '../core/permissions.js';
import { esc, byName } from '../core/utils.js';
import { pageHeader, metric, card, table, empty, badge, openForm, toast, setError, setMainHtml } from '../ui/components.js';

const btn=(id,label,cls='btn btn-ghost btn-sm')=>`<button type="button" class="${cls}" data-id="${esc(id)}">${esc(label)}</button>`;
const bind=(selector,fn)=>document.querySelectorAll(selector).forEach(el=>el.addEventListener('click',()=>fn(el.dataset.id,el)));

export async function renderDashboard(){
  setMainHtml('<div class="loading-card">Cargando panel…</div>');
  try{
    const d=await repos.dashboard.load();
    const pending=d.fees.filter(x=>['pendiente','vencida','parcialmente_pagada'].includes(x.estado));
    const unpaid=pending.reduce((s,x)=>s+Number(x.importe||0),0);
    const future=d.sessions.filter(x=>String(x.fecha)>=new Date().toISOString().slice(0,10)&&x.estado!=='cancelada');
    const unread=d.notifs.filter(x=>!x.leida);
    setMainHtml(`${pageHeader('Inicio','Resumen operativo conectado a Supabase')}
      <div class="metrics">${metric('Socios activos',d.members.filter(x=>x.estado==='activo').length)}${metric('Grupos activos',d.groups.filter(x=>x.activo).length)}${metric('Cuotas pendientes',pending.length,`${unpaid.toFixed(2)} € nominales`)}${metric('Avisos sin leer',unread.length)}</div>
      <div class="grid-2">${card('Próximas sesiones',future.length?future.slice(0,8).map(x=>`<div class="cert-step"><span class="cert-index">${esc(String(x.fecha).slice(8,10)||'•')}</span><div><strong>${esc(x.fecha)}</strong><small>${esc(x.estado)}</small></div></div>`).join(''):empty('Sin sesiones próximas'))}${card('Estado del sistema',`<p>Frontend <strong>${esc(window.UW_CONFIG.release.version)}</strong></p><p>Backend esperado <strong>${esc(window.UW_CONFIG.release.backendVersion)}</strong></p><p>Rol efectivo <strong>${esc(state.session?.rol)}</strong></p><button class="btn btn-ghost" id="run-quick-diagnostic">Ejecutar diagnóstico</button><div id="quick-diagnostic" style="margin-top:12px"></div>`)}</div>`);
    document.getElementById('run-quick-diagnostic')?.addEventListener('click',async()=>{
      const box=document.getElementById('quick-diagnostic');box.textContent='Comprobando…';
      try{const { backend }=await import('../core/backend.js');const [contract,probe]=await Promise.all([backend.contract(),backend.probe()]);box.innerHTML=`${badge('Contrato OK','ok')} ${badge('Canal OK','ok')}<pre style="white-space:pre-wrap;font-size:11px">${esc(JSON.stringify({contract,probe},null,2))}</pre>`;}catch(e){box.innerHTML=`${badge('Fallo','danger')} ${esc(e.message)}`}
    });
  }catch(e){setError(e);setMainHtml(`${pageHeader('Inicio')} ${empty('No se pudo cargar el panel',e.message)}`)}
}

function disciplineFields(){return [
  {name:'nombre',label:'Nombre',required:true},{name:'orden',label:'Orden',type:'number',value:0},
  {name:'descripcion',label:'Descripción',type:'textarea',full:true},{name:'color',label:'Color',type:'color',value:'#ffffff'},
  {name:'activa',label:'Disciplina activa',type:'checkbox',value:true}
]}
function gradeFields(disciplines){return [
  {name:'disciplina_id',label:'Disciplina',type:'select',required:true,options:disciplines.filter(d=>d.activa).map(d=>({value:d.id,label:d.nombre}))},
  {name:'nombre',label:'Nombre del grado',required:true},{name:'orden',label:'Orden',type:'number',value:1,min:1},{name:'color',label:'Color',type:'color',value:'#ffffff'},
  {name:'meses_minimos',label:'Meses mínimos',type:'number',min:0},{name:'activo',label:'Grado activo',type:'checkbox',value:true}
]}

export async function renderCatalog(){
  setMainHtml('<div class="loading-card">Cargando catálogo…</div>');
  try{
    const [disciplines,grades]=await Promise.all([repos.catalog.disciplines(),repos.catalog.grades()]);
    disciplines.sort(byName); const canD=has(state.session,'discipline'),canG=has(state.session,'grade');
    const drows=disciplines.map(d=>`<tr><td><strong>${esc(d.nombre)}</strong><br><small>${esc(d.descripcion||'')}</small></td><td>${badge(d.activa?'Activa':'Inactiva',d.activa?'ok':'neutral')}</td><td>${esc(d.orden)}</td><td><div class="row-actions">${canD?btn(d.id,'Editar','btn btn-ghost btn-sm edit-discipline')+btn(d.id,d.activa?'Desactivar':'Activar','btn btn-ghost btn-sm toggle-discipline'):''}</div></td></tr>`);
    const grows=grades.map(g=>{const d=disciplines.find(x=>x.id===g.disciplina_id);return `<tr><td>${esc(d?.nombre||'—')}</td><td><strong>${esc(g.nombre)}</strong></td><td>${esc(g.orden)}</td><td>${badge(g.activo?'Activo':'Inactivo',g.activo?'ok':'neutral')}</td><td>${canG?btn(g.id,'Editar','btn btn-ghost btn-sm edit-grade'):''}</td></tr>`});
    setMainHtml(`${pageHeader('Disciplinas y grados','Catálogo deportivo',`${canD?'<button class="btn btn-primary" id="new-discipline">Nueva disciplina</button>':''}${canG?'<button class="btn btn-ghost" id="new-grade">Nuevo grado</button>':''}`)}
      ${card('Disciplinas',drows.length?table(['Disciplina','Estado','Orden','Acciones'],drows):empty('Sin disciplinas'))}
      ${card('Grados',grows.length?table(['Disciplina','Grado','Orden','Estado','Acciones'],grows):empty('Sin grados'))}`);
    const reload=()=>renderCatalog();
    document.getElementById('new-discipline')?.addEventListener('click',()=>openForm({title:'Nueva disciplina',fields:disciplineFields(),onSubmit:async v=>{await repos.catalog.saveDiscipline(v);toast('Disciplina guardada');await reload();}}));
    bind('.edit-discipline',(id)=>{const d=disciplines.find(x=>x.id===id);openForm({title:'Editar disciplina',fields:disciplineFields(),initial:d,onSubmit:async v=>{await repos.catalog.saveDiscipline({...d,...v,id});toast('Disciplina actualizada');await reload();}})});
    bind('.toggle-discipline',async(id,el)=>{const d=disciplines.find(x=>x.id===id);el.disabled=true;try{await repos.catalog.saveDiscipline({...d,activa:!d.activa});toast(d.activa?'Disciplina desactivada':'Disciplina activada');await reload();}catch(e){setError(e);el.disabled=false;}});
    document.getElementById('new-grade')?.addEventListener('click',()=>openForm({title:'Nuevo grado',fields:gradeFields(disciplines),onSubmit:async v=>{await repos.catalog.saveGrade(v);toast('Grado guardado');await reload();}}));
    bind('.edit-grade',(id)=>{const g=grades.find(x=>x.id===id);openForm({title:'Editar grado',fields:gradeFields(disciplines),initial:g,onSubmit:async v=>{await repos.catalog.saveGrade({...g,...v,id});toast('Grado actualizado');await reload();}})});
  }catch(e){setError(e);setMainHtml(`${pageHeader('Disciplinas y grados')} ${empty('No se pudo cargar el catálogo',e.message)}`)}
}
