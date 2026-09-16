-- KOMBAX RC13 build 20.101 R8 · 180 · Urban Warriors Jiu-Jitsu Interclub demo
-- Owner-controlled bootstrap that creates a NORMAL public KOMBAX Event owned by the real Urban Warriors club.
-- It deliberately reuses the production Events domain, organizer entitlement, Fight Cards and album pipeline.
begin;

create or replace function public.app_kombax_demo_urban_warriors_jiujitsu_seed_v180()
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();
  v_owner boolean:=false;
  v_club uuid;
  v_social uuid;
  v_event uuid;
  v_slug text:='urban-warriors-interclub-jiu-jitsu-palafolls-demo';
  v_base text:='https://kombax.es/assets/demo-events/urban-warriors-jiujitsu-interclub/';
  r record;
  a uuid;b uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select exists(select 1 from public.kombax_platform_admins x where x.perfil_id=v_uid and x.activo and x.nivel='owner') into v_owner;
  if not v_owner then raise exception 'PLATFORM_OWNER_REQUIRED'; end if;

  select c.id into v_club
  from public.clubes c
  where c.activo and (lower(trim(c.slug))='urban-warriors' or lower(trim(c.nombre))='urban warriors')
  order by case when lower(trim(c.slug))='urban-warriors' then 0 else 1 end,c.id
  limit 1;
  if v_club is null then raise exception 'KOMBAX_URBAN_WARRIORS_CLUB_NOT_FOUND'; end if;

  if not exists(
    select 1 from public.kombax_entitlements e
    where e.sujeto_tipo='club' and e.sujeto_id=v_club and e.capacidad_clave='events.public.organize'
      and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now())
  ) then raise exception 'URBAN_WARRIORS_EVENTS_NOT_ENABLED'; end if;

  select sp.id into v_social
  from public.kombax_social_perfiles sp
  where sp.sujeto_tipo='club' and sp.club_id=v_club and sp.visible and sp.estado='activo'
  order by sp.verificado desc,sp.creado_en asc
  limit 1;

  select e.id into v_event from public.kombax_eventos_publicos e where e.slug=v_slug limit 1;
  if v_event is null then
    insert into public.kombax_eventos_publicos(
      slug,tipo,nombre,resumen,descripcion,estado,visibilidad,fecha_inicio,fecha_fin,timezone,
      lugar_nombre,direccion,codigo_postal,municipio,provincia,pais,cartel_url,banner_url,tema_visual,
      creador_tipo,creador_club_id,organizador_nombre,creado_por,publicado_en,
      mapa_url,web_oficial_url,inscripcion_url,inscripciones_abren_en,inscripciones_cierran_en,inscripcion_precio_desde,inscripciones_info,
      tickets_url,tickets_proveedor,tickets_abren_en,tickets_cierran_en,ticket_precio_desde,entradas_info,aforo,acceso_info,
      cartel_focus_x,cartel_focus_y,banner_focus_x,banner_focus_y
    ) values(
      v_slug,'interclub','Urban Warriors · Interclub de Jiu-Jitsu · Palafolls',
      'Interclub de jiu-jitsu para menores desde 8 años, juveniles y adultos, organizado por Urban Warriors.',
      'Evento ficticio completo de KOMBAX Events creado para validar el flujo real de un club organizador. Incluye categorías infantiles, juveniles y adultas; dos combates estelares, Fight Card, inscripciones, ubicación, álbum oficial y piezas de previa y postevento. Todas las personas, clubes rivales y resultados son ficticios y se usan exclusivamente para QA y demostración del producto.',
      'inscripciones_abiertas','publico','2026-11-14 09:00:00+01','2026-11-14 18:30:00+01','Europe/Madrid',
      'Pabellón Municipal de Palafolls','','08389','Palafolls','Barcelona','España',
      './assets/demo-events/urban-warriors-jiujitsu-interclub/poster.webp','./assets/demo-events/urban-warriors-jiujitsu-interclub/banner.webp','arena',
      'club',v_club,'Urban Warriors',v_uid,now(),
      'https://www.google.com/maps/search/?api=1&query=Palafolls+Barcelona','https://kombax.es/','https://kombax.es/','2026-08-27 00:00:00+02','2026-11-08 23:59:00+01',18,
      'Inscripción de ejemplo mediante KOMBAX. Categorías por edad, nivel y peso. Los menores participan con autorización del tutor y control del club organizador.',
      'https://kombax.es/','Urban Warriors','2026-08-27 00:00:00+02','2026-11-14 08:45:00+01',0,
      'Acceso de público gratuito hasta completar aforo. KOMBAX muestra la información del evento y no procesa pagos.',450,
      'Apertura 08:15. Acreditación y control de categorías 08:30. Inicio 09:00. Zona de calentamiento, grada familiar y acceso adaptado.',
      50,42,50,44
    ) returning id into v_event;
  else
    update public.kombax_eventos_publicos set
      tipo='interclub',nombre='Urban Warriors · Interclub de Jiu-Jitsu · Palafolls',
      resumen='Interclub de jiu-jitsu para menores desde 8 años, juveniles y adultos, organizado por Urban Warriors.',
      descripcion='Evento ficticio completo de KOMBAX Events creado para validar el flujo real de un club organizador. Incluye categorías infantiles, juveniles y adultas; dos combates estelares, Fight Card, inscripciones, ubicación, álbum oficial y piezas de previa y postevento. Todas las personas, clubes rivales y resultados son ficticios y se usan exclusivamente para QA y demostración del producto.',
      estado='inscripciones_abiertas',visibilidad='publico',fecha_inicio='2026-11-14 09:00:00+01',fecha_fin='2026-11-14 18:30:00+01',timezone='Europe/Madrid',
      lugar_nombre='Pabellón Municipal de Palafolls',direccion='',codigo_postal='08389',municipio='Palafolls',provincia='Barcelona',pais='España',
      cartel_url='./assets/demo-events/urban-warriors-jiujitsu-interclub/poster.webp',banner_url='./assets/demo-events/urban-warriors-jiujitsu-interclub/banner.webp',tema_visual='arena',
      creador_tipo='club',creador_club_id=v_club,creador_perfil_directo_id=null,organizador_nombre='Urban Warriors',
      mapa_url='https://www.google.com/maps/search/?api=1&query=Palafolls+Barcelona',web_oficial_url='https://kombax.es/',inscripcion_url='https://kombax.es/',
      inscripciones_abren_en='2026-08-27 00:00:00+02',inscripciones_cierran_en='2026-11-08 23:59:00+01',inscripcion_precio_desde=18,
      inscripciones_info='Inscripción de ejemplo mediante KOMBAX. Categorías por edad, nivel y peso. Los menores participan con autorización del tutor y control del club organizador.',
      tickets_url='https://kombax.es/',tickets_proveedor='Urban Warriors',tickets_abren_en='2026-08-27 00:00:00+02',tickets_cierran_en='2026-11-14 08:45:00+01',ticket_precio_desde=0,
      entradas_info='Acceso de público gratuito hasta completar aforo. KOMBAX muestra la información del evento y no procesa pagos.',aforo=450,
      acceso_info='Apertura 08:15. Acreditación y control de categorías 08:30. Inicio 09:00. Zona de calentamiento, grada familiar y acceso adaptado.',
      cartel_focus_x=50,cartel_focus_y=42,banner_focus_x=50,banner_focus_y=44,actualizado_en=now()
    where id=v_event;
  end if;

  delete from public.kombax_evento_entidades where evento_id=v_event and rol='organizador_principal';
  if v_social is not null then
    insert into public.kombax_evento_entidades(evento_id,rol,origen,social_profile_id,puede_gestionar,estado,orden,creado_por)
    values(v_event,'organizador_principal','kombax',v_social,true,'aceptada',0,v_uid);
  else
    insert into public.kombax_evento_entidades(evento_id,rol,origen,nombre_externo,logo_url_externo,web_externa,puede_gestionar,estado,orden,creado_por)
    values(v_event,'organizador_principal','externa','Urban Warriors','https://kombax.es/assets/urban-warriors-logo.png','https://kombax.es/',false,'aceptada',0,v_uid);
  end if;

  delete from public.kombax_evento_combates_publicos where evento_id=v_event;
  delete from public.kombax_evento_participantes_publicos where evento_id=v_event;

  create temporary table if not exists pg_temp.kx_uw_bjj_people(nombre text,foto text,club text,categoria text,peso numeric) on commit drop;
  truncate pg_temp.kx_uw_bjj_people;
  insert into pg_temp.kx_uw_bjj_people values
    ('Malik Benítez','action-adults-01.webp','Urban Warriors','Adulto · cinturón negro · -82 kg',82),
    ('Bruno Sato','action-adults-02.webp','Barcelona Grappling Lab','Adulto · cinturón negro · -82 kg',82),
    ('Aina Torres',null,'Urban Warriors','Adulta · cinturón morado · -64 kg',64),
    ('Hana Ribeiro',null,'Costa BJJ Academy','Adulta · cinturón morado · -64 kg',64),
    ('Daniel Ortiz',null,'Urban Warriors','Juvenil 16-17 · -70 kg',70),
    ('Marc Vidal',null,'North Coast Jiu-Jitsu','Juvenil 16-17 · -70 kg',70),
    ('Laia Costa',null,'Urban Warriors','Cadete 14-15 · -52 kg',52),
    ('Emma León',null,'Maresme Grappling','Cadete 14-15 · -52 kg',52),
    ('Leo Martín',null,'Urban Warriors','Infantil 11-13 · -42 kg',42),
    ('Hugo Ríos',null,'Montseny BJJ','Infantil 11-13 · -42 kg',42),
    ('Nico Serra',null,'Urban Warriors','Benjamín 8-10 · -30 kg',30),
    ('Ian Cruz',null,'Costa Brava Jiu-Jitsu','Benjamín 8-10 · -30 kg',30);

  for r in select * from pg_temp.kx_uw_bjj_people loop
    insert into public.kombax_evento_participantes_publicos(evento_id,origen,nombre_publico,foto_url_externa,club_nombre,disciplina,categoria,peso,estado_inscripcion,visible_publico,notas_publicas,creado_por)
    values(v_event,'externa',r.nombre,case when r.foto is null then null else v_base||r.foto end,r.club,'Jiu-Jitsu',r.categoria,r.peso,'aceptada',true,'Perfil ficticio para demostración y QA de KOMBAX Events.',v_uid);
  end loop;

  select id into a from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico='Malik Benítez';
  select id into b from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico='Bruno Sato';
  insert into public.kombax_evento_combates_publicos(evento_id,participante_a_id,participante_b_id,disciplina,categoria,peso_texto,tatami_ring,orden,hora_programada,estado,visible_publico,destacado,creado_por)
  values(v_event,a,b,'Jiu-Jitsu','Adulto · cinturón negro','-82 kg','Tatami Central',1,'2026-11-14 17:30:00+01','programado',true,true,v_uid);

  select id into a from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico='Aina Torres';
  select id into b from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico='Hana Ribeiro';
  insert into public.kombax_evento_combates_publicos(evento_id,participante_a_id,participante_b_id,disciplina,categoria,peso_texto,tatami_ring,orden,hora_programada,estado,visible_publico,destacado,creado_por)
  values(v_event,a,b,'Jiu-Jitsu','Adulto femenino · cinturón morado','-64 kg','Tatami Central',2,'2026-11-14 16:55:00+01','programado',true,true,v_uid);

  for r in select * from (values
    ('Daniel Ortiz','Marc Vidal','Juvenil 16-17','-70 kg',3,'2026-11-14 15:40:00+01'::timestamptz),
    ('Laia Costa','Emma León','Cadete 14-15','-52 kg',4,'2026-11-14 14:35:00+01'::timestamptz),
    ('Leo Martín','Hugo Ríos','Infantil 11-13','-42 kg',5,'2026-11-14 12:20:00+01'::timestamptz),
    ('Nico Serra','Ian Cruz','Benjamín 8-10','-30 kg',6,'2026-11-14 10:15:00+01'::timestamptz)
  ) x(na,nb,cat,peso,ord,hora) loop
    select id into a from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico=r.na;
    select id into b from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico=r.nb;
    insert into public.kombax_evento_combates_publicos(evento_id,participante_a_id,participante_b_id,disciplina,categoria,peso_texto,tatami_ring,orden,hora_programada,estado,visible_publico,destacado,creado_por)
    values(v_event,a,b,'Jiu-Jitsu',r.cat,r.peso,case when r.ord<=4 then 'Tatami Central' else 'Tatami 2' end,r.ord,r.hora,'programado',true,false,v_uid);
  end loop;

  return jsonb_build_object(
    'ok',true,'event_id',v_event,'slug',v_slug,'club_id',v_club,
    'organizer','Urban Warriors','participant_count',(select count(*) from public.kombax_evento_participantes_publicos where evento_id=v_event),
    'fight_count',(select count(*) from public.kombax_evento_combates_publicos where evento_id=v_event),
    'media_count',(select count(*) from public.kombax_evento_media where evento_id=v_event and estado<>'retirado')
  );
end $$;
revoke all on function public.app_kombax_demo_urban_warriors_jiujitsu_seed_v180() from public,anon;
grant execute on function public.app_kombax_demo_urban_warriors_jiujitsu_seed_v180() to authenticated;

create or replace function public.app_kombax_demo_urban_warriors_jiujitsu_cleanup_v180()
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_event uuid;v_paths text[];
begin
  if v_uid is null or not exists(select 1 from public.kombax_platform_admins a where a.perfil_id=v_uid and a.activo and a.nivel='owner') then raise exception 'PLATFORM_OWNER_REQUIRED'; end if;
  select id into v_event from public.kombax_eventos_publicos where slug='urban-warriors-interclub-jiu-jitsu-palafolls-demo';
  if v_event is null then return jsonb_build_object('ok',true,'removed',false); end if;
  select coalesce(array_agg(storage_path) filter(where storage_path is not null),'{}'::text[]) into v_paths from public.kombax_evento_media where evento_id=v_event;
  delete from public.kombax_eventos_publicos where id=v_event;
  return jsonb_build_object('ok',true,'removed',true,'storage_paths',to_jsonb(v_paths));
end $$;
revoke all on function public.app_kombax_demo_urban_warriors_jiujitsu_cleanup_v180() from public,anon;
grant execute on function public.app_kombax_demo_urban_warriors_jiujitsu_cleanup_v180() to authenticated;

comment on function public.app_kombax_demo_urban_warriors_jiujitsu_seed_v180() is '20.101 R8 owner bootstrap. Creates a normal club-owned KOMBAX Event for Urban Warriors using the real Events domain, entitlement and management isolation.';

commit;
