-- ROLLBACK DE EMERGENCIA 065.
-- ADVERTENCIA: eliminar kombax_social_contacto_mensajes destruye mensajes creados tras 065.
-- Ejecutar únicamente como reversión explícita con copia de seguridad previa.
begin;

drop trigger if exists trg_kombax_contact_seed_message_v065 on public.kombax_social_contactos;
drop function if exists public.app_kombax_contact_seed_message_v065();
drop function if exists public.app_kombax_social_network_mutate_v065(text,jsonb,uuid);
drop function if exists public.app_kombax_contact_mark_read_v065(uuid);
drop function if exists public.app_kombax_contact_mensajes_v065(uuid);
drop function if exists public.app_kombax_contactos_v065();
drop function if exists public.app_kombax_contact_pair_blocked_v065(uuid,uuid);
drop function if exists public.app_kombax_contact_can_access_v065(uuid);
drop function if exists public.app_kombax_perfil_publico_v065(uuid);
drop function if exists public.app_kombax_social_feed_v065(timestamptz,uuid,integer);
drop function if exists public.app_kombax_social_directorio_v065(text,integer);
drop function if exists public.app_kombax_social_afiliacion_v065(uuid);
drop function if exists public.app_kombax_social_mutate_v065(text,jsonb,uuid);
drop function if exists public.app_kombax_identity_mutate_v065(text,jsonb,uuid);
drop function if exists public.app_kombax_social_estado_v065(uuid);

drop index if exists public.uq_kombax_contact_pair_open_v065;
drop table if exists public.kombax_social_contacto_mensajes;

alter table public.kombax_social_contactos
  drop constraint if exists kombax_social_contactos_mensajes_limite_check,
  drop column if exists cerrado_en,
  drop column if exists cerrado_por,
  drop column if exists mensajes_limite;

alter table public.identidades_sociales drop column if exists afiliacion_visible;

update public.textos_legales set vigente=false where tipo='comunidad_general' and version='1.2.0';
update public.textos_legales set vigente=true where tipo='comunidad_general' and version='1.1.0';

notify pgrst,'reload schema';
commit;
