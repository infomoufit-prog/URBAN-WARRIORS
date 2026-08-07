import fs from 'node:fs';
import path from 'node:path';
const root=path.resolve(new URL('..', import.meta.url).pathname);
const app=fs.readFileSync(path.join(root,'web/js/app.js'),'utf8');
const store=fs.readFileSync(path.join(root,'web/js/data-store.js'),'utf8');
const sql=fs.readFileSync(path.join(root,'supabase/migrations/009_final_operational_v140.sql'),'utf8');
const checks=[
 ['registro solo preinscripción',/registrar_cuenta_club[\s\S]*insert into public\.preinscripciones/i.test(sql) && !/registrar_cuenta_club[\s\S]*insert into public\.socios/i.test(sql.split('create or replace function public.app_aprobar_preinscripcion')[0])],
 ['aprobación crea socio',/app_aprobar_preinscripcion[\s\S]*insert into public\.socios/i.test(sql)],
 ['aprobación valida aforo',/v_ocupacion>=v_plazas/i.test(sql)],
 ['lista de espera RPC',/app_lista_espera_preinscripcion/i.test(sql) && /waitlistEnrollment/i.test(store)],
 ['botón lista espera',/data-waitlist-enrollment/i.test(app)],
 ['mensajes y cierre homogéneo',/(finishMutation\()/g.test(app)],
 ['alta directa RPC',/app_guardar_socio/i.test(store)],
 ['grupos y horarios RPC',/app_guardar_grupo/i.test(store) && /p_horarios/i.test(store)],
 ['publicaciones Storage',/uploadPublicMedia\(file,'comunicaciones'\)/i.test(app)],
 ['material Storage',/uploadPublicMedia\(file,'material'\)/i.test(app)],
 ['documentos privados',/uploadMemberDocument/i.test(app) && /member-documents/i.test(store)],
 ['justificantes privados',/uploadPaymentProof/i.test(app) && /justificantes-pago/i.test(store)],
 ['refresh JWT',/refreshSession/i.test(store) && /ensureFreshSession/i.test(store)],
 ['diagnóstico final',/app_diagnostico_final/i.test(sql) && /runFinalDiagnostic/i.test(store)],
 ['Firebase preparado',/registerPushToken/i.test(store) && /UW_PUSH/i.test(app)]
];
const failed=checks.filter(([,ok])=>!ok).map(([name])=>name);
if(failed.length){console.error('FALLAN: '+failed.join(', '));process.exit(1)}
console.log(`OK: ${checks.length} circuitos finales verificados por contratos y código.`);
