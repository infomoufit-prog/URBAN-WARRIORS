begin;
update public.textos_legales set vigente=false where tipo='comunidad_general' and version='1.3.0' and vigente;
update public.textos_legales set vigente=true where tipo='comunidad_general' and version='1.2.0';
revoke execute on function public.app_kombax_social_network_mutate_v104(text,jsonb,uuid) from authenticated;
revoke execute on function public.app_kombax_contact_mensajes_v104(uuid,integer,integer,integer) from authenticated;
revoke execute on function public.app_kombax_contactos_v104() from authenticated;
drop function if exists public.app_kombax_social_network_mutate_v104(text,jsonb,uuid);
drop function if exists public.app_kombax_contact_mensajes_v104(uuid,integer,integer,integer);
drop function if exists public.app_kombax_contactos_v104();
-- Revertir integer -> smallint solo es seguro si ningún ordinal supera 32767.
do $$
begin
  if exists(select 1 from public.kombax_social_contacto_mensajes where ordinal>32767) then
    raise exception 'ROLLBACK_BLOCKED_CHAT_ORDINAL_OVER_SMALLINT';
  end if;
end $$;
alter table public.kombax_social_contacto_mensajes alter column ordinal type smallint using ordinal::smallint;
alter table public.kombax_social_contacto_mensajes drop constraint if exists kombax_social_contacto_mensajes_ordinal_check;
alter table public.kombax_social_contacto_mensajes add constraint kombax_social_contacto_mensajes_ordinal_check check (ordinal>=1);
notify pgrst,'reload schema';
commit;
