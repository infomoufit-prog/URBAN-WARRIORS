with required(name) as (values ('publicaciones_comunidad'),('comunicaciones'),('eventos_competicion'),('notificaciones'),('material_catalogo'),('documentos_socios'),('seguimiento'),('asistencias'),('sesiones_entrenamiento'))
select r.name,to_regclass('public.'||r.name) is not null ok from required r order by r.name;
select 'accionabilidad notificaciones' control,to_regprocedure('public.app_notificacion_requiere_accion_v034(uuid)') is not null ok;
select 'miembros coordinacion' control,exists(select 1 from information_schema.columns where table_schema='public' and table_name='miembros_club' and column_name='coordinacion') ok;
