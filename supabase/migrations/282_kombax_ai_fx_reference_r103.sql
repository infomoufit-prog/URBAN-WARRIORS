-- R103 calibration: ECB reference 25 September 2026, 1 EUR = 1.1403 USD.
-- This estimate is admin-only and remains centrally adjustable.
begin;
update kombax_commercial.runtime_config_r64
set value='0.876963957',description='Estimated EUR per USD from ECB 2026-09-25; reconcile against OpenAI invoices'
where config_key='ai_eur_per_usd';
insert into kombax_commercial.runtime_config_r64(config_key,value,description)
values('ai_fx_reference_at','"2026-09-25"','Reference date for USD to EUR estimate')
on conflict(config_key) do update set value=excluded.value,description=excluded.description;
commit;
