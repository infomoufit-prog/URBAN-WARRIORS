-- KOMBAX R62.5.2 · QR access performance hardening
-- Covers FK access paths identified by Supabase advisors after the main R62.5.2 migration.
begin;

create index if not exists idx_event_ticket_access_staff_granted_by_r6252
  on kombax_payments.event_ticket_access_staff(granted_by);

create index if not exists idx_event_ticket_checkin_audit_actor_r6252
  on kombax_payments.event_ticket_checkin_audit(actor_user_id, created_at desc);

commit;
