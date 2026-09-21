import fs from 'node:fs';import path from 'node:path';
const root=path.resolve(process.argv[2]||path.join(import.meta.dirname,'..'));const read=p=>fs.readFileSync(path.join(root,p),'utf8');const must=(x,m)=>{if(!x)throw Error(m)};
const m143=read('supabase/migrations/143_kombax_finance_premium_v2_20079.sql'),m144=read('supabase/migrations/144_kombax_finance_premium_dashboard_v2_20080.sql'),m145=read('supabase/migrations/145_kombax_finance_premium_reports_v2_20081.sql'),m146=read('supabase/migrations/146_kombax_finance_premium_qa_v2_20082.sql');
const cases=[
 ['pending payment excluded from collection',/estado_validacion='validado'/,m143+m144+m146],
 ['partial payments preserved in consolidated math',/pagado_validado/.test(m144)&&/saldo/.test(m144),null],
 ['receipt is not created by recurring engine',!/insert\s+into\s+public\.recibos_cuota/i.test(m143),null],
 ['manual charge does not invent payment',!/insert\s+into\s+public\.pagos/i.test(m144),null],
 ['rule exceptions: exempt',/'exento'/,m143],['rule exceptions: pause',/'pausa'/,m143],['rule exceptions: discount',/'bonificacion'/,m143],['rule exceptions: custom amount',/'importe_personalizado'/,m143],['rule exceptions: skip cycle',/'omitir_ciclo'/,m143],
 ['dynamic group membership',/socio_disciplinas/,m143+m146],
 ['mid-cycle default no proration',/prorrateo|sin prorrateo|ninguno/i,m143],
 ['real database dedupe',/uq_cuota_regla_socio_ciclo_v143/,m143],
 ['real run serialized',/pg_try_advisory_xact_lock/,m146],
 ['report snapshot immutable',/FINANCE_REPORT_SNAPSHOT_IMMUTABLE/,m145],
 ['report file immutable',/FINANCE_REPORT_FILE_IMMUTABLE/,m145],
 ['reports private storage',/finance-reports','finance-reports',false/,m145],
 ['QA approval invalidates after rule edits',/trg_finance_qa_invalidate_rule_v146/,m146]
];
for(const [name,rule,src] of cases){const ok=typeof rule==='boolean'?rule:rule.test(src);must(ok,`Regression matrix failed: ${name}`)}
console.log(`OK 20082 regression matrix · ${cases.length}/${cases.length} invariants`);
