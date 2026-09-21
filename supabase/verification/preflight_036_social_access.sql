-- RC13 build 20018 · preflight 036 (solo lectura)
-- Resultado requerido: todos los controles = true.
select * from (values
  ('gateway_035',to_regprocedure('public.app_mutate_v160_pre_club_profile_035(text,jsonb,uuid)') is not null),
  ('contrato_035',to_regprocedure('public.app_runtime_contract_v160_pre_club_profile_035(uuid)') is not null),
  ('perfil_club_035',to_regprocedure('public.app_perfil_club_publico_v035(uuid)') is not null),
  ('comunidad_interna',to_regclass('public.publicaciones_comunidad') is not null),
  ('socios',to_regclass('public.socios') is not null),
  ('miembros_club',to_regclass('public.miembros_club') is not null),
  ('perfiles',to_regclass('public.perfiles') is not null),
  ('perfiles_deportivos',to_regclass('public.perfiles_deportivos') is not null),
  ('textos_legales',to_regclass('public.textos_legales') is not null),
  ('aceptaciones_legales',to_regclass('public.aceptaciones_legales') is not null),
  ('config_club',to_regclass('public.config_club') is not null),
  ('idempotencia',to_regclass('public.app_mutation_requests') is not null),
  ('columnas_socio_edad',not exists(
    select 1 from (values('id'),('club_id'),('perfil_id'),('estado'),('fecha_nacimiento'),('nombre'),('apellidos')) v(col)
    where not exists(select 1 from pg_attribute a where a.attrelid=to_regclass('public.socios') and a.attname=v.col and a.attnum>0 and not a.attisdropped)
  )),
  ('columnas_comunidad_moderacion',not exists(
    select 1 from (values('id'),('club_id'),('autor_perfil_id'),('autor_nombre'),('texto'),('estado'),('moderada_por'),('moderacion_motivo')) v(col)
    where not exists(select 1 from pg_attribute a where a.attrelid=to_regclass('public.publicaciones_comunidad') and a.attname=v.col and a.attnum>0 and not a.attisdropped)
  ))
) x(control,ok) order by control;
