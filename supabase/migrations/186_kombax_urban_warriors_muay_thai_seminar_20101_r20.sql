-- KOMBAX 20.101 R20 · Urban Warriors · Seminario Pro de Muay Thai · Adrián Serrano
-- Idempotent commercial/demo seed. No destructive cleanup. Uses the real KOMBAX Events domain and an internal Club Community post.
begin;

do $$
declare
  v_club uuid;
  v_author uuid;
  v_social uuid;
  v_event uuid;
  v_slug text := 'urban-warriors-seminario-pro-muay-thai-adrian-serrano-demo';
  v_post_path text := 'demo-static:assets/demo-events/urban-warriors-muay-thai-seminar/poster.webp';
  v_recap_path text := 'demo-static:assets/demo-events/urban-warriors-muay-thai-seminar/album-01-clinch.webp';
  v_count integer;
begin
  select c.id into v_club
  from public.clubes c
  where c.activo and (lower(trim(coalesce(c.slug,'')))='urban-warriors' or lower(trim(c.nombre))='urban warriors')
  order by case when lower(trim(coalesce(c.slug,'')))='urban-warriors' then 0 else 1 end,c.id
  limit 1;
  if v_club is null then raise exception 'KOMBAX_URBAN_WARRIORS_CLUB_NOT_FOUND'; end if;

  select m.perfil_id into v_author
  from public.miembros_club m
  where m.club_id=v_club and m.activo and m.rol in ('direccion','secretaria','comunicacion')
  order by case m.rol when 'direccion' then 0 when 'secretaria' then 1 else 2 end,m.perfil_id
  limit 1;
  if v_author is null then raise exception 'KOMBAX_URBAN_WARRIORS_STAFF_NOT_FOUND'; end if;

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

  insert into public.kombax_eventos_publicos(
    slug,tipo,nombre,resumen,descripcion,estado,visibilidad,fecha_inicio,fecha_fin,timezone,
    lugar_nombre,municipio,provincia,pais,cartel_url,banner_url,tema_visual,
    creador_tipo,creador_club_id,organizador_nombre,creado_por,publicado_en
  ) values(
    v_slug,'seminario','Seminario Pro de Muay Thai · Adrián Serrano',
    'Urban Warriors presenta una sesión técnica con el peleador profesional Adrián Serrano: clinch, timing, combinaciones y aplicación táctica.',
    'Seminario técnico de Muay Thai organizado por Urban Warriors y protagonizado por Adrián Serrano, peleador profesional ficticio creado para demostración comercial de KOMBAX. La sesión trabaja fundamentos aplicados de clinch, control de distancia, timing, combinaciones, rodillas y lectura táctica. El material visual de cartel, banner y álbum postevento se integra en el flujo real de KOMBAX Events. No representa una contratación real ni datos económicos de una persona existente.',
    'finalizado','publico','2026-08-23 10:00:00+02','2026-08-23 14:00:00+02','Europe/Madrid',
    'Urban Warriors','Palafolls','Barcelona','España',
    './assets/demo-events/urban-warriors-muay-thai-seminar/poster.webp',
    './assets/demo-events/urban-warriors-muay-thai-seminar/banner.webp','seminar',
    'club',v_club,'Urban Warriors',v_author,'2026-08-18 10:00:00+02'
  )
  on conflict(slug) do update set
    tipo=excluded.tipo,nombre=excluded.nombre,resumen=excluded.resumen,descripcion=excluded.descripcion,
    estado=excluded.estado,visibilidad=excluded.visibilidad,fecha_inicio=excluded.fecha_inicio,fecha_fin=excluded.fecha_fin,timezone=excluded.timezone,
    lugar_nombre=excluded.lugar_nombre,municipio=excluded.municipio,provincia=excluded.provincia,pais=excluded.pais,
    cartel_url=excluded.cartel_url,banner_url=excluded.banner_url,tema_visual=excluded.tema_visual,
    creador_tipo='club',creador_club_id=v_club,creador_perfil_directo_id=null,organizador_nombre='Urban Warriors',actualizado_en=now()
  returning id into v_event;

  -- Keep exactly one organizer principal for this seed event.
  delete from public.kombax_evento_entidades where evento_id=v_event and rol='organizador_principal';
  if v_social is not null then
    insert into public.kombax_evento_entidades(evento_id,rol,origen,social_profile_id,puede_gestionar,estado,orden,creado_por)
    values(v_event,'organizador_principal','kombax',v_social,true,'aceptada',0,v_author);
  else
    insert into public.kombax_evento_entidades(evento_id,rol,origen,nombre_externo,logo_url_externo,web_externa,puede_gestionar,estado,orden,creado_por)
    values(v_event,'organizador_principal','externa','Urban Warriors','https://kombax.es/assets/urban-warriors-logo.png','https://kombax.es/',false,'aceptada',0,v_author);
  end if;

  -- One public protagonist. No Fight Card is created for a seminar.
  select count(*) into v_count from public.kombax_evento_participantes_publicos where evento_id=v_event and nombre_publico='Adrián Serrano' and estado_inscripcion<>'retirada';
  if v_count>1 then raise exception 'KOMBAX_R20_SEMINAR_DUPLICATE_PROTAGONIST'; end if;
  if v_count=0 then
    insert into public.kombax_evento_participantes_publicos(evento_id,origen,nombre_publico,club_nombre,disciplina,categoria,estado_inscripcion,visible_publico,notas_publicas,creado_por)
    values(v_event,'externa','Adrián Serrano','Profesional invitado','Muay Thai','Peleador profesional · Seminario técnico','aceptada',true,'Perfil ficticio utilizado exclusivamente para seed comercial y QA de KOMBAX.',v_author);
  else
    update public.kombax_evento_participantes_publicos set
      club_nombre='Profesional invitado',disciplina='Muay Thai',categoria='Peleador profesional · Seminario técnico',estado_inscripcion='aceptada',visible_publico=true,
      notas_publicas='Perfil ficticio utilizado exclusivamente para seed comercial y QA de KOMBAX.',actualizado_en=now()
    where evento_id=v_event and nombre_publico='Adrián Serrano' and estado_inscripcion<>'retirada';
  end if;

  -- Community announcement: natural key = club + packaged poster path.
  select count(*) into v_count from public.publicaciones_comunidad where club_id=v_club and media_path=v_post_path and ciclo_estado='activo';
  if v_count>1 then raise exception 'KOMBAX_R20_COMMUNITY_ANNOUNCEMENT_DUPLICATE'; end if;
  if v_count=0 then
    insert into public.publicaciones_comunidad(club_id,autor_perfil_id,autor_nombre,autor_avatar_path,texto,media_path,media_tipo,media_mime,estado,creado_en,expira_en,ciclo_estado)
    select v_club,v_author,trim(concat_ws(' ',p.nombre,p.apellidos)),p.avatar_path,
      'Urban Warriors presenta el Seminario Pro de Muay Thai con Adrián Serrano. Una sesión intensiva de técnica, clinch, timing, combinaciones y aplicación táctica. Consulta la ficha completa en KOMBAX Events.',
      v_post_path,'imagen','image/webp','publicada','2026-08-18 10:05:00+02',now()+interval '30 days','activo'
    from public.perfiles p where p.id=v_author;
  else
    update public.publicaciones_comunidad set
      texto='Urban Warriors presenta el Seminario Pro de Muay Thai con Adrián Serrano. Una sesión intensiva de técnica, clinch, timing, combinaciones y aplicación táctica. Consulta la ficha completa en KOMBAX Events.',
      autor_perfil_id=v_author,media_tipo='imagen',media_mime='image/webp',estado='publicada',expira_en=now()+interval '30 days',ciclo_estado='activo'
    where club_id=v_club and media_path=v_post_path and ciclo_estado='activo';
  end if;

  -- Post-event recap using the first album image. This keeps the demo credible now that the event is finalized.
  select count(*) into v_count from public.publicaciones_comunidad where club_id=v_club and media_path=v_recap_path and ciclo_estado='activo';
  if v_count>1 then raise exception 'KOMBAX_R20_COMMUNITY_RECAP_DUPLICATE'; end if;
  if v_count=0 then
    insert into public.publicaciones_comunidad(club_id,autor_perfil_id,autor_nombre,autor_avatar_path,texto,media_path,media_tipo,media_mime,estado,creado_en,expira_en,ciclo_estado)
    select v_club,v_author,trim(concat_ws(' ',p.nombre,p.apellidos)),p.avatar_path,
      'Así se vivió el seminario de Adrián Serrano en Urban Warriors: trabajo técnico de clinch, control, rodillas y combinaciones con aplicación práctica. El álbum completo ya está disponible en KOMBAX Events.',
      v_recap_path,'imagen','image/webp','publicada','2026-08-23 18:30:00+02',now()+interval '30 days','activo'
    from public.perfiles p where p.id=v_author;
  else
    update public.publicaciones_comunidad set
      texto='Así se vivió el seminario de Adrián Serrano en Urban Warriors: trabajo técnico de clinch, control, rodillas y combinaciones con aplicación práctica. El álbum completo ya está disponible en KOMBAX Events.',
      autor_perfil_id=v_author,media_tipo='imagen',media_mime='image/webp',estado='publicada',expira_en=now()+interval '30 days',ciclo_estado='activo'
    where club_id=v_club and media_path=v_recap_path and ciclo_estado='activo';
  end if;
end $$;

commit;
