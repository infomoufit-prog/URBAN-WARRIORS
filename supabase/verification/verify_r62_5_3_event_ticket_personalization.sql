do $$
begin
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_eventos_publicos' and column_name='ticket_accent') then raise exception 'missing ticket_accent'; end if;
  if not exists(select 1 from information_schema.columns where table_schema='public' and table_name='kombax_eventos_publicos' and column_name='ticket_logo_entity_ids') then raise exception 'missing ticket_logo_entity_ids'; end if;
  if not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='app_kombax_event_ticketing_mutate_r6253') then raise exception 'missing r6253 mutate'; end if;
  if not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='app_kombax_my_event_tickets_r6253') then raise exception 'missing r6253 wallet'; end if;
  if has_function_privilege('anon','public.app_kombax_event_ticketing_mutate_r6253(uuid,jsonb,uuid)','EXECUTE') then raise exception 'anon mutate exposure'; end if;
  if has_function_privilege('anon','public.app_kombax_my_event_tickets_r6253(integer)','EXECUTE') then raise exception 'anon wallet exposure'; end if;
  raise notice 'KOMBAX R62.5.3 EVENT TICKET PERSONALIZATION: PASS';
end $$;
