-- KOMBAX R268b: proteger además consultas Social, auditoría de inventario,
-- métricas de comercio y expedientes de cumplimiento vinculados a la ficha.
DO $migration$
DECLARE
  v_source text;
  v_existing text := 'or exists(select 1 from public.kombax_showcase_inquiries_r58 where elemento_id=v_item.id);';
  v_new text := 'or exists(select 1 from public.kombax_showcase_inquiries_r58 where elemento_id=v_item.id) or exists(select 1 from public.kombax_social_contactos where showcase_elemento_id=v_item.id) or exists(select 1 from kombax_payments.showcase_stock_movements_r65 where product_id=v_item.id) or exists(select 1 from kombax_payments.commerce_analytics_events_r65 where product_id=v_item.id) or exists(select 1 from kombax_compliance.product_reports where product_id=v_item.id);';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_source
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='app_kombax_showcase_mutate_v067';
  IF v_source IS NULL THEN RAISE EXCEPTION 'SHOWCASE_DELETE_RPC_NOT_FOUND'; END IF;
  IF position(v_new IN v_source)>0 THEN RETURN; END IF;
  IF position(v_existing IN v_source)=0 THEN RAISE EXCEPTION 'SHOWCASE_DELETE_GUARD_NOT_EXPECTED'; END IF;
  EXECUTE replace(v_source, v_existing, v_new);
END
$migration$;
