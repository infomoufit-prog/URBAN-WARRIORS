-- KOMBAX RC13 build 20.090 · 159 · KOMBAX Eventos Foundation
-- Dominio público transversal INDEPENDIENTE de public.eventos_competicion (Mi Club > Eventos).
-- Fase 1: modelo seguro + lectura pública. La escritura/organización se abrirá por entitlements en fases posteriores.
begin;

insert into public.kombax_capacidades(clave,descripcion,sensible) values
 ('events.public.read','Descubrir y consultar KOMBAX Eventos públicos',false),
 ('events.public.organize','Crear y gestionar KOMBAX Eventos públicos',true),
 ('events.public.share','Compartir piezas públicas de KOMBAX Eventos',false)
on conflict(clave) do nothing;

create table if not exists public.kombax_eventos_publicos(
 id uuid primary key default gen_random_uuid(),
 slug text not null unique check(slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
 tipo text not null check(tipo in ('open','interclub','velada','campeonato','torneo','seminario','clinic','masterclass','stage','campus','sparring_day','exhibicion','federativo','otro')),
 nombre text not null check(char_length(nombre) between 3 and 180),
 resumen text not null default '' check(char_length(resumen)<=500),
 descripcion text not null default '' check(char_length(descripcion)<=6000),
 estado text not null default 'borrador' check(estado in ('borrador','publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado','cancelado')),
 visibilidad text not null default 'publico' check(visibilidad in ('publico','kombax','invitacion')),
 fecha_inicio timestamptz,
 fecha_fin timestamptz,
 timezone text not null default 'Europe/Madrid' check(char_length(timezone) between 3 and 80),
 lugar_nombre text not null default '' check(char_length(lugar_nombre)<=220),
 municipio text not null default '' check(char_length(municipio)<=120),
 provincia text not null default '' check(char_length(provincia)<=120),
 pais text not null default 'España' check(char_length(pais)<=120),
 cartel_url text,
 banner_url text,
 tema_visual text not null default 'fight' check(tema_visual in ('fight','arena','federation','seminar')),
 creador_tipo text not null check(creador_tipo in ('club','perfil_directo')),
 creador_club_id uuid references public.clubes(id) on delete restrict,
 creador_perfil_directo_id uuid references public.perfiles_kombax_directos(id) on delete restrict,
 organizador_nombre text not null default '' check(char_length(organizador_nombre)<=180),
 creado_por uuid not null references public.perfiles(id) on delete restrict default auth.uid(),
 publicado_en timestamptz,
 creado_en timestamptz not null default now(),
 actualizado_en timestamptz not null default now(),
 constraint kombax_eventos_publicos_creador_ck check(
   (creador_tipo='club' and creador_club_id is not null and creador_perfil_directo_id is null)
   or (creador_tipo='perfil_directo' and creador_perfil_directo_id is not null and creador_club_id is null)
 ),
 constraint kombax_eventos_publicos_fechas_ck check(fecha_fin is null or fecha_inicio is null or fecha_fin>=fecha_inicio)
);
create index if not exists idx_kombax_eventos_publicos_discovery_v159 on public.kombax_eventos_publicos(estado,fecha_inicio,id) where visibilidad='publico';
create index if not exists idx_kombax_eventos_publicos_tipo_fecha_v159 on public.kombax_eventos_publicos(tipo,fecha_inicio,id) where visibilidad='publico';
create index if not exists idx_kombax_eventos_publicos_creator_club_v159 on public.kombax_eventos_publicos(creador_club_id,fecha_inicio desc) where creador_club_id is not null;
create index if not exists idx_kombax_eventos_publicos_creator_profile_v159 on public.kombax_eventos_publicos(creador_perfil_directo_id,fecha_inicio desc) where creador_perfil_directo_id is not null;

alter table public.kombax_eventos_publicos enable row level security;
revoke all on public.kombax_eventos_publicos from public,anon,authenticated;

-- Lectura segura: solo campos destinados a superficie pública; jamás toca eventos_competicion.
create or replace function public.app_kombax_eventos_publicos_v159(
 p_query text default '',p_tipo text default null,p_estado text default null,p_limit integer default 60
) returns table(
 id uuid,slug text,tipo text,nombre text,resumen text,descripcion text,estado text,fecha_inicio timestamptz,fecha_fin timestamptz,
 timezone text,lugar_nombre text,municipio text,provincia text,pais text,cartel_url text,banner_url text,tema_visual text,
 creador_tipo text,organizador_nombre text
) language sql stable security definer set search_path=public as $$
 select e.id,e.slug,e.tipo,e.nombre,e.resumen,e.descripcion,e.estado,e.fecha_inicio,e.fecha_fin,e.timezone,e.lugar_nombre,e.municipio,e.provincia,e.pais,e.cartel_url,e.banner_url,e.tema_visual,e.creador_tipo,e.organizador_nombre
 from public.kombax_eventos_publicos e
 where e.visibilidad='publico'
   and e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado')
   and (p_tipo is null or p_tipo='' or e.tipo=p_tipo)
   and (p_estado is null or p_estado='' or e.estado=p_estado)
   and (coalesce(trim(p_query),'')='' or lower(concat_ws(' ',e.nombre,e.resumen,e.descripcion,e.organizador_nombre,e.lugar_nombre,e.municipio,e.provincia,e.pais)) like '%'||lower(trim(p_query))||'%')
 order by case when e.estado='en_curso' then 0 when e.fecha_inicio>=now() then 1 else 2 end,e.fecha_inicio asc nulls last,e.id
 limit least(100,greatest(1,coalesce(p_limit,60)));
$$;
revoke all on function public.app_kombax_eventos_publicos_v159(text,text,text,integer) from public;
grant execute on function public.app_kombax_eventos_publicos_v159(text,text,text,integer) to anon,authenticated;

create or replace function public.app_kombax_evento_publico_detalle_v159(p_evento_id uuid)
returns table(
 id uuid,slug text,tipo text,nombre text,resumen text,descripcion text,estado text,fecha_inicio timestamptz,fecha_fin timestamptz,
 timezone text,lugar_nombre text,municipio text,provincia text,pais text,cartel_url text,banner_url text,tema_visual text,
 creador_tipo text,organizador_nombre text
) language sql stable security definer set search_path=public as $$
 select e.id,e.slug,e.tipo,e.nombre,e.resumen,e.descripcion,e.estado,e.fecha_inicio,e.fecha_fin,e.timezone,e.lugar_nombre,e.municipio,e.provincia,e.pais,e.cartel_url,e.banner_url,e.tema_visual,e.creador_tipo,e.organizador_nombre
 from public.kombax_eventos_publicos e
 where e.id=p_evento_id and e.visibilidad='publico'
   and e.estado in ('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado')
 limit 1;
$$;
revoke all on function public.app_kombax_evento_publico_detalle_v159(uuid) from public;
grant execute on function public.app_kombax_evento_publico_detalle_v159(uuid) to anon,authenticated;

comment on table public.kombax_eventos_publicos is 'KOMBAX Eventos públicos. Dominio transversal; NO contiene ni refleja automáticamente eventos internos de Mi Club.';
comment on function public.app_kombax_eventos_publicos_v159(text,text,text,integer) is 'Superficie pública segura de KOMBAX Eventos. No consulta public.eventos_competicion.';

commit;
