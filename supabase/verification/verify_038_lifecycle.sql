with required(name) as (values ('publicaciones_comunidad'),('comunicaciones'),('eventos_competicion'),('notificaciones'),('material_catalogo'),('documentos_socios'),('seguimiento'),('asistencias'),('sesiones_entrenamiento')),
checks as(select r.name,count(c.column_name) found from required r left join information_schema.columns c on c.table_schema='public' and c.table_name=r.name and c.column_name in ('ciclo_estado','archivado_en','archivado_por','papelera_en','papelera_por','restaurar_hasta') group by r.name)
select name,found=6 ok,found from checks order by name;
select 'auditoria' control,to_regclass('public.contenido_ciclo_auditoria') is not null ok;
select 'accion' control,to_regprocedure('public.app_ciclo_accion_v038(uuid,text,uuid[],text,text)') is not null ok;
select 'listado' control,to_regprocedure('public.app_ciclo_listar_v038(uuid,text,text,date,date,integer)') is not null ok;
select 'estados inválidos' control,coalesce(sum(n),0)=0 ok,coalesce(sum(n),0)::bigint detalle from (
  select count(*) n from public.publicaciones_comunidad where ciclo_estado not in ('activo','archivado','papelera') union all
  select count(*) from public.comunicaciones where ciclo_estado not in ('activo','archivado','papelera') union all
  select count(*) from public.eventos_competicion where ciclo_estado not in ('activo','archivado','papelera') union all
  select count(*) from public.notificaciones where ciclo_estado not in ('activo','archivado','papelera') union all
  select count(*) from public.material_catalogo where ciclo_estado not in ('activo','archivado','papelera') union all
  select count(*) from public.documentos_socios where ciclo_estado not in ('activo','archivado','papelera') union all
  select count(*) from public.seguimiento where ciclo_estado not in ('activo','archivado','papelera') union all
  select count(*) from public.asistencias where ciclo_estado not in ('activo','archivado','papelera') union all
  select count(*) from public.sesiones_entrenamiento where ciclo_estado not in ('activo','archivado','papelera')
) x;
