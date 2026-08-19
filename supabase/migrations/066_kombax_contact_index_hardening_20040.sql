-- KOMBAX RC13 build 20040 · Contacto KOMBAX index hardening.
-- Cierra las FK sin índice detectadas por Supabase Advisor dentro del dominio de contacto.

begin;

create index if not exists idx_kombax_contact_messages_author_v066
  on public.kombax_social_contacto_mensajes(autor_social_id);

create index if not exists idx_kombax_contact_messages_created_by_v066
  on public.kombax_social_contacto_mensajes(creado_por);

create index if not exists idx_kombax_social_contactos_cerrado_por_v066
  on public.kombax_social_contactos(cerrado_por);

-- Estas dos FK ya existían antes de 065, pero pertenecen al mismo agregado de contacto
-- y quedan cubiertas ahora para no dejar deuda local tras ampliar el módulo.
create index if not exists idx_kombax_social_contactos_creado_por_v066
  on public.kombax_social_contactos(creado_por);

create index if not exists idx_kombax_social_contactos_respondido_por_v066
  on public.kombax_social_contactos(respondido_por);

commit;
