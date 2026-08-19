import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const root=resolve(import.meta.dirname,'..');const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RC7: ${msg}`);console.log(`OK RC7: ${msg}`)};
const [cfg,repos,perms,app,groups,training,catalog,finance,comms,admin,sql]=await Promise.all([
  read('web/config.js'),read('web/js/core/repositories.js'),read('web/js/core/permissions.js'),read('web/js/app.js'),
  read('web/js/modules/groups-members.js'),read('web/js/modules/training.js'),read('web/js/modules/dashboard-catalog.js'),
  read('web/js/modules/finance.js'),read('web/js/modules/comms-material.js'),read('web/js/modules/admin.js'),read('supabase/migrations/019_final_deletion_media_cleanup_v163.sql')
]);
assert(cfg.includes("version: '2.0.0-rc.13'")&&Number(cfg.match(/build:\s*(\d+)/)?.[1])>=20020&&cfg.includes("app_diagnostico_final_v166"),'RC13 conserva regresión RC7 / v166');
for(const op of ['grupo.eliminar_forzado','alumno.eliminar_forzado','sesion.eliminar_forzado','disciplina.eliminar_forzado','grado.eliminar_forzado','tarifa.eliminar_forzado','material.eliminar_forzado','publicacion.limpiar_antiguas']) assert(sql.includes(`'${op}'`)&&repos.includes(`'${op}'`),`operación ${op}`);
assert(sql.includes("tiene_rol_club(p_club_id,'direccion','secretaria','comunicacion')")&&perms.includes("communication:['direccion','coordinacion','secretaria','comunicacion']")&&['communications','community','material','documents'].every(id=>app.includes(`'${id}'`)),'Secretaría entra en gestión editorial');
assert(sql.includes("datos->>'comunicacion_id'=v_id::text")&&sql.includes("'imagen_url',v_image"),'borrado de publicación limpia avisos y devuelve imagen');
assert(repos.includes("backend.remove('club-public-media'")&&comms.includes('quitar_imagen')&&comms.includes('Limpiar antiguas'),'limpieza física de multimedia integrada');
assert(comms.includes('repos.communications.removeImage(oldImage)')&&comms.includes('repos.material.removeImage(oldImage)'),'reemplazar/quitar imagen elimina archivo anterior');
assert(groups.includes('force-delete-member')&&groups.includes('force-delete-group')&&groups.includes('Escribe ELIMINAR'),'borrado total reforzado en alumnos y grupos');
assert(training.includes('force-delete-session')&&catalog.includes('force-delete-discipline')&&catalog.includes('force-delete-grade')&&finance.includes('force-delete-tariff')&&comms.includes('detail-force-delete-material'),'borrado total disponible en ciclo operativo');
assert(admin.includes('E2E_RC10_')&&admin.includes('repos.members.forceDelete')&&admin.includes('repos.groups.forceDelete')&&admin.includes('publicacionEImagen'),'certificación final limpia sus propios datos');

assert(comms.includes('delete-comm')&&comms.includes('incluir_publicadas'),'borrado directo y limpieza masiva opcional de publicadas');
assert(repos.includes('removeBrandImage')&&admin.includes('quitar_logo')&&admin.includes('quitar_portada'),'branding reemplazable sin dejar imágenes huérfanas');
assert(sql.includes("estado='publicada'")&&sql.includes("'included_published'"),'limpieza masiva puede incluir publicaciones publicadas por decisión explícita');
console.log('RC7 DELETION + MEDIA CLEANUP: PASS');
