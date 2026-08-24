import { backend } from './backend.js';
import { state } from './state.js';

const club=()=>state.session?.club_id;
const ensure=()=>{if(!club())throw new Error('No hay un club activo.');return club();};
const enc=value=>encodeURIComponent(String(value||''));

export const financePremiumRepo={
  context:()=>backend.readRpc('app_finance_v2_context_v145',{p_club_id:ensure()}),
  dashboard:(filters={})=>backend.readRpc('app_finance_v2_dashboard_v146',{p_club_id:ensure(),p_filters:filters||{}}),
  rows:(filters={},limit=60,offset=0)=>backend.readRpc('app_finance_v2_rows_v146',{p_club_id:ensure(),p_filters:filters||{},p_limit:limit,p_offset:offset}),
  rules:()=>backend.select('reglas_cobro',`select=*&club_id=eq.${enc(ensure())}&order=activa.desc,nombre`),
  ruleScopes:()=>backend.select('reglas_cobro_destinatarios',`select=*&club_id=eq.${enc(ensure())}&order=creado_en`),
  exceptions:()=>backend.select('reglas_cobro_excepciones',`select=*&club_id=eq.${enc(ensure())}&order=activa.desc,creado_en.desc&limit=500`),
  reports:()=>backend.select('finanzas_informes',`select=id,identificador,tipo,titulo,filtros,resumen,version,storage_path,storage_sha256,archivo_estado,archivo_bytes,generado_en,generado_por,origen_informe_id&club_id=eq.${enc(ensure())}&order=generado_en.desc&limit=200`),
  reportSnapshot:(id)=>backend.select('finanzas_informes',`select=*&club_id=eq.${enc(ensure())}&id=eq.${enc(id)}&limit=1`).then(rows=>rows?.[0]||null),
  charge:(id)=>backend.select('v_finanzas_detalle_v2',`select=*&club_id=eq.${enc(ensure())}&cuota_id=eq.${enc(id)}&limit=1`).then(rows=>rows?.[0]||null),
  payment:(id)=>backend.select('pagos',`select=*&club_id=eq.${enc(ensure())}&id=eq.${enc(id)}&limit=1`).then(rows=>rows?.[0]||null),
  receipt:(id)=>backend.select('recibos_cuota',`select=*&club_id=eq.${enc(ensure())}&id=eq.${enc(id)}&limit=1`).then(rows=>rows?.[0]||null),
  previewRule:(ruleId,date=null,forceCurrent=false)=>backend.readRpc('app_finance_v2_preview_v144',{p_club_id:ensure(),p_regla_id:ruleId,p_fecha:date,p_force_current:forceCurrent}),
  shadowRule:(ruleId,date=null,forceCurrent=false)=>backend.mutate('finance.v2.rule.shadow',{regla_id:ruleId,fecha:date,force_current:forceCurrent}),
  generateRuleNow:(ruleId,date=null,forceCurrent=false)=>backend.mutate('finance.v2.rule.generate_now',{regla_id:ruleId,fecha:date,force_current:forceCurrent}),
  setFeature:(key,enabled)=>backend.mutate('finance.v2.feature.set',{key,enabled:Boolean(enabled)}),
  saveRule:(payload)=>backend.mutate('finance.v2.rule.save',payload),
  replaceRuleScopes:(ruleId,destinatarios)=>backend.mutate('finance.v2.rule.scopes.replace',{regla_id:ruleId,destinatarios}),
  saveException:(payload)=>backend.mutate('finance.v2.exception.save',payload),
  previewCharge:(payload)=>backend.readRpc('app_finance_v2_charge_preview_v145',{p_club_id:ensure(),p_payload:payload}),
  createCharge:(payload)=>backend.mutate('finance.v2.charge.create',payload),
  createReport:(payload)=>backend.mutate('finance.v2.report.create',payload),
  finalizeReport:(reportId,sha256,bytes)=>backend.mutate('finance.v2.report.finalize',{report_id:reportId,sha256,bytes}),
  uploadReport:(path,blob)=>backend.upload('finance-reports',path,blob,false),
  reportUrl:(path,expires=600)=>backend.signedUrl('finance-reports',path,expires)
};
