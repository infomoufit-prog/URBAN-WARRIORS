select '060.01 access codes table' test, to_regclass('public.kombax_codigos_acceso_club') is not null ok
union all select '060.02 team requests table',to_regclass('public.kombax_solicitudes_equipo_club') is not null
union all select '060.03 read codes rpc',to_regprocedure('public.app_kombax_codigos_club_v060(uuid)') is not null
union all select '060.04 rotate code rpc',to_regprocedure('public.app_kombax_codigo_rotar_v060(uuid,text,text)') is not null
union all select '060.05 public validate rpc',to_regprocedure('public.app_kombax_codigo_validar_v060(text,text,text)') is not null
union all select '060.06 team request rpc',to_regprocedure('public.app_kombax_equipo_solicitar_v060(text,text)') is not null
union all select '060.07 team review rpc',to_regprocedure('public.app_kombax_solicitud_equipo_resolver_v060(uuid,text,text,text)') is not null
union all select '060.08 current club seeded',exists(select 1 from public.kombax_codigos_acceso_club)
union all select '060.09 codes format',not exists(select 1 from public.kombax_codigos_acceso_club where codigo_alumnos !~ '^[0-9]{4,5}$' or codigo_equipo !~ '^[0-9]{4,5}$' or codigo_alumnos=codigo_equipo)
union all select '060.10 v059 pending revoked',not exists(select 1 from public.invitaciones_club where estado='pendiente' and tipo_invitacion in ('alumno','equipo'))
union all select '060.11 release 20033',(public.app_kombax_es_platform_admin_v055() is false) or true;
