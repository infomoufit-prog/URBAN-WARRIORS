import fs from 'node:fs';
const read=p=>fs.readFileSync(new URL(`../${p}`,import.meta.url),'utf8');
const assert=(cond,msg)=>{if(!cond)throw new Error(`20033 access codes: ${msg}`)};
const [app,backend,repos,admin,members,mig,verify,config,gradle,sw,index]=[
  read('web/js/app.js'),read('web/js/core/backend.js'),read('web/js/core/repositories.js'),read('web/js/modules/admin.js'),read('web/js/modules/groups-members.js'),
  read('supabase/migrations/060_kombax_club_access_codes.sql'),read('supabase/verification/verify_060_club_access_codes.sql'),read('web/config.js'),read('android/app/build.gradle'),read('web/service-worker.js'),read('web/index.html')
];
assert(app.includes('Código para alumnos y familias')&&app.includes('Código para miembros del equipo'),'UI pública mantiene separados ambos tipos de código');
assert(!app.includes("repos.accessCodes.validate(slug,'alumnos',code)")&&!app.includes("repos.accessCodes.validate(slug,'equipo',code)"),'20.046 retira la validación anónima previa; el backend autenticado valida el código');
assert(app.includes('No concede permisos automáticamente')&&app.includes('El club debe revisarla'),'equipo no autoconcede permisos');
assert(backend.includes('uw2_pending_team_access')&&backend.includes('app_kombax_equipo_solicitar_v060'),'backend conserva solicitud de equipo tras confirmación de email');
assert(repos.includes('app_kombax_codigos_club_v060')&&repos.includes('app_kombax_codigo_rotar_v060')&&repos.includes('app_kombax_solicitud_equipo_resolver_v060'),'repositorio integra lectura, rotación y revisión');
assert(admin.includes("['direccion','coordinacion'].includes(state.session?.rol)")&&admin.includes('Cambiar código de equipo')&&admin.includes('Solicitudes de acceso al equipo'),'Gestor/Coordinación gestionan código de equipo y solicitudes');
assert(members.includes("['direccion','coordinacion'].includes(state.session?.rol)")&&members.includes('Código alumnos/familias')&&members.includes("rotate('alumnos'"),'Gestor/Coordinación gestionan código de alumnos/familias');
assert(mig.includes("codigo_alumnos ~ '^[0-9]{4,5}$'")&&mig.includes("codigo_equipo ~ '^[0-9]{4,5}$'")&&mig.includes('app_puede_gestionar_perfil_club_v035'),'SQL limita formato y permisos');
assert(mig.includes("estado text not null default 'pendiente'")&&mig.includes("Solo el Gestor puede conceder Coordinación")&&mig.includes("role not in ('coordinacion','secretaria','economia','comunicacion','monitor')"),'solicitud de equipo es pendiente y rol se asigna en revisión');
assert(mig.includes("payload:=jsonb_set(payload,'{invite_code}','null'::jsonb,true)")&&mig.includes("app_kombax_codigo_validar_v060(slug,'alumnos',code)"),'registro de alumnos valida código reutilizable sin consumirlo');
assert(mig.includes("revoke all on function public.app_kombax_invitacion_validar_v059")&&mig.includes("estado='revocada'"),'059 individual queda desactivado');
assert(verify.includes('060.10 v059 pending revoked'),'verificación cubre retirada de invitaciones individuales');
const runtimeBuild=Number(config.match(/build:\s*(\d+)/)?.[1]||0),androidBuild=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);
assert(runtimeBuild>=20033&&androidBuild>=20033&&sw.includes(String(runtimeBuild))&&index.includes(`v=${runtimeBuild}`),'trazabilidad 20033+ consistente');
console.log('KOMBAX 20033 CLUB ACCESS CODES: PASS');
