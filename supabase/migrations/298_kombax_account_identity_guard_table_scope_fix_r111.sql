-- KOMBAX R111 · hotfix de alcance del trigger de identidad R100.
-- Recuperado del estado ya aplicado en Supabase para mantener la base acumulativa reconstruible.
begin;

create or replace function public.app_kombax_account_identity_guard_r100()
returns trigger
language plpgsql
security definer
set search_path to 'public','auth'
as $$
declare
  v_uid uuid:=new.perfil_id;
  v_type text:=new.tipo;
  v_other_type text;
  v_is_member boolean;
  v_is_club_admin boolean;
begin
  if tg_op='UPDATE' then
    if new.perfil_id=old.perfil_id and new.tipo=old.tipo then return new; end if;
  end if;

  -- Solo kombax_solicitudes_alta dispone de perfil_directo_id.
  if tg_table_name='kombax_solicitudes_alta' then
    if new.perfil_directo_id is not null
       and exists(
         select 1
         from public.perfiles_kombax_directos d
         where d.id=new.perfil_directo_id
           and d.perfil_id=v_uid
           and d.tipo=v_type
       )
    then
      return new;
    end if;
  end if;

  select exists(
    select 1 from public.miembros_club m
    where m.perfil_id=v_uid and m.activo and (m.rol='direccion' or m.coordinacion)
  ) into v_is_club_admin;

  select exists(
    select 1 from public.identidades_sociales i
    where i.perfil_id=v_uid and i.estado='activa'
  ) into v_is_member;

  if v_is_club_admin and v_type<>'club' then
    raise exception 'KOMBAX_ACCOUNT_TYPE_CLUB';
  end if;

  if v_is_member and not v_is_club_admin and v_type<>'competidor' then
    raise exception 'KOMBAX_MEMBER_ONLY_COMPETITOR';
  end if;

  -- Solo perfiles_kombax_directos dispone de origen_identidad_social_id.
  if tg_table_name='perfiles_kombax_directos' then
    if v_is_member and v_type='competidor' and new.origen_identidad_social_id is null then
      raise exception 'KOMBAX_COMPETITOR_MEMBER_SOURCE_REQUIRED';
    end if;
  end if;

  select prior.tipo into v_other_type
  from (
    select d.tipo
    from public.perfiles_kombax_directos d
    where d.perfil_id=v_uid and d.tipo<>'espectador'
    union all
    select a.tipo
    from public.kombax_solicitudes_alta a
    where a.perfil_id=v_uid
  ) prior
  where prior.tipo<>v_type
  limit 1;

  if v_other_type is not null then
    raise exception 'KOMBAX_ACCOUNT_TYPE_IMMUTABLE';
  end if;

  if v_type='club' and exists(
    select 1 from public.perfiles_kombax_directos d
    where d.perfil_id=v_uid and d.tipo='competidor'
  ) then
    raise exception 'KOMBAX_ACCOUNT_TYPE_IMMUTABLE';
  end if;

  return new;
end $$;

revoke all on function public.app_kombax_account_identity_guard_r100() from public,anon,authenticated;

notify pgrst,'reload schema';
commit;
