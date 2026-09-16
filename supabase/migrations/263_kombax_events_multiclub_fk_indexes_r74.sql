-- R74 performance hardening for foreign keys introduced by migration 261.
create index if not exists idx_event_connections_requested_by_v261
  on public.kombax_event_connections_v220(requested_by);
create index if not exists idx_event_connections_authorized_by_v261
  on public.kombax_event_connections_v220(authorized_by)
  where authorized_by is not null;
create index if not exists idx_event_connection_participant_internal_v261
  on public.kombax_event_connection_participant_shares_v261(internal_participant_id);
create index if not exists idx_event_connection_participant_shared_by_v261
  on public.kombax_event_connection_participant_shares_v261(shared_by);
