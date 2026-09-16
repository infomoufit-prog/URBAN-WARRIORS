import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(fileURLToPath(new URL('..',import.meta.url)));
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const sql=read('supabase/migrations/200_kombax_professional_relations_operations_20101_r30.sql');
const ops=read('web/js/modules/professional-operations.js');
const hub=read('web/js/modules/managed-profile-hub.js');
const repos=read('web/js/core/repositories.js');
const gateway=read('web/js/modules/gateway.js');
const index=read('web/index.html');
const sw=read('web/service-worker.js');
const checks=[
 ['Professional entities isolated by subject', sql.includes('kombax_professional_clients_v198') && sql.includes('professional_profile_id uuid not null') && sql.includes('kombax_professional_sessions_v198')],
 ['No clinical health domain introduced', !sql.includes('kombax_health_') && !sql.includes('historia_clinica') && sql.includes("'clinical_health_records_enabled',false") && ops.includes('no contiene expediente sanitario ni datos clínicos')],
 ['Specialty capability mapping', sql.includes('kombax_professional_specialty_capabilities_v198') && sql.includes("('representante_manager','professional.delegations.manage',true)") && sql.includes("('promotor_organizador','events.public.organize',true)")],
 ['Manager consent state machine', sql.includes("status in ('requested','accepted','rejected','revoked','expired')") && sql.includes('KOMBAX_DELEGATION_TARGET_OWNER_REQUIRED') && sql.includes("status='revoked'")],
 ['Manager permission allowlist', sql.includes('KOMBAX_DELEGATION_PERMISSION_NOT_ALLOWED') && sql.includes("'calendar.read','opportunities.manage','events.requests.manage','professional_fields.edit','representation.documents.manage'")],
 ['Competitor remains target not professional subtype', sql.includes("d.tipo='competidor'") && hub.includes('Competidor sigue separado del Perfil Profesional')],
 ['Events assignments limited', sql.includes("assignment_type in ('medical','official')") && sql.includes('app_kombax_evento_puede_gestionar_v160') && sql.includes("array['assignment.read','result.submit']")],
 ['Security definer checks auth and managed subject', sql.includes("if v_uid is null then raise exception 'AUTH_REQUIRED'") && sql.includes("app_kombax_puede_gestionar_perfil_v070(p_profile_id,'read')")],
 ['Private tables have RLS and revoked direct access', sql.includes('enable row level security') && sql.includes('revoke all on public.kombax_professional_delegations_v198 from public,anon,authenticated')],
 ['Frontend RPC integration', repos.includes('app_kombax_professional_workspace_v198') && repos.includes('app_kombax_professional_mutate_v198') && gateway.includes('renderProfessionalOperations')],
 ['Competitor can accept reject revoke', ops.includes('delegation-accept') && ops.includes('delegation-reject') && ops.includes('delegation-revoke')],
 ['R30-or-newer cache bust', /20101r(?:3[0-9]|[4-9][0-9])/.test(index) && /media-r(?:3[0-9]|[4-9][0-9])/.test(sw)]
];
let ok=0;
for(const [n,v] of checks){if(!v){console.error('FAIL · '+n);process.exitCode=1}else{ok++;console.log('PASS · '+n)}}
console.log(`R30 ${ok}/${checks.length}`);
