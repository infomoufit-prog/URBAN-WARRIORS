-- KOMBAX 20.101 R21 · Cierre global de encuadre multimedia.
-- Extiende el sistema R21 a avatar privado, perfil deportivo, branding de club,
-- perfil público de club y galería secundaria de Showcase.
begin;

alter table public.perfiles add column if not exists avatar_presentation jsonb not null default '{}'::jsonb;
alter table public.perfiles_deportivos add column if not exists foto_presentation jsonb not null default '{}'::jsonb;
alter table public.clubes add column if not exists logo_presentation jsonb not null default '{}'::jsonb;
alter table public.clubes add column if not exists portada_presentation jsonb not null default '{}'::jsonb;
alter table public.perfiles_club_publicos add column if not exists logo_presentation jsonb not null default '{}'::jsonb;
alter table public.perfiles_club_publicos add column if not exists portada_presentation jsonb not null default '{}'::jsonb;
alter table public.kombax_showcase_elementos add column if not exists galeria_presentacion jsonb not null default '{}'::jsonb;

create or replace function public.app_kombax_media_presentation_set_v188(p_scope text,p_target_id uuid,p_presentation jsonb)
returns jsonb
language plpgsql security definer
set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_scope text:=lower(btrim(coalesce(p_scope,'')));
  v_p jsonb:=public.app_kombax_media_presentation_normalize_v187(p_presentation);
  v_club uuid; v_slot text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_target_id is null then raise exception 'MEDIA_PRESENTATION_TARGET_REQUIRED'; end if;

  if v_scope in ('event_participant','event_media','social_media','profile_media','club_media','community_post','showcase_item','material_item','communication') then
    return public.app_kombax_media_presentation_set_v187(v_scope,p_target_id,v_p);
  elsif v_scope='private_avatar' then
    if p_target_id<>v_uid then raise exception 'PROFILE_MEDIA_FORBIDDEN'; end if;
    update public.perfiles set avatar_presentation=v_p,actualizado_en=now() where id=v_uid;
  elsif v_scope='sports_profile' then
    if not public.app_puede_editar_perfil_deportivo_v032(p_target_id) then raise exception 'SPORTS_PROFILE_EDIT_DENIED'; end if;
    select club_id into v_club from public.socios where id=p_target_id;
    update public.perfiles_deportivos set foto_presentation=v_p,actualizado_en=now() where club_id=v_club and socio_id=p_target_id;
  elsif v_scope in ('club_brand_logo','club_brand_cover') then
    v_club:=p_target_id;
    if not public.app_puede_publicar_branding_v039(v_club) then raise exception 'BRANDING_MANAGE_DENIED'; end if;
    if v_scope='club_brand_logo' then update public.clubes set logo_presentation=v_p,actualizado_en=now() where id=v_club;
    else update public.clubes set portada_presentation=v_p,actualizado_en=now() where id=v_club; end if;
  elsif v_scope in ('club_public_logo','club_public_cover') then
    v_club:=p_target_id;
    if not public.app_puede_gestionar_perfil_club_v035(v_club) and not public.app_kombax_es_moderador_v041() then raise exception 'CLUB_PUBLIC_MEDIA_FORBIDDEN'; end if;
    if v_scope='club_public_logo' then update public.perfiles_club_publicos set logo_presentation=v_p,actualizado_en=now() where club_id=v_club;
    else update public.perfiles_club_publicos set portada_presentation=v_p,actualizado_en=now() where club_id=v_club; end if;
  elsif v_scope ~ '^showcase_gallery_[0-2]$' then
    v_slot:=substring(v_scope from '([0-2])$');
    if not exists(select 1 from public.kombax_showcase_elementos e where e.id=p_target_id and public.app_kombax_showcase_puede_gestionar_v045(e.marca_id)) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
    update public.kombax_showcase_elementos set galeria_presentacion=jsonb_set(coalesce(galeria_presentacion,'{}'::jsonb),array[v_slot],v_p,true),actualizado_en=now() where id=p_target_id;
  else
    raise exception 'MEDIA_PRESENTATION_SCOPE_INVALID';
  end if;
  return jsonb_build_object('id',p_target_id,'scope',v_scope,'presentation',v_p);
end $$;
revoke all on function public.app_kombax_media_presentation_set_v188(text,uuid,jsonb) from public,anon;
grant execute on function public.app_kombax_media_presentation_set_v188(text,uuid,jsonb) to authenticated;

create or replace function public.app_kombax_media_presentations_v188(p_scope text,p_ids uuid[])
returns table(id uuid,presentation jsonb)
language plpgsql stable security definer
set search_path=public,auth
as $$
declare v_scope text:=lower(btrim(coalesce(p_scope,''))); v_slot text; begin
  if coalesce(array_length(p_ids,1),0)=0 then return; end if;
  if v_scope in ('event_participant','event_media','social_media','profile_media','club_media','showcase_item','material_item') then
    return query select * from public.app_kombax_media_presentations_v187(v_scope,p_ids); return;
  elsif v_scope='private_avatar' then
    if auth.uid() is null then return; end if;
    return query select p.id,coalesce(p.avatar_presentation,'{}'::jsonb) from public.perfiles p where p.id=any(p_ids) and p.id=auth.uid();
  elsif v_scope='sports_profile' then
    if auth.uid() is null then return; end if;
    return query select pd.socio_id,coalesce(pd.foto_presentation,'{}'::jsonb) from public.perfiles_deportivos pd where pd.socio_id=any(p_ids) and public.app_puede_ver_perfil_deportivo_v032(pd.club_id,pd.socio_id);
  elsif v_scope in ('club_brand_logo','club_brand_cover') then
    if auth.uid() is null then return; end if;
    if v_scope='club_brand_logo' then return query select c.id,coalesce(c.logo_presentation,'{}'::jsonb) from public.clubes c where c.id=any(p_ids) and public.es_miembro_club(c.id);
    else return query select c.id,coalesce(c.portada_presentation,'{}'::jsonb) from public.clubes c where c.id=any(p_ids) and public.es_miembro_club(c.id); end if;
  elsif v_scope in ('club_public_logo','club_public_cover') then
    if v_scope='club_public_logo' then return query select p.club_id,coalesce(p.logo_presentation,'{}'::jsonb) from public.perfiles_club_publicos p where p.club_id=any(p_ids) and p.visible and not p.moderacion_oculta;
    else return query select p.club_id,coalesce(p.portada_presentation,'{}'::jsonb) from public.perfiles_club_publicos p where p.club_id=any(p_ids) and p.visible and not p.moderacion_oculta; end if;
  elsif v_scope ~ '^showcase_gallery_[0-2]$' then
    v_slot:=substring(v_scope from '([0-2])$');
    return query select e.id,coalesce(e.galeria_presentacion->v_slot,'{}'::jsonb) from public.kombax_showcase_elementos e where e.id=any(p_ids) and e.estado='publicado';
  else return;
  end if;
end $$;
revoke all on function public.app_kombax_media_presentations_v188(text,uuid[]) from public;
grant execute on function public.app_kombax_media_presentations_v188(text,uuid[]) to anon,authenticated;
notify pgrst,'reload schema';
commit;
