-- R95: verified competitor discovery with exact or overlapping competitive weight.
begin;
create or replace function public.app_kombax_discovery_search_r626(p_filters jsonb default '{}'::jsonb)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_target text:=lower(coalesce(nullif(trim(p_filters->>'target_type'),''),'all'));
  v_query text:=lower(trim(coalesce(p_filters->>'query','')));
  v_discipline text:=lower(trim(coalesce(p_filters->>'discipline','')));
  v_territory text:=lower(trim(coalesce(p_filters->>'territory','')));
  v_availability text:=lower(coalesce(nullif(trim(p_filters->>'availability'),''),'open'));
  v_level text:=lower(trim(coalesce(p_filters->>'competition_level','')));
  v_affiliation text:=lower(trim(coalesce(p_filters->>'affiliation_status','')));
  v_specialty text:=lower(trim(coalesce(p_filters->>'specialty','')));
  v_work_mode text:=lower(trim(coalesce(p_filters->>'work_mode','')));
  v_weight numeric:=nullif(p_filters->>'weight_kg','')::numeric;
  v_weight_min numeric:=nullif(p_filters->>'weight_min_kg','')::numeric;
  v_weight_max numeric:=nullif(p_filters->>'weight_max_kg','')::numeric;
  v_min_fights integer:=nullif(p_filters->>'min_fights','')::integer;
  v_min_experience integer:=nullif(p_filters->>'min_experience_years','')::integer;
  v_short_notice boolean:=coalesce(nullif(p_filters->>'short_notice','')::boolean,false);
  v_verified_only boolean:=coalesce(nullif(p_filters->>'verified_only','')::boolean,false);
  v_date_from timestamptz:=nullif(p_filters->>'date_from','')::timestamptz;
  v_date_to timestamptz:=nullif(p_filters->>'date_to','')::timestamptz;
  v_limit integer:=least(100,greatest(1,coalesce(nullif(p_filters->>'limit','')::integer,30)));
  v_rows jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_target not in ('all','competitor','professional') then raise exception 'KOMBAX_DISCOVERY_TARGET_INVALID'; end if;
  if v_availability not in ('open','all','available','limited','unavailable') then raise exception 'KOMBAX_DISCOVERY_AVAILABILITY_INVALID'; end if;
  if (v_weight is not null and (v_weight<15 or v_weight>300)) or (v_weight_min is not null and (v_weight_min<15 or v_weight_min>300)) or (v_weight_max is not null and (v_weight_max<15 or v_weight_max>300)) or (v_weight_min is not null and v_weight_max is not null and v_weight_min>v_weight_max) then raise exception 'KOMBAX_DISCOVERY_WEIGHT_INVALID'; end if;
  if v_date_from is not null and v_date_to is null then v_date_to:=v_date_from+interval '1 day'; end if;
  if v_date_to is not null and v_date_from is null then v_date_from:=v_date_to-interval '1 day'; end if;
  if v_date_from is not null and v_date_to<=v_date_from then raise exception 'KOMBAX_DISCOVERY_DATE_RANGE_INVALID'; end if;

  with discovery as (
    select
      d.id as profile_id,s.id as social_profile_id,'competitor'::text as profile_type,d.nombre_publico,d.slug,
      s.avatar_url,s.verificado,coalesce(f.territory,d.ubicacion) as territory,f.max_travel_km,f.disciplines,
      case when f.availability_public then f.availability_status else null end as availability_status,
      case when f.availability_public then f.availability_reason else null end as availability_reason,
      not f.availability_public as availability_private,
      f.availability_updated_at,(coalesce(s.contacto_habilitado,false) and f.discoverable) as contactable,
      f.min_notice_hours,f.competition_level,f.usual_category,f.public_weight_min_kg,f.public_weight_max_kg,
      f.fight_count_declared,f.wins_declared,f.losses_declared,f.draws_declared,f.affiliation_status,f.accepts_short_notice,
      null::text as specialty,null::text[] as specialties,null::integer as experience_years,null::text[] as work_modes,false as credential_verified,
      (case when f.availability_status='available' then 4 when f.availability_status='limited' then 2 else 0 end
       +case when f.accepts_short_notice then 2 else 0 end
       +case when s.verificado then 1 else 0 end) as match_score
    from public.kombax_fighter_discovery_v221 f
    join public.perfiles_kombax_directos d on d.id=f.competitor_profile_id
    join public.kombax_social_perfiles s on s.id=f.social_profile_id
    where v_target in ('all','competitor') and f.discoverable
      and d.tipo='competidor' and d.publico and d.estado='activo' and d.verificacion_estado='verificado' and public.app_kombax_fighter_is_adult_v221(d.id)
      and s.visible and s.estado='activo' and s.verificado
      and (v_query='' or lower(coalesce(d.nombre_publico,'')) like '%'||v_query||'%' or lower(coalesce(d.club_declarado,'')) like '%'||v_query||'%' or lower(coalesce(d.ubicacion,'')) like '%'||v_query||'%')
      and (v_discipline='' or exists(select 1 from unnest(f.disciplines) z where lower(z)=v_discipline))
      and (v_territory='' or lower(coalesce(f.territory,d.ubicacion,'')) like '%'||v_territory||'%')
      and (v_availability='all' or (f.availability_public and ((v_availability='open' and f.availability_status in ('available','limited')) or f.availability_status=v_availability)))
      and (v_level='' or lower(coalesce(f.competition_level,''))=v_level)
      and (v_affiliation='' or lower(f.affiliation_status)=v_affiliation)
      and ((v_weight is null and v_weight_min is null and v_weight_max is null) or ((f.public_weight_min_kg is not null or f.public_weight_max_kg is not null) and (v_weight is null or ((f.public_weight_min_kg is null or f.public_weight_min_kg<=v_weight) and (f.public_weight_max_kg is null or f.public_weight_max_kg>=v_weight))) and (v_weight_min is null or f.public_weight_max_kg is null or f.public_weight_max_kg>=v_weight_min) and (v_weight_max is null or f.public_weight_min_kg is null or f.public_weight_min_kg<=v_weight_max)))
      and (v_min_fights is null or coalesce(f.fight_count_declared,0)>=v_min_fights)
      and (not v_short_notice or f.accepts_short_notice)
      and (not v_verified_only or s.verificado)
      and (v_date_from is null or exists(select 1 from public.kombax_discovery_availability_slots_r626 sl where sl.profile_id=d.id and sl.visibility='public' and sl.slot_status='available' and sl.starts_at<v_date_to and sl.ends_at>v_date_from))

    union all

    select
      d.id as profile_id,s.id as social_profile_id,'professional'::text as profile_type,d.nombre_publico,d.slug,
      s.avatar_url,s.verificado,coalesce(p.territory,d.ubicacion) as territory,p.max_travel_km,p.disciplines,
      case when p.availability_public then p.availability_status else null end as availability_status,
      case when p.availability_public then p.availability_reason else null end as availability_reason,
      not p.availability_public as availability_private,
      p.availability_updated_at,(coalesce(s.contacto_habilitado,false) and p.contact_enabled and p.discoverable) as contactable,
      p.min_notice_hours,null::text as competition_level,null::text as usual_category,null::numeric as public_weight_min_kg,null::numeric as public_weight_max_kg,
      null::integer as fight_count_declared,null::integer as wins_declared,null::integer as losses_declared,null::integer as draws_declared,null::text as affiliation_status,false as accepts_short_notice,
      pp.especialidad_principal as specialty,
      array_prepend(pp.especialidad_principal,coalesce((select array_agg(ps.especialidad_codigo order by ps.especialidad_codigo) from public.kombax_profesional_especialidades_secundarias_v196 ps where ps.perfil_directo_id=d.id),'{}'::text[])) as specialties,
      p.experience_years,p.work_modes,
      exists(select 1 from public.kombax_professional_credentials_v198 c where c.professional_profile_id=d.id and c.estado='verified' and (c.expires_on is null or c.expires_on>=current_date)) as credential_verified,
      (case when p.availability_status='available' then 4 when p.availability_status='limited' then 2 else 0 end
       +case when s.verificado then 1 else 0 end
       +case when exists(select 1 from public.kombax_professional_credentials_v198 c where c.professional_profile_id=d.id and c.estado='verified' and (c.expires_on is null or c.expires_on>=current_date)) then 2 else 0 end) as match_score
    from public.kombax_professional_discovery_r626 p
    join public.perfiles_kombax_directos d on d.id=p.professional_profile_id
    join public.kombax_social_perfiles s on s.id=p.social_profile_id
    left join public.kombax_profesional_perfiles_v196 pp on pp.perfil_directo_id=d.id
    where v_target in ('all','professional') and p.discoverable
      and d.tipo='profesional' and d.publico and d.estado='activo'
      and s.visible and s.estado='activo'
      and (v_query='' or lower(coalesce(d.nombre_publico,'')) like '%'||v_query||'%' or lower(coalesce(d.ubicacion,'')) like '%'||v_query||'%' or lower(coalesce(pp.especialidad_principal,'')) like '%'||v_query||'%')
      and (v_discipline='' or exists(select 1 from unnest(p.disciplines) z where lower(z)=v_discipline))
      and (v_territory='' or lower(coalesce(p.territory,d.ubicacion,'')) like '%'||v_territory||'%')
      and (v_availability='all' or (p.availability_public and ((v_availability='open' and p.availability_status in ('available','limited')) or p.availability_status=v_availability)))
      and (v_specialty='' or lower(coalesce(pp.especialidad_principal,'')) like '%'||v_specialty||'%' or exists(select 1 from public.kombax_profesional_especialidades_secundarias_v196 ps where ps.perfil_directo_id=d.id and lower(ps.especialidad_codigo) like '%'||v_specialty||'%'))
      and (v_work_mode='' or exists(select 1 from unnest(p.work_modes) z where lower(z)=v_work_mode))
      and (v_min_experience is null or coalesce(p.experience_years,0)>=v_min_experience)
      and (not v_verified_only or s.verificado or exists(select 1 from public.kombax_professional_credentials_v198 c where c.professional_profile_id=d.id and c.estado='verified' and (c.expires_on is null or c.expires_on>=current_date)))
      and (v_date_from is null or exists(select 1 from public.kombax_discovery_availability_slots_r626 sl where sl.profile_id=d.id and sl.visibility='public' and sl.slot_status='available' and sl.starts_at<v_date_to and sl.ends_at>v_date_from))
  )
  select coalesce(jsonb_agg(to_jsonb(x) order by x.match_score desc,x.nombre_publico),'[]'::jsonb) into v_rows
  from (select * from discovery order by match_score desc,nombre_publico limit v_limit) x;
  return v_rows;
end $$;
commit;
