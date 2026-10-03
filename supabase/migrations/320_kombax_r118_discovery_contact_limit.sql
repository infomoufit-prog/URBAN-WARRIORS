-- KOMBAX R118 · Phase 5/9 correction · discovery pagination + contact target

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
    select * from enriched e
    where not v_verified_only or e.facet_verified
  ),
  grouped as (
    select
      e.owner_profile_id,
      max(coalesce((e.row->>'match_score')::integer,0)) as match_score,
      bool_or(coalesce((e.row->>'contactable')::boolean,false)) as contactable,
      jsonb_agg(
        jsonb_set(
          jsonb_set(
            e.row,
            '{credential_verified}',
            to_jsonb(case
              when e.direct_type='profesional' then e.facet_verified
              else coalesce((e.row->>'credential_verified')::boolean,false)
            end),
            true
          ),
          '{facet_verified}',to_jsonb(e.facet_verified),true
        )
        order by coalesce((e.row->>'match_score')::integer,0) desc,e.direct_type
      ) as facets
    from filtered e
    group by e.owner_profile_id
  ),
  ranked as (
    select g.*
    from grouped g
    order by g.match_score desc,g.owner_profile_id
    limit v_limit
  ),
  rendered as (
    select
      g.*,
      canon.social_profile_id as canonical_social_profile_id,
      canon.nombre_publico as canonical_name,
      canon.avatar_url as canonical_avatar,
      coalesce(
        (
          select (f->>'social_profile_id')::uuid
          from jsonb_array_elements(g.facets) f
          where coalesce((f->>'contactable')::boolean,false)
          order by coalesce((f->>'match_score')::integer,0) desc
          limit 1
        ),
        canon.social_profile_id,
        (g.facets->0->>'social_profile_id')::uuid
      ) as contact_social_profile_id
    from ranked g
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
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'person_profile_id',r.owner_profile_id,
      'social_profile_id',coalesce(r.canonical_social_profile_id,(r.facets->0->>'social_profile_id')::uuid),
      'canonical_social_profile_id',r.canonical_social_profile_id,
      'contact_social_profile_id',r.contact_social_profile_id,
      'nombre_publico',coalesce(r.canonical_name,r.facets->0->>'nombre_publico'),
      'avatar_url',coalesce(r.canonical_avatar,r.facets->0->>'avatar_url'),
      'profile_type',case when jsonb_array_length(r.facets)>1 then 'person' else r.facets->0->>'profile_type' end,
      'facet_types',coalesce((select jsonb_agg(distinct f->>'profile_type') from jsonb_array_elements(r.facets) f),'[]'::jsonb),
      'facets',r.facets,
      'contactable',r.contactable,
      'match_score',r.match_score,
      'territory',r.facets->0->>'territory',
      'availability_status',r.facets->0->>'availability_status',
      'availability_private',coalesce((r.facets->0->>'availability_private')::boolean,false),
      'disciplines',coalesce(r.facets->0->'disciplines','[]'::jsonb),
      'credential_verified',exists(
        select 1 from jsonb_array_elements(r.facets) f
        where coalesce((f->>'credential_verified')::boolean,false)
      )
    )
    order by r.match_score desc,coalesce(r.canonical_name,r.facets->0->>'nombre_publico')
  ),'[]'::jsonb)
  into v_rows
  from rendered r;

  return coalesce(v_rows,'[]'::jsonb);
end
$function$;

do $$
begin
  if position('contact_social_profile_id' in pg_get_functiondef('public.app_kombax_discovery_search_r118(jsonb)'::regprocedure))=0 then
    raise exception 'R118_ASSERT_DISCOVERY_CONTACT_TARGET_MISSING';
  end if;
  if position('ranked as' in lower(pg_get_functiondef('public.app_kombax_discovery_search_r118(jsonb)'::regprocedure)))=0 then
    raise exception 'R118_ASSERT_DISCOVERY_LIMIT_STAGE_MISSING';
  end if;
end $$;
