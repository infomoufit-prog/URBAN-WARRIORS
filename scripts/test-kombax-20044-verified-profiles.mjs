import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const root=resolve(fileURLToPath(new URL('..',import.meta.url)));
const read=p=>readFileSync(resolve(root,p),'utf8');
const must=(ok,msg)=>{if(!ok)throw new Error(`20044: ${msg}`)};
for(const n of [69,70,71,72]){
  const prefix=String(n).padStart(3,'0');
  const files=Object.keys({
    69:'069_kombax_verified_identity_policy_20044.sql',70:'070_kombax_profile_governance_managers_20044.sql',71:'071_kombax_plans_entitlements_20044.sql',72:'072_kombax_verified_profiles_workflow_20044.sql'
  });
  void files;
}
const migrations={
  69:'supabase/migrations/069_kombax_verified_identity_policy_20044.sql',
  70:'supabase/migrations/070_kombax_profile_governance_managers_20044.sql',
  71:'supabase/migrations/071_kombax_plans_entitlements_20044.sql',
  72:'supabase/migrations/072_kombax_verified_profiles_validation_20044.sql',
  73:'supabase/migrations/073_kombax_competitor_identity_continuity_20044.sql',
  74:'supabase/migrations/074_kombax_verified_profiles_social_guards_20044.sql',
  75:'supabase/migrations/075_kombax_verified_profiles_public_apis_20044.sql',
  76:'supabase/migrations/076_kombax_verified_profiles_owner_apis_20044.sql',
  77:'supabase/migrations/077_kombax_verified_profiles_mutations_20044.sql',
  78:'supabase/migrations/078_kombax_verified_profiles_media_20044.sql',
  79:'supabase/migrations/079_kombax_verified_profiles_admin_hardening_20044.sql',
  80:'supabase/migrations/080_kombax_subscription_window_hardening_20044.sql',
  81:'supabase/migrations/081_kombax_verified_profile_internal_rpc_hardening_20044.sql',
};
for(const [n,p] of Object.entries(migrations)){must(existsSync(resolve(root,p)),`falta migración ${n}`);must(existsSync(resolve(root,`supabase/verification/verify_${String(n).padStart(3,'0')}_${p.split('/').pop().slice(4)}`)),`falta verificación ${n}`);}
const m69=read(migrations[69]),m70=read(migrations[70]),m71=read(migrations[71]);
const m72=[72,73,74,75,76,77,78,79,80,81].map(n=>read(migrations[n])).join('\n');
const repos=read('web/js/core/repositories.js'),gateway=read('web/js/modules/gateway.js'),social=read('web/js/modules/kombax-social.js'),publicProfile=read('web/js/modules/public-profile.js'),admin=read('web/js/modules/platform-admin.js'),config=read('web/config.js'),index=read('web/index.html'),sw=read('web/service-worker.js'),gradle=read('android/app/build.gradle');
const build=Number(config.match(/build:\s*(\d+)/)?.[1]||0),versionCode=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);
must(build>=20044,'web build debe conservar o superar 20044');must(versionCode>=20044,'Android versionCode debe conservar o superar 20044');must(index.includes(`v=${build}`),'cache busting debe coincidir con build actual');must(sw.includes(String(build)),'service worker debe coincidir con build actual');
// Badge policy
must(m69.includes("where sujeto_tipo='miembro' and verificado"),'069 debe hacer backfill de insignia Miembro');
must(m69.includes("d.tipo in ('competidor','marca','federacion')"),'069 debe limitar insignias directas');
must(m69.includes('app_kombax_social_badge_guard_v069'),'069 debe tener guard de insignia');
// Governance
must(m70.includes('create table if not exists public.kombax_perfil_gestores'),'070 debe crear multigestor');
must(m70.includes('drop constraint if exists perfiles_kombax_directos_perfil_id_tipo_key'),'070 debe liberar Marca/Federación múltiples');
must(m70.includes("where tipo='competidor'"),'070 debe conservar unicidad Competidor');
must(m70.includes('app_kombax_puede_gestionar_perfil_v070'),'070 debe centralizar permisos');
// Plans separated from verification
must(m71.includes('create table if not exists public.kombax_planes'),'071 debe modelar planes');
must(m71.includes('app_kombax_reconcile_entitlements_v071'),'071 debe reconciliar entitlements');
must(m71.includes('app_kombax_subscription_mutate_v071'),'071 debe separar activación de servicio');
must(m71.includes("origen='suscripcion'"),'071 debe marcar entitlements de suscripción');
must(read(migrations[80]).includes("interval '1 microsecond'"),'080 debe endurecer ventanas temporales de suscripción/entitlements');
must(read(migrations[81]).includes('revoke execute on function public.app_kombax_badge_tipo_v069'),'081 debe cerrar helpers internos de badge');
must(read(migrations[81]).includes('app_kombax_perfil_servicio_activo_v071'),'081 debe cerrar helpers internos de servicio');
// Workflow final
must(m72.includes('app_kombax_application_validate_v072'),'072 debe validar formularios');
must(m72.includes('KOMBAX_COMPETITOR_MIN_AGE_16'),'Competidor autónomo debe ser 16+');
must(m72.includes('app_kombax_social_switch_competitor_v072'),'072 debe preservar identidad Social en upgrade');
must(m72.includes("sujeto_tipo='perfil_directo',identidad_social_id=null,perfil_directo_id=v_d.id"),'upgrade debe convertir la misma fila Social');
must(m72.includes("sujeto_tipo='miembro',perfil_directo_id=null,identidad_social_id=v_i.id"),'downgrade debe preservar la misma fila Social');
must(m72.includes("v_type not in ('competidor','marca','federacion')"),'profesional no puede abrir perfil oficial');
must(m72.includes("if not public.app_kombax_es_platform_admin_v055()"),'verificación debe exigir admin de plataforma');
must(!m72.match(/if v_state='verified'[\s\S]{0,1200}insert into public\.kombax_entitlements/),'verificar no puede autoconceder entitlements');
must(m72.includes('revoke execute on function public.app_kombax_perfil_mutate_v043'),'mutator antiguo debe quedar cerrado');
must(m72.includes("return v-'relations'"),'perfil público 072 debe seguir sin Relaciones');
// Frontend contracts
for(const fn of ['app_kombax_mis_perfiles_v072','app_kombax_mis_solicitudes_v072','app_kombax_perfil_mutate_v072','app_kombax_media_mutate_v072','app_kombax_social_feed_v072','app_kombax_social_directorio_v072','app_kombax_perfil_publico_v072','app_kombax_platform_dashboard_v072','app_kombax_platform_application_v072'])must(repos.includes(fn),`frontend no usa ${fn}`);
must(gateway.includes('Solicitar perfil'),'gateway debe hablar de solicitud, no alta automática');
must(gateway.includes('Continuidad con mi perfil de Miembro'),'Competidor debe ofrecer upgrade conservando Social');
must(gateway.includes("disabled:true")&&gateway.includes("id:'profesional'"),'Profesional debe quedar reservado');
must(social.includes('Afiliación confirmada'),'Social debe diferenciar afiliación de insignia');
must(publicProfile.includes('Afiliación confirmada'),'Perfil público debe diferenciar afiliación de insignia');
must(admin.includes('La verificación no activa la suscripción'),'Admin debe separar verificación y servicio');
must(admin.includes('setProfileService'),'Admin debe poder activar servicio por separado');

must(m72.includes('concedido_por')&&!m72.includes('asignado_por'),'072 usa la columna real concedido_por para gestores');
must(m72.includes('KOMBAX_OWNER_ROLE_IMMUTABLE'),'propietario canónico no puede degradarse mediante gestión compartida');
console.log('KOMBAX BUILD 20044 VERIFIED PROFILES: PASS');
