-- KOMBAX 20.101 R35 · Event-centric preparation privacy hardening
-- Daily weight history is not granted by generic event roles.
-- Coaches/preparation team require an explicit preparation grant; club direction/coordinator retain administrative access.

begin;

create or replace function public.app_kombax_preparation_can_v216(p_preparation_id uuid,p_action text default 'read')
returns boolean
language plpgsql stable security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_p public.kombax_competition_preparations_v216%rowtype;
  v_action text:=lower(coalesce(nullif(trim(p_action),''),'read'));
  v_profile_access text;
begin
  if v_uid is null or p_preparation_id is null then return false; end if;
  if v_action not in ('read','log','verify','manage','official_verify') then return false; end if;
  -- R35 separates the official event weigh-in from the private preparation log.
  if v_action='official_verify' then return false; end if;

  select * into v_p from public.kombax_competition_preparations_v216 where id=p_preparation_id;
  if not found then return false; end if;
  if public.app_kombax_es_platform_admin_v055() then return true; end if;

  if v_p.competitor_profile_id is not null then
    v_profile_access:=case when v_action='read' then 'read' when v_action in ('log','verify') then 'edit' else 'admin' end;
    if public.app_kombax_puede_gestionar_perfil_v070(v_p.competitor_profile_id,v_profile_access) then return true; end if;
    if v_action in ('read','log','verify') and exists(
      select 1 from public.kombax_professional_delegations_v198 d
      where d.target_profile_id=v_p.competitor_profile_id and d.status='accepted'
        and (d.starts_at is null or d.starts_at<=now()) and (d.expires_at is null or d.expires_at>now())
        and public.app_kombax_puede_gestionar_perfil_v070(d.professional_profile_id,'read')
    ) then return true; end if;
  end if;

  if v_p.socio_id is not null then
    if v_action='read' and public.puede_ver_socio(v_p.socio_id) then return true; end if;
    if exists(select 1 from public.socios s where s.id=v_p.socio_id and s.perfil_id=v_uid) then return true; end if;
  end if;

  -- Club administration can manage; monitors/coaches are intentionally not implicit.
  -- They are added through kombax_preparation_access_v216 for the concrete preparation.
  if v_p.club_id is not null and exists(
    select 1 from public.miembros_club mc
    where mc.club_id=v_p.club_id and mc.perfil_id=v_uid and mc.activo
      and (mc.rol::text='direccion' or mc.coordinacion)
  ) then return true; end if;

  if exists(
    select 1 from public.kombax_preparation_access_v216 a
    where a.preparation_id=v_p.id and a.perfil_id=v_uid and a.status='active'
      and (
        (v_action='read' and 'read'=any(a.permissions)) or
        (v_action='log' and ('log'=any(a.permissions) or 'manage'=any(a.permissions))) or
        (v_action='verify' and ('verify'=any(a.permissions) or 'manage'=any(a.permissions))) or
        (v_action='manage' and 'manage'=any(a.permissions))
      )
  ) then return true; end if;
  return false;
end $$;
revoke all on function public.app_kombax_preparation_can_v216(uuid,text) from public,anon,service_role;
grant execute on function public.app_kombax_preparation_can_v216(uuid,text) to authenticated;

create or replace function public.app_kombax_public_registration_private_manager_v218(p_registration_id uuid)
returns boolean language plpgsql stable security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_r public.kombax_evento_participantes_publicos%rowtype;
  v_competitor_social public.kombax_social_perfiles%rowtype;
  v_presenter_social public.kombax_social_perfiles%rowtype;
  v_identity public.identidades_sociales%rowtype;
begin
  if v_uid is null or p_registration_id is null then return false; end if;
  select * into v_r from public.kombax_evento_participantes_publicos where id=p_registration_id;
  if not found then return false; end if;
  if public.app_kombax_es_platform_admin_v055() then return true; end if;

  -- Athlete/guardian/direct profile owner.
  if v_r.competidor_social_profile_id is not null then
    select * into v_competitor_social from public.kombax_social_perfiles where id=v_r.competidor_social_profile_id;
    if found then
      if v_competitor_social.sujeto_tipo='perfil_directo' and v_competitor_social.perfil_directo_id is not null
         and public.app_kombax_puede_gestionar_perfil_v070(v_competitor_social.perfil_directo_id,'edit') then
        return true;
      end if;
      if v_competitor_social.sujeto_tipo='miembro' and v_competitor_social.identidad_social_id is not null then
        select * into v_identity from public.identidades_sociales where id=v_competitor_social.identidad_social_id;
        if found and v_identity.socio_origen_id is not null and public.puede_ver_socio(v_identity.socio_origen_id) then return true; end if;
      end if;
    end if;
  end if;

  -- Presenting club: only direction/coordinator can activate/manage the private preparation.
  if v_r.presentado_por_social_profile_id is not null then
    select * into v_presenter_social from public.kombax_social_perfiles where id=v_r.presentado_por_social_profile_id;
    if found and v_presenter_social.sujeto_tipo='club' and v_presenter_social.club_id is not null and exists(
      select 1 from public.miembros_club mc
      where mc.club_id=v_presenter_social.club_id and mc.perfil_id=v_uid and mc.activo
        and (mc.rol::text='direccion' or mc.coordinacion)
    ) then return true; end if;
  end if;
  return false;
end $$;
revoke all on function public.app_kombax_public_registration_private_manager_v218(uuid) from public,anon,service_role;
grant execute on function public.app_kombax_public_registration_private_manager_v218(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
