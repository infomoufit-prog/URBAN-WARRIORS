select
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='clubes' and column_name='recibo_prefijo') as prefijo_col_ok,
  (select recibo_prefijo='UW' from public.clubes where slug='urban-warriors') as urban_prefijo_ok,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='recibos_cuota' and column_name='emisor_logo_url') as snapshot_logo_ok,
  exists(select 1 from pg_trigger where tgname='trg_recibo_branding_v096' and not tgisinternal) as trigger_branding_ok,
  exists(select 1 from pg_trigger where tgname='trg_club_recibo_prefijo_v096' and not tgisinternal) as trigger_prefix_ok,
  not has_function_privilege('authenticated','public.trg_recibo_branding_v096()','EXECUTE') as trigger_no_auth_exec,
  not has_function_privilege('anon','public.app_kombax_recibo_prefijo_v096(text,text)','EXECUTE') as helper_no_anon_exec,
  not has_function_privilege('authenticated','public.app_kombax_recibo_prefijo_v096(text,text)','EXECUTE') as helper_no_auth_exec,
  not has_table_privilege('anon','public.recibos_cuota','SELECT') as anon_sin_recibos,
  not exists(select 1 from public.recibos_cuota where emisor_nombre is null or emisor_prefijo is null) as historicos_backfill_ok;
