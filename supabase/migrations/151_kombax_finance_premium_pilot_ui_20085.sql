-- KOMBAX RC13 build 20085 · Pilot UI rollout only
-- Enables read/dashboard/report UX for the current pilot/QA clubs.
-- Real recurrence, QA approval and pilot-live remain explicitly CLOSED.
begin;

update public.config_club cc
set valor='true'::jsonb, actualizado_en=now()
from public.clubes c
where c.id=cc.club_id
  and lower(c.nombre) in ('urban warriors','qa-club-001 · kombax qa test')
  and cc.clave in ('finance_v2_enabled','finance_dashboard_v2_enabled','finance_reports_enabled');

update public.config_club cc
set valor='false'::jsonb, actualizado_en=now()
from public.clubes c
where c.id=cc.club_id
  and lower(c.nombre) in ('urban warriors','qa-club-001 · kombax qa test')
  and cc.clave in ('finance_recurring_enabled','finance_qa_shadow_approved','finance_pilot_live_enabled');

commit;
