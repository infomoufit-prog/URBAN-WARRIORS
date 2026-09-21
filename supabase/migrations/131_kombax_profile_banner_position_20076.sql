-- KOMBAX RC13 build 20076 · persistent banner focal-point positioning.
-- Stores the preferred visible area without destructively cropping the source image.
begin;

alter table public.kombax_social_perfiles
  add column if not exists banner_position_x numeric(5,2) not null default 50,
  add column if not exists banner_position_y numeric(5,2) not null default 50;

alter table public.kombax_social_perfiles
  drop constraint if exists kombax_social_banner_position_x_v131,
  drop constraint if exists kombax_social_banner_position_y_v131;

alter table public.kombax_social_perfiles
  add constraint kombax_social_banner_position_x_v131 check (banner_position_x between 0 and 100),
  add constraint kombax_social_banner_position_y_v131 check (banner_position_y between 0 and 100);

create or replace function public.app_kombax_social_banner_position_v131(
  p_social_id uuid,
  p_x numeric,
  p_y numeric
) returns jsonb
language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();
  v_x numeric(5,2):=round(least(100,greatest(0,coalesce(p_x,50)))::numeric,2);
  v_y numeric(5,2):=round(least(100,greatest(0,coalesce(p_y,50)))::numeric,2);
  v_profile public.kombax_social_perfiles;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_social_id is null then raise exception 'KOMBAX_SOCIAL_PROFILE_REQUIRED'; end if;
  if not public.app_kombax_social_puede_actuar_v051(p_social_id) then raise exception 'KOMBAX_SOCIAL_PROFILE_FORBIDDEN'; end if;

  update public.kombax_social_perfiles
     set banner_position_x=v_x,banner_position_y=v_y,actualizado_en=now()
   where id=p_social_id
   returning * into v_profile;
  if v_profile.id is null then raise exception 'KOMBAX_SOCIAL_PROFILE_NOT_FOUND'; end if;

  insert into public.kombax_actor_audit(actor_perfil_id,public_social_id,club_id,accion,objeto_tipo,objeto_id,detalle)
  values(v_uid,v_profile.id,v_profile.club_id,'social.profile.banner.position','social_profile',v_profile.id,
    jsonb_build_object('banner_position_x',v_x,'banner_position_y',v_y));

  return jsonb_build_object('ok',true,'social_profile_id',v_profile.id,'banner_position_x',v_x,'banner_position_y',v_y);
end $$;
revoke all on function public.app_kombax_social_banner_position_v131(uuid,numeric,numeric) from public,anon;
grant execute on function public.app_kombax_social_banner_position_v131(uuid,numeric,numeric) to authenticated;

-- Keep the existing canonical profile contract and enrich it with the persisted focal point.
do $$
begin
  if to_regprocedure('public.app_kombax_perfil_publico_v094(uuid)') is not null
     and to_regprocedure('public.app_kombax_perfil_publico_v094_pre_banner_v131(uuid)') is null then
    alter function public.app_kombax_perfil_publico_v094(uuid) rename to app_kombax_perfil_publico_v094_pre_banner_v131;
  end if;
end $$;

create or replace function public.app_kombax_perfil_publico_v094(p_social_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare
  v jsonb;
  v_x numeric(5,2);
  v_y numeric(5,2);
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  v:=public.app_kombax_perfil_publico_v094_pre_banner_v131(p_social_id);
  if v is null then return null; end if;
  select banner_position_x,banner_position_y into v_x,v_y from public.kombax_social_perfiles where id=p_social_id;
  v:=jsonb_set(v,'{banner_position_x}',to_jsonb(coalesce(v_x,50)),true);
  v:=jsonb_set(v,'{banner_position_y}',to_jsonb(coalesce(v_y,50)),true);
  return v;
end $$;
revoke all on function public.app_kombax_perfil_publico_v094(uuid) from public,anon;
grant execute on function public.app_kombax_perfil_publico_v094(uuid) to authenticated;

revoke all on function public.app_kombax_perfil_publico_v094_pre_banner_v131(uuid) from public,anon,authenticated;
grant execute on function public.app_kombax_perfil_publico_v094_pre_banner_v131(uuid) to service_role;

notify pgrst,'reload schema';
commit;
