import {repos} from '../core/repositories.js';
import {getLocale} from '../i18n/index.js';
import {isoDate} from '../core/utils.js';
import {openForm,toast} from '../ui/components.js';
const copy=(es,en)=>getLocale()==='es'?es:en;
export function openHistoricalFinance(members,reload){
 const requestId=crypto.randomUUID();
 const modal=openForm({title:copy('Registrar histórico','Record historical entry'),
  subtitle:copy('Registro manual. No realiza cargos bancarios. Los avisos quedan pausados.','Manual record. No bank charge is made. Reminders remain paused.'),
  fields:[
   {name:'socio_id',label:copy('Alumno','Student'),type:'select',required:true,options:members.map(m=>({value:m.id,label:`${m.apellidos}, ${m.nombre}`}))},
   {name:'estado',label:copy('Situación del histórico','Historical status'),type:'select',required:true,value:'pendiente',options:[{value:'pendiente',label:copy('Cuota anterior pendiente','Previous outstanding charge')},{value:'pagado',label:copy('Pago anterior ya realizado','Previous payment already made')}]},
   {name:'concepto',label:copy('Concepto','Description'),required:true},
   {name:'importe',label:copy('Importe','Amount'),type:'number',min:0.01,step:'0.01',required:true},
   {name:'periodo',label:copy('Periodo al que corresponde','Period covered'),type:'date',required:true},
   {name:'vencimiento',label:copy('Vencimiento original','Original due date'),type:'date',required:true},
   {name:'fecha_pago',label:copy('Fecha real del pago','Actual payment date'),type:'date'},
   {name:'metodo',label:copy('Método de pago','Payment method'),type:'select',value:'transferencia',options:['transferencia','bizum','efectivo','tarjeta','otro'].map(value=>({value,label:value}))},
   {name:'referencia',label:copy('Referencia','Reference')},
   {name:'observaciones',label:copy('Observaciones','Notes'),type:'textarea',full:true}
  ],submitText:copy('Registrar histórico','Record historical entry'),onSubmit:async v=>{
   await repos.finance.historical(v,requestId);toast(copy('Histórico registrado','Historical entry recorded'));await reload();
  }});
 const form=modal.wrap.querySelector('form');
 const mode=form.elements.namedItem('estado'),paid=form.elements.namedItem('fecha_pago');
 for(const key of ['periodo','vencimiento','fecha_pago'])form.elements.namedItem(key).max=isoDate();
 const sync=()=>{for(const key of ['fecha_pago','metodo','referencia']){const input=form.elements.namedItem(key);input.disabled=mode.value!=='pagado';const row=input.closest('.field');if(row){row.hidden=input.disabled;row.style.display=input.disabled?'none':'';}}paid.required=mode.value==='pagado';};
 mode.addEventListener('change',sync);sync();
}
