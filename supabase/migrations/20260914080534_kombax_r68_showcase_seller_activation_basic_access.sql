-- KOMBAX R68 · Seller activation is independent from Showcase Commerce rights.
-- Applied live on 2026-09-14. Keeps the existing RPC name for frontend compatibility.

create or replace function public.app_showcase_seller_center_r627(p_provider_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path to ''
as $function$
declare
  v_uid uuid := (select auth.uid());
  m public.kombax_showcase_marcas;
  s kombax_marketplace.seller_applications;
  v_base jsonb;
  v_policies jsonb;
  v_stripe jsonb;
  v_plan text;
  v_commerce_allowed boolean := false;
  v_seller_active boolean := false;
  v_activation_status text := 'not_started';
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;

  select * into m from public.kombax_showcase_marcas where id = p_provider_id;
  if m.id is null then raise exception 'SHOWCASE_PROVIDER_NOT_FOUND'; end if;
  if not kombax_payments.can_manage_provider(v_uid,p_provider_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;

  select * into s from kombax_marketplace.seller_applications where provider_id = p_provider_id;
  v_base := kombax_marketplace.base_verification_r627(p_provider_id);
  v_plan := kombax_commercial.seller_plan_r64('showcase_provider', p_provider_id);
  v_commerce_allowed := kombax_commercial.provider_commerce_allowed_r64(p_provider_id);

  select coalesce(jsonb_agg(jsonb_build_object(
    'code',p.policy_code,'version',p.version,'title',p.title,'body',p.body,
    'legal_review_status',p.legal_review_status,'required',p.required_for_seller,
    'accepted',exists(select 1 from kombax_marketplace.policy_acceptances a where a.provider_id=p_provider_id and a.policy_code=p.policy_code and a.policy_version=p.version and a.acceptance_scope='seller'),
    'accepted_at',(select max(a.accepted_at) from kombax_marketplace.policy_acceptances a where a.provider_id=p_provider_id and a.policy_code=p.policy_code and a.policy_version=p.version and a.acceptance_scope='seller')
  ) order by p.policy_code),'[]'::jsonb) into v_policies
  from kombax_marketplace.policy_documents p where p.status='active' and p.required_for_seller;

  select jsonb_build_object(
    'status',a.status,'details_submitted',a.details_submitted,'charges_enabled',a.charges_enabled,'payouts_enabled',a.payouts_enabled,
    'requirements_due',a.requirements_due,'requirements_pending_verification',a.requirements_pending_verification,'disabled_reason',a.disabled_reason,
    'charge_model',a.charge_model,'fees_payer',a.stripe_fees_payer,'losses_responsibility',a.losses_responsibility,'dashboard_type',a.stripe_dashboard_type
  ) into v_stripe
  from kombax_payments.connected_accounts a
  where a.subject_type='showcase_provider' and a.subject_id=p_provider_id
  order by a.updated_at desc limit 1;

  v_seller_active := kombax_marketplace.seller_ready_r627(p_provider_id);
  v_activation_status := case
    when v_seller_active then 'active'
    when s.id is null then 'not_started'
    when s.status in ('submitted','under_review') then 'verification_pending'
    when s.status='needs_information' then 'needs_information'
    when s.status='rejected' then 'rejected'
    when s.status='suspended' then 'suspended'
    when s.status='verified' then 'activation_required'
    else 'in_progress'
  end;

  return jsonb_build_object(
    'ok',true,
    'provider',jsonb_build_object('id',m.id,'name',m.nombre,'type',m.sujeto_tipo,'verified',m.verificada,'state',m.estado,'subject_type',case when m.sujeto_tipo='club' then 'club' else 'direct_profile' end,'subject_id',case when m.sujeto_tipo='club' then m.club_id else m.perfil_directo_id end),
    'base_verification',coalesce(v_base,'{}'::jsonb),
    'application',case when s.id is null then null else to_jsonb(s) end,
    'policies',coalesce(v_policies,'[]'::jsonb),
    'stripe',coalesce(v_stripe,jsonb_build_object('status','not_configured','charges_enabled',false,'payouts_enabled',false)),
    'checks',jsonb_build_object(
      'identity_verified',coalesce((v_base->>'verified')::boolean,false) and m.verificada and m.estado='publicada',
      'seller_verified',coalesce(s.status='verified',false),
      'policies_accepted',kombax_marketplace.seller_policies_ready_r627(p_provider_id),
      'stripe_ready',coalesce((v_stripe->>'charges_enabled')::boolean,false) and coalesce((v_stripe->>'payouts_enabled')::boolean,false) and coalesce(v_stripe->>'status','')='active',
      'selling_ready',v_seller_active
    ),
    'seller_account',jsonb_build_object(
      'activation_required',true,'activation_status',v_activation_status,'active',v_seller_active,
      'activation_definition','identity_verified + seller_verified + policies_accepted + stripe_ready'
    ),
    'commercial_access',jsonb_build_object(
      'seller_center_access',true,'catalog_management',true,'plan_code',v_plan,'commerce_allowed',v_commerce_allowed,
      'checkout_available',v_seller_active and v_commerce_allowed,
      'commerce_activation_required',coalesce(v_plan='club' and not v_commerce_allowed,false)
    )
  );
end
$function$;
