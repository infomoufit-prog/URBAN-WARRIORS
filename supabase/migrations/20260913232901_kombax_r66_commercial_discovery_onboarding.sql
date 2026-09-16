-- KOMBAX 20.117 R66 · Commercial discovery / onboarding continuity
-- Keeps account creation free and separates identity verification, plan intent and Billing.
-- No SaaS Billing charge or frontend deployment is performed by this migration.
begin;

-- ---------------------------------------------------------------------------
-- 1) Marca / Federación applications carry an explicit commercial plan intent.
--    Legacy already-verified applications without a plan remain valid; the guard
--    applies when a new application is submitted/reviewed or when state changes.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_direct_commercial_plan_application_guard_r66()
returns trigger
language plpgsql
security definer
set search_path=public,auth,kombax_commercial
as $$
declare
  v_plan text:=lower(btrim(coalesce(new.datos_verificacion->>'plan_codigo','')));
  v_cycle text:=lower(btrim(coalesce(new.datos_verificacion->>'billing_cycle','monthly')));
  v_required boolean:=false;
begin
  if new.tipo not in('marca','federacion') then return new; end if;

  if new.tipo='marca' and v_plan<>'' and v_plan not in('brand_start','brand_growth','brand_enterprise') then
    raise exception 'KOMBAX_BRAND_PLAN_INVALID';
  end if;
  if new.tipo='federacion' and v_plan<>'' and v_plan not in('federation','federation_partner') then
    raise exception 'KOMBAX_FEDERATION_PLAN_INVALID';
  end if;
  if v_cycle not in('monthly','annual') then raise exception 'KOMBAX_COMMERCIAL_BILLING_CYCLE_INVALID'; end if;

  v_required:=new.estado in('submitted','under_review')
    or (new.estado in('verified','limited') and (tg_op='INSERT' or old.estado is distinct from new.estado));
  if v_required and v_plan='' then raise exception 'KOMBAX_COMMERCIAL_PLAN_REQUIRED'; end if;

  if v_plan<>'' then
    new.datos_verificacion:=jsonb_set(coalesce(new.datos_verificacion,'{}'::jsonb),'{plan_codigo}',to_jsonb(v_plan),true);
    new.datos_verificacion:=jsonb_set(new.datos_verificacion,'{billing_cycle}',to_jsonb(v_cycle),true);
  end if;
  return new;
end $$;
revoke all on function public.app_kombax_direct_commercial_plan_application_guard_r66() from public,anon,authenticated;

drop trigger if exists trg_kombax_direct_commercial_plan_application_guard_r66 on public.kombax_solicitudes_alta;
create trigger trg_kombax_direct_commercial_plan_application_guard_r66
before insert or update of datos_verificacion,estado on public.kombax_solicitudes_alta
for each row execute function public.app_kombax_direct_commercial_plan_application_guard_r66();

-- On verification, persist the plan selected before onboarding as a separate,
-- auditable commercial request. Verification never activates Billing.
create or replace function public.app_kombax_direct_commercial_plan_request_after_verify_r66()
returns trigger
language plpgsql
security definer
set search_path=public,auth,kombax_commercial
as $$
declare
  v_plan text:=lower(btrim(coalesce(new.datos_verificacion->>'plan_codigo','')));
  v_cycle text:=lower(btrim(coalesce(new.datos_verificacion->>'billing_cycle','monthly')));
  v_founder_open boolean:=false;
  v_valid boolean:=false;
begin
  if new.tipo not in('marca','federacion') or new.estado<>'verified' or old.estado='verified' or new.perfil_directo_id is null then return new; end if;
  v_valid:=(new.tipo='marca' and v_plan in('brand_start','brand_growth','brand_enterprise'))
    or (new.tipo='federacion' and v_plan in('federation','federation_partner'));
  if not v_valid then return new; end if;

  select coalesce((value#>>'{}')::boolean,false) into v_founder_open
  from kombax_commercial.runtime_config_r64 where config_key='founder_sales_open';

  insert into kombax_commercial.plan_requests_r64(
    subject_type,subject_id,requested_plan_code,billing_cycle,founder_requested,request_id,requested_by,detail
  )
  select 'direct_profile',new.perfil_directo_id,v_plan,v_cycle,coalesce(v_founder_open,false),gen_random_uuid(),new.perfil_id,
    jsonb_build_object(
      'source','direct_profile_application',
      'application_id',new.id,
      'profile_type',new.tipo,
      'billing_activation_performed',false
    )
  where not exists(
    select 1 from kombax_commercial.plan_requests_r64 r
    where r.subject_type='direct_profile' and r.subject_id=new.perfil_directo_id
      and coalesce(r.detail->>'application_id','')=new.id::text
  );

  insert into kombax_commercial.organization_terms_r64(
    subject_type,subject_id,plan_code,billing_cycle,founder_locked,founder_continuous_since,updated_at
  ) values('direct_profile',new.perfil_directo_id,v_plan,v_cycle,false,null,now())
  on conflict(subject_type,subject_id) do update set
    plan_code=excluded.plan_code,billing_cycle=excluded.billing_cycle,updated_at=now();
  return new;
end $$;
revoke all on function public.app_kombax_direct_commercial_plan_request_after_verify_r66() from public,anon,authenticated;

drop trigger if exists trg_kombax_direct_commercial_plan_request_after_verify_r66 on public.kombax_solicitudes_alta;
create trigger trg_kombax_direct_commercial_plan_request_after_verify_r66
after update of estado on public.kombax_solicitudes_alta
for each row execute function public.app_kombax_direct_commercial_plan_request_after_verify_r66();

-- ---------------------------------------------------------------------------
-- 2) Seller Center exposes the managed subject identifier to its own manager.
--    This lets Showcase route the user to the exact plan context instead of a
--    generic hash. Authorization remains can_manage_provider().
-- ---------------------------------------------------------------------------
create or replace function public.app_showcase_seller_center_r627(p_provider_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=(select auth.uid());m public.kombax_showcase_marcas;s kombax_marketplace.seller_applications;v_base jsonb;v_policies jsonb;v_stripe jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into m from public.kombax_showcase_marcas where id=p_provider_id;
  if m.id is null then raise exception 'SHOWCASE_PROVIDER_NOT_FOUND'; end if;
  if not kombax_payments.can_manage_provider(v_uid,p_provider_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
  select * into s from kombax_marketplace.seller_applications where provider_id=p_provider_id;
  v_base:=kombax_marketplace.base_verification_r627(p_provider_id);
  select coalesce(jsonb_agg(jsonb_build_object(
    'code',p.policy_code,'version',p.version,'title',p.title,'body',p.body,'legal_review_status',p.legal_review_status,
    'required',p.required_for_seller,'accepted',exists(select 1 from kombax_marketplace.policy_acceptances a where a.provider_id=p_provider_id and a.policy_code=p.policy_code and a.policy_version=p.version and a.acceptance_scope='seller'),
    'accepted_at',(select max(a.accepted_at) from kombax_marketplace.policy_acceptances a where a.provider_id=p_provider_id and a.policy_code=p.policy_code and a.policy_version=p.version and a.acceptance_scope='seller')
  ) order by p.policy_code),'[]'::jsonb) into v_policies from kombax_marketplace.policy_documents p where p.status='active' and p.required_for_seller;
  select jsonb_build_object('status',a.status,'details_submitted',a.details_submitted,'charges_enabled',a.charges_enabled,'payouts_enabled',a.payouts_enabled,'requirements_due',a.requirements_due,'requirements_pending_verification',a.requirements_pending_verification,'disabled_reason',a.disabled_reason,'charge_model',a.charge_model,'fees_payer',a.stripe_fees_payer,'losses_responsibility',a.losses_responsibility,'dashboard_type',a.stripe_dashboard_type) into v_stripe
  from kombax_payments.connected_accounts a where a.subject_type='showcase_provider' and a.subject_id=p_provider_id order by a.updated_at desc limit 1;
  return jsonb_build_object(
    'ok',true,
    'provider',jsonb_build_object(
      'id',m.id,'name',m.nombre,'type',m.sujeto_tipo,'verified',m.verificada,'state',m.estado,
      'subject_type',case when m.sujeto_tipo='club' then 'club' else 'direct_profile' end,
      'subject_id',case when m.sujeto_tipo='club' then m.club_id else m.perfil_directo_id end
    ),
    'base_verification',coalesce(v_base,'{}'::jsonb),
    'application',case when s.id is null then null else to_jsonb(s) end,
    'policies',coalesce(v_policies,'[]'::jsonb),
    'stripe',coalesce(v_stripe,jsonb_build_object('status','not_configured','charges_enabled',false,'payouts_enabled',false)),
    'checks',jsonb_build_object(
      'identity_verified',coalesce((v_base->>'verified')::boolean,false) and m.verificada and m.estado='publicada',
      'seller_verified',coalesce(s.status='verified',false),
      'policies_accepted',kombax_marketplace.seller_policies_ready_r627(p_provider_id),
      'stripe_ready',coalesce((v_stripe->>'charges_enabled')::boolean,false) and coalesce((v_stripe->>'payouts_enabled')::boolean,false) and coalesce(v_stripe->>'status','')='active',
      'selling_ready',kombax_marketplace.seller_ready_r627(p_provider_id)
    )
  );
end $$;
revoke all on function public.app_showcase_seller_center_r627(uuid) from public,anon;
grant execute on function public.app_showcase_seller_center_r627(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3) Brand Growth/Enterprise (and Brand Start when using punctual publication)
--    can appear as Event organizer candidates. The entitlement/capability check
--    remains authoritative; this only fixes discovery of an eligible identity.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_eventos_mis_organizadores_v160()
returns table(social_profile_id uuid, sujeto_tipo text, sujeto_id uuid, perfil_tipo text, nombre_publico text, slug text, logo_url text, verificado boolean, puede_organizar boolean, motivo text)
language sql
stable security definer
set search_path=public,auth,kombax_commercial
as $$
  select sp.id,
    case when sp.sujeto_tipo='club' then 'club' else 'perfil_directo' end,
    case when sp.sujeto_tipo='club' then sp.club_id else sp.perfil_directo_id end,
    public.app_kombax_social_tipo_v051(sp.id),
    sp.nombre_publico,sp.slug,public.app_kombax_social_avatar_url_v063(sp.id),sp.verificado,
    public.app_kombax_eventos_sujeto_puede_organizar_v160(
      case when sp.sujeto_tipo='club' then 'club' else 'perfil_directo' end,
      case when sp.sujeto_tipo='club' then sp.club_id else sp.perfil_directo_id end
    ),
    case
      when sp.sujeto_tipo='club' and not public.app_kombax_eventos_sujeto_puede_organizar_v160('club',sp.club_id)
        then 'Revisa Club, Premium o Enterprise y las activaciones de Events disponibles'
      when sp.sujeto_tipo='perfil_directo' and public.app_kombax_social_tipo_v051(sp.id)='marca'
        and not public.app_kombax_eventos_sujeto_puede_organizar_v160('perfil_directo',sp.perfil_directo_id)
        then 'Revisa Brand Start, Growth o Enterprise y las activaciones de Events disponibles'
      when sp.sujeto_tipo='perfil_directo' and public.app_kombax_social_tipo_v051(sp.id)='federacion'
        and not public.app_kombax_eventos_sujeto_puede_organizar_v160('perfil_directo',sp.perfil_directo_id)
        then 'Revisa Federation y sus capacidades de Events'
      when sp.sujeto_tipo='perfil_directo' and public.app_kombax_social_tipo_v051(sp.id)='profesional'
        and not public.app_kombax_eventos_sujeto_puede_organizar_v160('perfil_directo',sp.perfil_directo_id)
        then 'Disponible con Profesional Pro'
      when sp.sujeto_tipo='perfil_directo' and public.app_kombax_social_tipo_v051(sp.id)='competidor'
        and not public.app_kombax_eventos_sujeto_puede_organizar_v160('perfil_directo',sp.perfil_directo_id)
        then 'Disponible para Competidor Pro cuando se active'
      else ''
    end
  from public.kombax_social_perfiles sp
  left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
  where auth.uid() is not null and sp.visible and sp.estado='activo' and sp.sujeto_tipo in('club','perfil_directo')
    and (
      (sp.sujeto_tipo='club' and exists(
        select 1 from public.miembros_club m
        where m.club_id=sp.club_id and m.perfil_id=auth.uid() and m.activo
          and (m.rol in('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false))
      ))
      or
      (sp.sujeto_tipo='perfil_directo' and d.perfil_id=auth.uid()
        and d.tipo in('federacion','marca','profesional','competidor') and d.estado='activo')
    )
  order by public.app_kombax_eventos_sujeto_puede_organizar_v160(
    case when sp.sujeto_tipo='club' then 'club' else 'perfil_directo' end,
    case when sp.sujeto_tipo='club' then sp.club_id else sp.perfil_directo_id end
  ) desc,sp.nombre_publico;
$$;
revoke all on function public.app_kombax_eventos_mis_organizadores_v160() from public,anon;
grant execute on function public.app_kombax_eventos_mis_organizadores_v160() to authenticated;

commit;
