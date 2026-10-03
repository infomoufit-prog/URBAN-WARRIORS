-- KOMBAX R118 Phase 4 compatibility rollback.
-- New credential tables/columns are intentionally preserved to avoid data loss.
-- Disable R118 RPC entry points and let the previous v198 professional workspace/mutator remain authoritative.
revoke execute on function public.app_kombax_professional_workspace_r118(uuid) from authenticated;
revoke execute on function public.app_kombax_professional_credential_mutate_r118(text,jsonb,uuid) from authenticated;
revoke execute on function public.app_kombax_professional_credential_queue_r118() from authenticated;
revoke execute on function public.app_kombax_professional_public_credentials_r118(uuid) from anon,authenticated;
