-- RC13 build 20018 · preflight 035 (solo lectura)
-- Resultado requerido: todos los controles = true.
select * from (values
  ('gateway_034',to_regprocedure('public.app_mutate_v160_pre_notifications_034(text,jsonb,uuid)') is not null),
  ('contrato_034',to_regprocedure('public.app_runtime_contract_v160_pre_notifications_034(uuid)') is not null),
  ('notificaciones_034',to_regprocedure('public.app_notificaciones_accionables_v034(uuid)') is not null),
  ('clubes',to_regclass('public.clubes') is not null),
  ('miembros_club',to_regclass('public.miembros_club') is not null),
  ('disciplinas',to_regclass('public.disciplinas') is not null),
  ('socio_disciplinas',to_regclass('public.socio_disciplinas') is not null),
  ('perfiles_deportivos',to_regclass('public.perfiles_deportivos') is not null),
  ('perfiles_sin_select_directo',not has_table_privilege('authenticated','public.perfiles_deportivos','SELECT')),
  ('columnas_marca_club',not exists(
    select 1 from (values('id'),('slug'),('nombre'),('lema'),('web'),('logo_url'),('portada_url'),('activo')) v(col)
    where not exists(select 1 from pg_attribute a where a.attrelid=to_regclass('public.clubes') and a.attname=v.col and a.attnum>0 and not a.attisdropped)
  )),
  ('columnas_perfil_deportivo',not exists(
    select 1 from (values('club_id'),('socio_id'),('apodo'),('foto_path'),('visible'),('moderacion_oculta')) v(col)
    where not exists(select 1 from pg_attribute a where a.attrelid=to_regclass('public.perfiles_deportivos') and a.attname=v.col and a.attnum>0 and not a.attisdropped)
  ))
) x(control,ok) order by control;
