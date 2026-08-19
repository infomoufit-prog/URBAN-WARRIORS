-- Retorno controlado de 037. No borra lecturas ya registradas.
begin;
drop function if exists public.app_notificaciones_centro_v037(uuid,integer);
drop index if exists public.idx_notificaciones_lecturas_notificacion_perfil_v037;

create or replace function public.app_marcar_notificacion_leida(p_notificacion_id uuid)
returns void language plpgsql security definer set search_path=public,auth
as $$
declare v_row public.notificaciones; v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'Debes iniciar sesión'; end if;
  select * into v_row from public.notificaciones where id=p_notificacion_id;
  if v_row.id is null then raise exception 'Notificación no encontrada'; end if;
  if not (v_row.perfil_id=v_uid or (v_row.rol_destino is not null and public.tiene_rol_club(v_row.club_id,v_row.rol_destino)) or (v_row.audiencia='todos' and public.es_miembro_club(v_row.club_id))) then raise exception 'No tienes acceso a esta notificación'; end if;
  if v_row.perfil_id=v_uid then update public.notificaciones set leida=true,leida_en=now() where id=v_row.id;
  else insert into public.notificaciones_lecturas(notificacion_id,perfil_id) values(v_row.id,v_uid) on conflict(notificacion_id,perfil_id) do update set leida_en=now(); end if;
end $$;
revoke all on function public.app_marcar_notificacion_leida(uuid) from public,anon;
grant execute on function public.app_marcar_notificacion_leida(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
