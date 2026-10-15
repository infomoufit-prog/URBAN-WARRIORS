-- Personal Instagram credentials belong only to the confirmed adult/16+ member owner.
-- Preserve existing club/direct-profile rules and all post/Meta/legal checks.
CREATE OR REPLACE FUNCTION kombax_meta.can_manage(p_actor uuid, p_social uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select p_actor is not null and exists(select 1 from public.kombax_social_perfiles sp
 where sp.id=p_social and sp.estado='activo' and (
  (sp.sujeto_tipo='club' and exists(select 1 from public.miembros_club mc
   where mc.club_id=sp.club_id and mc.perfil_id=p_actor and mc.activo and mc.rol='direccion'))
  or (sp.sujeto_tipo='perfil_directo' and exists(select 1 from public.perfiles_kombax_directos d
   where d.id=sp.perfil_directo_id and d.estado='activo' and d.tipo<>'espectador' and
   (d.perfil_id=p_actor or exists(select 1 from public.kombax_perfil_gestores g
    where g.perfil_directo_id=d.id and g.perfil_id=p_actor and g.estado='activo' and g.rol in ('owner','admin')))))
 or (sp.sujeto_tipo='miembro' and sp.visible and sp.publicar_habilitado
  and exists(select 1 from public.identidades_sociales i
   join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id
   where i.id=sp.identidad_social_id and i.perfil_id=p_actor and i.tipo='miembro' and i.estado='activa'
    and s.perfil_id=p_actor and s.estado='activo' and s.fecha_nacimiento is not null
    and s.fecha_nacimiento<=current_date-interval '16 years'))
 ));
$function$;

revoke all on function kombax_meta.can_manage(uuid,uuid) from public,anon,authenticated;

