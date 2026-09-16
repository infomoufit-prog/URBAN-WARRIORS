-- KOMBAX 20.101 · R16 backend hotfix
-- Urban Warriors demo fighter images: durable HTTPS Storage URLs + idempotent seed repair.
-- Applied to main Supabase as migration kombax_events_urban_fighter_storage_repair_20101_v183.

begin;

alter function public.app_kombax_demo_urban_warriors_jiujitsu_seed_v180()
  rename to app_kombax_demo_urban_warriors_jiujitsu_seed_v180_core;

create function public.app_kombax_demo_urban_warriors_jiujitsu_seed_v180()
returns jsonb
language plpgsql
security definer
set search_path to 'public','auth'
as $$
declare
  v_result jsonb;
  v_event uuid;
  v_adult_url constant text := 'https://poggsobhtutbuagjiydc.supabase.co/storage/v1/object/public/club-public-media/11111111-1111-4111-8111-111111111111/events-demo/urban-warriors-jiujitsu/adult.webp';
  v_youth_url constant text := 'https://poggsobhtutbuagjiydc.supabase.co/storage/v1/object/public/club-public-media/11111111-1111-4111-8111-111111111111/events-demo/urban-warriors-jiujitsu/youth.webp';
begin
  v_result := public.app_kombax_demo_urban_warriors_jiujitsu_seed_v180_core();

  select e.id into v_event
  from public.kombax_eventos_publicos e
  where e.slug='urban-warriors-interclub-jiu-jitsu-palafolls-demo'
  limit 1;

  if v_event is not null then
    update public.kombax_evento_participantes_publicos p
    set foto_url_externa = case
      when p.nombre_publico in ('Leo Martín','Hugo Ríos','Nico Serra','Ian Cruz') then v_youth_url
      else v_adult_url
    end,
    actualizado_en=now()
    where p.evento_id=v_event;
  end if;

  return coalesce(v_result,'{}'::jsonb) || jsonb_build_object(
    'fighter_photos_repaired',true,
    'fighter_photo_count',(
      select count(*)
      from public.kombax_evento_participantes_publicos p
      where p.evento_id=v_event
        and p.foto_url_externa like 'https://poggsobhtutbuagjiydc.supabase.co/storage/v1/object/public/club-public-media/%'
    )
  );
end $$;

revoke all on function public.app_kombax_demo_urban_warriors_jiujitsu_seed_v180_core() from public,anon,authenticated;
revoke all on function public.app_kombax_demo_urban_warriors_jiujitsu_seed_v180() from public,anon;
grant execute on function public.app_kombax_demo_urban_warriors_jiujitsu_seed_v180() to authenticated;

with target as (
  select id
  from public.kombax_eventos_publicos
  where slug='urban-warriors-interclub-jiu-jitsu-palafolls-demo'
  limit 1
)
update public.kombax_evento_participantes_publicos p
set foto_url_externa = case
  when p.nombre_publico in ('Leo Martín','Hugo Ríos','Nico Serra','Ian Cruz') then
    'https://poggsobhtutbuagjiydc.supabase.co/storage/v1/object/public/club-public-media/11111111-1111-4111-8111-111111111111/events-demo/urban-warriors-jiujitsu/youth.webp'
  else
    'https://poggsobhtutbuagjiydc.supabase.co/storage/v1/object/public/club-public-media/11111111-1111-4111-8111-111111111111/events-demo/urban-warriors-jiujitsu/adult.webp'
end,
actualizado_en=now()
from target t
where p.evento_id=t.id;

notify pgrst,'reload schema';
commit;
