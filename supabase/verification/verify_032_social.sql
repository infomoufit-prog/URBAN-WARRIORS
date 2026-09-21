-- Urban Warriors RC13 · verificación 032. SOLO LECTURA.
-- Resultado requerido: todos los controles booleanos = true y 0 incidencias.
select * from (values
  ('perfiles_deportivos',to_regclass('public.perfiles_deportivos') is not null),
  ('comunidad_likes',to_regclass('public.comunidad_likes') is not null),
  ('gateway_032',to_regprocedure('public.app_mutate_v160_pre_social_032(text,jsonb,uuid)') is not null),
  ('contrato_032',to_regprocedure('public.app_runtime_contract_v160_pre_social_032(uuid)') is not null),
  ('lectura_publica_segura',to_regprocedure('public.app_perfiles_deportivos_publicos_v032(uuid,uuid)') is not null),
  ('editor_perfil',to_regprocedure('public.app_puede_editar_perfil_deportivo_v032(uuid)') is not null),
  ('visibilidad_perfil',to_regprocedure('public.app_puede_ver_perfil_deportivo_v032(uuid,uuid)') is not null),
  ('moderacion_perfil',to_regprocedure('public.app_puede_moderar_perfil_deportivo_v032(uuid)') is not null),
  ('moderacion_separada_privacidad',exists(select 1 from information_schema.columns where table_schema='public' and table_name='perfiles_deportivos' and column_name='moderacion_oculta' and data_type='boolean')),
  ('perfil_sin_select_directo',not has_table_privilege('authenticated','public.perfiles_deportivos','SELECT')),
  ('trigger_likes',exists(select 1 from pg_trigger where tgname='trg_comunidad_likes_count_v032' and not tgisinternal)),
  ('trigger_autor_socio',exists(select 1 from pg_trigger where tgname='trg_comunidad_autor_socio_v032' and not tgisinternal)),
  ('bucket_foto_privado',exists(select 1 from storage.buckets where id='sports-profile-media' and public=false))
) x(control,ok)
order by control;

select 'moderacion_sin_auditoria' control,count(*) incidencias
from public.perfiles_deportivos
where moderacion_oculta and (moderado_por is null or moderado_en is null);

select 'likes_descuadrados' control,count(*) incidencias
from public.publicaciones_comunidad p
where p.likes_count<>(select count(*) from public.comunidad_likes l where l.club_id=p.club_id and l.publicacion_id=p.id);

select 'likes_duplicados' control,count(*) incidencias
from (
  select club_id,publicacion_id,perfil_id,count(*) n
  from public.comunidad_likes
  group by club_id,publicacion_id,perfil_id
  having count(*)>1
) d;
