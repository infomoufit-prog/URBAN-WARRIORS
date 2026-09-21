select
  to_regclass('public.miembros_club') is not null as miembros_club,
  to_regclass('public.kombax_solicitudes_equipo_club') is not null as solicitudes_equipo,
  to_regclass('public.kombax_codigos_acceso_club') is not null as codigos_acceso,
  to_regprocedure('public.app_kombax_codigo_validar_v060(text,text,text)') is not null as codigo_validar_v060,
  to_regprocedure('public.app_kombax_club_team_v051(uuid)') is not null as club_team_v051,
  to_regprocedure('public.app_kombax_solicitud_equipo_resolver_v060(uuid,text,text,text)') is not null as resolver_v060,
  to_regprocedure('public.app_kombax_equipo_solicitar_v109(text,text,text)') is not null as v109_already_present;

select estado,count(*) from public.kombax_solicitudes_equipo_club group by estado order by estado;
