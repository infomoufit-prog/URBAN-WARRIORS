-- WORK phase 1: club managers can review member interest sent from the public directory.
begin;
create or replace function public.app_kombax_club_interest_list_r98(p_club_id uuid)
returns table(thread_id uuid,account_id uuid,account_name text,account_email text,message text,sent_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not public.tiene_rol_club(p_club_id,'direccion','secretaria') then
  raise exception 'KOMBAX_CLUB_INTEREST_FORBIDDEN' using errcode='42501';
 end if;
 return query
 select t.id,t.account_id,btrim(concat_ws(' ',p.nombre,p.apellidos)),lower(coalesce(u.email,'')),m.texto,m.creado_en
 from public.kombax_club_interest_threads_r58 t
 join public.perfiles p on p.id=t.account_id
 left join auth.users u on u.id=t.account_id
 join lateral (
  select x.texto,x.creado_en from public.kombax_club_interest_messages_r58 x
  where x.thread_id=t.id order by x.creado_en desc limit 1
 ) m on true
 where t.club_id=p_club_id and t.estado='abierta'
 order by m.creado_en desc limit 100;
end $$;
revoke all on function public.app_kombax_club_interest_list_r98(uuid) from public,anon,service_role;
grant execute on function public.app_kombax_club_interest_list_r98(uuid) to authenticated;
commit;
