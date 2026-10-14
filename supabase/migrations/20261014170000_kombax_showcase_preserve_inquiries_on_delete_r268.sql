-- KOMBAX R268: nunca eliminar consultas al retirar una ficha de Showcase.
-- Las FK históricas usan ON DELETE CASCADE; por ello el borrado del producto
-- debe convertirse en una retirada si existe cualquier consulta asociada.
-- Extensión mínima, idempotente, de la RPC de eliminación v067 ya operativa.
DO $migration$
DECLARE
  v_source text;
  v_current text := 'v_has_history:=exists(select 1 from kombax_payments.showcase_order_items where product_id=v_item.id) or exists(select 1 from kombax_reputation.product_reviews where product_id=v_item.id);';
  v_new text := 'v_has_history:=exists(select 1 from kombax_payments.showcase_order_items where product_id=v_item.id) or exists(select 1 from kombax_reputation.product_reviews where product_id=v_item.id) or exists(select 1 from public.kombax_showcase_inquiries_r58 where elemento_id=v_item.id);';
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_source
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname='app_kombax_showcase_mutate_v067'
    AND pg_get_function_identity_arguments(p.oid)='p_operation text, p_payload jsonb, p_request_id uuid';
  IF v_source IS NULL THEN RAISE EXCEPTION 'SHOWCASE_DELETE_RPC_NOT_FOUND'; END IF;
  IF position(v_new IN v_source)>0 THEN RETURN; END IF;
  IF position(v_current IN v_source)=0 THEN RAISE EXCEPTION 'SHOWCASE_DELETE_RPC_BODY_CHANGED_REVIEW_REQUIRED'; END IF;
  EXECUTE replace(v_source, v_current, v_new);
END
$migration$;
