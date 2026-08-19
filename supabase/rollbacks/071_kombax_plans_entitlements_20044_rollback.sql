-- Rollback 071 requiere preservar estados comerciales y entitlements; no se automatiza para evitar reactivar privilegios antiguos.
do $$ begin raise exception 'ROLLBACK_071_REQUIRES_MANUAL_ENTITLEMENT_RECONCILIATION'; end $$;
