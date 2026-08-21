select
  to_regprocedure('public.app_kombax_equipo_solicitar_v109(text,text,text)') is not null as team_request_v109,
  to_regprocedure('public.app_kombax_solicitudes_equipo_v109(uuid)') is not null as team_list_v109,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_solicitudes_equipo_club' and column_name='rol_solicitado') as requested_role_column,
  exists(select 1 from pg_indexes where schemaname='public' and indexname='idx_kombax_solicitudes_equipo_pending_v109') as pending_index;

select rol,count(*)
from public.miembros_club
where activo and rol in ('alumno','familia')
group by rol
order by rol;

select count(*) as invalid_requested_roles
from public.kombax_solicitudes_equipo_club
where rol_solicitado is not null
  and rol_solicitado not in ('coordinacion','secretaria','economia','comunicacion','monitor');
