-- KOMBAX RC13 build 20024 · KOMBAX Social Alpha.
-- Capa global separada de Comunidad del Club. Sin seguidores, amistades, chat,
-- presencia, mensajes encadenados ni exposición de datos administrativos.

begin;

update public.textos_legales set vigente=false where tipo='comunidad_general' and version<>'1.1.0' and vigente;
insert into public.textos_legales(club_id,tipo,version,cuerpo,vigente)
select c.id,'comunidad_general','1.1.0',
E'NORMAS DE KOMBAX SOCIAL · ALPHA 1.1\n\nKOMBAX Social es una capa pública general y opcional, separada de la Comunidad del Club y de la gestión administrativa. Activarla no publica email, teléfono, fecha de nacimiento, domicilio, documentos, finanzas ni relaciones familiares.\n\nContenido. Se permiten actualizaciones deportivas, resultados, eventos y oportunidades legítimas. Se prohíben acoso, amenazas, odio o discriminación, explotación o sexualización de menores, violencia ilícita, datos privados de terceros, suplantación, spam y contenido ilegal.\n\nInteracción. Esta fase permite likes, bloqueos, denuncias y solicitudes estructuradas de contacto. No incluye seguidores, amistades, chat, mensajería encadenada, presencia ni estado en línea.\n\nMenores. La elegibilidad de publicación se rige por la edad verificada y las reglas del club. Las solicitudes de contacto quedan siempre bloqueadas si cualquiera de los perfiles personales corresponde a un menor de 18 años.\n\nModeración. KOMBAX puede ocultar contenido, revisar denuncias y suspender el acceso social sin alterar la membresía administrativa del club.',true
from public.clubes c
on conflict(club_id,tipo,version) do update set cuerpo=excluded.cuerpo,vigente=true;

insert into public.kombax_capacidades(clave,descripcion,sensible) values
  ('social.moderate','Moderación global de KOMBAX Social',true)
on conflict(clave) do nothing;

create table if not exists public.kombax_moderadores_globales(
  perfil_id uuid primary key references public.perfiles(id) on delete cascade,
  rol text not null default 'moderador' check(rol in ('moderador','administrador')),
  activo boolean not null default true,
  asignado_por uuid references public.perfiles(id) on delete set null,
  creado_en timestamptz not null default now()
);

create table if not exists public.kombax_social_perfiles(
  id uuid primary key default gen_random_uuid(),
  sujeto_tipo text not null check(sujeto_tipo in ('club','miembro','perfil_directo')),
  club_id uuid references public.clubes(id) on delete cascade,
  identidad_social_id uuid references public.identidades_sociales(id) on delete cascade,
  perfil_directo_id uuid references public.perfiles_kombax_directos(id) on delete cascade,
  slug text not null unique check(slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  nombre_publico text not null check(char_length(nombre_publico) between 1 and 160),
  bio text check(char_length(coalesce(bio,''))<=800),
  avatar_url text,
  banner_url text,
  verificado boolean not null default false,
  visible boolean not null default true,
  publicar_habilitado boolean not null default false,
  contacto_habilitado boolean not null default false,
  estado text not null default 'activo' check(estado in ('activo','limitado','suspendido','cerrado')),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  check(num_nonnulls(club_id,identidad_social_id,perfil_directo_id)=1),
  check((sujeto_tipo='club' and club_id is not null) or (sujeto_tipo='miembro' and identidad_social_id is not null) or (sujeto_tipo='perfil_directo' and perfil_directo_id is not null))
);
create unique index if not exists uq_kombax_social_perfil_club_v041 on public.kombax_social_perfiles(club_id) where sujeto_tipo='club';
create unique index if not exists uq_kombax_social_perfil_miembro_v041 on public.kombax_social_perfiles(identidad_social_id) where sujeto_tipo='miembro';
create unique index if not exists uq_kombax_social_perfil_directo_v041 on public.kombax_social_perfiles(perfil_directo_id) where sujeto_tipo='perfil_directo';
create index if not exists idx_kombax_social_perfiles_publicos_v041 on public.kombax_social_perfiles(estado,visible,sujeto_tipo,nombre_publico);

create table if not exists public.kombax_social_publicaciones(
  id uuid primary key default gen_random_uuid(),
  autor_perfil_id uuid not null references public.kombax_social_perfiles(id) on delete restrict,
  tipo text not null default 'actualizacion' check(tipo in ('actualizacion','resultado','evento','oportunidad')),
  texto text not null check(char_length(btrim(texto)) between 1 and 1500),
  estado text not null default 'activa' check(estado in ('activa','oculta','retirada')),
  likes_count integer not null default 0 check(likes_count>=0),
  moderada_por uuid references public.perfiles(id) on delete set null,
  moderacion_motivo text check(char_length(coalesce(moderacion_motivo,''))<=1000),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);
create index if not exists idx_kombax_social_feed_v041 on public.kombax_social_publicaciones(estado,creado_en desc,id desc);
create index if not exists idx_kombax_social_posts_autor_v041 on public.kombax_social_publicaciones(autor_perfil_id,creado_en desc);

create table if not exists public.kombax_social_likes(
  publicacion_id uuid not null references public.kombax_social_publicaciones(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  creado_en timestamptz not null default now(),
  primary key(publicacion_id,perfil_id)
);

create table if not exists public.kombax_social_bloqueos(
  bloqueador_perfil_id uuid not null references public.perfiles(id) on delete cascade,
  bloqueado_social_id uuid not null references public.kombax_social_perfiles(id) on delete cascade,
  creado_en timestamptz not null default now(),
  primary key(bloqueador_perfil_id,bloqueado_social_id)
);

create table if not exists public.kombax_social_contactos(
  id uuid primary key default gen_random_uuid(),
  remitente_social_id uuid not null references public.kombax_social_perfiles(id) on delete restrict,
  destinatario_social_id uuid not null references public.kombax_social_perfiles(id) on delete restrict,
  creado_por uuid not null references public.perfiles(id) on delete cascade,
  motivo text not null check(motivo in ('entrenamiento','competicion','evento','colaboracion','patrocinio','informacion','otro')),
  mensaje text not null check(char_length(btrim(mensaje)) between 10 and 500),
  estado text not null default 'pendiente' check(estado in ('pendiente','aceptada','rechazada','cerrada')),
  respondido_por uuid references public.perfiles(id) on delete set null,
  creado_en timestamptz not null default now(),
  respondido_en timestamptz,
  check(remitente_social_id<>destinatario_social_id)
);
create unique index if not exists uq_kombax_social_contacto_pendiente_v041 on public.kombax_social_contactos(remitente_social_id,destinatario_social_id) where estado='pendiente';
create index if not exists idx_kombax_social_contacto_destino_v041 on public.kombax_social_contactos(destinatario_social_id,estado,creado_en desc);

create table if not exists public.kombax_social_reportes(
  id uuid primary key default gen_random_uuid(),
  reportado_por uuid not null references public.perfiles(id) on delete cascade,
  objetivo_tipo text not null check(objetivo_tipo in ('publicacion','perfil')),
  objetivo_id uuid not null,
  motivo text not null check(motivo in ('acoso','odio_discriminacion','violencia','sexual_menores','privacidad','spam','suplantacion','otro')),
  detalle text check(char_length(coalesce(detalle,''))<=1500),
  estado text not null default 'pendiente' check(estado in ('pendiente','en_revision','resuelta','descartada')),
  revisado_por uuid references public.perfiles(id) on delete set null,
  resolucion text check(char_length(coalesce(resolucion,''))<=1500),
  creado_en timestamptz not null default now(),
  revisado_en timestamptz
);
create unique index if not exists uq_kombax_social_reporte_abierto_v041 on public.kombax_social_reportes(reportado_por,objetivo_tipo,objetivo_id) where estado in ('pendiente','en_revision');
create index if not exists idx_kombax_social_reportes_estado_v041 on public.kombax_social_reportes(estado,creado_en desc);

create table if not exists public.kombax_social_moderacion(
  id uuid primary key default gen_random_uuid(),
  moderador_id uuid not null references public.perfiles(id) on delete restrict,
  objetivo_tipo text not null check(objetivo_tipo in ('publicacion','perfil','reporte')),
  objetivo_id uuid not null,
  accion text not null check(accion in ('ocultar','restaurar','limitar','suspender','resolver','descartar')),
  motivo text not null check(char_length(btrim(motivo)) between 3 and 1000),
  creado_en timestamptz not null default now()
);

alter table public.kombax_moderadores_globales enable row level security;
alter table public.kombax_social_perfiles enable row level security;
alter table public.kombax_social_publicaciones enable row level security;
alter table public.kombax_social_likes enable row level security;
alter table public.kombax_social_bloqueos enable row level security;
alter table public.kombax_social_contactos enable row level security;
alter table public.kombax_social_reportes enable row level security;
alter table public.kombax_social_moderacion enable row level security;
revoke all on public.kombax_moderadores_globales,public.kombax_social_perfiles,public.kombax_social_publicaciones,public.kombax_social_likes,public.kombax_social_bloqueos,public.kombax_social_contactos,public.kombax_social_reportes,public.kombax_social_moderacion from public,anon,authenticated;

create or replace function public.app_kombax_es_moderador_v041()
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(select 1 from public.kombax_moderadores_globales m where m.perfil_id=auth.uid() and m.activo);
$$;
revoke all on function public.app_kombax_es_moderador_v041() from public,anon;
grant execute on function public.app_kombax_es_moderador_v041() to authenticated;

create or replace function public.app_kombax_capacidad_club_v041(p_club_id uuid,p_clave text)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(select 1 from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo)
    and exists(select 1 from public.kombax_entitlements e where e.sujeto_tipo='club' and e.sujeto_id=p_club_id and e.capacidad_clave=p_clave and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now()));
$$;
revoke all on function public.app_kombax_capacidad_club_v041(uuid,text) from public,anon;
grant execute on function public.app_kombax_capacidad_club_v041(uuid,text) to authenticated;

create or replace function public.app_kombax_social_acceso_v041()
returns boolean language sql stable security definer set search_path=public,auth as $$
  select auth.uid() is not null and (
    public.app_kombax_es_moderador_v041()
    or exists(select 1 from public.miembros_club m join public.kombax_entitlements e on e.sujeto_tipo='club' and e.sujeto_id=m.club_id and e.capacidad_clave='social.read' and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now()) where m.perfil_id=auth.uid() and m.activo)
    or exists(select 1 from public.perfiles_kombax_directos d join public.kombax_entitlements e on e.sujeto_tipo='perfil_directo' and e.sujeto_id=d.id and e.capacidad_clave='social.read' and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now()) where d.perfil_id=auth.uid() and d.estado='activo')
  );
$$;
revoke all on function public.app_kombax_social_acceso_v041() from public,anon;
grant execute on function public.app_kombax_social_acceso_v041() to authenticated;

create or replace function public.app_kombax_social_puede_publicar_v041(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.kombax_social_perfiles sp
    where sp.id=p_social_id and sp.visible and sp.estado='activo' and sp.publicar_habilitado and (
      (sp.sujeto_tipo='miembro' and exists(select 1 from public.identidades_sociales i where i.id=sp.identidad_social_id and i.perfil_id=auth.uid() and i.estado='activa') and public.app_kombax_capacidad_club_v041((select i.club_origen_id from public.identidades_sociales i where i.id=sp.identidad_social_id),'social.publish'))
      or (sp.sujeto_tipo='club' and public.app_kombax_capacidad_club_v041(sp.club_id,'social.publish') and exists(select 1 from public.miembros_club m where m.club_id=sp.club_id and m.perfil_id=auth.uid() and m.activo and (m.rol in ('direccion','secretaria','comunicacion') or coalesce(m.coordinacion,false))))
      or (sp.sujeto_tipo='perfil_directo' and exists(select 1 from public.perfiles_kombax_directos d join public.kombax_entitlements e on e.sujeto_tipo='perfil_directo' and e.sujeto_id=d.id and e.capacidad_clave='social.publish' and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now()) where d.id=sp.perfil_directo_id and d.perfil_id=auth.uid() and d.estado='activo' and d.verificacion_estado='verificado'))
    )
  );
$$;
revoke all on function public.app_kombax_social_puede_publicar_v041(uuid) from public,anon;
grant execute on function public.app_kombax_social_puede_publicar_v041(uuid) to authenticated;

create or replace function public.app_kombax_social_contactable_v041(p_social_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(
    select 1 from public.kombax_social_perfiles sp
    where sp.id=p_social_id and sp.visible and sp.estado='activo' and (
      (sp.sujeto_tipo in ('club','perfil_directo') and sp.contacto_habilitado)
      or exists(select 1 from public.identidades_sociales i join public.socios s on s.id=i.socio_origen_id and s.club_id=i.club_origen_id where i.id=sp.identidad_social_id and i.estado='activa' and s.estado='activo' and s.fecha_nacimiento is not null and extract(year from age(current_date,s.fecha_nacimiento))>=18)
    )
  );
$$;
revoke all on function public.app_kombax_social_contactable_v041(uuid) from public,anon;
grant execute on function public.app_kombax_social_contactable_v041(uuid) to authenticated;

create or replace function public.app_kombax_social_sync_club_v041()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.kombax_entitlements(sujeto_tipo,sujeto_id,capacidad_clave,activa,origen)
  values('club',new.id,'social.read',true,'manual'),('club',new.id,'social.publish',true,'manual')
  on conflict do nothing;
  insert into public.kombax_social_perfiles(sujeto_tipo,club_id,slug,nombre_publico,bio,avatar_url,banner_url,verificado,visible,publicar_habilitado,contacto_habilitado,estado)
  values('club',new.id,'club-'||new.slug,new.nombre,new.lema,new.logo_url,new.portada_url,true,new.activo,new.activo,true,case when new.activo then 'activo' else 'suspendido' end)
  on conflict do nothing;
  update public.kombax_social_perfiles set nombre_publico=new.nombre,bio=new.lema,avatar_url=new.logo_url,banner_url=new.portada_url,visible=new.activo,publicar_habilitado=new.activo,estado=case when new.activo then 'activo' else 'suspendido' end,actualizado_en=now()
  where sujeto_tipo='club' and club_id=new.id;
  return new;
end $$;
revoke all on function public.app_kombax_social_sync_club_v041() from public,anon,authenticated;
drop trigger if exists clubes_sync_kombax_social_v041 on public.clubes;
create trigger clubes_sync_kombax_social_v041 after insert or update of nombre,lema,logo_url,portada_url,activo on public.clubes for each row execute function public.app_kombax_social_sync_club_v041();

create or replace function public.app_kombax_social_sync_miembro_v041()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_socio public.socios;v_apodo text;v_bio text;v_adulto boolean:=false;
begin
  select * into v_socio from public.socios s where s.id=new.socio_origen_id and s.club_id=new.club_origen_id;
  select nullif(pd.apodo,''),nullif(pd.presentacion,'') into v_apodo,v_bio from public.perfiles_deportivos pd where pd.club_id=new.club_origen_id and pd.socio_id=new.socio_origen_id;
  v_adulto:=v_socio.fecha_nacimiento is not null and extract(year from age(current_date,v_socio.fecha_nacimiento))>=18;
  insert into public.kombax_social_perfiles(sujeto_tipo,identidad_social_id,slug,nombre_publico,bio,verificado,visible,publicar_habilitado,contacto_habilitado,estado)
  values('miembro',new.id,new.slug,coalesce(v_apodo,new.nombre_publico),v_bio,true,new.estado='activa',new.estado='activa',new.estado='activa' and v_adulto,case new.estado when 'activa' then 'activo' when 'suspendida' then 'suspendido' else 'cerrado' end)
  on conflict do nothing;
  update public.kombax_social_perfiles set slug=new.slug,nombre_publico=coalesce(v_apodo,new.nombre_publico),bio=v_bio,visible=new.estado='activa',publicar_habilitado=new.estado='activa',contacto_habilitado=new.estado='activa' and v_adulto,estado=case new.estado when 'activa' then 'activo' when 'suspendida' then 'suspendido' else 'cerrado' end,actualizado_en=now()
  where sujeto_tipo='miembro' and identidad_social_id=new.id;
  return new;
end $$;
revoke all on function public.app_kombax_social_sync_miembro_v041() from public,anon,authenticated;
drop trigger if exists identidades_sync_kombax_social_v041 on public.identidades_sociales;
create trigger identidades_sync_kombax_social_v041 after insert or update on public.identidades_sociales for each row execute function public.app_kombax_social_sync_miembro_v041();

create or replace function public.app_kombax_social_sync_directo_v041()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.kombax_social_perfiles(sujeto_tipo,perfil_directo_id,slug,nombre_publico,bio,verificado,visible,publicar_habilitado,contacto_habilitado,estado)
  values('perfil_directo',new.id,new.slug,new.nombre_publico,new.descripcion,new.verificacion_estado='verificado',new.publico and new.estado='activo',new.publico and new.estado='activo' and new.verificacion_estado='verificado',new.publico and new.estado='activo' and new.verificacion_estado='verificado',case when new.estado='activo' then 'activo' when new.estado='suspendido' then 'suspendido' when new.estado='cerrado' then 'cerrado' else 'limitado' end)
  on conflict do nothing;
  update public.kombax_social_perfiles set slug=new.slug,nombre_publico=new.nombre_publico,bio=new.descripcion,verificado=new.verificacion_estado='verificado',visible=new.publico and new.estado='activo',publicar_habilitado=new.publico and new.estado='activo' and new.verificacion_estado='verificado',contacto_habilitado=new.publico and new.estado='activo' and new.verificacion_estado='verificado',estado=case when new.estado='activo' then 'activo' when new.estado='suspendido' then 'suspendido' when new.estado='cerrado' then 'cerrado' else 'limitado' end,actualizado_en=now()
  where sujeto_tipo='perfil_directo' and perfil_directo_id=new.id;
  return new;
end $$;
revoke all on function public.app_kombax_social_sync_directo_v041() from public,anon,authenticated;
drop trigger if exists directos_sync_kombax_social_v041 on public.perfiles_kombax_directos;
create trigger directos_sync_kombax_social_v041 after insert or update on public.perfiles_kombax_directos for each row execute function public.app_kombax_social_sync_directo_v041();

-- El trigger no puede invocarse como función normal; backfill explícito y seguro.
insert into public.kombax_entitlements(sujeto_tipo,sujeto_id,capacidad_clave,activa,origen)
select 'club',c.id,k.clave,true,'manual' from public.clubes c cross join (values('social.read'),('social.publish')) k(clave)
on conflict do nothing;
insert into public.kombax_social_perfiles(sujeto_tipo,club_id,slug,nombre_publico,bio,avatar_url,banner_url,verificado,visible,publicar_habilitado,contacto_habilitado,estado)
select 'club',c.id,'club-'||c.slug,c.nombre,c.lema,c.logo_url,c.portada_url,true,c.activo,c.activo,true,case when c.activo then 'activo' else 'suspendido' end from public.clubes c
on conflict do nothing;

do $member_backfill$
declare r public.identidades_sociales;
begin
  for r in select * from public.identidades_sociales loop
    insert into public.kombax_social_perfiles(sujeto_tipo,identidad_social_id,slug,nombre_publico,bio,verificado,visible,publicar_habilitado,contacto_habilitado,estado)
    select 'miembro',r.id,r.slug,coalesce(nullif(pd.apodo,''),r.nombre_publico),nullif(pd.presentacion,''),true,r.estado='activa',r.estado='activa',r.estado='activa' and s.fecha_nacimiento is not null and extract(year from age(current_date,s.fecha_nacimiento))>=18,case r.estado when 'activa' then 'activo' when 'suspendida' then 'suspendido' else 'cerrado' end
    from public.socios s left join public.perfiles_deportivos pd on pd.club_id=s.club_id and pd.socio_id=s.id where s.club_id=r.club_origen_id and s.id=r.socio_origen_id
    on conflict do nothing;
  end loop;
end
$member_backfill$;

insert into public.kombax_social_perfiles(sujeto_tipo,perfil_directo_id,slug,nombre_publico,bio,verificado,visible,publicar_habilitado,contacto_habilitado,estado)
select 'perfil_directo',d.id,d.slug,d.nombre_publico,d.descripcion,d.verificacion_estado='verificado',d.publico and d.estado='activo',d.publico and d.estado='activo' and d.verificacion_estado='verificado',d.publico and d.estado='activo' and d.verificacion_estado='verificado',case when d.estado='activo' then 'activo' when d.estado='suspendido' then 'suspendido' when d.estado='cerrado' then 'cerrado' else 'limitado' end
from public.perfiles_kombax_directos d on conflict do nothing;

create or replace function public.trg_kombax_social_likes_v041()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='INSERT' then update public.kombax_social_publicaciones set likes_count=likes_count+1 where id=new.publicacion_id;return new;
  else update public.kombax_social_publicaciones set likes_count=greatest(likes_count-1,0) where id=old.publicacion_id;return old; end if;
end $$;
revoke all on function public.trg_kombax_social_likes_v041() from public,anon,authenticated;
drop trigger if exists kombax_social_likes_count_v041 on public.kombax_social_likes;
create trigger kombax_social_likes_count_v041 after insert or delete on public.kombax_social_likes for each row execute function public.trg_kombax_social_likes_v041();

create or replace function public.app_kombax_social_estado_v041(p_club_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_base jsonb;v_profile public.kombax_social_perfiles;
begin
  if auth.uid() is null or not public.es_miembro_club(p_club_id) then raise exception 'MEMBERSHIP_REQUIRED'; end if;
  v_base:=public.app_comunidad_general_estado_v036(p_club_id);
  select sp.* into v_profile from public.kombax_social_perfiles sp join public.identidades_sociales i on i.id=sp.identidad_social_id where i.perfil_id=auth.uid();
  return v_base||jsonb_build_object('social_profile_id',v_profile.id,'contact_enabled',coalesce(v_profile.contacto_habilitado,false),'rules_version','1.1.0');
end $$;
revoke all on function public.app_kombax_social_estado_v041(uuid) from public,anon;
grant execute on function public.app_kombax_social_estado_v041(uuid) to authenticated;

create or replace function public.app_kombax_social_mis_perfiles_v041()
returns table(id uuid,sujeto_tipo text,nombre_publico text,slug text,avatar_url text,verificado boolean,contacto_habilitado boolean)
language sql stable security definer set search_path=public,auth as $$
  select sp.id,sp.sujeto_tipo,sp.nombre_publico,sp.slug,sp.avatar_url,sp.verificado,public.app_kombax_social_contactable_v041(sp.id)
  from public.kombax_social_perfiles sp where public.app_kombax_social_puede_publicar_v041(sp.id)
  order by case sp.sujeto_tipo when 'miembro' then 0 when 'club' then 1 else 2 end,sp.nombre_publico;
$$;
revoke all on function public.app_kombax_social_mis_perfiles_v041() from public,anon;
grant execute on function public.app_kombax_social_mis_perfiles_v041() to authenticated;

create or replace function public.app_kombax_social_feed_v041(p_cursor timestamptz default null,p_cursor_id uuid default null,p_limit integer default 20)
returns table(id uuid,tipo text,texto text,likes_count integer,creado_en timestamptz,autor_id uuid,autor_nombre text,autor_tipo text,autor_slug text,autor_avatar_url text,autor_verificado boolean,liked_by_me boolean,contactable boolean)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED'; end if;
  return query select p.id,p.tipo,p.texto,p.likes_count,p.creado_en,sp.id,sp.nombre_publico,sp.sujeto_tipo,sp.slug,sp.avatar_url,sp.verificado,
    exists(select 1 from public.kombax_social_likes l where l.publicacion_id=p.id and l.perfil_id=auth.uid()),public.app_kombax_social_contactable_v041(sp.id)
  from public.kombax_social_publicaciones p join public.kombax_social_perfiles sp on sp.id=p.autor_perfil_id
  where p.estado='activa' and sp.estado='activo' and sp.visible
    and (p_cursor is null or (p.creado_en,p.id)<(p_cursor,p_cursor_id))
    and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
  order by p.creado_en desc,p.id desc limit least(greatest(coalesce(p_limit,20),1),20);
end $$;
revoke all on function public.app_kombax_social_feed_v041(timestamptz,uuid,integer) from public,anon;
grant execute on function public.app_kombax_social_feed_v041(timestamptz,uuid,integer) to authenticated;

create or replace function public.app_kombax_social_directorio_v041(p_query text default '',p_limit integer default 30)
returns table(id uuid,sujeto_tipo text,slug text,nombre_publico text,bio text,avatar_url text,banner_url text,verificado boolean,contactable boolean)
language plpgsql stable security definer set search_path=public,auth as $$
declare v_q text:=lower(btrim(coalesce(p_query,'')));
begin
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED'; end if;
  return query select sp.id,sp.sujeto_tipo,sp.slug,sp.nombre_publico,sp.bio,sp.avatar_url,sp.banner_url,sp.verificado,public.app_kombax_social_contactable_v041(sp.id)
  from public.kombax_social_perfiles sp where sp.visible and sp.estado='activo'
    and not exists(select 1 from public.kombax_social_bloqueos b where b.bloqueador_perfil_id=auth.uid() and b.bloqueado_social_id=sp.id)
    and (v_q='' or lower(sp.nombre_publico) like '%'||v_q||'%' or lower(sp.slug) like '%'||v_q||'%' or lower(coalesce(sp.bio,'')) like '%'||v_q||'%')
  order by sp.verificado desc,sp.nombre_publico limit least(greatest(coalesce(p_limit,30),1),50);
end $$;
revoke all on function public.app_kombax_social_directorio_v041(text,integer) from public,anon;
grant execute on function public.app_kombax_social_directorio_v041(text,integer) to authenticated;

create or replace function public.app_kombax_social_contactos_v041()
returns table(id uuid,remitente_id uuid,remitente_nombre text,destinatario_id uuid,destinatario_nombre text,motivo text,mensaje text,estado text,creado_en timestamptz,respondido_en timestamptz,direccion text,gestionable boolean)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if not public.app_kombax_social_acceso_v041() then raise exception 'SOCIAL_ACCESS_REQUIRED'; end if;
  return query select c.id,rs.id,rs.nombre_publico,ds.id,ds.nombre_publico,c.motivo,c.mensaje,c.estado,c.creado_en,c.respondido_en,
    case when c.creado_por=auth.uid() then 'enviada' else 'recibida' end,
    c.estado='pendiente' and public.app_kombax_social_puede_publicar_v041(c.destinatario_social_id)
  from public.kombax_social_contactos c join public.kombax_social_perfiles rs on rs.id=c.remitente_social_id join public.kombax_social_perfiles ds on ds.id=c.destinatario_social_id
  where c.creado_por=auth.uid() or public.app_kombax_social_puede_publicar_v041(c.destinatario_social_id)
  order by c.creado_en desc limit 200;
end $$;
revoke all on function public.app_kombax_social_contactos_v041() from public,anon;
grant execute on function public.app_kombax_social_contactos_v041() to authenticated;

-- El gateway social 041 es independiente de app_mutate_v160. Retirar la
-- operación legal 1.0 del contrato evita que el cliente anuncie una activación
-- histórica incompatible con las Normas KOMBAX Social 1.1.
-- DEPRECATED_MAIN_OPERATION: comunidad_general.activar
do $contract$
begin
  if to_regprocedure('public.app_runtime_contract_v160_pre_kombax_social_041(uuid)') is null then
    if to_regprocedure('public.app_runtime_contract_v160(uuid)') is null then raise exception '041: falta app_runtime_contract_v160'; end if;
    alter function public.app_runtime_contract_v160(uuid) rename to app_runtime_contract_v160_pre_kombax_social_041;
  end if;
end
$contract$;
revoke all on function public.app_runtime_contract_v160_pre_kombax_social_041(uuid) from public,anon,authenticated;

create or replace function public.app_runtime_contract_v160(p_club_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_base jsonb;v_operations jsonb;
begin
  v_base:=public.app_runtime_contract_v160_pre_kombax_social_041(p_club_id);
  select coalesce(jsonb_agg(value),'[]'::jsonb) into v_operations from jsonb_array_elements(coalesce(v_base->'operations','[]'::jsonb)) value where value<>to_jsonb('comunidad_general.activar'::text);
  return jsonb_set(v_base,'{operations}',v_operations,true)||jsonb_build_object('kombax_social_gateway','app_kombax_social_mutate_v041','kombax_social_schema',41);
end $$;
revoke all on function public.app_runtime_contract_v160(uuid) from public,anon;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;

create or replace function public.app_kombax_social_mutate_v041(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_club uuid;v_existing public.app_mutation_requests;v_result jsonb;
  v_actor uuid;v_target uuid;v_post public.kombax_social_publicaciones;v_contact public.kombax_social_contactos;v_report public.kombax_social_reportes;v_active boolean;v_status text;v_reason text;v_type text;v_text text;v_socio public.socios;v_identity public.identidades_sociales;v_age integer;v_min integer;v_legal uuid;v_name text;v_slug text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  begin v_club:=nullif(v_payload->>'club_id','')::uuid; exception when others then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
  if v_club is null or not public.es_miembro_club(v_club) then raise exception 'MUTATION_MEMBERSHIP_REQUIRED'; end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,v_club,p_operation); end if;

  if p_operation='kombax.social.activar' then
    if not exists(select 1 from public.miembros_club m where m.club_id=v_club and m.perfil_id=v_uid and m.activo and m.rol='alumno') then raise exception 'Solo una cuenta de alumno puede activar KOMBAX Social en esta fase'; end if;
    select * into v_socio from public.socios s where s.club_id=v_club and s.perfil_id=v_uid and s.estado='activo' order by s.creado_en desc limit 1;
    if v_socio.id is null or v_socio.fecha_nacimiento is null then raise exception 'El club debe validar primero tu identidad y fecha de nacimiento'; end if;
    v_age:=extract(year from age(current_date,v_socio.fecha_nacimiento))::integer;v_min:=public.app_edad_min_comunidad_general_v036(v_club);
    if v_age<v_min then raise exception 'No cumples la edad mínima configurada para KOMBAX Social'; end if;
    if coalesce((v_payload->>'acepta_normas')::boolean,false) is not true or coalesce((v_payload->>'acepta_privacidad')::boolean,false) is not true then raise exception 'Debes aceptar las normas y la privacidad de KOMBAX Social'; end if;
    select id into v_legal from public.textos_legales where club_id=v_club and tipo='comunidad_general' and version='1.1.0' and vigente limit 1;
    if v_legal is null then raise exception 'Las normas vigentes de KOMBAX Social no están disponibles'; end if;
    select * into v_identity from public.identidades_sociales i where i.perfil_id=v_uid for update;
    if v_identity.id is not null and v_identity.estado in ('suspendida','cerrada') then raise exception 'Tu acceso social no se puede reactivar desde este formulario'; end if;
    select coalesce(nullif(pd.apodo,''),trim(concat_ws(' ',v_socio.nombre,v_socio.apellidos))) into v_name from public.perfiles_deportivos pd where pd.club_id=v_club and pd.socio_id=v_socio.id;
    v_name:=coalesce(v_name,trim(concat_ws(' ',v_socio.nombre,v_socio.apellidos)));v_slug:='miembro-'||replace(v_uid::text,'-','');
    insert into public.aceptaciones_legales(club_id,perfil_id,socio_id,texto_legal_id,tipo,version,aceptado,aceptado_en,revocado_en,user_agent)
    values(v_club,v_uid,v_socio.id,v_legal,'comunidad_general','1.1.0',true,now(),null,left(coalesce(v_payload->>'user_agent',''),500))
    on conflict(club_id,perfil_id,tipo,version,socio_id) do update set texto_legal_id=excluded.texto_legal_id,aceptado=true,aceptado_en=now(),revocado_en=null,user_agent=excluded.user_agent;
    insert into public.identidades_sociales(perfil_id,club_origen_id,socio_origen_id,tipo,slug,nombre_publico,estado,version_normas,activada_en,actualizado_en)
    values(v_uid,v_club,v_socio.id,'miembro',v_slug,v_name,'activa','1.1.0',now(),now())
    on conflict(perfil_id) do update set club_origen_id=excluded.club_origen_id,socio_origen_id=excluded.socio_origen_id,nombre_publico=excluded.nombre_publico,estado='activa',version_normas='1.1.0',actualizado_en=now()
    returning * into v_identity;
    select jsonb_build_object('identity_id',v_identity.id,'status',v_identity.estado,'contact_enabled',v_age>=18) into v_result;

  elsif p_operation='kombax.social.publicar' then
    begin v_actor:=(v_payload->>'autor_perfil_id')::uuid; exception when others then raise exception 'Perfil autor no válido'; end;
    if not public.app_kombax_social_puede_publicar_v041(v_actor) then raise exception 'No puedes publicar con este perfil'; end if;
    v_type:=lower(coalesce(v_payload->>'tipo','actualizacion'));if v_type not in ('actualizacion','resultado','evento','oportunidad') then raise exception 'Tipo de publicación no válido'; end if;
    v_text:=btrim(coalesce(v_payload->>'texto',''));if char_length(v_text)<1 or char_length(v_text)>1500 then raise exception 'El texto debe tener entre 1 y 1500 caracteres'; end if;
    insert into public.kombax_social_publicaciones(autor_perfil_id,tipo,texto) values(v_actor,v_type,v_text) returning * into v_post;
    v_result:=to_jsonb(v_post);

  elsif p_operation='kombax.social.retirar' then
    begin v_target:=(v_payload->>'publicacion_id')::uuid; exception when others then raise exception 'Publicación no válida'; end;
    select * into v_post from public.kombax_social_publicaciones where id=v_target for update;
    if v_post.id is null then raise exception 'Publicación no encontrada'; end if;
    if not public.app_kombax_social_puede_publicar_v041(v_post.autor_perfil_id) and not public.app_kombax_es_moderador_v041() then raise exception 'No puedes retirar esta publicación'; end if;
    update public.kombax_social_publicaciones set estado='retirada',actualizado_en=now() where id=v_target returning * into v_post;v_result:=jsonb_build_object('id',v_post.id,'estado',v_post.estado);

  elsif p_operation='kombax.social.like' then
    begin v_target:=(v_payload->>'publicacion_id')::uuid; exception when others then raise exception 'Publicación no válida'; end;
    if not exists(select 1 from public.kombax_social_publicaciones p join public.kombax_social_perfiles sp on sp.id=p.autor_perfil_id where p.id=v_target and p.estado='activa' and sp.visible and sp.estado='activo') then raise exception 'Publicación no disponible'; end if;
    v_active:=coalesce((v_payload->>'activo')::boolean,true);
    if v_active then insert into public.kombax_social_likes(publicacion_id,perfil_id) values(v_target,v_uid) on conflict do nothing;else delete from public.kombax_social_likes where publicacion_id=v_target and perfil_id=v_uid;end if;
    v_result:=jsonb_build_object('publicacion_id',v_target,'activo',v_active);

  elsif p_operation='kombax.social.bloquear' then
    begin v_target:=(v_payload->>'perfil_social_id')::uuid; exception when others then raise exception 'Perfil no válido'; end;
    if not exists(select 1 from public.kombax_social_perfiles where id=v_target and visible) then raise exception 'Perfil no encontrado'; end if;
    v_active:=coalesce((v_payload->>'bloquear')::boolean,true);
    if v_active then insert into public.kombax_social_bloqueos(bloqueador_perfil_id,bloqueado_social_id) values(v_uid,v_target) on conflict do nothing;else delete from public.kombax_social_bloqueos where bloqueador_perfil_id=v_uid and bloqueado_social_id=v_target;end if;
    v_result:=jsonb_build_object('perfil_social_id',v_target,'bloqueado',v_active);

  elsif p_operation='kombax.social.contactar' then
    begin v_actor:=(v_payload->>'remitente_social_id')::uuid;v_target:=(v_payload->>'destinatario_social_id')::uuid;exception when others then raise exception 'Perfiles de contacto no válidos'; end;
    if not public.app_kombax_social_puede_publicar_v041(v_actor) then raise exception 'No puedes enviar la solicitud con este perfil'; end if;
    if not public.app_kombax_social_contactable_v041(v_actor) or not public.app_kombax_social_contactable_v041(v_target) then raise exception 'El contacto no está disponible; no se permite contacto con perfiles personales menores de 18 años'; end if;
    if v_actor=v_target then raise exception 'No puedes enviarte una solicitud a ti mismo'; end if;
    if exists(select 1 from public.kombax_social_contactos c where c.remitente_social_id=v_actor and c.destinatario_social_id=v_target and c.estado='pendiente') then raise exception 'Ya existe una solicitud pendiente entre estos perfiles'; end if;
    v_reason:=lower(coalesce(v_payload->>'motivo','otro'));if v_reason not in ('entrenamiento','competicion','evento','colaboracion','patrocinio','informacion','otro') then raise exception 'Motivo de contacto no válido'; end if;
    v_text:=btrim(coalesce(v_payload->>'mensaje',''));if char_length(v_text)<10 or char_length(v_text)>500 then raise exception 'El mensaje debe tener entre 10 y 500 caracteres'; end if;
    insert into public.kombax_social_contactos(remitente_social_id,destinatario_social_id,creado_por,motivo,mensaje) values(v_actor,v_target,v_uid,v_reason,v_text) returning * into v_contact;
    v_result:=jsonb_build_object('id',v_contact.id,'estado',v_contact.estado);

  elsif p_operation='kombax.social.contacto.estado' then
    begin v_target:=(v_payload->>'contacto_id')::uuid; exception when others then raise exception 'Solicitud no válida'; end;
    select * into v_contact from public.kombax_social_contactos where id=v_target for update;
    if v_contact.id is null or not public.app_kombax_social_puede_publicar_v041(v_contact.destinatario_social_id) then raise exception 'No puedes gestionar esta solicitud'; end if;
    v_status:=lower(coalesce(v_payload->>'estado',''));if v_status not in ('aceptada','rechazada','cerrada') then raise exception 'Estado de contacto no válido'; end if;
    if v_contact.estado<>'pendiente' and v_status<>'cerrada' then raise exception 'La solicitud ya fue respondida'; end if;
    update public.kombax_social_contactos set estado=v_status,respondido_por=v_uid,respondido_en=now() where id=v_target returning * into v_contact;
    v_result:=jsonb_build_object('id',v_contact.id,'estado',v_contact.estado);

  elsif p_operation='kombax.social.denunciar' then
    v_type:=lower(coalesce(v_payload->>'objetivo_tipo',''));if v_type not in ('publicacion','perfil') then raise exception 'Objetivo no válido'; end if;
    begin v_target:=(v_payload->>'objetivo_id')::uuid; exception when others then raise exception 'Objetivo no válido'; end;
    if v_type='publicacion' and not exists(select 1 from public.kombax_social_publicaciones where id=v_target) then raise exception 'Publicación no encontrada'; end if;
    if v_type='perfil' and not exists(select 1 from public.kombax_social_perfiles where id=v_target) then raise exception 'Perfil no encontrado'; end if;
    v_reason:=lower(coalesce(v_payload->>'motivo','otro'));if v_reason not in ('acoso','odio_discriminacion','violencia','sexual_menores','privacidad','spam','suplantacion','otro') then raise exception 'Motivo de denuncia no válido'; end if;
    insert into public.kombax_social_reportes(reportado_por,objetivo_tipo,objetivo_id,motivo,detalle) values(v_uid,v_type,v_target,v_reason,left(nullif(btrim(v_payload->>'detalle'),''),1500))
    on conflict(reportado_por,objetivo_tipo,objetivo_id) where estado in ('pendiente','en_revision') do update set motivo=excluded.motivo,detalle=excluded.detalle,creado_en=now() returning * into v_report;
    v_result:=jsonb_build_object('id',v_report.id,'estado',v_report.estado);

  elsif p_operation='kombax.social.moderar' then
    if not public.app_kombax_es_moderador_v041() then raise exception 'Moderación global requerida'; end if;
    begin v_target:=(v_payload->>'reporte_id')::uuid; exception when others then raise exception 'Reporte no válido'; end;
    v_status:=lower(coalesce(v_payload->>'estado',''));if v_status not in ('en_revision','resuelta','descartada') then raise exception 'Estado no válido'; end if;
    v_reason:=left(nullif(btrim(v_payload->>'resolucion'),''),1500);
    update public.kombax_social_reportes set estado=v_status,revisado_por=v_uid,resolucion=v_reason,revisado_en=now() where id=v_target returning * into v_report;
    if v_report.id is null then raise exception 'Reporte no encontrado'; end if;
    if v_status='resuelta' and coalesce((v_payload->>'ocultar')::boolean,false) and v_report.objetivo_tipo='publicacion' then update public.kombax_social_publicaciones set estado='oculta',moderada_por=v_uid,moderacion_motivo=coalesce(v_reason,'Ocultada por moderación'),actualizado_en=now() where id=v_report.objetivo_id;end if;
    insert into public.kombax_social_moderacion(moderador_id,objetivo_tipo,objetivo_id,accion,motivo) values(v_uid,'reporte',v_report.id,case when v_status='descartada' then 'descartar' else 'resolver' end,coalesce(v_reason,'Revisión de denuncia'));
    v_result:=jsonb_build_object('id',v_report.id,'estado',v_report.estado);
  else raise exception 'Operación KOMBAX Social no permitida';
  end if;

  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;return v_result;
exception when others then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;
end $$;
revoke all on function public.app_kombax_social_mutate_v041(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_social_mutate_v041(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
