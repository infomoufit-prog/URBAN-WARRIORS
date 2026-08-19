-- Rollback no destructivo del hardening de índices 066.
begin;
drop index if exists public.idx_kombax_contact_messages_author_v066;
drop index if exists public.idx_kombax_contact_messages_created_by_v066;
drop index if exists public.idx_kombax_social_contactos_cerrado_por_v066;
drop index if exists public.idx_kombax_social_contactos_creado_por_v066;
drop index if exists public.idx_kombax_social_contactos_respondido_por_v066;
commit;
