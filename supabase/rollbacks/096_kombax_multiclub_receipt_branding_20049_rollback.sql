-- El rollback destructivo está bloqueado porque eliminaría snapshots financieros históricos.
do $$ begin
  raise exception 'ROLLBACK_096_BLOCKED_FINANCIAL_TRACEABILITY';
end $$;
