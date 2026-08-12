import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { has } from '../core/permissions.js';
import { esc, money, dateFmt, monthStart, isoDate } from '../core/utils.js';
import { pageHeader, card, table, empty, badge, openForm, confirmDialog, toast, setError, setMainHtml, metric } from '../ui/components.js';

const bind=(selector,fn)=>document.querySelectorAll(selector).forEach(el=>el.addEventListener('click',()=>fn(el.dataset.id,el)));
const opts=(rows,label)=>rows.map(r=>({value:r.id,label:label(r)}));
const isDirection=()=>((state.session?.roles?.length?state.session.roles:[state.session?.rol]).filter(Boolean)).includes('direccion');
let financeYear=new Date().getFullYear();
const forceConfirm=(title,subtitle,onConfirm)=>openForm({title,subtitle:`${subtitle} Escribe ELIMINAR para confirmar.`,fields:[{name:'confirmacion',label:'Confirmación',required:true,placeholder:'ELIMINAR'}],submitText:'Eliminar todo definitivamente',onSubmit:async v=>{if(String(v.confirmacion||'').trim().toUpperCase()!=='ELIMINAR')throw new Error('Escribe ELIMINAR exactamente para confirmar.');return onConfirm();}});

export async function renderFinance(){
  setMainHtml('<div class="loading-card">Cargando finanzas…</div>');
  try{
    const [tariffs,fees,payments,receipts,members,account]=await Promise.all([
      repos.tariffs.list(),repos.finance.fees(),repos.finance.payments(),repos.finance.receipts(),repos.members.list(),repos.finance.account().catch(()=>[])
    ]);
    const canTariff=has(state.session,'tariff'),canGenerate=has(state.session,'feeGenerate'),canAdminPay=has(state.session,'paymentAdmin'),portal=['familia','alumno'].includes(state.session?.rol);
    const years=[...new Set(account.map(a=>Number(String(a.periodo||'').slice(0,4))).filter(Boolean).concat([new Date().getFullYear()]))].sort((a,b)=>b-a);
    if(!years.includes(financeYear))financeYear=years[0];
    const annualAccount=account.filter(a=>Number(String(a.periodo||'').slice(0,4))===financeYear);
    const annualFees=fees.filter(f=>Number(String(f.periodo||'').slice(0,4))===financeYear);
    const annualPayments=payments.filter(p=>Number(String(p.fecha||'').slice(0,4))===financeYear);
    const annualReceipts=receipts.filter(r=>Number(String(r.fecha_pago||r.periodo||'').slice(0,4))===financeYear);
    const pending=fees.filter(f=>['pendiente','vencida','parcialmente_pagada'].includes(f.estado));
    const pendingAmount=(account.length?account:pending).reduce((sum,row)=>sum+Number(row.saldo??row.importe??0),0);
    const overdue=fees.filter(f=>f.estado==='vencida');
    const pendingValidation=payments.filter(p=>p.estado_validacion==='pendiente');
    const validated=payments.filter(p=>p.estado_validacion==='validado');
    const generatedAnnual=annualAccount.reduce((sum,a)=>sum+Number(a.importe||0),0);
    const collected=annualAccount.reduce((sum,a)=>sum+Number(a.pagado_validado||0),0);
    const balanceAnnual=annualAccount.reduce((sum,a)=>sum+Number(a.saldo||0),0);
    const collectionRate=generatedAnnual>0?Math.min(100,(collected/generatedAnnual)*100):0;
    const materialAnnual=annualAccount.filter(a=>(a.origen||'')==='material'||String(a.concepto||'').startsWith('Material:'));
    const yearControl=`<label class="finance-year-control"><span>Ejercicio</span><select id="finance-year">${years.map(y=>`<option value="${y}" ${y===financeYear?'selected':''}>${y}</option>`).join('')}</select></label>`;
    const actions=`${canTariff?'<button class="btn btn-ghost" id="new-tariff">Nueva tarifa</button>':''}${canGenerate?'<button class="btn btn-primary" id="generate-fees">Generar cuotas</button>':''}`;
    const tariffRows=tariffs.map(t=>`<tr><td><strong>${esc(t.nombre)}</strong><br><small>${esc(t.descripcion||'')}</small></td><td>${money(t.importe)}</td><td>${money(t.matricula)}</td><td>${esc(t.periodicidad)}</td><td>${badge(t.activa?'Activa':'Inactiva',t.activa?'ok':'neutral')}</td><td>${canTariff?`<div class="row-actions"><button class="btn btn-ghost btn-sm edit-tariff" data-id="${esc(t.id)}">Editar</button><button class="btn btn-danger btn-sm delete-tariff" data-id="${esc(t.id)}">Eliminar</button>${isDirection()?`<button class="btn btn-danger btn-sm force-delete-tariff" data-id="${esc(t.id)}">Eliminar todo</button>`:''}</div>`:''}</td></tr>`);
    const feeRows=annualFees.slice(0,500).map(f=>{const m=members.find(x=>x.id===f.socio_id);return `<tr><td><strong>${esc(m?`${m.apellidos}, ${m.nombre}`:'—')}</strong></td><td>${esc(String(f.periodo||'').slice(0,7))}</td><td>${money(f.importe)}</td><td>${dateFmt(f.vencimiento)}</td><td>${badge(f.estado,f.estado==='pagada'?'ok':f.estado==='vencida'?'danger':f.estado==='parcialmente_pagada'?'warn':'neutral')}</td><td><div class="row-actions">${canAdminPay&&f.estado!=='pagada'?`<button class="btn btn-primary btn-sm admin-pay" data-id="${esc(f.id)}">Cobrar</button>`:''}${!canAdminPay&&f.estado!=='pagada'?`<button class="btn btn-primary btn-sm communicate-pay" data-id="${esc(f.id)}">Comunicar pago</button>`:''}${has(state.session,'reminders')&&f.estado!=='pagada'?(f.avisos_pausados?`<button class="btn btn-ghost btn-sm resume-fee" data-id="${esc(f.id)}">Reactivar avisos</button>`:`<button class="btn btn-ghost btn-sm pause-fee" data-id="${esc(f.id)}">Pausar avisos</button>`):''}</div></td></tr>`});
    const paymentRows=annualPayments.slice(0,500).map(p=>{const m=members.find(x=>x.id===p.socio_id);return `<tr><td>${dateFmt(p.fecha)}</td><td>${esc(m?`${m.apellidos}, ${m.nombre}`:'—')}</td><td>${money(p.importe)}</td><td>${esc(p.metodo)}</td><td>${badge(p.estado_validacion,p.estado_validacion==='validado'?'ok':p.estado_validacion==='rechazado'?'danger':'warn')}</td><td><div class="row-actions">${p.justificante_url?`<button class="btn btn-ghost btn-sm view-proof" data-id="${esc(p.id)}">Justificante</button>`:''}${canAdminPay&&p.estado_validacion==='pendiente'?`<button class="btn btn-primary btn-sm validate-pay" data-id="${esc(p.id)}">Validar</button> <button class="btn btn-ghost btn-sm reject-pay" data-id="${esc(p.id)}">Rechazar</button>`:''}</div></td></tr>`});
    const receiptRows=annualReceipts.slice(0,500).map(r=>`<tr><td><strong>${esc(r.numero)}</strong><br><small>${r.anulado_en?'ANULADO':''}</small></td><td>${esc(r.socio_nombre)}</td><td>${dateFmt(r.fecha_pago)}</td><td>${esc(String(r.periodo||'').slice(0,7))}</td><td>${money(r.importe)}</td><td>${badge(r.anulado_en?'Anulado':'Emitido',r.anulado_en?'danger':'ok')}<br><small>${esc(r.motivo_anulacion||r.metodo||'—')}</small></td><td>${canAdminPay&&!r.anulado_en?`<button class="btn btn-ghost btn-sm annul-receipt" data-id="${esc(r.id)}">Anular</button>`:''}</td></tr>`);
    const accountRows=annualAccount.slice(0,1000).map(a=>{const m=members.find(x=>x.id===a.socio_id);const saldo=Number(a.saldo||0);return `<tr><td><strong>${esc(m?`${m.apellidos}, ${m.nombre}`:'—')}</strong></td><td>${esc(String(a.periodo||'').slice(0,7))}</td><td>${badge((a.origen||'cuota')==='material'?'Material':'Cuota',(a.origen||'cuota')==='material'?'warn':'neutral')}<br><small>${esc(a.concepto||'Cuota')}</small></td><td>${money(a.importe)}</td><td>${money(a.pagado_validado)}</td><td><strong>${money(saldo)}</strong></td><td>${badge(a.estado,a.estado==='pagada'||saldo<=0?'ok':a.estado==='vencida'?'danger':'warn')}</td><td>${a.recibo_numero?`<strong>${esc(a.recibo_numero)}</strong>${a.recibo_anulado_en?'<br><small>ANULADO</small>':''}`:'—'}</td></tr>`});

    if(portal){
      setMainHtml(`${pageHeader('Estado de cuenta','Una vista sencilla de lo pendiente y lo ya pagado','', 'Mi cuenta')}
        ${yearControl}
        <div class="metrics">${metric('Total pendiente',money(pendingAmount))}${metric(`Pagado ${financeYear}`,money(collected))}${metric(`Movimientos ${financeYear}`,annualAccount.length)}${metric('Material registrado',materialAnnual.length)}</div>
        ${card(`Movimientos ${financeYear}`,accountRows.length?table(['Alumno','Periodo','Concepto','Importe','Pagado','Pendiente','Estado','Recibo'],accountRows):empty('Sin movimientos','Cuando el club genere una cuota o valide material aparecerá aquí.'))}
        ${card('Comunicar un pago',feeRows.length?table(['Alumno','Periodo','Importe','Vence','Estado','Acciones'],feeRows):empty('No hay conceptos para este ejercicio'))}
        ${card('Pagos comunicados',paymentRows.length?table(['Fecha','Alumno','Importe','Método','Validación','Acciones'],paymentRows):empty('Aún no has comunicado pagos'))}`);
    }else{
      setMainHtml(`${pageHeader('Finanzas','Historial anual, métricas, cuotas, material y pagos',actions,'Economía')}
        ${yearControl}
        <div class="metrics">${metric(`Generado ${financeYear}`,money(generatedAnnual))}${metric(`Cobrado ${financeYear}`,money(collected))}${metric(`Pendiente ${financeYear}`,money(balanceAnnual))}${metric('Tasa de cobro',`${collectionRate.toFixed(1)}%`)}${metric('Material',materialAnnual.length,'movimientos del ejercicio')}${metric('Por validar',pendingValidation.length,'pagos comunicados')}</div>
        ${pendingValidation.length?`<div class="alert alert-warning"><strong>Requiere acción</strong><span>${pendingValidation.length} pago${pendingValidation.length===1?'':'s'} pendiente${pendingValidation.length===1?'':'s'} de validación.</span></div>`:''}
        ${card(`Historial financiero ${financeYear}`,accountRows.length?table(['Alumno','Periodo','Origen / concepto','Importe','Pagado','Saldo','Estado','Recibo'],accountRows):empty('Sin movimientos'))}
        ${card('Tarifas',tariffRows.length?table(['Tarifa','Importe','Matrícula','Periodicidad','Estado','Acciones'],tariffRows):empty('Sin tarifas'))}
        ${card('Cuotas',feeRows.length?table(['Alumno','Periodo','Importe','Vence','Estado','Acciones'],feeRows):empty('Sin cuotas'))}
        ${card('Pagos',paymentRows.length?table(['Fecha','Alumno','Importe','Método','Validación','Acciones'],paymentRows):empty('Sin pagos'))}
        ${card('Recibos',receiptRows.length?table(['Número','Alumno','Pago','Periodo','Importe','Estado','Acciones'],receiptRows):empty('Sin recibos'))}`);
    }

    document.getElementById('finance-year')?.addEventListener('change',e=>{financeYear=Number(e.target.value)||new Date().getFullYear();renderFinance();});
    const reload=()=>renderFinance();
    const tariffFields=[{name:'nombre',label:'Nombre',required:true},{name:'importe',label:'Importe',type:'number',step:'0.01',min:0,required:true},{name:'matricula',label:'Matrícula',type:'number',step:'0.01',min:0,value:0},{name:'periodicidad',label:'Periodicidad',type:'select',value:'mensual',options:['mensual','trimestral','semestral','anual','unica'].map(x=>({value:x,label:x}))},{name:'descripcion',label:'Descripción',type:'textarea',full:true},{name:'activa',label:'Tarifa activa',type:'checkbox',value:true}];
    document.getElementById('new-tariff')?.addEventListener('click',()=>openForm({title:'Nueva tarifa',fields:tariffFields,onSubmit:async v=>{await repos.tariffs.save(v);toast('Tarifa guardada');await reload();}}));
    bind('.edit-tariff',id=>{const t=tariffs.find(x=>x.id===id);openForm({title:'Editar tarifa',fields:tariffFields,initial:t,onSubmit:async v=>{await repos.tariffs.save({...t,...v,id});toast('Tarifa actualizada');await reload();}})});
    bind('.delete-tariff',id=>confirmDialog('Eliminar tarifa','Se elimina si no está asignada. El Gestor de la app puede usar “Eliminar todo” para retirar también sus vínculos e historial de cambios.',async()=>{await repos.tariffs.delete(id);toast('Tarifa eliminada');await reload();},{confirmText:'Eliminar',danger:true}));
    bind('.force-delete-tariff',id=>forceConfirm('Eliminar tarifa e histórico','Se desvinculará de alumnos, solicitudes y cuotas y se borrará su historial de cambios.',async()=>{await repos.tariffs.forceDelete(id);toast('Tarifa e histórico eliminados');await reload();}));
    document.getElementById('generate-fees')?.addEventListener('click',()=>openForm({title:'Generar cuotas del periodo',subtitle:'La operación es idempotente según el backend.',fields:[{name:'periodo',label:'Periodo',type:'date',required:true,value:monthStart()}],submitText:'Generar',onSubmit:async v=>{const r=await repos.finance.generate(v.periodo);toast(`Cuotas generadas: ${r?.creadas??0}`);await reload();}}));
    const payFields=(fee)=>[{name:'importe',label:'Importe',type:'number',step:'0.01',min:.01,required:true,value:fee?.importe||''},{name:'fecha',label:'Fecha',type:'date',required:true,value:isoDate()},{name:'metodo',label:'Método',type:'select',required:true,value:'transferencia',options:['transferencia','bizum','efectivo','tarjeta','otro'].map(x=>({value:x,label:x}))},{name:'referencia',label:'Referencia'},{name:'observaciones',label:'Observaciones',type:'textarea',full:true}];
    bind('.admin-pay',id=>{const f=fees.find(x=>x.id===id);openForm({title:'Registrar cobro',fields:payFields(f),submitText:'Registrar pago',onSubmit:async v=>{await repos.finance.adminPayment({...v,cuota_id:id});toast('Pago registrado');await reload();}})});
    bind('.communicate-pay',id=>{const f=fees.find(x=>x.id===id);openForm({title:'Comunicar pago',subtitle:'Puedes adjuntar imagen o PDF (máx. 5 MB). El formulario no se cerrará hasta que el sistema confirme la operación.',fields:[...payFields(f),{name:'justificante',label:'Justificante',type:'file',accept:'image/*,.pdf',full:true}],submitText:'Comunicar pago',onSubmit:async v=>{const path=v.justificante?await repos.finance.uploadProof(f.socio_id,v.justificante):'';await repos.finance.communicatePayment({...v,cuota_id:id,justificante_path:path});toast('Pago comunicado');await reload();}})});
    bind('.view-proof',async(id,el)=>{el.disabled=true;try{const p=payments.find(x=>x.id===id);const url=await repos.finance.proofUrl(p?.justificante_url);if(!url)throw new Error('Este pago no tiene justificante adjunto.');window.open(url,'_blank','noopener,noreferrer');}catch(e){setError(e);}finally{el.disabled=false;}});
    bind('.validate-pay',async(id,el)=>{el.disabled=true;try{await repos.finance.validate(id,'validado');toast('Pago validado');await reload();}catch(e){setError(e);el.disabled=false;}});
    bind('.reject-pay',id=>openForm({title:'Rechazar pago',fields:[{name:'motivo',label:'Motivo',type:'textarea',required:true,full:true}],submitText:'Rechazar',onSubmit:async v=>{await repos.finance.validate(id,'rechazado',v.motivo);toast('Pago rechazado');await reload();}}));
    bind('.pause-fee',id=>openForm({title:'Pausar avisos',fields:[{name:'motivo',label:'Motivo',required:true},{name:'hasta',label:'Hasta',type:'date'}],onSubmit:async v=>{await repos.finance.pause(id,v.motivo,v.hasta);toast('Avisos pausados');await reload();}}));
    bind('.resume-fee',async(id,el)=>{el.disabled=true;try{await repos.finance.resume(id);toast('Avisos reactivados');await reload();}catch(e){setError(e);el.disabled=false;}});
    bind('.annul-receipt',id=>openForm({title:'Anular recibo',subtitle:'El recibo conserva su número y trazabilidad. No se borra.',fields:[{name:'motivo',label:'Motivo de anulación',type:'textarea',full:true,required:true}],submitText:'Anular recibo',onSubmit:async v=>{await repos.finance.annulReceipt(id,v.motivo);toast('Recibo anulado');await reload();}}));
  }catch(e){setError(e);setMainHtml(`${pageHeader('Finanzas')} ${empty('No se pudieron cargar las finanzas',e.message)}`)}
}

export async function renderReminders(){
  setMainHtml('<div class="loading-card">Cargando avisos…</div>');
  try{
    const [cfg,history]=await Promise.all([repos.reminders.load(),repos.reminders.history()]);const current=cfg?.[0]||{};const can=has(state.session,'reminders');
    const rows=history.map(x=>`<tr><td>${dateFmt(x.fecha_programada)}</td><td>${esc(x.aviso_numero)}</td><td>${esc(x.canal)}</td><td>${badge(x.estado,x.estado==='enviado'||x.estado==='leido'?'ok':x.estado==='error'?'danger':'neutral')}</td><td>${esc(x.detalle_error||'')}</td></tr>`);
    setMainHtml(`${pageHeader('Avisos de cobro','Configuración y trazabilidad',can?'<button class="btn btn-primary" id="edit-reminders">Configurar</button> <button class="btn btn-ghost" id="process-reminders">Procesar hoy</button>':'')}
      ${card('Configuración',`<p><strong>Días:</strong> ${esc((current.dias_aviso||[]).join(', ')||'1, 4, 8, 11, 14')}</p><p><strong>Hora:</strong> ${esc(current.hora_envio||'10:00')}</p><p><strong>Vencida desde día:</strong> ${esc(current.marcar_vencida_dia||15)}</p>${badge(current.activo!==false?'Activo':'Inactivo',current.activo!==false?'ok':'neutral')}`)}
      ${card('Historial',rows.length?table(['Fecha','Aviso','Canal','Estado','Detalle'],rows):empty('Sin avisos procesados'))}`);
    document.getElementById('edit-reminders')?.addEventListener('click',()=>openForm({title:'Configurar avisos',fields:[{name:'dias',label:'Días del mes',value:(current.dias_aviso||[1,4,8,11,14]).join(','),help:'Ejemplo: 1,4,8,11,14'},{name:'hora_envio',label:'Hora de envío',type:'time',value:String(current.hora_envio||'10:00').slice(0,5)},{name:'marcar_vencida_dia',label:'Marcar vencida desde',type:'number',min:1,max:28,value:current.marcar_vencida_dia||15},{name:'zona_horaria',label:'Zona horaria',value:current.zona_horaria||'Europe/Madrid'},{name:'canal_app',label:'Canal app',type:'checkbox',value:current.canal_app!==false},{name:'canal_push',label:'Canal push',type:'checkbox',value:current.canal_push!==false},{name:'canal_email',label:'Canal email',type:'checkbox',value:current.canal_email===true},{name:'agrupar_por_familia',label:'Agrupar por familia',type:'checkbox',value:current.agrupar_por_familia!==false},{name:'activo',label:'Avisos activos',type:'checkbox',value:current.activo!==false}],onSubmit:async v=>{const dias=String(v.dias).split(',').map(x=>Number(x.trim())).filter(x=>x>=1&&x<=28);if(dias.length!==5||new Set(dias).size!==5)throw new Error('Debes indicar exactamente cinco días distintos entre 1 y 28.');await repos.reminders.save({...v,dias_aviso:dias});toast('Configuración guardada');await renderReminders();}}));
    document.getElementById('process-reminders')?.addEventListener('click',()=>openForm({title:'Procesar avisos',fields:[{name:'fecha',label:'Fecha',type:'date',required:true,value:isoDate()}],submitText:'Procesar',onSubmit:async v=>{const r=await repos.reminders.process(v.fecha);toast(`Proceso completado${r?.generados!=null?`: ${r.generados} avisos`:''}`);await renderReminders();}}));
  }catch(e){setError(e);setMainHtml(`${pageHeader('Avisos de cobro')} ${empty('No se pudieron cargar los avisos',e.message)}`)}
}
