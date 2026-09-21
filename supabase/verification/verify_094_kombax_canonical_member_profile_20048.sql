select
  count(*) filter(where column_name='apodo_deportivo')=1 as apodo_column,
  count(*) filter(where column_name='disciplinas_publicas')=1 as disciplines_column,
  count(*) filter(where column_name='trayectoria_declarada')=1 as trajectory_column
from information_schema.columns where table_schema='public' and table_name='identidades_sociales';
select
  to_regprocedure('public.app_kombax_identity_mutate_v094(text,jsonb,uuid)') is not null as mutate_094,
  to_regprocedure('public.app_kombax_perfil_publico_v094(uuid)') is not null as public_profile_094,
  has_function_privilege('authenticated','public.app_kombax_identity_mutate_v094(text,jsonb,uuid)','EXECUTE') as mutate_auth,
  not has_function_privilege('anon','public.app_kombax_identity_mutate_v094(text,jsonb,uuid)','EXECUTE') as mutate_anon_closed,
  has_function_privilege('authenticated','public.app_kombax_perfil_publico_v094(uuid)','EXECUTE') as profile_auth,
  not has_table_privilege('authenticated','public.identidades_sociales','SELECT') as identities_direct_private,
  not has_table_privilege('authenticated','public.perfiles_deportivos','SELECT') as legacy_direct_private;
select position('perfiles_deportivos' in pg_get_functiondef('public.app_kombax_social_sync_miembro_v041()'::regprocedure))=0 as sync_detached_from_legacy;
