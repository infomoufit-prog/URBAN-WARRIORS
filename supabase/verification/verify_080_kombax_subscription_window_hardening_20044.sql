select
  strpos(pg_get_functiondef('public.app_kombax_reconcile_entitlements_v071(uuid,uuid)'::regprocedure),'1 microsecond')>0 as entitlement_window_hardened,
  strpos(pg_get_functiondef('public.app_kombax_subscription_mutate_v071(text,jsonb,uuid)'::regprocedure),'1 microsecond')>0 as subscription_window_hardened;
