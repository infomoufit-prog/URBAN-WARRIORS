-- Conservative R63 rollback: functions are removed, evidence/data tables and columns are intentionally retained.
begin;
drop function if exists public.app_kombax_commercial_purchase_eligibility_r63();
drop function if exists public.app_kombax_commercial_report_r63(text,uuid,text,text,uuid);
drop function if exists public.app_kombax_commercial_moderation_queue_r63(integer);
drop function if exists public.app_kombax_event_cancel_commercial_plan_r63(uuid,text,uuid);
-- Do not automatically restore the pre-R63 checkout gates: doing so would re-enable known minor purchases.
commit;
