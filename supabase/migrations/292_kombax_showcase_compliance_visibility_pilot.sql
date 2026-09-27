-- Pilot security: a known product ID must not reveal another provider's draft compliance data.
create or replace function public.app_showcase_product_compliance_r630(p_product_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $function$
declare
  e public.kombax_showcase_elementos;
  p kombax_compliance.product_profiles;
  r kombax_compliance.product_category_rules;
  s kombax_marketplace.seller_applications;
  m public.kombax_showcase_marcas;
  v_open integer;
begin
  select * into e from public.kombax_showcase_elementos where id = p_product_id;
  if e.id is null then raise exception 'SHOWCASE_PRODUCT_NOT_FOUND'; end if;
  select * into m from public.kombax_showcase_marcas where id = e.marca_id;
  if not (
    (e.estado = 'publicado' and m.estado = 'publicada')
    or public.app_kombax_showcase_puede_gestionar_v045(e.marca_id)
    or public.app_kombax_es_platform_admin_v055()
  ) then
    raise exception 'SHOWCASE_PRODUCT_NOT_FOUND';
  end if;
  select * into p from kombax_compliance.product_profiles where product_id = e.id;
  if p.product_id is not null then
    select * into r from kombax_compliance.product_category_rules where category_code = p.category_code;
  end if;
  select * into s from kombax_marketplace.seller_applications where provider_id = e.marca_id;
  select count(*) into v_open from kombax_compliance.cases c
   where c.entity_type = 'product' and c.entity_id = e.id and c.status not in ('resolved', 'closed');
  return jsonb_build_object(
    'ok', true, 'product_id', e.id, 'listing_kind', e.listing_kind,
    'seller', jsonb_build_object(
      'provider_id', m.id, 'name', m.nombre, 'verified_identity', m.verificada,
      'trader_status', coalesce(s.professional_status, 'unknown'),
      'legal_name', s.legal_name, 'registered_address', s.registered_address,
      'country', coalesce(s.establishment_country, s.country),
      'support_email', s.support_email, 'support_phone', s.support_phone
    ),
    'product', case when p.product_id is null then null else jsonb_build_object(
      'category_code', p.category_code, 'category_label', r.label,
      'risk_tier', r.risk_tier, 'policy_status', r.policy_status,
      'manufacturer_name', p.manufacturer_name,
      'manufacturer_postal_address', p.manufacturer_postal_address,
      'manufacturer_email', p.manufacturer_email,
      'manufacturer_country', p.manufacturer_country,
      'eu_responsible_person_name', p.eu_responsible_person_name,
      'eu_responsible_person_postal_address', p.eu_responsible_person_postal_address,
      'eu_responsible_person_email', p.eu_responsible_person_email,
      'model_reference', p.model_reference,
      'country_of_origin', p.country_of_origin,
      'ce_applicability', p.ce_applicability,
      'ce_marking_confirmed', p.ce_marking_confirmed,
      'safety_warnings', p.safety_warnings,
      'safety_instructions', p.safety_instructions,
      'completeness_status', p.completeness_status,
      'moderation_state', p.moderation_state,
      'safety_gate_status', p.safety_gate_status
    ) end,
    'commerce_ready', kombax_compliance.product_compliance_ready_r630(e.id)
      and kombax_marketplace.seller_ready_r627(e.marca_id),
    'open_cases', v_open,
    'verified_seller_meaning',
      'KOMBAX ha verificado determinados datos de identidad o actividad del vendedor; no garantiza todos sus productos.'
  );
end
$function$;

revoke all on function public.app_showcase_product_compliance_r630(uuid) from public, anon;
grant execute on function public.app_showcase_product_compliance_r630(uuid) to authenticated;
