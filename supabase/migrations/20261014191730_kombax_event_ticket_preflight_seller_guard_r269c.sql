-- R269c: el diagnostico debe indicar Stripe pendiente cuando el vendedor aun no esta configurado.
DO $patch$
DECLARE v_def text; v_old text; v_new text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='app_kombax_event_ticket_categories_preflight_r269';
 IF v_def IS NULL THEN RAISE EXCEPTION 'PREFLIGHT_FUNCTION_NOT_FOUND'; END IF;
 v_old := $old$  v_seller := kombax_payments.event_seller_r625(p_event_id);
  BEGIN v_seller_uuid := nullif(v_seller->>'subject_id','')::uuid; EXCEPTION WHEN invalid_text_representation THEN v_seller_uuid:=null; END;$old$;
 v_new := $new$  BEGIN
    v_seller := kombax_payments.event_seller_r625(p_event_id);
    v_seller_uuid := nullif(v_seller->>'subject_id','')::uuid;
  EXCEPTION WHEN OTHERS THEN
    v_seller_uuid := null;
  END;$new$;
 IF position('EXCEPTION WHEN OTHERS THEN' in v_def)>0 THEN RETURN; END IF;
 IF position(v_old in v_def)=0 THEN RAISE EXCEPTION 'PREFLIGHT_FUNCTION_BODY_CHANGED'; END IF;
 EXECUTE replace(v_def,v_old,v_new);
END $patch$;
