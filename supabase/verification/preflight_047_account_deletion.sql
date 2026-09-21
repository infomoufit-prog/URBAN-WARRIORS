select to_regclass('public.perfiles') is not null as perfiles_ok,
       to_regclass('public.perfiles_kombax_directos') is not null as kombax_profiles_ok,
       to_regclass('public.app_mutation_requests') is not null as mutation_requests_ok;
