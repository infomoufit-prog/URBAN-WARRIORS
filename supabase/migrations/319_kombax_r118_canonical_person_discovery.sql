-- KOMBAX R118 · Phase 5/9 · canonical person discovery without duplicate cards

create or replace function public.app_kombax_discovery_search_r118(p_filters jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
stable security definer
set search_path to 'public','auth'
as $function$
declare
  v_uid uuid:=auth.uid();
  v_filters jsonb:=coalesce(p_filters,'{}'::jsonb);
  v_verified_only boolean:=coalesce(nullif(v_filters->>'verified_only','')::boolean,false);
  v_limit integer:=least(100,greatest(1,coalesce(nullif(v_filters->>'limit','')::integer,30)));
  v_raw jsonb;
  v_rows jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;

  -- R626 uses the historical English credential state. Run its structural filters
  -- without verified_only and apply the corrected R118 verification semantics below.
  v_raw:=public.app_kombax_discovery_search_r626(
    jsonb_set(v_filters,'{verified_only}','false'::jsonb,true)
  );

  with raw as (
    select x.value as row
    from jsonb_array_elements(coalesce(v_raw,'[]'::jsonb)) x
  ),
  enriched as (
    select
      r.row,
      d.perfil_id as owner_profile_id,
      d.id as direct_profile_id,
      d.tipo as direct_type,
      case
        when d.tipo='profesional' then exists(
          select 1 from public.kombax_professional_credentials_v198 c
          where c.professional_profile_id=d.id
            and c.estado='verificada'
            and (c.expires_on is null or c.expires_on>=current_date)
        )
        else coalesce((r.row->>'verificado')::boolean,false)
      end as facet_verified
    from raw r
    join public.perfiles_kombax_directos d on d.id=(r.row->>'profile_id')::uuid
  ),
  filtered as (
    select *
    from enriched e
    where not v_verified_only or e.facet_verified
  ),
  grouped as (
    select
      e.owner_profile_id,
      max(coalesce((e.row->>'match_score')::integer,0)) as match_score,
      bool_or(coalesce((e.row->>'contactable')::boolean,false)) as contactable,
      jsonb_agg(
        jsonb_set(
          jsonb_set(e.row,'{credential_verified}',to_jsonb(case when e.direct_type='profesional' then e.facet_verified else coalesce((e.row->>'credential_verified')::boolean,false) end),true),
          '{facet_verified}',to_jsonb(e.facet_verified),true
        )
        order by coalesce((e.row->>'match_score')::integer,0) desc,e.direct_type
      ) as facets
    from filtered e
    group by e.owner_profile_id
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'person_profile_id',g.owner_profile_id,
      'social_profile_id',coalesce(canon.social_profile_id,(g.facets->0->>'social_profile_id')::uuid),
      'canonical_social_profile_id',canon.social_profile_id,
      'nombre_publico',coalesce(canon.nombre_publico,g.facets->0->>'nombre_publico'),
      'avatar_url',coalesce(canon.avatar_url,g.facets->0->>'avatar_url'),
      'profile_type',case when jsonb_array_length(g.facets)>1 then 'person' else g.facets->0->>'profile_type' end,
      'facet_types',coalesce((select jsonb_agg(distinct f->>'profile_type') from jsonb_array_elements(g.facets) f),'[]'::jsonb),
      'facets',g.facets,
      'contactable',g.contactable,
      'match_score',g.match_score,
      'territory',g.facets->0->>'territory',
      'availability_status',g.facets->0->>'availability_status',
      'availability_private',coalesce((g.facets->0->>'availability_private')::boolean,false),
      'disciplines',coalesce(g.facets->0->'disciplines','[]'::jsonb),
      'credential_verified',exists(
        select 1 from jsonb_array_elements(g.facets) f
        where coalesce((f->>'credential_verified')::boolean,false)
      )
    )
    order by g.match_score desc,coalesce(canon.nombre_publico,g.facets->0->>'nombre_publico')
  ),'[]'::jsonb) into v_rows
  from grouped g
  left join lateral (
    select sp.id as social_profile_id,sp.nombre_publico,sp.avatar_url
    from public.identidades_sociales i
    join public.kombax_social_perfiles sp
      on sp.identidad_social_id=i.id
     and sp.sujeto_tipo='miembro'
     and sp.visible and sp.estado='activo'
    where i.perfil_id=g.owner_profile_id and i.estado='activa'
    order by sp.actualizado_en desc
    limit 1
  ) canon on true
  limit v_limit;

  return coalesce(v_rows,'[]'::jsonb);
end
$function$;

create or replace function public.app_kombax_discovery_public_profile_r118(p_social_profile_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path to 'public','auth'
as $function$
declare
  v_base jsonb;
  v_profile uuid;
  v_type text;
  v_verified boolean:=false;
  v_credentials jsonb:='[]'::jsonb;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  v_base:=public.app_kombax_discovery_public_profile_r626(p_social_profile_id);
  if v_base is null then return null; end if;
  begin v_profile:=(v_base->>'profile_id')::uuid; exception when others then return v_base; end;
  v_type:=v_base->>'profile_type';
  if v_type='professional' then
    select exists(
      select 1 from public.kombax_professional_credentials_v198 c
      where c.professional_profile_id=v_profile
        and c.estado='verificada'
        and (c.expires_on is null or c.expires_on>=current_date)
    ) into v_verified;
    select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into v_credentials
    from public.app_kombax_professional_public_credentials_r118(v_profile) x;
    v_base:=jsonb_set(v_base,'{credential_verified}',to_jsonb(v_verified),true)
            ||jsonb_build_object('public_credentials',v_credentials);
  end if;
  return v_base;
end
$function$;

create or replace function public.app_kombax_person_facets_r118(p_social_profile_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path to 'public','auth'
as $function$
declare
  v_owner uuid;
  v_canonical uuid;
  v_facets jsonb;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;

  select coalesce(i.perfil_id,d.perfil_id)
  into v_owner
  from public.kombax_social_perfiles sp
  left join public.identidades_sociales i
    on sp.sujeto_tipo='miembro' and i.id=sp.identidad_social_id
  left join public.perfiles_kombax_directos d
    on sp.sujeto_tipo='perfil_directo' and d.id=sp.perfil_directo_id
  where sp.id=p_social_profile_id and sp.visible and sp.estado='activo';

  if v_owner is null then return null; end if;

  select sp.id into v_canonical
  from public.identidades_sociales i
  join public.kombax_social_perfiles sp
    on sp.identidad_social_id=i.id and sp.sujeto_tipo='miembro'
  where i.perfil_id=v_owner and i.estado='activa' and sp.visible and sp.estado='activo'
  order by sp.actualizado_en desc limit 1;

  select coalesce(jsonb_agg(jsonb_build_object(
    'profile_id',d.id,
    'social_profile_id',sp.id,
    'type',d.tipo,
    'name',d.nombre_publico,
    'verified',d.verificacion_estado='verificado',
    'status',d.estado,
    'specialty',pp.especialidad_principal,
    'professional_specialties',case when d.tipo='profesional' then
      array_prepend(pp.especialidad_principal,coalesce((select array_agg(s.especialidad_codigo order by s.especialidad_codigo) from public.kombax_profesional_especialidades_secundarias_v196 s where s.perfil_directo_id=d.id),'{}'::text[]))
      else null end,
    'credential_verified',case when d.tipo='profesional' then exists(
      select 1 from public.kombax_professional_credentials_v198 c
      where c.professional_profile_id=d.id and c.estado='verificada'
        and (c.expires_on is null or c.expires_on>=current_date)
    ) else false end,
    'public_credentials',case when d.tipo='profesional' then
      coalesce((select jsonb_agg(to_jsonb(pc)) from public.app_kombax_professional_public_credentials_r118(d.id) pc),'[]'::jsonb)
      else '[]'::jsonb end
  ) order by d.tipo),'[]'::jsonb)
  into v_facets
  from public.perfiles_kombax_directos d
  join public.kombax_social_perfiles sp
    on sp.perfil_directo_id=d.id and sp.sujeto_tipo='perfil_directo'
   and sp.visible and sp.estado='activo'
  left join public.kombax_profesional_perfiles_v196 pp on pp.perfil_directo_id=d.id
  where d.perfil_id=v_owner
    and d.tipo in ('competidor','profesional','espectador')
    and d.estado='activo';

  return jsonb_build_object(
    'person_profile_id',v_owner,
    'canonical_social_profile_id',v_canonical,
    'facets',v_facets
  );
end
$function$;

revoke all on function public.app_kombax_discovery_search_r118(jsonb) from public;
revoke all on function public.app_kombax_discovery_public_profile_r118(uuid) from public;
revoke all on function public.app_kombax_person_facets_r118(uuid) from public;
grant execute on function public.app_kombax_discovery_search_r118(jsonb) to authenticated;
grant execute on function public.app_kombax_discovery_public_profile_r118(uuid) to authenticated;
grant execute on function public.app_kombax_person_facets_r118(uuid) to authenticated;

do $$
begin
  if position('estado=''verificada''' in pg_get_functiondef('public.app_kombax_discovery_public_profile_r118(uuid)'::regprocedure))=0 then
    raise exception 'R118_ASSERT_CREDENTIAL_STATE_NOT_FIXED';
  end if;
end $$;
