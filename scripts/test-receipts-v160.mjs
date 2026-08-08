import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const root=resolve(import.meta.dirname,'..');
const [sql,store,app,css,config]=await Promise.all([
  readFile(resolve(root,'supabase/migrations/016_recibos_cuota.sql'),'utf8'),
  readFile(resolve(root,'web/js/data-store.js'),'utf8'),
  readFile(resolve(root,'web/js/app.js'),'utf8'),
  readFile(resolve(root,'web/css/app.css'),'utf8'),
  readFile(resolve(root,'web/config.js'),'utf8')
]);
const checks=[]; const check=(n,v)=>checks.push([n,Boolean(v)]);
check('tabla recibos única por cuota',sql.includes('create table if not exists public.recibos_cuota')&&sql.includes('unique (club_id, cuota_id)'));
check('numeración anual atómica',sql.includes('recibos_contadores')&&sql.includes("'UW-'||v_year::text||'-'||lpad(v_seq::text,6,'0')"));
check('emisión automática al pagar',sql.includes('trg_emitir_recibo_cuota_pagada')&&sql.includes("new.estado='pagada'"));
check('sin escritura cliente',sql.includes('revoke insert, update, delete on table public.recibos_cuota from public, anon, authenticated'));
check('lectura socio tutor tesorería',sql.includes('public.puede_ver_socio(socio_id)')&&sql.includes("'direccion','economia','secretaria'"));
check('notificación recibo disponible',sql.includes('Pago validado · recibo disponible')&&sql.includes("'recibo-'||v_fee.id::text"));
check('frontend carga recibos',store.includes("'recibos_cuota', `select=*&club_id=eq.${clubId}&order=periodo.desc,numero.desc`")&&store.includes('pagos, recibos, sesionesRaw'));
check('botón de recibo',app.includes('data-receipt=')&&app.includes('Ver recibo'));
check('PDF real cliente',app.includes('canvasJpegToPdf')&&app.includes("type:'application/pdf'")&&app.includes('Descargar PDF'));
check('diseño negro Warriors',css.includes('.receipt-card')&&css.includes('background: #050608')&&app.includes('Gracias por formar parte de Urban Warriors'));
check('build15',config.includes('build: 15'));
const bad=checks.filter(([,ok])=>!ok); for(const [n,ok] of checks) console.log(`${ok?'OK':'FAIL'} ${n}`);
if(bad.length) throw new Error(`Recibos: ${bad.length} fallo(s)`);
console.log(`OK: ${checks.length} controles de recibos Urban Warriors.`);
