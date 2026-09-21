-- Cover assistance-ledger foreign keys reported by the Supabase performance advisor.
create index if not exists assistance_periods_plan_idx on kombax_ai_ops.assistance_periods(plan);
create index if not exists assistance_cases_period_idx on kombax_ai_ops.assistance_cases(period_id);
create index if not exists assistance_tenant_settings_plan_idx on kombax_ai_ops.assistance_tenant_settings(plan_override) where plan_override is not null;
create index if not exists migration_allowance_plan_idx on kombax_ai_ops.migration_allowance_cases(plan);
