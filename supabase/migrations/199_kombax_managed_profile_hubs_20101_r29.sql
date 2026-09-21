-- KOMBAX 20.101 R29 · managed profile hubs
begin;

create or replace function public.app_kombax_managed_profile_hub_v197(p_perfil_directo_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_type text;
  v_profile jsonb;
  v_caps jsonb:='[]'::jsonb;
  v_managers jsonb:='[]'::jsonb;
  v_specialty jsonb:='{}'::jsonb;
  v_modules jsonb:='[]'::jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_perfil_directo_id is null then raise exception 'KOMBAX_PROFILE_REQUIRED'; end if;
  if not public.app_kombax_puede_gestionar_perfil_v070(p_perfil_directo_id,'read') then
    raise exception 'KOMBAX_PROFILE_NOT_MANAGED';
  end if;

  select d.tipo,
         jsonb_build_object(
           'id',d.id,'tipo',d.tipo,'slug',d.slug,'nombre_publico',d.nombre_publico,
           'descripcion',d.descripcion,'workflow_estado',d.workflow_estado,
           'verificacion_estado',d.verificacion_estado,'publico',d.publico,
           'ubicacion',d.ubicacion,'disciplinas',coalesce(to_jsonb(d.disciplinas),'[]'::jsonb),
           'categoria',d.categoria,'club_declarado',d.club_declarado,'web_publica',d.web_publica,
           'avatar_path',d.avatar_path,'banner_path',d.banner_path,
           'moderacion_estado',d.moderacion_estado,'actualizado_en',d.actualizado_en
         )
  into v_type,v_profile
  from public.perfiles_kombax_directos d where d.id=p_perfil_directo_id;

  if v_type is null then raise exception 'KOMBAX_PROFILE_NOT_FOUND'; end if;

  select coalesce(jsonb_agg(jsonb_build_object('clave',c.capacidad_clave,'origen',c.origen,'sensible',c.sensible) order by c.capacidad_clave),'[]'::jsonb)
    into v_caps from public.app_kombax_profile_capabilities_v196(p_perfil_directo_id)c;

  select coalesce(jsonb_agg(jsonb_build_object('perfil_id',g.perfil_id,'rol',g.rol,'estado',g.estado) order by case g.rol when 'owner' then 0 when 'admin' then 1 when 'editor' then 2 else 3 end,g.creado_en),'[]'::jsonb)
    into v_managers
  from public.kombax_perfil_gestores g
  where g.perfil_directo_id=p_perfil_directo_id and g.estado='activo';

  if v_type='profesional' then
    select jsonb_build_object(
      'principal',pp.especialidad_principal,
      'secundarias',coalesce((select jsonb_agg(s.especialidad_codigo order by s.especialidad_codigo) from public.kombax_profesional_especialidades_secundarias_v196 s where s.perfil_directo_id=pp.perfil_directo_id),'[]'::jsonb)
    ) into v_specialty
    from public.kombax_profesional_perfiles_v196 pp where pp.perfil_directo_id=p_perfil_directo_id;
  end if;

  v_modules:=case v_type
    when 'federacion' then '["overview","public_profile","affiliated_clubs","calendar","events","documents","communications","social","managers","privacy_support"]'::jsonb
    when 'marca' then '["overview","public_profile","showcase","social","contacts","managers","privacy_support"]'::jsonb
    when 'profesional' then '["overview","public_profile","services","schedule","events","social","showcase","privacy_support"]'::jsonb
    when 'competidor' then '["overview","public_profile","sport_profile","events","fight_cards","social","showcase","privacy_support"]'::jsonb
    when 'espectador' then '["overview","saved","event_interests","notifications","privacy_support"]'::jsonb
    else '["overview","public_profile","privacy_support"]'::jsonb end;

  return jsonb_build_object(
    'profile',v_profile,
    'capabilities',v_caps,
    'managers',v_managers,
    'professional_specialty',coalesce(v_specialty,'{}'::jsonb),
    'modules',v_modules,
    'boundaries',jsonb_build_object(
      'private_club_access',false,
      'cross_profile_private_access',false,
      'competitor_is_professional_subtype',false,
      'spectator_public_profile_default',false,
      'health_records_access',false
    ),
    'version','r29-v197'
  );
end $$;

revoke all on function public.app_kombax_managed_profile_hub_v197(uuid) from public,anon;
grant execute on function public.app_kombax_managed_profile_hub_v197(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
