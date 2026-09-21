-- KOMBAX 20.101 R50 · KOMBAX Social publication media HD/MP4 up to 60 seconds.
-- Live rollout migration 1: feed/publication media + storage headroom + 1080p guard.
begin;

update storage.buckets
set file_size_limit=104857600,
    allowed_mime_types=array['image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime']::text[]
where id in ('kombax-public-media','kombax-restricted-media');

do $$
declare r record;
begin
  for r in
    select conname,pg_get_constraintdef(oid) as definition
    from pg_constraint
    where conrelid='public.kombax_social_media'::regclass and contype='c'
  loop
    if r.conname in ('kombax_social_media_bytes_check','kombax_social_media_check','kombax_social_media_bytes_r50','kombax_social_media_format_duration_r50','kombax_social_media_bytes_r50_ck','kombax_social_media_contract_r50_ck')
       or r.definition ilike '%duration_seconds%'
       or (r.definition ilike '%bytes%' and r.definition ilike '%26214400%') then
      execute format('alter table public.kombax_social_media drop constraint %I',r.conname);
    end if;
  end loop;
end $$;

alter table public.kombax_social_media
  add constraint kombax_social_media_bytes_r50_ck check(
    (tipo='video' and bytes between 1 and 104857600)
    or (tipo<>'video' and bytes between 1 and 26214400)
  ),
  add constraint kombax_social_media_contract_r50_ck check(
    (tipo='video' and mime_type in ('video/mp4','video/webm','video/quicktime') and duration_seconds is not null and duration_seconds>0 and duration_seconds<=60.2)
    or (tipo in ('avatar','banner','photo') and mime_type in ('image/jpeg','image/png','image/webp') and duration_seconds is null)
  );

create or replace function public.app_kombax_social_video_hd_guard_v241()
returns trigger language plpgsql set search_path=public as $$
declare v_validate boolean:=false;
begin
  if new.tipo='video' then
    if tg_op='INSERT' then v_validate:=true;
    else v_validate:=new.bytes is distinct from old.bytes
      or new.mime_type is distinct from old.mime_type
      or new.duration_seconds is distinct from old.duration_seconds
      or new.width is distinct from old.width
      or new.height is distinct from old.height;
    end if;
    if v_validate then
      if new.mime_type not in ('video/mp4','video/webm','video/quicktime') then raise exception 'KOMBAX_SOCIAL_VIDEO_FORMAT_INVALID'; end if;
      if new.bytes is null or new.bytes<1 or new.bytes>104857600 then raise exception 'KOMBAX_SOCIAL_VIDEO_TOO_LARGE'; end if;
      if new.duration_seconds is null or new.duration_seconds<=0 or new.duration_seconds>60.2 then raise exception 'KOMBAX_SOCIAL_VIDEO_DURATION_INVALID'; end if;
      if new.width is null or new.height is null or new.width<1 or new.height<1 then raise exception 'KOMBAX_SOCIAL_VIDEO_DIMENSIONS_REQUIRED'; end if;
      if greatest(new.width,new.height)>1920 or least(new.width,new.height)>1080 then raise exception 'KOMBAX_SOCIAL_VIDEO_RESOLUTION_TOO_HIGH'; end if;
    end if;
  end if;
  return new;
end $$;

revoke all on function public.app_kombax_social_video_hd_guard_v241() from public,anon,authenticated;
drop trigger if exists kombax_social_video_hd_guard_v241 on public.kombax_social_media;
create trigger kombax_social_video_hd_guard_v241 before insert or update on public.kombax_social_media for each row execute function public.app_kombax_social_video_hd_guard_v241();
comment on function public.app_kombax_social_video_hd_guard_v241() is 'R50: validates new KOMBAX Social videos: MP4/WEBM/MOV, <=60.2s, <=100MB, <=1080p envelope.';

notify pgrst,'reload schema';
commit;
