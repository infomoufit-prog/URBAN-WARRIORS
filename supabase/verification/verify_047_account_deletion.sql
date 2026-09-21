select to_regclass('public.kombax_solicitudes_eliminacion') is not null as table_ok,
       to_regprocedure('public.app_kombax_solicitudes_eliminacion_v047()') is not null as read_rpc_ok,
       to_regprocedure('public.app_kombax_eliminacion_mutate_v047(text,jsonb,uuid)') is not null as mutate_rpc_ok;
select indexname from pg_indexes where schemaname='public' and tablename='kombax_solicitudes_eliminacion' and indexname='uq_kombax_delete_open_v047';
