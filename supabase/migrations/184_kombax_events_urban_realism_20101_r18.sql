-- KOMBAX 20.101 R18 · Urban Warriors realism pass
-- 10 unique fictional fighters · 5 fights total · exactly 1 Main Event.
begin;

create or replace function public.app_kombax_demo_urban_warriors_jiujitsu_seed_v180()
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_result jsonb;
  v_event uuid;
  v_uid uuid:=auth.uid();
  a uuid;b uuid;
  v_base text:='https://kombax.es/assets/demo-events/urban-warriors-jiujitsu-interclub/fighters-realistic/';
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  v_result:=public.app_kombax_demo_urban_warriors_jiujitsu_seed_v180_core();

  select e.id into v_event from public.kombax_eventos_publicos e
  where e.slug='urban-warriors-interclub-jiu-jitsu-palafolls-demo' limit 1;
  if v_event is null then raise exception 'URBAN_WARRIORS_DEMO_NOT_FOUND'; end if;

  update public.kombax_eventos_publicos set
    descripcion='Evento ficticio completo de KOMBAX Events creado para validar el flujo real de un club organizador. Incluye 10 competidores ficticios con retratos individuales, cuatro combates de Fight Card y un único Main Event. Todas las personas, clubes rivales y resultados son ficticios y se usan exclusivamente para QA y demostración del producto.',
    actualizado_en=now()
  where id=v_event;

  -- Core R8 creates 12/6. Normalize the demo to the 10 portraits available.
  delete from public.kombax_evento_combates_publicos where evento_id=v_event;
  delete from public.kombax_evento_participantes_publicos
  where evento_id=v_event and nombre_publico in ('Nico Serra','Ian Cruz');

  update public.kombax_evento_participantes_publicos set foto_url_externa=v_base||'malik-benitez.webp',categoria='Adulto · cinturón negro · -82 kg',peso=82,actualizado_en=now() where evento_id=v_event and nombre_publico='Malik Benítez';
  update public.kombax_evento_participantes_publicos set foto_url_externa=v_base||'bruno-sato.webp',categoria='Adulto · cinturón negro · -82 kg',peso=82,actualizado_en=now() where evento_id=v_event and nombre_publico='Bruno Sato';
  update public.kombax_evento_participantes_publicos set foto_url_externa=v_base||'aina-torres.webp',categoria='Adulta · cinturón morado · -64 kg',peso=64,actualizado_en=now() where evento_id=v_event and nombre_publico='Aina Torres';
  update public.kombax_evento_participantes_publicos set foto_url_externa=v_base||'hana-ribeiro.webp',categoria='Adulta · cinturón morado · -64 kg',peso=64,actualizado_en=now() where evento_id=v_event and nombre_publico='Hana Ribeiro';
  update public.kombax_evento_participantes_publicos set foto_url_externa=v_base||'daniel-ortiz.webp',categoria='Adulto · cinturón marrón · -76 kg',peso=76,actualizado_en=now() where evento_id=v_event and nombre_publico='Daniel Ortiz';
  update public.kombax_evento_participantes_publicos set foto_url_externa=v_base||'marc-vidal.webp',categoria='Adulto · cinturón morado · -76 kg',peso=76,actualizado_en=now() where evento_id=v_event and nombre_publico='Marc Vidal';
  update public.kombax_evento_participantes_publicos set foto_url_externa=v_base||'laia-costa.webp',categoria='Cadete femenino · 14-15 · -52 kg',peso=52,actualizado_en=now() where evento_id=v_event and nombre_publico='Laia Costa';
  update public.kombax_evento_participantes_publicos set foto_url_externa=v_base||'emma-leon.webp',categoria='Cadete femenino · 14-15 · -52 kg',peso=52,actualizado_en=now() where evento_id=v_event and nombre_publico='Emma León';
  update public.kombax_evento_participantes_publicos set foto_url_externa=v_base||'leo-martin.webp',categoria='Juvenil masculino · 13-16 · -48 kg',peso=48,actualizado_en=now() where evento_id=v_event and nombre_publico='Leo Martín';
  update public.kombax_evento_participantes_publicos set foto_url_externa=v_base||'hugo-rios.webp',categoria='Juvenil masculino · 13-16 · -48 kg',peso=48,actualizado_en=now() where evento_id=v_event and nombre_publico='Hugo Ríos';

  -- Main Event
  select id into a from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico='Malik Benítez';
  select id into b from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico='Bruno Sato';
  insert into public.kombax_evento_combates_publicos(evento_id,participante_a_id,participante_b_id,disciplina,categoria,peso_texto,tatami_ring,orden,hora_programada,estado,visible_publico,destacado,creado_por)
  values(v_event,a,b,'Jiu-Jitsu','Adulto · cinturón negro','-82 kg','Tatami Central',1,'2026-11-14 17:30:00+01','programado',true,true,v_uid);

  select id into a from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico='Aina Torres';
  select id into b from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico='Hana Ribeiro';
  insert into public.kombax_evento_combates_publicos(evento_id,participante_a_id,participante_b_id,disciplina,categoria,peso_texto,tatami_ring,orden,hora_programada,estado,visible_publico,destacado,creado_por)
  values(v_event,a,b,'Jiu-Jitsu','Adulto femenino · cinturón morado','-64 kg','Tatami Central',2,'2026-11-14 16:40:00+01','programado',true,false,v_uid);

  select id into a from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico='Daniel Ortiz';
  select id into b from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico='Marc Vidal';
  insert into public.kombax_evento_combates_publicos(evento_id,participante_a_id,participante_b_id,disciplina,categoria,peso_texto,tatami_ring,orden,hora_programada,estado,visible_publico,destacado,creado_por)
  values(v_event,a,b,'Jiu-Jitsu','Adulto · cinturón marrón/morado','-76 kg','Tatami Central',3,'2026-11-14 15:30:00+01','programado',true,false,v_uid);

  select id into a from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico='Laia Costa';
  select id into b from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico='Emma León';
  insert into public.kombax_evento_combates_publicos(evento_id,participante_a_id,participante_b_id,disciplina,categoria,peso_texto,tatami_ring,orden,hora_programada,estado,visible_publico,destacado,creado_por)
  values(v_event,a,b,'Jiu-Jitsu','Cadete femenino · 14-15','-52 kg','Tatami 2',4,'2026-11-14 14:20:00+01','programado',true,false,v_uid);

  select id into a from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico='Leo Martín';
  select id into b from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico='Hugo Ríos';
  insert into public.kombax_evento_combates_publicos(evento_id,participante_a_id,participante_b_id,disciplina,categoria,peso_texto,tatami_ring,orden,hora_programada,estado,visible_publico,destacado,creado_por)
  values(v_event,a,b,'Jiu-Jitsu','Juvenil masculino · 13-16','-48 kg','Tatami 2',5,'2026-11-14 12:30:00+01','programado',true,false,v_uid);

  return coalesce(v_result,'{}'::jsonb)||jsonb_build_object(
    'participant_count',(select count(*) from public.kombax_evento_participantes_publicos where evento_id=v_event),
    'unique_photo_count',(select count(distinct foto_url_externa) from public.kombax_evento_participantes_publicos where evento_id=v_event and foto_url_externa is not null),
    'fight_count',(select count(*) from public.kombax_evento_combates_publicos where evento_id=v_event),
    'main_event_count',(select count(*) from public.kombax_evento_combates_publicos where evento_id=v_event and destacado is true),
    'demo_album_photo_count',10,
    'realistic_portraits',true
  );
end $$;

revoke all on function public.app_kombax_demo_urban_warriors_jiujitsu_seed_v180() from public,anon;
grant execute on function public.app_kombax_demo_urban_warriors_jiujitsu_seed_v180() to authenticated,service_role;
comment on function public.app_kombax_demo_urban_warriors_jiujitsu_seed_v180() is '20.101 R18 realism pass: 10 unique fictional portraits, 5 fights total, one Main Event; local demo album mirrors the same 10 portraits.';

commit;
