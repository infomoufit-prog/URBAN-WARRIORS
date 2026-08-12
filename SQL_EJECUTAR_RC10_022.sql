-- ==========================================================================
-- URBAN WARRIORS 2.0 RC10 FINAL MVP · v166
-- Notificaciones agrupadas · sesiones recurrentes · comunidad · perfil
-- finanzas/estado de cuenta · legal/consentimientos · preparación push
-- Ejecutar DESPUÉS de 021_access_roles_gestor_coordinacion_v165.sql.
-- Idempotente. Mantiene backend 1.6.0 / schema epoch 160 / app_mutate_v160.
-- ==========================================================================
begin;

-- --------------------------------------------------------------------------
-- 1. PERFIL, PREFERENCIAS Y LEGAL
-- --------------------------------------------------------------------------
alter table public.perfiles add column if not exists avatar_path text;

create table if not exists public.preferencias_notificacion (
  club_id uuid not null references public.clubes(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  push_general boolean not null default true,
  push_finanzas boolean not null default true,
  push_sesiones boolean not null default true,
  push_comunidad boolean not null default false,
  actualizado_en timestamptz not null default now(),
  primary key(club_id,perfil_id)
);
alter table public.preferencias_notificacion enable row level security;
drop policy if exists preferencias_notificacion_propias on public.preferencias_notificacion;
create policy preferencias_notificacion_propias on public.preferencias_notificacion
for select to authenticated using(perfil_id=auth.uid());
revoke all on public.preferencias_notificacion from public,anon;
grant select on public.preferencias_notificacion to authenticated;

create table if not exists public.aceptaciones_legales (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  socio_id uuid,
  texto_legal_id uuid not null,
  tipo text not null,
  version text not null,
  aceptado boolean not null,
  aceptado_en timestamptz not null default now(),
  revocado_en timestamptz,
  user_agent text,
  foreign key(club_id,socio_id) references public.socios(club_id,id) on delete cascade,
  foreign key(club_id,texto_legal_id) references public.textos_legales(club_id,id) on delete restrict,
  unique(club_id,perfil_id,socio_id,tipo,version)
);
alter table public.aceptaciones_legales enable row level security;
drop policy if exists aceptaciones_legales_propias on public.aceptaciones_legales;
create policy aceptaciones_legales_propias on public.aceptaciones_legales
for select to authenticated using(perfil_id=auth.uid() or public.tiene_rol_club(club_id,'direccion','secretaria'));
revoke all on public.aceptaciones_legales from public,anon;
grant select on public.aceptaciones_legales to authenticated;

-- Textos legales vigentes visibles incluso antes del registro.
alter table public.textos_legales enable row level security;
drop policy if exists textos_legales_publicos_rc10 on public.textos_legales;
create policy textos_legales_publicos_rc10 on public.textos_legales
for select to anon,authenticated using(vigente=true);
grant select on public.textos_legales to anon,authenticated;

-- Semillas versionadas por club. El nombre/email se presentan dinámicamente en UI.
-- Desactivar primero versiones anteriores para respetar el índice parcial
-- (una sola versión vigente por club/tipo) antes de insertar 2.0.0.
update public.textos_legales set vigente=false
where tipo in ('condiciones_uso','privacidad','comunidad','derechos_imagen') and version<>'2.0.0' and vigente;
insert into public.textos_legales(club_id,tipo,version,cuerpo,vigente)
select c.id,'condiciones_uso','2.0.0',
E'CONDICIONES DE USO DE URBAN WARRIORS\n\n1. Objeto. Urban Warriors es una herramienta de gestión interna del club para matrículas, sesiones, asistencia, comunicaciones, material, documentación y pagos.\n\n2. Cuenta. Cada persona usuaria debe utilizar datos veraces, custodiar sus credenciales y no compartir la cuenta. Los menores utilizan la plataforma mediante la cuenta de su padre, madre o tutor cuando corresponda.\n\n3. Comunidad. El contenido debe estar relacionado con la actividad del club y respetar a terceros. No se permite contenido ofensivo, intimidatorio, discriminatorio, ilícito, sexual, violento fuera del contexto deportivo, datos personales de terceros sin autorización, publicidad no autorizada ni material que vulnere derechos. El club puede ocultar o eliminar contenido y suspender el acceso cuando exista incumplimiento.\n\n4. Publicaciones temporales. El contenido social de Comunidad tiene límites mensuales y una retención máxima de 30 días. Su eliminación implica también la eliminación del archivo multimedia asociado cuando técnicamente sea posible.\n\n5. Sesiones y reservas. Confirmar asistencia expresa intención de acudir; el check-in registra la asistencia real. El club puede cancelar, sustituir monitor, cambiar sala u horario de una sesión y comunicarlo a las personas afectadas.\n\n6. Pagos. La información económica de la aplicación es un soporte de gestión del club. Los recibos anulados conservan trazabilidad.\n\n7. Disponibilidad. El servicio puede interrumpirse por mantenimiento, seguridad o incidencias técnicas.\n\n8. Uso responsable. La persona usuaria se compromete a utilizar la plataforma conforme a la ley, estas condiciones y las normas del club.\n\n9. Modificaciones. Los cambios sustanciales se publicarán mediante una nueva versión de estas condiciones y podrán requerir nueva aceptación.',true
from public.clubes c
on conflict(club_id,tipo,version) do update set cuerpo=excluded.cuerpo,vigente=true;

insert into public.textos_legales(club_id,tipo,version,cuerpo,vigente)
select c.id,'privacidad','2.0.0',
E'POLÍTICA DE PRIVACIDAD\n\nResponsable: la entidad titular del club identificado en Urban Warriors. Los datos de contacto del club se muestran en Configuración y en las comunicaciones oficiales.\n\nFinalidades: gestionar la relación con socios y familias; altas y matrículas; grupos, sesiones, reservas y asistencia; progreso deportivo y seguimiento; documentación administrativa; cuotas, pagos y recibos; solicitudes de material; comunicaciones y notificaciones; seguridad y soporte de la aplicación.\n\nDatos tratados: identificación y contacto; relación familiar cuando exista; información deportiva y de asistencia; documentación aportada; información económica vinculada a cuotas y pagos; contenido que el usuario decida publicar; datos técnicos mínimos de sesión y dispositivo necesarios para seguridad y notificaciones.\n\nBase jurídica: ejecución de la relación con el club y prestación de los servicios solicitados; cumplimiento de obligaciones legales cuando proceda; interés legítimo en seguridad y administración; y consentimiento cuando el tratamiento lo requiera, especialmente en usos opcionales de imagen.\n\nMenores: cuando el tratamiento se base en consentimiento, se aplicarán las reglas legales de capacidad y representación vigentes.\n\nConservación: durante la relación con el club y los plazos necesarios para atender obligaciones legales o reclamaciones. El contenido social de Comunidad se elimina a los 30 días como máximo.\n\nDestinatarios y proveedores: únicamente personal autorizado del club y proveedores tecnológicos necesarios para prestar la aplicación, bajo las garantías correspondientes.\n\nDerechos: acceso, rectificación, supresión, oposición, limitación, portabilidad cuando proceda y retirada del consentimiento. Las solicitudes se dirigen al club. También puede acudirse a la Agencia Española de Protección de Datos.\n\nSeguridad: la plataforma aplica control de acceso por roles, almacenamiento privado para documentación y trazabilidad de operaciones relevantes.',true
from public.clubes c
on conflict(club_id,tipo,version) do update set cuerpo=excluded.cuerpo,vigente=true;

insert into public.textos_legales(club_id,tipo,version,cuerpo,vigente)
select c.id,'comunidad','2.0.0',
E'POLÍTICA DE COMUNIDAD\n\nLa Comunidad es un espacio interno del club. Los usuarios pueden compartir contenido relacionado con entrenamientos, competición, celebraciones y vida deportiva.\n\nLímites: hasta 3 publicaciones al mes por cuenta de alumno/familia. El equipo del club puede publicar hasta 5 contenidos sociales al mes. Cada publicación admite una imagen o un vídeo de hasta 15 segundos.\n\nCaducidad: las publicaciones de Comunidad caducan a los 30 días y se eliminan junto con su archivo multimedia.\n\nPrivacidad: el perfil público no es navegable. En Comunidad solo se muestra el nombre y, si existe, la fotografía de perfil del autor junto al contenido publicado.\n\nModeración: el autor puede borrar su contenido. El Gestor de la app, Coordinación y Comunicación pueden ocultar o eliminar contenido que incumpla las normas o afecte a terceros.\n\nImágenes de terceros: quien publica debe disponer de autorización suficiente para compartir imágenes o vídeos de otras personas. La autorización de imagen dentro de Urban Warriors no equivale a una autorización para publicar externamente en redes sociales del club.',true
from public.clubes c
on conflict(club_id,tipo,version) do update set cuerpo=excluded.cuerpo,vigente=true;

insert into public.textos_legales(club_id,tipo,version,cuerpo,vigente)
select c.id,'derechos_imagen','2.0.0',
E'AUTORIZACIÓN DE IMAGEN Y CONTENIDO AUDIOVISUAL\n\nEsta autorización es opcional y separada de las condiciones necesarias para utilizar las funciones esenciales de gestión del club.\n\nAl aceptarla, la persona autoriza al club a mostrar su imagen o la del menor representado, según corresponda, dentro de Urban Warriors para finalidades de comunidad interna, información deportiva y comunicaciones del propio club.\n\nLa autorización no incluye por sí sola la difusión abierta en redes sociales, publicidad externa o medios ajenos a Urban Warriors. Para esos usos deberá existir una autorización específica cuando sea necesaria.\n\nLa autorización puede retirarse para usos futuros mediante solicitud al club. La retirada no afecta a tratamientos realizados lícitamente con anterioridad. El club atenderá solicitudes de retirada o supresión de imágenes conforme a la normativa aplicable.',true
from public.clubes c
on conflict(club_id,tipo,version) do update set cuerpo=excluded.cuerpo,vigente=true;

-- Solo una versión vigente por tipo.
update public.textos_legales t set vigente=false
where t.version<>'2.0.0' and t.tipo in ('condiciones_uso','privacidad','comunidad','derechos_imagen')
  and exists(select 1 from public.textos_legales x where x.club_id=t.club_id and x.tipo=t.tipo and x.version='2.0.0');

-- Los clubes creados después de RC10 reciben automáticamente las mismas
-- plantillas legales vigentes. La identidad/contacto del responsable se presenta
-- dinámicamente desde la configuración de cada club.
create or replace function public.app_seed_legal_new_club_rc10()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.textos_legales(club_id,tipo,version,cuerpo,vigente)
  select new.id,t.tipo,t.version,t.cuerpo,true
  from (
    select distinct on(tipo) tipo,version,cuerpo
    from public.textos_legales
    where version='2.0.0' and vigente and club_id<>new.id
    order by tipo,creado_en,id
  ) t
  on conflict(club_id,tipo,version) do update set cuerpo=excluded.cuerpo,vigente=true;
  return new;
end $$;
revoke all on function public.app_seed_legal_new_club_rc10() from public,anon,authenticated;
drop trigger if exists clubes_seed_legal_rc10 on public.clubes;
create trigger clubes_seed_legal_rc10 after insert on public.clubes
for each row execute function public.app_seed_legal_new_club_rc10();

-- Buckets privados.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('profile-media','profile-media',false,5242880,array['image/jpeg','image/png','image/webp']::text[])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('community-media','community-media',false,20971520,array['image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime']::text[])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

-- profile-media: club/perfil/archivo
 drop policy if exists profile_media_read_rc10 on storage.objects;
create policy profile_media_read_rc10 on storage.objects for select to authenticated using(
  bucket_id='profile-media' and array_length(storage.foldername(name),1)>=2
  and public.es_miembro_club(((storage.foldername(name))[1])::uuid)
);
drop policy if exists profile_media_write_rc10 on storage.objects;
create policy profile_media_write_rc10 on storage.objects for insert to authenticated with check(
  bucket_id='profile-media' and array_length(storage.foldername(name),1)>=2
  and ((storage.foldername(name))[2])::uuid=auth.uid()
  and public.es_miembro_club(((storage.foldername(name))[1])::uuid)
);
drop policy if exists profile_media_delete_rc10 on storage.objects;
create policy profile_media_delete_rc10 on storage.objects for delete to authenticated using(
  bucket_id='profile-media' and array_length(storage.foldername(name),1)>=2
  and (((storage.foldername(name))[2])::uuid=auth.uid() or public.tiene_rol_club(((storage.foldername(name))[1])::uuid,'direccion'))
);

-- --------------------------------------------------------------------------
-- 2. COMUNIDAD TEMPORAL
-- --------------------------------------------------------------------------
create table if not exists public.publicaciones_comunidad (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  autor_perfil_id uuid not null references public.perfiles(id) on delete cascade,
  autor_nombre text not null,
  autor_avatar_path text,
  texto text,
  media_path text not null,
  media_tipo text not null check(media_tipo in ('imagen','video')),
  duracion_segundos numeric(6,2),
  estado text not null default 'publicada' check(estado in ('publicada','oculta')),
  moderada_por uuid references public.perfiles(id),
  moderacion_motivo text,
  creado_en timestamptz not null default now(),
  expira_en timestamptz not null default (now()+interval '30 days'),
  unique(club_id,id)
);
create index if not exists publicaciones_comunidad_feed_idx on public.publicaciones_comunidad(club_id,estado,creado_en desc);
create index if not exists publicaciones_comunidad_expira_idx on public.publicaciones_comunidad(expira_en) where estado='publicada';
alter table public.publicaciones_comunidad enable row level security;
drop policy if exists comunidad_lectura_rc10 on public.publicaciones_comunidad;
create policy comunidad_lectura_rc10 on public.publicaciones_comunidad for select to authenticated using(
  public.es_miembro_club(club_id) and (estado='publicada' or autor_perfil_id=auth.uid() or public.tiene_rol_club(club_id,'direccion','secretaria','comunicacion'))
);
revoke all on public.publicaciones_comunidad from public,anon;
grant select on public.publicaciones_comunidad to authenticated;

-- community-media: club/perfil/archivo, lectura solo miembros del club.
drop policy if exists community_media_read_rc10 on storage.objects;
create policy community_media_read_rc10 on storage.objects for select to authenticated using(
  bucket_id='community-media' and array_length(storage.foldername(name),1)>=2
  and public.es_miembro_club(((storage.foldername(name))[1])::uuid)
);
drop policy if exists community_media_write_rc10 on storage.objects;
create policy community_media_write_rc10 on storage.objects for insert to authenticated with check(
  bucket_id='community-media' and array_length(storage.foldername(name),1)>=2
  and ((storage.foldername(name))[2])::uuid=auth.uid()
  and public.es_miembro_club(((storage.foldername(name))[1])::uuid)
);
drop policy if exists community_media_delete_rc10 on storage.objects;
create policy community_media_delete_rc10 on storage.objects for delete to authenticated using(
  bucket_id='community-media' and array_length(storage.foldername(name),1)>=2
  and (
    ((storage.foldername(name))[2])::uuid=auth.uid()
    or public.tiene_rol_club(((storage.foldername(name))[1])::uuid,'direccion','secretaria','comunicacion')
  )
);

-- --------------------------------------------------------------------------
-- 3. SESIONES RECURRENTES
-- --------------------------------------------------------------------------
create table if not exists public.series_sesiones (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  grupo_id uuid not null,
  dias_semana smallint[] not null,
  hora_inicio time not null,
  hora_fin time,
  monitor_nombre text,
  sala text,
  codigo_acceso text,
  fecha_inicio date not null default current_date,
  fecha_fin date,
  activa boolean not null default true,
  creado_por uuid references public.perfiles(id),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  foreign key(club_id,grupo_id) references public.grupos(club_id,id) on delete cascade,
  check(cardinality(dias_semana)>=1),
  check(0 < all(dias_semana) and 8 > all(dias_semana)),
  unique(club_id,id)
);
create index if not exists series_sesiones_club_activa_idx on public.series_sesiones(club_id,activa,grupo_id);
alter table public.series_sesiones enable row level security;
drop policy if exists series_sesiones_lectura_rc10 on public.series_sesiones;
create policy series_sesiones_lectura_rc10 on public.series_sesiones for select to authenticated using(public.es_miembro_club(club_id));
revoke all on public.series_sesiones from public,anon;
grant select on public.series_sesiones to authenticated;

alter table public.sesiones_entrenamiento add column if not exists serie_id uuid;
alter table public.sesiones_entrenamiento add column if not exists sala text;
alter table public.sesiones_entrenamiento add column if not exists motivo_cambio text;
do $$ begin
  if not exists(select 1 from pg_constraint where conname='sesiones_entrenamiento_serie_fk') then
    alter table public.sesiones_entrenamiento add constraint sesiones_entrenamiento_serie_fk foreign key(serie_id) references public.series_sesiones(id) on delete set null;
  end if;
end $$;
create unique index if not exists sesiones_entrenamiento_serie_fecha_uidx on public.sesiones_entrenamiento(club_id,serie_id,fecha) where serie_id is not null;

create or replace function public.app_generar_sesiones_recurrentes(p_club_id uuid,p_horizonte_dias integer default 84)
returns integer language plpgsql security definer set search_path=public,auth as $$
declare v_count integer:=0; v_s public.series_sesiones; v_d date;
begin
  if p_horizonte_dias<7 or p_horizonte_dias>180 then p_horizonte_dias:=84; end if;
  for v_s in select * from public.series_sesiones where club_id=p_club_id and activa loop
    for v_d in select gs::date from generate_series(greatest(current_date,v_s.fecha_inicio),least(current_date+p_horizonte_dias,coalesce(v_s.fecha_fin,current_date+p_horizonte_dias)),interval '1 day') gs
      where extract(isodow from gs)::int=any(v_s.dias_semana)
    loop
      insert into public.sesiones_entrenamiento(club_id,grupo_id,fecha,hora_inicio,hora_fin,monitor_nombre,estado,observacion_general,codigo_acceso,serie_id,sala)
      values(v_s.club_id,v_s.grupo_id,v_d,v_s.hora_inicio,v_s.hora_fin,v_s.monitor_nombre,'programada','Sesión recurrente',null,v_s.id,v_s.sala)
      on conflict do nothing;
      if found then v_count:=v_count+1; end if;
    end loop;
  end loop;
  return v_count;
end $$;
revoke all on function public.app_generar_sesiones_recurrentes(uuid,integer) from public,anon;
grant execute on function public.app_generar_sesiones_recurrentes(uuid,integer) to authenticated,service_role;

-- --------------------------------------------------------------------------
-- 4. FINANZAS: ESTADO DE CUENTA
-- --------------------------------------------------------------------------
create or replace view public.v_estado_cuenta_socio with (security_invoker=true) as
select
  q.club_id,
  q.socio_id,
  q.id as cuota_id,
  q.periodo,
  q.concepto,
  q.importe,
  q.vencimiento,
  q.estado,
  coalesce(pa.pagado_validado,0)::numeric(10,2) as pagado_validado,
  greatest(q.importe-coalesce(pa.pagado_validado,0),0)::numeric(10,2) as saldo,
  pa.ultima_fecha_pago,
  rc.recibo_id,
  rc.recibo_numero,
  rc.recibo_anulado_en
from public.cuotas q
left join lateral (
  select
    coalesce(sum(p.importe) filter(where p.estado_validacion='validado'),0)::numeric(10,2) as pagado_validado,
    max(p.fecha) filter(where p.estado_validacion='validado') as ultima_fecha_pago
  from public.pagos p
  where p.club_id=q.club_id and p.cuota_id=q.id
) pa on true
left join lateral (
  select
    r.id as recibo_id,
    r.numero as recibo_numero,
    r.anulado_en as recibo_anulado_en
  from public.recibos_cuota r
  where r.club_id=q.club_id and r.cuota_id=q.id
  limit 1
) rc on true;
grant select on public.v_estado_cuenta_socio to authenticated;

-- --------------------------------------------------------------------------
-- 5. GATEWAY RC10
-- --------------------------------------------------------------------------
do $$ begin
  if to_regprocedure('public.app_mutate_v160_v165(text,jsonb,uuid)') is null and to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null then
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_v165;
  end if;
end $$;
revoke all on function public.app_mutate_v160_v165(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_runtime_contract_v160(p_club_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid(); v_roles jsonb; v_meta public.app_runtime_meta;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  if not public.es_miembro_club(p_club_id) then raise exception 'CLUB_MEMBERSHIP_REQUIRED: la cuenta no pertenece al club activo'; end if;
  select * into v_meta from public.app_runtime_meta where singleton=true;
  select coalesce(jsonb_agg(m.rol order by m.rol::text),'[]'::jsonb) into v_roles from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=v_uid and m.activo;
  return jsonb_build_object('ok',true,'backend_version',v_meta.backend_version,'schema_epoch',v_meta.schema_epoch,'mutation_endpoint',v_meta.mutation_endpoint,'club_id',p_club_id,'user_id',v_uid,'roles',v_roles,'write_ready',true,
  'operations',jsonb_build_array(
    'cuenta.registrar','invitacion.aceptar','invitacion.crear','perfil.guardar','disciplina.guardar','grado.guardar','grupo.guardar','alumno.guardar','preinscripcion.crear','preinscripcion.aprobar','preinscripcion.espera','preinscripcion.rechazar','matricula.solicitar','matricula.desactivar','graduacion.registrar','tarifa.guardar','material.guardar','material.variante.guardar','material.solicitar','material.pedido.estado','publicacion.guardar','sesion.guardar','asistencia.guardar','checkin.registrar','seguimiento.guardar','documento.registrar','notificacion.leer','pago.comunicar','pago.registrar_admin','pago.validar','cuota.pausar_avisos','cuota.reactivar_avisos','avisos.configurar','cuotas.generar','avisos.procesar','club.configurar','push.registrar','grupo.eliminar','alumno.archivar','alumno.eliminar','preinscripcion.cancelar','preinscripcion.eliminar','sesion.eliminar','disciplina.eliminar','grado.eliminar','tarifa.eliminar','material.eliminar','publicacion.eliminar','recibo.anular','documento.actualizar','documento.archivar','documento.eliminar','grupo.eliminar_forzado','alumno.eliminar_forzado','sesion.eliminar_forzado','disciplina.eliminar_forzado','grado.eliminar_forzado','tarifa.eliminar_forzado','material.eliminar_forzado','publicacion.limpiar_antiguas','sesion.reserva.confirmar','sesion.reserva.cancelar',
    'notificacion.leer_grupo','notificacion.leer_todas','notificaciones.preferencias','sesion.serie.guardar','sesion.excepcion.guardar','sesion.serie.finalizar','sesiones.recurrentes.generar','comunidad.publicar','comunidad.eliminar','comunidad.moderar','perfil.avatar','legal.aceptar'
  ));
end $$;
revoke all on function public.app_runtime_contract_v160(uuid) from public,anon;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid(); v_payload jsonb:=coalesce(p_payload,'{}'::jsonb); v_club uuid; v_existing public.app_mutation_requests; v_result jsonb;
  v_id uuid; v_tipo text; v_version text; v_texto uuid; v_path text; v_old_path text; v_post public.publicaciones_comunidad; v_count integer; v_is_staff boolean; v_serie public.series_sesiones;
begin
  if p_operation not in ('notificacion.leer_grupo','notificacion.leer_todas','notificaciones.preferencias','sesion.serie.guardar','sesion.excepcion.guardar','sesion.serie.finalizar','sesiones.recurrentes.generar','comunidad.publicar','comunidad.eliminar','comunidad.moderar','perfil.avatar','legal.aceptar') then
    return public.app_mutate_v160_v165(p_operation,p_payload,p_request_id);
  end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  begin v_club:=nullif(v_payload->>'club_id','')::uuid; exception when others then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
  if v_club is null or not public.es_miembro_club(v_club) then raise exception 'MUTATION_MEMBERSHIP_REQUIRED'; end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,v_club,p_operation); end if;

  if p_operation='notificacion.leer_todas' then
    insert into public.notificaciones_lecturas(notificacion_id,perfil_id)
    select n.id,v_uid from public.notificaciones n where n.club_id=v_club and (
      n.perfil_id=v_uid or n.audiencia='todos' or (n.rol_destino is not null and public.tiene_rol_club(v_club,n.rol_destino))
    ) on conflict(notificacion_id,perfil_id) do update set leida_en=now();
    update public.notificaciones set leida=true,leida_en=now() where club_id=v_club and perfil_id=v_uid;
    get diagnostics v_count=row_count; v_result:=jsonb_build_object('marcadas',v_count);

  elsif p_operation='notificacion.leer_grupo' then
    v_tipo:=coalesce(nullif(v_payload->>'tipo',''),'general');
    insert into public.notificaciones_lecturas(notificacion_id,perfil_id)
    select n.id,v_uid from public.notificaciones n where n.club_id=v_club and coalesce(n.tipo,'general')=v_tipo and (
      n.perfil_id=v_uid or n.audiencia='todos' or (n.rol_destino is not null and public.tiene_rol_club(v_club,n.rol_destino))
    ) on conflict(notificacion_id,perfil_id) do update set leida_en=now();
    update public.notificaciones set leida=true,leida_en=now() where club_id=v_club and perfil_id=v_uid and coalesce(tipo,'general')=v_tipo;
    v_result:=jsonb_build_object('tipo',v_tipo,'ok',true);

  elsif p_operation='notificaciones.preferencias' then
    insert into public.preferencias_notificacion(club_id,perfil_id,push_general,push_finanzas,push_sesiones,push_comunidad,actualizado_en)
    values(v_club,v_uid,coalesce((v_payload->>'push_general')::boolean,true),coalesce((v_payload->>'push_finanzas')::boolean,true),coalesce((v_payload->>'push_sesiones')::boolean,true),coalesce((v_payload->>'push_comunidad')::boolean,true),now())
    on conflict(club_id,perfil_id) do update set push_general=excluded.push_general,push_finanzas=excluded.push_finanzas,push_sesiones=excluded.push_sesiones,push_comunidad=excluded.push_comunidad,actualizado_en=now();
    v_result:=jsonb_build_object('ok',true);

  elsif p_operation='perfil.avatar' then
    v_path:=nullif(v_payload->>'avatar_path','');
    select avatar_path into v_old_path from public.perfiles where id=v_uid;
    update public.perfiles set avatar_path=v_path,avatar_url=null,actualizado_en=now() where id=v_uid;
    update public.publicaciones_comunidad set autor_avatar_path=v_path where club_id=v_club and autor_perfil_id=v_uid;
    v_result:=jsonb_build_object('avatar_path',v_path,'old_avatar_path',v_old_path);

  elsif p_operation='legal.aceptar' then
    v_tipo:=lower(trim(coalesce(v_payload->>'tipo',''))); v_version:=coalesce(nullif(v_payload->>'version',''),'2.0.0');
    select id into v_texto from public.textos_legales where club_id=v_club and tipo=v_tipo and version=v_version and vigente limit 1;
    if v_texto is null then raise exception 'Documento legal no disponible'; end if;
    v_id:=nullif(v_payload->>'socio_id','')::uuid;
    delete from public.aceptaciones_legales
      where club_id=v_club and perfil_id=v_uid and socio_id is not distinct from v_id and tipo=v_tipo and version=v_version;
    insert into public.aceptaciones_legales(club_id,perfil_id,socio_id,texto_legal_id,tipo,version,aceptado,aceptado_en,revocado_en,user_agent)
    values(v_club,v_uid,v_id,v_texto,v_tipo,v_version,coalesce((v_payload->>'aceptado')::boolean,true),now(),case when coalesce((v_payload->>'aceptado')::boolean,true) then null else now() end,left(coalesce(v_payload->>'user_agent',''),500));
    v_result:=jsonb_build_object('tipo',v_tipo,'version',v_version,'aceptado',coalesce((v_payload->>'aceptado')::boolean,true));

  elsif p_operation='sesion.excepcion.guardar' then
    if not public.tiene_rol_club(v_club,'direccion','secretaria','monitor') then raise exception 'No tienes permiso para modificar sesiones'; end if;
    v_id:=(v_payload->>'sesion_id')::uuid;
    declare v_before public.sesiones_entrenamiento; v_after public.sesiones_entrenamiento; v_group_name text; v_msg text; begin
      select * into v_before from public.sesiones_entrenamiento where club_id=v_club and id=v_id for update;
      if v_before.id is null then raise exception 'Sesión no encontrada'; end if;
      update public.sesiones_entrenamiento set
        estado=coalesce(nullif(v_payload->>'estado',''),estado),
        monitor_nombre=coalesce(nullif(v_payload->>'monitor_nombre',''),monitor_nombre),
        hora_inicio=coalesce(nullif(v_payload->>'hora_inicio','')::time,hora_inicio),
        hora_fin=coalesce(nullif(v_payload->>'hora_fin','')::time,hora_fin),
        sala=coalesce(nullif(v_payload->>'sala',''),sala),
        observacion_general=coalesce(nullif(v_payload->>'observacion_general',''),observacion_general),
        motivo_cambio=left(coalesce(v_payload->>'motivo',''),500)
      where club_id=v_club and id=v_id returning * into v_after;
      select nombre into v_group_name from public.grupos where club_id=v_club and id=v_after.grupo_id;
      v_msg:=case when v_after.estado='cancelada' then 'Sesión cancelada'
        when coalesce(v_before.monitor_nombre,'')<>coalesce(v_after.monitor_nombre,'') then 'Cambio de monitor'
        when v_before.hora_inicio<>v_after.hora_inicio or coalesce(v_before.hora_fin,'00:00')<>coalesce(v_after.hora_fin,'00:00') then 'Cambio de horario'
        else 'Actualización de sesión' end;
      insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
      select distinct v_club,x.perfil_id,'sesion-cambio-'||v_id||'-'||x.perfil_id||'-'||extract(epoch from now())::bigint,'sesion_cambio',v_msg,
        coalesce(v_group_name,'Clase')||' · '||to_char(v_after.fecha,'DD/MM/YYYY')||' · '||to_char(v_after.hora_inicio,'HH24:MI')||case when coalesce(v_payload->>'motivo','')<>'' then ' · '||left(v_payload->>'motivo',180) else '' end,
        'groups',jsonb_build_object('sesion_id',v_id,'grupo_id',v_after.grupo_id,'estado',v_after.estado),v_uid
      from (
        select s.perfil_id from public.socios s join public.socio_disciplinas sd on sd.club_id=s.club_id and sd.socio_id=s.id and sd.activa where s.club_id=v_club and sd.grupo_id=v_after.grupo_id and s.perfil_id is not null
        union
        select ts.tutor_perfil_id from public.tutores_socios ts join public.socio_disciplinas sd on sd.club_id=ts.club_id and sd.socio_id=ts.socio_id and sd.activa where ts.club_id=v_club and sd.grupo_id=v_after.grupo_id
      ) x where x.perfil_id is not null;
      v_result:=to_jsonb(v_after);
    end;

  elsif p_operation='sesion.serie.guardar' then
    if not public.tiene_rol_club(v_club,'direccion','secretaria','monitor') then raise exception 'No tienes permiso para gestionar series'; end if;
    v_id:=nullif(v_payload->>'id','')::uuid;
    if v_id is null then
      insert into public.series_sesiones(club_id,grupo_id,dias_semana,hora_inicio,hora_fin,monitor_nombre,sala,codigo_acceso,fecha_inicio,fecha_fin,activa,creado_por)
      values(v_club,(v_payload->>'grupo_id')::uuid,array(select jsonb_array_elements_text(v_payload->'dias_semana')::smallint),(v_payload->>'hora_inicio')::time,nullif(v_payload->>'hora_fin','')::time,coalesce(v_payload->>'monitor_nombre',''),coalesce(v_payload->>'sala',''),nullif(v_payload->>'codigo_acceso',''),coalesce(nullif(v_payload->>'fecha_inicio','')::date,current_date),nullif(v_payload->>'fecha_fin','')::date,true,v_uid)
      returning * into v_serie;
    else
      -- Las ocurrencias futuras sin actividad se regeneran con la nueva plantilla.
      -- Si una ocurrencia ya tiene reservas/asistencia/accesos se desacopla de la
      -- serie para conservar su histórico y poder gestionarla como excepción.
      update public.sesiones_entrenamiento se set serie_id=null,
        motivo_cambio=coalesce(nullif(se.motivo_cambio,''),'Conservada al editar la serie por tener actividad asociada')
      where se.club_id=v_club and se.serie_id=v_id and se.fecha>=current_date and (
        exists(select 1 from public.reservas_sesion r where r.club_id=se.club_id and r.sesion_id=se.id)
        or exists(select 1 from public.asistencias a where a.club_id=se.club_id and a.sesion_id=se.id)
        or exists(select 1 from public.registros_acceso_clase ra where ra.club_id=se.club_id and ra.sesion_id=se.id)
      );
      delete from public.sesiones_entrenamiento se
      where se.club_id=v_club and se.serie_id=v_id and se.fecha>=current_date;

      update public.series_sesiones set grupo_id=(v_payload->>'grupo_id')::uuid,dias_semana=array(select jsonb_array_elements_text(v_payload->'dias_semana')::smallint),hora_inicio=(v_payload->>'hora_inicio')::time,hora_fin=nullif(v_payload->>'hora_fin','')::time,monitor_nombre=coalesce(v_payload->>'monitor_nombre',''),sala=coalesce(v_payload->>'sala',''),codigo_acceso=nullif(v_payload->>'codigo_acceso',''),fecha_inicio=coalesce(nullif(v_payload->>'fecha_inicio','')::date,current_date),fecha_fin=nullif(v_payload->>'fecha_fin','')::date,activa=coalesce((v_payload->>'activa')::boolean,true),actualizado_en=now() where club_id=v_club and id=v_id returning * into v_serie;
      if v_serie.id is null then raise exception 'Serie no encontrada'; end if;
    end if;
    perform public.app_generar_sesiones_recurrentes(v_club,84);
    v_result:=to_jsonb(v_serie);

  elsif p_operation='sesion.serie.finalizar' then
    if not public.tiene_rol_club(v_club,'direccion','secretaria','monitor') then raise exception 'No tienes permiso para gestionar series'; end if;
    v_id:=(v_payload->>'serie_id')::uuid;
    declare v_cutoff date:=coalesce(nullif(v_payload->>'fecha_fin','')::date,current_date); v_group uuid; begin
      update public.series_sesiones set activa=false,fecha_fin=v_cutoff,actualizado_en=now()
        where club_id=v_club and id=v_id returning grupo_id into v_group;
      if v_group is null then raise exception 'Serie no encontrada'; end if;

      -- Las ocurrencias futuras sin actividad desaparecen. Si ya tienen una reserva,
      -- asistencia o acceso se mantienen como evidencia, pero quedan canceladas.
      update public.sesiones_entrenamiento se set estado='cancelada',serie_id=null,
        motivo_cambio='Serie finalizada por el club'
      where se.club_id=v_club and se.serie_id=v_id and se.fecha>v_cutoff and (
        exists(select 1 from public.reservas_sesion r where r.club_id=se.club_id and r.sesion_id=se.id)
        or exists(select 1 from public.asistencias a where a.club_id=se.club_id and a.sesion_id=se.id)
        or exists(select 1 from public.registros_acceso_clase ra where ra.club_id=se.club_id and ra.sesion_id=se.id)
      );
      delete from public.sesiones_entrenamiento se
        where se.club_id=v_club and se.serie_id=v_id and se.fecha>v_cutoff;

      insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
      select distinct v_club,x.perfil_id,'serie-finalizada-'||v_id||'-'||x.perfil_id,'sesion_cambio','Programación de clases actualizada',
        'La serie semanal ha finalizado. Revisa tus próximas sesiones.','groups',jsonb_build_object('serie_id',v_id,'grupo_id',v_group,'fecha_fin',v_cutoff),v_uid
      from (
        select s.perfil_id from public.socios s join public.socio_disciplinas sd on sd.club_id=s.club_id and sd.socio_id=s.id and sd.activa where s.club_id=v_club and sd.grupo_id=v_group and s.perfil_id is not null
        union
        select ts.tutor_perfil_id from public.tutores_socios ts join public.socio_disciplinas sd on sd.club_id=ts.club_id and sd.socio_id=ts.socio_id and sd.activa where ts.club_id=v_club and sd.grupo_id=v_group
      ) x where x.perfil_id is not null
      on conflict do nothing;
      v_result:=jsonb_build_object('serie_id',v_id,'activa',false,'fecha_fin',v_cutoff);
    end;

  elsif p_operation='sesiones.recurrentes.generar' then
    if not public.tiene_rol_club(v_club,'direccion','secretaria','monitor') then raise exception 'No tienes permiso para generar sesiones'; end if;
    v_count:=public.app_generar_sesiones_recurrentes(v_club,coalesce(nullif(v_payload->>'horizonte_dias','')::int,84));
    v_result:=jsonb_build_object('creadas',v_count);

  elsif p_operation='comunidad.publicar' then
    v_path:=nullif(v_payload->>'media_path',''); v_tipo:=lower(coalesce(v_payload->>'media_tipo',''));
    if v_path is null or v_tipo not in ('imagen','video') then raise exception 'Imagen o vídeo obligatorio'; end if;
    if v_tipo='video' and coalesce(nullif(v_payload->>'duracion_segundos','')::numeric,999)>15.2 then raise exception 'El vídeo supera 15 segundos'; end if;
    select exists(select 1 from public.miembros_club where club_id=v_club and perfil_id=v_uid and activo and rol in ('direccion','secretaria','comunicacion')) into v_is_staff;
    select count(*) into v_count from public.publicaciones_comunidad where club_id=v_club and autor_perfil_id=v_uid and creado_en>=date_trunc('month',now()) and creado_en<date_trunc('month',now())+interval '1 month';
    if (v_is_staff and v_count>=5) or (not v_is_staff and v_count>=3) then raise exception 'Has alcanzado el límite mensual de publicaciones'; end if;
    insert into public.publicaciones_comunidad(club_id,autor_perfil_id,autor_nombre,autor_avatar_path,texto,media_path,media_tipo,duracion_segundos,estado,expira_en)
    select v_club,v_uid,trim(concat_ws(' ',p.nombre,p.apellidos)),p.avatar_path,left(coalesce(v_payload->>'texto',''),800),v_path,v_tipo,nullif(v_payload->>'duracion_segundos','')::numeric,'publicada',now()+interval '30 days' from public.perfiles p where p.id=v_uid returning * into v_post;
    insert into public.notificaciones(club_id,audiencia,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    values(v_club,'todos','comunidad-'||v_post.id,'comunidad','Nueva publicación en Comunidad',v_post.autor_nombre||' ha compartido '||case when v_tipo='video' then 'un vídeo.' else 'una imagen.' end,'community',jsonb_build_object('publicacion_comunidad_id',v_post.id),v_uid);
    v_result:=to_jsonb(v_post)||jsonb_build_object('limite_mensual',case when v_is_staff then 5 else 3 end,'usadas_mes',v_count+1);

  elsif p_operation='comunidad.eliminar' then
    v_id:=(v_payload->>'publicacion_id')::uuid;
    select * into v_post from public.publicaciones_comunidad where club_id=v_club and id=v_id;
    if v_post.id is null then raise exception 'Publicación no encontrada'; end if;
    if v_post.autor_perfil_id<>v_uid and not public.tiene_rol_club(v_club,'direccion','secretaria','comunicacion') then raise exception 'No puedes eliminar esta publicación'; end if;
    delete from public.publicaciones_comunidad where id=v_id;
    v_result:=jsonb_build_object('id',v_id,'media_path',v_post.media_path);

  elsif p_operation='comunidad.moderar' then
    if not public.tiene_rol_club(v_club,'direccion','secretaria','comunicacion') then raise exception 'No tienes permiso para moderar'; end if;
    v_id:=(v_payload->>'publicacion_id')::uuid;
    update public.publicaciones_comunidad set estado=case when coalesce((v_payload->>'oculta')::boolean,true) then 'oculta' else 'publicada' end,moderada_por=v_uid,moderacion_motivo=left(coalesce(v_payload->>'motivo',''),500) where club_id=v_club and id=v_id returning * into v_post;
    v_result:=to_jsonb(v_post);
  end if;

  v_result:=jsonb_build_object('ok',true,'backend_version','1.6.0','operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));
  update public.app_mutation_requests set result=v_result,completed_at=now(),club_id=v_club where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end $$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

-- Diagnóstico instalable desde SQL Editor: NO depende de auth.uid().
create or replace function public.app_diagnostico_instalacion_v166()
returns table(control text,estado text,detalle text) language sql stable security definer set search_path=public,auth as $$
  select 'gateway RC10',case when to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null then 'OK' else 'FALLO' end,'puerta única activa' union all
  select 'RC9 encapsulado',case when to_regprocedure('public.app_mutate_v160_v165(text,jsonb,uuid)') is not null then 'OK' else 'FALLO' end,'operaciones RC9 preservadas' union all
  select 'comunidad',case when to_regclass('public.publicaciones_comunidad') is not null then 'OK' else 'FALLO' end,'feed social temporal' union all
  select 'retención comunidad',case when exists(select 1 from information_schema.columns where table_schema='public' and table_name='publicaciones_comunidad' and column_name='expira_en') then 'OK' else 'FALLO' end,'caducidad 30 días' union all
  select 'series sesiones',case when to_regclass('public.series_sesiones') is not null then 'OK' else 'FALLO' end,'sesiones semanales recurrentes' union all
  select 'generador recurrente',case when to_regprocedure('public.app_generar_sesiones_recurrentes(uuid,integer)') is not null then 'OK' else 'FALLO' end,'horizonte móvil' union all
  select 'notificaciones masivas',case when pg_get_functiondef('public.app_mutate_v160(text,jsonb,uuid)'::regprocedure) like '%notificacion.leer_todas%' then 'OK' else 'FALLO' end,'leer grupos/todas' union all
  select 'estado de cuenta',case when to_regclass('public.v_estado_cuenta_socio') is not null then 'OK' else 'FALLO' end,'cuotas + pagos + recibos' union all
  select 'perfil avatar',case when exists(select 1 from information_schema.columns where table_schema='public' and table_name='perfiles' and column_name='avatar_path') then 'OK' else 'FALLO' end,'foto de perfil privada' union all
  select 'legal versionado',case when to_regclass('public.aceptaciones_legales') is not null then 'OK' else 'FALLO' end,'condiciones y consentimientos' union all
  select 'preferencias push',case when to_regclass('public.preferencias_notificacion') is not null then 'OK' else 'FALLO' end,'control por categorías' union all
  select 'buckets privados',case when exists(select 1 from storage.buckets where id='community-media' and not public) and exists(select 1 from storage.buckets where id='profile-media' and not public) then 'OK' else 'FALLO' end,'community-media + profile-media';
$$;
revoke all on function public.app_diagnostico_instalacion_v166() from public,anon,authenticated;

-- Diagnóstico autenticado para la app, restringido al Gestor.
create or replace function public.app_diagnostico_final_v166()
returns table(control text,estado text,detalle text) language plpgsql security definer set search_path=public,auth as $$
declare v_club uuid;
begin
  select club_id into v_club from public.miembros_club where perfil_id=auth.uid() and activo and rol='direccion' order by creado_en limit 1;
  if v_club is null then raise exception 'Solo el Gestor de la app puede ejecutar el diagnóstico técnico'; end if;
  return query select * from public.app_diagnostico_instalacion_v166();
end $$;
revoke all on function public.app_diagnostico_final_v166() from public,anon;
grant execute on function public.app_diagnostico_final_v166() to authenticated;

notify pgrst,'reload schema';
commit;

select * from public.app_diagnostico_instalacion_v166();
