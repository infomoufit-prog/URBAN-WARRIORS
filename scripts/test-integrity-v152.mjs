import fs from 'node:fs';

const sql = fs.readFileSync('supabase/migrations/012_operational_integrity_v152.sql','utf8');
const app = fs.readFileSync('web/js/app.js','utf8');
const store = fs.readFileSync('web/js/data-store.js','utf8');
const css = fs.readFileSync('web/css/app.css','utf8');
const config = fs.readFileSync('web/config.js','utf8');
const pkg = JSON.parse(fs.readFileSync('package.json','utf8'));
const gradle = fs.readFileSync('android/app/build.gradle','utf8');

function section(name, nextName) {
  const start = sql.indexOf(`create or replace function public.${name}`);
  if (start < 0) return '';
  const end = nextName ? sql.indexOf(`create or replace function public.${nextName}`, start + 1) : sql.length;
  return sql.slice(start, end < 0 ? sql.length : end);
}

const saveMember = section('app_guardar_socio','app_registrar_graduacion');
const saveGroup = section('app_guardar_grupo','app_guardar_socio');
const savePost = section('app_guardar_comunicacion','app_guardar_variante_material');
const checkin = section('app_registrar_checkin','app_guardar_seguimiento');
const adminPayment = section('registrar_cobro_cuota','app_diagnostico_integridad_v152');
const autotest = section('app_autotest_operativo_v152');

const checks = [
  ['versión web 1.5.2', config.includes("version: '1.5.2'") && config.includes('build: 10')],
  ['versión paquete 1.5.2', pkg.version === '1.5.2'],
  ['versión Android 1.5.2', gradle.includes('versionCode 10') && gradle.includes("versionName '1.5.2'")],
  ['índice multigrupo activo', sql.includes('uq_socio_disciplina_grupo_activa')],
  ['alta de alumno sin conflicto antiguo', !saveMember.includes('on conflict(club_id,socio_id,disciplina_id)') && !saveMember.includes('disciplina_id<>')],
  ['alta conserva otras matrículas', saveMember.includes('grupo_id=p_grupo_id') && !/update\s+public\.socio_disciplinas[\s\S]*set\s+activa=false/i.test(saveMember)],
  ['grupos y horarios se guardan en una transacción RPC', saveGroup.includes('delete from public.horarios_grupo') && saveGroup.includes('insert into public.horarios_grupo') && saveGroup.includes('Hay horarios solapados')],
  ['publicación y notificación son una única RPC', savePost.includes('insert into public.comunicaciones') && savePost.includes('insert into public.notificaciones') && savePost.includes('notificada_en=now()')],
  ['publicaciones idempotentes por audiencia/rol', savePost.includes('on conflict(club_id,audiencia,clave)') && savePost.includes('on conflict(club_id,rol_destino,clave)')],
  ['check-in y asistencia atómicos', checkin.includes('insert into public.registros_acceso_clase') && checkin.includes('insert into public.asistencias')],
  ['cobro administrativo notifica en servidor', adminPayment.includes('insert into public.pagos') && adminPayment.includes('update public.cuotas') && adminPayment.includes('insert into public.notificaciones')],
  ['perfil propio usa RPC', store.includes("supabase.rpc('app_guardar_perfil_propio'")],
  ['baja de matrícula usa RPC específica', store.includes("supabase.rpc('app_desactivar_matricula'") && app.includes('data-disable-enrollment')],
  ['frontend carga todas las matrículas', store.includes('const matriculas = links.map') && store.includes('grupo_ids: [...new Set(links.map') && app.includes('memberEnrollments(member)')],
  ['check-in frontend usa RPC atómica', store.includes("supabase.rpc('app_registrar_checkin'")],
  ['asistencia frontend usa RPC', store.includes("supabase.rpc('app_guardar_asistencia'")],
  ['seguimiento frontend usa RPC', store.includes("supabase.rpc('app_guardar_seguimiento'")],
  ['documentos limpian Storage si falla DB', store.includes("storageRemove('member-documents'")],
  ['publicaciones limpian imagen si falla DB', app.includes('if (uploaded) await store.removePublicMedia(uploaded)')],
  ['edición limpia imagen anterior tras guardar', app.includes('previousImage') && app.includes('previousImage !== uploaded')],
  ['justificante dispone de limpieza compensatoria', store.includes('async removePaymentProof(') && sql.includes('justificantes_borrar_autorizados')],
  ['errores de guardado visibles en formulario', app.includes('No se ha guardado:') && css.includes('.form-error')],
  ['cierre/retorno de formulario actualiza hash', /function finishMutation[\s\S]*history\.replaceState/.test(app)],
  ['autotest real cubre publicación', autotest.includes("'-PUBLICACION'") && autotest.includes('publicación no guardada/notificada')],
  ['autotest real cubre alumno multigrupo', autotest.includes('multigrupo no conservó ambas matrículas')],
  ['autotest real cubre pagos', autotest.includes('pago comunicado no pausó avisos') && autotest.includes('cobro administrativo no actualizó cuota')],
  ['autotest real limpia datos temporales', autotest.includes('Limpieza explícita') && autotest.includes('delete from public.socios')],
  ['diagnóstico real incluido', sql.includes('app_diagnostico_integridad_v152') && sql.includes('policy_justificantes_delete')],
  ['recarga del esquema PostgREST', sql.includes("notify pgrst, 'reload schema'")],
];

const failed = checks.filter(([,ok]) => !ok);
for (const [name,ok] of checks) console.log(`${ok ? 'OK' : 'FALLO'}: ${name}`);
if (failed.length) {
  throw new Error(`Integridad 1.5.2: ${failed.length} comprobaciones fallaron: ${failed.map(([n])=>n).join(', ')}`);
}
console.log(`OK: ${checks.length} comprobaciones de integridad 1.5.2.`);
