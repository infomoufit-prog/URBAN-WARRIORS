-- Rollback 069 bloqueado por seguridad.
-- Restaurar el comportamiento histórico volvería a conceder insignia a Miembros.
do $$ begin raise exception 'ROLLBACK_069_BLOCKED_BADGE_PRIVACY_MUST_BE_PRESERVED'; end $$;
