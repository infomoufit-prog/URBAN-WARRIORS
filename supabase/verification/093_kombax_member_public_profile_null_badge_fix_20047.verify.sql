select
  position('coalesce(to_jsonb(v_badge)' in pg_get_functiondef('public.app_kombax_perfil_publico_v072(uuid)'::regprocedure)) > 0 as null_badge_safe,
  has_function_privilege('authenticated','public.app_kombax_perfil_publico_v072(uuid)','EXECUTE') as authenticated_open,
  not has_function_privilege('anon','public.app_kombax_perfil_publico_v072(uuid)','EXECUTE') as anon_closed;
