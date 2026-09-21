-- RC13 build 20018 · verificación 034 (solo lectura)
select
  to_regclass('public.notificaciones_revisiones') is not null as revisiones,
  to_regprocedure('public.app_notificacion_requiere_accion_v034(uuid)') is not null as clasificador,
  to_regprocedure('public.app_notificaciones_accionables_v034(uuid)') is not null as rpc_accionables,
  to_regprocedure('public.app_mutate_v160_pre_notifications_034(text,jsonb,uuid)') is not null as gateway_previo,
  to_regprocedure('public.app_runtime_contract_v160_pre_notifications_034(uuid)') is not null as contrato_previo,
  pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure) like '%notificacion.revisar%' as revisar_en_gateway,
  pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure) like '%not public.app_notificacion_requiere_accion_v034%' as masivas_protegidas,
  has_function_privilege('authenticated','public.app_notificaciones_accionables_v034(uuid)','EXECUTE') as lectura_auth;

select count(*) as revisiones_fuera_club
from public.notificaciones_revisiones r
join public.notificaciones n on n.id=r.notificacion_id
where n.club_id<>r.club_id;
