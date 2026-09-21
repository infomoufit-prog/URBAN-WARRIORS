-- RC13 build 20018 · verificación 036 (solo lectura)
select
  to_regclass('public.identidades_sociales') is not null as identidades,
  to_regclass('public.moderacion_accesos_sociales') is not null as auditoria_acceso_social,
  to_regclass('public.bloqueos_comunidad') is not null as bloqueos,
  to_regclass('public.reportes_comunidad') is not null as reportes,
  to_regprocedure('public.app_comunidad_general_estado_v036(uuid)') is not null as estado_social,
  to_regprocedure('public.app_seed_comunidad_general_new_club_v036()') is not null as seed_social_nuevo_club,
  to_regprocedure('public.app_edad_min_comunidad_general_v036(uuid)') is not null as lector_edad_social_defensivo,
  to_regprocedure('public.app_comunidad_bloqueados_v036(uuid)') is not null as rpc_bloqueos,
  to_regprocedure('public.app_comunidad_reportes_v036(uuid)') is not null as rpc_reportes,
  to_regprocedure('public.app_mutate_v160_pre_social_access_036(text,jsonb,uuid)') is not null as gateway_previo,
  to_regprocedure('public.app_runtime_contract_v160_pre_social_access_036(uuid)') is not null as contrato_previo,
  pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure) like '%v_age<16%' as alta_alumno_16,
  not exists(
    select 1 from public.clubes cl
    left join public.config_club c on c.club_id=cl.id and c.clave='edad_min_comunidad_general'
    where c.club_id is null
       or jsonb_typeof(c.valor)<>'number'
       or not case when (c.valor#>>'{}') ~ '^[0-9]{1,3}$'
                   then (c.valor#>>'{}')::integer between 14 and 99
                   else false end
  ) as configuracion_edad_social,
  pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure) like '%v_age<v_min_social_age%' as comunidad_edad_configurable,
  pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure) like '%s.estado=''activo''%' as socio_activo_verificado,
  pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure) like '%suspendido o cerrado%' as suspension_no_autoreactivable,
  pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure) like '%insert into public.aceptaciones_legales%' as aceptacion_social_auditable,
  pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure) like '%Debes leer y aceptar las Normas de Comunidad antes de publicar%' as ugc_normas_explicitas,
  pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure) like '%insert into public.moderacion_accesos_sociales%' as moderacion_acceso_auditable,
  pg_get_functiondef('public.app_runtime_contract_v160(uuid)'::regprocedure) like '%comunidad_general.moderar_acceso%' as contrato_moderacion_acceso,
  not has_table_privilege('authenticated','public.reportes_comunidad','SELECT') as reportes_sin_select_directo,
  not has_table_privilege('authenticated','public.moderacion_accesos_sociales','SELECT') as auditoria_sin_select_directo;

select count(*) as identidades_con_socio_origen_invalido
from public.identidades_sociales i left join public.socios s on s.id=i.socio_origen_id
where i.socio_origen_id is not null and s.id is null;

select count(*) as bloqueos_a_si_mismo from public.bloqueos_comunidad where bloqueador_perfil_id=bloqueado_perfil_id;

select count(*) as altas_sociales_sin_aceptacion_vigente
from public.identidades_sociales i
left join public.aceptaciones_legales a on a.club_id=i.club_origen_id and a.perfil_id=i.perfil_id and a.socio_id=i.socio_origen_id
  and a.tipo='comunidad_general' and a.version=i.version_normas and a.aceptado and a.revocado_en is null
where i.estado='activa' and a.id is null;

select count(*) as moderaciones_fuera_identidad
from public.moderacion_accesos_sociales m
left join public.identidades_sociales i on i.id=m.identidad_social_id and i.perfil_id=m.perfil_id
where i.id is null;

select count(*) as suspensiones_sin_motivo
from public.identidades_sociales where estado='suspendida' and nullif(trim(suspension_motivo),'') is null;
