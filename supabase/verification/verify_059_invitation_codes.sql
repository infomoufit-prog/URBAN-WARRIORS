select
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='invitaciones_club' and column_name='tipo_invitacion') as type_column_ok,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='invitaciones_club' and column_name='codigo') as code_column_ok,
  to_regprocedure('public.app_kombax_invitacion_crear_v059(uuid,text,text,text,text,integer)') is not null as create_rpc_ok,
  to_regprocedure('public.app_kombax_invitacion_validar_v059(text,text)') is not null as validate_rpc_ok,
  to_regprocedure('public.app_kombax_invitacion_aceptar_equipo_v059(text)') is not null as accept_team_rpc_ok,
  to_regprocedure('public.app_kombax_invitacion_email_payload_v059(uuid)') is not null as email_payload_ok,
  to_regprocedure('public.app_kombax_invitacion_email_estado_v059(uuid,text,text)') is not null as email_state_ok,
  pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure) ilike '%invite_code%' as student_register_gate_ok,
  (select count(*)=count(distinct upper(codigo)) from public.invitaciones_club where codigo is not null) as codes_unique_ok,
  not exists(select 1 from public.invitaciones_club where codigo is null) as all_invites_have_code_ok;
