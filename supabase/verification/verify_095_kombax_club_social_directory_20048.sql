select
  to_regprocedure('public.app_kombax_club_social_directory_v095(uuid,text,integer)') is not null as directory_present,
  has_function_privilege('authenticated','public.app_kombax_club_social_directory_v095(uuid,text,integer)','EXECUTE') as directory_auth,
  not has_function_privilege('anon','public.app_kombax_club_social_directory_v095(uuid,text,integer)','EXECUTE') as directory_anon_closed,
  position('kombax_relaciones' in pg_get_functiondef('public.app_kombax_club_social_directory_v095(uuid,text,integer)'::regprocedure))=0 as relations_not_exposed;
