-- KOMBAX R115 · Pilot freeze onboarding / membership authority / Social gate
-- Principle: a free account is not automatically Spectator and self-declaring as
-- Member/Practitioner never grants Social publishing. The club-confirmed active
-- membership remains the authority. Competitor stays autonomous after verification.

begin;

create or replace function public.app_kombax_member_membership_confirmed_r115(p_club_id uuid default null)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1
    from public.socios s
    join public.miembros_club mc
      on mc.club_id=s.club_id
     and mc.perfil_id=auth.uid()
     and mc.rol='alumno'
     and mc.activo
    where s.perfil_id=auth.uid()
      and s.estado='activo'
      and s.kombax_acceso_estado='activo'
      and (p_club_id is null or s.club_id=p_club_id)
  );
$$;
revoke all on function public.app_kombax_member_membership_confirmed_r115(uuid) from public,anon;
grant execute on function public.app_kombax_member_membership_confirmed_r115(uuid) to authenticated;

-- Harden the canonical publication/action gate without altering the direct-profile
-- rules introduced in R109. Member publication requires an active identity AND an
-- active club-approved membership represented in socios + miembros_club.
create or replace function public.app_kombax_social_puede_actuar_v051(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
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
        and public.app_kombax_club_permiso_v051(sp.club_id,'social.act_as_club'))
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
$$;
revoke all on function public.app_kombax_social_puede_actuar_v051(uuid) from public,anon;
grant execute on function public.app_kombax_social_puede_actuar_v051(uuid) to authenticated;

create or replace function public.app_kombax_social_puede_publicar_v041(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.app_kombax_social_puede_actuar_v051(p_social_id);
$$;
revoke all on function public.app_kombax_social_puede_publicar_v041(uuid) from public,anon;
grant execute on function public.app_kombax_social_puede_publicar_v041(uuid) to authenticated;

-- Latest read status. Preserve every R123 minor-safety decision, then make the
-- membership authority explicit so the UI cannot advertise member activation after
-- the club relationship has been suspended/revoked.
create or replace function public.app_kombax_social_estado_v124(p_club_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v jsonb;v_uid uuid:=auth.uid();
begin
  v:=public.app_kombax_social_estado_v123(p_club_id);
  if v_uid is null then return v; end if;
  if coalesce(v->>'scope','')='member' and not public.app_kombax_member_membership_confirmed_r115(p_club_id) then
    return v||jsonb_build_object(
      'status','inactiva','eligible',false,'membership_confirmed',false,
      'reason','Tu club debe confirmar una membresía activa antes de que puedas publicar en KOMBAX Social como Miembro/Practicante.'
    );
  end if;
  if coalesce(v->>'scope','')='member' then v:=v||jsonb_build_object('membership_confirmed',true); end if;
  return v;
end $$;
revoke all on function public.app_kombax_social_estado_v124(uuid) from public,anon;
grant execute on function public.app_kombax_social_estado_v124(uuid) to authenticated;

-- Latest mutation wrapper: activation/profile changes for the member identity are
-- impossible unless the club-approved membership is still active. Other identities
-- preserve R123/R109 behavior, including standalone Competitor verification.
create or replace function public.app_kombax_identity_mutate_v124(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_club uuid;
begin
  if p_operation in ('kombax.identity.member.activate','kombax.identity.member.profile.update') then
    begin v_club:=nullif(p_payload->>'club_id','')::uuid; exception when others then v_club:=null; end;
    if not public.app_kombax_member_membership_confirmed_r115(v_club) then
      raise exception 'KOMBAX_MEMBER_CLUB_CONFIRMATION_REQUIRED';
    end if;
  end if;
  return public.app_kombax_identity_mutate_v123(p_operation,p_payload,p_request_id);
end $$;
revoke all on function public.app_kombax_identity_mutate_v124(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_identity_mutate_v124(text,jsonb,uuid) to authenticated;

commit;
