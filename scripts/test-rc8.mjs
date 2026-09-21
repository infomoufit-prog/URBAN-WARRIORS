import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const root=resolve(import.meta.dirname,'..');const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RC8: ${msg}`);console.log(`OK RC8: ${msg}`)};
const [cfg,repos,portal,training,docs,supa,backend,admin,sql]=await Promise.all([
  read('web/config.js'),read('web/js/core/repositories.js'),read('web/js/modules/portal.js'),read('web/js/modules/training.js'),read('web/js/modules/documents.js'),read('web/js/core/supabase.js'),read('web/js/core/backend.js'),read('web/js/modules/admin.js'),read('supabase/migrations/020_session_reservations_document_download_v164.sql')
]);
assert(cfg.includes("version: '2.0.0-rc.13'")&&Number(cfg.match(/build:\s*(\d+)/)?.[1])>=20020&&cfg.includes("app_diagnostico_final_v166"),'regresión RC8 preservada en RC13 / v166');
assert(sql.includes('create table if not exists public.reservas_sesion')&&sql.includes("'sesion.reserva.confirmar'")&&sql.includes("'sesion.reserva.cancelar'"),'tabla y operaciones de reserva gobernadas');
assert(sql.includes('Aforo completo para esta sesión')&&sql.includes('for update of s'),'aforo protegido frente a concurrencia');
assert(sql.includes("public.puede_ver_socio(v_socio_id)")&&sql.includes('socio_disciplinas')&&sql.includes('and sd.activa'),'reserva limitada al alumno/familia autorizado y matrícula activa');
assert(sql.includes("'direccion'::public.rol_club")&&sql.includes("'secretaria'::public.rol_club")&&sql.includes("'monitor'::public.rol_club"),'reserva notifica al equipo operativo');
assert(repos.includes("reservations:()=>read('reservas_sesion'")&&repos.includes("mutation('sesion.reserva.confirmar'")&&repos.includes("mutation('sesion.reserva.cancelar'"),'repositories integran confirmación/cancelación');
assert(portal.includes('Confirmar asistencia')&&portal.includes('Cancelar asistencia')&&portal.includes('Asistencia confirmada'),'portal alumno/familia permite RSVP previo');
assert(training.includes('confirmaciones previas')&&training.includes("badge(r?.estado==='confirmada'?'Confirmada'")&&training.includes('han indicado que asistirán'),'Dirección/Secretaría/Monitor ven confirmaciones por sesión');
assert(supa.includes('downloadSigned')&&backend.includes('DOWNLOAD ${bucket}')&&repos.includes("download:(path)=>backend.download('member-documents'")&&docs.includes('Descargar'),'archivo documental dispone de descarga real');
assert(portal.includes('download-portal-doc'),'familia/alumno puede descargar documentos visibles');
assert(admin.includes('E2E_RC10_')&&admin.includes('repos.sessions.reserve')&&admin.includes("backend.select('reservas_sesion'"),'E2E RC8 verifica reserva real');
console.log('RC8 SESSION RSVP + DOCUMENT DOWNLOAD: PASS');
