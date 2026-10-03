-- Run only AFTER applying the repair and deploying both Owner functions.
-- Uses the existing private scheduler secret. Contains no keys.
begin;
create or replace function kombax_owner_ai.dispatch_verifications_r118()
returns bigint language plpgsql security definer set search_path='' as $$
declare v_url text;v_secret text;v_request bigint;
begin
 if not exists(select 1 from kombax_owner_ai.verification_jobs_r118 where status='queued' or (status='processing' and lease_until<now())) then return null;end if;
 select decrypted_secret into v_url from vault.decrypted_secrets where name='project_url' limit 1;
 select decrypted_secret into v_secret from vault.decrypted_secrets where name='uw_cron_secret' limit 1;
 if v_url is null or v_secret is null then raise exception 'OWNER_VERIFICATION_SCHEDULER_CONFIGURATION_REQUIRED';end if;
 select net.http_post(url:=rtrim(v_url,'/')||'/functions/v1/kombax-owner-verification-worker-r118',
  headers:=jsonb_build_object('content-type','application/json','x-uw-cron-secret',v_secret),body:='{}'::jsonb,timeout_milliseconds:=150000) into v_request;
 return v_request;
end $$;
revoke all on function kombax_owner_ai.dispatch_verifications_r118() from public,anon,authenticated;
do $$
declare j bigint;
begin
 if not exists(select 1 from pg_extension where extname='pg_cron') or not exists(select 1 from pg_extension where extname='pg_net') then raise exception 'OWNER_VERIFICATION_SCHEDULER_EXTENSIONS_REQUIRED';end if;
 if not exists(select 1 from vault.secrets where name='uw_cron_secret') or not exists(select 1 from vault.secrets where name='project_url') then raise exception 'OWNER_VERIFICATION_SCHEDULER_VAULT_REQUIRED';end if;
 select jobid into j from cron.job where jobname='kombax-owner-verification-pilot-r118' limit 1;
 if j is not null then perform cron.unschedule(j);end if;
 perform cron.schedule('kombax-owner-verification-pilot-r118','* * * * *',$cron$select kombax_owner_ai.dispatch_verifications_r118();$cron$);
end $$;
commit;
-- Pause automatic processing without affecting manual review:
-- select cron.unschedule('kombax-owner-verification-pilot-r118');
