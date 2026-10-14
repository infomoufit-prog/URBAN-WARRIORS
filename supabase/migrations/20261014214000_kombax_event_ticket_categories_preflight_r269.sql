-- R269: lectura autorizada de condiciones previas a la venta por categorías.
-- NO habilita checkout_enabled, no crea órdenes y no llama a Stripe.
CREATE OR REPLACE FUNCTION public.app_kombax_event_ticket_categories_preflight_r269(p_event_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_event public.kombax_eventos_publicos%ROWTYPE;
  v_org jsonb;
  v_seller jsonb;
  v_seller_uuid uuid;
  v_checks jsonb := '[]'::jsonb;
  v_categories integer;
  v_available integer;
  v_invalid integer;
  v_stripe_ok boolean := false;
  v_commercial_ok boolean := false;
  v_contracts_ok boolean := false;
  v_organizer_ok boolean := false;
  v_compliance_ok boolean := false;
BEGIN
  IF auth.uid() IS NULL OR coalesce(public.app_kombax_evento_puede_gestionar_v160(p_event_id),false) IS NOT TRUE THEN
    RAISE EXCEPTION 'EVENT_MANAGE_REQUIRED';
  END IF;
  SELECT * INTO v_event FROM public.kombax_eventos_publicos WHERE id=p_event_id;
  IF v_event.id IS NULL THEN RAISE EXCEPTION 'EVENT_NOT_FOUND';END IF;
  SELECT count(*), count(*) FILTER (WHERE is_active), count(*) FILTER (WHERE unit_price_minor < 50)
    INTO v_categories,v_available,v_invalid FROM public.kombax_event_ticket_categories_r265 WHERE event_id=p_event_id;
  v_checks := v_checks || jsonb_build_array(jsonb_build_object('key','categories_defined','ok',v_categories>0 AND v_available>0));
  v_checks := v_checks || jsonb_build_array(jsonb_build_object('key','paid_categories_only','ok',v_invalid=0));
  v_checks := v_checks || jsonb_build_array(jsonb_build_object('key','ticketing_config','ok',coalesce(v_event.ticketing_enabled,false) AND v_event.ticketing_mode='kombax' AND v_event.ticket_capacity>0));
  v_checks := v_checks || jsonb_build_array(jsonb_build_object('key','event_not_closed','ok',v_event.estado NOT IN ('cancelado','finalizado','borrador')));
  v_commercial_ok := coalesce(kombax_commercial.event_ticketing_active_r628(p_event_id),false);
  v_contracts_ok := coalesce(kombax_commercial.event_contracts_ready_r628(p_event_id),false);
  v_org := kombax_compliance.organizer_status_r630(p_event_id);
  v_organizer_ok := coalesce((v_org->>'verified')::boolean,false);
  v_compliance_ok := coalesce(kombax_compliance.event_compliance_ready_r630(p_event_id),false);
  v_checks := v_checks || jsonb_build_array(jsonb_build_object('key','commercial_ticketing','ok',v_commercial_ok));
  v_checks := v_checks || jsonb_build_array(jsonb_build_object('key','event_contracts','ok',v_contracts_ok));
  v_checks := v_checks || jsonb_build_array(jsonb_build_object('key','organizer_verified','ok',v_organizer_ok));
  v_checks := v_checks || jsonb_build_array(jsonb_build_object('key','compliance_ready','ok',v_compliance_ok));
  BEGIN
    v_seller := kombax_payments.event_seller_r625(p_event_id);
    v_seller_uuid := nullif(v_seller->>'subject_id','')::uuid;
  EXCEPTION WHEN OTHERS THEN
    v_seller_uuid := null;
  END;
  IF v_seller_uuid IS NOT NULL THEN
    SELECT EXISTS (SELECT 1 FROM kombax_payments.connected_accounts a
      WHERE a.subject_type=v_seller->>'subject_type' AND a.subject_id=v_seller_uuid
      AND a.status='active' AND a.charges_enabled=true AND a.payouts_enabled=true
      AND a.configuration_compatible=true AND a.charge_model='direct') INTO v_stripe_ok;
  END IF;
  v_checks := v_checks || jsonb_build_array(jsonb_build_object('key','seller_stripe_connect','ok',v_stripe_ok));
  RETURN jsonb_build_object(
    'event_id',p_event_id,'categories_defined',v_categories,'categories_active',v_available,
    'preconditions_pass', NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_checks) AS x(item) WHERE (x.item->>'ok')::boolean IS DISTINCT FROM true),
    'real_payment_tested',false,
    'message','Diagnóstico de preparación, no autorización de venta. Las categorías continúan deshabilitadas hasta activación y prueba E2E autorizada.',
    'checks',v_checks);
END $function$;
REVOKE ALL ON FUNCTION public.app_kombax_event_ticket_categories_preflight_r269(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.app_kombax_event_ticket_categories_preflight_r269(uuid) TO authenticated;
