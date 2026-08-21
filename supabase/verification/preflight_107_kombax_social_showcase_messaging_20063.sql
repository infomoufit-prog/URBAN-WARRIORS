-- Preflight 107 · KOMBAX build 20063 · Social + Showcase messaging.
-- Solo lectura: ejecutar antes de la migración.
select
  to_regclass('public.kombax_social_contactos') is not null as contacts_table,
  to_regclass('public.kombax_social_contacto_mensajes') is not null as messages_table,
  to_regclass('public.kombax_showcase_elementos') is not null as showcase_items_table,
  to_regclass('public.kombax_showcase_marcas') is not null as showcase_brands_table,
  to_regprocedure('public.app_kombax_social_network_mutate_v104(text,jsonb,uuid)') is not null as network_v104,
  to_regprocedure('public.app_kombax_contactos_v106()') is not null as contacts_v106,
  to_regprocedure('public.app_kombax_header_activity_v106()') is not null as header_activity_v106,
  to_regprocedure('public.app_kombax_header_summary_v106(uuid)') is not null as header_summary_v106,
  to_regclass('public.uq_kombax_contact_pair_open_v065') is not null as legacy_pair_index,
  not exists(
    select 1
    from public.kombax_social_contactos c
    where c.estado in ('pendiente','aceptada')
    group by least(c.remitente_social_id,c.destinatario_social_id), greatest(c.remitente_social_id,c.destinatario_social_id)
    having count(*)>1
  ) as legacy_open_pairs_consistent;
