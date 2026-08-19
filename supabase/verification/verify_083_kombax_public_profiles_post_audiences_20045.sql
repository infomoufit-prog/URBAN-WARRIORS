-- VERIFY 083 · perfiles Social públicos + audiencia por publicación.
select
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_social_publicaciones' and column_name='audiencia') as audience_column,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_social_publicaciones' and column_name='audiencia_club_id') as audience_club_column,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_social_publicaciones' and column_name='audiencia_federacion_social_id') as audience_federation_column,
  to_regprocedure('public.app_kombax_social_audiencias_v083(uuid)') is not null as audiences_rpc,
  to_regprocedure('public.app_kombax_social_feed_v083(timestamptz,uuid,integer)') is not null as feed_rpc,
  to_regprocedure('public.app_kombax_perfil_publico_v083(uuid)') is not null as public_profile_rpc,
  to_regprocedure('public.app_kombax_social_comentarios_v083(uuid,integer)') is not null as comments_rpc,
  to_regprocedure('public.app_kombax_social_guardados_v083(integer)') is not null as saved_rpc,
  to_regprocedure('public.app_kombax_social_mutate_v083(text,jsonb,uuid)') is not null as mutate_rpc,
  has_function_privilege('authenticated','public.app_kombax_social_feed_v083(timestamptz,uuid,integer)','EXECUTE') as auth_feed_083,
  has_function_privilege('authenticated','public.app_kombax_perfil_publico_v083(uuid)','EXECUTE') as auth_profile_083,
  has_function_privilege('authenticated','public.app_kombax_social_mutate_v083(text,jsonb,uuid)','EXECUTE') as auth_mutate_083,
  not has_function_privilege('anon','public.app_kombax_social_mutate_v083(text,jsonb,uuid)','EXECUTE') as anon_mutate_closed,
  not has_function_privilege('authenticated','public.app_kombax_social_mutate_v067(text,jsonb,uuid)','EXECUTE') as old_mutate_closed,
  not has_function_privilege('authenticated','public.app_kombax_social_feed_v072(timestamptz,uuid,integer)','EXECUTE') as old_feed_closed,
  not has_function_privilege('authenticated','public.app_kombax_perfil_publico_v072(uuid)','EXECUTE') as old_profile_closed,
  not has_table_privilege('anon','public.kombax_relaciones','SELECT') as relations_anon_private,
  not has_table_privilege('authenticated','public.kombax_relaciones','SELECT') as relations_auth_private,
  position($needle$return v-'relations'$needle$ in pg_get_functiondef('public.app_kombax_perfil_publico_v083(uuid)'::regprocedure))>0 as relations_stripped;

select audiencia,count(*) from public.kombax_social_publicaciones group by audiencia order by audiencia;
