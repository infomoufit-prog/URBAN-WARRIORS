-- R97 · Calendar and entity-scoped pilot/founder program. No participant is inferred by name.
begin;

insert into kombax_commercial.runtime_config_r64(config_key,value,description) values
 ('pilot_start_at','"2026-10-01T00:00:00+02:00"','Inicio del piloto en Madrid'),
 ('pilot_end_at','"2026-11-16T00:00:00+01:00"','Fin exclusivo del piloto; 15 noviembre completo'),
 ('official_launch_window','"segunda semana de enero de 2027"','Ventana orientativa; no activa el lanzamiento'),
 ('official_launch_at','null','Fecha exacta pendiente de decisión'),
 ('trial_duration_days','15','Duración del futuro trial'),
 ('pilot_mode','true','Programa piloto habilitado'),
 ('public_trial_open','false','Trial público cerrado hasta validar privacidad'),
 ('ai_credits_per_cost_unit','400','Referencia interna; unidad monetaria de tarifa de modelo'),
 ('ai_credits_enforcement','false','Sombra hasta validar concurrencia y cobros')
on conflict(config_key) do nothing;

create table if not exists kombax_commercial.pilot_entities_r97(
 subject_type text not null check(subject_type in ('club','direct_profile')),
 subject_id uuid not null,
 tenant_ref text generated always as (case when subject_type='club' then 'club:' else 'profile:' end || subject_id::text) stored,
 enrolled_at timestamptz not null default now(),
 enrolled_by uuid references auth.users(id) on delete set null,
 founder_eligible boolean not null default true,
 notes text,
 primary key(subject_type,subject_id),
 unique(tenant_ref)
);
alter table kombax_commercial.pilot_entities_r97 enable row level security;
revoke all on kombax_commercial.pilot_entities_r97 from public,anon,authenticated;
grant all on kombax_commercial.pilot_entities_r97 to service_role;

create table if not exists kombax_commercial.plan_benefits_r97(
 id uuid primary key default gen_random_uuid(),
 subject_type text not null check(subject_type in ('club','direct_profile')),
 subject_id uuid not null,
 benefit_code text not null check(benefit_code in ('PILOT_FOUNDER_6M','URBAN_WARRIORS_12M','MANUAL_COMPENSATION')),
 plan_code text not null references kombax_commercial.plan_pricing_r64(plan_code),
 starts_at timestamptz not null,
 ends_at timestamptz not null,
 source text not null,
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 check(ends_at>starts_at),
 unique(subject_type,subject_id,benefit_code,starts_at)
);
create index if not exists plan_benefits_entity_time_r97 on kombax_commercial.plan_benefits_r97(subject_type,subject_id,starts_at,ends_at);
alter table kombax_commercial.plan_benefits_r97 enable row level security;
revoke all on kombax_commercial.plan_benefits_r97 from public,anon,authenticated;
grant all on kombax_commercial.plan_benefits_r97 to service_role;

create or replace function kombax_commercial.program_phase_r97(p_at timestamptz default now())
returns text language sql stable security definer set search_path='' as $$
 with config as (
  select
   (select trim(both '"' from value::text)::timestamptz from kombax_commercial.runtime_config_r64 where config_key='pilot_start_at') pilot_start,
   (select trim(both '"' from value::text)::timestamptz from kombax_commercial.runtime_config_r64 where config_key='pilot_end_at') pilot_end,
   (select case when value='null'::jsonb then null else trim(both '"' from value::text)::timestamptz end from kombax_commercial.runtime_config_r64 where config_key='official_launch_at') launch_at
 )
 select case when p_at<pilot_start then 'PREPARATION' when p_at<pilot_end then 'PILOT'
             when launch_at is null or p_at<launch_at then 'FOUNDER_PRELAUNCH' else 'OFFICIAL' end from config;
$$;
revoke all on function kombax_commercial.program_phase_r97(timestamptz) from public,anon,authenticated;
grant execute on function kombax_commercial.program_phase_r97(timestamptz) to service_role;

create or replace function kombax_commercial.effective_benefit_r97(p_subject_type text,p_subject_id uuid,p_at timestamptz default now())
returns text language sql stable security definer set search_path='' as $$
 select b.plan_code from kombax_commercial.plan_benefits_r97 b
 where b.subject_type=p_subject_type and b.subject_id=p_subject_id and b.starts_at<=p_at and b.ends_at>p_at
 order by b.created_at desc limit 1;
$$;
revoke all on function kombax_commercial.effective_benefit_r97(text,uuid,timestamptz) from public,anon,authenticated;
grant execute on function kombax_commercial.effective_benefit_r97(text,uuid,timestamptz) to service_role;

-- Existing commercial access checks call active_plan_r64. A benefit overrides access for its window
-- while the underlying subscription, content and history stay intact after downgrade.
create or replace function kombax_commercial.active_plan_r64(p_subject_type text,p_subject_id uuid)
returns text language sql stable security definer set search_path='' as $$
 select coalesce(
   kombax_commercial.effective_benefit_r97(p_subject_type,p_subject_id,now()),
   (select s.modalidad from public.kombax_suscripciones s
    where s.sujeto_tipo=case when p_subject_type='direct_profile' then 'perfil_directo' else p_subject_type end
      and s.sujeto_id=p_subject_id and s.estado in('prueba','activa')
      and (s.inicia_en is null or s.inicia_en<=now()) and (s.termina_en is null or s.termina_en>now())
    order by s.actualizado_en desc,s.creado_en desc limit 1));
$$;

create or replace function public.app_kombax_pilot_enroll_r97(p_subject_type text,p_subject_id uuid,p_notes text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not public.app_kombax_es_platform_admin_v055() then raise exception 'platform_admin_required' using errcode='42501'; end if;
 if p_subject_type not in ('club','direct_profile') or p_subject_id is null then raise exception 'invalid_subject'; end if;
 if p_subject_type='club' and not exists(select 1 from public.clubes where id=p_subject_id) then raise exception 'club_not_found'; end if;
 if p_subject_type='direct_profile' and not exists(select 1 from public.perfiles_kombax_directos where id=p_subject_id) then raise exception 'profile_not_found'; end if;
 insert into kombax_commercial.pilot_entities_r97(subject_type,subject_id,enrolled_by,notes)
 values(p_subject_type,p_subject_id,auth.uid(),left(p_notes,500))
 on conflict(subject_type,subject_id) do update set notes=coalesce(excluded.notes,kombax_commercial.pilot_entities_r97.notes);
 return jsonb_build_object('ok',true,'tenant_ref',case when p_subject_type='club' then 'club:' else 'profile:' end||p_subject_id::text,'phase',kombax_commercial.program_phase_r97());
end $$;
revoke all on function public.app_kombax_pilot_enroll_r97(text,uuid,text) from public,anon,service_role;
grant execute on function public.app_kombax_pilot_enroll_r97(text,uuid,text) to authenticated;

create or replace function public.app_kombax_founder_benefit_r97(p_subject_type text,p_subject_id uuid,p_program text,p_start_at timestamptz)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_start timestamptz:=p_start_at;
begin
 if not public.app_kombax_es_platform_admin_v055() then raise exception 'platform_admin_required' using errcode='42501'; end if;
 if p_subject_type<>'club' or p_subject_id is null or v_start is null then raise exception 'invalid_club_or_start'; end if;
 if not exists(select 1 from public.clubes where id=p_subject_id) then raise exception 'club_not_found'; end if;
 if p_program='PILOT_FOUNDER_6M' then
  if not exists(select 1 from kombax_commercial.pilot_entities_r97 where subject_type='club' and subject_id=p_subject_id and founder_eligible) then raise exception 'pilot_enrollment_required'; end if;
  insert into kombax_commercial.plan_benefits_r97(subject_type,subject_id,benefit_code,plan_code,starts_at,ends_at,source,created_by)
  values('club',p_subject_id,p_program,'premium',v_start,v_start+interval '3 months','pilot_founder',auth.uid()),
        ('club',p_subject_id,p_program,'club',v_start+interval '3 months',v_start+interval '6 months','pilot_founder',auth.uid())
  on conflict(subject_type,subject_id,benefit_code,starts_at) do nothing;
 elsif p_program='URBAN_WARRIORS_12M' then
  insert into kombax_commercial.plan_benefits_r97(subject_type,subject_id,benefit_code,plan_code,starts_at,ends_at,source,created_by)
  values('club',p_subject_id,p_program,'premium',v_start,v_start+interval '12 months','official_activation',auth.uid())
  on conflict(subject_type,subject_id,benefit_code,starts_at) do nothing;
 else raise exception 'unsupported_benefit'; end if;
 return jsonb_build_object('ok',true,'club_id',p_subject_id,'program',p_program);
end $$;
revoke all on function public.app_kombax_founder_benefit_r97(text,uuid,text,timestamptz) from public,anon,service_role;
grant execute on function public.app_kombax_founder_benefit_r97(text,uuid,text,timestamptz) to authenticated;

-- Keep the existing AI context aligned with active founder benefits.
create or replace function kombax_ai_ops.resolve_context(p_uid uuid, p_tenant_hint text default null::text)
returns table(tenant_ref text, plan text, started_at timestamptz)
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_ref text:=btrim(coalesce(p_tenant_hint,''));
  v_id uuid;
  v_direct record;
begin
  if p_uid is null then raise exception 'authentication_required' using errcode='42501'; end if;

  if v_ref like 'club:%' then
    begin v_id:=replace(v_ref,'club:','')::uuid; exception when invalid_text_representation then v_id:=null; end;
    if v_id is not null and exists(select 1 from public.miembros_club mc where mc.club_id=v_id and mc.perfil_id=p_uid and mc.activo) then
      tenant_ref:='club:'||v_id::text;
      select coalesce(case kombax_commercial.effective_benefit_r97('club',v_id,now()) when 'enterprise' then 'FEDERATION' when 'premium' then 'CLUB_PREMIUM' when 'club' then 'CLUB_BASIC' end,ts.plan_override,case s.modalidad when 'enterprise' then 'FEDERATION' when 'premium' then 'CLUB_PREMIUM' when 'federacion_institucional' then 'FEDERATION' when 'competidor_premium' then 'CLUB_PREMIUM' when 'marca_profesional' then 'CLUB_PREMIUM' else 'CLUB_BASIC' end),
             coalesce(ts.started_at,s.inicia_en,s.creado_en,c.creado_en,now())
        into plan,started_at
      from public.clubes c
      left join lateral (
        select ks.* from public.kombax_suscripciones ks
        where ks.sujeto_tipo='club' and ks.sujeto_id=c.id and ks.estado in ('prueba','activa')
          and (ks.inicia_en is null or ks.inicia_en<=now()) and (ks.termina_en is null or ks.termina_en>now())
        order by ks.actualizado_en desc limit 1
      ) s on true
      left join kombax_ai_ops.assistance_tenant_settings ts on ts.tenant_ref='club:'||c.id::text
      where c.id=v_id;
      return next; return;
    end if;
  end if;

  if v_ref like 'profile:%' then
    begin v_id:=replace(v_ref,'profile:','')::uuid; exception when invalid_text_representation then v_id:=null; end;
    if v_id is not null and kombax_ai_ops.org_assist_access_allowed(p_uid,'profile:'||v_id::text) then
      select d.id,d.creado_en,d.tipo,d.nombre_publico,s.modalidad,s.inicia_en,s.creado_en subscription_created
        into v_direct
      from public.perfiles_kombax_directos d
      left join lateral (
        select ks.* from public.kombax_suscripciones ks
        where ks.sujeto_tipo='perfil_directo' and ks.sujeto_id=d.id and ks.estado in ('prueba','activa')
          and (ks.inicia_en is null or ks.inicia_en<=now()) and (ks.termina_en is null or ks.termina_en>now())
        order by (ks.modalidad='federacion_institucional') desc,ks.actualizado_en desc limit 1
      ) s on true
      where d.id=v_id and d.estado='activo' and lower(d.tipo) in ('federacion','marca');
      if found then
        tenant_ref:='profile:'||v_direct.id::text;
        select coalesce(ts.plan_override,case v_direct.modalidad when 'federacion_institucional' then 'FEDERATION' when 'marca_profesional' then 'CLUB_PREMIUM' else case when lower(v_direct.tipo)='federacion' then 'FEDERATION' when lower(v_direct.tipo)='marca' then 'CLUB_PREMIUM' else 'CLUB_BASIC' end end),
               coalesce(ts.started_at,v_direct.inicia_en,v_direct.subscription_created,v_direct.creado_en,now())
          into plan,started_at
        from (values(1)) x(n)
        left join kombax_ai_ops.assistance_tenant_settings ts on ts.tenant_ref='profile:'||v_direct.id::text;
        return next; return;
      end if;
    end if;
  end if;

  -- Backwards-compatible raw club UUID hint.
  if v_ref<>'' and v_ref not like '%:%' then
    begin v_id:=v_ref::uuid; exception when invalid_text_representation then v_id:=null; end;
    if v_id is not null and exists(select 1 from public.miembros_club mc where mc.club_id=v_id and mc.perfil_id=p_uid and mc.activo) then
      return query select * from kombax_ai_ops.resolve_context(p_uid,'club:'||v_id::text); return;
    end if;
  end if;

  -- Prefer an accessible Federation/Brand direct profile if one exists.
  select d.id,d.creado_en,d.tipo,d.nombre_publico,s.modalidad,s.inicia_en,s.creado_en subscription_created
    into v_direct
  from public.perfiles_kombax_directos d
  left join lateral (
    select ks.* from public.kombax_suscripciones ks
    where ks.sujeto_tipo='perfil_directo' and ks.sujeto_id=d.id and ks.estado in ('prueba','activa')
      and (ks.inicia_en is null or ks.inicia_en<=now()) and (ks.termina_en is null or ks.termina_en>now())
    order by (ks.modalidad='federacion_institucional') desc,ks.actualizado_en desc limit 1
  ) s on true
  where d.estado='activo'
    and lower(d.tipo) in ('federacion','marca')
    and kombax_ai_ops.org_assist_access_allowed(p_uid,'profile:'||d.id::text)
  order by (lower(d.tipo)='federacion') desc,d.actualizado_en desc
  limit 1;
  if found then
    return query select * from kombax_ai_ops.resolve_context(p_uid,'profile:'||v_direct.id::text); return;
  end if;

  select mc.club_id into v_id
  from public.miembros_club mc
  where mc.perfil_id=p_uid and mc.activo
  order by (mc.rol::text='direccion') desc,mc.creado_en
  limit 1;
  if found then return query select * from kombax_ai_ops.resolve_context(p_uid,'club:'||v_id::text); return; end if;

  tenant_ref:='account:'||p_uid::text;
  select coalesce(ts.plan_override,'CLUB_BASIC'),coalesce(ts.started_at,p.creado_en,now()) into plan,started_at
  from public.perfiles p
  left join kombax_ai_ops.assistance_tenant_settings ts on ts.tenant_ref='account:'||p_uid::text
  where p.id=p_uid;
  if not found then plan:='CLUB_BASIC'; started_at:=now(); end if;
  return next;
end;
$function$;


commit;
