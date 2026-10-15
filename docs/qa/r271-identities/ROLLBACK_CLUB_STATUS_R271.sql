begin;
CREATE OR REPLACE FUNCTION public.app_kombax_social_estado_v124(p_club_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v jsonb;
  v_uid uuid:=auth.uid();
  v_confirmed boolean:=false;
  v_identity public.identidades_sociales;
begin
  v:=public.app_kombax_social_estado_v123(p_club_id);
  if v_uid is null then return v; end if;

  select * into v_identity
  from public.identidades_sociales
  where perfil_id=v_uid
  limit 1;

  if v_identity.id is not null then
    v_confirmed:=public.app_kombax_member_membership_confirmed_r115(p_club_id);
    return v||jsonb_build_object(
      'scope','member',
      'status',case when v_identity.estado='activa' then 'activa' else 'inactiva' end,
      'eligible',v_identity.estado='activa',
      'membership_confirmed',v_confirmed,
      'publication_enabled',v_confirmed and v_identity.estado='activa',
      'album_enabled',v_identity.estado='activa',
      'profile_enabled',v_identity.estado='activa',
      'reason',case
        when v_identity.estado<>'activa' then 'Tu perfil público está suspendido o cerrado.'
        when v_confirmed then 'Tu perfil público está activo y tu club ha confirmado la membresía.'
        else 'Tu perfil público está activo. Podrás publicar en KOMBAX Social cuando un club confirme tu membresía.'
      end
    );
  end if;

  if exists(select 1 from public.perfiles p where p.id=v_uid) then
    return v||jsonb_build_object(
      'scope','person',
      'status','inactiva',
      'eligible',true,
      'membership_confirmed',false,
      'publication_enabled',false,
      'album_enabled',true,
      'profile_enabled',true,
      'reason','Tu cuenta KOMBAX puede activar un único Perfil Social personal. Las facetas Competidor y Profesional se añaden sobre esta misma identidad.'
    );
  end if;

  return v;
end $function$
;
CREATE OR REPLACE FUNCTION public.app_kombax_social_puede_actuar_v051(p_social_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
  select exists(
    select 1 from public.kombax_social_perfiles sp
    where sp.id=p_social_id and sp.visible and sp.estado='activo' and sp.publicar_habilitado and (
      (sp.sujeto_tipo='miembro' and exists(
        select 1
        from public.identidades_sociales i
        join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id
        join public.miembros_club mc on mc.club_id=s.club_id and mc.perfil_id=auth.uid() and mc.rol='alumno' and mc.activo
        where i.id=sp.identidad_social_id
          and i.perfil_id=auth.uid()
          and i.estado='activa'
          and s.perfil_id=auth.uid()
          and s.estado='activo'
          and s.kombax_acceso_estado='activo'
          and s.fecha_nacimiento is not null
          and extract(year from age(current_date,s.fecha_nacimiento))>=14
      ))
      or (sp.sujeto_tipo='club'
        and public.app_kombax_club_permiso_v051(sp.club_id,'social.publish')
        and public.app_kombax_club_permiso_v051(sp.club_id,'social.act_as_club')
        and (
          exists(select 1 from public.kombax_solicitudes_alta a where a.club_id=sp.club_id and a.tipo='club' and a.estado='verified')
          or exists(select 1 from kombax_commercial.pilot_club_activations_r110 pilot where pilot.club_id=sp.club_id and pilot.activation_status='active')
        ))
      or (sp.sujeto_tipo='perfil_directo' and exists(
        select 1 from public.perfiles_kombax_directos d
        where d.id=sp.perfil_directo_id and d.perfil_id=auth.uid()
          and d.estado='activo' and d.verificacion_estado='verificado' and d.social_activo
          and (
            d.tipo in ('marca','federacion','media')
            or (d.tipo='competidor' and d.fecha_nacimiento_verificada is not null
                and d.fecha_nacimiento_verificada<=current_date-interval '16 years')
            or (d.tipo='profesional' and exists(
              select 1 from public.kombax_perfil_persona_privada_v196 p
              where p.perfil_directo_id=d.id and public.app_kombax_profile_age_v196(p.fecha_nacimiento)>=18
            ))
          )
      ))
    )
  );
$function$
;
CREATE OR REPLACE FUNCTION public.app_kombax_social_puede_gestionar_perfil_publico_r117(p_social_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
  select auth.uid() is not null and exists(
    select 1
    from public.kombax_social_perfiles sp
    left join public.identidades_sociales i
      on sp.sujeto_tipo='miembro' and i.id=sp.identidad_social_id
    left join public.perfiles_kombax_directos d
      on sp.sujeto_tipo='perfil_directo' and d.id=sp.perfil_directo_id
    where sp.id=p_social_id
      and sp.estado in ('activo','limitado')
      and (
        (sp.sujeto_tipo='miembro'
          and i.perfil_id=auth.uid()
          and i.estado='activa')
        or
        (sp.sujeto_tipo='perfil_directo'
          and d.perfil_id=auth.uid()
          and d.estado not in ('suspendido','cerrado'))
        or public.app_kombax_social_puede_actuar_v051(sp.id)
      )
  );
$function$
;
drop table if exists private.kombax_social_demo_clubs_r271;
notify pgrst,'reload schema';
commit;

