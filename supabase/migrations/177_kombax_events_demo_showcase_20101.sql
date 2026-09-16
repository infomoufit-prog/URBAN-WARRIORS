-- KOMBAX RC13 build 20.101 · 177 · Owner-controlled real demo event seed
-- Creates normal KOMBAX Event rows through an Owner-only bootstrap RPC.
begin;

create or replace function public.app_kombax_demo_event_seed_v177()
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();
  v_owner boolean:=false;
  v_direct uuid;
  v_event uuid;
  v_slug text:='noche-de-impacto-barcelona-demo';
  v_base text:='https://kombax.es/assets/demo-events/noche-impacto-barcelona/';
  r record;
  a uuid;b uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select exists(select 1 from public.kombax_platform_admins a where a.perfil_id=v_uid and a.activo and a.nivel='owner') into v_owner;
  if not v_owner then raise exception 'PLATFORM_OWNER_REQUIRED'; end if;

  select d.id into v_direct
  from public.perfiles_kombax_directos d
  where d.perfil_id=v_uid and d.tipo='federacion' and d.estado='activo' and d.verificacion_estado='verificado'
  order by case when lower(coalesce(d.nombre_publico,'')) like '%qa%' then 0 else 1 end,d.creado_en desc
  limit 1;
  if v_direct is null then raise exception 'DEMO_FEDERATION_CONTEXT_REQUIRED'; end if;

  select e.id into v_event from public.kombax_eventos_publicos e where e.slug=v_slug limit 1;
  if v_event is null then
    insert into public.kombax_eventos_publicos(
      slug,tipo,nombre,resumen,descripcion,estado,visibilidad,fecha_inicio,fecha_fin,timezone,
      lugar_nombre,direccion,codigo_postal,municipio,provincia,pais,cartel_url,banner_url,tema_visual,
      creador_tipo,creador_perfil_directo_id,organizador_nombre,creado_por,publicado_en,
      mapa_url,web_oficial_url,inscripcion_url,inscripciones_abren_en,inscripciones_cierran_en,inscripcion_precio_desde,inscripciones_info,
      tickets_url,tickets_proveedor,tickets_abren_en,tickets_cierran_en,ticket_precio_desde,entradas_info,aforo,acceso_info
    ) values(
      v_slug,'velada','Noche de Impacto · Barcelona · DEMO QA',
      'Velada ficticia completa para demostrar a clubes y federaciones cómo se publica y vive un KOMBAX Evento.',
      'Evento demostrativo oficial de QA. Incluye organizador y federación ficticios, Main Event, co-main femenino, undercard, participantes, entradas, inscripción, recinto, álbum previo/evento/postevento y piezas de highlights. Todos los nombres, clubes y resultados son ficticios.',
      'inscripciones_abiertas','publico','2026-10-18 19:30:00+02','2026-10-18 23:30:00+02','Europe/Madrid',
      'Palau Combat Barcelona','Av. del Litoral 88','08005','Barcelona','Barcelona','España',
      './assets/demo-events/noche-impacto-barcelona/poster.webp','./assets/demo-events/noche-impacto-barcelona/banner.webp','arena',
      'perfil_directo',v_direct,'Club Fénix Elite · DEMO',v_uid,now(),
      'https://www.google.com/maps/search/?api=1&query=Barcelona','https://kombax.es/','https://kombax.es/','2026-08-27 00:00:00+02','2026-10-10 23:59:00+02',25,
      'DEMO QA · Inscripción de ejemplo para competidores. Categorías y reglamento ficticios para presentación comercial.',
      'https://kombax.es/','KOMBAX Tickets · DEMO','2026-08-27 00:00:00+02','2026-10-18 19:00:00+02',29,
      'DEMO QA · Entrada general desde 29 €, grada 39 € y front row 59 €. KOMBAX no procesa el pago; el enlace es demostrativo.',1800,
      'Apertura de puertas 18:30. Inicio de la velada 19:30. Acceso adaptado, zona de prensa y parking de demostración.'
    ) returning id into v_event;
  else
    update public.kombax_eventos_publicos set
      estado='inscripciones_abiertas',visibilidad='publico',actualizado_en=now(),
      cartel_url='./assets/demo-events/noche-impacto-barcelona/poster.webp',banner_url='./assets/demo-events/noche-impacto-barcelona/banner.webp',
      organizador_nombre='Club Fénix Elite · DEMO'
    where id=v_event;
  end if;

  delete from public.kombax_evento_entidades where evento_id=v_event and origen='externa' and nombre_externo in ('Club Fénix Elite · DEMO','Federación Nova Combat · DEMO');
  insert into public.kombax_evento_entidades(evento_id,rol,origen,nombre_externo,logo_url_externo,web_externa,puede_gestionar,estado,orden,creado_por)
  values
    (v_event,'organizador_principal','externa','Club Fénix Elite · DEMO',v_base||'club-fenix-logo.webp','https://kombax.es/',false,'aceptada',0,v_uid),
    (v_event,'avala','externa','Federación Nova Combat · DEMO',v_base||'nova-combat-logo.webp','https://kombax.es/',false,'aceptada',0,v_uid);

  delete from public.kombax_evento_combates_publicos where evento_id=v_event;
  delete from public.kombax_evento_participantes_publicos where evento_id=v_event;

  create temporary table if not exists pg_temp.kx_demo_people(nombre text,foto text,club text,disciplina text,categoria text,peso numeric) on commit drop;
  truncate pg_temp.kx_demo_people;
  insert into pg_temp.kx_demo_people values
   ('Hugo “Raven” Salvatierra','fighter-hugo-salvatierra.webp','Club Fénix Elite','Kickboxing','Pro -75 kg',75),
   ('Darío “Atlas” Moreno','fighter-dario-moreno.webp','Atlas Fight Team','Kickboxing','Pro -75 kg',75),
   ('Vera “Tempest” León','fighter-vera-leon.webp','Club Fénix Elite','MMA','Pro -57 kg',57),
   ('Nerea “Venom” Rivas','fighter-nerea-rivas.webp','Rivas Combat Lab','MMA','Pro -57 kg',57),
   ('Adrián Cruz','fighter-adrian-cruz.webp','Fénix Academy','Kickboxing','-70 kg',70),
   ('Marcos Durán','fighter-marcos-duran.webp','Durán Team','Kickboxing','-70 kg',70),
   ('Youssef Kadi','fighter-youssef-kadi.webp','Kadi Fight Club','MMA','-66 kg',66),
   ('Leo Serra','fighter-leo-serra.webp','Serra Combat','MMA','-66 kg',66),
   ('Claudia Sanz','fighter-claudia-sanz.webp','Fénix Academy','MMA','-61 kg',61),
   ('Maia Costa','fighter-maia-costa.webp','Costa Fight Lab','MMA','-61 kg',61),
   ('Iván Keller','fighter-ivan-keller.webp','Keller Team','Kickboxing','-80 kg',80),
   ('Bruno Mota','fighter-bruno-mota.webp','Mota Combat','Kickboxing','-80 kg',80);

  for r in select * from pg_temp.kx_demo_people loop
    insert into public.kombax_evento_participantes_publicos(evento_id,origen,nombre_publico,foto_url_externa,club_nombre,disciplina,categoria,peso,estado_inscripcion,visible_publico,notas_publicas,creado_por)
    values(v_event,'externa',r.nombre,v_base||r.foto,r.club,r.disciplina,r.categoria,r.peso,'aceptada',true,'Perfil ficticio de demostración QA.',v_uid);
  end loop;

  select id into a from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico='Hugo “Raven” Salvatierra';
  select id into b from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico='Darío “Atlas” Moreno';
  insert into public.kombax_evento_combates_publicos(evento_id,participante_a_id,participante_b_id,disciplina,categoria,peso_texto,tatami_ring,orden,hora_programada,estado,visible_publico,destacado,creado_por)
  values(v_event,a,b,'Kickboxing','Profesional','-75 kg','Main Arena',1,'2026-10-18 22:30:00+02','programado',true,true,v_uid);

  select id into a from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico='Vera “Tempest” León';
  select id into b from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico='Nerea “Venom” Rivas';
  insert into public.kombax_evento_combates_publicos(evento_id,participante_a_id,participante_b_id,disciplina,categoria,peso_texto,tatami_ring,orden,hora_programada,estado,visible_publico,destacado,creado_por)
  values(v_event,a,b,'MMA','Profesional femenino','-57 kg','Main Arena',2,'2026-10-18 21:45:00+02','programado',true,false,v_uid);

  for r in select * from (values
    ('Adrián Cruz','Marcos Durán','Kickboxing','-70 kg',3,'2026-10-18 21:00:00+02'::timestamptz),
    ('Youssef Kadi','Leo Serra','MMA','-66 kg',4,'2026-10-18 20:30:00+02'::timestamptz),
    ('Claudia Sanz','Maia Costa','MMA','-61 kg',5,'2026-10-18 20:00:00+02'::timestamptz),
    ('Iván Keller','Bruno Mota','Kickboxing','-80 kg',6,'2026-10-18 19:40:00+02'::timestamptz)
  ) x(na,nb,disc,peso,ord,hora) loop
    select id into a from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico=r.na;
    select id into b from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico=r.nb;
    insert into public.kombax_evento_combates_publicos(evento_id,participante_a_id,participante_b_id,disciplina,categoria,peso_texto,tatami_ring,orden,hora_programada,estado,visible_publico,destacado,creado_por)
    values(v_event,a,b,r.disc,'Undercard',r.peso,'Main Arena',r.ord,r.hora,'programado',true,false,v_uid);
  end loop;

  return jsonb_build_object('ok',true,'event_id',v_event,'slug',v_slug,'media_count',(select count(*) from public.kombax_evento_media where evento_id=v_event and estado<>'retirado'));
end $$;
revoke all on function public.app_kombax_demo_event_seed_v177() from public,anon;
grant execute on function public.app_kombax_demo_event_seed_v177() to authenticated;

create or replace function public.app_kombax_demo_event_cleanup_v177()
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_event uuid;v_paths text[];
begin
  if v_uid is null or not exists(select 1 from public.kombax_platform_admins a where a.perfil_id=v_uid and a.activo and a.nivel='owner') then raise exception 'PLATFORM_OWNER_REQUIRED'; end if;
  select id into v_event from public.kombax_eventos_publicos where slug='noche-de-impacto-barcelona-demo';
  if v_event is null then return jsonb_build_object('ok',true,'removed',false); end if;
  select coalesce(array_agg(storage_path) filter(where storage_path is not null),'{}'::text[]) into v_paths from public.kombax_evento_media where evento_id=v_event;
  delete from public.kombax_eventos_publicos where id=v_event;
  return jsonb_build_object('ok',true,'removed',true,'storage_paths',to_jsonb(v_paths));
end $$;
revoke all on function public.app_kombax_demo_event_cleanup_v177() from public,anon;
grant execute on function public.app_kombax_demo_event_cleanup_v177() to authenticated;

comment on function public.app_kombax_demo_event_seed_v177() is '20.101 Owner-only QA bootstrap. Creates a normal public KOMBAX Event, participants and fights; it does not create a parallel demo domain.';
notify pgrst,'reload schema';
commit;
