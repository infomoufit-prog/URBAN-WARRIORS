-- R118 FIX05: explicit 30-day trials and persistent monthly organization post quota.
-- Private bookkeeping; public RPCs authorize against real ownership/memberships.
create table if not exists kombax_commercial.space_trials_r118(
  subject_type text not null check(subject_type in ('club','direct_profile')),
  subject_id uuid not null,
  started_at timestamptz not null default now(),
  ends_at timestamptz not null,
  created_by uuid not null,
  primary key(subject_type,subject_id),
  check(ends_at>started_at)
);
alter table kombax_commercial.space_trials_r118 enable row level security;
revoke all on kombax_commercial.space_trials_r118 from public,anon,authenticated;

create or replace function public.app_kombax_space_trial_r118(p_subject_type text,p_subject_id uuid,p_activate boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_trial kombax_commercial.space_trials_r118%rowtype;v_plan text;v_uid uuid:=auth.uid();v_kind text;
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';end if;
  if p_subject_type='club' then
    perform 1 from public.clubes where id=p_subject_id for update;
    if not found or not public.app_puede_gestionar_perfil_club_v035(p_subject_id) then raise exception 'CLUB_OWNER_REQUIRED' using errcode='42501';end if;
    v_plan:='club';
  elsif p_subject_type='direct_profile' then
    select tipo into v_kind from public.perfiles_kombax_directos where id=p_subject_id and perfil_id=v_uid and estado='activo' for update;
    if not found or v_kind<>'federacion' then raise exception 'ORGANIZATION_OWNER_REQUIRED' using errcode='42501';end if;
    v_plan:='federation';
  else raise exception 'INVALID_SUBJECT';end if;
  if exists(select 1 from kombax_commercial.pilot_entities_r97 where subject_type=p_subject_type and subject_id=p_subject_id) then
    return jsonb_build_object('ok',true,'status','pilot','activation_allowed',false,'billing_activation_performed',false);
  end if;
  select * into v_trial from kombax_commercial.space_trials_r118 where subject_type=p_subject_type and subject_id=p_subject_id;
  if v_trial.subject_id is not null then
    return jsonb_build_object('ok',true,'status',case when v_trial.ends_at>now() then 'trial' else 'expired' end,'activation_allowed',false,'started_at',v_trial.started_at,'ends_at',v_trial.ends_at,'billing_activation_performed',false);
  end if;
  if kombax_commercial.active_plan_r64(p_subject_type,p_subject_id) is not null then
    return jsonb_build_object('ok',true,'status','active','activation_allowed',false,'billing_activation_performed',false);
  end if;
  if not p_activate then return jsonb_build_object('ok',true,'status','available','activation_allowed',true,'days',30,'billing_activation_performed',false);end if;
  insert into kombax_commercial.space_trials_r118(subject_type,subject_id,ends_at,created_by)
    values(p_subject_type,p_subject_id,now()+interval '30 days',v_uid) returning * into v_trial;
  insert into public.kombax_suscripciones(sujeto_tipo,sujeto_id,estado,modalidad,proveedor,referencia_externa,inicia_en,termina_en)
    values(case when p_subject_type='direct_profile' then 'perfil_directo' else p_subject_type end,p_subject_id,'prueba',v_plan,'kombax_trial_r118',p_subject_type||':'||p_subject_id::text,v_trial.started_at,v_trial.ends_at);
  if p_subject_type='direct_profile' then perform public.app_kombax_reconcile_entitlements_v071(p_subject_id,v_uid);end if;
  return jsonb_build_object('ok',true,'status','trial','activation_allowed',false,'started_at',v_trial.started_at,'ends_at',v_trial.ends_at,'billing_activation_performed',false);
end $$;
revoke all on function public.app_kombax_space_trial_r118(text,uuid,boolean) from public,anon,service_role;
grant execute on function public.app_kombax_space_trial_r118(text,uuid,boolean) to authenticated;

-- Store consumed slots separately so deleting a post never resets the free quota.
create table if not exists kombax_commercial.social_slots_r118(
  publication_id uuid primary key,
  social_id uuid not null,
  consumed_at timestamptz not null default now()
);
alter table kombax_commercial.social_slots_r118 enable row level security;
revoke all on kombax_commercial.social_slots_r118 from public,anon,authenticated;
create index if not exists social_slots_r118_month on kombax_commercial.social_slots_r118(social_id,consumed_at);
-- Preserve this month's prior publications when introducing the limit.
insert into kombax_commercial.social_slots_r118(publication_id,social_id,consumed_at)
select p.id,p.autor_perfil_id,p.creado_en from public.kombax_social_publicaciones p
join public.kombax_social_perfiles sp on sp.id=p.autor_perfil_id
left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
where sp.sujeto_tipo='club' or (sp.sujeto_tipo='perfil_directo' and d.tipo='federacion')
on conflict(publication_id) do nothing;

create or replace function kombax_commercial.social_quota_guard_r118()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_sp public.kombax_social_perfiles%rowtype;v_kind text;v_subject text;v_id uuid;v_count integer;
begin
  if tg_op='UPDATE' and old.autor_perfil_id is distinct from new.autor_perfil_id then raise exception 'SOCIAL_AUTHOR_IMMUTABLE';end if;
  if new.estado<>'activa' then return new;end if;
  select * into v_sp from public.kombax_social_perfiles where id=new.autor_perfil_id;
  if v_sp.sujeto_tipo='club' then v_subject:='club';v_id:=v_sp.club_id;
  elsif v_sp.sujeto_tipo='perfil_directo' then
    select tipo into v_kind from public.perfiles_kombax_directos where id=v_sp.perfil_directo_id;
    if v_kind<>'federacion' or v_kind is null then return new;end if;
    v_subject:='direct_profile';v_id:=v_sp.perfil_directo_id;
  else return new;end if;
  perform pg_advisory_xact_lock(hashtextextended('social-quota:'||new.autor_perfil_id::text,0));
  if exists(select 1 from kombax_commercial.social_slots_r118 where publication_id=new.id) then return new;end if;
  if kombax_commercial.active_plan_r64(v_subject,v_id) is null then
    select count(*) into v_count from kombax_commercial.social_slots_r118
      where social_id=new.autor_perfil_id and consumed_at>=date_trunc('month',now() at time zone 'UTC') at time zone 'UTC';
    if v_count>=3 then raise exception 'SOCIAL_FREE_MONTHLY_LIMIT_3';end if;
  end if;
  insert into kombax_commercial.social_slots_r118(publication_id,social_id) values(new.id,new.autor_perfil_id) on conflict do nothing;
  return new;
end $$;
revoke all on function kombax_commercial.social_quota_guard_r118() from public,anon,authenticated;
drop trigger if exists kombax_social_quota_r118 on public.kombax_social_publicaciones;
create trigger kombax_social_quota_r118 before insert or update on public.kombax_social_publicaciones
  for each row execute function kombax_commercial.social_quota_guard_r118();
