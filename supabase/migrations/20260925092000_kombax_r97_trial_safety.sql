-- R97 · Future trial stays closed. Unverified trial entities cannot store migration documents.
begin;

create table if not exists kombax_commercial.trial_entities_r97(
 club_id uuid primary key references public.clubes(id) on delete restrict,
 started_at timestamptz not null default now(),
 ends_at timestamptz not null,
 verified_at timestamptz,
 converted_at timestamptz,
 created_by uuid not null references auth.users(id) on delete restrict,
 check(ends_at>started_at),
 check(converted_at is null or verified_at is not null)
);
alter table kombax_commercial.trial_entities_r97 enable row level security;
revoke all on kombax_commercial.trial_entities_r97 from public,anon,authenticated;
grant all on kombax_commercial.trial_entities_r97 to service_role;

create or replace function kombax_commercial.trial_safe_r97(p_tenant_ref text)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from kombax_commercial.trial_entities_r97 t
   where p_tenant_ref='club:'||t.club_id::text and t.verified_at is null and t.converted_at is null);
$$;
revoke all on function kombax_commercial.trial_safe_r97(text) from public,anon,authenticated;
grant execute on function kombax_commercial.trial_safe_r97(text) to service_role;

create or replace function public.app_kombax_trial_upload_allowed_r97(p_ticket_id text)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from kombax_customer_ops.tickets t
   where t.ticket_id=p_ticket_id and t.user_ref=auth.uid()
     and not kombax_commercial.trial_safe_r97(t.tenant_ref));
$$;
revoke all on function public.app_kombax_trial_upload_allowed_r97(text) from public,anon,service_role;
grant execute on function public.app_kombax_trial_upload_allowed_r97(text) to authenticated;

-- Storage checks run before a file is accepted, not merely before its metadata is registered.
drop policy if exists kombax_migration_staging_insert_v217 on storage.objects;
create policy kombax_migration_staging_insert_v217 on storage.objects for insert to authenticated with check(
 bucket_id='kombax-migration-staging' and (storage.foldername(name))[1]=auth.uid()::text
 and public.app_kombax_migration_ticket_owned_v217((storage.foldername(name))[2])
 and public.app_kombax_trial_upload_allowed_r97((storage.foldername(name))[2])
);

create or replace function public.app_kombax_trial_start_r97(p_club_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_open boolean;v_days integer;v_started timestamptz:=now();
begin
 if auth.uid() is null then raise exception 'authentication_required' using errcode='42501'; end if;
 select value::text='true' into v_open from kombax_commercial.runtime_config_r64 where config_key='public_trial_open';
 if not coalesce(v_open,false) then return jsonb_build_object('ok',false,'reason','TRIAL_NOT_OPEN'); end if;
 if p_club_id is null or not public.app_puede_gestionar_perfil_club_v035(p_club_id) then raise exception 'club_owner_required' using errcode='42501'; end if;
 if exists(select 1 from kombax_commercial.pilot_entities_r97 where subject_type='club' and subject_id=p_club_id) then raise exception 'pilot_not_trial'; end if;
 select value::text::integer into v_days from kombax_commercial.runtime_config_r64 where config_key='trial_duration_days';
 insert into kombax_commercial.trial_entities_r97(club_id,started_at,ends_at,created_by)
 values(p_club_id,v_started,v_started+make_interval(days=>coalesce(v_days,15)),auth.uid())
 on conflict(club_id) do nothing;
 return jsonb_build_object('ok',true,'club_id',p_club_id,'safe_mode',true);
end $$;
revoke all on function public.app_kombax_trial_start_r97(uuid) from public,anon,service_role;
grant execute on function public.app_kombax_trial_start_r97(uuid) to authenticated;

commit;
