import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
const root=path.resolve(fileURLToPath(new URL('..',import.meta.url)));const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const schema=read('supabase/migrations/202_kombax_professional_basic_finance_20101_r31.sql');
const runtime=read('supabase/migrations/203_kombax_professional_finance_runtime_20101_r31.sql');
const ui=read('web/js/modules/professional-finance.js');const adapter=read('web/js/core/finance-adapter.js');const repos=read('web/js/core/repositories.js');const hub=read('web/js/modules/managed-profile-hub.js');const index=read('web/index.html');const sw=read('web/service-worker.js');
const checks=[
 ['No fake Club tenancy',!schema.includes('club_id uuid')&&schema.includes('professional_profile_id uuid not null')&&runtime.includes("'fake_club',false")],
 ['Dedicated professional finance capabilities',schema.includes('professional.finance.manage')&&schema.includes('professional.finance.reports')],
 ['Services charges payments expenses isolated', ['services_v199','charges_v199','payments_v199','expenses_v199'].every(x=>schema.includes('kombax_professional_'+x))],
 ['RLS and direct DML revoked',schema.includes('enable row level security')&&schema.includes('from public,anon,authenticated')],
 ['Runtime auth and capability gates',runtime.includes("raise exception 'AUTH_REQUIRED'")&&runtime.includes('app_kombax_puede_gestionar_perfil_v070')&&runtime.includes('professional.finance.manage')],
 ['Overpayment blocked and state derived',runtime.includes('KOMBAX_FINANCE_OVERPAYMENT_INVALID')&&runtime.includes('app_kombax_professional_charge_restate_v199')&&runtime.includes("when v_paid<v_amount then 'parcial'")],
 ['Cross-subject client/service/assignment blocked',runtime.includes('KOMBAX_FINANCE_CLIENT_SCOPE_INVALID')&&runtime.includes('KOMBAX_FINANCE_SERVICE_SCOPE_INVALID')&&runtime.includes('KOMBAX_FINANCE_ASSIGNMENT_SCOPE_INVALID')],
 ['Represented charge requires active delegation',runtime.includes('KOMBAX_FINANCE_REPRESENTATION_NOT_ACTIVE')&&runtime.includes("d.status='accepted'")&&runtime.includes('d.revoked_at is null')],
 ['Global notification center extended by subject',runtime.includes('alter table public.notificaciones alter column club_id drop not null')&&runtime.includes("subject_type='direct_profile'")&&runtime.includes('app_kombax_professional_finance_notifications_v199')],
 ['No in-app payments or fiscal invoicing claims',runtime.includes("'processes_money',false")&&runtime.includes("'fiscal_invoicing',false")&&ui.includes('no procesa dinero')&&ui.includes('no genera facturas fiscales automáticas')],
 ['Common finance adapter present',adapter.includes('normalizeProfessionalFinance')&&adapter.includes("PROFESSIONAL:'professional'")&&adapter.includes('chargeCanReceivePayment')],
 ['Repository RPC integration',repos.includes('app_kombax_professional_finance_v199')&&repos.includes('app_kombax_professional_finance_notifications_v199')&&repos.includes('app_kombax_professional_finance_mutate_v199')],
 ['Mi actividad finance module capability-gated',hub.includes('Finanzas Profesionales')&&hub.includes('professional.finance.manage')&&hub.includes('renderProfessionalFinance')],
 ['Basic 12-month report',runtime.includes("interval '11 months'")&&ui.includes('Últimos 12 meses')],
 ['R31-or-newer cache bust',/20101r3[1-9]/.test(index)&&/media-r3[1-9]/.test(sw)]
];
let ok=0;for(const [n,v] of checks){if(!v){console.error('FAIL · '+n);process.exitCode=1}else{ok++;console.log('PASS · '+n)}}console.log(`R31 ${ok}/${checks.length}`);
