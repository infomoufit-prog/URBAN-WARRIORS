import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
const root=path.resolve(process.argv[2]||path.join(import.meta.dirname,'..'));
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const must=(ok,msg)=>{if(!ok)throw new Error(msg)};
const m143=read('supabase/migrations/143_kombax_finance_premium_v2_20079.sql');
const m144=read('supabase/migrations/144_kombax_finance_premium_dashboard_v2_20080.sql');
const m145=read('supabase/migrations/145_kombax_finance_premium_reports_v2_20081.sql');
const ui=read('web/js/modules/finance-premium.js');
const worker=read('supabase/functions/finance-report/index.ts');
const config=read('web/config.js'),index=read('web/index.html'),sw=read('web/service-worker.js');

must(/finance_reports_enabled/.test(m143)&&/'false'::jsonb/.test(m143),'143: reports flag must exist and start false');
must(/create table if not exists public\.informes_financieros/.test(m145),'145: historical report registry missing');
must(/snapshot jsonb not null/.test(m145)&&/totales jsonb not null/.test(m145),'145: immutable report dataset/totals missing');
must(/FINANCE_REPORT_SNAPSHOT_IMMUTABLE/.test(m145)&&/trg_finance_report_immutable_v145/.test(m145),'145: immutable snapshot trigger missing');
must(/FINANCE_REPORT_FILE_IMMUTABLE/.test(m145),'145: emitted PDF metadata must not be silently replaced');
must(/finance-reports','finance-reports',false/.test(m145),'145: finance report storage bucket must be private');
must(/finance_reports_read_v145/.test(m145)&&/tiene_rol_club\(\(\(storage\.foldername\(name\)\)\[1\]\)::uuid,'direccion','secretaria','economia'\)/.test(m145),'145: private storage read policy missing');
must(!/finance_reports_.*for insert to authenticated/i.test(m145),'145: browser must not write PDF objects directly');
must(/private\.finance_create_report_v145/.test(m145),'145: authoritative snapshot builder missing');
must(/app_finance_v2_dashboard_v144/.test(m145)&&/v_offset:=v_offset\+500/.test(m145),'145: report snapshot must reuse/paginate dashboard filter semantics');
must(/v_total>5000/.test(m145),'145: report dataset safety cap missing');
must(/group_discipline_scope','snapshot_at_report_generation'/.test(m145),'145: report must freeze current group/discipline labels');
must(/KX-FIN-/.test(m145)&&/informes_financieros_secuencia_v145/.test(m145),'145: per-club report identifier sequence missing');
must(/source_report_id/.test(m145)&&/max\(version\).*\+1/s.test(m145),'145: non-destructive updated-version lineage missing');
must(/finance\.informe\.crear/.test(m145)&&/app_mutate_v160_pre_finance_reports_145/.test(m145),'145: report creation must remain in the single mutation gateway');
must(/select backend_version into v_backend_version from public\.app_runtime_meta/.test(m145),'145: report gateway must preserve RC13 backend version');
must(/app_runtime_contract_v160_pre_finance_reports_145/.test(m145)&&/finance\.informe\.crear/.test(m145),'145: runtime contract extension missing');
must(/FINANCE_REPORT_SNAPSHOT/.test(m145)&&/FINANCE_REPORT_PDF/.test(m145),'145: snapshot and PDF audit trails missing');
must(/app_finance_v2_reports_v145/.test(m145)&&/app_finance_v2_report_payload_v145/.test(m145),'145: report list/payload APIs missing');
must(/app_finance_v2_report_file_attach_v145/.test(m145)&&/auth\.role\(\).*service_role/s.test(m145),'145: service-only atomic file attachment missing');
must(!/delete\s+from\s+public\.(pagos|recibos_cuota|informes_financieros)/i.test(m145),'145: historical finance objects must not be deleted');

for(const type of ['tesoreria_mensual','tesoreria_anual','cobros','pendientes','vencidos','por_grupo','por_disciplina','por_categoria','por_metodo_pago','licencias','competiciones','eventos','estado_cuenta'])must(m145.includes(`'${type}'`),`145: missing report type ${type}`);

must(/PDFDocument/.test(worker)&&/StandardFonts/.test(worker),'worker: real PDF generator missing');
must(/app_finance_v2_report_payload_v145/.test(worker)&&/Authorization:auth/.test(worker),'worker: authenticated report permission check missing');
must(/service\.storage\.from\('finance-reports'\)\.upload/.test(worker),'worker: private PDF upload missing');
must(/app_finance_v2_report_file_attach_v145/.test(worker),'worker: atomic file metadata/audit attach missing');
must(/Pagina \$\{i\+1\}\/\$\{pages\.length\}/.test(worker),'worker: page X/Y footer missing');
must(/Evolucion mensual/.test(worker)&&/Detalle financiero/.test(worker),'worker: KPI/chart/table PDF content missing');
must(/club\.logo_url/.test(worker)&&/club\.cif/.test(worker),'worker: club branding snapshot missing');
must(/archivo_sha256/.test(m145)&&/SHA-256/.test(worker),'worker: historical file hash missing');

must(/REPORT_TYPES/.test(ui)&&/Informe de esta vista/.test(ui),'UI: report catalog/current-view report missing');
must(/finance_reports_enabled/.test(ui),'UI: reports feature flag missing');
must(/backend\.mutate\('finance\.informe\.crear'/.test(ui),'UI: report snapshot must use authoritative gateway');
must(/backend\.invokeFunction\('finance-report'/.test(ui),'UI: PDF worker invocation missing');
must(/backend\.signedUrl\('finance-reports'/.test(ui),'UI: private signed PDF URL missing');
must(/Versión actualizada/.test(ui)&&/source_report_id/.test(ui),'UI: non-destructive report refresh missing');
must(/Estado de cuenta PDF/.test(ui)&&/estado_cuenta/.test(ui),'UI: individual account PDF action missing');
must(/PDF pendiente/.test(ui),'UI: recoverable snapshot/PDF partial failure state missing');
must(Number(config.match(/build:\s*(\d+)/)?.[1]||0)>=20081,'web: build number regressed below 20081');
const build=Number(config.match(/build:\s*(\d+)/)?.[1]||0);must(new RegExp(`finance-premium-bootstrap\\.js\\?v=${build}`).test(index),'web: Finance Premium bootstrap cache-bust does not match build');
must(sw.includes(`rc13-${build}`),'PWA: service worker build does not match current build');

for(const file of ['web/js/modules/finance-premium.js','web/js/modules/finance-premium-bootstrap.js','web/service-worker.js'])execFileSync(process.execPath,['--check',path.join(root,file)],{stdio:'pipe'});

// Lightweight structural sanity for the Edge TS file in environments without Deno.
for(const [a,b,name] of [['{','}','braces'],['(',')','parentheses'],['[',']','brackets']]){
  const left=[...worker].filter(c=>c===a).length,right=[...worker].filter(c=>c===b).length;must(left===right,`worker: unbalanced ${name}`);
}

console.log('OK 20081 finance premium reports/snapshots/PDF invariants');
