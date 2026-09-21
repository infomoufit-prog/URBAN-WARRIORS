select to_regclass('public.perfiles_kombax_directos') is not null as direct_profiles_ok,
       to_regclass('public.kombax_social_perfiles') is not null as social_profiles_ok,
       to_regprocedure('public.app_kombax_social_mutate_v044(text,jsonb,uuid)') is not null as social_044_ok;
