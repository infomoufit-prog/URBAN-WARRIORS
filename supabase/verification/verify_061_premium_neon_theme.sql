select '061.01 public profile theme rpc' check_name,to_regprocedure('public.app_perfil_club_publico_v061(uuid)') is not null ok
union all select '061.02 kombax public profile v053',position('theme_id' in pg_get_functiondef(to_regprocedure('public.app_kombax_perfil_publico_v053(uuid)')))>0
union all select '061.03 four supported themes',(select count(*)=4 from (values('combat-dark'),('performance-pro'),('champion-gold'),('dojo-heritage')) v(id));
