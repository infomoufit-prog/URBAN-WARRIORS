-- Urban Warriors RC13 · preflight 033. SOLO LECTURA.
select * from (values
  ('gateway_032',to_regprocedure('public.app_mutate_v160_pre_social_032(text,jsonb,uuid)') is not null),
  ('rpc_perfiles_032',to_regprocedure('public.app_perfiles_deportivos_publicos_v032(uuid,uuid)') is not null),
  ('likes_032',to_regclass('public.comunidad_likes') is not null),
  ('socios',to_regclass('public.socios') is not null),
  ('disciplinas',to_regclass('public.disciplinas') is not null),
  ('miembros_club',to_regclass('public.miembros_club') is not null)
) x(control,ok) order by control;
