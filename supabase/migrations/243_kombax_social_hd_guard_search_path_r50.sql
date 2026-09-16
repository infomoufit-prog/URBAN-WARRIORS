-- KOMBAX 20.101 R50 · Security hardening for the Social HD video trigger helper.
-- Narrow follow-up: fixes advisor function_search_path_mutable without changing behavior.
begin;

create or replace function public.app_kombax_social_video_hd_guard_v241()
returns trigger
language plpgsql
set search_path=public
as $$
begin
  if new.tipo='video' then
    if lower(coalesce(new.mime_type,'')) not in ('video/mp4','video/webm','video/quicktime') then
      raise exception 'KOMBAX_SOCIAL_VIDEO_FORMAT_INVALID';
    end if;
    if new.bytes is null or new.bytes<1 or new.bytes>104857600 then
      raise exception 'KOMBAX_SOCIAL_VIDEO_TOO_LARGE';
    end if;
    if new.duration_seconds is null or new.duration_seconds<=0 or new.duration_seconds>60.2 then
      raise exception 'KOMBAX_SOCIAL_VIDEO_DURATION_INVALID';
    end if;
    if new.width is not null and new.width>1920 then raise exception 'KOMBAX_SOCIAL_VIDEO_RESOLUTION_INVALID'; end if;
    if new.height is not null and new.height>1080 then raise exception 'KOMBAX_SOCIAL_VIDEO_RESOLUTION_INVALID'; end if;
  end if;
  return new;
end $$;

revoke all on function public.app_kombax_social_video_hd_guard_v241() from public,anon,authenticated;
comment on function public.app_kombax_social_video_hd_guard_v241() is 'R50: validates new KOMBAX Social videos <=60.2s / <=100MB / <=1080p with fixed search_path.';

notify pgrst,'reload schema';
commit;
