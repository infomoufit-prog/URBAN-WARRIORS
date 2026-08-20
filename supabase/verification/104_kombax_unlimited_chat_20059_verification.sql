select
  to_regprocedure('public.app_kombax_contactos_v104()') is not null as contacts_present,
  to_regprocedure('public.app_kombax_contact_mensajes_v104(uuid,integer,integer,integer)') is not null as messages_present,
  to_regprocedure('public.app_kombax_social_network_mutate_v104(text,jsonb,uuid)') is not null as mutate_present,
  (select data_type from information_schema.columns where table_schema='public' and table_name='kombax_social_contacto_mensajes' and column_name='ordinal')='integer' as ordinal_is_integer,
  exists(
    select 1 from pg_constraint c
    where c.conrelid='public.kombax_social_contacto_mensajes'::regclass
      and c.conname='kombax_social_contacto_mensajes_ordinal_check'
      and pg_get_constraintdef(c.oid) not like '%<= 20%'
  ) as ordinal_no_upper_20,
  exists(select 1 from public.textos_legales where tipo='comunidad_general' and version='1.3.0' and vigente) as rules_13_current,
  has_function_privilege('authenticated','public.app_kombax_social_network_mutate_v104(text,jsonb,uuid)','EXECUTE') as auth_mutate,
  not has_function_privilege('anon','public.app_kombax_social_network_mutate_v104(text,jsonb,uuid)','EXECUTE') as anon_closed;
