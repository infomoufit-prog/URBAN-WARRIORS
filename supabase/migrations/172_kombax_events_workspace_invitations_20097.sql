-- KOMBAX RC13 build 20.097 · 172 · Events invitations scoped to club workspace
begin;
create or replace function public.app_kombax_eventos_invitaciones_contexto_v172(p_club_id uuid)
returns table(id uuid,evento_id uuid,evento_nombre text,evento_fecha timestamptz,rol text,social_profile_id uuid,identidad_nombre text,identidad_tipo text,creado_en timestamptz)
language sql stable security definer set search_path=public,auth as $$
  select ee.id,e.id,e.nombre,e.fecha_inicio,ee.rol,ee.social_profile_id,sp.nombre_publico,public.app_kombax_social_tipo_v051(sp.id),ee.creado_en
  from public.kombax_evento_entidades ee
  join public.kombax_eventos_publicos e on e.id=ee.evento_id
  join public.kombax_social_perfiles sp on sp.id=ee.social_profile_id
  where ee.estado='pendiente'
    and sp.sujeto_tipo='club' and sp.club_id=p_club_id and sp.estado='activo' and sp.visible
    and exists(
      select 1 from public.miembros_club m
      where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo
        and (m.rol in ('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false))
    )
  order by ee.creado_en desc;
$$;
revoke all on function public.app_kombax_eventos_invitaciones_contexto_v172(uuid) from public,anon;
grant execute on function public.app_kombax_eventos_invitaciones_contexto_v172(uuid) to authenticated;
comment on function public.app_kombax_eventos_invitaciones_contexto_v172(uuid) is '20.097: co-organization invitations visible only for the active club workspace.';
notify pgrst,'reload schema';
commit;
