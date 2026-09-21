-- 106 rollback · returns runtime to v105/v104 contracts.
begin;
drop function if exists public.app_kombax_contact_mark_read_v106(uuid);
drop function if exists public.app_kombax_contact_mensajes_v106(uuid,integer,integer,integer);
drop function if exists public.app_kombax_contactos_v106();
drop function if exists public.app_kombax_header_summary_v106(uuid);
drop function if exists public.app_kombax_header_activity_v106();
drop function if exists public.app_kombax_contact_can_access_v106(uuid);
drop function if exists public.app_kombax_my_social_actor_ids_v106();
drop index if exists public.idx_kombax_social_contacto_remitente_v106;
notify pgrst,'reload schema';
commit;
