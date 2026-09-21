-- Verificación build 20041 · ciclo de vida del contenido + multimedia adaptable.

-- 1) Contacto KOMBAX conserva tombstones por participante.
select
  count(*) filter (where column_name='eliminado_remitente_en')=1 as sender_tombstone,
  count(*) filter (where column_name='eliminado_destinatario_en')=1 as recipient_tombstone
from information_schema.columns
where table_schema='public' and table_name='kombax_social_contactos'
  and column_name in ('eliminado_remitente_en','eliminado_destinatario_en');

-- 2) Superficie 067 completa.
select
  to_regprocedure('public.app_kombax_contact_can_access_v067(uuid)') is not null as contact_access_067,
  to_regprocedure('public.app_kombax_contactos_v067()') is not null as contacts_067,
  to_regprocedure('public.app_kombax_contact_mensajes_v067(uuid)') is not null as messages_067,
  to_regprocedure('public.app_kombax_contact_mark_read_v067(uuid)') is not null as mark_read_067,
  to_regprocedure('public.app_kombax_social_network_mutate_v067(text,jsonb,uuid)') is not null as contact_mutate_067,
  to_regprocedure('public.app_kombax_social_mutate_v067(text,jsonb,uuid)') is not null as social_mutate_067,
  to_regprocedure('public.app_kombax_showcase_mutate_v067(text,jsonb,uuid)') is not null as showcase_mutate_067;

-- 3) Privilegios: gateways autenticados; helper interno no expuesto a cliente/anon.
select
  has_function_privilege('authenticated','public.app_kombax_contactos_v067()','EXECUTE') as contacts_rpc,
  has_function_privilege('authenticated','public.app_kombax_contact_mensajes_v067(uuid)','EXECUTE') as messages_rpc,
  has_function_privilege('authenticated','public.app_kombax_contact_mark_read_v067(uuid)','EXECUTE') as mark_read_rpc,
  has_function_privilege('authenticated','public.app_kombax_social_network_mutate_v067(text,jsonb,uuid)','EXECUTE') as contact_mutation_rpc,
  has_function_privilege('authenticated','public.app_kombax_social_mutate_v067(text,jsonb,uuid)','EXECUTE') as social_mutation_rpc,
  has_function_privilege('authenticated','public.app_kombax_showcase_mutate_v067(text,jsonb,uuid)','EXECUTE') as showcase_mutation_rpc,
  has_function_privilege('authenticated','public.app_kombax_contact_can_access_v067(uuid)','EXECUTE') as internal_helper_exposed,
  has_function_privilege('anon','public.app_kombax_social_network_mutate_v067(text,jsonb,uuid)','EXECUTE') as anon_contact_mutation,
  has_function_privilege('anon','public.app_kombax_social_mutate_v067(text,jsonb,uuid)','EXECUTE') as anon_social_mutation,
  has_function_privilege('anon','public.app_kombax_showcase_mutate_v067(text,jsonb,uuid)','EXECUTE') as anon_showcase_mutation;

-- 4) Un contacto eliminado por alguno de los participantes no puede seguir abierto.
select id,estado,eliminado_remitente_en,eliminado_destinatario_en
from public.kombax_social_contactos
where estado in ('pendiente','aceptada')
  and (eliminado_remitente_en is not null or eliminado_destinatario_en is not null);

-- 5) El límite de Contacto KOMBAX se mantiene en <= 20.
select c.id,count(m.id) as mensajes,c.mensajes_limite,max(m.ordinal) as ultimo_ordinal
from public.kombax_social_contactos c
left join public.kombax_social_contacto_mensajes m on m.contacto_id=c.id
group by c.id,c.mensajes_limite
having count(m.id)>20 or coalesce(max(m.ordinal),0)>20;

-- 6) Publicaciones activas no deben apuntar a media eliminada.
select p.id as publicacion_id,p.social_media_id,m.estado as media_estado
from public.kombax_social_publicaciones p
join public.kombax_social_media m on m.id=p.social_media_id
where p.estado='activa' and m.estado='removed';

-- 7) No quedan residuos QA del certificado 20041.
select
  (select count(*) from public.kombax_social_contactos where mensaje='QA temporal eliminación 20041') as qa_contactos,
  (select count(*) from public.kombax_social_publicaciones where texto='QA temporal eliminación Social 20041') as qa_posts,
  (select count(*) from public.kombax_social_media where storage_path like '%qa-20041-delete.jpg') as qa_media,
  (select count(*) from public.kombax_showcase_elementos where nombre='QA temporal eliminación Showcase 20041') as qa_showcase;
