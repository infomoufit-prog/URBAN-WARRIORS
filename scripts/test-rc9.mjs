import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const root=resolve(import.meta.dirname,'..');const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RC9: ${msg}`);console.log(`OK RC9: ${msg}`)};
const [cfg,permissions,backend,app,admin,dashboard,sql,pkg,gradle]=await Promise.all([
  read('web/config.js'),read('web/js/core/permissions.js'),read('web/js/core/backend.js'),read('web/js/app.js'),read('web/js/modules/admin.js'),read('web/js/modules/dashboard-catalog.js'),read('supabase/migrations/021_access_roles_gestor_coordinacion_v165.sql'),read('package.json'),read('android/app/build.gradle')
]);
assert(cfg.includes("version: '2.0.0-rc.13'")&&Number(cfg.match(/build:\s*(\d+)/)?.[1])>=20020&&cfg.includes("app_diagnostico_final_v166"),'RC13 conserva Gestor/Coordinación de RC9 y diagnóstico v166');
assert(permissions.includes("direccion:'Gestor de la app'")&&permissions.includes("coordinacion:'Coordinación'"),'nombres de rol definitivos');
assert(permissions.includes("invite:['direccion']")&&permissions.includes("certification:['direccion']"),'invitaciones y E2E reservados al Gestor de la app');
for(const key of ['discipline','member','tariff','communication','session','document','paymentAdmin','clubConfig'])assert(new RegExp(`${key}:\\[[^\\]]*'coordinacion'`).test(permissions),`Coordinación recibe permiso operativo ${key}`);
assert(backend.includes("effectiveRole=isCoordination?'coordinacion':chosen.rol")&&backend.includes("effectiveRoles=isCoordination?['coordinacion']"),'sesión colapsa permisos auxiliares bajo Coordinación');
assert(app.includes("role==='direccion'||role==='coordinacion'")&&app.includes("if(state.session?.platform_admin===true){allowed.add('diagnostics')"),'Gestor/Coordinación comparten navegación operativa y las herramientas técnicas quedan reservadas al administrador global');
assert(admin.includes("{value:'coordinacion',label:'Coordinación'}")&&admin.includes("m.coord?'Coordinación'")&&admin.includes("isManager=state.session?.rol==='direccion'"),'equipo representa Coordinación como un único rol y solo Gestor puede concederla');
assert(admin.includes('Área reservada a la Administración global de KOMBAX')&&admin.includes('Solo la administración global de KOMBAX puede ejecutar la certificación.'),'herramientas técnicas quedan restringidas a Administración KOMBAX');
assert(dashboard.includes("coordination=role==='coordinacion'")&&dashboard.includes('Coordinación · Gestión operativa')&&dashboard.includes('Gestor de la app · Panel global'),'dashboard distingue Gestor y Coordinación');
assert(sql.includes('add column if not exists coordinacion boolean')&&sql.includes("values\n        (v_club_id,v_uid,'secretaria',true,true),\n        (v_club_id,v_uid,'economia',true,true),\n        (v_club_id,v_uid,'comunicacion',true,true)"),'Coordinación usa permisos operativos compuestos certificados');
assert(sql.includes("not in ('secretaria','economia','comunicacion')")&&sql.includes("Solo el Gestor de la app puede invitar a Coordinación"),'Coordinación nunca recibe dirección ni puede autoelevarse');
assert(sql.includes('app_mutate_v160_v164')&&sql.includes('app_diagnostico_final_v165'),'RC8 encapsulado y gateway RC9 activo');
assert(pkg.includes('test-rc9.mjs')&&Number(gradle.match(/versionCode\s+(\d+)/)?.[1])>=20021&&gradle.includes("versionName '2.0.0-rc.13'"),'regresión RC9 incluida; Android conserva actualización desde 20021');
console.log('RC9 GESTOR + COORDINACIÓN: PASS');
