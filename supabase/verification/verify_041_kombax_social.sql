-- Solo lectura. Todos los controles deben devolver PASS después de 041.
select 'social_tables' control,case when (
  select count(*) from unnest(array['kombax_social_perfiles','kombax_social_publicaciones','kombax_social_likes','kombax_social_bloqueos','kombax_social_contactos','kombax_social_reportes','kombax_social_moderacion']) n
  where to_regclass('public.'||n) is not null
)=7 then 'PASS' else 'FAIL' end resultado;
select 'rpc_surface' control,case when to_regprocedure('public.app_kombax_social_feed_v041(timestamp with time zone,uuid,integer)') is not null and to_regprocedure('public.app_kombax_social_directorio_v041(text,integer)') is not null and to_regprocedure('public.app_kombax_social_mutate_v041(text,jsonb,uuid)') is not null then 'PASS' else 'FAIL' end resultado;
select 'no_direct_select' control,case when not has_table_privilege('authenticated','public.kombax_social_perfiles','SELECT') and not has_table_privilege('authenticated','public.kombax_social_contactos','SELECT') and not has_table_privilege('authenticated','public.kombax_social_reportes','SELECT') then 'PASS' else 'FAIL' end resultado;
select 'rls' control,case when not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname like 'kombax_social_%' and c.relkind='r' and not c.relrowsecurity) then 'PASS' else 'FAIL' end resultado;
select 'club_profiles' control,case when not exists(select 1 from public.clubes c left join public.kombax_social_perfiles sp on sp.club_id=c.id and sp.sujeto_tipo='club' where sp.id is null) then 'PASS' else 'FAIL' end resultado;
select 'minor_contact_guard' control,case when pg_get_functiondef('public.app_kombax_social_contactable_v041(uuid)'::regprocedure) ilike '%>=18%' then 'PASS' else 'FAIL' end resultado;
select 'no_chat_followers' control,case when to_regclass('public.kombax_social_mensajes') is null and to_regclass('public.kombax_social_conversaciones') is null and to_regclass('public.kombax_social_seguidores') is null then 'PASS' else 'FAIL' end resultado;
select 'rules_1_1' control,case when exists(select 1 from public.textos_legales where tipo='comunidad_general' and version='1.1.0' and vigente) then 'PASS' else 'FAIL' end resultado;
select 'runtime_contract_041' control,case when to_regprocedure('public.app_runtime_contract_v160_pre_kombax_social_041(uuid)') is not null and pg_get_functiondef('public.app_runtime_contract_v160(uuid)'::regprocedure) like '%app_kombax_social_mutate_v041%' then 'PASS' else 'FAIL' end resultado;
