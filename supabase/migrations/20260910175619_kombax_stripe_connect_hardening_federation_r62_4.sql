-- KOMBAX R62.4 · Stripe Connect hardening + Federation.
-- Incremental sobre R62. No altera el modelo económico: Direct Charges, fees de Stripe
-- cobradas a la cuenta conectada y cero application fees para KOMBAX.

begin;

alter table kombax_payments.connected_accounts
  add column if not exists federation_profile_id uuid references public.perfiles_kombax_directos(id) on delete restrict,
  add column if not exists requirements_pending_verification jsonb not null default '[]'::jsonb,
  add column if not exists stripe_api_version text,
  add column if not exists last_synced_at timestamptz;

alter table kombax_payments.connected_accounts drop constraint if exists connected_accounts_subject_type_check;
alter table kombax_payments.connected_accounts
  add constraint connected_accounts_subject_type_check check(subject_type in('club','showcase_provider','federation'));

alter table kombax_payments.connected_accounts drop constraint if exists connected_accounts_check;
alter table kombax_payments.connected_accounts
  add constraint connected_accounts_check check(
    (subject_type='club' and club_id=subject_id and showcase_provider_id is null and federation_profile_id is null)
    or (subject_type='showcase_provider' and showcase_provider_id=subject_id and club_id is null and federation_profile_id is null)
    or (subject_type='federation' and federation_profile_id=subject_id and club_id is null and showcase_provider_id is null)
  );

create index if not exists idx_connected_accounts_federation_r624
  on kombax_payments.connected_accounts(federation_profile_id) where federation_profile_id is not null;

-- Federación: consultar estado financiero es distinto de poder sustituir/configurar
-- la cuenta. Tesorería puede consultar; onboarding queda reservado a owner/admin,
-- Presidencia y plataforma.
create or replace function kombax_payments.can_view_federation_connect_r624(p_actor uuid,p_federation uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select p_actor is not null and exists(
    select 1 from public.perfiles_kombax_directos d
    where d.id=p_federation and d.tipo='federacion' and d.estado='activo' and d.verificacion_estado='verificado'
      and (
        d.perfil_id=p_actor
        or exists(select 1 from public.kombax_perfil_gestores g where g.perfil_directo_id=d.id and g.perfil_id=p_actor and g.estado='activo')
        or exists(
          select 1 from public.kombax_federation_team_v200 t
          join public.kombax_federation_role_capabilities_v200 rc on rc.role_code=t.role_code
          where t.federation_profile_id=d.id and t.perfil_id=p_actor and t.status='active' and rc.capability_key='federation.team.finance'
        )
        or exists(select 1 from public.kombax_platform_admins pa where pa.perfil_id=p_actor and pa.activo)
      )
  );
$$;

create or replace function kombax_payments.can_manage_federation_connect_r624(p_actor uuid,p_federation uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select p_actor is not null and exists(
    select 1 from public.perfiles_kombax_directos d
    where d.id=p_federation and d.tipo='federacion' and d.estado='activo' and d.verificacion_estado='verificado'
      and (
        d.perfil_id=p_actor
        or exists(select 1 from public.kombax_perfil_gestores g where g.perfil_directo_id=d.id and g.perfil_id=p_actor and g.estado='activo' and g.rol in('owner','admin'))
        or exists(select 1 from public.kombax_federation_team_v200 t where t.federation_profile_id=d.id and t.perfil_id=p_actor and t.status='active' and t.role_code='presidencia')
        or exists(select 1 from public.kombax_platform_admins pa where pa.perfil_id=p_actor and pa.activo)
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
    select m.nombre,null into v_name,v_email from public.kombax_showcase_marcas m where m.id=p_subject_id;
  elsif p_subject_type='federation' then
    v_ok:=kombax_payments.can_manage_federation_connect_r624(p_actor_id,p_subject_id);
    select d.nombre_publico,(select u.email from auth.users u where u.id=p_actor_id) into v_name,v_email
      from public.perfiles_kombax_directos d where d.id=p_subject_id and d.tipo='federacion' and d.estado='activo' and d.verificacion_estado='verificado';
  else
    raise exception 'CONNECTED_SUBJECT_INVALID';
  end if;
  if not coalesce(v_ok,false) then raise exception 'PAYMENTS_OWNER_REQUIRED'; end if;
  select * into v_account from kombax_payments.connected_accounts a where a.subject_type=p_subject_type and a.subject_id=p_subject_id;
  return jsonb_build_object('subject_type',p_subject_type,'subject_id',p_subject_id,'display_name',v_name,'email',v_email,
    'stripe_account_id',v_account.stripe_account_id,'status',coalesce(v_account.status,'not_configured'),
    'configuration_compatible',coalesce(v_account.configuration_compatible,true),'charge_model',coalesce(v_account.charge_model,'direct'));
end $$;

-- Runtime sólo devuelve acct_ al backend después de autorizar al actor. El frontend
-- nunca decide qué cuenta Stripe debe cobrar.
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
  end if;
  if not coalesce(v_ok,false) then raise exception 'PAYMENTS_OWNER_REQUIRED'; end if;

  select * into v_existing from kombax_payments.connected_accounts a where a.subject_type=p_subject_type and a.subject_id=p_subject_id for update;
  if found then
    if v_existing.stripe_account_id<>p_stripe_account_id then raise exception 'CONNECTED_ACCOUNT_REASSIGNMENT_FORBIDDEN'; end if;
    update kombax_payments.connected_accounts set charge_model='direct',stripe_fees_payer='account',losses_responsibility='stripe',
      stripe_dashboard_type='full',configuration_compatible=true,updated_at=now() where id=v_existing.id;
    return;
  end if;

  insert into kombax_payments.connected_accounts(subject_type,subject_id,club_id,showcase_provider_id,federation_profile_id,stripe_account_id,created_by,
    charge_model,stripe_fees_payer,losses_responsibility,stripe_dashboard_type,configuration_compatible)
  values(p_subject_type,p_subject_id,case when p_subject_type='club' then p_subject_id end,
    case when p_subject_type='showcase_provider' then p_subject_id end,case when p_subject_type='federation' then p_subject_id end,
    p_stripe_account_id,p_actor_id,'direct','account','stripe','full',true);
end $$;

create or replace function public.app_stripe_connect_sync_internal_v261(
  p_stripe_account_id text,p_details_submitted boolean,p_charges_enabled boolean,p_payouts_enabled boolean,
  p_requirements_due jsonb,p_requirements_eventually_due jsonb,p_requirements_pending_verification jsonb,
  p_disabled_reason text,p_api_version text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_row kombax_payments.connected_accounts;v_due jsonb:=coalesce(p_requirements_due,'[]'::jsonb);v_pending jsonb:=coalesce(p_requirements_pending_verification,'[]'::jsonb);
begin
  if coalesce(p_stripe_account_id,'') !~ '^acct_[A-Za-z0-9]+$' then raise exception 'CONNECTED_ACCOUNT_INVALID'; end if;
  update kombax_payments.connected_accounts set
    details_submitted=coalesce(p_details_submitted,false),charges_enabled=coalesce(p_charges_enabled,false),payouts_enabled=coalesce(p_payouts_enabled,false),
    requirements_due=v_due,requirements_eventually_due=coalesce(p_requirements_eventually_due,'[]'::jsonb),requirements_pending_verification=v_pending,
    disabled_reason=nullif(left(coalesce(p_disabled_reason,''),500),''),stripe_api_version=nullif(left(coalesce(p_api_version,''),80),''),last_synced_at=now(),
    status=case
      when coalesce(p_charges_enabled,false) and coalesce(p_payouts_enabled,false) then 'active'
      when nullif(coalesce(p_disabled_reason,''),'') is not null then 'restricted'
      when jsonb_array_length(v_due)>0 then 'action_required'
      when jsonb_array_length(v_pending)>0 or coalesce(p_details_submitted,false) then 'verification_pending'
      else 'pending' end,
    updated_at=now()
  where stripe_account_id=p_stripe_account_id returning * into v_row;
  if not found then raise exception 'CONNECTED_ACCOUNT_NOT_ATTACHED'; end if;
  return jsonb_build_object('status',v_row.status,'charges_enabled',v_row.charges_enabled,'payouts_enabled',v_row.payouts_enabled,'last_synced_at',v_row.last_synced_at);
end $$;

-- R62.4 corrige el reintento de checkout: si el request_id ya reservó un intento pero
-- la sesión aún no quedó adjunta, devuelve de nuevo el contexto server-side completo.
create or replace function public.app_stripe_checkout_prepare_internal_v259(p_actor_id uuid,p_kind text,p_reference_id uuid,p_quantity integer,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_attempt kombax_payments.payment_attempts;v_account kombax_payments.connected_accounts;v_fee public.cuotas;v_item public.kombax_showcase_elementos;v_provider public.kombax_showcase_marcas;v_order kombax_payments.showcase_orders;v_amount int;v_platform int;v_qty int:=greatest(1,least(coalesce(p_quantity,1),100));v_name text;v_seller text;
begin
  select * into v_attempt from kombax_payments.payment_attempts where actor_user_id=p_actor_id and request_id=p_request_id;
  if found then
    if v_attempt.kind<>p_kind
      or (p_kind='club_fee' and v_attempt.cuota_id is distinct from p_reference_id)
      or (p_kind='showcase_order' and nullif(v_attempt.metadata->>'product_id','')::uuid is distinct from p_reference_id) then
      raise exception 'CHECKOUT_REQUEST_ID_REUSED';
    end if;
    select * into strict v_account from kombax_payments.connected_accounts where id=v_attempt.connected_account_id;
    if v_attempt.cuota_id is not null then
      select q.concepto into v_name from public.cuotas q where q.id=v_attempt.cuota_id;
    elsif v_attempt.order_id is not null then
      select o.seller_name,i.product_name into v_seller,v_name from kombax_payments.showcase_orders o
      left join kombax_payments.showcase_order_items i on i.order_id=o.id where o.id=v_attempt.order_id limit 1;
    end if;
    return jsonb_build_object('attempt_id',v_attempt.id,'order_id',v_attempt.order_id,'kind',v_attempt.kind,'status',v_attempt.status,
      'stripe_checkout_session_id',v_attempt.stripe_checkout_session_id,'stripe_account_id',v_account.stripe_account_id,
      'amount_minor',v_attempt.amount_minor,'platform_fee_minor',v_attempt.platform_fee_minor,'currency',lower(v_attempt.currency),
      'name',coalesce(v_name,'Pago KOMBAX'),'seller_name',v_seller);
  end if;
  if p_kind='club_fee' then
    if not kombax_payments.can_pay_fee(p_actor_id,p_reference_id) then raise exception 'FEE_PAYMENT_DENIED'; end if;
    select * into strict v_fee from public.cuotas where id=p_reference_id for update;
    if v_fee.estado in('pagada','reembolsada','cancelada','anulada','exenta') then raise exception 'FEE_NOT_PAYABLE'; end if;
    select * into strict v_account from kombax_payments.connected_accounts where subject_type='club' and subject_id=v_fee.club_id and status='active' and charges_enabled and payouts_enabled and configuration_compatible and charge_model='direct';
    v_amount:=round(v_fee.importe*100)::int;v_platform:=kombax_payments.resolve_fee_minor('club_fee',v_amount,'club',v_fee.club_id);
    insert into kombax_payments.payment_attempts(request_id,kind,actor_user_id,connected_account_id,club_id,cuota_id,amount_minor,platform_fee_minor,currency,metadata)
    values(p_request_id,p_kind,p_actor_id,v_account.id,v_fee.club_id,v_fee.id,v_amount,v_platform,'EUR',jsonb_build_object('concept',v_fee.concepto)) returning * into v_attempt;
    update public.cuotas set estado='procesando',metodo_pago='stripe_checkout',actualizado_en=now() where id=v_fee.id;
    return jsonb_build_object('attempt_id',v_attempt.id,'kind',p_kind,'amount_minor',v_amount,'platform_fee_minor',v_platform,'currency','eur','name',v_fee.concepto,'stripe_account_id',v_account.stripe_account_id);
  elsif p_kind='showcase_order' then
    select * into strict v_item from public.kombax_showcase_elementos where id=p_reference_id and estado='publicado' and commerce_enabled for update;
    if v_item.precio_venta is null or v_item.precio_venta<=0 or (v_item.stock is not null and v_item.stock<v_qty) then raise exception 'PRODUCT_NOT_AVAILABLE'; end if;
    select * into strict v_provider from public.kombax_showcase_marcas where id=v_item.marca_id and estado='publicada';
    select * into strict v_account from kombax_payments.connected_accounts where subject_type='showcase_provider' and subject_id=v_provider.id and status='active' and charges_enabled and payouts_enabled and configuration_compatible and charge_model='direct';
    v_amount:=round(v_item.precio_venta*100)::int*v_qty;v_platform:=kombax_payments.resolve_fee_minor('showcase',v_amount,'showcase_provider',v_provider.id);
    insert into kombax_payments.showcase_orders(order_number,buyer_user_id,seller_provider_id,seller_name,amount_total_minor,currency)
    values('KX-'||to_char(clock_timestamp(),'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),p_actor_id,v_provider.id,v_provider.nombre,v_amount,'EUR') returning * into v_order;
    insert into kombax_payments.showcase_order_items(order_id,product_id,product_name,quantity,unit_amount_minor) values(v_order.id,v_item.id,v_item.nombre,v_qty,round(v_item.precio_venta*100)::int);
    insert into kombax_payments.showcase_order_history(order_id,to_status,actor_user_id,source) values(v_order.id,'received',p_actor_id,'buyer');
    insert into kombax_payments.payment_attempts(request_id,kind,actor_user_id,connected_account_id,order_id,amount_minor,platform_fee_minor,currency,metadata)
    values(p_request_id,p_kind,p_actor_id,v_account.id,v_order.id,v_amount,v_platform,'EUR',jsonb_build_object('product_id',v_item.id,'seller',v_provider.nombre)) returning * into v_attempt;
    return jsonb_build_object('attempt_id',v_attempt.id,'order_id',v_order.id,'kind',p_kind,'amount_minor',v_amount,'platform_fee_minor',v_platform,'currency','eur','name',v_item.nombre,'seller_name',v_provider.nombre,'stripe_account_id',v_account.stripe_account_id);
  else raise exception 'CHECKOUT_KIND_INVALID'; end if;
end $$;

revoke all on function kombax_payments.can_view_federation_connect_r624(uuid,uuid),kombax_payments.can_manage_federation_connect_r624(uuid,uuid) from public,anon,authenticated;
grant execute on function kombax_payments.can_view_federation_connect_r624(uuid,uuid),kombax_payments.can_manage_federation_connect_r624(uuid,uuid) to service_role;

revoke all on function public.app_stripe_connect_status_v259(text,uuid) from public,anon;
grant execute on function public.app_stripe_connect_status_v259(text,uuid) to authenticated;

revoke all on function public.app_stripe_connect_prepare_internal_v259(uuid,text,uuid),public.app_stripe_connect_attach_internal_v259(uuid,text,uuid,text),public.app_stripe_connect_runtime_internal_v261(uuid,text,uuid,boolean),public.app_stripe_connect_sync_internal_v261(text,boolean,boolean,boolean,jsonb,jsonb,jsonb,text,text),public.app_stripe_checkout_prepare_internal_v259(uuid,text,uuid,integer,uuid) from public,anon,authenticated;
grant execute on function public.app_stripe_connect_prepare_internal_v259(uuid,text,uuid),public.app_stripe_connect_attach_internal_v259(uuid,text,uuid,text),public.app_stripe_connect_runtime_internal_v261(uuid,text,uuid,boolean),public.app_stripe_connect_sync_internal_v261(text,boolean,boolean,boolean,jsonb,jsonb,jsonb,text,text),public.app_stripe_checkout_prepare_internal_v259(uuid,text,uuid,integer,uuid) to service_role;

notify pgrst,'reload schema';
commit;
