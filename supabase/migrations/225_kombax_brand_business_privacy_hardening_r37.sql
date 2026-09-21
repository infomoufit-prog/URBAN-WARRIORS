-- KOMBAX 20.101 R37 · Brand Business Hub privacy hardening
begin;

-- Explicit deny policies: business objects are available only through checked RPCs.
do $$
declare t text;
begin
  foreach t in array array[
    'kombax_brand_profiles_v223','kombax_brand_campaigns_v223','kombax_brand_collaboration_preferences_v223',
    'kombax_brand_proposals_v223','kombax_brand_team_roles_v223','kombax_brand_audit_v223'
  ] loop
    execute format('drop policy if exists %I on public.%I','r37_rpc_only',t);
    execute format('create policy %I on public.%I for all to public using(false) with check(false)','r37_rpc_only',t);
  end loop;
end $$;

-- No R37 brand function may reach private competition preparation / daily weight history.
-- This is intentionally enforced by design and covered by the R37 source and live audit tests.

alter function public.app_kombax_brand_workspace_v223(uuid) set search_path='';
alter function public.app_kombax_brand_discovery_v223(uuid,text,text,text,text,integer) set search_path='';
alter function public.app_kombax_brand_open_campaigns_v223(uuid,integer) set search_path='';
alter function public.app_kombax_brand_collaboration_preferences_v223(uuid) set search_path='';
alter function public.app_kombax_brand_inbox_v223(uuid,integer) set search_path='';
alter function public.app_kombax_brand_mutate_v223(text,jsonb) set search_path='';

revoke execute on function public.app_kombax_brand_workspace_v223(uuid) from public,anon;
revoke execute on function public.app_kombax_brand_discovery_v223(uuid,text,text,text,text,integer) from public,anon;
revoke execute on function public.app_kombax_brand_open_campaigns_v223(uuid,integer) from public,anon;
revoke execute on function public.app_kombax_brand_collaboration_preferences_v223(uuid) from public,anon;
revoke execute on function public.app_kombax_brand_inbox_v223(uuid,integer) from public,anon;
revoke execute on function public.app_kombax_brand_mutate_v223(text,jsonb) from public,anon;

commit;
