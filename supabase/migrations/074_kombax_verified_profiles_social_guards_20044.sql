-- KOMBAX RC13 build 20044 · 074 · kombax verified profiles social guards

begin;

-- ---------------------------------------------------------------------------
-- 3. Autorización Social y Contacto con gestores + servicio activo.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_social_puede_actuar_v051(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.kombax_social_perfiles sp
    where sp.id=p_social_id and sp.visible and sp.estado='activo' and sp.publicar_habilitado and (
      (sp.sujeto_tipo='miembro' and exists(select 1 from public.identidades_sociales i where i.id=sp.identidad_social_id and i.perfil_id=auth.uid() and i.estado='activa' and public.app_kombax_capacidad_club_v041(i.club_origen_id,'social.publish')))
      or (sp.sujeto_tipo='club' and public.app_kombax_capacidad_club_v041(sp.club_id,'social.publish') and public.app_kombax_club_permiso_v051(sp.club_id,'social.act_as_club'))
      or (sp.sujeto_tipo='perfil_directo' and exists(
        select 1 from public.perfiles_kombax_directos d where d.id=sp.perfil_directo_id and d.estado='activo' and d.verificacion_estado='verificado' and d.workflow_estado in ('verified','limited')
          and d.social_activo and public.app_kombax_perfil_servicio_activo_v071(d.id) and d.tipo in ('competidor','marca','federacion')
          and ((d.tipo='competidor' and d.perfil_id=auth.uid()) or (d.tipo in ('marca','federacion') and public.app_kombax_puede_gestionar_perfil_v070(d.id,'social')))
          and (d.tipo<>'competidor' or d.fecha_nacimiento_verificada is not null and extract(year from age(current_date,d.fecha_nacimiento_verificada))>=14)
      ))
    )
  );
$$;
revoke all on function public.app_kombax_social_puede_actuar_v051(uuid) from public,anon;
grant execute on function public.app_kombax_social_puede_actuar_v051(uuid) to authenticated;

create or replace function public.app_kombax_social_contactable_v041(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.kombax_social_perfiles sp
    left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
    where sp.id=p_social_id and sp.visible and sp.estado='activo' and sp.contacto_habilitado and (
      sp.sujeto_tipo='club'
      or (sp.sujeto_tipo='miembro' and exists(select 1 from public.identidades_sociales i join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id where i.id=sp.identidad_social_id and i.estado='activa' and s.estado='activo' and s.fecha_nacimiento is not null and extract(year from age(current_date,s.fecha_nacimiento))>=18))
      or (sp.sujeto_tipo='perfil_directo' and d.tipo in ('marca','federacion') and d.verificacion_estado='verificado' and public.app_kombax_perfil_servicio_activo_v071(d.id))
      or (sp.sujeto_tipo='perfil_directo' and d.tipo='competidor' and d.verificacion_estado='verificado' and public.app_kombax_perfil_servicio_activo_v071(d.id) and d.fecha_nacimiento_verificada is not null and extract(year from age(current_date,d.fecha_nacimiento_verificada))>=18)
    )
  );
$$;
revoke all on function public.app_kombax_social_contactable_v041(uuid) from public,anon;
grant execute on function public.app_kombax_social_contactable_v041(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Afiliación canónica: sigue siendo visible tras promover al Miembro a Competidor.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_social_afiliacion_v072(p_social_id uuid)
returns jsonb language sql stable security definer set search_path=public as $$
  with target as(
    select sp.*,case when sp.sujeto_tipo='miembro' then sp.identidad_social_id when sp.sujeto_tipo='perfil_directo' and d.tipo='competidor' then d.origen_identidad_social_id else null end identity_id
    from public.kombax_social_perfiles sp left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id where sp.id=p_social_id
  )
  select case when i.afiliacion_visible and i.estado='activa' and s.estado='activo' then jsonb_build_object(
    'club_id',c.id,'club_nombre',c.nombre,'club_social_id',csp.id,'club_social_slug',csp.slug,'verificada',true,'fuente','membresia_club'
  ) else null end
  from target t join public.identidades_sociales i on i.id=t.identity_id join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id
  join public.clubes c on c.id=i.club_origen_id
  left join lateral(select x.id,x.slug from public.kombax_social_perfiles x where x.sujeto_tipo='club' and x.club_id=c.id and x.estado='activo' and x.visible order by x.creado_en limit 1)csp on true
  where t.estado='activo' and t.visible;
$$;
revoke all on function public.app_kombax_social_afiliacion_v072(uuid) from public,anon,authenticated;

notify pgrst,'reload schema';
commit;
