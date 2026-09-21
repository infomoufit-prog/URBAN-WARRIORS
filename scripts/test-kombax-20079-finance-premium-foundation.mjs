import fs from 'node:fs'
import path from 'node:path'

const root=process.cwd()
const migration=fs.readFileSync(path.join(root,'supabase/migrations/143_kombax_finance_premium_v2_20079.sql'),'utf8')
const worker=fs.readFileSync(path.join(root,'supabase/functions/finance-recurring/index.ts'),'utf8')

function must(text, pattern, message){
  if(!(pattern instanceof RegExp ? pattern.test(text) : text.includes(pattern))){
    throw new Error(message)
  }
}
function mustNot(text, pattern, message){
  if(pattern instanceof RegExp ? pattern.test(text) : text.includes(pattern)){
    throw new Error(message)
  }
}

// Feature flags and safe rollout.
for(const flag of ['finance_v2_enabled','finance_dashboard_v2_enabled','finance_recurring_enabled','finance_reports_enabled']){
  must(migration,flag,`Falta feature flag ${flag}`)
}
must(migration,"'false'::jsonb",'Los flags deben arrancar desactivados')
must(migration,'p_shadow boolean default true','El motor debe arrancar en shadow por defecto')
must(migration,"current_setting('request.jwt.claim.role',true)",'La detección server-side debe tolerar el claim de service role existente')

// Data model.
for(const table of ['reglas_cobro','reglas_cobro_destinatarios','reglas_cobro_excepciones','reglas_cobro_ejecuciones']){
  must(migration,`public.${table}`,`Falta ${table}`)
}
must(migration,'uq_cuota_regla_socio_ciclo_v143','Falta UNIQUE club+regla+socio+ciclo')
must(migration,'uq_cuota_generacion_clave_v143','Falta segunda defensa de clave de generación')
must(migration,'on conflict do nothing','La generación debe tolerar retries/doble click')
must(migration,'public.socio_disciplinas','Los scopes grupo/disciplina deben resolverse dinámicamente')
must(migration,"politica_alta in ('siguiente_ciclo','manual_ciclo_actual_completo')",'Falta política explícita de altas intermedias')
must(migration,"prorrateo_modo='ninguno'",'El prorrateo no puede activarse implícitamente')

// Sacred existing payment/receipt semantics are not rewritten by this migration.
mustNot(migration,/update\s+public\.pagos\s+set/i,'20079 no debe reinterpretar pagos históricos')
mustNot(migration,/delete\s+from\s+public\.pagos/i,'20079 no debe borrar pagos')
mustNot(migration,/delete\s+from\s+public\.recibos_cuota/i,'20079 no debe borrar recibos')
mustNot(migration,/update\s+public\.recibos_cuota\s+set/i,'20079 no debe reescribir recibos históricos')

// Gateway, audit and privacy.
must(migration,'app_mutate_v160_pre_finance_143','Las mutaciones Finance V2 deben encadenarse al gateway existente')
must(migration,'public.app_mutation_requests','Las mutaciones deben reutilizar idempotencia por request_id')
must(migration,'public.registrar_auditoria()','Falta auditoría financiera')
must(migration,'enable row level security','Las nuevas tablas públicas deben activar RLS')
must(migration,'revoke all on schema private from public, anon, authenticated','El núcleo privado no debe exponerse al Data API')

// Notifications: produce events; do not create a push stack.
must(migration,'insert into public.notificaciones','Finance V2 debe publicar eventos al centro existente')
must(migration,"'Tienes un nuevo cargo del club.'",'Copy financiero debe ser neutro')
mustNot(migration,/firebase|fcm|dispositivos_push/i,'La migración no debe duplicar el dispatcher push')

// Scheduler worker: same cron security, service role, no browser cron or push implementation.
must(worker,"../_shared/cron-security.ts",'El worker debe reutilizar seguridad cron compartida')
must(worker,"procesar_cargos_recurrentes",'El worker debe llamar al motor autoritativo')
must(worker,"const shadow = body.shadow !== false",'El scheduler debe arrancar en shadow salvo activación explícita')
must(worker,"SUPABASE_SERVICE_ROLE_KEY",'El worker debe usar credenciales exclusivamente server-side')
mustNot(worker,/firebase|fcm/i,'El worker de recurrencia no debe implementar push')
mustNot(worker,/window\.|document\./i,'La recurrencia no puede depender del navegador')

console.log('OK 20079 finance premium foundation invariants')
