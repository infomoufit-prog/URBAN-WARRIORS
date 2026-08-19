-- PRECHECK 083 · perfiles públicos + audiencias por publicación.
select
  to_regclass('public.kombax_social_publicaciones') is not null as posts_ok,
  to_regclass('public.kombax_social_perfiles') is not null as social_profiles_ok,
  to_regclass('public.kombax_relaciones') is not null as relations_ok,
  to_regprocedure('public.app_kombax_social_mutate_v067(text,jsonb,uuid)') is not null as mutate_067_ok,
  to_regprocedure('public.app_kombax_social_feed_v072(timestamptz,uuid,integer)') is not null as feed_072_ok,
  to_regprocedure('public.app_kombax_perfil_publico_v072(uuid)') is not null as public_profile_072_ok,
  to_regprocedure('public.app_kombax_social_afiliacion_v072(uuid)') is not null as affiliation_072_ok,
  not has_table_privilege('anon','public.kombax_relaciones','SELECT') as relations_anon_private,
  not has_table_privilege('authenticated','public.kombax_relaciones','SELECT') as relations_auth_private;
