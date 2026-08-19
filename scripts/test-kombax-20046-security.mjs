import fs from 'node:fs';
const read=p=>fs.readFileSync(new URL(`../${p}`,import.meta.url),'utf8');
const mig=read('supabase/migrations/084_kombax_social_legacy_rpc_shutdown_20046.sql');
const repo=read('web/js/core/repositories.js');
const backendCore=read('web/js/core/backend.js');
const fail=m=>{console.error('FAIL 20046 SECURITY:',m);process.exit(1)};
const ok=(c,m)=>{if(!c)fail(m)};
for(const v of ['v041','v044','v053','v065','v072']) ok(mig.includes(`app_kombax_social_feed_${v}`),`cierra feed ${v}`);
for(const v of ['v041','v044','v049','v050','v053','v065','v067']) ok(mig.includes(`app_kombax_social_mutate_${v}`),`cierra mutate ${v}`);
ok(repo.includes("app_kombax_social_feed_v085"),'runtime usa feed 085');
ok(repo.includes("app_kombax_social_mutate_v085")||repo.includes("app_kombax_social_mutate_v099"),'runtime usa mutate 085 o fachada endurecida posterior');
ok(repo.includes("app_kombax_social_comentarios_v083"),'runtime usa comentarios 083');
ok(repo.includes("app_kombax_perfil_publico_v083")||repo.includes("app_kombax_perfil_publico_v094"),'runtime usa perfil 083 o wrapper posterior seguro');
console.log('KOMBAX BUILD 20046 SECURITY · legacy Social RPC shutdown: PASS');
const mig85=read('supabase/migrations/085_kombax_restricted_social_media_20046.sql');
const social=read('web/js/modules/kombax-social.js');
ok(mig85.includes("'kombax-restricted-media'")&&mig85.includes('public=false'),'bucket restringido es privado');
ok(mig85.includes('app_kombax_social_restricted_media_visible_v085'),'lectura Storage se vincula a audiencia de la publicación');
ok(mig85.includes('app_kombax_social_mutate_v083_pre_media_v085')&&mig85.includes('select public.app_kombax_social_mutate_v085'),'20.045 mutate queda como wrapper endurecido, no bypass');
ok(mig85.includes("case when f.media_bucket='kombax-public-media' then f.media_path else null end"),'20.045 feed no expone path privado');
ok(mig85.includes('KOMBAX_RESTRICTED_POST_REQUIRES_PRIVATE_MEDIA'),'backend impide media pública en post restringido');
ok(mig85.includes('KOMBAX_PUBLIC_POST_REQUIRES_PUBLIC_MEDIA'),'backend impide media privada accidental en post público');
ok(repo.includes("app_kombax_social_feed_v085")&&(repo.includes("app_kombax_social_mutate_v085")||repo.includes("app_kombax_social_mutate_v099"))&&repo.includes("app_kombax_social_media_v085"),'runtime conserva feed/media 085 y mutación 085 o fachada endurecida posterior');
ok(repo.includes("mediaAccessUrl")&&repo.includes("kombax-restricted-media"),'runtime usa URL firmada para media restringida');
ok(social.includes("Las publicaciones restringidas no pueden reutilizar ni guardar multimedia en el álbum público"),'UI impide mezclar álbum público con post restringido');
ok(social.includes("mediaAccessUrl(p.media_path,p.media_bucket"),'feed resuelve media según bucket');
console.log('KOMBAX BUILD 20046 SECURITY · restricted Social media: PASS');
const mig86=read('supabase/migrations/086_kombax_access_code_rate_limit_20046.sql');
const app=read('web/js/app.js');
ok(mig86.includes('kombax_codigo_intentos_v086')&&mig86.includes("next_fail>=5")&&mig86.includes("interval '15 minutes'")&&mig86.includes("'rate_limited',true"),'códigos tienen rate limit persistente 5/15m');
ok(!mig86.includes("if next_fail>=5 then raise exception 'KOMBAX_ACCESS_CODE_RATE_LIMIT'"),'quinto fallo no revierte el bloqueo por excepción');
ok(mig86.includes("'ok',false")&&mig86.includes("'error_code'")&&!mig86.includes("then raise exception 'Código de equipo no válido'"),'wrappers no revierten el contador al rechazar código');
ok(backendCore.includes("response?.ok===false&&response?.error_code")&&backendCore.includes("if(result?.ok===false)throw new Error"),'cliente convierte rechazo estructurado en error UX después del commit');
ok(mig86.includes('app_kombax_codigo_validar_raw_v086')&&mig86.includes('revoke all on function public.app_kombax_codigo_validar_raw_v086'),'comparación bruta queda interna');
ok(mig86.includes('kombax_codigo_intentos_anon_v086')&&mig86.includes('x-forwarded-for')&&mig86.includes('next_fail>=10'),'compatibilidad 20.045 queda rate-limited por IP');
ok(mig86.includes('app_kombax_codigo_validar_seguro_v086')&&mig86.includes('app_kombax_equipo_solicitar_v060'),'equipo usa validador seguro');
ok(mig86.includes("p_operation='cuenta.registrar'")&&mig86.includes("app_kombax_codigo_validar_seguro_v086(slug,'alumnos',code)"),'alta alumno usa validador seguro');
ok(!repo.includes("validate:(clubSlug,tipo,codigo)=>backend.publicRpc('app_kombax_codigo_validar_v060'"),'frontend elimina oracle público de código');
ok(!app.includes("repos.accessCodes.validate(slug,'alumnos'")&&!app.includes("repos.accessCodes.validate(slug,'equipo'"),'UI no valida códigos antes de auth');
console.log('KOMBAX BUILD 20046 SECURITY · access-code anti brute-force: PASS');
const mig87=read('supabase/migrations/087_kombax_api_surface_hardening_20046.sql');
ok(backendCore.includes("app_kombax_mis_perfiles_v072")&&!backendCore.includes("app_kombax_mis_perfiles_v043"),'login global usa perfiles v072');
ok(backendCore.includes("app_kombax_mis_solicitudes_v072")&&!backendCore.includes("app_kombax_mis_solicitudes_v043"),'login global usa solicitudes v072');
ok(app.includes("app_kombax_registro_catalogo_publico_v087")&&!app.includes("client.select('clubes',`select=id,nombre&slug=eq."),'registro público usa contrato RPC mínimo');
ok(mig87.includes('revoke execute on function public.actualizar_grado_actual() from public, anon, authenticated'),'trigger no queda RPC cliente');
ok(mig87.includes("c.relname not in ('clubes','disciplinas','grupos','tarifas','textos_legales')"),'anon directo se limita a compatibilidad de registro');
ok(mig87.includes('ae.club_id=club_ambitos_trabajo.club_id')&&!mig87.includes('ae.club_id=ae.club_id'),'RLS multiclub elimina tautología');
ok(mig87.includes('s.club_id=registros_acceso_clase.club_id')&&!mig87.includes('s.club_id=s.club_id'),'RLS check-in enlaza sesión al club y elimina tautología');
ok(mig87.includes('create policy accesos_registro_usuario on public.registros_acceso_clase')&&mig87.includes('for insert to authenticated'),'check-in propio exige sesión autenticada');
ok(mig87.includes('app_kombax_registro_catalogo_publico_v087'),'catálogo de registro expone contrato mínimo');
console.log('KOMBAX BUILD 20046 SECURITY · API surface + multiclub RLS: PASS');

const mig88=read('supabase/migrations/088_kombax_superseded_rpc_shutdown_20046.sql');
ok(mig85.includes("p_operation='kombax.social.eliminar'")&&mig85.includes("'{data,storage_bucket}'"),'borrado de post conserva bucket para limpiar media privada');
ok(repo.includes("backend.remove(out.storage_bucket||'kombax-public-media',out.storage_path)"),'cliente elimina post del bucket correcto');
ok(mig88.includes('app_kombax_contactos_v065')&&mig88.includes('app_kombax_contactos_v067'),'Contacto cierra 065 y conserva 067');
ok(mig88.includes('app_kombax_identity_mutate_v051')&&mig88.includes('app_kombax_identity_mutate_v065'),'identidad cierra 051 y conserva 065');
ok(mig88.includes('app_kombax_platform_dashboard_v055')&&mig88.includes('app_kombax_platform_dashboard_v072'),'administración cierra dashboard supersedido');
ok(mig88.includes('app_kombax_showcase_list_v042')&&mig88.includes('app_kombax_showcase_list_v054'),'Showcase cierra listado antiguo y conserva actual');
ok(mig88.includes('app_kombax_social_directorio_v052')&&mig88.includes('app_kombax_social_directorio_v072'),'directorio cierra proyección antigua');
console.log('KOMBAX BUILD 20046 SECURITY · superseded RPC shutdown: PASS');

const mig89=read('supabase/migrations/089_kombax_internal_rpc_default_privileges_20046.sql');
ok(mig89.includes('alter default privileges for role postgres in schema public')&&mig89.includes('revoke execute on functions from public,anon,authenticated,service_role'),'futuros objetos API son opt-in');
ok(mig89.includes("p.prorettype='pg_catalog.trigger'::regtype")&&mig89.includes('revoke execute on function %I.%I() from public,anon,authenticated'),'todos los triggers quedan fuera del Data API');
for(const helper of ['app_kombax_es_platform_admin_v055','app_kombax_social_acceso_v041','app_kombax_social_contactable_v041','app_kombax_social_puede_publicar_v041','app_kombax_social_tipo_v051','app_kombax_contact_reason_allowed_v044']) ok(mig89.includes(helper),`helper interno cerrado: ${helper}`);
for(const oldDiag of ['app_diagnostico_persistencia_v161','app_diagnostico_final_v162','app_diagnostico_final_v163','app_diagnostico_final_v164','app_diagnostico_final_v165']) ok(mig88.includes(oldDiag),`diagnóstico supersedido cerrado: ${oldDiag}`);
ok(mig88.includes('app_diagnostico_final_v166'),'diagnóstico actual v166 permanece');
console.log('KOMBAX BUILD 20046 SECURITY · internal helpers + deny-by-default: PASS');

const mig90=read('supabase/migrations/090_kombax_default_privileges_complete_20046.sql');
const mig90n=mig90.toLowerCase().replace(/\s+/g,' ').replace(/\s*,\s*/g,',');
ok(mig90n.includes('revoke all privileges on tables from anon,authenticated,service_role'),'defaults futuros de tablas quedan completamente cerrados');
ok(mig90n.includes('revoke all privileges on sequences from anon,authenticated,service_role'),'defaults futuros de secuencias quedan completamente cerrados');
ok(mig90n.includes('revoke all privileges on functions from public,anon,authenticated,service_role'),'defaults futuros de funciones quedan completamente cerrados');
console.log('KOMBAX BUILD 20046 SECURITY · complete default privileges: PASS');

const mig91=read('supabase/migrations/091_kombax_media_preserved_impl_shutdown_20046.sql');
for(const preserved of [
  'app_kombax_social_media_v053_pre_media_v085',
  'app_kombax_social_feed_v083_pre_media_v085',
  'app_kombax_social_mutate_v083_pre_media_v085'
]){
  ok(mig91.includes(`revoke all on function public.${preserved}`),`implementación preservada queda cerrada: ${preserved}`);
  ok(mig91.includes(`grant execute on function public.${preserved}`)&&mig91.includes('to service_role'),`implementación preservada mantiene service_role: ${preserved}`);
}
console.log('KOMBAX BUILD 20046 SECURITY · preserved media implementations internal-only: PASS');

const mig92=read('supabase/migrations/092_kombax_internal_helper_shutdown_20046.sql');
for(const helper of [
  'app_kombax_social_avatar_path_v058',
  'app_kombax_social_banner_path_v058',
  'app_kombax_codigo_validar_seguro_v086',
  'app_kombax_relacion_tipo_valido_v045',
  'app_multiclub_audit_v030',
  'app_perfil_club_publico_v035'
]) ok(mig92.includes(`revoke execute on function public.${helper}`),`helper adicional fuera del Data API: ${helper}`);
ok(mig92.includes('revoke execute on function public.app_generar_sesiones_recurrentes(uuid,integer) from public,anon,authenticated'),'generador recurrente no es RPC cliente');
ok(mig92.includes('grant execute on function public.app_generar_sesiones_recurrentes(uuid,integer) to service_role'),'generador recurrente conserva ejecución de Edge Function');
ok(mig92.includes('grant execute on function public.app_guardar_asistencia')&&mig92.includes('to service_role'),'gateways heredados pueden seguir delegando en asistencia internamente');
console.log('KOMBAX BUILD 20046 SECURITY · additional internal helpers: PASS');
const cfg46=read('web/config.js');
const idx46=read('web/index.html');
const sw46=read('web/service-worker.js');
const gradle46=read('android/app/build.gradle');
const cfgBuild46=Number(cfg46.match(/build:\s*(\d+)/)?.[1]||0);
const gradleBuild46=Number(gradle46.match(/versionCode\s+(\d+)/)?.[1]||0);
const idxBuilds46=[...idx46.matchAll(/\?v=(\d+)/g)].map(x=>Number(x[1]));
const swBuild46=Number(sw46.match(/uw2-2\.0\.0-rc13-(\d+)/)?.[1]||0);
ok(cfgBuild46>=20046,'config conserva build 20046 o posterior');
ok(gradleBuild46>=20046,'Android conserva versionCode 20046 o posterior');
ok(idxBuilds46.length>0&&idxBuilds46.every(x=>x>=20046),'assets web invalidan cache con 20046 o posterior');
ok(swBuild46>=20046,'service worker usa cache 20046 o posterior');
console.log('KOMBAX BUILD 20046 SECURITY · release metadata: PASS');

