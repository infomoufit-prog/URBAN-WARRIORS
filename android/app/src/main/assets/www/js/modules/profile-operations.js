import {repos} from '../core/repositories.js';
import {esc,humanError,localIsoDate} from '../core/utils.js';
import {openDetail,openForm,confirmDialog,toast} from '../ui/components.js';
import {openFinanceContext} from './finance-context.js';

const labels={income:'Ingreso recibido',expense:'Gasto pagado',refund:'Devolución realizada',task:'Actividad',open:'Pendiente',done:'Completado',cancelled:'Anulado'};
const money=(v,c='EUR')=>new Intl.NumberFormat(undefined,{style:'currency',currency:c}).format(Number(v||0)/100);
const modeTitle=(profile,kind)=>kind==='finance'?`Finanzas · ${profile.nombre_publico}`:profile.tipo==='marca'?'Campañas y Embajadores':profile.tipo==='federacion'?'Centro de Temporada':'Centro de Producción';
const categories=profile=>profile.tipo==='marca'?[['campaign','Campaña'],['collaboration','Colaboración'],['ambassadors','Embajadores · avanzado'],['attribution','Resultado documentado · avanzado']]:profile.tipo==='federacion'?[['season','Temporada'],['renewal','Renovación de licencias'],['calendar','Calendario federativo'],['sponsorship','Patrocinio']]:[['production','Producción'],['program','Programa'],['access','Accesos y QR'],['partners','Colaboradores']];

export async function openProfileOperations(profile,{kind='finance',offset=0}={}){
 try{
  const ws=await repos.kombaxProfiles.operationsWorkspace(profile.id,kind,offset),a=ws.access||{},rows=ws.rows||[];
  const canCreate=kind==='finance'?a.write_finance:a.edit_tasks;
  const body=`<div class="kx-profile-operations"><p>${kind==='finance'?'Registro administrativo de ingresos recibidos, gastos y devoluciones. No inicia cobros ni sustituye facturas fiscales. Los movimientos de Stripe se consultan por separado.':'Planifica tareas, responsables y entregables en las notas; registra resultados observados sin atribución automática de ventas. La publicación y la venta se gestionan en sus módulos autorizados.'}</p>
   ${!a.active_service?'<div class="alert">Para crear actividad necesitas verificación y el servicio correspondiente. Puedes consultar el historial autorizado y anular registros existentes.</div>':''}
   ${kind==='finance'?`<div class="kx-brand-metrics">${(ws.totals||[]).map(x=>`<article class="kx-brand-metric"><span>${esc(x.currency)} · movimientos registrados</span><strong>${esc(money(Number(x.income_minor)-Number(x.expense_minor)-Number(x.refund_minor),x.currency))}</strong><small>Ingresos ${esc(money(x.income_minor,x.currency))} · gastos ${esc(money(x.expense_minor,x.currency))} · devoluciones ${esc(money(x.refund_minor,x.currency))}</small></article>`).join('')||'<p>Sin movimientos registrados.</p>'}</div>`:''}
   <div class="row-actions">${canCreate?`<button class="btn btn-primary" data-ops-new>${kind==='finance'?'Registrar movimiento':'Crear actividad'}</button>`:''}${kind==='finance'&&profile.tipo==='federacion'?'<button class="btn btn-ghost" data-ops-stripe>Historial de cobros y Stripe</button>':''}<button class="btn btn-ghost" data-ops-export>Descargar esta página CSV</button></div>
   <details open><summary>${rows.length?`${offset+1}–${offset+rows.length} de ${Number(ws.total)||0} registros`:'Sin registros'}</summary><div class="kx-brand-proposal-list">${rows.map(r=>`<article class="kx-brand-proposal-card"><div><small>${esc(labels[r.kind])} · ${esc(labels[r.state])} · ${esc(r.occurred_on)}</small><strong>${esc(r.title)}</strong><small>${esc(r.category)}${r.due_on?` · fecha límite ${esc(r.due_on)}`:''}${r.kind!=='task'?` · ${esc(money(r.amount_minor,r.currency))}`:''}</small><p style="white-space:pre-wrap">${esc(r.notes)}</p></div><div class="row-actions">${r.state!=='cancelled'?`${r.kind==='task'&&canCreate?`<button class="btn btn-ghost" data-ops-state="${r.state==='open'?'done':'open'}" data-id="${esc(r.id)}">${r.state==='open'?'Completar':'Reabrir'}</button>`:''}<button class="btn btn-ghost" data-ops-state="cancelled" data-id="${esc(r.id)}">Anular</button>`:''}</div></article>`).join('')||'<p>No hay registros en este espacio.</p>'}</div></details>
   <div class="row-actions">${offset>0?'<button class="btn btn-ghost" data-ops-prev>10 anteriores</button>':''}${offset+rows.length<ws.total?'<button class="btn btn-ghost" data-ops-next>10 siguientes</button>':''}</div><div data-ops-error role="alert"></div></div>`;
  const modal=openDetail({title:modeTitle(profile,kind),subtitle:profile.nombre_publico,width:'960px',body});
  const refresh=()=>openProfileOperations(profile,{kind,offset});
  modal.wrap.querySelector('[data-ops-prev]')?.addEventListener('click',()=>openProfileOperations(profile,{kind,offset:Math.max(0,offset-10)}));
  modal.wrap.querySelector('[data-ops-next]')?.addEventListener('click',()=>openProfileOperations(profile,{kind,offset:offset+10}));
  modal.wrap.querySelector('[data-ops-stripe]')?.addEventListener('click',()=>openFinanceContext({subjectType:'federation',subjectId:profile.id,title:'Cobros de Federación'}));
  modal.wrap.querySelector('[data-ops-new]')?.addEventListener('click',()=>openForm({title:kind==='finance'?'Registrar movimiento recibido o pagado':'Preparar actividad',subtitle:'Solo para esta identidad. Las notas son privadas.',fields:[
   ...(kind==='finance'?[{name:'kind',label:'Tipo',type:'select',required:true,options:['income','expense','refund'].map(value=>({value,label:labels[value]}))},{name:'amount',label:'Importe',type:'number',min:0.01,step:0.01,required:true},{name:'currency',label:'Moneda',type:'select',options:['EUR','USD','GBP'].map(value=>({value,label:value}))}]:[]),
   {name:'title',label:'Concepto o actividad',required:true,minLength:2,maxLength:180},
   {name:'category',label:kind==='finance'?'Categoría':'Tipo de actividad',...(kind==='tasks'?{type:'select',options:categories(profile).filter(([v])=>a.advanced||!['ambassadors','attribution'].includes(v)).map(([value,label])=>({value,label}))}:{maxLength:80})},
   {name:'occurred_on',label:kind==='finance'?'Fecha del movimiento':'Fecha de planificación',type:'date',required:true,value:localIsoDate()},
   ...(kind==='tasks'?[{name:'due_on',label:'Fecha límite',type:'date'}]:[]),
   {name:'notes',label:kind==='tasks'?'Objetivo, responsable, entregables y resultado observado':'Referencia y notas',type:'textarea',rows:4,full:true,maxLength:2000}
  ],submitText:'Guardar',onSubmit:async v=>{
   const amount=kind==='finance'?Number(v.amount)*100:0;
   if(!Number.isFinite(amount)||Math.abs(amount-Math.round(amount))>0.000001)throw new Error('El importe debe tener como máximo dos decimales.');
   await repos.kombaxProfiles.operationsMutate('operation.create',{profile_id:profile.id,...v,kind:kind==='tasks'?'task':v.kind,amount_minor:Math.round(amount)});
   toast('Registro guardado');setTimeout(()=>openProfileOperations(profile,{kind,offset:0}),350);
  }}));
  modal.wrap.querySelectorAll('[data-ops-state]').forEach(b=>b.addEventListener('click',()=>confirmDialog('Actualizar registro','Se conserva el registro y su trazabilidad. No modifica pagos ni entradas de Stripe.',async()=>{
   try{await repos.kombaxProfiles.operationsMutate('operation.state',{profile_id:profile.id,id:b.dataset.id,state:b.dataset.opsState});toast('Registro actualizado');setTimeout(refresh,350);}catch(e){toast(humanError(e),'error');setTimeout(refresh,350);}
  },{confirmText:'Confirmar'})));
  modal.wrap.querySelector('[data-ops-export]')?.addEventListener('click',()=>{
   const safe=v=>`"${String(v??'').replace(/^[=+@-]/,"'").replaceAll('"','""')}"`;
   const csv=[['fecha','concepto','tipo','estado','importe_centimos','moneda','categoria','notas'],...rows.map(r=>[r.occurred_on,r.title,r.kind,r.state,r.amount_minor,r.currency,r.category,r.notes])].map(r=>r.map(safe).join(';')).join('\r\n');
   const url=URL.createObjectURL(new Blob(['\ufeff'+csv],{type:'text/csv;charset=utf-8'})),link=document.createElement('a');link.href=url;link.download=`KOMBAX_${kind}_${profile.id}_${offset}.csv`;link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
  });
 }catch(e){toast(humanError(e),'error');}
}
