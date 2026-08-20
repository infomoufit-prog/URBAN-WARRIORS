-- 106 verification · run after migration.
select
  to_regprocedure('public.app_kombax_header_summary_v106(uuid)') is not null as header_v106,
  to_regprocedure('public.app_kombax_header_activity_v106()') is not null as activity_v106,
  to_regprocedure('public.app_kombax_contactos_v106()') is not null as contacts_v106,
  to_regprocedure('public.app_kombax_contact_mensajes_v106(uuid,integer,integer,integer)') is not null as messages_v106,
  to_regprocedure('public.app_kombax_contact_mark_read_v106(uuid)') is not null as mark_read_v106,
  to_regclass('public.idx_kombax_social_contacto_remitente_v106') is not null as sender_index;

select
  has_function_privilege('authenticated','public.app_kombax_header_summary_v106(uuid)','EXECUTE') as authenticated_header,
  not has_function_privilege('anon','public.app_kombax_header_summary_v106(uuid)','EXECUTE') as anon_header_closed,
  has_function_privilege('authenticated','public.app_kombax_contact_mensajes_v106(uuid,integer,integer,integer)','EXECUTE') as authenticated_messages,
  not has_function_privilege('anon','public.app_kombax_contact_mensajes_v106(uuid,integer,integer,integer)','EXECUTE') as anon_messages_closed;

select p.proname,p.prosecdef,coalesce(array_to_string(p.proconfig,','),'') as config
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname in (
  'app_kombax_header_summary_v106','app_kombax_header_activity_v106','app_kombax_contactos_v106',
  'app_kombax_contact_mensajes_v106','app_kombax_contact_mark_read_v106'
)
order by p.proname;
