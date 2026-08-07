-- Urban Warriors 1.6.0 build 12
-- Recibos breves de cuota: emisión automática, trazabilidad y lectura familiar/tesorería.

begin;

create table if not exists public.recibos_contadores (
  club_id uuid not null references public.clubes(id) on delete cascade,
  anio integer not null check (anio between 2020 and 2200),
  ultimo integer not null default 0 check (ultimo >= 0),
  actualizado_en timestamptz not null default now(),
  primary key (club_id, anio)
);

create table if not exists public.recibos_cuota (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  cuota_id uuid not null,
  socio_id uuid not null,
  pago_id uuid,
  anio integer not null,
  secuencia integer not null,
  numero text not null,
  socio_nombre text not null,
  pagado_por text not null,
  actividad text not null,
  periodo date not null,
  importe numeric(10,2) not null check (importe >= 0),
  fecha_pago date not null,
  metodo text,
  emitido_en timestamptz not null default now(),
  anulado_en timestamptz,
  motivo_anulacion text,
  creado_por uuid references public.perfiles(id),
  foreign key (club_id, cuota_id) references public.cuotas(club_id, id) on delete restrict,
  foreign key (club_id, socio_id) references public.socios(club_id, id) on delete restrict,
  foreign key (pago_id) references public.pagos(id) on delete set null,
  unique (club_id, cuota_id),
  unique (club_id, numero),
  unique (club_id, anio, secuencia)
);
create index if not exists idx_recibos_cuota_club_periodo on public.recibos_cuota(club_id, periodo desc, numero desc);
create index if not exists idx_recibos_cuota_socio on public.recibos_cuota(club_id, socio_id, periodo desc);

alter table public.recibos_contadores enable row level security;
alter table public.recibos_cuota enable row level security;

-- El contador nunca se expone al cliente.
drop policy if exists recibos_contadores_sin_cliente on public.recibos_contadores;
create policy recibos_contadores_sin_cliente on public.recibos_contadores
for select using (false);

-- El socio/tutor puede ver sus recibos; dirección, economía y secretaría pueden consultar todos.
drop policy if exists recibos_cuota_lectura on public.recibos_cuota;
create policy recibos_cuota_lectura on public.recibos_cuota
for select using (
  public.puede_ver_socio(socio_id)
  or public.tiene_rol_club(club_id,'direccion','economia','secretaria')
);

revoke all on table public.recibos_contadores from public, anon, authenticated;
revoke insert, update, delete on table public.recibos_cuota from public, anon, authenticated;
grant select on table public.recibos_cuota to authenticated;

create or replace function public.emitir_recibo_cuota(p_cuota_id uuid)
returns public.recibos_cuota
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_fee public.cuotas;
  v_payment public.pagos;
  v_member public.socios;
  v_receipt public.recibos_cuota;
  v_year integer;
  v_seq integer;
  v_number text;
  v_activity text;
  v_payer text;
  v_tutor text;
  v_staff boolean;
  v_destinatario uuid;
begin
  select * into v_fee from public.cuotas where id=p_cuota_id for update;
  if v_fee.id is null then raise exception 'RECIBO_CUOTA_NO_ENCONTRADA'; end if;
  if v_fee.estado <> 'pagada' then raise exception 'RECIBO_CUOTA_NO_PAGADA'; end if;

  select * into v_receipt from public.recibos_cuota where club_id=v_fee.club_id and cuota_id=v_fee.id;
  if v_receipt.id is not null then return v_receipt; end if;

  select * into v_member from public.socios where club_id=v_fee.club_id and id=v_fee.socio_id;
  if v_member.id is null then raise exception 'RECIBO_SOCIO_NO_ENCONTRADO'; end if;

  select p.* into v_payment
  from public.pagos p
  where p.club_id=v_fee.club_id and p.cuota_id=v_fee.id and p.estado_validacion='validado'
  order by coalesce(p.validado_en,p.creado_en) desc, p.fecha desc, p.id desc
  limit 1;

  -- Actividad: disciplina de la tarifa cuando existe; si no, resumen de matrículas activas.
  select d.nombre into v_activity
  from public.tarifas t
  join public.disciplinas d on d.club_id=t.club_id and d.id=t.disciplina_id
  where t.club_id=v_fee.club_id and t.id=v_fee.tarifa_id
  limit 1;

  if coalesce(v_activity,'')='' then
    select string_agg(x.nombre, ' + ' order by x.nombre) into v_activity
    from (
      select distinct d.nombre
      from public.socio_disciplinas sd
      join public.disciplinas d on d.club_id=sd.club_id and d.id=sd.disciplina_id
      where sd.club_id=v_fee.club_id and sd.socio_id=v_fee.socio_id and sd.activa
    ) x;
  end if;
  v_activity := coalesce(nullif(v_activity,''), nullif(v_fee.concepto,''), 'Cuota de socio');

  -- Pagador: si quien comunicó el pago es el propio socio/tutor, usar su nombre.
  -- Si lo registró personal del club, usar tutor principal cuando exista; en adulto, el socio.
  v_payer := null;
  if v_payment.comunicado_por is not null then
    select exists(
      select 1 from public.miembros_club mc
      where mc.club_id=v_fee.club_id and mc.perfil_id=v_payment.comunicado_por and mc.activo
        and mc.rol in ('direccion','economia','secretaria','monitor','comunicacion')
    ) into v_staff;
    if not coalesce(v_staff,false) then
      select trim(concat_ws(' ',p.nombre,p.apellidos)) into v_payer
      from public.perfiles p where p.id=v_payment.comunicado_por;
    end if;
  end if;

  select trim(concat_ws(' ',p.nombre,p.apellidos)) into v_tutor
  from public.tutores_socios ts
  join public.perfiles p on p.id=ts.tutor_perfil_id
  where ts.club_id=v_fee.club_id and ts.socio_id=v_fee.socio_id
  order by ts.contacto_principal desc, ts.id
  limit 1;

  v_payer := coalesce(nullif(v_payer,''), nullif(v_tutor,''), trim(concat_ws(' ',v_member.nombre,v_member.apellidos)));
  v_year := extract(year from coalesce(v_payment.fecha,current_date))::integer;

  insert into public.recibos_contadores(club_id,anio,ultimo)
  values(v_fee.club_id,v_year,1)
  on conflict(club_id,anio) do update
    set ultimo=public.recibos_contadores.ultimo+1, actualizado_en=now()
  returning ultimo into v_seq;

  v_number := 'UW-'||v_year::text||'-'||lpad(v_seq::text,6,'0');

  insert into public.recibos_cuota(
    club_id,cuota_id,socio_id,pago_id,anio,secuencia,numero,socio_nombre,pagado_por,
    actividad,periodo,importe,fecha_pago,metodo,creado_por
  ) values (
    v_fee.club_id,v_fee.id,v_fee.socio_id,v_payment.id,v_year,v_seq,v_number,
    trim(concat_ws(' ',v_member.nombre,v_member.apellidos)),v_payer,v_activity,v_fee.periodo,
    v_fee.importe,coalesce(v_payment.fecha,current_date),v_payment.metodo,v_payment.validado_por
  ) returning * into v_receipt;

  select coalesce(v_member.perfil_id,ts.tutor_perfil_id) into v_destinatario
  from public.socios s
  left join lateral (
    select t.tutor_perfil_id from public.tutores_socios t
    where t.club_id=s.club_id and t.socio_id=s.id
    order by t.contacto_principal desc,t.id limit 1
  ) ts on true
  where s.club_id=v_fee.club_id and s.id=v_fee.socio_id;

  if v_destinatario is not null then
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos)
    values(
      v_fee.club_id,v_destinatario,'recibo-'||v_fee.id::text,'cuota','Pago validado · recibo disponible',
      v_receipt.socio_nombre||': '||v_receipt.numero||' ya está disponible.','fees',
      jsonb_build_object('recibo_id',v_receipt.id,'cuota_id',v_fee.id,'numero',v_receipt.numero)
    )
    on conflict (club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;
  end if;

  return v_receipt;
end;
$$;

revoke all on function public.emitir_recibo_cuota(uuid) from public, anon, authenticated;

create or replace function public.trg_emitir_recibo_cuota_pagada()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if new.estado='pagada' and (tg_op='INSERT' or old.estado is distinct from new.estado) then
    perform public.emitir_recibo_cuota(new.id);
  end if;
  return new;
end;
$$;

revoke all on function public.trg_emitir_recibo_cuota_pagada() from public, anon, authenticated;

drop trigger if exists trg_emitir_recibo_cuota_pagada on public.cuotas;
create trigger trg_emitir_recibo_cuota_pagada
after insert or update of estado on public.cuotas
for each row execute function public.trg_emitir_recibo_cuota_pagada();

-- Compatibilidad con cuotas que ya estaban pagadas antes de instalar esta migración.
do $$
declare r record;
begin
  for r in
    select c.id from public.cuotas c
    where c.estado='pagada'
      and not exists(select 1 from public.recibos_cuota rc where rc.club_id=c.club_id and rc.cuota_id=c.id)
    order by c.periodo,c.creado_en,c.id
  loop
    perform public.emitir_recibo_cuota(r.id);
  end loop;
end;
$$;

-- Diagnóstico no destructivo para SQL Editor.
create or replace function public.app_diagnostico_recibos_v160(p_club_id uuid)
returns jsonb
language sql
security definer
set search_path=public,auth
as $$
  select jsonb_build_object(
    'ok',
      to_regclass('public.recibos_cuota') is not null
      and to_regprocedure('public.emitir_recibo_cuota(uuid)') is not null
      and exists(select 1 from pg_trigger where tgname='trg_emitir_recibo_cuota_pagada' and not tgisinternal),
    'club_id',p_club_id,
    'recibos',count(*),
    'pagadas_sin_recibo',(
      select count(*) from public.cuotas c
      where c.club_id=p_club_id and c.estado='pagada'
        and not exists(select 1 from public.recibos_cuota r where r.club_id=c.club_id and r.cuota_id=c.id)
    )
  )
  from public.recibos_cuota r where r.club_id=p_club_id;
$$;
revoke all on function public.app_diagnostico_recibos_v160(uuid) from public, anon, authenticated;
grant execute on function public.app_diagnostico_recibos_v160(uuid) to service_role, postgres;

notify pgrst, 'reload schema';
commit;
