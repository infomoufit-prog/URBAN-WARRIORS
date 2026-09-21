-- KOMBAX RC13 build 20023 · puerta pública, contextos multiclub y perfiles directos cerrados.
-- No crea precios, checkout ni perfiles directos reales. Los clubes demo viven en fixtures separados.

begin;

create table if not exists public.perfiles_kombax_directos(
  id uuid primary key default gen_random_uuid(),
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  tipo text not null check(tipo in ('competidor','marca','federacion','espectador','profesional')),
  slug text not null unique check(slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  nombre_publico text not null check(char_length(nombre_publico) between 1 and 160),
  descripcion text check(char_length(coalesce(descripcion,''))<=1600),
  estado text not null default 'borrador' check(estado in ('borrador','pendiente_verificacion','activo','suspendido','cerrado')),
  verificacion_estado text not null default 'no_iniciada' check(verificacion_estado in ('no_iniciada','pendiente','verificado','rechazado')),
  publico boolean not null default false,
  moderacion_estado text not null default 'normal' check(moderacion_estado in ('normal','limitado','suspendido')),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique(perfil_id,tipo)
);
create index if not exists idx_perfiles_kombax_directos_estado_v040 on public.perfiles_kombax_directos(tipo,estado,publico);

create table if not exists public.kombax_capacidades(
  clave text primary key check(clave ~ '^[a-z][a-z0-9_.-]{2,80}$'),
  descripcion text not null,
  sensible boolean not null default false,
  creada_en timestamptz not null default now()
);
insert into public.kombax_capacidades(clave,descripcion,sensible) values
  ('club.manage','Acceso a la gestión privada concedido por membresía de club',true),
  ('social.read','Lectura de KOMBAX Social',false),
  ('social.publish','Publicación en KOMBAX Social',true),
  ('contact.request','Creación de solicitudes estructuradas de contacto',true),
  ('showcase.publish','Publicación informativa en KOMBAX Showcase',true)
on conflict(clave) do nothing;

create table if not exists public.kombax_suscripciones(
  id uuid primary key default gen_random_uuid(),
  sujeto_tipo text not null check(sujeto_tipo in ('club','perfil_directo')),
  sujeto_id uuid not null,
  estado text not null default 'inactiva' check(estado in ('inactiva','prueba','activa','pausada','cancelada')),
  modalidad text,
  proveedor text,
  referencia_externa text,
  inicia_en timestamptz,
  termina_en timestamptz,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  check(termina_en is null or inicia_en is null or termina_en>inicia_en)
);
create index if not exists idx_kombax_suscripciones_sujeto_v040 on public.kombax_suscripciones(sujeto_tipo,sujeto_id,estado);

create table if not exists public.kombax_entitlements(
  id uuid primary key default gen_random_uuid(),
  sujeto_tipo text not null check(sujeto_tipo in ('club','perfil_directo')),
  sujeto_id uuid not null,
  capacidad_clave text not null references public.kombax_capacidades(clave) on delete restrict,
  activa boolean not null default true,
  origen text not null default 'manual' check(origen in ('membresia','suscripcion','manual','promocion')),
  inicia_en timestamptz not null default now(),
  termina_en timestamptz,
  asignada_por uuid references public.perfiles(id) on delete set null,
  creada_en timestamptz not null default now(),
  check(termina_en is null or termina_en>inicia_en)
);
create unique index if not exists idx_kombax_entitlement_activo_v040 on public.kombax_entitlements(sujeto_tipo,sujeto_id,capacidad_clave) where activa;

create or replace function public.app_validar_sujeto_kombax_v040()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.sujeto_tipo='club' and not exists(select 1 from public.clubes where id=new.sujeto_id) then raise exception 'KOMBAX_SUBJECT_CLUB_NOT_FOUND'; end if;
  if new.sujeto_tipo='perfil_directo' and not exists(select 1 from public.perfiles_kombax_directos where id=new.sujeto_id) then raise exception 'KOMBAX_SUBJECT_PROFILE_NOT_FOUND'; end if;
  return new;
end $$;
revoke all on function public.app_validar_sujeto_kombax_v040() from public,anon,authenticated;
drop trigger if exists kombax_suscripciones_sujeto_v040 on public.kombax_suscripciones;
create trigger kombax_suscripciones_sujeto_v040 before insert or update of sujeto_tipo,sujeto_id on public.kombax_suscripciones for each row execute function public.app_validar_sujeto_kombax_v040();
drop trigger if exists kombax_entitlements_sujeto_v040 on public.kombax_entitlements;
create trigger kombax_entitlements_sujeto_v040 before insert or update of sujeto_tipo,sujeto_id on public.kombax_entitlements for each row execute function public.app_validar_sujeto_kombax_v040();

alter table public.perfiles_kombax_directos enable row level security;
alter table public.kombax_capacidades enable row level security;
alter table public.kombax_suscripciones enable row level security;
alter table public.kombax_entitlements enable row level security;
revoke all on public.perfiles_kombax_directos,public.kombax_capacidades,public.kombax_suscripciones,public.kombax_entitlements from public,anon,authenticated;
grant select on public.perfiles_kombax_directos to authenticated;
drop policy if exists perfiles_kombax_directos_propios_v040 on public.perfiles_kombax_directos;
create policy perfiles_kombax_directos_propios_v040 on public.perfiles_kombax_directos for select using(perfil_id=auth.uid());

create or replace function public.app_buscar_clubes_kombax_v040(p_query text default '',p_limit integer default 30)
returns table(club_id uuid,slug text,nombre text,lema text,logo_url text,portada_url text,ciudad text,provincia text,theme_id text,branding_version integer,disciplinas jsonb)
language sql stable security definer set search_path=public as $$
  with q as(select lower(btrim(coalesce(p_query,''))) value)
  select c.id,c.slug,coalesce(nullif(pc.nombre_publico,''),c.nombre),coalesce(pc.lema,c.lema),coalesce(pc.logo_url,c.logo_url),coalesce(pc.portada_url,c.portada_url),pc.ciudad,pc.provincia,c.theme_id,c.branding_version,
    coalesce((select jsonb_agg(d.nombre order by d.orden,d.nombre) from public.disciplinas d where d.club_id=c.id and d.activa),'[]'::jsonb)
  from public.clubes c left join public.perfiles_club_publicos pc on pc.club_id=c.id cross join q
  where c.activo and coalesce(pc.visible,true) and not coalesce(pc.moderacion_oculta,false)
    and (q.value='' or lower(c.nombre) like '%'||q.value||'%' or lower(c.slug) like '%'||q.value||'%'
      or lower(coalesce(pc.ciudad,'')) like '%'||q.value||'%' or lower(coalesce(pc.provincia,'')) like '%'||q.value||'%'
      or exists(select 1 from public.disciplinas d where d.club_id=c.id and d.activa and lower(d.nombre) like '%'||q.value||'%'))
  order by case when lower(c.nombre)=q.value then 0 else 1 end,c.nombre
  limit least(greatest(coalesce(p_limit,30),1),50);
$$;
revoke all on function public.app_buscar_clubes_kombax_v040(text,integer) from public;
grant execute on function public.app_buscar_clubes_kombax_v040(text,integer) to anon,authenticated;

create or replace function public.app_mis_contextos_kombax_v040()
returns jsonb language sql stable security definer set search_path=public,auth as $$
  select case when auth.uid() is null then jsonb_build_object('clubs','[]'::jsonb,'direct_profiles','[]'::jsonb)
  else jsonb_build_object(
    'clubs',coalesce((select jsonb_agg(jsonb_build_object('club_id',m.club_id,'rol',m.rol,'coordinacion',coalesce(m.coordinacion,false),'club',jsonb_build_object('id',c.id,'slug',c.slug,'nombre',c.nombre,'lema',c.lema,'logo_url',c.logo_url,'portada_url',c.portada_url,'theme_id',c.theme_id,'branding_version',c.branding_version)) order by c.nombre,m.rol::text)
      from public.miembros_club m join public.clubes c on c.id=m.club_id where m.perfil_id=auth.uid() and m.activo and c.activo),'[]'::jsonb),
    'direct_profiles',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'tipo',p.tipo,'slug',p.slug,'nombre_publico',p.nombre_publico,'estado',p.estado,'verificacion_estado',p.verificacion_estado,'publico',p.publico) order by p.tipo)
      from public.perfiles_kombax_directos p where p.perfil_id=auth.uid()),'[]'::jsonb)
  ) end;
$$;
revoke all on function public.app_mis_contextos_kombax_v040() from public,anon;
grant execute on function public.app_mis_contextos_kombax_v040() to authenticated;

commit;
