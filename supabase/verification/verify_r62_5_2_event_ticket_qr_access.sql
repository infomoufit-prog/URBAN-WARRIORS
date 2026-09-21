do $$
begin
  if to_regclass('kombax_payments.event_ticket_access_staff') is null then raise exception 'R6252 staff table missing'; end if;
  if to_regclass('kombax_payments.event_ticket_checkin_audit') is null then raise exception 'R6252 audit table missing'; end if;
  if not exists(select 1 from information_schema.columns where table_schema='kombax_payments' and table_name='event_tickets' and column_name='used_by') then raise exception 'R6252 used_by missing'; end if;
  if to_regprocedure('public.app_kombax_event_ticket_checkin_r6252(uuid,text)') is null then raise exception 'R6252 checkin RPC missing'; end if;
  if to_regprocedure('public.app_kombax_my_event_tickets_r6252(integer)') is null then raise exception 'R6252 wallet RPC missing'; end if;
  if to_regprocedure('public.app_kombax_event_ticket_dashboard_r6252(uuid)') is null then raise exception 'R6252 dashboard RPC missing'; end if;
  if has_table_privilege('authenticated','kombax_payments.event_ticket_access_staff','select') then raise exception 'R6252 staff table exposed'; end if;
  if has_table_privilege('authenticated','kombax_payments.event_ticket_checkin_audit','select') then raise exception 'R6252 checkin audit exposed'; end if;
  if exists(select 1 from kombax_payments.event_tickets where ticket_token is null) then raise exception 'R6252 ticket without QR token'; end if;
  raise notice 'KOMBAX R62.5.2 EVENT TICKETING QR ACCESS: PASS';
end $$;

-- R62.5.2 performance hardening indexes must exist.
do $$
begin
  if to_regclass('kombax_payments.idx_event_ticket_access_staff_granted_by_r6252') is null then
    raise exception 'R6252 missing granted_by index';
  end if;
  if to_regclass('kombax_payments.idx_event_ticket_checkin_audit_actor_r6252') is null then
    raise exception 'R6252 missing checkin actor index';
  end if;
end $$;
