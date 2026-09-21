-- KOMBAX / Urban Warriors · build 20022
-- Persistencia unificada de lecturas y centro de notificaciones en una consulta.
-- Requiere 034 y no cambia backend_version, schema_epoch ni el gateway vigente.
begin;

create index if not exists idx_notificaciones_lecturas_notificacion_perfil_v037
  on public.notificaciones_lecturas(notificacion_id,perfil_id,leida_en desc);

create or replace function public.app_marcar_notificacion_leida(p_notificacion_id uuid)
returns void
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  v_row public.notificaciones;
  v_uid uuid:=auth.uid();
begin
  if v_uid is null then raise exception 'Debes iniciar sesión'; end if;
  select * into v_row from public.notificaciones where id=p_notificacion_id for update;
  if v_row.id is null then raise exception 'Notificación no encontrada'; end if;
  if not (
    v_row.perfil_id=v_uid
    or (v_row.rol_destino is not null and public.tiene_rol_club(v_row.club_id,v_row.rol_destino))
    or (v_row.audiencia='todos' and public.es_miembro_club(v_row.club_id))
  ) then raise exception 'No tienes acceso a esta notificación'; end if;

  -- La lectura personal se registra siempre. De este modo la fuente de verdad
  -- es idéntica para avisos directos, por rol y para todo el club.
  insert into public.notificaciones_lecturas(notificacion_id,perfil_id,leida_en)
  values(v_row.id,v_uid,now())
  on conflict(notificacion_id,perfil_id) do update set leida_en=excluded.leida_en;

  -- Se conserva la marca histórica de la fila dirigida para clientes previos.
  if v_row.perfil_id=v_uid then
    update public.notificaciones set leida=true,leida_en=now() where id=v_row.id;
  end if;
end
$$;
revoke all on function public.app_marcar_notificacion_leida(uuid) from public,anon;
grant execute on function public.app_marcar_notificacion_leida(uuid) to authenticated;

create or replace function public.app_notificaciones_centro_v037(p_club_id uuid,p_limit integer default 500)
returns setof jsonb
language sql
stable
security definer
set search_path=public,auth
as $$
  select to_jsonb(n)
    || jsonb_build_object(
      'leida',coalesce(l.perfil_id is not null,n.perfil_id=auth.uid() and n.leida,false),
      'leida_en',coalesce(l.leida_en,case when n.perfil_id=auth.uid() then n.leida_en end),
      'requiere_accion',public.app_notificacion_requiere_accion_v034(n.id)
    )
  from public.notificaciones n
  left join public.notificaciones_lecturas l
    on l.notificacion_id=n.id and l.perfil_id=auth.uid()
  where n.club_id=p_club_id
    and public.es_miembro_club(p_club_id)
    and (
      n.perfil_id=auth.uid()
      or n.audiencia='todos'
      or n.rol_destino is not null and public.tiene_rol_club(p_club_id,n.rol_destino)
    )
  order by n.creado_en desc,n.id desc
  limit least(1000,greatest(1,coalesce(p_limit,500)));
$$;
revoke all on function public.app_notificaciones_centro_v037(uuid,integer) from public,anon;
grant execute on function public.app_notificaciones_centro_v037(uuid,integer) to authenticated;

do $audit$
begin
  if to_regprocedure('public.app_notificaciones_centro_v037(uuid,integer)') is null then raise exception '037: falta centro unificado'; end if;
  if to_regprocedure('public.app_notificacion_requiere_accion_v034(uuid)') is null then raise exception '037: falta clasificador 034'; end if;
  if not exists(select 1 from pg_class where oid='public.notificaciones_lecturas'::regclass and relrowsecurity) then raise exception '037: RLS de lecturas no activa'; end if;
end
$audit$;

notify pgrst,'reload schema';
commit;
