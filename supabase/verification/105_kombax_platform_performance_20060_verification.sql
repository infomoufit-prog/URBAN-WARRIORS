select
  to_regprocedure('public.app_kombax_header_summary_v105(uuid)') is not null as header_summary_present,
  to_regclass('public.idx_notificaciones_club_active_feed_v105') is not null as notification_index_present,
  has_function_privilege('authenticated','public.app_kombax_header_summary_v105(uuid)','EXECUTE') as authenticated_execute,
  not has_function_privilege('anon','public.app_kombax_header_summary_v105(uuid)','EXECUTE') as anon_closed;
