-- KOMBAX 20.101 R21 · Sistema global de encuadre multimedia.
-- Aditivo e idempotente: conserva los archivos originales y almacena solo presentación visual.
begin;

alter table public.kombax_evento_participantes_publicos add column if not exists media_presentation jsonb not null default '{}'::jsonb;
alter table public.kombax_evento_media add column if not exists media_presentation jsonb not null default '{}'::jsonb;
alter table public.kombax_social_media add column if not exists media_presentation jsonb not null default '{}'::jsonb;
alter table public.kombax_perfil_media add column if not exists media_presentation jsonb not null default '{}'::jsonb;
alter table public.kombax_club_media add column if not exists media_presentation jsonb not null default '{}'::jsonb;
alter table public.publicaciones_comunidad add column if not exists media_presentation jsonb not null default '{}'::jsonb;
alter table public.kombax_showcase_elementos add column if not exists imagen_presentacion jsonb not null default '{}'::jsonb;
alter table public.material_catalogo add column if not exists media_presentation jsonb not null default '{}'::jsonb;
alter table public.comunicaciones add column if not exists media_presentation jsonb not null default '{}'::jsonb;

create or replace function public.app_kombax_media_presentation_normalize_v187(p_value jsonb)
returns jsonb
language plpgsql immutable
set search_path=public
as $$
declare
  v jsonb:=case when jsonb_typeof(coalesce(p_value,'{}'::jsonb))='object' then coalesce(p_value,'{}'::jsonb) else '{}'::jsonb end;
  v_fit text:=lower(coalesce(v->>'fit','auto'));
  v_orientation text:=lower(coalesce(v->>'orientation','auto'));
  v_x numeric;v_y numeric;v_zoom numeric;
begin
  if v_fit not in ('auto','cover','contain') then v_fit:='auto'; end if;
  if v_orientation not in ('auto','portrait','landscape','square') then v_orientation:='auto'; end if;
  begin v_x:=(v->>'focus_x')::numeric; exception when others then v_x:=50; end;
  begin v_y:=(v->>'focus_y')::numeric; exception when others then v_y:=50; end;
  begin v_zoom:=(v->>'zoom')::numeric; exception when others then v_zoom:=1; end;
  v_x:=greatest(0,least(100,coalesce(v_x,50)));
  v_y:=greatest(0,least(100,coalesce(v_y,50)));
  v_zoom:=greatest(1,least(2.5,coalesce(v_zoom,1)));
  return jsonb_build_object('fit',v_fit,'focus_x',round(v_x,2),'focus_y',round(v_y,2),'zoom',round(v_zoom,2),'orientation',v_orientation);
end $$;
revoke all on function public.app_kombax_media_presentation_normalize_v187(jsonb) from public,anon,authenticated;

create or replace function public.app_kombax_media_presentation_set_v187(p_scope text,p_target_id uuid,p_presentation jsonb)
returns jsonb
language plpgsql security definer
set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_scope text:=lower(btrim(coalesce(p_scope,'')));
  v_p jsonb:=public.app_kombax_media_presentation_normalize_v187(p_presentation);
  v_event uuid;v_social uuid;v_brand uuid;v_club uuid;v_author uuid;v_direct uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_target_id is null then raise exception 'MEDIA_PRESENTATION_TARGET_REQUIRED'; end if;

  if v_scope='event_participant' then
    select evento_id into v_event from public.kombax_evento_participantes_publicos where id=p_target_id;
    if v_event is null or not public.app_kombax_evento_puede_gestionar_v160(v_event) then raise exception 'EVENTS_MANAGE_DENIED'; end if;
    update public.kombax_evento_participantes_publicos set media_presentation=v_p,actualizado_en=now() where id=p_target_id;
  elsif v_scope='event_media' then
    select evento_id into v_event from public.kombax_evento_media where id=p_target_id;
    if v_event is null or not public.app_kombax_evento_puede_gestionar_v160(v_event) then raise exception 'EVENTS_MANAGE_DENIED'; end if;
    update public.kombax_evento_media set media_presentation=v_p,actualizado_en=now() where id=p_target_id;
  elsif v_scope='social_media' then
    select social_profile_id into v_social from public.kombax_social_media where id=p_target_id;
    if v_social is null or not public.app_kombax_social_puede_actuar_v051(v_social) then raise exception 'KOMBAX_SOCIAL_MEDIA_FORBIDDEN'; end if;
    update public.kombax_social_media set media_presentation=v_p,actualizado_en=now() where id=p_target_id;
  elsif v_scope='profile_media' then
    select perfil_directo_id into v_direct from public.kombax_perfil_media where id=p_target_id;
    if v_direct is null or not exists(select 1 from public.perfiles_kombax_directos d where d.id=v_direct and d.perfil_id=v_uid) then raise exception 'KOMBAX_PROFILE_MEDIA_FORBIDDEN'; end if;
    update public.kombax_perfil_media set media_presentation=v_p,actualizado_en=now() where id=p_target_id;
  elsif v_scope='club_media' then
    select club_id into v_club from public.kombax_club_media where id=p_target_id;
    if v_club is null or (not public.app_puede_gestionar_perfil_club_v035(v_club) and not public.app_kombax_es_moderador_v041()) then raise exception 'KOMBAX_CLUB_ALBUM_FORBIDDEN'; end if;
    update public.kombax_club_media set media_presentation=v_p,actualizado_en=now() where id=p_target_id;
  elsif v_scope='community_post' then
    select club_id,autor_perfil_id into v_club,v_author from public.publicaciones_comunidad where id=p_target_id;
    if v_club is null or not public.es_miembro_club(v_club) or (v_author<>v_uid and not public.tiene_rol_club(v_club,'direccion','secretaria','comunicacion')) then raise exception 'COMMUNITY_MEDIA_FORBIDDEN'; end if;
    update public.publicaciones_comunidad set media_presentation=v_p where id=p_target_id;
  elsif v_scope='showcase_item' then
    select marca_id into v_brand from public.kombax_showcase_elementos where id=p_target_id;
    if v_brand is null or not public.app_kombax_showcase_puede_gestionar_v045(v_brand) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED'; end if;
    update public.kombax_showcase_elementos set imagen_presentacion=v_p,actualizado_en=now() where id=p_target_id;
  elsif v_scope='material_item' then
    select club_id into v_club from public.material_catalogo where id=p_target_id;
    if v_club is null or not public.tiene_rol_club(v_club,'direccion','economia','secretaria') then raise exception 'MATERIAL_MEDIA_FORBIDDEN'; end if;
    update public.material_catalogo set media_presentation=v_p where id=p_target_id;
  elsif v_scope='communication' then
    select club_id into v_club from public.comunicaciones where id=p_target_id;
    if v_club is null or not public.tiene_rol_club(v_club,'direccion','secretaria','comunicacion') then raise exception 'COMMUNICATION_MEDIA_FORBIDDEN'; end if;
    update public.comunicaciones set media_presentation=v_p where id=p_target_id;
  else
    raise exception 'MEDIA_PRESENTATION_SCOPE_INVALID';
  end if;
  return jsonb_build_object('id',p_target_id,'scope',v_scope,'presentation',v_p);
end $$;
revoke all on function public.app_kombax_media_presentation_set_v187(text,uuid,jsonb) from public,anon;
grant execute on function public.app_kombax_media_presentation_set_v187(text,uuid,jsonb) to authenticated;

-- Lector compacto para enriquecer RPC históricos sin reescribir sus contratos.
-- Solo devuelve metadatos visuales de recursos que ya son públicos/visibles.
create or replace function public.app_kombax_media_presentations_v187(p_scope text,p_ids uuid[])
returns table(id uuid,presentation jsonb)
language plpgsql stable security definer
set search_path=public,auth
as $$
declare v_scope text:=lower(btrim(coalesce(p_scope,'')));begin
  if coalesce(array_length(p_ids,1),0)=0 then return; end if;
  if v_scope='event_participant' then
    return query select p.id,coalesce(p.media_presentation,'{}'::jsonb) from public.kombax_evento_participantes_publicos p where p.id=any(p_ids) and coalesce(p.visible_publico,true)=true and p.estado_inscripcion='aceptada';
  elsif v_scope='event_media' then
    return query select m.id,coalesce(m.media_presentation,'{}'::jsonb) from public.kombax_evento_media m where m.id=any(p_ids) and m.estado='visible';
  elsif v_scope='social_media' then
    return query select m.id,coalesce(m.media_presentation,'{}'::jsonb) from public.kombax_social_media m where m.id=any(p_ids) and m.estado='active' and coalesce(m.storage_bucket,'kombax-public-media')='kombax-public-media';
  elsif v_scope='profile_media' then
    return query select m.id,coalesce(m.media_presentation,'{}'::jsonb) from public.kombax_perfil_media m where m.id=any(p_ids) and m.estado='active';
  elsif v_scope='club_media' then
    return query select m.id,coalesce(m.media_presentation,'{}'::jsonb) from public.kombax_club_media m where m.id=any(p_ids) and m.estado='active';
  elsif v_scope='showcase_item' then
    return query select e.id,coalesce(e.imagen_presentacion,'{}'::jsonb) from public.kombax_showcase_elementos e where e.id=any(p_ids) and e.estado='publicado';
  elsif v_scope='material_item' then
    if auth.uid() is null then return; end if;
    return query select m.id,coalesce(m.media_presentation,'{}'::jsonb) from public.material_catalogo m where m.id=any(p_ids) and public.es_miembro_club(m.club_id);
  else
    return;
  end if;
end $$;
revoke all on function public.app_kombax_media_presentations_v187(text,uuid[]) from public;
grant execute on function public.app_kombax_media_presentations_v187(text,uuid[]) to anon,authenticated;

notify pgrst,'reload schema';
commit;
