-- KOMBAX 20.101 R36 · privacy/audit hardening
-- No direct access to connection, invitation, discovery or private weight tables.

begin;

-- Explicitly deny direct table access. RPCs are the only client path.
do $$
declare t text;
begin
  foreach t in array array['kombax_event_connections_v220','kombax_event_publication_policies_v220','kombax_event_organizer_permissions_v220','kombax_event_public_projection_v220','kombax_event_connection_audit_v220','kombax_fighter_discovery_v221','kombax_fight_invitations_v221'] loop
    execute format('drop policy if exists %I on public.%I','kombax_r36_no_direct_'||t,t);
    execute format('create policy %I on public.%I for all to public using(false) with check(false)','kombax_r36_no_direct_'||t,t);
  end loop;
end $$;

-- Never allow an event connection to expose the private daily weight history.
-- Official weigh-in publication remains represented only as an event-level publication flag.
create or replace function public.app_kombax_event_public_projection_v220(p_public_event_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_projection jsonb;
begin
  select pp.projection into v_projection
  from public.kombax_event_public_projection_v220 pp
  join public.kombax_event_connections_v220 c on c.id=pp.connection_id
  where c.public_event_id=p_public_event_id and c.status='connected';
  return coalesce(v_projection,'{}'::jsonb);
end $$;
revoke all on function public.app_kombax_event_public_projection_v220(uuid) from public,service_role;
grant execute on function public.app_kombax_event_public_projection_v220(uuid) to anon,authenticated;

notify pgrst,'reload schema';
commit;
