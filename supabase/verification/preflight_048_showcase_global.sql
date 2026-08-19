select to_regclass('public.kombax_showcase_marcas') is not null as providers_ok,
       to_regclass('public.perfiles_kombax_directos') is not null as profiles_ok,
       to_regprocedure('public.app_kombax_showcase_puede_gestionar_v045(uuid)') is not null as auth_v045_ok;
