select to_regclass('public.kombax_evento_participantes_publicos') is not null as participants_table_ok,
       to_regclass('public.kombax_evento_combates_publicos') is not null as fights_table_ok,
       to_regprocedure('public.app_kombax_evento_participantes_v161(uuid)') is not null as participants_rpc_ok,
       to_regprocedure('public.app_kombax_evento_combates_v161(uuid)') is not null as fights_rpc_ok,
       to_regprocedure('public.app_kombax_eventos_mutate_v161(text,jsonb,uuid)') is not null as mutate_rpc_ok;
select count(*)=0 as no_internal_event_fk
from information_schema.constraint_column_usage
where table_schema='public' and table_name in ('eventos_competicion','evento_participantes','evento_combates')
  and constraint_name like 'kombax_evento_%';
