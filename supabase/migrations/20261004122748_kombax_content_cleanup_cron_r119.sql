begin;
do $$
declare template text;
begin
 select command into template from cron.job where jobname='urban-warriors-notification-dispatch' and active;
 if template is null or template not like '%x-uw-cron-secret%' or template not like '%notification-dispatch%' then
  raise exception 'Authenticated cron template missing; configure cleanup scheduler before activation';
 end if;
 -- Reuse the established secret without exposing it in source, logs or the client.
 perform cron.schedule('kombax-content-cleanup-r119','* * * * *',replace(template,'notification-dispatch','kombax-content-cleanup'));
end $$;
commit;
