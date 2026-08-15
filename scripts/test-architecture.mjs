import { readFile,readdir } from 'node:fs/promises';import { resolve,relative } from 'node:path';
const root=resolve(import.meta.dirname,'..'),web=resolve(root,'web');
async function files(dir){const out=[];for(const e of await readdir(dir,{withFileTypes:true})){const p=resolve(dir,e.name);if(e.isDirectory())out.push(...await files(p));else out.push(p)}return out}
const js=(await files(resolve(web,'js'))).filter(f=>f.endsWith('.js'));const texts=Object.fromEntries(await Promise.all(js.map(async f=>[relative(web,f).replaceAll('\\','/'),await readFile(f,'utf8')])));
const all=Object.values(texts).join('\n');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL: ${msg}`);console.log(`OK: ${msg}`)};
assert(!all.includes('UW_STORE'),'frontend 2.0 no reutiliza UW_STORE');
assert(!all.includes('demoMode'),'sin vía demo paralela');
const mutationEndpointRefs=(all.match(/mutationEndpoint/g)||[]).length;assert(mutationEndpointRefs>=2,'gateway versionado referenciado');
for(const [name,text] of Object.entries(texts)){if(name!=='js/core/supabase.js'&&name!=='js/app.js')assert(!/\bfetch\s*\(/.test(text),`${name} no hace fetch directo`)}
assert(/await this\.contract\(\)/.test(texts['js/core/backend.js']),'mutación valida contrato antes de escribir');
assert(/response\.backend_version===cfg\.release\.backendVersion/.test(texts['js/core/backend.js']),'respuesta de mutación valida versión backend');
assert(/response\.request_id===requestId/.test(texts['js/core/backend.js']),'respuesta valida request_id');
assert(!/cache\.put\(req,res\.clone\(\)\).*\.(?:js|css)/s.test(await readFile(resolve(web,'service-worker.js'),'utf8')),'service worker no cachea runtime JS/CSS');
const repos=texts['js/core/repositories.js'];const ops=[...repos.matchAll(/mutation\('([^']+)'/g)].map(m=>m[1]);const allowed=new Set(['disciplina.guardar','grado.guardar','grupo.guardar','alumno.guardar','matricula.solicitar','matricula.desactivar','graduacion.registrar','preinscripcion.crear','preinscripcion.aprobar','preinscripcion.espera','preinscripcion.rechazar','tarifa.guardar','pago.registrar_admin','pago.comunicar','pago.validar','cuota.pausar_avisos','cuota.reactivar_avisos','cuotas.generar','avisos.configurar','avisos.procesar','sesion.guardar','asistencia.guardar','checkin.registrar','seguimiento.guardar','publicacion.guardar','material.guardar','material.variante.guardar','material.solicitar','material.pedido.estado','notificacion.leer','invitacion.crear','club.configurar','perfil.guardar','documento.registrar','grupo.eliminar','alumno.archivar','alumno.eliminar','preinscripcion.cancelar','preinscripcion.eliminar','sesion.eliminar','disciplina.eliminar','grado.eliminar','tarifa.eliminar','material.eliminar','publicacion.eliminar','recibo.anular','documento.actualizar','documento.archivar','documento.eliminar','grupo.eliminar_forzado','alumno.eliminar_forzado','sesion.eliminar_forzado','disciplina.eliminar_forzado','grado.eliminar_forzado','tarifa.eliminar_forzado','material.eliminar_forzado','publicacion.limpiar_antiguas','sesion.reserva.confirmar','sesion.reserva.cancelar','notificacion.leer_grupo','notificacion.leer_todas','notificaciones.preferencias','sesion.serie.guardar','sesion.serie.finalizar','sesiones.recurrentes.generar','sesion.excepcion.guardar','comunidad.publicar','comunidad.eliminar','comunidad.moderar','comunidad.like','perfil.avatar','perfil_deportivo.guardar','perfil_deportivo.foto','perfil_deportivo.moderar','evento.guardar','evento.estado','evento.participante.externo','evento.inscripcion.solicitar','evento.inscripcion.estado','evento.inscripcion.baja','evento.combate.guardar','evento.combate.eliminar','notificacion.revisar','club_publico.guardar','comunidad_general.activar','comunidad.denunciar','comunidad.bloquear','comunidad.denuncia.estado','comunidad_general.moderar_acceso','legal.aceptar']);
assert(ops.every(o=>allowed.has(o)),`todas las operaciones repository pertenecen al contrato (${ops.length})`);
assert(new Set(ops).size>=30,`cobertura funcional de operaciones: ${new Set(ops).size}`);
assert(/form\.addEventListener\('submit'/.test(texts['js/ui/components.js']),'formularios tienen listener submit directo');
assert(/button\.disabled=true/.test(texts['js/ui/components.js'])&&/Guardando…/.test(texts['js/ui/components.js']),'estado visual Guardando y bloqueo doble envío');
assert(/await onSubmit\(values/.test(texts['js/ui/components.js']),'UI espera confirmación backend antes de cerrar formulario');
const formBlock=texts['js/ui/components.js'].match(/export function openForm[\s\S]*?export function openDetail/)?.[0]||'';
assert(!/e\.target===wrap\)close\(\)/.test(formBlock),'formularios no se cierran al volver del selector Android');
assert(/menuButton\?\.addEventListener\('click',\(\)=>setSidebarOpen\(!sidebar\?\.classList\.contains\('open'\)\)\)/.test(texts['js/app.js']),'el mismo botón móvil abre y cierra el menú lateral');
assert(/overflow-y:auto/.test(await readFile(resolve(web,'css/app.css'),'utf8'))&&/touch-action:pan-y/.test(await readFile(resolve(web,'css/app.css'),'utf8')),'menú lateral permite desplazamiento táctil vertical');
console.log('ARQUITECTURA RC10: PASS');
// Import graph and Android compatibility checks.
for(const [name,text] of Object.entries(texts)){
  for(const m of text.matchAll(/from\s+['"](\.\.?\/[^'"]+)['"]/g)){
    const target=resolve(web,name,'..',m[1]);
    try{await readFile(target,'utf8')}catch{throw new Error(`FAIL: import inexistente ${name} -> ${m[1]}`)}
  }
}

const adminSrc=await readFile(resolve(root,'web/js/modules/admin.js'),'utf8');
assert(/sessionAccessCode=`E2E\$\{Date\.now\(\)\.toString\(36\)/.test(adminSrc),'E2E usa código de sesión único por ejecución');
assert(!/codigo_acceso:'E2E'/.test(adminSrc),'E2E no reutiliza código fijo de sesión');
console.log('OK: grafo de imports relativo resuelto');
const gradle=await readFile(resolve(root,'android/app/build.gradle'),'utf8');
const mainActivity=await readFile(resolve(root,'android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),'utf8');
assert(/versionCode\s+20020/.test(gradle)&&/versionName '2\.0\.0-rc\.13'/.test(gradle),'Android RC13 versionado con build 20020');
assert(mainActivity.includes('appassets.androidplatform.net')&&mainActivity.includes('shouldInterceptRequest'),'Android sirve ES modules desde origen HTTPS virtual');
assert(mainActivity.includes('UrbanWarriorsApp/2.0.0-rc.13'),'User-Agent Android acompaña versión RC13');
