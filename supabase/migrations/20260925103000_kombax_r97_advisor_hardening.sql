-- R97 · Resolve new advisor findings. Private tables intentionally have no client policies.
alter function kombax_ai_ops.ai_monthly_amount_r97(text) set search_path='';
create index if not exists ai_credit_grants_actor_r97 on kombax_ai_ops.ai_credit_grants_r97(created_by);
create index if not exists ai_credit_ledger_grant_r97 on kombax_ai_ops.ai_credit_ledger_r97(grant_id);
create index if not exists ai_credit_ledger_turn_r97 on kombax_ai_ops.ai_credit_ledger_r97(turn_id);
create index if not exists ai_credit_reservations_tenant_r97 on kombax_ai_ops.ai_credit_reservations_r97(tenant_ref);
create index if not exists pilot_entities_actor_r97 on kombax_commercial.pilot_entities_r97(enrolled_by);
create index if not exists plan_benefits_actor_r97 on kombax_commercial.plan_benefits_r97(created_by);
create index if not exists plan_benefits_plan_r97 on kombax_commercial.plan_benefits_r97(plan_code);
create index if not exists trial_entities_actor_r97 on kombax_commercial.trial_entities_r97(created_by);
