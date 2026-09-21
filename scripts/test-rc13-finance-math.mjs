import { summarizeFinance, groupFinance } from '../web/js/core/finance-math.js';
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RC13 FINANCE MATH: ${msg}`);console.log(`OK RC13 FINANCE MATH: ${msg}`)};
const rows=[
  {socio_id:'a',origen:'cuota',importe:50,pagado_validado:50,saldo:0,estado:'pagada'},
  {socio_id:'a',origen:'material',importe:30,pagado_validado:10,saldo:20,estado:'parcialmente_pagada'},
  {socio_id:'b',origen:'otro',importe:25,pagado_validado:0,saldo:25,estado:'vencida'},
  // Pago validado superior al cargo no puede inflar el total cobrado del cargo.
  {socio_id:'c',origen:'cuota',importe:40,pagado_validado:45,saldo:0,estado:'pagada'}
];
const s=summarizeFinance(rows);
assert(s.total_generado===145,'total generado suma cuota + material + otros una sola vez');
assert(s.total_cobrado===100,'cobrado se limita al importe de cada cargo y no sobrecuenta sobrepagos');
assert(s.total_pendiente===45,'pendiente suma únicamente saldos restantes');
assert(s.total_vencido===25,'vencido suma el saldo de cargos vencidos');
assert(s.alumnos_con_deuda===2,'alumnos con deuda se cuentan sin duplicados');
assert(Math.abs(s.porcentaje_cobro-(100*100/145))<1e-9,'porcentaje de cobro deriva del mismo conjunto filtrado');
const byOrigin=groupFinance(rows,'origen',['cuota','material','otro']);
const cuota=byOrigin.find(x=>x.value==='cuota'),material=byOrigin.find(x=>x.value==='material'),otro=byOrigin.find(x=>x.value==='otro');
assert(cuota.total_generado===90&&cuota.total_cobrado===90,'desglose de cuotas cuadra');
assert(material.total_generado===30&&material.total_cobrado===10&&material.total_pendiente===20,'desglose de material cuadra');
assert(otro.total_generado===25&&otro.total_vencido===25,'desglose de otros cuadra');
assert(byOrigin.reduce((n,x)=>n+x.total_generado,0)===s.total_generado,'suma de orígenes coincide con total general');
console.log('RC13 FINANCE FILTER MATH: PASS');
