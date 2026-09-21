-- KOMBAX RC13 build 20040 · afiliación verificada + Contacto KOMBAX breve.
-- Objetivos:
-- 1) Exponer la pertenencia real miembro↔club como afiliación verificada y controlable.
-- 2) Evolucionar las solicitudes de contacto a un hilo profesional de solo texto,
--    máximo 20 mensajes totales, sin multimedia, grupos, presencia ni estado "escribiendo".

begin;

-- Normas 1.2: conservan el histórico 1.1 y describen exactamente el nuevo Contacto KOMBAX.
update public.textos_legales set vigente=false where tipo='comunidad_general' and version<>'1.2.0' and vigente;
insert into public.textos_legales(club_id,tipo,version,cuerpo,vigente)
select c.id,'comunidad_general','1.2.0',
E'NORMAS DE KOMBAX SOCIAL · 1.2\n\nKOMBAX Social es una capa pública general y opcional, separada de la Comunidad del Club y de la gestión administrativa. Activarla no publica email, teléfono, fecha de nacimiento, domicilio, documentos, finanzas ni relaciones familiares.\n\nIdentidad y afiliación. Un perfil Miembro puede mostrar su afiliación a un club cuando KOMBAX la verifica contra una membresía real y activa. La afiliación puede ocultarse públicamente sin alterar la pertenencia administrativa al club. El perfil del Miembro y el perfil del Club siguen siendo identidades independientes.\n\nContenido. Se permiten actualizaciones deportivas, resultados, eventos, oportunidades y publicaciones de afiliación verificadas. Se prohíben acoso, amenazas, odio o discriminación, explotación o sexualización de menores, violencia ilícita, datos privados de terceros, suplantación, spam y contenido ilegal.\n\nContacto KOMBAX. Una solicitud aceptada habilita un intercambio profesional breve de solo texto entre dos identidades. Cada contacto admite como máximo 20 mensajes totales, incluido el mensaje inicial. No admite imágenes, vídeos, audios, archivos, grupos, presencia, estado en línea ni indicador de escritura. Al alcanzar el límite o cerrar el contacto, el hilo queda en modo lectura.\n\nMenores. KOMBAX Social puede estar disponible desde la edad mínima social verificada por el club, pero Contacto KOMBAX queda bloqueado cuando cualquiera de los perfiles personales corresponde a una persona menor de 18 años.\n\nSeguridad. Los participantes pueden bloquear y denunciar. Un bloqueo impide iniciar o continuar Contacto KOMBAX. Los mensajes privados no son de lectura global para moderadores; cualquier revisión excepcional deberá vincularse a un flujo de denuncia específico.\n\nModeración. KOMBAX puede ocultar contenido público, revisar denuncias y suspender el acceso social sin alterar la membresía administrativa del club.',true
from public.clubes c
on conflict(club_id,tipo,version) do update set cuerpo=excluded.cuerpo,vigente=true;

-- Estado Social 065: conserva el contrato 051 y expone la versión legal vigente real.
create or replace function public.app_kombax_social_estado_v065(p_club_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v jsonb;v_rules text;
begin
  v:=public.app_kombax_social_estado_v051(p_club_id);
  select version into v_rules from public.textos_legales
  where tipo='comunidad_general' and vigente and (p_club_id is null or club_id=p_club_id)
  order by creado_en desc limit 1;
  return v||jsonb_build_object('rules_version',coalesce(v_rules,'1.2.0'));
end $$;
revoke all on function public.app_kombax_social_estado_v065(uuid) from public,anon;
grant execute on function public.app_kombax_social_estado_v065(uuid) to authenticated;

-- Wrapper de identidad: nuevas activaciones de Miembro registran la versión legal efectivamente aceptada.
create or replace function public.app_kombax_identity_mutate_v065(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v jsonb;v_version text;
begin
  v:=public.app_kombax_identity_mutate_v051(p_operation,p_payload,p_request_id);
  if p_operation='kombax.identity.member.activate' then
    select t.version into v_version from public.textos_legales t
    where t.tipo='comunidad_general' and t.vigente and t.club_id=nullif(p_payload->>'club_id','')::uuid
    order by t.creado_en desc limit 1;
    if v_version is not null then
      update public.identidades_sociales set version_normas=v_version,actualizado_en=now() where perfil_id=auth.uid();
    end if;
  end if;
  return v;
end $$;
revoke all on function public.app_kombax_identity_mutate_v065(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_identity_mutate_v065(text,jsonb,uuid) to authenticated;

-- Wrapper Social: las nuevas activaciones de Marca/Federación conservan el gateway 053 y aceptan Normas 1.2.
create or replace function public.app_kombax_social_mutate_v065(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v jsonb;v_direct uuid;v_version text;
begin
  v:=public.app_kombax_social_mutate_v053(p_operation,p_payload,p_request_id);
  if p_operation='kombax.social.direct.activate' then
    begin v_direct:=(p_payload->>'perfil_directo_id')::uuid;exception when others then v_direct:=null;end;
    if v_direct is not null and exists(select 1 from public.perfiles_kombax_directos d where d.id=v_direct and d.perfil_id=auth.uid()) then
      select version into v_version from public.textos_legales where tipo='comunidad_general' and vigente order by creado_en desc limit 1;
      v_version:=coalesce(v_version,'1.2.0');
      update public.perfiles_kombax_directos set social_normas_version=v_version,actualizado_en=now() where id=v_direct;
      insert into public.kombax_aceptaciones_globales(perfil_id,perfil_directo_id,tipo,version,aceptado,user_agent)
      values
        (auth.uid(),v_direct,'social_normas',v_version,true,left(coalesce(p_payload->>'user_agent',''),500)),
        (auth.uid(),v_direct,'social_privacidad',v_version,true,left(coalesce(p_payload->>'user_agent',''),500))
      on conflict(perfil_directo_id,tipo,version) do update set aceptado=true,aceptado_en=now(),revocado_en=null,user_agent=excluded.user_agent;
    end if;
  end if;
  return v;
end $$;
revoke all on function public.app_kombax_social_mutate_v065(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_mutate_v065(text,jsonb,uuid) to authenticated;

-- La afiliación ya era visible en distintas vistas a través de club_origen_id.
-- Se añade un control explícito sin duplicar la relación canónica socio/club.
alter table public.identidades_sociales
  add column if not exists afiliacion_visible boolean not null default true;

-- Metadatos de cierre del contacto y límite contractual por hilo.
alter table public.kombax_social_contactos
  add column if not exists mensajes_limite smallint not null default 20,
  add column if not exists cerrado_por uuid references public.perfiles(id) on delete set null,
  add column if not exists cerrado_en timestamptz;

alter table public.kombax_social_contactos
  drop constraint if exists kombax_social_contactos_mensajes_limite_check;
alter table public.kombax_social_contactos
  add constraint kombax_social_contactos_mensajes_limite_check
  check (mensajes_limite between 2 and 20);

-- Un único hilo abierto por pareja de identidades, independientemente de quién inició.
create unique index if not exists uq_kombax_contact_pair_open_v065
on public.kombax_social_contactos(
  least(remitente_social_id,destinatario_social_id),
  greatest(remitente_social_id,destinatario_social_id)
)
where estado in ('pendiente','aceptada');

-- Mensajería deliberadamente de SOLO TEXTO. No existen columnas de archivos, medios o URL.
create table if not exists public.kombax_social_contacto_mensajes(
  id uuid primary key default gen_random_uuid(),
  contacto_id uuid not null references public.kombax_social_contactos(id) on delete cascade,
  autor_social_id uuid not null references public.kombax_social_perfiles(id) on delete restrict,
  creado_por uuid not null references public.perfiles(id) on delete restrict,
  ordinal smallint not null check(ordinal between 1 and 20),
  texto text not null check(char_length(btrim(texto)) between 1 and 500),
  creado_en timestamptz not null default now(),
  leido_en timestamptz,
  unique(contacto_id,ordinal)
);
create index if not exists idx_kombax_contact_messages_thread_v065
  on public.kombax_social_contacto_mensajes(contacto_id,creado_en,id);
create index if not exists idx_kombax_contact_messages_unread_v065
  on public.kombax_social_contacto_mensajes(contacto_id,leido_en)
  where leido_en is null;
alter table public.kombax_social_contacto_mensajes enable row level security;
revoke all on public.kombax_social_contacto_mensajes from public,anon,authenticated;

-- Historial existente: la solicitud original pasa a ser el mensaje 1 del hilo.
insert into public.kombax_social_contacto_mensajes(contacto_id,autor_social_id,creado_por,ordinal,texto,creado_en)
select c.id,c.remitente_social_id,c.creado_por,1,c.mensaje,c.creado_en
from public.kombax_social_contactos c
where not exists(select 1 from public.kombax_social_contacto_mensajes m where m.contacto_id=c.id and m.ordinal=1)
on conflict(contacto_id,ordinal) do nothing;

-- Compatibilidad: cualquier solicitud creada por rutas antiguas también genera mensaje 1.
create or replace function public.app_kombax_contact_seed_message_v065()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.kombax_social_contacto_mensajes(contacto_id,autor_social_id,creado_por,ordinal,texto,creado_en)
  values(new.id,new.remitente_social_id,new.creado_por,1,new.mensaje,new.creado_en)
  on conflict(contacto_id,ordinal) do nothing;
  return new;
end $$;
revoke all on function public.app_kombax_contact_seed_message_v065() from public,anon,authenticated;
drop trigger if exists trg_kombax_contact_seed_message_v065 on public.kombax_social_contactos;
create trigger trg_kombax_contact_seed_message_v065
after insert on public.kombax_social_contactos
for each row execute function public.app_kombax_contact_seed_message_v065();

-- Afiliación efectiva. Nunca confía en texto libre: exige identidad activa + socio activo + club real.
create or replace function public.app_kombax_social_afiliacion_v065(p_social_id uuid)
returns jsonb language sql stable security definer set search_path=public as $$
  select case when i.afiliacion_visible and i.estado='activa' and s.estado='activo' then
    jsonb_build_object(
      'club_id',c.id,
      'club_nombre',c.nombre,
      'club_social_id',csp.id,
      'club_social_slug',csp.slug,
      'verificada',true,
      'fuente','membresia_club'
    ) else null end
  from public.kombax_social_perfiles sp
  join public.identidades_sociales i on i.id=sp.identidad_social_id
  join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id
  join public.clubes c on c.id=i.club_origen_id
  left join lateral(
    select x.id,x.slug from public.kombax_social_perfiles x
    where x.sujeto_tipo='club' and x.club_id=c.id and x.estado='activo' and x.visible
    order by x.creado_en asc limit 1
  ) csp on true
  where sp.id=p_social_id and sp.sujeto_tipo='miembro' and sp.estado='activo' and sp.visible;
$$;
revoke all on function public.app_kombax_social_afiliacion_v065(uuid) from public,anon,authenticated;

-- Directorio enriquecido con afiliación canónica y perfil Social del club.
create or replace function public.app_kombax_social_directorio_v065(p_query text default '',p_limit integer default 30)
returns table(
  id uuid,sujeto_tipo text,perfil_tipo text,slug text,nombre_publico text,bio text,
  avatar_url text,avatar_path text,banner_url text,banner_path text,verificado boolean,
  contactable boolean,club_id uuid,club_nombre text,club_social_id uuid,afiliacion_verificada boolean
)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_q text:=lower(btrim(coalesce(p_query,'')));
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  return query
  select sp.id,sp.sujeto_tipo,public.app_kombax_social_tipo_v051(sp.id),sp.slug,sp.nombre_publico,sp.bio,
    public.app_kombax_social_avatar_url_v063(sp.id),public.app_kombax_social_avatar_path_v058(sp.id),
    public.app_kombax_social_banner_url_v063(sp.id),public.app_kombax_social_banner_path_v058(sp.id),sp.verificado,
    public.app_kombax_social_contactable_v041(sp.id),
    case when aff.j is not null then (aff.j->>'club_id')::uuid else coalesce(sp.club_id,i.club_origen_id) end,
    case when aff.j is not null then aff.j->>'club_nombre' else c.nombre end,
    nullif(aff.j->>'club_social_id','')::uuid,
    coalesce((aff.j->>'verificada')::boolean,false)
  from public.kombax_social_perfiles sp
  left join public.identidades_sociales i on i.id=sp.identidad_social_id
  left join public.clubes c on c.id=coalesce(sp.club_id,i.club_origen_id)
  left join public.perfiles_kombax_directos d on d.id=sp.perfil_directo_id
  left join lateral(select public.app_kombax_social_afiliacion_v065(sp.id) j) aff on true
  where sp.visible and sp.estado='activo'
    and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
    and (v_q='' or lower(sp.nombre_publico) like '%'||v_q||'%' or lower(sp.slug) like '%'||v_q||'%' or lower(coalesce(sp.bio,'')) like '%'||v_q||'%' or lower(coalesce(c.nombre,'')) like '%'||v_q||'%' or lower(coalesce(d.tipo,'')) like '%'||v_q||'%')
  order by sp.verificado desc,sp.nombre_publico
  limit least(greatest(coalesce(p_limit,30),1),50);
end $$;
revoke all on function public.app_kombax_social_directorio_v065(text,integer) from public,anon;
grant execute on function public.app_kombax_social_directorio_v065(text,integer) to authenticated;

-- Feed enriquecido: toda publicación de un miembro puede mostrar su club verificado sin convertirla en publicación del club.
create or replace function public.app_kombax_social_feed_v065(p_cursor timestamptz default null,p_cursor_id uuid default null,p_limit integer default 20)
returns table(
  id uuid,tipo text,texto text,likes_count integer,comentarios_count integer,creado_en timestamptz,
  autor_id uuid,autor_nombre text,autor_tipo text,autor_slug text,autor_avatar_url text,autor_avatar_path text,
  autor_verificado boolean,autor_club_id uuid,autor_club_nombre text,autor_club_social_id uuid,autor_afiliacion_verificada boolean,
  liked_by_me boolean,saved_by_me boolean,contactable boolean,comentarios_estado text,
  media_id uuid,media_tipo text,media_path text,media_mime text,media_duration numeric
)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  return query
  select p.id,p.tipo,p.texto,p.likes_count,p.comentarios_count,p.creado_en,
    sp.id,sp.nombre_publico,public.app_kombax_social_tipo_v051(sp.id),sp.slug,
    public.app_kombax_social_avatar_url_v063(sp.id),public.app_kombax_social_avatar_path_v058(sp.id),sp.verificado,
    nullif(aff.j->>'club_id','')::uuid,aff.j->>'club_nombre',nullif(aff.j->>'club_social_id','')::uuid,coalesce((aff.j->>'verificada')::boolean,false),
    exists(select 1 from public.kombax_social_likes l where l.publicacion_id=p.id and l.perfil_id=auth.uid()),
    exists(select 1 from public.kombax_social_guardados g where g.publicacion_id=p.id and g.perfil_id=auth.uid()),
    public.app_kombax_social_contactable_v041(sp.id),p.comentarios_estado,
    coalesce(sm.id,pm.id),coalesce(sm.tipo,pm.tipo),coalesce(sm.storage_path,pm.storage_path),coalesce(sm.mime_type,pm.mime_type),coalesce(sm.duration_seconds,pm.duration_seconds)
  from public.kombax_social_publicaciones p
  join public.kombax_social_perfiles sp on sp.id=p.autor_perfil_id
  left join public.kombax_social_media sm on sm.id=p.social_media_id and sm.estado='active'
  left join public.kombax_perfil_media pm on pm.id=p.media_id and pm.estado='active'
  left join lateral(select public.app_kombax_social_afiliacion_v065(sp.id) j) aff on true
  where p.estado='activa' and sp.visible and sp.estado='activo'
    and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
    and (p_cursor is null or p.creado_en<p_cursor or (p.creado_en=p_cursor and p.id<p_cursor_id))
  order by p.creado_en desc,p.id desc
  limit least(greatest(coalesce(p_limit,20),1),20);
end $$;
revoke all on function public.app_kombax_social_feed_v065(timestamptz,uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_feed_v065(timestamptz,uuid,integer) to authenticated;

-- Perfil público enriquecido manteniendo íntegro el contrato 053 anterior.
create or replace function public.app_kombax_perfil_publico_v065(p_social_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v jsonb;v_aff jsonb;v_visible boolean;
begin
  v:=public.app_kombax_perfil_publico_v053(p_social_id);
  if v is null then return null;end if;
  v_aff:=public.app_kombax_social_afiliacion_v065(p_social_id);
  select i.afiliacion_visible into v_visible
  from public.kombax_social_perfiles sp join public.identidades_sociales i on i.id=sp.identidad_social_id
  where sp.id=p_social_id and sp.sujeto_tipo='miembro';
  v:=jsonb_set(v,'{affiliation_visible}',to_jsonb(coalesce(v_visible,false)),true);
  if v_aff is not null then v:=jsonb_set(v,'{affiliation}',v_aff,true);end if;
  return v;
end $$;
revoke all on function public.app_kombax_perfil_publico_v065(uuid) from public,anon;
grant execute on function public.app_kombax_perfil_publico_v065(uuid) to authenticated;

-- Helper interno de autorización de hilos.
create or replace function public.app_kombax_contact_can_access_v065(p_contacto_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.kombax_social_contactos c
    where c.id=p_contacto_id and (
      public.app_kombax_social_puede_actuar_v051(c.remitente_social_id)
      or public.app_kombax_social_puede_actuar_v051(c.destinatario_social_id)
    )
  );
$$;
revoke all on function public.app_kombax_contact_can_access_v065(uuid) from public,anon,authenticated;

-- Bloqueo bilateral para identidades personales. Un bloqueo del destinatario también corta el contacto.
-- Los perfiles Club no heredan bloqueos personales de un gestor concreto.
create or replace function public.app_kombax_contact_pair_blocked_v065(p_actor_social_id uuid,p_target_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select
    exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=p_target_social_id)
    or exists(
      select 1
      from public.kombax_social_perfiles tsp
      left join public.identidades_sociales ti on ti.id=tsp.identidad_social_id
      left join public.perfiles_kombax_directos td on td.id=tsp.perfil_directo_id
      join public.kombax_social_bloqueos b on b.bloqueador_perfil_id=coalesce(ti.perfil_id,td.perfil_id) and b.bloqueado_social_id=p_actor_social_id
      where tsp.id=p_target_social_id and tsp.sujeto_tipo in ('miembro','perfil_directo')
    );
$$;
revoke all on function public.app_kombax_contact_pair_blocked_v065(uuid,uuid) from public,anon,authenticated;

-- Bandeja de Contacto KOMBAX. El contador incluye el mensaje inicial de solicitud.
create or replace function public.app_kombax_contactos_v065()
returns table(
  id uuid,remitente_id uuid,remitente_nombre text,destinatario_id uuid,destinatario_nombre text,
  motivo text,estado text,creado_en timestamptz,respondido_en timestamptz,cerrado_en timestamptz,
  direccion text,gestionable boolean,mensajes_count integer,mensajes_limite integer,mensajes_restantes integer,
  ultimo_mensaje text,ultimo_mensaje_en timestamptz,no_leidos integer,puede_chat boolean,puede_cerrar boolean
)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED';end if;
  return query
  select c.id,rs.id,rs.nombre_publico,ds.id,ds.nombre_publico,c.motivo,c.estado,c.creado_en,c.respondido_en,c.cerrado_en,
    case
      when public.app_kombax_social_puede_actuar_v051(c.destinatario_social_id) and not public.app_kombax_social_puede_actuar_v051(c.remitente_social_id) then 'recibida'
      when public.app_kombax_social_puede_actuar_v051(c.remitente_social_id) then 'enviada'
      else 'moderacion'
    end,
    c.estado='pendiente' and public.app_kombax_social_puede_actuar_v051(c.destinatario_social_id),
    coalesce(stats.cnt,0)::integer,c.mensajes_limite::integer,greatest(c.mensajes_limite-coalesce(stats.cnt,0),0)::integer,
    stats.last_text,stats.last_at,
    coalesce((select count(*)::integer from public.kombax_social_contacto_mensajes um where um.contacto_id=c.id and um.leido_en is null and not public.app_kombax_social_puede_actuar_v051(um.autor_social_id)),0),
    c.estado='aceptada' and coalesce(stats.cnt,0)<c.mensajes_limite
      and public.app_kombax_social_contactable_v041(c.remitente_social_id)
      and public.app_kombax_social_contactable_v041(c.destinatario_social_id)
      and not case when public.app_kombax_social_puede_actuar_v051(c.remitente_social_id)
        then public.app_kombax_contact_pair_blocked_v065(c.remitente_social_id,c.destinatario_social_id)
        else public.app_kombax_contact_pair_blocked_v065(c.destinatario_social_id,c.remitente_social_id) end,
    c.estado='aceptada'
  from public.kombax_social_contactos c
  join public.kombax_social_perfiles rs on rs.id=c.remitente_social_id
  join public.kombax_social_perfiles ds on ds.id=c.destinatario_social_id
  left join lateral(
    select count(*)::integer cnt,
      (array_agg(m.texto order by m.ordinal desc))[1] last_text,
      max(m.creado_en) last_at
    from public.kombax_social_contacto_mensajes m where m.contacto_id=c.id
  ) stats on true
  where public.app_kombax_contact_can_access_v065(c.id)
  order by coalesce(stats.last_at,c.creado_en) desc
  limit 200;
end $$;
revoke all on function public.app_kombax_contactos_v065() from public,anon;
grant execute on function public.app_kombax_contactos_v065() to authenticated;

create or replace function public.app_kombax_contact_mensajes_v065(p_contacto_id uuid)
returns table(id uuid,contacto_id uuid,autor_social_id uuid,autor_nombre text,ordinal integer,texto text,creado_en timestamptz,leido_en timestamptz,propio boolean)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if auth.uid() is null or not public.app_kombax_contact_can_access_v065(p_contacto_id) then raise exception 'KOMBAX_CONTACT_ACCESS_FORBIDDEN';end if;
  return query
  select m.id,m.contacto_id,m.autor_social_id,sp.nombre_publico,m.ordinal::integer,m.texto,m.creado_en,m.leido_en,
    public.app_kombax_social_puede_actuar_v051(m.autor_social_id)
  from public.kombax_social_contacto_mensajes m
  join public.kombax_social_perfiles sp on sp.id=m.autor_social_id
  where m.contacto_id=p_contacto_id
  order by m.ordinal,m.creado_en,m.id;
end $$;
revoke all on function public.app_kombax_contact_mensajes_v065(uuid) from public,anon;
grant execute on function public.app_kombax_contact_mensajes_v065(uuid) to authenticated;

-- Marcar leído es idempotente y solo afecta mensajes de la contraparte.
create or replace function public.app_kombax_contact_mark_read_v065(p_contacto_id uuid)
returns integer language plpgsql security definer set search_path=public,auth as $$
declare v_count integer;
begin
  if auth.uid() is null or not public.app_kombax_contact_can_access_v065(p_contacto_id) then raise exception 'KOMBAX_CONTACT_ACCESS_FORBIDDEN';end if;
  update public.kombax_social_contacto_mensajes m
    set leido_en=coalesce(m.leido_en,now())
  where m.contacto_id=p_contacto_id and m.leido_en is null
    and not public.app_kombax_social_puede_actuar_v051(m.autor_social_id);
  get diagnostics v_count=row_count;
  return v_count;
end $$;
revoke all on function public.app_kombax_contact_mark_read_v065(uuid) from public,anon;
grant execute on function public.app_kombax_contact_mark_read_v065(uuid) to authenticated;

-- Mutaciones nuevas con idempotencia, límites y auditoría.
create or replace function public.app_kombax_social_network_mutate_v065(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;
  v_actor uuid;v_target uuid;v_contact_id uuid;v_contact public.kombax_social_contactos;v_message public.kombax_social_contacto_mensajes;
  v_reason text;v_text text;v_count integer;v_limit integer;v_aff jsonb;v_identity_id uuid;v_post public.kombax_social_publicaciones;v_visible boolean;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  if p_operation not in ('kombax.social.affiliation.visibility','kombax.social.affiliation.share','kombax.contact.request','kombax.contact.message.send','kombax.contact.close') then
    raise exception 'KOMBAX_SOCIAL_NETWORK_OPERATION_NOT_ALLOWED';
  end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;
    if v_existing.result is not null then return v_existing.result;end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,null,p_operation);
  end if;

  if p_operation='kombax.social.affiliation.visibility' then
    begin v_actor:=(v_payload->>'social_profile_id')::uuid;exception when others then raise exception 'KOMBAX_AFFILIATION_PROFILE_INVALID';end;
    if not public.app_kombax_social_puede_actuar_v051(v_actor) then raise exception 'KOMBAX_AFFILIATION_FORBIDDEN';end if;
    select sp.identidad_social_id into v_identity_id from public.kombax_social_perfiles sp where sp.id=v_actor and sp.sujeto_tipo='miembro';
    if v_identity_id is null then raise exception 'KOMBAX_AFFILIATION_MEMBER_REQUIRED';end if;
    v_visible:=coalesce((v_payload->>'visible')::boolean,true);
    update public.identidades_sociales set afiliacion_visible=v_visible,actualizado_en=now() where id=v_identity_id and perfil_id=v_uid;
    if not found then raise exception 'KOMBAX_AFFILIATION_NOT_OWNED';end if;
    v_result:=jsonb_build_object('social_profile_id',v_actor,'visible',v_visible);

  elsif p_operation='kombax.social.affiliation.share' then
    begin v_actor:=(v_payload->>'social_profile_id')::uuid;exception when others then raise exception 'KOMBAX_AFFILIATION_PROFILE_INVALID';end;
    if not public.app_kombax_social_puede_actuar_v051(v_actor) then raise exception 'KOMBAX_AFFILIATION_FORBIDDEN';end if;
    v_aff:=public.app_kombax_social_afiliacion_v065(v_actor);
    if v_aff is null then raise exception 'KOMBAX_AFFILIATION_NOT_VISIBLE_OR_ACTIVE';end if;
    select count(*) into v_count from public.kombax_social_publicaciones where autor_perfil_id=v_actor and estado='activa';
    if v_count>=30 then raise exception 'KOMBAX_POST_ACTIVE_LIMIT_30';end if;
    select count(*) into v_count from public.kombax_social_publicaciones where autor_perfil_id=v_actor and creado_en>=date_trunc('day',now()) and estado<>'retirada';
    if v_count>=3 then raise exception 'KOMBAX_POST_DAILY_LIMIT_3';end if;
    v_text:='Miembro de '||(v_aff->>'club_nombre')||' · afiliación verificada en KOMBAX.';
    insert into public.kombax_social_publicaciones(autor_perfil_id,tipo,texto,comentarios_estado)
      values(v_actor,'actualizacion',v_text,'open') returning * into v_post;
    insert into public.kombax_actor_audit(actor_perfil_id,public_social_id,club_id,accion,objeto_tipo,objeto_id,detalle)
      values(v_uid,v_actor,(v_aff->>'club_id')::uuid,'social.affiliation.share','social_post',v_post.id,jsonb_build_object('club_social_id',v_aff->>'club_social_id'));
    v_result:=to_jsonb(v_post)||jsonb_build_object('affiliation',v_aff);

  elsif p_operation='kombax.contact.request' then
    begin v_actor:=(v_payload->>'remitente_social_id')::uuid;v_target:=(v_payload->>'destinatario_social_id')::uuid;exception when others then raise exception 'KOMBAX_CONTACT_PROFILES_INVALID';end;
    if v_actor=v_target then raise exception 'KOMBAX_CONTACT_SELF_FORBIDDEN';end if;
    if not public.app_kombax_social_puede_actuar_v051(v_actor) then raise exception 'KOMBAX_CONTACT_SOURCE_NOT_OWNED';end if;
    if not public.app_kombax_social_contactable_v041(v_actor) or not public.app_kombax_social_contactable_v041(v_target) then raise exception 'KOMBAX_CONTACT_NOT_AVAILABLE_18_PLUS';end if;
    if public.app_kombax_contact_pair_blocked_v065(v_actor,v_target) then raise exception 'KOMBAX_CONTACT_BLOCKED';end if;
    if exists(select 1 from public.kombax_social_contactos c where least(c.remitente_social_id,c.destinatario_social_id)=least(v_actor,v_target) and greatest(c.remitente_social_id,c.destinatario_social_id)=greatest(v_actor,v_target) and c.estado in ('pendiente','aceptada')) then raise exception 'KOMBAX_CONTACT_THREAD_ALREADY_OPEN';end if;
    v_reason:=lower(coalesce(v_payload->>'motivo','otro'));
    if v_reason not in ('entrenamiento','competicion','evento','colaboracion','patrocinio','informacion','otro') then raise exception 'KOMBAX_CONTACT_REASON_INVALID';end if;
    v_text:=btrim(coalesce(v_payload->>'mensaje',''));
    if char_length(v_text)<10 or char_length(v_text)>500 then raise exception 'KOMBAX_CONTACT_REQUEST_TEXT_INVALID';end if;
    insert into public.kombax_social_contactos(remitente_social_id,destinatario_social_id,creado_por,motivo,mensaje,mensajes_limite)
      values(v_actor,v_target,v_uid,v_reason,v_text,20) returning * into v_contact;
    v_result:=jsonb_build_object('id',v_contact.id,'estado',v_contact.estado,'mensajes_count',1,'mensajes_limite',v_contact.mensajes_limite);

  elsif p_operation='kombax.contact.message.send' then
    begin v_contact_id:=(v_payload->>'contacto_id')::uuid;v_actor:=(v_payload->>'autor_social_id')::uuid;exception when others then raise exception 'KOMBAX_CONTACT_MESSAGE_CONTEXT_INVALID';end;
    select * into v_contact from public.kombax_social_contactos where id=v_contact_id for update;
    if v_contact.id is null then raise exception 'KOMBAX_CONTACT_NOT_FOUND';end if;
    if v_actor not in (v_contact.remitente_social_id,v_contact.destinatario_social_id) or not public.app_kombax_social_puede_actuar_v051(v_actor) then raise exception 'KOMBAX_CONTACT_MESSAGE_SENDER_FORBIDDEN';end if;
    if v_contact.estado<>'aceptada' then raise exception 'KOMBAX_CONTACT_NOT_OPEN';end if;
    v_target:=case when v_actor=v_contact.remitente_social_id then v_contact.destinatario_social_id else v_contact.remitente_social_id end;
    if not public.app_kombax_social_contactable_v041(v_actor) or not public.app_kombax_social_contactable_v041(v_target) then raise exception 'KOMBAX_CONTACT_NOT_AVAILABLE_18_PLUS';end if;
    if public.app_kombax_contact_pair_blocked_v065(v_actor,v_target) then raise exception 'KOMBAX_CONTACT_BLOCKED';end if;
    v_text:=btrim(coalesce(v_payload->>'texto',''));
    if char_length(v_text)<1 or char_length(v_text)>500 then raise exception 'KOMBAX_CONTACT_MESSAGE_TEXT_INVALID';end if;
    select count(*)::integer into v_count from public.kombax_social_contacto_mensajes where contacto_id=v_contact.id;
    v_limit:=least(greatest(coalesce(v_contact.mensajes_limite,20),2),20);
    if v_count>=v_limit then raise exception 'KOMBAX_CONTACT_MESSAGE_LIMIT_20';end if;
    insert into public.kombax_social_contacto_mensajes(contacto_id,autor_social_id,creado_por,ordinal,texto)
      values(v_contact.id,v_actor,v_uid,v_count+1,v_text) returning * into v_message;
    if v_message.ordinal>=v_limit then
      update public.kombax_social_contactos set estado='cerrada',cerrado_por=v_uid,cerrado_en=now() where id=v_contact.id;
    end if;
    insert into public.kombax_actor_audit(actor_perfil_id,public_social_id,club_id,accion,objeto_tipo,objeto_id,detalle)
      select v_uid,v_actor,coalesce(sp.club_id,i.club_origen_id),'social.contact.message','contact_message',v_message.id,jsonb_build_object('contact_id',v_contact.id,'ordinal',v_message.ordinal,'limit',v_limit)
      from public.kombax_social_perfiles sp left join public.identidades_sociales i on i.id=sp.identidad_social_id where sp.id=v_actor;
    v_result:=to_jsonb(v_message)||jsonb_build_object('mensajes_limite',v_limit,'cerrado',v_message.ordinal>=v_limit);

  elsif p_operation='kombax.contact.close' then
    begin v_contact_id:=(v_payload->>'contacto_id')::uuid;exception when others then raise exception 'KOMBAX_CONTACT_ID_INVALID';end;
    select * into v_contact from public.kombax_social_contactos where id=v_contact_id for update;
    if v_contact.id is null or not public.app_kombax_contact_can_access_v065(v_contact.id) then raise exception 'KOMBAX_CONTACT_ACCESS_FORBIDDEN';end if;
    if v_contact.estado='aceptada' then
      update public.kombax_social_contactos set estado='cerrada',cerrado_por=v_uid,cerrado_en=now() where id=v_contact.id returning * into v_contact;
    elsif v_contact.estado not in ('cerrada','rechazada') then raise exception 'KOMBAX_CONTACT_CLOSE_STATE_INVALID';end if;
    v_result:=jsonb_build_object('id',v_contact.id,'estado',v_contact.estado,'cerrado_en',v_contact.cerrado_en);
  end if;

  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end $$;
revoke all on function public.app_kombax_social_network_mutate_v065(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_network_mutate_v065(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
