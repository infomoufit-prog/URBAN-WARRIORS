-- KOMBAX R62.5 split migration aligned with remote Supabase history.
-- Derived without semantic changes from original 20260910192600 migration.

begin;
-- ---------------------------------------------------------------------------
-- 1) CONNECT PARA ORGANIZADORES DIRECTOS DE EVENTS (profesional/competidor)
-- Federación reutiliza subject_type=federation; Club reutiliza club; Marca reutiliza
-- showcase_provider. Evitamos una segunda cuenta Stripe para la misma entidad.
-- ---------------------------------------------------------------------------
alter table kombax_payments.connected_accounts
  add column if not exists event_organizer_profile_id uuid references public.perfiles_kombax_directos(id) on delete restrict;

alter table kombax_payments.connected_accounts drop constraint if exists connected_accounts_subject_type_check;
alter table kombax_payments.connected_accounts
  add constraint connected_accounts_subject_type_check
  check(subject_type in('club','showcase_provider','federation','event_organizer'));

alter table kombax_payments.connected_accounts drop constraint if exists connected_accounts_check;
alter table kombax_payments.connected_accounts
  add constraint connected_accounts_check check(
    (subject_type='club' and club_id=subject_id and showcase_provider_id is null and federation_profile_id is null and event_organizer_profile_id is null)
    or (subject_type='showcase_provider' and showcase_provider_id=subject_id and club_id is null and federation_profile_id is null and event_organizer_profile_id is null)
    or (subject_type='federation' and federation_profile_id=subject_id and club_id is null and showcase_provider_id is null and event_organizer_profile_id is null)
    or (subject_type='event_organizer' and event_organizer_profile_id=subject_id and club_id is null and showcase_provider_id is null and federation_profile_id is null)
  );

create index if not exists idx_connected_accounts_event_organizer_r625
  on kombax_payments.connected_accounts(event_organizer_profile_id)
  where event_organizer_profile_id is not null;

create or replace function kombax_payments.can_manage_event_organizer_connect_r625(p_actor uuid,p_profile uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select p_actor is not null and exists(
    select 1
    from public.perfiles_kombax_directos d
    where d.id=p_profile
      and d.tipo in('profesional','competidor')
      and d.estado='activo'
      and d.verificacion_estado='verificado'
      and (
        d.perfil_id=p_actor
        or exists(
          select 1 from public.kombax_perfil_gestores g
          where g.perfil_directo_id=d.id and g.perfil_id=p_actor and g.estado='activo' and g.rol in('owner','admin')
        )
        or exists(select 1 from public.kombax_platform_admins pa where pa.perfil_id=p_actor and pa.activo)
      )
      and exists(
        select 1 from public.kombax_entitlements e
        where e.sujeto_tipo='perfil_directo' and e.sujeto_id=d.id
          and e.capacidad_clave='events.public.organize' and e.activa
          and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now())
      )
  );
$$;

create or replace function public.app_stripe_connect_status_v259(p_subject_type text,p_subject_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());v_ok boolean:=false;v_row kombax_payments.connected_accounts;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_subject_type='club' then
    v_ok:=exists(select 1 from public.miembros_club m where m.club_id=p_subject_id and m.perfil_id=v_uid and m.activo and m.rol in('direccion','secretaria','economia'));
  elsif p_subject_type='showcase_provider' then
    v_ok:=kombax_payments.can_manage_provider(v_uid,p_subject_id);
  elsif p_subject_type='federation' then
    v_ok:=kombax_payments.can_view_federation_connect_r624(v_uid,p_subject_id);
  elsif p_subject_type='event_organizer' then
    v_ok:=kombax_payments.can_manage_event_organizer_connect_r625(v_uid,p_subject_id);
  end if;
  if not v_ok then raise exception 'PAYMENTS_ACCESS_DENIED'; end if;
  select * into v_row from kombax_payments.connected_accounts a where a.subject_type=p_subject_type and a.subject_id=p_subject_id;
  if not found then return jsonb_build_object(
    'subject_type',p_subject_type,'subject_id',p_subject_id,'status','not_configured','charges_enabled',false,'payouts_enabled',false,'details_submitted',false,
    'requirements_due','[]'::jsonb,'requirements_eventually_due','[]'::jsonb,'requirements_pending_verification','[]'::jsonb,
    'charge_model','direct','stripe_fees_payer','account','losses_responsibility','stripe','stripe_dashboard_type','full','configuration_compatible',true
  ); end if;
  return jsonb_build_object(
    'subject_type',v_row.subject_type,'subject_id',v_row.subject_id,'status',v_row.status,'charges_enabled',v_row.charges_enabled,'payouts_enabled',v_row.payouts_enabled,
    'details_submitted',v_row.details_submitted,'requirements_due',v_row.requirements_due,'requirements_eventually_due',v_row.requirements_eventually_due,
    'requirements_pending_verification',v_row.requirements_pending_verification,'disabled_reason',v_row.disabled_reason,'updated_at',v_row.updated_at,'last_synced_at',v_row.last_synced_at,
    'stripe_api_version',v_row.stripe_api_version,'charge_model',v_row.charge_model,'stripe_fees_payer',v_row.stripe_fees_payer,
    'losses_responsibility',v_row.losses_responsibility,'stripe_dashboard_type',v_row.stripe_dashboard_type,'configuration_compatible',v_row.configuration_compatible
  );
end $$;

create or replace function public.app_stripe_connect_prepare_internal_v259(p_actor_id uuid,p_subject_type text,p_subject_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_ok boolean:=false;v_name text;v_email text;v_account kombax_payments.connected_accounts;
begin
  if p_actor_id is null then raise exception 'ACTOR_REQUIRED'; end if;
  if p_subject_type='club' then
    select exists(select 1 from public.miembros_club m where m.club_id=p_subject_id and m.perfil_id=p_actor_id and m.activo and m.rol='direccion'),c.nombre,c.email
      into v_ok,v_name,v_email from public.clubes c where c.id=p_subject_id;
  elsif p_subject_type='showcase_provider' then
    v_ok:=kombax_payments.can_manage_provider(p_actor_id,p_subject_id);
    select m.nombre,(select u.email from auth.users u where u.id=p_actor_id) into v_name,v_email from public.kombax_showcase_marcas m where m.id=p_subject_id;
  elsif p_subject_type='federation' then
    v_ok:=kombax_payments.can_manage_federation_connect_r624(p_actor_id,p_subject_id);
    select d.nombre_publico,(select u.email from auth.users u where u.id=p_actor_id) into v_name,v_email
      from public.perfiles_kombax_directos d where d.id=p_subject_id and d.tipo='federacion' and d.estado='activo' and d.verificacion_estado='verificado';
  elsif p_subject_type='event_organizer' then
    v_ok:=kombax_payments.can_manage_event_organizer_connect_r625(p_actor_id,p_subject_id);
    select d.nombre_publico,(select u.email from auth.users u where u.id=p_actor_id) into v_name,v_email
      from public.perfiles_kombax_directos d where d.id=p_subject_id and d.tipo in('profesional','competidor') and d.estado='activo' and d.verificacion_estado='verificado';
  else
    raise exception 'CONNECTED_SUBJECT_INVALID';
  end if;
  if not coalesce(v_ok,false) then raise exception 'PAYMENTS_OWNER_REQUIRED'; end if;
  select * into v_account from kombax_payments.connected_accounts a where a.subject_type=p_subject_type and a.subject_id=p_subject_id;
  return jsonb_build_object('subject_type',p_subject_type,'subject_id',p_subject_id,'display_name',v_name,'email',v_email,
    'stripe_account_id',v_account.stripe_account_id,'status',coalesce(v_account.status,'not_configured'),
    'configuration_compatible',coalesce(v_account.configuration_compatible,true),'charge_model',coalesce(v_account.charge_model,'direct'));
end $$;

create or replace function public.app_stripe_connect_runtime_internal_v261(p_actor_id uuid,p_subject_type text,p_subject_id uuid,p_manage boolean default false)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_ok boolean:=false;v_row kombax_payments.connected_accounts;
begin
  if p_actor_id is null then raise exception 'ACTOR_REQUIRED'; end if;
  if p_subject_type='club' then
    v_ok:=exists(select 1 from public.miembros_club m where m.club_id=p_subject_id and m.perfil_id=p_actor_id and m.activo and m.rol in('direccion','secretaria','economia') and (not p_manage or m.rol='direccion'));
  elsif p_subject_type='showcase_provider' then
    v_ok:=kombax_payments.can_manage_provider(p_actor_id,p_subject_id);
  elsif p_subject_type='federation' then
    v_ok:=case when p_manage then kombax_payments.can_manage_federation_connect_r624(p_actor_id,p_subject_id) else kombax_payments.can_view_federation_connect_r624(p_actor_id,p_subject_id) end;
  elsif p_subject_type='event_organizer' then
    v_ok:=kombax_payments.can_manage_event_organizer_connect_r625(p_actor_id,p_subject_id);
  end if;
  if not coalesce(v_ok,false) then raise exception 'PAYMENTS_ACCESS_DENIED'; end if;
  select * into v_row from kombax_payments.connected_accounts a where a.subject_type=p_subject_type and a.subject_id=p_subject_id;
  return jsonb_build_object('stripe_account_id',v_row.stripe_account_id,'status',coalesce(v_row.status,'not_configured'),
    'configuration_compatible',coalesce(v_row.configuration_compatible,true));
end $$;

create or replace function public.app_stripe_connect_attach_internal_v259(p_actor_id uuid,p_subject_type text,p_subject_id uuid,p_stripe_account_id text)
returns void language plpgsql security definer set search_path='' as $$
declare v_ok boolean:=false;v_existing kombax_payments.connected_accounts;
begin
  if p_actor_id is null or coalesce(p_stripe_account_id,'') !~ '^acct_[A-Za-z0-9]+$' then raise exception 'CONNECTED_ACCOUNT_INVALID'; end if;
  if p_subject_type='club' then
    v_ok:=exists(select 1 from public.miembros_club m where m.club_id=p_subject_id and m.perfil_id=p_actor_id and m.activo and m.rol='direccion');
  elsif p_subject_type='showcase_provider' then
    v_ok:=kombax_payments.can_manage_provider(p_actor_id,p_subject_id);
  elsif p_subject_type='federation' then
    v_ok:=kombax_payments.can_manage_federation_connect_r624(p_actor_id,p_subject_id);
  elsif p_subject_type='event_organizer' then
    v_ok:=kombax_payments.can_manage_event_organizer_connect_r625(p_actor_id,p_subject_id);
  end if;
  if not coalesce(v_ok,false) then raise exception 'PAYMENTS_OWNER_REQUIRED'; end if;

  select * into v_existing from kombax_payments.connected_accounts a where a.subject_type=p_subject_type and a.subject_id=p_subject_id for update;
  if found then
    if v_existing.stripe_account_id<>p_stripe_account_id then raise exception 'CONNECTED_ACCOUNT_REASSIGNMENT_FORBIDDEN'; end if;
    update kombax_payments.connected_accounts set charge_model='direct',stripe_fees_payer='account',losses_responsibility='stripe',
      stripe_dashboard_type='full',configuration_compatible=true,updated_at=now() where id=v_existing.id;
    return;
  end if;

  insert into kombax_payments.connected_accounts(subject_type,subject_id,club_id,showcase_provider_id,federation_profile_id,event_organizer_profile_id,stripe_account_id,created_by,
    charge_model,stripe_fees_payer,losses_responsibility,stripe_dashboard_type,configuration_compatible)
  values(p_subject_type,p_subject_id,case when p_subject_type='club' then p_subject_id end,
    case when p_subject_type='showcase_provider' then p_subject_id end,case when p_subject_type='federation' then p_subject_id end,
    case when p_subject_type='event_organizer' then p_subject_id end,p_stripe_account_id,p_actor_id,'direct','account','stripe','full',true);
end $$;
commit;
