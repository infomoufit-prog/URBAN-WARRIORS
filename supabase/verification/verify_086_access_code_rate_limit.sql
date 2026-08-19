select
  to_regclass('public.kombax_codigo_intentos_v086') is not null as auth_attempts_table,
  to_regclass('public.kombax_codigo_intentos_anon_v086') is not null as anon_attempts_table,
  to_regprocedure('public.app_kombax_codigo_validar_raw_v086(text,text,text)') is not null as raw_validator,
  to_regprocedure('public.app_kombax_codigo_validar_seguro_v086(text,text,text)') is not null as safe_validator,
  has_function_privilege('anon','public.app_kombax_codigo_validar_v060(text,text,text)','EXECUTE') as legacy_anon_compat_open,
  has_function_privilege('authenticated','public.app_kombax_codigo_validar_v060(text,text,text)','EXECUTE') as legacy_auth_compat_open,
  not has_function_privilege('anon','public.app_kombax_codigo_validar_raw_v086(text,text,text)','EXECUTE') as raw_anon_closed,
  not has_function_privilege('authenticated','public.app_kombax_codigo_validar_raw_v086(text,text,text)','EXECUTE') as raw_auth_closed,
  has_function_privilege('authenticated','public.app_kombax_codigo_validar_seguro_v086(text,text,text)','EXECUTE') as safe_auth_open,
  not has_table_privilege('authenticated','public.kombax_codigo_intentos_v086','SELECT') as auth_attempts_private,
  not has_table_privilege('anon','public.kombax_codigo_intentos_anon_v086','SELECT') as anon_attempts_private,
  position('x-forwarded-for' in pg_get_functiondef('public.app_kombax_codigo_validar_v060(text,text,text)'::regprocedure))>0 as legacy_ip_rate_limited;
