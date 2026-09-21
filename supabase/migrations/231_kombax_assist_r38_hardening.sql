-- KOMBAX 20.101 R38 · Assist privacy/economy hardening

-- Private schemas stay closed even if future default grants change.
revoke all on schema kombax_ai_ops from public,anon,authenticated,service_role;
revoke all on schema kombax_customer_ops from public,anon,authenticated,service_role;
alter default privileges in schema kombax_ai_ops revoke all on tables from public,anon,authenticated,service_role;
alter default privileges in schema kombax_customer_ops revoke all on tables from public,anon,authenticated,service_role;
alter default privileges in schema kombax_ai_ops revoke execute on functions from public,anon,authenticated,service_role;
alter default privileges in schema kombax_customer_ops revoke execute on functions from public,anon,authenticated,service_role;

-- Ensure the assistant cannot ever infer or query private competition weight/preparation through its R38 database surface.
comment on function public.app_kombax_assist_turn_internal_v227(uuid) is 'Service-only Assist context. Reads support chat and staged migration files only; no competition preparation or private weight history.';
comment on function public.app_kombax_assist_turn_complete_v227(uuid,text,text,integer,integer,jsonb) is 'Service-only AI usage ledger and migration extraction cache. Never exposes model/token/cost to customer APIs.';

-- Service-only functions must not inherit PUBLIC execute.
revoke execute on function public.app_kombax_assist_turn_internal_v227(uuid) from public,anon,authenticated;
revoke execute on function public.app_kombax_assist_turn_complete_v227(uuid,text,text,integer,integer,jsonb) from public,anon,authenticated;
revoke execute on function public.app_kombax_assist_turn_fail_v227(uuid,text) from public,anon,authenticated;
grant execute on function public.app_kombax_assist_turn_internal_v227(uuid) to service_role;
grant execute on function public.app_kombax_assist_turn_complete_v227(uuid,text,text,integer,integer,jsonb) to service_role;
grant execute on function public.app_kombax_assist_turn_fail_v227(uuid,text) to service_role;

-- Customer functions are authenticated-only.
revoke execute on function public.app_kombax_assist_dashboard_v227(text) from public,anon,service_role;
revoke execute on function public.app_kombax_assist_messages_v227(text,integer) from public,anon,service_role;
revoke execute on function public.app_kombax_assist_turn_reserve_v227(text,text,text) from public,anon,service_role;
revoke execute on function public.app_kombax_assist_turn_context_v227(uuid) from public,anon,service_role;
revoke execute on function public.app_kombax_migration_file_register_v228(text,text,text,text,bigint) from public,anon,service_role;
revoke execute on function public.app_kombax_migration_files_v228(text) from public,anon,service_role;
revoke execute on function public.app_kombax_migration_preview_v228(text) from public,anon,service_role;

grant execute on function public.app_kombax_assist_dashboard_v227(text) to authenticated;
grant execute on function public.app_kombax_assist_messages_v227(text,integer) to authenticated;
grant execute on function public.app_kombax_assist_turn_reserve_v227(text,text,text) to authenticated;
grant execute on function public.app_kombax_assist_turn_context_v227(uuid) to authenticated;
grant execute on function public.app_kombax_migration_file_register_v228(text,text,text,text,bigint) to authenticated;
grant execute on function public.app_kombax_migration_files_v228(text) to authenticated;
grant execute on function public.app_kombax_migration_preview_v228(text) to authenticated;
notify pgrst,'reload schema';
