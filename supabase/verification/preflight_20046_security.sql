select jsonb_build_object(
  'social_posts',to_regclass('public.kombax_social_publicaciones') is not null,
  'social_media',to_regclass('public.kombax_social_media') is not null,
  'storage_objects',to_regclass('storage.objects') is not null,
  'visibility_083',to_regprocedure('public.app_kombax_social_puede_ver_publicacion_v083(uuid)') is not null,
  'feed_083',to_regprocedure('public.app_kombax_social_feed_v083(timestamptz,uuid,integer)') is not null,
  'mutate_083',to_regprocedure('public.app_kombax_social_mutate_v083(text,jsonb,uuid)') is not null,
  'profiles_072',to_regprocedure('public.app_kombax_mis_perfiles_v072()') is not null,
  'applications_072',to_regprocedure('public.app_kombax_mis_solicitudes_v072()') is not null,
  'raw_code_060',to_regprocedure('public.app_kombax_codigo_validar_v060(text,text,text)') is not null,
  'team_request_060',to_regprocedure('public.app_kombax_equipo_solicitar_v060(text,text)') is not null,
  'base_mutate_060',to_regprocedure('public.app_mutate_v160_pre_access_codes_060(text,jsonb,uuid)') is not null,
  'pgcrypto_digest',to_regprocedure('extensions.digest(bytea,text)') is not null,
  'platform_owner_helper',to_regprocedure('public.app_kombax_es_platform_admin_v055()') is not null,
  'contact_067',to_regprocedure('public.app_kombax_contactos_v067()') is not null,
  'diagnostic_166',to_regprocedure('public.app_diagnostico_final_v166()') is not null,
  'work_scope_policy',exists(select 1 from pg_policies where schemaname='public' and tablename='club_ambitos_trabajo' and policyname='ambitos_lectura_v057'),
  'access_log_policy',exists(select 1 from pg_policies where schemaname='public' and tablename='registros_acceso_clase' and policyname='accesos_registro_usuario')
) as preflight_20046;
