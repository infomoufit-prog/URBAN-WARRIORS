-- R95: A member publishes through their own active Social identity.
-- Club team permissions continue to govern acting as the club.
begin;

create or replace function public.app_kombax_social_puede_actuar_v051(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.kombax_social_perfiles sp
    where sp.id=p_social_id and sp.visible and sp.estado='activo' and sp.publicar_habilitado and (
      (sp.sujeto_tipo='miembro' and exists(
        select 1 from public.identidades_sociales i
        join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id
        where i.id=sp.identidad_social_id and i.perfil_id=auth.uid()
          and i.estado='activa' and s.estado='activo' and s.fecha_nacimiento is not null
          and extract(year from age(current_date,s.fecha_nacimiento))>=14
      ))
      or (sp.sujeto_tipo='club'
        and public.app_kombax_club_permiso_v051(sp.club_id,'social.publish')
        and public.app_kombax_club_permiso_v051(sp.club_id,'social.act_as_club'))
      or (sp.sujeto_tipo='perfil_directo' and exists(
        select 1 from public.perfiles_kombax_directos d
        where d.id=sp.perfil_directo_id and d.perfil_id=auth.uid()
          and d.estado='activo' and d.verificacion_estado='verificado' and d.social_activo
          and (
            d.tipo in ('marca','federacion','media')
            or (d.tipo in ('competidor','profesional') and exists(
              select 1 from public.identidades_sociales i
              join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id
              where i.perfil_id=d.perfil_id and i.estado='activa' and s.estado='activo'
                and s.fecha_nacimiento is not null
                and extract(year from age(current_date,s.fecha_nacimiento))>=14
            ))
          )
      ))
    )
  );
$$;
revoke all on function public.app_kombax_social_puede_actuar_v051(uuid) from public,anon;
grant execute on function public.app_kombax_social_puede_actuar_v051(uuid) to authenticated;

commit;
