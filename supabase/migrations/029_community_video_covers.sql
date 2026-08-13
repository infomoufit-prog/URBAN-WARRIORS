-- Release I: vídeos 50 MB/1080p y portadas automática/manual gobernadas.
begin;

alter table public.publicaciones_comunidad
  add column if not exists portada_automatica_path text,
  add column if not exists portada_manual_path text;

update storage.buckets
set file_size_limit=52428800,
    allowed_mime_types=array['image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime']::text[]
where id='community-media';

do $migration$
begin
  if to_regprocedure('public.app_mutate_v160_pre_video_029(text,jsonb,uuid)') is null then
    if to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is null then raise exception '029: falta app_mutate_v160'; end if;
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_video_029;
  end if;
end
$migration$;
revoke all on function public.app_mutate_v160_pre_video_029(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_club uuid;
  v_existing public.app_mutation_requests;
  v_post public.publicaciones_comunidad;
  v_result jsonb;
  v_data jsonb;
  v_id uuid;
  v_auto text;
  v_manual text;
  v_old_manual text;
  v_width integer;
  v_height integer;
  v_bytes bigint;
  v_can_cover boolean:=false;
begin
  if p_operation not in ('comunidad.publicar','comunidad.eliminar','comunidad.moderar') then
    return public.app_mutate_v160_pre_video_029(p_operation,p_payload,p_request_id);
  end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  begin v_club:=nullif(v_payload->>'club_id','')::uuid; exception when others then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
  begin v_id:=nullif(v_payload->>'publicacion_id','')::uuid; exception when others then v_id:=null; end;

  if p_operation='comunidad.moderar' and v_payload->>'accion'='portada' then
    if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
    if v_club is null or not public.es_miembro_club(v_club) then raise exception 'MUTATION_MEMBERSHIP_REQUIRED'; end if;
    select public.tiene_rol_club(v_club,'direccion') or exists(
      select 1 from public.miembros_club m where m.club_id=v_club and m.perfil_id=v_uid and m.activo and m.coordinacion
    ) into v_can_cover;
    if not v_can_cover then raise exception 'Solo Gestor o Coordinación pueden cambiar la portada'; end if;
    v_manual:=nullif(v_payload->>'portada_manual_path','');
    if v_id is null or v_manual is null then raise exception 'Publicación y portada son obligatorias'; end if;
    if strpos(v_manual,v_club::text||'/'||v_uid::text||'/')<>1 then raise exception 'Path de portada no autorizado'; end if;
    select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
    if v_existing.request_id is not null then
      if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
      if v_existing.result is not null then return v_existing.result; end if;
    else
      insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,v_club,p_operation);
    end if;
    select * into v_post from public.publicaciones_comunidad where club_id=v_club and id=v_id for update;
    if v_post.id is null or v_post.media_tipo<>'video' then raise exception 'Vídeo no encontrado'; end if;
    v_old_manual:=v_post.portada_manual_path;
    update public.publicaciones_comunidad set portada_manual_path=v_manual where id=v_id returning * into v_post;
    v_data:=to_jsonb(v_post)||jsonb_build_object('old_cover_path',v_old_manual);
    v_result:=jsonb_build_object('ok',true,'backend_version','1.6.0','operation',p_operation,'request_id',p_request_id,'data',v_data);
    update public.app_mutation_requests set result=v_result,completed_at=now(),club_id=v_club where request_id=p_request_id;
    return v_result;
  end if;

  if p_operation='comunidad.publicar' and lower(coalesce(v_payload->>'media_tipo',''))='video' then
    begin v_width:=nullif(v_payload->>'media_width','')::integer; exception when others then v_width:=null; end;
    begin v_height:=nullif(v_payload->>'media_height','')::integer; exception when others then v_height:=null; end;
    begin v_bytes:=nullif(v_payload->>'media_size_bytes','')::bigint; exception when others then v_bytes:=null; end;
    v_auto:=nullif(v_payload->>'portada_automatica_path','');v_manual:=nullif(v_payload->>'portada_manual_path','');
    if v_width is null or v_height is null or greatest(v_width,v_height)>1920 or least(v_width,v_height)>1080 then raise exception 'El vídeo debe tener resolución máxima 1080p'; end if;
    if v_bytes is null or v_bytes>52428800 then raise exception 'El vídeo supera 50 MB'; end if;
    if v_auto is null then raise exception 'La portada automática es obligatoria'; end if;
    if v_club is null or strpos(v_auto,v_club::text||'/'||v_uid::text||'/')<>1 then raise exception 'Path de portada automática no autorizado'; end if;
    if v_manual is not null then
      select public.tiene_rol_club(v_club,'direccion') or exists(
        select 1 from public.miembros_club m where m.club_id=v_club and m.perfil_id=v_uid and m.activo and m.coordinacion
      ) into v_can_cover;
      if not v_can_cover then raise exception 'Solo Gestor o Coordinación pueden elegir portada manual'; end if;
      if strpos(v_manual,v_club::text||'/'||v_uid::text||'/')<>1 then raise exception 'Path de portada manual no autorizado'; end if;
    end if;
  elsif p_operation='comunidad.eliminar' and v_club is not null and v_id is not null then
    select portada_automatica_path,portada_manual_path into v_auto,v_manual from public.publicaciones_comunidad where club_id=v_club and id=v_id;
  end if;

  v_result:=public.app_mutate_v160_pre_video_029(p_operation,p_payload,p_request_id);
  if p_operation='comunidad.publicar' and lower(coalesce(v_payload->>'media_tipo',''))='video' then
    v_data:=coalesce(v_result->'data','{}'::jsonb);v_id:=nullif(v_data->>'id','')::uuid;
    update public.publicaciones_comunidad set portada_automatica_path=v_auto,portada_manual_path=v_manual where id=v_id;
    v_data:=v_data||jsonb_build_object('portada_automatica_path',v_auto,'portada_manual_path',v_manual);
  elsif p_operation='comunidad.eliminar' then
    v_data:=coalesce(v_result->'data','{}'::jsonb);
    v_data:=v_data||jsonb_build_object(
      'portada_automatica_path',coalesce(v_auto,v_data->>'portada_automatica_path'),
      'portada_manual_path',coalesce(v_manual,v_data->>'portada_manual_path')
    );
  else
    return v_result;
  end if;
  v_result:=jsonb_set(v_result,'{data}',v_data,true);
  update public.app_mutation_requests set result=v_result where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end
$$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;

select
  to_regprocedure('public.app_mutate_v160_pre_video_029(text,jsonb,uuid)') is not null as rollback_ok,
  (select file_size_limit from storage.buckets where id='community-media')=52428800 as bucket_50mb_ok;
