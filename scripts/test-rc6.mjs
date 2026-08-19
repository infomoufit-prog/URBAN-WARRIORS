import { readFile,readdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createHash } from 'node:crypto';
const root=resolve(import.meta.dirname,'..');const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RC6: ${msg}`);console.log(`OK RC6: ${msg}`)};
const [cfg,repos,docs,portal,groups,finance,training,comms,admin,components,css,sql]=await Promise.all([
 read('web/config.js'),read('web/js/core/repositories.js'),read('web/js/modules/documents.js'),read('web/js/modules/portal.js'),read('web/js/modules/groups-members.js'),read('web/js/modules/finance.js'),read('web/js/modules/training.js'),read('web/js/modules/comms-material.js'),read('web/js/modules/admin.js'),read('web/js/ui/components.js'),read('web/css/app.css'),read('supabase/migrations/018_final_product_lifecycle_documents_v162.sql')
]);
assert(cfg.includes("version: '2.0.0-rc.13'")&&Number(cfg.match(/build:\s*(\d+)/)?.[1])>=20020&&cfg.includes('schemaEpoch: 160')&&cfg.includes("app_diagnostico_final_v166"),'RC13 conserva capa funcional RC6 y compatibilidad epoch 160');
for(const op of ['grupo.eliminar','alumno.archivar','alumno.eliminar','preinscripcion.cancelar','preinscripcion.eliminar','sesion.eliminar','disciplina.eliminar','grado.eliminar','tarifa.eliminar','material.eliminar','publicacion.eliminar','recibo.anular','documento.actualizar','documento.archivar','documento.eliminar'])assert(sql.includes(`'${op}'`)&&repos.includes(`'${op}'`),`operación gobernada ${op}`);
assert(sql.includes("estado in ('vigente','archivado','sustituido')")&&sql.includes('fecha_documento')&&sql.includes('reemplazado_por'),'expediente documental con trazabilidad');
assert(docs.includes('Archivo documental')&&docs.includes('Sustituir documento')&&docs.includes('member-documents')===false,'UI de archivo documental completa');
assert(portal.includes('Adjuntar documento')&&portal.includes('repos.documents.upload'),'familia/alumno puede aportar documentación a su expediente');
assert(groups.includes('Dar de baja')&&groups.includes('force-delete-member')&&groups.includes('force-delete-group'),'ciclo de vida de grupos y alumnos visible');
assert(finance.includes('Anular recibo')&&finance.includes('annulReceipt'),'recibos se anulan con trazabilidad');
assert(training.includes('delete-session')&&training.includes('force-delete-session'),'sesiones tienen borrado seguro y borrado total de Dirección');
assert(comms.includes('publication-detail')&&comms.includes('Leer más')&&comms.includes('Tienda del club')&&comms.includes('Solicitar material'),'publicaciones y tienda premium completas');
assert(admin.includes('Personalizar el club')&&admin.includes("uploadBrandImage('logo'")&&admin.includes("uploadBrandImage('cover'")&&admin.includes('publishBranding'),'personalización versionada con logo y portada subida a Storage');
assert(components.includes('--uw-cover-image')&&css.includes('.store-hero')&&css.includes('.brand-preview')&&css.includes('.publication-cover'),'branding premium usa color, logo y fondos');
assert(admin.includes('Subir y leer documento privado')&&admin.includes('Ciclo de vida seguro')&&admin.includes('E2E_RC10_'),'runner final verifica Storage y lifecycle');
let h=createHash('sha256');for(const f of (await readdir(resolve(root,'supabase/migrations'))).filter(x=>/^(00[1-9]|01[0-7])_.*\.sql$/.test(x)).sort()){h.update(f);h.update(await readFile(resolve(root,'supabase/migrations',f)))}
assert(h.digest('hex')==='f3f33071f6f9aefa76bca6972957482e2d1f907b3640f613a5277c5a858c0403','migraciones 001→017 conservadas byte a byte');
console.log('RC6 FINAL PRODUCT: PASS');
