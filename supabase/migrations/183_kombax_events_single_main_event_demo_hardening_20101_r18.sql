-- KOMBAX 20.101 R18 · Demo event single Main Event hardening
-- Purpose: normalize Urban Warriors demo so exactly one fight is highlighted after every seed run.
-- Non-destructive: no schema change; wraps existing v180 seed behavior.

create or replace function public.app_kombax_demo_urban_warriors_jiujitsu_seed_v180()
returns jsonb
language plpgsql
security definer
set search_path to 'public','auth'
as $function$
declare
  v_result jsonb;
  v_event uuid;
  v_main_fight uuid;
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

    select c.id into v_main_fight
    from public.kombax_evento_combates_publicos c
    where c.evento_id=v_event and c.estado<>'cancelado'
    order by coalesce(c.orden,999),c.creado_en,c.id
    limit 1;

    update public.kombax_evento_combates_publicos c
    set destacado=(c.id=v_main_fight),actualizado_en=now()
    where c.evento_id=v_event;
  end if;

  return coalesce(v_result,'{}'::jsonb) || jsonb_build_object(
    'fighter_photos_repaired',true,
    'fighter_photo_count',(select count(*) from public.kombax_evento_participantes_publicos p where p.evento_id=v_event and p.foto_url_externa like 'https://poggsobhtutbuagjiydc.supabase.co/storage/v1/object/public/club-public-media/%'),
    'single_main_event',true,
    'main_event_fight_id',v_main_fight,
    'main_event_count',(select count(*) from public.kombax_evento_combates_publicos c where c.evento_id=v_event and c.destacado=true)
  );
end $function$;

revoke all on function public.app_kombax_demo_urban_warriors_jiujitsu_seed_v180() from public, anon;
grant execute on function public.app_kombax_demo_urban_warriors_jiujitsu_seed_v180() to authenticated, service_role;

-- Repair the currently installed demo immediately.
with target as (
  select e.id as evento_id
  from public.kombax_eventos_publicos e
  where e.slug='urban-warriors-interclub-jiu-jitsu-palafolls-demo'
), main as (
  select c.id,c.evento_id
  from public.kombax_evento_combates_publicos c
  join target t on t.evento_id=c.evento_id
  where c.estado<>'cancelado'
  order by coalesce(c.orden,999),c.creado_en,c.id
  limit 1
)
update public.kombax_evento_combates_publicos c
set destacado=(c.id=(select id from main)),actualizado_en=now()
where c.evento_id=(select evento_id from target);
