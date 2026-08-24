select
  to_regprocedure('public.app_kombax_contact_message_report_v122(uuid,text,text)') is not null as report_rpc_ok,
  to_regclass('public.kombax_message_report_evidence_v122') is not null as evidence_table_ok,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_social_contacto_mensajes' and column_name='moderation_hidden') as hidden_column_ok,
  position("'mensaje'" in pg_get_constraintdef((select oid from pg_constraint where conname='kombax_social_reportes_objetivo_tipo_check' limit 1)))>0 as report_message_type_ok,
  not has_function_privilege('anon','public.app_kombax_contact_message_report_v122(uuid,text,text)','EXECUTE') as anon_denied;
