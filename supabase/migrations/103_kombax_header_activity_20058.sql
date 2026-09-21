-- KOMBAX RC13 build 20058 · 103 · split global/club/message header activity
begin;

create or replace function public.app_kombax_header_activity_v103()
returns table(
  kombax_pending integer,
  relation_requests integer,
  contact_requests integer,
  message_unread integer
)
language sql
stable
security definer
set search_path=public,auth
as $$
  with access_scope as (
    select auth.uid() as uid, public.app_kombax_social_acceso_v041() as social_access
  ),
  relation_count as (
    select count(distinct r.id)::integer as n
    from public.kombax_relaciones r cross join access_scope s
    where s.uid is not null and s.social_access
      and r.estado='pending'
      and public.app_kombax_social_puede_actuar_v051(r.destino_social_id)
  ),
  contact_count as (
    select count(distinct c.id)::integer as n
    from public.kombax_social_contactos c cross join access_scope s
    where s.uid is not null and s.social_access
      and c.estado='pendiente'
      and public.app_kombax_social_puede_actuar_v051(c.destinatario_social_id)
      and public.app_kombax_contact_can_access_v067(c.id)
  ),
  unread_count as (
    select count(*)::integer as n
    from public.kombax_social_contacto_mensajes m
    join public.kombax_social_contactos c on c.id=m.contacto_id
    cross join access_scope s
    where s.uid is not null and s.social_access
      and c.estado='aceptada'
      and m.leido_en is null
      and public.app_kombax_contact_can_access_v067(c.id)
      and not public.app_kombax_social_puede_actuar_v051(m.autor_social_id)
  )
  select (r.n+c.n)::integer,r.n,c.n,m.n
  from relation_count r,contact_count c,unread_count m;
$$;

revoke all on function public.app_kombax_header_activity_v103() from public,anon;
grant execute on function public.app_kombax_header_activity_v103() to authenticated;

notify pgrst,'reload schema';
commit;
