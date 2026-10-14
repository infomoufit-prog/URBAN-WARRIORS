-- R269b: normaliza el acceso a cada elemento JSON durante la comprobación.
DO $patch$
DECLARE v_def text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='public' AND p.proname='app_kombax_event_ticket_categories_preflight_r269';
 IF v_def IS NULL THEN RAISE EXCEPTION 'PREFLIGHT_FUNCTION_NOT_FOUND'; END IF;
 IF position('AS x(item) WHERE (x.item->>' IN v_def)>0 THEN RETURN; END IF;
 IF position('AS checks WHERE (checks->>' IN v_def)=0 THEN RAISE EXCEPTION 'PREFLIGHT_FUNCTION_CHANGED'; END IF;
 EXECUTE replace(v_def,'AS checks WHERE (checks->>', 'AS x(item) WHERE (x.item->>');
END $patch$;
