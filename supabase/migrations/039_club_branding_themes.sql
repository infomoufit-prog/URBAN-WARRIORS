-- KOMBAX / Urban Warriors RC13 build 20022 · branding versionado y reversible.
-- Aditiva. No publica archivos: solo conserva las URLs ya cargadas por Storage.

begin;

alter table public.clubes
  add column if not exists theme_id text not null default 'combat-dark',
  add column if not exists branding_version integer not null default 1,
  add column if not exists branding_actualizado_en timestamptz,
  add column if not exists branding_actualizado_por uuid references public.perfiles(id) on delete set null;

do $$ begin
  alter table public.clubes add constraint clubes_theme_id_v039
    check (theme_id in ('combat-dark','performance-pro','champion-gold','dojo-heritage')) not valid;
exception when duplicate_object then null; end $$;
alter table public.clubes validate constraint clubes_theme_id_v039;

create table if not exists public.club_branding_history (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  version integer not null check(version>0),
  snapshot jsonb not null,
  motivo text not null default 'publicacion',
  creado_por uuid references public.perfiles(id) on delete set null,
  creado_en timestamptz not null default now(),
  unique(club_id,version),
  check(jsonb_typeof(snapshot)='object'),
  check(char_length(motivo) between 1 and 240)
);
create index if not exists idx_club_branding_history_v039
  on public.club_branding_history(club_id,version desc);

insert into public.club_branding_history(club_id,version,snapshot,motivo)
select c.id,c.branding_version,
  jsonb_build_object('theme_id',c.theme_id,'logo_url',c.logo_url,'portada_url',c.portada_url),
  'estado inicial'
from public.clubes c
on conflict(club_id,version) do nothing;

alter table public.club_branding_history enable row level security;
revoke all on public.club_branding_history from public,anon,authenticated;
grant select on public.club_branding_history to authenticated;
drop policy if exists club_branding_history_select_v039 on public.club_branding_history;
create policy club_branding_history_select_v039 on public.club_branding_history
for select using (
  exists(select 1 from public.miembros_club m
    where m.club_id=club_branding_history.club_id and m.perfil_id=auth.uid() and m.activo
      and (m.rol='direccion' or coalesce(m.coordinacion,false)))
);

create or replace function public.app_puede_publicar_branding_v039(p_club_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists(select 1 from public.miembros_club m
    where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo
      and (m.rol='direccion' or coalesce(m.coordinacion,false)));
$$;
revoke all on function public.app_puede_publicar_branding_v039(uuid) from public,anon;
grant execute on function public.app_puede_publicar_branding_v039(uuid) to authenticated;

create or replace function public.app_guard_branding_v039()
returns trigger language plpgsql security definer set search_path=public,auth as $$
begin
  if auth.uid() is not null and (
    new.theme_id is distinct from old.theme_id or new.logo_url is distinct from old.logo_url or
    new.portada_url is distinct from old.portada_url or new.color_primario is distinct from old.color_primario or
    new.color_secundario is distinct from old.color_secundario
  ) and not public.app_puede_publicar_branding_v039(old.id) then
    raise exception 'BRANDING_FORBIDDEN';
  end if;
  return new;
end $$;
revoke all on function public.app_guard_branding_v039() from public,anon,authenticated;
drop trigger if exists clubes_guard_branding_v039 on public.clubes;
create trigger clubes_guard_branding_v039 before update on public.clubes
for each row execute function public.app_guard_branding_v039();

create or replace function public.app_publicar_branding_v039(
  p_club_id uuid,
  p_expected_version integer,
  p_theme_id text,
  p_logo_url text default null,
  p_portada_url text default null
) returns jsonb
language plpgsql security definer set search_path=public,auth as $$
declare v_club public.clubes; v_next integer; v_logo text; v_cover text;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_puede_publicar_branding_v039(p_club_id) then raise exception 'BRANDING_FORBIDDEN'; end if;
  if p_theme_id is null or p_theme_id not in ('combat-dark','performance-pro','champion-gold','dojo-heritage') then raise exception 'BRANDING_THEME_INVALID'; end if;
  v_logo:=nullif(btrim(coalesce(p_logo_url,'')),'');
  v_cover:=nullif(btrim(coalesce(p_portada_url,'')),'');
  if v_logo is not null and (char_length(v_logo)>1000 or v_logo !~* '^https://') then raise exception 'BRANDING_LOGO_URL_INVALID'; end if;
  if v_cover is not null and (char_length(v_cover)>1000 or v_cover !~* '^https://') then raise exception 'BRANDING_COVER_URL_INVALID'; end if;

  perform pg_advisory_xact_lock(hashtextextended(p_club_id::text,39));
  select * into v_club from public.clubes where id=p_club_id for update;
  if v_club.id is null then raise exception 'BRANDING_CLUB_NOT_FOUND'; end if;
  if v_club.branding_version is distinct from p_expected_version then raise exception 'BRANDING_VERSION_CONFLICT'; end if;

  insert into public.club_branding_history(club_id,version,snapshot,motivo,creado_por)
  values(v_club.id,v_club.branding_version,
    jsonb_build_object('theme_id',v_club.theme_id,'logo_url',v_club.logo_url,'portada_url',v_club.portada_url),
    'antes de publicar',auth.uid())
  on conflict(club_id,version) do nothing;

  v_next:=v_club.branding_version+1;
  update public.clubes set theme_id=p_theme_id,logo_url=v_logo,portada_url=v_cover,
    branding_version=v_next,branding_actualizado_en=now(),branding_actualizado_por=auth.uid(),actualizado_en=now()
  where id=p_club_id returning * into v_club;
  return jsonb_build_object('ok',true,'club_id',v_club.id,'theme_id',v_club.theme_id,
    'logo_url',v_club.logo_url,'portada_url',v_club.portada_url,'branding_version',v_club.branding_version);
end $$;
revoke all on function public.app_publicar_branding_v039(uuid,integer,text,text,text) from public,anon;
grant execute on function public.app_publicar_branding_v039(uuid,integer,text,text,text) to authenticated;

create or replace function public.app_restaurar_branding_v039(p_club_id uuid,p_source_version integer)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_club public.clubes; v_source public.club_branding_history; v_next integer;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not public.app_puede_publicar_branding_v039(p_club_id) then raise exception 'BRANDING_FORBIDDEN'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_club_id::text,39));
  select * into v_club from public.clubes where id=p_club_id for update;
  select * into v_source from public.club_branding_history where club_id=p_club_id and version=p_source_version;
  if v_club.id is null then raise exception 'BRANDING_CLUB_NOT_FOUND'; end if;
  if v_source.id is null then raise exception 'BRANDING_VERSION_NOT_FOUND'; end if;
  if coalesce(v_source.snapshot->>'theme_id','') not in ('combat-dark','performance-pro','champion-gold','dojo-heritage') then raise exception 'BRANDING_HISTORY_INVALID'; end if;

  insert into public.club_branding_history(club_id,version,snapshot,motivo,creado_por)
  values(v_club.id,v_club.branding_version,
    jsonb_build_object('theme_id',v_club.theme_id,'logo_url',v_club.logo_url,'portada_url',v_club.portada_url),
    'antes de restaurar '||p_source_version::text,auth.uid())
  on conflict(club_id,version) do nothing;

  v_next:=v_club.branding_version+1;
  update public.clubes set theme_id=v_source.snapshot->>'theme_id',
    logo_url=nullif(v_source.snapshot->>'logo_url',''),portada_url=nullif(v_source.snapshot->>'portada_url',''),
    branding_version=v_next,branding_actualizado_en=now(),branding_actualizado_por=auth.uid(),actualizado_en=now()
  where id=p_club_id returning * into v_club;
  return jsonb_build_object('ok',true,'club_id',v_club.id,'theme_id',v_club.theme_id,
    'logo_url',v_club.logo_url,'portada_url',v_club.portada_url,'branding_version',v_club.branding_version,
    'restored_from',p_source_version);
end $$;
revoke all on function public.app_restaurar_branding_v039(uuid,integer) from public,anon;
grant execute on function public.app_restaurar_branding_v039(uuid,integer) to authenticated;

commit;
