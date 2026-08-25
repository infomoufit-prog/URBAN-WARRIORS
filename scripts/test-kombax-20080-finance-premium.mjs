import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const root=path.resolve(process.argv[2]||path.join(import.meta.dirname,'..'));
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const must=(ok,msg)=>{if(!ok)throw new Error(msg)};
const m143=read('supabase/migrations/143_kombax_finance_premium_v2_20079.sql');
const m144=read('supabase/migrations/144_kombax_finance_premium_dashboard_v2_20080.sql');
const premium=read('web/js/modules/finance-premium.js');
const bootstrap=read('web/js/modules/finance-premium-bootstrap.js');
const index=read('web/index.html');
const config=read('web/config.js');
const sw=read('web/service-worker.js');

must(/finance_v2_enabled/.test(m143)&&/finance_dashboard_v2_enabled/.test(m143)&&/finance_recurring_enabled/.test(m143),'143: missing finance feature flags');
must(/'false'::jsonb/.test(m143),'143: flags must start false');
must(/uq_cuota_regla_socio_ciclo_v143/.test(m143),'143: database idempotency index missing');
must(/on conflict do nothing/i.test(m143),'143: retry/concurrency protection missing');
must(/procesar_cargos_recurrentes/.test(m143)&&/p_shadow boolean default true/.test(m143),'143: recurring engine must default to shadow');
must(!/delete\s+from\s+public\.(pagos|recibos_cuota)/i.test(m143),'143: historical payments/receipts must not be deleted');

must(/app_finance_v2_dashboard_v144/.test(m144),'144: premium dashboard RPC missing');
must(/app_finance_v2_preview_cargo_v144/.test(m144),'144: mandatory manual charge preview missing');
must(/finance\.cargo\.crear/.test(m144),'144: manual charge gateway operation missing');
must(/backend_version.*app_runtime_meta|select backend_version into v_backend_version from public\.app_runtime_meta/s.test(m144),'144: gateway must return active runtime backend version');
must(!/1\.6\.0\+finance-v143/.test(m144),'144: incompatible synthetic backend version reintroduced');
must(/p_estado='pendiente_abierto'/.test(m144)&&/p_estado='vencido_abierto'/.test(m144),'144: interactive KPI filters missing');
must(/join filtered f/.test(m144)&&/estado_validacion='pendiente'/.test(m144),'144: pending validation counter must share filtered dataset');
must(/private\.finance_manual_recipients_v144/.test(m144)&&/select distinct c\.socio_id/.test(m144),'144: recipient deduplication missing');
must(!/insert\s+into\s+public\.pagos/i.test(m144),'144: KOMBAX must not invent/process bank money');
must(/p_operation='finance\.cargo\.crear'.*finance_v2_enabled/s.test(m144),'144: manual charge write must be protected by finance_v2_enabled');
must(/finance-v2-manual-.*perfil_id/s.test(m144)&&/Tienes un nuevo cargo del club/.test(m144),'144: manual charges must publish grouped recipient events to the existing notification pipeline');
must(/public\.auditoria/.test(m144)&&/finance\.cargo\.crear/.test(m144),'144: manual bulk charge must be audited');

must(/const names=\['Categoría','Concepto','Destinatarios','Importe','Periodo','Vencimiento','Observaciones','Preview'\]/.test(premium),'UI: + Nuevo cargo must keep the 8-step wizard');
must(/app_finance_v2_preview_cargo_v144/.test(premium)&&/Crear cargos/.test(premium),'UI: preview-before-create flow missing');
must(/fv2-kpi/.test(premium)&&/(fv2-bar-button|fv2-chart-svg)/.test(premium)&&/(data-aging|fv2-donut-seg)/.test(premium),'UI: interactive KPI/chart/aging controls missing');
must(/fv2-mobile/.test(premium)&&/fv2-card/.test(premium),'UI: mobile card layout missing');
must(/finance_dashboard_v2_enabled/.test(premium),'UI: dashboard feature flag gate missing');
must(/legacy=main\?\.innerHTML/.test(bootstrap)&&/main\.innerHTML=legacy/.test(bootstrap)&&/main\.querySelector\('\.fv2-tabs'\)/.test(bootstrap),'UI: automatic RC13 fallback missing');
const currentBuild=Number(config.match(/build:\s*(\d+)/)?.[1]||0);
must(currentBuild>=20080,'web: build number regressed below 20080');
must(new RegExp(`finance-premium-bootstrap\\.js\\?v=${currentBuild}`).test(index),'web: premium bootstrap not loaded for current build');
must(sw.includes(`rc13-${currentBuild}`),'PWA: service worker build does not match current build');

must(/select backend_version into v_backend_version from public\.app_runtime_meta/.test(m143),'143 corrected bundle must preserve exact RC13 backend version');
must(!/1\.6\.0\+finance-v143/.test(m143),'143 corrected bundle must not emit a synthetic backend version');
must(/'payments',coalesce\(v_payments/.test(m144)&&/'receipts',coalesce\(v_receipts/.test(m144),'144: global filters must feed payments and receipts from the same filtered dataset');
must(/v_concepto\|\|'.*left\(v_lote/.test(m144),'144: manual batch must preserve distinct same-period concepts without changing public concept');
must(/data-state=\"\$\{state\}\"/.test(premium)&&/filters\.estado=b\.dataset\.state/.test(premium),'UI: chart series must drill into generated/collected/pending state');
must(/name:'activa'.*value:false/.test(premium)&&/toggle-rule/.test(premium),'UI: automation must support explicit paused/active state');
must(/payments\(D\.payments/.test(premium)&&/receipts\(D\.receipts/.test(premium),'UI: Payments/Receipts tabs must honor the dashboard cross-filter dataset');
must(!/shadow:false/.test(premium),'UI: 20080 must not expose non-shadow recurring execution');

for(const file of ['web/js/modules/finance-premium.js','web/js/modules/finance-premium-bootstrap.js','web/service-worker.js']){
  execFileSync(process.execPath,['--check',path.join(root,file)],{stdio:'pipe'});
}

console.log('OK 20080 finance premium dashboard/manual-charge invariants');
