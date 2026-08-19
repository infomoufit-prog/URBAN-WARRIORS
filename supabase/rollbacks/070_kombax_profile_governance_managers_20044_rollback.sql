-- Rollback 070 requiere migración de datos manual: eliminar multigestor puede bloquear organizaciones compartidas.
do $$ begin raise exception 'ROLLBACK_070_REQUIRES_MANUAL_PROFILE_GOVERNANCE_MIGRATION'; end $$;
