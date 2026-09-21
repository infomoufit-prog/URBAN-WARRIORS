-- Verificación build 20040 · afiliación verificada + Contacto KOMBAX.

-- Contrato legal vigente.
select club_id,version,vigente
from public.textos_legales
where tipo='comunidad_general' and version in ('1.1.0','1.2.0')
order by club_id,version;

-- Superficie 065 completa.
select
  to_regprocedure('public.app_kombax_social_estado_v065(uuid)') is not null as social_status_065,
  to_regprocedure('public.app_kombax_identity_mutate_v065(text,jsonb,uuid)') is not null as identity_mutate_065,
  to_regprocedure('public.app_kombax_social_mutate_v065(text,jsonb,uuid)') is not null as social_mutate_065,
  to_regprocedure('public.app_kombax_social_afiliacion_v065(uuid)') is not null as affiliation_065,
  to_regprocedure('public.app_kombax_social_directorio_v065(text,integer)') is not null as directory_065,
  to_regprocedure('public.app_kombax_social_feed_v065(timestamptz,uuid,integer)') is not null as feed_065,
  to_regprocedure('public.app_kombax_perfil_publico_v065(uuid)') is not null as public_profile_065,
  to_regprocedure('public.app_kombax_contactos_v065()') is not null as contacts_065,
  to_regprocedure('public.app_kombax_contact_mensajes_v065(uuid)') is not null as messages_065,
  to_regprocedure('public.app_kombax_contact_mark_read_v065(uuid)') is not null as mark_read_065,
  to_regprocedure('public.app_kombax_social_network_mutate_v065(text,jsonb,uuid)') is not null as network_mutate_065;

-- Privilegios: la API pública es RPC; tabla y helpers internos no se exponen.
select
  has_function_privilege('authenticated','public.app_kombax_contactos_v065()','EXECUTE') as contacts_rpc,
  has_function_privilege('authenticated','public.app_kombax_contact_mensajes_v065(uuid)','EXECUTE') as messages_rpc,
  has_function_privilege('authenticated','public.app_kombax_social_network_mutate_v065(text,jsonb,uuid)','EXECUTE') as mutation_rpc,
  has_function_privilege('authenticated','public.app_kombax_contact_can_access_v065(uuid)','EXECUTE') as internal_access_helper_exposed,
  has_function_privilege('authenticated','public.app_kombax_contact_pair_blocked_v065(uuid,uuid)','EXECUTE') as internal_block_helper_exposed,
  has_table_privilege('authenticated','public.kombax_social_contacto_mensajes','SELECT') as direct_message_select;

-- La tabla de mensajes debe seguir siendo exclusivamente textual.
select a.attname as column_name,pg_catalog.format_type(a.atttypid,a.atttypmod) as data_type
from pg_catalog.pg_attribute a
where a.attrelid='public.kombax_social_contacto_mensajes'::regclass
  and a.attnum>0 and not a.attisdropped
order by a.attnum;

-- No debe haber dos hilos abiertos para la misma pareja.
select least(remitente_social_id,destinatario_social_id) as a,
       greatest(remitente_social_id,destinatario_social_id) as b,
       count(*) as open_threads
from public.kombax_social_contactos
where estado in ('pendiente','aceptada')
group by 1,2
having count(*)>1;

-- Ningún hilo puede superar 20 mensajes ni saltarse ordinales.
select c.id,count(m.id) as messages,min(m.ordinal) as first_ordinal,max(m.ordinal) as last_ordinal,c.mensajes_limite
from public.kombax_social_contactos c
left join public.kombax_social_contacto_mensajes m on m.contacto_id=c.id
group by c.id,c.mensajes_limite
having count(m.id)>20 or coalesce(max(m.ordinal),0)>20;
