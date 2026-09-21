-- RC13 build 20018 · verificación 035 (solo lectura)
select
  to_regclass('public.perfiles_club_publicos') is not null as tabla,
  to_regprocedure('public.app_perfil_club_publico_v035(uuid)') is not null as rpc_perfil,
  to_regprocedure('public.app_buscar_identidades_publicas_v035(uuid,text,integer)') is not null as rpc_busqueda,
  to_regprocedure('public.app_puede_gestionar_perfil_club_v035(uuid)') is not null as permiso,
  to_regprocedure('public.app_seed_perfil_club_publico_v035()') is not null as seed_nuevo_club,
  to_regprocedure('public.app_mutate_v160_pre_club_profile_035(text,jsonb,uuid)') is not null as gateway_previo,
  to_regprocedure('public.app_runtime_contract_v160_pre_club_profile_035(uuid)') is not null as contrato_previo,
  not has_table_privilege('authenticated','public.perfiles_club_publicos','SELECT') as sin_select_directo,
  pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure) like '%club_publico.guardar%' as operacion_gateway,
  pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure) like '%Los enlaces públicos deben utilizar HTTPS%' as urls_publicas_https;

select count(*) as clubes_activos_sin_perfil_publico
from public.clubes c left join public.perfiles_club_publicos p on p.club_id=c.id
where c.activo and p.club_id is null;
