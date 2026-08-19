do $$ begin
  raise exception 'ROLLBACK_094_REQUIRES_MANUAL_REVIEW: canonical Member fields may contain user edits. Do not destructively drop them automatically; restore function definitions from build 20047 only after data export/reconciliation.';
end $$;
