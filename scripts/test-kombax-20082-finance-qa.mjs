import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';

const root=path.resolve(process.argv[2]||path.join(import.meta.dirname,'..'));
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const must=(ok,msg)=>{if(!ok)throw new Error(msg)};
const m143=read('supabase/migrations/143_kombax_finance_premium_v2_20079.sql');
const m144=read('supabase/migrations/144_kombax_finance_premium_dashboard_v2_20080.sql');
const m145=read('supabase/migrations/145_kombax_finance_premium_reports_v2_20081.sql');
const m146=read('supabase/migrations/146_kombax_finance_premium_qa_v2_20082.sql');
const ui=read('web/js/modules/finance-premium.js');
const cfg=read('web/config.js');
const index=read('web/index.html');
const sw=read('web/service-worker.js');

must(/finance_qa_shadow_approved.*false/s.test(m146),'146: QA gate must start closed');
must(/finance_qa_shadow_runs/.test(m146)&&/fingerprint text not null/.test(m146),'146: deterministic shadow history missing');
must(/app_finance_v2_qa_status_v146/.test(m146),'146: QA status RPC missing');
must(/finance_qa_anomalies_v146/.test(m146),'146: invariant scanner missing');
for(const marker of ['duplicate_rule_student_cycle','duplicate_generation_key','validated_overpayment','account_view_mismatch','receipt_before_full_payment','paid_charge_without_active_receipt','report_file_missing'])must(m146.includes(marker),`146: blocker ${marker} missing`);
must(/estado_validacion='validado'/.test(m146),'146: financial balance checks must use validated payments only');
must(/estado_validacion='pendiente'/.test(m146),'146: pending validation visibility missing');
must(/finance_qa_fingerprint_v146/.test(m146)&&/socio_disciplinas/.test(m146)&&/reglas_cobro_excepciones/.test(m146),'146: shadow fingerprint must include dynamic recipients/config/exceptions');
must(/FINANCE_QA_TWO_SHADOW_RUNS_REQUIRED/.test(m146)&&/FINANCE_QA_SHADOW_RUNS_NOT_EQUIVALENT/.test(m146),'146: approval must require two equivalent shadow runs');
must(/r1\.fingerprint<>r2\.fingerprint/.test(m146)&&/r1\.fecha_proceso<>r2\.fecha_proceso/.test(m146),'146: shadow equivalence must bind date and fingerprint');
must(/trg_finance_qa_invalidate_rule_v146/.test(m146)&&/trg_finance_qa_invalidate_target_v146/.test(m146)&&/trg_finance_qa_invalidate_exception_v146/.test(m146),'146: config changes must revoke approval');
must(/finance_qa_shadow_approved=false/.test(m146),'146: real recurring engine must be gated by QA approval');
must(/pg_try_advisory_xact_lock/.test(m146)&&/finance_real_run_in_progress/.test(m146),'146: real concurrency serialization missing');
must(/FINANCE_QA_APPROVAL_REQUIRED_BEFORE_RECURRING/.test(m146),'146: recurring flag cannot be enabled before QA approval');
must(/app_mutation_requests/.test(m146)&&/MUTATION_REQUEST_ID_REUSED/.test(m146),'146: QA mutations must preserve gateway idempotency');
must(/finance\.qa\.shadow\.run/.test(m146)&&/finance\.qa\.aprobar/.test(m146)&&/finance\.qa\.revocar/.test(m146),'146: QA gateway operations missing');
must(!/delete\s+from\s+public\.(pagos|cuotas|recibos_cuota|informes_financieros)/i.test(m146),'146: QA migration must not delete financial history');
must(!/update\s+public\.(pagos|cuotas|recibos_cuota|informes_financieros)/i.test(m146),'146: QA migration must not rewrite financial history');

must(/uq_cuota_regla_socio_ciclo_v143/.test(m143)&&/on conflict do nothing/i.test(m143),'regression: recurring database idempotency missing');
must(/app_finance_v2_preview_cargo_v144/.test(m144),'regression: mandatory manual charge preview missing');
must(/FINANCE_REPORT_FILE_IMMUTABLE/.test(m145)&&/FINANCE_REPORT_SNAPSHOT_IMMUTABLE/.test(m145),'regression: immutable reports missing');
must(/values\('finance-reports','finance-reports',false/.test(m145),'regression: finance reports storage must remain private');

must(/app_finance_v2_qa_status_v146/.test(ui)&&/Ejecutar Shadow QA/.test(ui),'UI: QA center/status missing');
must(/finance\.qa\.shadow\.run/.test(ui)&&/finance\.qa\.aprobar/.test(ui)&&/finance\.qa\.revocar/.test(ui),'UI: QA actions missing');
must(/Dos Shadow equivalentes/.test(ui)&&/Anomalías bloqueantes/.test(ui),'UI: approval evidence not visible');
must(!/shadow\s*:\s*false/.test(ui),'UI: 20082 must not expose a non-shadow recurring execution');
must(!/finance_recurring_enabled[^\n]{0,120}true/.test(ui),'UI: 20082 must not enable recurring mode');

const build=Number(cfg.match(/build:\s*(\d+)/)?.[1]||0);
must(build>=20082,'web: build number below 20082');
must(index.includes(`finance-premium-bootstrap.js?v=${build}`),'web: premium bootstrap cache-buster mismatch');
must(sw.includes(`rc13-${build}`),'PWA: service worker cache version mismatch');

for(const file of ['web/js/modules/finance-premium.js','web/js/modules/finance-premium-bootstrap.js','web/service-worker.js'])execFileSync(process.execPath,['--check',path.join(root,file)],{stdio:'pipe'});

console.log('OK 20082 finance premium QA/shadow gate invariants');
