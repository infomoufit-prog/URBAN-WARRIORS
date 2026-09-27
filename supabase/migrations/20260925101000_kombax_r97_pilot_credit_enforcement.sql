-- R97 · Pilot and future trial wallets are authoritative after transactional QA.
-- Non-enrolled tenants retain the previous assistance limits.
update kombax_commercial.runtime_config_r64
set value='true'::jsonb,updated_at=now()
where config_key='ai_credits_enforcement';
