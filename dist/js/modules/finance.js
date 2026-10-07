import {openHistoricalFinance} from './historical-finance.js';
import { getLocale as kxGetLocale, t } from '../i18n/index.js';
import { localeTag as kxLocaleTag } from '../i18n/formatters.js';
import { repos } from '../core/repositories.js';
import { state } from '../core/state.js';
import { has } from '../core/permissions.js';
import { esc, money, dateFmt, monthStart, isoDate, humanError } from '../core/utils.js';
import { pageHeader, card, table, empty, badge, openForm, openDetail, confirmDialog, toast, setError, setMainHtml, metric } from '../ui/components.js';
import { summarizeFinance, groupFinance } from '../core/finance-math.js';
import { migrationAssistBanner, openMigrationPreparation } from './customer-operations.js';
import { contentTranslationAttrs, prewarmUserContentTranslations } from '../i18n/user-content-translation.js';
import { paymentCenterSummaryHtml, bindPaymentCenter, openPaymentCenter } from './payments-center.js';
import { openFinanceContext } from './finance-context.js';
import { mountFinanceGuide } from './finance-guide.js';

const bind=(selector,fn)=>document.querySelectorAll(selector).forEach(el=>el.addEventListener('click',()=>fn(el.dataset.id,el)));
const opts=(rows,label)=>rows.map(r=>({value:r.id,label:label(r)}));
const isDirection=()=>((state.session?.roles?.length?state.session.roles:[state.session?.rol]).filter(Boolean)).includes('direccion');
const financeFilters={year:'',month:'',socio:'',origin:'',status:''};
let financeLimit=100;
const originLabel=(x)=>({cuota:t('finance.labels.fee'),material:t('finance.labels.material'),otro:t('finance.labels.other')}[x]||x||t('finance.labels.fee'));
const publicConcept=(value)=>String(value||t('finance.labels.fee')).replace(/\s\[[0-9a-f]{8}\]$/i,'');
const stripeStatusLabel=value=>({not_configured:t('finance.stripe.notConfigured'),pending:t('finance.stripe.configurationPending'),verification_pending:t('finance.stripe.verificationPending'),active:t('finance.stripe.active'),action_required:t('finance.stripe.actionRequired'),restricted:t('finance.stripe.restricted')})[value]||t('finance.stripe.notConfigured');
const monthLabel=(n)=>new Intl.DateTimeFormat(kxLocaleTag(kxGetLocale()),{month:'long'}).format(new Date(2024,Number(n)-1,1));
const receiptIssuer=r=>{
  const sessionClub=String(r?.club_id||'')===String(state.session?.club_id||'')?(state.session?.club||{}):{};
  return {
    nombre:r?.emisor_nombre||sessionClub.nombre||'Club KOMBAX',
    logo_url:r?.emisor_logo_url||sessionClub.logo_url||'./assets/kombax-symbol.png',
    cif:r?.emisor_cif||sessionClub.cif||'',
    email:r?.emisor_email||sessionClub.email||'',
    telefono:r?.emisor_telefono||sessionClub.telefono||'',
    direccion:r?.emisor_direccion||sessionClub.direccion||'',
    web:r?.emisor_web||sessionClub.web||''
  };
};
const receiptLogo=club=>/^(https:\/\/|\.\/|\/)/i.test(String(club?.logo_url||''))?club.logo_url:'./assets/kombax-symbol.png';
const receiptDocument=(r)=>{
  const club=receiptIssuer(r);
  const status=r.anulado_en?t('finance.receipt.cancelled'):t('finance.receipt.collected');
  const rows=[
    [t('finance.labels.student'),r.socio_nombre],
    [t('finance.labels.paidBy'),r.pagado_por],
    [t('finance.labels.concept'),publicConcept(r.concepto||r.actividad)],
    [t('finance.labels.period'),String(r.periodo||'').slice(0,7)],
    [t('finance.labels.paymentDate'),dateFmt(r.fecha_pago)],
    [t('finance.receipt.method'),r.metodo||'—'],
    [t('finance.labels.reference'),r.referencia||'—'],
    [t('finance.labels.amount'),money(r.importe)]
  ];
  const issuerMeta=[club.direccion,club.cif?`CIF/NIF ${club.cif}`:'',club.email,club.telefono,club.web].filter(Boolean);
  return `<article class="professional-receipt ${r.anulado_en?'is-annulled':''}">
    <header><div class="receipt-brand"><img src="${esc(receiptLogo(club))}" alt="${esc(club.nombre)}"><div><small>${t('finance.labels.paymentReceipt')}</small><h2>${esc(club.nombre)}</h2><p>${issuerMeta.map(esc).join(' · ')}</p></div></div><div class="receipt-number"><span>${status}</span><strong>${esc(r.numero||'—')}</strong><small>${t('finance.labels.issued')} ${dateFmt(r.emitido_en||r.fecha_pago)}</small></div></header>
    <div class="receipt-watermark">${esc(String(club.nombre||'KOMBAX').slice(0,2).toUpperCase())}</div>
    <section class="receipt-grid">${rows.map(([k,v])=>`<div><span>${esc(k)}</span><strong>${esc(v??'—')}</strong></div>`).join('')}</section>
    ${r.anulado_en?`<div class="receipt-annul-note"><strong>${t('finance.labels.annulledReceipt')}</strong><span>${esc(r.motivo_anulacion||t('finance.labels.noReason'))}</span></div>`:''}
    <footer><span>${t('finance.receipt.identifiable',{number:esc(r.numero||'—')})}</span><span>${esc(club.email||club.web||club.nombre||'')}</span></footer>
  </article>`;
};

const printReceipt=(r)=>{
  const popup=window.open('','_blank','width=860,height=960');
  if(!popup)throw new Error(t('finance.receipt.printBlocked'));
  try{popup.opener=null}catch{}
  popup.document.open();
  popup.document.write(`<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${t('finance.receipt.title',{number:esc(r.numero||'')})}</title><link rel="stylesheet" href="${new URL('./css/app.css',location.href).href}"></head><body class="receipt-print-page">${receiptDocument(r)}<script>addEventListener('load',()=>setTimeout(()=>print(),180));<\/script></body></html>`);
  popup.document.close();
};
export const openReceipt=(r)=>{
  if(!r)return;
  const {wrap}=openDetail({title:t('finance.receipt.title',{number:r.numero||''}),subtitle:t('finance.receipt.subtitle'),className:'receipt-modal',body:receiptDocument(r),actions:`<button class="btn btn-ghost" id="share-receipt" type="button">${t('finance.actions.shareData')}</button><button class="btn btn-primary" id="print-receipt" type="button">${t('finance.actions.printSavePdf')}</button>`});
  wrap.querySelector('#print-receipt')?.addEventListener('click',()=>{try{printReceipt(r)}catch(e){setError(e)}});
  wrap.querySelector('#share-receipt')?.addEventListener('click',async()=>{const text=`Recibo ${r.numero} · ${r.socio_nombre} · ${money(r.importe)} · ${dateFmt(r.fecha_pago)}`;try{if(navigator.share)await navigator.share({title:`Recibo ${r.numero}`,text});else{await navigator.clipboard.writeText(text);toast(t('finance.actions.paymentCopied'));}}catch(e){if(e?.name!=='AbortError')setError(e)}});
};
async function renderMonitorFinance(){
  setMainHtml(`<div class="loading-card">${t('common.states.loadingWallet')}</div>`);
  try{
    const [ctx,rows]=await Promise.all([repos.scopes.context(),repos.scopes.finance()]);
    const level=ctx?.finance_level||'none';
    const levelLabel={none:t('finance.wallet.noAccess'),status:t('finance.wallet.statusOnly'),portfolio:t('finance.wallet.portfolio'),collect:t('finance.wallet.collect'),receipts:t('finance.wallet.receipts')}[level]||level;
    if(level==='none'){
      setMainHtml(`${pageHeader(t('finance.wallet.title'),t('finance.wallet.privacy'),'',t('finance.title'))}<div class="alert alert-info"><strong>${t('finance.wallet.noAccess')}</strong><span>${t('finance.wallet.noAccessBody')}</span></div>`);return;
    }
    const list=Array.isArray(rows)?rows:[];
    const uniqueStudents=new Set(list.map(x=>x.socio_id));
    const pending=list.filter(x=>x.cuota_id&&['pendiente','vencida','parcialmente_pagada'].includes(x.estado));
    const visibleAmount=list.some(x=>x.importe!=null);
    const totalPending=visibleAmount?pending.reduce((a,x)=>a+Number(x.saldo||0),0):null;
    const tr=list.filter(x=>x.cuota_id).map(x=>`<tr><td><strong>${esc(x.socio_nombre||'—')}</strong></td><td>${esc(publicConcept(x.concepto||'Cuota'))}</td><td>${esc(String(x.periodo||'').slice(0,7))}</td><td>${badge(x.estado||'—',x.estado==='pagada'?'ok':x.estado==='vencida'?'danger':'warn')}</td><td>${x.importe==null?t('finance.labels.private'):money(x.importe)}</td><td>${x.saldo==null?t('finance.labels.private'):`<strong>${money(x.saldo)}</strong>`}</td><td>${x.recibo_numero?esc(x.recibo_numero):'—'}</td><td>${x.can_collect&&x.estado!=='pagada'?`<button class="btn btn-primary btn-sm monitor-collect" data-id="${esc(x.cuota_id)}">${t('finance.actions.recordPayment')}</button>`:''}</td></tr>`);
    setMainHtml(`${pageHeader(t('finance.wallet.title'),t('finance.wallet.assignedSubtitle'),'',t('finance.title'))}
      <div class="metrics">${metric(t('finance.labels.level'),levelLabel)}${metric(t('finance.labels.students'),uniqueStudents.size)}${metric(t('finance.labels.pending'),pending.length)}${visibleAmount?metric(t('finance.labels.visibleBalance'),money(totalPending||0)):metric(t('finance.labels.amount'),t('finance.labels.hidden'))}</div>
      <div class="alert alert-info"><strong>${t('finance.wallet.privacyActive')}</strong><span>${t('finance.wallet.privacyBody')}</span></div>
      ${card(t('finance.wallet.assigned'),tr.length?table(['Alumno','Concepto','Periodo','Estado','Importe','Pendiente','Recibo','Acción'],tr):empty(t('finance.wallet.noVisibleCharges'),t('finance.wallet.noVisibleChargesBody')))}`);
    document.querySelectorAll('.monitor-collect').forEach(b=>b.addEventListener('click',()=>{const row=list.find(x=>x.cuota_id===b.dataset.id);openForm({title:t('finance.actions.recordPayment'),subtitle:`${row?.socio_nombre||''} · operación auditada`,fields:[{name:'importe',label:'Importe',type:'number',step:'0.01',min:.01,required:true,value:row?.saldo??''},{name:'fecha',label:'Fecha',type:'date',required:true,value:isoDate()},{name:'metodo',label:'Método',type:'select',required:true,value:'efectivo',options:['transferencia','bizum','efectivo','tarjeta','otro'].map(x=>({value:x,label:x}))},{name:'referencia',label:'Referencia'},{name:'observaciones',label:'Observaciones',type:'textarea',full:true}],submitText:'Registrar cobro',onSubmit:async v=>{await repos.scopes.collect({...v,cuota_id:b.dataset.id});toast('Cobro registrado y auditado');await renderMonitorFinance();}})}));
  }catch(error){setError(error);setMainHtml(`${pageHeader('Mi cartera')} ${empty('No se pudo cargar tu cartera',humanError(error))}`);}
}

export async function renderFinance(){
  if(state.session?.rol==='monitor')return renderMonitorFinance();
  setMainHtml('<div class="loading-card">Cargando finanzas…</div>');
  try{
    const portal=['familia','alumno'].includes(state.session?.rol);
    const periodRows=await repos.finance.years();
    const years=[...new Set(periodRows.map(x=>Number(String(x.periodo||'').slice(0,4))).filter(Boolean))].sort((a,b)=>b-a);
    if(!financeFilters.year)financeFilters.year=String(years.includes(new Date().getFullYear())?new Date().getFullYear():(years[0]||new Date().getFullYear()));
    const [tariffs,fees,payments,receipts,members,account,detail,annual]=await Promise.all([
      repos.tariffs.list(),repos.finance.fees(financeLimit),repos.finance.payments(financeLimit),repos.finance.receipts(financeLimit),repos.members.list(),repos.finance.account(financeLimit).catch(()=>[]),
      portal?Promise.resolve([]):repos.finance.detail({...financeFilters,limit:financeLimit}),
      portal?Promise.resolve([]):repos.finance.metricsAnnual()
    ]);
    const canTariff=has(state.session,'tariff'),canGenerate=has(state.session,'feeGenerate'),canAdminPay=has(state.session,'paymentAdmin');
    const connect=portal?null:await repos.payments.paymentMethodsStatus('club',state.session.club_id).catch(()=>({status:'not_configured',stripe_account_connected:false,charges_enabled:false,payouts_enabled:false,card_enabled:true,sepa_enabled:false}));
    const payerOptions=portal?await repos.payments.payerOptions(state.session.club_id).catch(()=>({card_available:false,sepa_available:false,mandates:[]})):null;
    const pending=fees.filter(f=>['pendiente','vencida','parcialmente_pagada'].includes(f.estado));
    const pendingAmount=(account.length?account:pending).reduce((sum,row)=>sum+Number(row.saldo??row.importe??0),0);
    const overdue=fees.filter(f=>f.estado==='vencida');
    const pendingValidation=payments.filter(p=>p.estado_validacion==='pendiente');
    const validated=payments.filter(p=>p.estado_validacion==='validado');
    const collected=validated.reduce((sum,p)=>sum+Number(p.importe||0),0);
    const actions=`${!portal?`<button class="btn btn-ghost" id="finance-context-r84">${esc(t('prepilot.financeContext'))}</button>`:''}${canTariff?'<button class="btn btn-ghost" id="new-tariff">Nueva tarifa</button>':''}${canGenerate?'<button class="btn btn-primary" id="generate-fees">Generar cuotas</button>':''}`;
    const tariffRows=tariffs.map(t=>`<tr><td><strong ${contentTranslationAttrs({contentId:t.id,contentType:'club_tariff',fieldName:'name',sourceLocale:t.source_locale||t.idioma||'',visibility:'tenant'})}>${esc(t.nombre)}</strong><br><small ${contentTranslationAttrs({contentId:t.id,contentType:'club_tariff',fieldName:'description',sourceLocale:t.source_locale||t.idioma||'',visibility:'tenant'})}>${esc(t.descripcion||'')}</small></td><td>${money(t.importe)}</td><td>${money(t.matricula)}</td><td>${esc(t.periodicidad)}</td><td>${badge(t.activa?'Activa':'Inactiva',t.activa?'ok':'neutral')}</td><td>${canTariff?`<div class="row-actions"><button class="btn btn-ghost btn-sm edit-tariff" data-id="${esc(t.id)}">Editar</button><button class="btn btn-danger btn-sm delete-tariff" data-id="${esc(t.id)}">Eliminar</button></div>`:''}</td></tr>`);
    const matchesFeeFilter=f=>portal||(
      (!financeFilters.year||String(f.periodo||'').slice(0,4)===String(financeFilters.year))&&
      (!financeFilters.month||Number(String(f.periodo||'').slice(5,7))===Number(financeFilters.month))&&
      (!financeFilters.socio||f.socio_id===financeFilters.socio)&&
      (!financeFilters.origin||(f.origen||'cuota')===financeFilters.origin)&&
      (!financeFilters.status||f.estado===financeFilters.status)
    );
    const visibleFees=fees.filter(matchesFeeFilter),visibleFeeIds=new Set(visibleFees.map(f=>f.id));
    const contextFiltered=!portal;
    const visiblePayments=contextFiltered?payments.filter(p=>visibleFeeIds.has(p.cuota_id)):payments;
    const visibleReceipts=contextFiltered?receipts.filter(r=>visibleFeeIds.has(r.cuota_id)):receipts;
    const visiblePendingValidation=visiblePayments.filter(p=>p.estado_validacion==='pendiente');
    const balanceByFee=new Map(account.map(a=>[a.cuota_id,Number(a.saldo??a.importe??0)]));
    const feeRows=visibleFees.slice(0,300).map(f=>{const m=members.find(x=>x.id===f.socio_id);const balance=balanceByFee.get(f.id)??Number(f.importe||0);return `<tr><td><strong>${esc(m?`${m.apellidos}, ${m.nombre}`:'—')}</strong></td><td><strong>${esc(publicConcept(f.concepto))}</strong></td><td>${badge(originLabel(f.origen),'neutral')}</td><td>${esc(String(f.periodo||'').slice(0,7))}</td><td>${money(f.importe)}</td><td><strong>${money(balance)}</strong></td><td>${dateFmt(f.vencimiento)}</td><td>${badge(f.estado,f.estado==='pagada'?'ok':f.estado==='vencida'?'danger':f.estado==='parcialmente_pagada'?'warn':'neutral')}</td><td><div class="row-actions">${canAdminPay&&f.estado!=='pagada'?`<button class="btn btn-primary btn-sm admin-pay" data-id="${esc(f.id)}">Cobrar</button>${connect?.sepa_enabled&&connect?.sepa_capability_status==='active'?`<button class="btn btn-ghost btn-sm sepa-charge" data-id="${esc(f.id)}">${esc(t('payments.chargeSepa'))}</button>`:''}`:''}${!canAdminPay&&f.estado!=='pagada'?`<button class="btn btn-primary btn-sm communicate-pay" data-id="${esc(f.id)}">Comunicar pago</button>`:''}${has(state.session,'reminders')&&f.estado!=='pagada'?(f.avisos_pausados?`<button class="btn btn-ghost btn-sm resume-fee" data-id="${esc(f.id)}">Reactivar avisos</button>`:`<button class="btn btn-ghost btn-sm pause-fee" data-id="${esc(f.id)}">Pausar avisos</button>`):''}</div></td></tr>`});
    const paymentRows=visiblePayments.slice(0,300).map(p=>{const m=members.find(x=>x.id===p.socio_id);return `<tr><td>${dateFmt(p.fecha)}</td><td>${esc(m?`${m.apellidos}, ${m.nombre}`:'—')}</td><td>${money(p.importe)}</td><td>${esc(p.metodo)}</td><td>${badge(p.estado_validacion,p.estado_validacion==='validado'?'ok':p.estado_validacion==='rechazado'?'danger':'warn')}</td><td><div class="row-actions">${p.justificante_url?`<button class="btn btn-ghost btn-sm view-proof" data-id="${esc(p.id)}">Justificante</button>`:''}${canAdminPay&&p.estado_validacion==='pendiente'?`<button class="btn btn-primary btn-sm validate-pay" data-id="${esc(p.id)}">Validar</button> <button class="btn btn-ghost btn-sm reject-pay" data-id="${esc(p.id)}">Rechazar</button>`:''}</div></td></tr>`});
    const receiptRows=visibleReceipts.slice(0,300).map(r=>`<tr><td><strong>${esc(r.numero)}</strong><br><small>${r.anulado_en?'ANULADO':''}</small></td><td>${esc(r.socio_nombre)}</td><td>${esc(publicConcept(r.concepto||r.actividad))}</td><td>${badge(originLabel(r.origen),"neutral")}</td><td>${dateFmt(r.fecha_pago)}</td><td>${esc(String(r.periodo||'').slice(0,7))}</td><td>${money(r.importe)}</td><td>${badge(r.anulado_en?'Anulado':'Cobrado',r.anulado_en?'danger':'ok')}<br><small>${esc(r.motivo_anulacion||r.metodo||'—')}</small></td><td><div class="row-actions"><button class="btn btn-primary btn-sm view-receipt" data-id="${esc(r.id)}">Ver recibo</button>${canAdminPay&&!r.anulado_en?`<button class="btn btn-ghost btn-sm annul-receipt" data-id="${esc(r.id)}">Anular</button>`:''}</div></td></tr>`);
    const accountRows=account.slice(0,500).map(a=>{const m=members.find(x=>x.id===a.socio_id);const saldo=Number(a.saldo||0);return `<tr><td><strong>${esc(m?`${m.apellidos}, ${m.nombre}`:'—')}</strong></td><td>${esc(String(a.periodo||'').slice(0,7))}</td><td>${esc(publicConcept(a.concepto))}</td><td>${badge(originLabel(a.origen),'neutral')}</td><td>${money(a.importe)}</td><td>${money(a.pagado_validado)}</td><td><strong>${money(saldo)}</strong></td><td>${badge(a.estado,a.estado==='pagada'||saldo<=0?'ok':a.estado==='vencida'?'danger':'warn')}</td><td>${a.recibo_numero?`<strong>${esc(a.recibo_numero)}</strong>${a.recibo_anulado_en?'<br><small>ANULADO</small>':''}`:'—'}</td></tr>`});

    if(portal){
      const conceptRows=account.filter(a=>Number(a.saldo||0)>0).map(a=>{const m=members.find(x=>x.id===a.socio_id);const fee=fees.find(x=>x.id===a.cuota_id);return `<tr><td><strong>${esc(publicConcept(a.concepto))}</strong><br><small>${esc(m?`${m.nombre} ${m.apellidos}`:'')}</small></td><td>${badge(originLabel(a.origen),'neutral')}</td><td>${money(a.importe)}</td><td>${money(a.pagado_validado)}</td><td><strong>${money(a.saldo)}</strong></td><td>${dateFmt(a.vencimiento)}</td><td>${badge(a.estado,a.estado==='vencida'?'danger':'warn')}</td><td>${fee?`<div class="row-actions">${payerOptions?.card_available?`<button class="btn btn-primary btn-sm stripe-pay" data-id="${esc(fee.id)}">Pagar ahora</button>`:''}${payerOptions?.sepa_available?`<button class="btn btn-ghost btn-sm sepa-setup" data-id="${esc(fee.id)}">${esc(t('payments.setupSepa'))}</button>`:''}<button class="btn btn-ghost btn-sm communicate-pay" data-id="${esc(fee.id)}">Comunicar otro pago</button></div>`:''}</td></tr>`});
      setMainHtml(`${pageHeader('Mis pagos','Consulta únicamente tus conceptos, pagos y recibos','', 'Mi cuenta')}
        <div class="metrics">${metric('Total pendiente',money(pendingAmount),'todos tus conceptos')}${metric('Vencidos',overdue.length)}${metric('Pagos validados',validated.length)}</div>
        ${card('Conceptos pendientes',conceptRows.length?table(['Concepto','Origen','Importe','Pagado','Pendiente','Vence','Estado','Acción'],conceptRows):empty('Todo al día','No tienes conceptos pendientes.'))}
        ${card('Historial básico',accountRows.length?table(['Alumno','Periodo','Concepto','Origen','Importe','Pagado','Saldo','Estado','Recibo'],accountRows):empty('Sin movimientos','Cuando el club genere un cargo aparecerá aquí.'))}
        ${card('Pagos comunicados',paymentRows.length?table(['Fecha','Alumno','Importe','Método','Validación','Acciones'],paymentRows):empty('Aún no has comunicado pagos'))}
        ${card('Recibos',receiptRows.length?table(['Número','Alumno','Concepto','Origen','Pago','Periodo','Importe','Estado','Acciones'],receiptRows):empty('Los recibos aparecerán cuando el cargo quede completamente pagado'))}`);
    }else{
      const filteredSummary=summarizeFinance(detail);
      const filteredMonths=groupFinance(detail,'mes');
      const originBreakdown=groupFinance(detail,'origen',['cuota','material','otro']);
      const scopeLabel=[financeFilters.origin?originLabel(financeFilters.origin):'Todos los orígenes',financeFilters.month?monthLabel(financeFilters.month):financeFilters.year].filter(Boolean).join(' · ');
      const filterOptions=`<div class="finance-filters"><label>Año<select id="finance-year">${(years.length?years:[new Date().getFullYear()]).map(y=>`<option value="${y}" ${String(y)===String(financeFilters.year)?'selected':''}>${y}</option>`).join('')}</select></label><label>Mes<select id="finance-month"><option value="">Todos</option>${Array.from({length:12},(_,i)=>i+1).map(m=>`<option value="${m}" ${String(m)===String(financeFilters.month)?'selected':''}>${esc(monthLabel(m))}</option>`).join('')}</select></label><label>Alumno<select id="finance-member"><option value="">Todos</option>${members.map(m=>`<option value="${esc(m.id)}" ${m.id===financeFilters.socio?'selected':''}>${esc(`${m.apellidos}, ${m.nombre}`)}</option>`).join('')}</select></label><label>Origen<select id="finance-origin"><option value="">Todos</option>${['cuota','material','otro'].map(x=>`<option value="${x}" ${x===financeFilters.origin?'selected':''}>${originLabel(x)}</option>`).join('')}</select></label><label>Estado<select id="finance-status"><option value="">Todos</option>${['pendiente','parcialmente_pagada','vencida','pagada','anulada','exenta'].map(x=>`<option value="${x}" ${x===financeFilters.status?'selected':''}>${x}</option>`).join('')}</select></label></div>`;
      const detailRows=detail.map(x=>`<tr><td><strong>${esc(`${x.socio_apellidos||''}, ${x.socio_nombre||''}`)}</strong></td><td>${esc(publicConcept(x.concepto))}</td><td>${badge(originLabel(x.origen),'neutral')}</td><td>${esc(String(x.periodo||'').slice(0,7))}</td><td>${dateFmt(x.creado_en)}</td><td>${dateFmt(x.vencimiento)}</td><td>${money(x.importe)}</td><td>${money(x.pagado_validado)}</td><td><strong>${money(x.saldo)}</strong></td><td>${badge(x.estado,x.estado==='pagada'?'ok':x.estado==='vencida'?'danger':'warn')}</td><td>${esc(x.ultimo_metodo_pago||'—')}</td><td>${x.recibo_numero?esc(x.recibo_numero):'—'}</td></tr>`);
      const originRows=originBreakdown.map(x=>`<tr><td>${badge(originLabel(x.value),'neutral')}</td><td>${money(x.total_generado)}</td><td>${money(x.total_cobrado)}</td><td><strong>${money(x.total_pendiente)}</strong></td><td>${money(x.total_vencido)}</td><td>${x.alumnos_con_deuda}</td></tr>`);
      const monthlyRows=filteredMonths.map(x=>`<tr><td>${esc(monthLabel(x.value))}</td><td>${money(x.total_generado)}</td><td>${money(x.total_cobrado)}</td><td>${money(x.total_pendiente)}</td><td>${money(x.total_vencido)}</td><td>${Number(x.porcentaje_cobro||0).toFixed(2)} %</td></tr>`);
      const annualRows=annual.map(x=>`<tr><td>${esc(x.anio)}</td><td>${money(x.total_generado)}</td><td>${money(x.total_cobrado)}</td><td>${money(x.total_pendiente)}</td><td>${money(x.total_vencido)}</td><td>${esc(x.porcentaje_cobro)} %</td><td>${esc(x.alumnos_con_deuda)}</td></tr>`);
      const connectCard=paymentCenterSummaryHtml(connect||{}, {subjectType:'club',title:t('payments.title'),compact:true});
      setMainHtml(`${pageHeader('Finanzas','Tarifas, cuotas, pagos, recibos y estado de cuenta',actions,'Economía')}
        ${connectCard}
        ${filterOptions}
        <div class="metrics">${metric('Generado',money(filteredSummary.total_generado),scopeLabel)}${metric('Cobrado',money(filteredSummary.total_cobrado),scopeLabel)}${metric('Pendiente',money(filteredSummary.total_pendiente),scopeLabel)}${metric('Vencido',money(filteredSummary.total_vencido),scopeLabel)}${metric('% cobro',`${Number(filteredSummary.porcentaje_cobro||0).toFixed(2)} %`,scopeLabel)}${metric('Alumnos con deuda',filteredSummary.alumnos_con_deuda,scopeLabel)}</div>
        ${visiblePendingValidation.length?`<div class="alert alert-warning"><strong>Requiere acción</strong><span>${visiblePendingValidation.length} pago${visiblePendingValidation.length===1?'':'s'} pendiente${visiblePendingValidation.length===1?'':'s'} de validación en este filtro.</span></div>`:''}
        ${card('Desglose por origen',originRows.length?table(['Origen','Generado','Cobrado','Pendiente','Vencido','Con deuda'],originRows):empty('Sin importes para estos filtros'))}
        ${card(`Historial financiero ${esc(financeFilters.year)}`,detailRows.length?table(['Alumno','Concepto','Origen','Periodo','Creado','Vence','Importe','Cobrado','Pendiente','Estado','Método','Recibo'],detailRows):empty('Sin movimientos para estos filtros'))}
        ${card('Evolución mensual',monthlyRows.length?table(['Mes','Generado','Cobrado','Pendiente','Vencido','% cobro'],monthlyRows):empty('Sin evolución mensual'))}
        ${card('Evolución anual general',annualRows.length?table(['Año','Generado','Cobrado','Pendiente','Vencido','% cobro','Con deuda'],annualRows):empty('Sin histórico anual'))}
        ${card('Tarifas',tariffRows.length?table(['Tarifa','Importe','Matrícula','Periodicidad','Estado','Acciones'],tariffRows):empty('Sin tarifas'))}
        ${card('Cargos y cuotas',feeRows.length?table(['Alumno','Concepto','Origen','Periodo','Importe','Pendiente','Vence','Estado','Acciones'],feeRows):empty('Sin cargos para estos filtros'))}
        ${card('Pagos',paymentRows.length?table(['Fecha','Alumno','Importe','Método','Validación','Acciones'],paymentRows):empty('Sin pagos'))}
        ${card('Recibos',receiptRows.length?table(['Número','Alumno','Concepto','Origen','Pago','Periodo','Importe','Estado','Acciones'],receiptRows):empty('Sin recibos'))}`);
    }

    mountFinanceGuide({premium:!portal});
    if(!portal)bindPaymentCenter(document.querySelector('#main-view'),{subjectType:'club',subjectId:state.session.club_id,onRefresh:renderFinance,assistContext:{clubId:state.session.club_id,onBack:renderFinance}});
    document.getElementById('finance-context-r84')?.addEventListener('click',()=>openFinanceContext({subjectType:'club',subjectId:state.session.club_id}));

    const financeLoaded=Math.max(fees.length,payments.length,receipts.length,account.length,detail.length);
    if(financeLoaded>=financeLimit&&financeLimit<500){const more=document.createElement('div');more.className='load-more-wrap';more.innerHTML='<button class="btn btn-ghost" id="load-more-finance">Cargar más histórico financiero</button>';document.getElementById('main-view')?.appendChild(more);document.getElementById('load-more-finance')?.addEventListener('click',()=>{financeLimit=Math.min(500,financeLimit+100);renderFinance();});}

    if(!portal){
      const financeHeader=document.querySelector('#main-view .page-header');
      financeHeader?.insertAdjacentHTML('afterend',migrationAssistBanner({title:'¿Tienes cuotas o pagos históricos fuera de KOMBAX?',body:'Importa Excel, CSV, PDF o documentos mediante KOMBAX Migrations. El asistente prepara una vista previa y no registra movimientos sin confirmación.'}));
      document.querySelector('#main-view [data-kx-migration-assist]')?.addEventListener('click',openMigrationPreparation);
    }
    for(const [id,key] of [['finance-year','year'],['finance-month','month'],['finance-member','socio'],['finance-origin','origin'],['finance-status','status']])document.getElementById(id)?.addEventListener('change',e=>{financeFilters[key]=e.target.value;renderFinance();});

    if(has(state.session,'paymentAdmin')){const host=document.querySelector('#main-view .page-header');if(host){const button=document.createElement('button');button.type='button';button.className='btn btn-ghost';button.textContent=kxGetLocale()==='es'?'Registrar histórico':'Record historical entry';button.addEventListener('click',()=>openHistoricalFinance(members,renderFinance));host.appendChild(button);}}
    const reload=()=>renderFinance();
    bind('.stripe-pay',async(id,button)=>{button.disabled=true;try{const out=await repos.payments.checkout('club_fee',id,1);if(!out?.url)throw new Error('No se pudo abrir el pago seguro.');location.assign(out.url);}catch(error){setError(error);button.disabled=false;}});
    bind('.sepa-setup',async(id,button)=>{button.disabled=true;try{const out=await repos.payments.sepaSetup(id);if(!out?.url)throw new Error(t('payments.connectError'));toast(t('payments.sepaSetupOpened'));location.assign(out.url);}catch(error){setError(error);button.disabled=false;}});
    bind('.sepa-charge',async(id,button)=>{button.disabled=true;try{const out=await repos.payments.sepaChargeFee(id);toast(t('payments.sepaChargeStarted'));await renderFinance();}catch(error){setError(error);button.disabled=false;}});
    const tariffFields=[{name:'nombre',label:'Nombre',required:true},{name:'importe',label:'Importe',type:'number',step:'0.01',min:0,required:true},{name:'matricula',label:'Matrícula',type:'number',step:'0.01',min:0,value:0},{name:'periodicidad',label:'Periodicidad',type:'select',value:'mensual',options:['mensual','trimestral','semestral','anual','unica'].map(x=>({value:x,label:x}))},{name:'descripcion',label:'Descripción',type:'textarea',full:true},{name:'activa',label:'Tarifa activa',type:'checkbox',value:true}];
    document.getElementById('new-tariff')?.addEventListener('click',()=>openForm({title:'Nueva tarifa',fields:tariffFields,onSubmit:async v=>{const saved=await repos.tariffs.save(v);const contentId=saved?.id||saved?.tariff_id||null;if(contentId){void prewarmUserContentTranslations([{contentId,contentType:'club_tariff',fieldName:'name',text:v.nombre,visibility:'tenant'},{contentId,contentType:'club_tariff',fieldName:'description',text:v.descripcion,visibility:'tenant'}]);}toast('Tarifa guardada');await reload();}}));
    bind('.edit-tariff',id=>{const t=tariffs.find(x=>x.id===id);openForm({title:'Editar tarifa',fields:tariffFields,initial:t,onSubmit:async v=>{await repos.tariffs.save({...t,...v,id});void prewarmUserContentTranslations([{contentId:id,contentType:'club_tariff',fieldName:'name',text:v.nombre,visibility:'tenant'},{contentId:id,contentType:'club_tariff',fieldName:'description',text:v.descripcion,visibility:'tenant'}]);toast('Tarifa actualizada');await reload();}})});
    bind('.delete-tariff',id=>confirmDialog('Eliminar tarifa','Solo se elimina si nunca se ha utilizado. Si ya estuvo asignada o generó cuotas, desactívala y conserva su histórico financiero.',async()=>{await repos.tariffs.delete(id);toast('Tarifa eliminada');await reload();},{confirmText:'Eliminar',danger:true}));
    document.getElementById('generate-fees')?.addEventListener('click',()=>openForm({title:'Generar cuotas del periodo',subtitle:'Puedes repetir la operación con seguridad: no duplicará cuotas del mismo periodo.',fields:[{name:'periodo',label:'Periodo',type:'date',required:true,value:monthStart()}],submitText:'Generar',onSubmit:async v=>{const r=await repos.finance.generate(v.periodo);toast(`Cuotas generadas: ${r?.creadas??0}`);await reload();}}));
    const payFields=(fee)=>[{name:'importe',label:`Importe · ${publicConcept(fee?.concepto||'Cuota')}`,type:'number',step:'0.01',min:.01,required:true,value:balanceByFee.get(fee?.id)??fee?.importe??'',help:`Pendiente específico de ${originLabel(fee?.origen)}. Puedes registrar un pago parcial.`},{name:'fecha',label:'Fecha',type:'date',required:true,value:isoDate()},{name:'metodo',label:'Método',type:'select',required:true,value:'transferencia',options:['transferencia','bizum','efectivo','tarjeta','otro'].map(x=>({value:x,label:x}))},{name:'referencia',label:'Referencia'},{name:'observaciones',label:'Observaciones',type:'textarea',full:true}];
    bind('.admin-pay',id=>{const f=fees.find(x=>x.id===id);openForm({title:t('finance.actions.recordPayment'),fields:payFields(f),submitText:'Registrar pago',onSubmit:async v=>{await repos.finance.adminPayment({...v,cuota_id:id});toast('Pago registrado');await reload();}})});
    bind('.communicate-pay',id=>{const f=fees.find(x=>x.id===id);openForm({title:'Comunicar pago',subtitle:'Puedes adjuntar imagen o PDF (máx. 5 MB). El formulario no se cerrará hasta que el sistema confirme la operación.',fields:[...payFields(f),{name:'justificante',label:'Justificante',type:'file',accept:'image/*,.pdf',full:true}],submitText:'Comunicar pago',onSubmit:async v=>{const path=v.justificante?await repos.finance.uploadProof(f.socio_id,v.justificante):'';await repos.finance.communicatePayment({...v,cuota_id:id,justificante_path:path});toast('Pago comunicado');await reload();}})});
    bind('.view-proof',async(id,el)=>{el.disabled=true;try{const p=payments.find(x=>x.id===id);const url=await repos.finance.proofUrl(p?.justificante_url);if(!url)throw new Error('Este pago no tiene justificante adjunto.');window.open(url,'_blank','noopener,noreferrer');}catch(e){setError(e);}finally{el.disabled=false;}});
    bind('.validate-pay',async(id,el)=>{el.disabled=true;try{await repos.finance.validate(id,'validado');toast('Pago validado');await reload();}catch(e){setError(e);el.disabled=false;}});
    bind('.reject-pay',id=>openForm({title:'Rechazar pago',fields:[{name:'motivo',label:'Motivo',type:'textarea',required:true,full:true}],submitText:'Rechazar',onSubmit:async v=>{await repos.finance.validate(id,'rechazado',v.motivo);toast('Pago rechazado');await reload();}}));
    bind('.view-receipt',id=>openReceipt(receipts.find(x=>x.id===id)));
    bind('.pause-fee',id=>openForm({title:'Pausar avisos',fields:[{name:'motivo',label:'Motivo',required:true},{name:'hasta',label:'Hasta',type:'date'}],onSubmit:async v=>{await repos.finance.pause(id,v.motivo,v.hasta);toast('Avisos pausados');await reload();}}));
    bind('.resume-fee',async(id,el)=>{el.disabled=true;try{await repos.finance.resume(id);toast('Avisos reactivados');await reload();}catch(e){setError(e);el.disabled=false;}});
    bind('.annul-receipt',id=>openForm({title:'Anular recibo',subtitle:'El recibo conserva su número y trazabilidad. No se borra.',fields:[{name:'motivo',label:'Motivo de anulación',type:'textarea',full:true,required:true}],submitText:'Anular recibo',onSubmit:async v=>{await repos.finance.annulReceipt(id,v.motivo);toast('Recibo anulado');await reload();}}));
  }catch(e){setError(e);setMainHtml(`${pageHeader('Finanzas')} ${empty('No se pudieron cargar las finanzas',humanError(e))}`)}
}

export async function renderReminders(){
  setMainHtml('<div class="loading-card">Cargando avisos…</div>');
  try{
    const [cfg,history]=await Promise.all([repos.reminders.load(),repos.reminders.history()]);const current=cfg?.[0]||{};const can=has(state.session,'reminders');
    const rows=history.map(x=>`<tr><td>${dateFmt(x.fecha_programada)}</td><td>${esc(x.aviso_numero)}</td><td>${esc(x.canal)}</td><td>${badge(x.estado,x.estado==='enviado'||x.estado==='leido'?'ok':x.estado==='error'?'danger':'neutral')}</td><td>${esc(x.detalle_error||'')}</td></tr>`);
    setMainHtml(`${pageHeader('Avisos de cobro','Configuración y trazabilidad',can?'<button class="btn btn-primary" id="edit-reminders">Configurar</button> <button class="btn btn-ghost" id="process-reminders">Procesar hoy</button>':'')}
      ${card('Configuración',`<p><strong>Días:</strong> ${esc((current.dias_aviso||[]).join(', ')||'1, 4, 8, 11, 14')}</p><p><strong>Hora:</strong> ${esc(current.hora_envio||'10:00')}</p><p><strong>Vencida desde día:</strong> ${esc(current.marcar_vencida_dia||15)}</p>${badge(current.activo!==false?'Activo':'Inactivo',current.activo!==false?'ok':'neutral')}`)}
      ${card('Historial',rows.length?table(['Fecha','Aviso','Canal','Estado','Detalle'],rows):empty('Sin avisos procesados'))}`);
    mountFinanceGuide({premium:true});
    document.getElementById('edit-reminders')?.addEventListener('click',()=>openForm({title:'Configurar avisos',fields:[{name:'dias',label:'Días del mes',value:(current.dias_aviso||[1,4,8,11,14]).join(','),help:'Ejemplo: 1,4,8,11,14'},{name:'hora_envio',label:'Hora de envío',type:'time',value:String(current.hora_envio||'10:00').slice(0,5)},{name:'marcar_vencida_dia',label:'Marcar vencida desde',type:'number',min:1,max:28,value:current.marcar_vencida_dia||15},{name:'zona_horaria',label:'Zona horaria',value:current.zona_horaria||'Europe/Madrid'},{name:'canal_app',label:'Canal app',type:'checkbox',value:current.canal_app!==false},{name:'canal_push',label:'Canal push',type:'checkbox',value:current.canal_push!==false},{name:'canal_email',label:'Canal email',type:'checkbox',value:current.canal_email===true},{name:'agrupar_por_familia',label:'Agrupar por familia',type:'checkbox',value:current.agrupar_por_familia!==false},{name:'activo',label:'Avisos activos',type:'checkbox',value:current.activo!==false}],onSubmit:async v=>{const dias=String(v.dias).split(',').map(x=>Number(x.trim())).filter(x=>x>=1&&x<=28);if(dias.length!==5||new Set(dias).size!==5)throw new Error('Debes indicar exactamente cinco días distintos entre 1 y 28.');await repos.reminders.save({...v,dias_aviso:dias});toast('Configuración guardada');await renderReminders();}}));
    document.getElementById('process-reminders')?.addEventListener('click',()=>openForm({title:'Procesar avisos',fields:[{name:'fecha',label:'Fecha',type:'date',required:true,value:isoDate()}],submitText:'Procesar',onSubmit:async v=>{const r=await repos.reminders.process(v.fecha);toast(`Proceso completado${r?.generados!=null?`: ${r.generados} avisos`:''}`);await renderReminders();}}));
  }catch(e){setError(e);setMainHtml(`${pageHeader('Avisos de cobro')} ${empty('No se pudieron cargar los avisos',humanError(e))}`)}
}
