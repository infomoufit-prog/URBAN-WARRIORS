select 'columnas branding' control,count(*)=4 ok,count(*) detalle
from information_schema.columns where table_schema='public' and table_name='clubes'
  and column_name in ('theme_id','branding_version','branding_actualizado_en','branding_actualizado_por');
select 'historial branding' control,to_regclass('public.club_branding_history') is not null ok;
select 'funcion publicar' control,to_regprocedure('public.app_publicar_branding_v039(uuid,integer,text,text,text)') is not null ok;
select 'funcion restaurar' control,to_regprocedure('public.app_restaurar_branding_v039(uuid,integer)') is not null ok;
select 'temas válidos' control,count(*)=0 ok,count(*) detalle from public.clubes
where theme_id not in ('combat-dark','performance-pro','champion-gold','dojo-heritage');
select 'versiones positivas' control,count(*)=0 ok,count(*) detalle from public.clubes where branding_version<1;
select 'RLS historial' control,c.relrowsecurity ok from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname='club_branding_history';
