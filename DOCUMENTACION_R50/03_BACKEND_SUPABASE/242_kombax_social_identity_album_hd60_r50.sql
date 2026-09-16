-- KOMBAX 20.101 R50 · Align Club and Direct Profile albums with Social HD60.
-- Follow-up to the already-applied Social direct-media R50 migration.
begin;

alter table public.kombax_club_media drop constraint if exists kombax_club_media_bytes_check;
alter table public.kombax_club_media drop constraint if exists kombax_club_media_bytes_r50;
alter table public.kombax_club_media drop constraint if exists kombax_club_video_duration_v046;
alter table public.kombax_club_media drop constraint if exists kombax_club_video_duration_r50;
alter table public.kombax_club_media
  add constraint kombax_club_media_bytes_r50 check(
    (tipo='video' and bytes between 1 and 104857600)
    or (tipo='photo' and bytes between 1 and 26214400)
  ),
  add constraint kombax_club_video_duration_r50 check(
    tipo<>'video' or (duration_seconds is not null and duration_seconds>0 and duration_seconds<=60.2)
  );

alter table public.kombax_perfil_media drop constraint if exists kombax_perfil_media_bytes_check;
alter table public.kombax_perfil_media drop constraint if exists kombax_perfil_media_bytes_r50;
alter table public.kombax_perfil_media drop constraint if exists kombax_perfil_media_check;
alter table public.kombax_perfil_media drop constraint if exists kombax_perfil_media_format_duration_r50;
alter table public.kombax_perfil_media
  add constraint kombax_perfil_media_bytes_r50 check(
    (tipo='video' and bytes between 1 and 104857600)
    or (tipo<>'video' and bytes between 1 and 26214400)
  ),
  add constraint kombax_perfil_media_format_duration_r50 check(
    (tipo='video' and mime_type like 'video/%' and duration_seconds is not null and duration_seconds>0 and duration_seconds<=60.2)
    or (tipo<>'video' and mime_type like 'image/%' and duration_seconds is null)
  );

-- Preserve the existing authorization/idempotency body and relax only the historical 15 s guard.
-- Idempotent: if a live incremental migration already patched the function to 60.2 s, this is a no-op.
do $$
declare v_ddl text;
begin
  select pg_get_functiondef('public.app_kombax_media_mutate_v072(text,jsonb,uuid)'::regprocedure) into v_ddl;
  if v_ddl is null then raise exception 'KOMBAX_R50_MEDIA_FUNCTION_MISSING'; end if;
  if position('v_duration>15' in v_ddl)>0 then
    v_ddl:=replace(v_ddl,'v_duration>15','v_duration>60.2');
    v_ddl:=replace(v_ddl,'KOMBAX_VIDEO_MAX_15_SECONDS','KOMBAX_VIDEO_MAX_60_SECONDS');
    execute v_ddl;
  elsif position('v_duration>60.2' in v_ddl)=0 then
    raise exception 'KOMBAX_R50_MEDIA_FUNCTION_BASELINE_UNEXPECTED';
  end if;
end $$;
revoke all on function public.app_kombax_media_mutate_v072(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_media_mutate_v072(text,jsonb,uuid) to authenticated;
comment on function public.app_kombax_media_mutate_v072(text,jsonb,uuid) is 'R50 direct-profile media mutation: video up to 60.2 seconds / 100 MB, existing authorization/idempotency preserved.';

notify pgrst,'reload schema';
commit;
