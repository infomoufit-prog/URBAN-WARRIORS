-- Verificación 069: Miembro nunca tiene insignia; solo Club/Competidor/Marca/Federación son elegibles.
select
  count(*) filter(where sujeto_tipo='miembro' and verificado) as miembros_con_insignia_debe_ser_0,
  count(*) filter(where sujeto_tipo='club' and not verificado) as clubes_sin_insignia,
  count(*) filter(where sujeto_tipo='perfil_directo' and verificado and coalesce(public.app_kombax_social_tipo_v051(id),'') not in ('competidor','marca','federacion')) as directos_invalidos_con_insignia
from public.kombax_social_perfiles;

select
  position('new.verificado:=coalesce(v_valid,false)' in pg_get_functiondef('public.app_kombax_social_badge_guard_v069()'::regprocedure))>0 as guard_fuerza_politica,
  position('false' in pg_get_functiondef('public.app_kombax_social_sync_miembro_v041()'::regprocedure))>0 as sync_miembro_sin_insignia,
  has_function_privilege('authenticated','public.app_kombax_badge_tipo_v069(uuid)','EXECUTE') as badge_rpc_auth,
  not has_function_privilege('anon','public.app_kombax_badge_tipo_v069(uuid)','EXECUTE') as badge_rpc_no_anon;
