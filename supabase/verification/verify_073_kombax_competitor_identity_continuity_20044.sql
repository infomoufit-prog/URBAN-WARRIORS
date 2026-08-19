-- Verificación 073
select to_regprocedure('public.app_kombax_social_switch_competitor_v072(uuid)') is not null as switcher, position('sujeto_tipo=''perfil_directo'' ' in pg_get_functiondef('public.app_kombax_social_switch_competitor_v072(uuid)'::regprocedure))>0 as preserves_row;
