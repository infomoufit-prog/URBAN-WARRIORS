-- KOMBAX RC13 build 20049 · recibos multi-club con snapshot de branding del emisor.
-- No renumera recibos históricos. Los nuevos recibos usan prefijo estable por club.
begin;

alter table public.clubes
  add column if not exists recibo_prefijo text;

do $$
begin
  if not exists(
    select 1 from pg_constraint
    where conname='clubes_recibo_prefijo_v096_check'
      and conrelid='public.clubes'::regclass
  ) then
    alter table public.clubes
      add constraint clubes_recibo_prefijo_v096_check
      check(recibo_prefijo is null or recibo_prefijo ~ '^[A-Z0-9]{2,8}$') not valid;
    alter table public.clubes validate constraint clubes_recibo_prefijo_v096_check;
  end if;
end $$;

create or replace function public.app_kombax_recibo_prefijo_v096(p_nombre text,p_slug text)
returns text
language sql
immutable
set search_path=public
as $$
  with src as (
    select trim(regexp_replace(
      translate(upper(coalesce(nullif(p_nombre,''),nullif(p_slug,''),'KOMBAX')),
        'ÁÉÍÓÚÜÑÇ','AEIOUUNC'),
      '[^A-Z0-9]+',' ','g')) as nombre,
      regexp_replace(upper(coalesce(p_slug,p_nombre,'KX')),'[^A-Z0-9]+','','g') as slug
  ), initials as (
    select string_agg(left(part,1),'' order by ord) as value
    from src, regexp_split_to_table(src.nombre,' +') with ordinality as x(part,ord)
    where part<>''
  )
  select case
    when length(coalesce(initials.value,'')) between 2 and 8 then left(initials.value,8)
    when length(src.slug)>=2 then left(src.slug,8)
    else 'KX'
  end
  from src cross join initials;
$$;
revoke all on function public.app_kombax_recibo_prefijo_v096(text,text) from public,anon,authenticated;

update public.clubes c
set recibo_prefijo=case
  when c.slug='urban-warriors' then 'UW'
  else public.app_kombax_recibo_prefijo_v096(c.nombre,c.slug)
end
where c.recibo_prefijo is null;

create or replace function public.trg_club_recibo_prefijo_v096()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if new.recibo_prefijo is null or btrim(new.recibo_prefijo)='' then
    new.recibo_prefijo:=case
      when new.slug='urban-warriors' then 'UW'
      else public.app_kombax_recibo_prefijo_v096(new.nombre,new.slug)
    end;
  else
    new.recibo_prefijo:=upper(regexp_replace(new.recibo_prefijo,'[^A-Za-z0-9]+','','g'));
  end if;
  return new;
end;
$$;
revoke all on function public.trg_club_recibo_prefijo_v096() from public,anon,authenticated;

drop trigger if exists trg_club_recibo_prefijo_v096 on public.clubes;
create trigger trg_club_recibo_prefijo_v096
before insert on public.clubes
for each row execute function public.trg_club_recibo_prefijo_v096();

alter table public.recibos_cuota
  add column if not exists emisor_nombre text,
  add column if not exists emisor_logo_url text,
  add column if not exists emisor_cif text,
  add column if not exists emisor_email text,
  add column if not exists emisor_telefono text,
  add column if not exists emisor_direccion text,
  add column if not exists emisor_web text,
  add column if not exists emisor_prefijo text;

-- Backfill del branding existente sin cambiar número, importe, fecha ni trazabilidad.
update public.recibos_cuota r
set emisor_nombre=c.nombre,
    emisor_logo_url=coalesce(nullif(c.logo_url,''),nullif(p.logo_url,'')),
    emisor_cif=c.cif,
    emisor_email=c.email,
    emisor_telefono=c.telefono,
    emisor_direccion=c.direccion,
    emisor_web=coalesce(nullif(c.web,''),nullif(p.web_publica,'')),
    emisor_prefijo=c.recibo_prefijo
from public.clubes c
left join public.perfiles_club_publicos p on p.club_id=c.id
where r.club_id=c.id
  and (r.emisor_nombre is null or r.emisor_prefijo is null);

create or replace function public.trg_recibo_branding_v096()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_club public.clubes;
  v_public public.perfiles_club_publicos;
  v_prefix text;
begin
  select * into v_club from public.clubes where id=new.club_id;
  if v_club.id is null then raise exception 'RECIBO_CLUB_NO_ENCONTRADO'; end if;
  select * into v_public from public.perfiles_club_publicos where club_id=new.club_id;

  v_prefix:=coalesce(nullif(v_club.recibo_prefijo,''),public.app_kombax_recibo_prefijo_v096(v_club.nombre,v_club.slug),'KX');
  new.emisor_nombre:=v_club.nombre;
  new.emisor_logo_url:=coalesce(nullif(v_club.logo_url,''),nullif(v_public.logo_url,''));
  new.emisor_cif:=v_club.cif;
  new.emisor_email:=v_club.email;
  new.emisor_telefono:=v_club.telefono;
  new.emisor_direccion:=v_club.direccion;
  new.emisor_web:=coalesce(nullif(v_club.web,''),nullif(v_public.web_publica,''));
  new.emisor_prefijo:=v_prefix;
  new.numero:=v_prefix||'-'||new.anio::text||'-'||lpad(new.secuencia::text,6,'0');
  return new;
end;
$$;
revoke all on function public.trg_recibo_branding_v096() from public,anon,authenticated;

drop trigger if exists trg_recibo_branding_v096 on public.recibos_cuota;
create trigger trg_recibo_branding_v096
before insert on public.recibos_cuota
for each row execute function public.trg_recibo_branding_v096();

commit;
