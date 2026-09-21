-- KOMBAX RC13 build 20079 · Finanzas Premium 2.0 · backend foundation
-- Additive, feature-flagged and rollback-friendly. No historical finance row is rewritten.
-- Base: RC13 / 20078 (20077 financial contracts preserved).

begin;

-- ---------------------------------------------------------------------------
-- 0) Safety preconditions
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.cuotas') is null
     or to_regclass('public.pagos') is null
     or to_regclass('public.recibos_cuota') is null
     or to_regclass('public.config_club') is null
     or to_regclass('public.socios') is null
     or to_regclass('public.socio_disciplinas') is null then
    raise exception 'FINANCE_V2_143_BASE_CONTRACT_MISSING';
  end if;
  if to_regprocedure('public.tiene_rol_club(uuid,public.rol_club[])') is null then
    raise exception 'FINANCE_V2_143_ROLE_HELPER_MISSING';
  end if;
end
$$;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 1) Feature flags: OFF by default for every club.
-- Existing config_club remains the single club configuration source.
-- ---------------------------------------------------------------------------
insert into public.config_club(club_id,clave,valor,descripcion,editable_por)
select c.id, f.clave, 'false'::jsonb, f.descripcion, 'direccion'::public.rol_club
from public.clubes c
cross join (values
  ('finance_v2_enabled','Finanzas Premium 2.0 habilitado para el club'),
  ('finance_dashboard_v2_enabled','Dashboard Finanzas Premium 2.0 habilitado'),
  ('finance_recurring_enabled','Generación automática recurrente habilitada'),
  ('finance_reports_enabled','Informes financieros Premium 2.0 habilitados')
) as f(clave,descripcion)
on conflict(club_id,clave) do nothing;

-- ---------------------------------------------------------------------------
-- 2) Rules / automation
-- ---------------------------------------------------------------------------
create table if not exists public.reglas_cobro (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  tarifa_id uuid,
  nombre text not null,
  concepto text not null,
  categoria text not null default 'cuota'
    check (categoria in ('cuota','matricula','licencia','material','competicion','evento','desplazamiento','otro')),
  importe numeric(10,2) not null check (importe >= 0),
  periodicidad text not null default 'mensual'
    check (periodicidad in ('mensual','trimestral','semestral','anual','unica')),
  fecha_inicio date not null,
  fecha_fin date,
  dia_generacion smallint not null default 1 check (dia_generacion between 1 and 28),
  dia_vencimiento smallint not null default 10 check (dia_vencimiento between 1 and 28),
  zona_horaria text not null default 'Europe/Madrid',
  politica_alta text not null default 'siguiente_ciclo'
    check (politica_alta in ('siguiente_ciclo','manual_ciclo_actual_completo')),
  prorrateo_modo text not null default 'ninguno'
    check (prorrateo_modo='ninguno'),
  activa boolean not null default true,
  metadatos jsonb not null default '{}'::jsonb,
  creada_por uuid references public.perfiles(id),
  creado_en timestamptz not null default now(),
  actualizado_por uuid references public.perfiles(id),
  actualizado_en timestamptz not null default now(),
  foreign key (club_id,tarifa_id) references public.tarifas(club_id,id) on delete set null,
  unique(club_id,id),
  check (fecha_fin is null or fecha_fin >= fecha_inicio),
  check (categoria <> 'otro' or length(trim(concepto)) > 0)
);
create index if not exists idx_reglas_cobro_club_activa_v143
  on public.reglas_cobro(club_id,activa,fecha_inicio,fecha_fin);
create index if not exists idx_reglas_cobro_tarifa_v143
  on public.reglas_cobro(club_id,tarifa_id) where tarifa_id is not null;

create table if not exists public.reglas_cobro_destinatarios (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  regla_id uuid not null,
  tipo text not null check (tipo in ('socio','grupo','disciplina','todos_activos')),
  socio_id uuid,
  grupo_id uuid,
  disciplina_id uuid,
  creado_por uuid references public.perfiles(id),
  creado_en timestamptz not null default now(),
  foreign key (club_id,regla_id) references public.reglas_cobro(club_id,id) on delete cascade,
  foreign key (club_id,socio_id) references public.socios(club_id,id) on delete cascade,
  foreign key (club_id,grupo_id) references public.grupos(club_id,id) on delete cascade,
  foreign key (club_id,disciplina_id) references public.disciplinas(club_id,id) on delete cascade,
  check (
    (tipo='socio' and socio_id is not null and grupo_id is null and disciplina_id is null)
    or (tipo='grupo' and socio_id is null and grupo_id is not null and disciplina_id is null)
    or (tipo='disciplina' and socio_id is null and grupo_id is null and disciplina_id is not null)
    or (tipo='todos_activos' and socio_id is null and grupo_id is null and disciplina_id is null)
  )
);
create unique index if not exists uq_regla_destino_scope_v143
  on public.reglas_cobro_destinatarios(
    club_id,regla_id,tipo,
    coalesce(socio_id,'00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(grupo_id,'00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(disciplina_id,'00000000-0000-0000-0000-000000000000'::uuid)
  );
create index if not exists idx_regla_destino_regla_v143
  on public.reglas_cobro_destinatarios(club_id,regla_id,tipo);

create table if not exists public.reglas_cobro_excepciones (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  regla_id uuid not null,
  socio_id uuid not null,
  tipo text not null
    check (tipo in ('excluir','exento','pausa','bonificacion','importe_personalizado','omitir_ciclo')),
  fecha_inicio date,
  fecha_fin date,
  ciclo_clave text,
  bonificacion_porcentaje numeric(5,2)
    check (bonificacion_porcentaje is null or (bonificacion_porcentaje >= 0 and bonificacion_porcentaje <= 100)),
  bonificacion_importe numeric(10,2)
    check (bonificacion_importe is null or bonificacion_importe >= 0),
  importe_personalizado numeric(10,2)
    check (importe_personalizado is null or importe_personalizado >= 0),
  motivo text not null,
  activa boolean not null default true,
  creada_por uuid references public.perfiles(id),
  creado_en timestamptz not null default now(),
  actualizado_por uuid references public.perfiles(id),
  actualizado_en timestamptz not null default now(),
  foreign key (club_id,regla_id) references public.reglas_cobro(club_id,id) on delete cascade,
  foreign key (club_id,socio_id) references public.socios(club_id,id) on delete cascade,
  check (fecha_fin is null or fecha_inicio is null or fecha_fin >= fecha_inicio),
  check (tipo <> 'importe_personalizado' or importe_personalizado is not null),
  check (tipo <> 'bonificacion' or bonificacion_porcentaje is not null or bonificacion_importe is not null),
  check (tipo <> 'omitir_ciclo' or ciclo_clave is not null)
);
create index if not exists idx_regla_excepciones_lookup_v143
  on public.reglas_cobro_excepciones(club_id,regla_id,socio_id,activa,fecha_inicio,fecha_fin);
create unique index if not exists uq_regla_excepcion_ciclo_v143
  on public.reglas_cobro_excepciones(club_id,regla_id,socio_id,tipo,ciclo_clave)
  where activa and ciclo_clave is not null;

create table if not exists public.reglas_cobro_ejecuciones (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null default gen_random_uuid() unique,
  club_id uuid not null references public.clubes(id) on delete cascade,
  fecha_proceso date not null,
  modo text not null check (modo in ('scheduler','manual','shadow')),
  shadow boolean not null default true,
  estado text not null default 'iniciada' check (estado in ('iniciada','completada','parcial','error')),
  solicitada_por uuid references public.perfiles(id),
  iniciado_en timestamptz not null default now(),
  finalizado_en timestamptz,
  estadisticas jsonb not null default '{}'::jsonb,
  errores jsonb not null default '[]'::jsonb
);
create index if not exists idx_reglas_ejecuciones_club_fecha_v143
  on public.reglas_cobro_ejecuciones(club_id,fecha_proceso desc,iniciado_en desc);

-- ---------------------------------------------------------------------------
-- 3) Additive charge metadata. Existing rows are untouched.
-- ---------------------------------------------------------------------------
alter table public.cuotas add column if not exists regla_cobro_id uuid;
alter table public.cuotas add column if not exists categoria_financiera text;
alter table public.cuotas add column if not exists ciclo_clave text;
alter table public.cuotas add column if not exists generacion_clave text;
alter table public.cuotas add column if not exists generado_automaticamente boolean not null default false;
alter table public.cuotas add column if not exists generado_por_ejecucion_id uuid;
alter table public.cuotas add column if not exists snapshot_regla jsonb;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname='fk_cuotas_regla_cobro_v143' and conrelid='public.cuotas'::regclass
  ) then
    alter table public.cuotas
      add constraint fk_cuotas_regla_cobro_v143
      foreign key (club_id,regla_cobro_id)
      references public.reglas_cobro(club_id,id) on delete set null;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname='fk_cuotas_ejecucion_v143' and conrelid='public.cuotas'::regclass
  ) then
    alter table public.cuotas
      add constraint fk_cuotas_ejecucion_v143
      foreign key (generado_por_ejecucion_id)
      references public.reglas_cobro_ejecuciones(id) on delete set null;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname='ck_cuotas_categoria_financiera_v143' and conrelid='public.cuotas'::regclass
  ) then
    alter table public.cuotas add constraint ck_cuotas_categoria_financiera_v143
      check (categoria_financiera is null or categoria_financiera in
        ('cuota','matricula','licencia','material','competicion','evento','desplazamiento','otro'));
  end if;
end
$$;

-- Sacred invariant: one generated charge per club + rule + student + cycle.
create unique index if not exists uq_cuota_regla_socio_ciclo_v143
  on public.cuotas(club_id,regla_cobro_id,socio_id,ciclo_clave)
  where regla_cobro_id is not null and ciclo_clave is not null;
create unique index if not exists uq_cuota_generacion_clave_v143
  on public.cuotas(generacion_clave)
  where generacion_clave is not null;
create index if not exists idx_cuotas_regla_v143
  on public.cuotas(club_id,regla_cobro_id,periodo)
  where regla_cobro_id is not null;
create index if not exists idx_cuotas_categoria_v143
  on public.cuotas(club_id,categoria_financiera,estado,vencimiento)
  where categoria_financiera is not null;

-- ---------------------------------------------------------------------------
-- 4) RLS and grants. Reads are scoped; writes go through an authoritative RPC.
-- ---------------------------------------------------------------------------
alter table public.reglas_cobro enable row level security;
alter table public.reglas_cobro_destinatarios enable row level security;
alter table public.reglas_cobro_excepciones enable row level security;
alter table public.reglas_cobro_ejecuciones enable row level security;

drop policy if exists reglas_cobro_lectura_v143 on public.reglas_cobro;
create policy reglas_cobro_lectura_v143 on public.reglas_cobro
for select to authenticated
using (public.tiene_rol_club(club_id,'direccion','secretaria','economia'));

drop policy if exists reglas_cobro_dest_lectura_v143 on public.reglas_cobro_destinatarios;
create policy reglas_cobro_dest_lectura_v143 on public.reglas_cobro_destinatarios
for select to authenticated
using (public.tiene_rol_club(club_id,'direccion','secretaria','economia'));

drop policy if exists reglas_cobro_exc_lectura_v143 on public.reglas_cobro_excepciones;
create policy reglas_cobro_exc_lectura_v143 on public.reglas_cobro_excepciones
for select to authenticated
using (public.tiene_rol_club(club_id,'direccion','secretaria','economia'));

drop policy if exists reglas_cobro_exec_lectura_v143 on public.reglas_cobro_ejecuciones;
create policy reglas_cobro_exec_lectura_v143 on public.reglas_cobro_ejecuciones
for select to authenticated
using (public.tiene_rol_club(club_id,'direccion','economia'));

revoke all on public.reglas_cobro, public.reglas_cobro_destinatarios,
  public.reglas_cobro_excepciones, public.reglas_cobro_ejecuciones
from public,anon,authenticated;
grant select on public.reglas_cobro, public.reglas_cobro_destinatarios,
  public.reglas_cobro_excepciones, public.reglas_cobro_ejecuciones
to authenticated;
grant all on public.reglas_cobro, public.reglas_cobro_destinatarios,
  public.reglas_cobro_excepciones, public.reglas_cobro_ejecuciones
to service_role;

-- ---------------------------------------------------------------------------
-- 5) Internal helpers
-- ---------------------------------------------------------------------------
create or replace function private.finance_flag_v143(p_club_id uuid,p_key text)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select coalesce(
    (
      select lower(trim(both '"' from c.valor::text)) in ('true','1','si','sí','yes')
      from public.config_club c
      where c.club_id=p_club_id and c.clave=p_key
      limit 1
    ),
    false
  );
$$;
revoke all on function private.finance_flag_v143(uuid,text) from public,anon,authenticated;

create or replace function private.finance_cycle_v143(
  p_regla_id uuid,
  p_fecha date,
  p_forzar_ciclo_actual boolean default false
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  r public.reglas_cobro;
  v_cycle date;
  v_start_month date;
  v_month_diff integer;
  v_step integer;
  v_generation date;
  v_due date;
  v_due_ok boolean:=false;
  v_key text;
begin
  select * into r from public.reglas_cobro where id=p_regla_id;
  if r.id is null or not r.activa then
    return jsonb_build_object('corresponde',false,'motivo','regla_inactiva');
  end if;
  if p_fecha < r.fecha_inicio or (r.fecha_fin is not null and p_fecha > r.fecha_fin) then
    return jsonb_build_object('corresponde',false,'motivo','fuera_vigencia');
  end if;

  if r.periodicidad='unica' then
    v_cycle:=r.fecha_inicio;
    v_generation:=r.fecha_inicio;
    v_due:=greatest(r.fecha_inicio,(date_trunc('month',r.fecha_inicio)::date + (r.dia_vencimiento-1)));
    v_key:=to_char(v_cycle,'YYYY-MM-DD');
    v_due_ok:=p_fecha>=v_generation;
  else
    v_cycle:=date_trunc('month',p_fecha)::date;
    v_start_month:=date_trunc('month',r.fecha_inicio)::date;
    v_step:=case r.periodicidad
      when 'mensual' then 1
      when 'trimestral' then 3
      when 'semestral' then 6
      when 'anual' then 12
      else 1 end;
    v_month_diff:=(extract(year from v_cycle)::int*12+extract(month from v_cycle)::int)
      -(extract(year from v_start_month)::int*12+extract(month from v_start_month)::int);

    if v_month_diff<0 or mod(v_month_diff,v_step)<>0 then
      return jsonb_build_object('corresponde',false,'motivo','fuera_cadencia');
    end if;

    -- A rule that starts mid-cycle defaults to the next full cycle.
    if not p_forzar_ciclo_actual and v_cycle=v_start_month and r.fecha_inicio>v_cycle then
      return jsonb_build_object('corresponde',false,'motivo','alta_intermedia_siguiente_ciclo');
    end if;

    v_generation:=v_cycle+(r.dia_generacion-1);
    v_due:=v_cycle+(r.dia_vencimiento-1);
    v_key:=to_char(v_cycle,'YYYY-MM');
    v_due_ok:=p_forzar_ciclo_actual or p_fecha>=greatest(v_generation,r.fecha_inicio);
  end if;

  if r.fecha_fin is not null and v_cycle>r.fecha_fin then
    return jsonb_build_object('corresponde',false,'motivo','regla_finalizada');
  end if;

  return jsonb_build_object(
    'corresponde',v_due_ok,
    'ciclo',v_cycle,
    'ciclo_clave',v_key,
    'generacion',v_generation,
    'vencimiento',v_due,
    'motivo',case when v_due_ok then 'ok' else 'aun_no_corresponde' end
  );
end
$$;
revoke all on function private.finance_cycle_v143(uuid,date,boolean) from public,anon,authenticated;

create or replace function private.finance_recipients_v143(
  p_regla_id uuid,
  p_ciclo date,
  p_ciclo_clave text,
  p_forzar_ciclo_actual boolean default false
)
returns table(
  socio_id uuid,
  importe_final numeric(10,2),
  excepcion_aplicada text
)
language sql
stable
security definer
set search_path=''
as $$
with rule as (
  select r.* from public.reglas_cobro r where r.id=p_regla_id and r.activa
),
scope_members as (
  select d.club_id,d.regla_id,s.id as socio_id
  from public.reglas_cobro_destinatarios d
  join rule r on r.id=d.regla_id and r.club_id=d.club_id
  join public.socios s on s.club_id=d.club_id and s.id=d.socio_id
  where d.tipo='socio'

  union all

  select d.club_id,d.regla_id,sd.socio_id
  from public.reglas_cobro_destinatarios d
  join rule r on r.id=d.regla_id and r.club_id=d.club_id
  join public.socio_disciplinas sd
    on sd.club_id=d.club_id and sd.grupo_id=d.grupo_id
  where d.tipo='grupo'
    and sd.activa
    and (p_forzar_ciclo_actual or sd.fecha_inicio<=p_ciclo)
    and (sd.fecha_fin is null or sd.fecha_fin>=p_ciclo)

  union all

  select d.club_id,d.regla_id,sd.socio_id
  from public.reglas_cobro_destinatarios d
  join rule r on r.id=d.regla_id and r.club_id=d.club_id
  join public.socio_disciplinas sd
    on sd.club_id=d.club_id and sd.disciplina_id=d.disciplina_id
  where d.tipo='disciplina'
    and sd.activa
    and (p_forzar_ciclo_actual or sd.fecha_inicio<=p_ciclo)
    and (sd.fecha_fin is null or sd.fecha_fin>=p_ciclo)

  union all

  select d.club_id,d.regla_id,s.id
  from public.reglas_cobro_destinatarios d
  join rule r on r.id=d.regla_id and r.club_id=d.club_id
  join public.socios s on s.club_id=d.club_id
  where d.tipo='todos_activos'
),
dedup as (
  select distinct m.club_id,m.regla_id,m.socio_id
  from scope_members m
),
eligible as (
  select d.*,s.fecha_alta,s.estado
  from dedup d
  join public.socios s on s.club_id=d.club_id and s.id=d.socio_id
  where s.estado='activo'
    and (p_forzar_ciclo_actual or s.fecha_alta<=p_ciclo)
),
effective as (
  select e.*,
    exists(
      select 1 from public.reglas_cobro_excepciones x
      where x.club_id=e.club_id and x.regla_id=e.regla_id and x.socio_id=e.socio_id and x.activa
        and (x.fecha_inicio is null or x.fecha_inicio<=p_ciclo)
        and (x.fecha_fin is null or x.fecha_fin>=p_ciclo)
        and (
          x.tipo in ('excluir','exento','pausa')
          or (x.tipo='omitir_ciclo' and x.ciclo_clave=p_ciclo_clave)
        )
    ) as bloqueado,
    (
      select x.importe_personalizado
      from public.reglas_cobro_excepciones x
      where x.club_id=e.club_id and x.regla_id=e.regla_id and x.socio_id=e.socio_id
        and x.activa and x.tipo='importe_personalizado'
        and (x.fecha_inicio is null or x.fecha_inicio<=p_ciclo)
        and (x.fecha_fin is null or x.fecha_fin>=p_ciclo)
      order by x.actualizado_en desc,x.creado_en desc limit 1
    ) as importe_personalizado,
    coalesce((
      select sum(coalesce(x.bonificacion_importe,0))
      from public.reglas_cobro_excepciones x
      where x.club_id=e.club_id and x.regla_id=e.regla_id and x.socio_id=e.socio_id
        and x.activa and x.tipo='bonificacion'
        and (x.fecha_inicio is null or x.fecha_inicio<=p_ciclo)
        and (x.fecha_fin is null or x.fecha_fin>=p_ciclo)
    ),0) as bonificacion_importe,
    coalesce((
      select sum(coalesce(x.bonificacion_porcentaje,0))
      from public.reglas_cobro_excepciones x
      where x.club_id=e.club_id and x.regla_id=e.regla_id and x.socio_id=e.socio_id
        and x.activa and x.tipo='bonificacion'
        and (x.fecha_inicio is null or x.fecha_inicio<=p_ciclo)
        and (x.fecha_fin is null or x.fecha_fin>=p_ciclo)
    ),0) as bonificacion_porcentaje
  from eligible e
)
select
  e.socio_id,
  greatest(
    0::numeric,
    round(
      (
        coalesce(e.importe_personalizado,r.importe)
        - e.bonificacion_importe
      ) * (1-greatest(0,least(100,e.bonificacion_porcentaje))/100.0),
      2
    )
  )::numeric(10,2) as importe_final,
  case
    when e.importe_personalizado is not null then 'importe_personalizado'
    when e.bonificacion_importe>0 or e.bonificacion_porcentaje>0 then 'bonificacion'
    else null end as excepcion_aplicada
from effective e
join rule r on r.id=e.regla_id and r.club_id=e.club_id
where not e.bloqueado;
$$;
revoke all on function private.finance_recipients_v143(uuid,date,text,boolean) from public,anon,authenticated;

-- ---------------------------------------------------------------------------
-- 6) Public read APIs: flags and mandatory preview.
-- ---------------------------------------------------------------------------
create or replace function public.app_finance_v2_flags_v143(p_club_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if auth.uid() is null or not public.es_miembro_club(p_club_id) then
    raise exception 'FINANCE_V2_MEMBERSHIP_REQUIRED';
  end if;
  return jsonb_build_object(
    'finance_v2_enabled',private.finance_flag_v143(p_club_id,'finance_v2_enabled'),
    'finance_dashboard_v2_enabled',private.finance_flag_v143(p_club_id,'finance_dashboard_v2_enabled'),
    'finance_recurring_enabled',private.finance_flag_v143(p_club_id,'finance_recurring_enabled'),
    'finance_reports_enabled',private.finance_flag_v143(p_club_id,'finance_reports_enabled')
  );
end
$$;
revoke all on function public.app_finance_v2_flags_v143(uuid) from public,anon;
grant execute on function public.app_finance_v2_flags_v143(uuid) to authenticated;

create or replace function public.app_finance_v2_preview_regla_v143(
  p_regla_id uuid,
  p_fecha date default current_date,
  p_forzar_ciclo_actual boolean default false
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  r public.reglas_cobro;
  v_cycle jsonb;
  v_ciclo date;
  v_key text;
  v_due date;
  v_count integer:=0;
  v_total numeric(12,2):=0;
  v_rows jsonb:='[]'::jsonb;
begin
  select * into r from public.reglas_cobro where id=p_regla_id;
  if r.id is null then raise exception 'FINANCE_V2_RULE_NOT_FOUND'; end if;
  if auth.uid() is null or not public.tiene_rol_club(r.club_id,'direccion','secretaria','economia') then
    raise exception 'FINANCE_V2_PREVIEW_FORBIDDEN';
  end if;

  v_cycle:=private.finance_cycle_v143(r.id,coalesce(p_fecha,current_date),p_forzar_ciclo_actual);
  if not coalesce((v_cycle->>'corresponde')::boolean,false) then
    return jsonb_build_object(
      'ok',true,'shadow',true,'regla_id',r.id,'club_id',r.club_id,
      'corresponde',false,'motivo',v_cycle->>'motivo','cargos',0,'total',0,'destinatarios','[]'::jsonb
    );
  end if;

  v_ciclo:=(v_cycle->>'ciclo')::date;
  v_key:=v_cycle->>'ciclo_clave';
  v_due:=(v_cycle->>'vencimiento')::date;

  select count(*),coalesce(sum(x.importe_final),0),
    coalesce(jsonb_agg(jsonb_build_object(
      'socio_id',x.socio_id,
      'importe',x.importe_final,
      'concepto',r.concepto,
      'categoria',r.categoria,
      'periodo',v_ciclo,
      'vencimiento',v_due,
      'excepcion',x.excepcion_aplicada
    ) order by x.socio_id),'[]'::jsonb)
  into v_count,v_total,v_rows
  from private.finance_recipients_v143(r.id,v_ciclo,v_key,p_forzar_ciclo_actual) x;

  return jsonb_build_object(
    'ok',true,'shadow',true,'regla_id',r.id,'club_id',r.club_id,
    'corresponde',true,'ciclo',v_ciclo,'ciclo_clave',v_key,'vencimiento',v_due,
    'cargos',v_count,'total',v_total,'destinatarios',v_rows
  );
end
$$;
revoke all on function public.app_finance_v2_preview_regla_v143(uuid,date,boolean) from public,anon;
grant execute on function public.app_finance_v2_preview_regla_v143(uuid,date,boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 7) Authoritative idempotent recurring engine.
-- The Edge worker calls this with service_role. Managers may call it manually.
-- ---------------------------------------------------------------------------
create or replace function public.procesar_cargos_recurrentes(
  p_fecha date default current_date,
  p_club_id uuid default null,
  p_shadow boolean default true,
  p_forzar_ciclo_actual boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_service boolean:=coalesce(auth.jwt()->>'role',current_setting('request.jwt.claim.role',true),'')='service_role';
  v_club public.clubes;
  r public.reglas_cobro;
  x record;
  v_exec uuid;
  v_request uuid:=gen_random_uuid();
  v_cycle jsonb;
  v_ciclo date;
  v_key text;
  v_due date;
  v_generation_key text;
  v_inserted integer:=0;
  v_existing integer:=0;
  v_preview integer:=0;
  v_rules integer:=0;
  v_errors integer:=0;
  v_total numeric(14,2):=0;
  v_error_rows jsonb:='[]'::jsonb;
  v_preview_rows jsonb:='[]'::jsonb;
  v_created_id uuid;
  v_mode text;
begin
  if p_club_id is null then
    raise exception 'FINANCE_V2_CLUB_REQUIRED';
  end if;

  if not v_service then
    if v_uid is null or not public.tiene_rol_club(p_club_id,'direccion','economia') then
      raise exception 'FINANCE_V2_PROCESS_FORBIDDEN';
    end if;
  end if;

  select * into v_club from public.clubes where id=p_club_id and activo;
  if v_club.id is null then raise exception 'FINANCE_V2_CLUB_NOT_FOUND'; end if;

  -- Shadow preview is allowed before activation. Real writes are flag gated.
  if not p_shadow then
    if not private.finance_flag_v143(p_club_id,'finance_v2_enabled') then
      return jsonb_build_object('ok',true,'disabled',true,'reason','finance_v2_enabled=false','club_id',p_club_id);
    end if;
    if v_service and not private.finance_flag_v143(p_club_id,'finance_recurring_enabled') then
      return jsonb_build_object('ok',true,'disabled',true,'reason','finance_recurring_enabled=false','club_id',p_club_id);
    end if;
  end if;

  v_mode:=case when p_shadow then 'shadow' when v_service then 'scheduler' else 'manual' end;

  insert into public.reglas_cobro_ejecuciones(
    request_id,club_id,fecha_proceso,modo,shadow,estado,solicitada_por
  ) values (
    v_request,p_club_id,coalesce(p_fecha,current_date),v_mode,p_shadow,'iniciada',v_uid
  ) returning id into v_exec;

  for r in
    select *
    from public.reglas_cobro
    where club_id=p_club_id and activa
      and fecha_inicio<=coalesce(p_fecha,current_date)
      and (fecha_fin is null or fecha_fin>=date_trunc('month',coalesce(p_fecha,current_date))::date)
    order by creado_en,id
  loop
    begin
      v_cycle:=private.finance_cycle_v143(r.id,coalesce(p_fecha,current_date),p_forzar_ciclo_actual);
      if not coalesce((v_cycle->>'corresponde')::boolean,false) then
        continue;
      end if;
      v_rules:=v_rules+1;
      v_ciclo:=(v_cycle->>'ciclo')::date;
      v_key:=v_cycle->>'ciclo_clave';
      v_due:=(v_cycle->>'vencimiento')::date;

      for x in
        select *
        from private.finance_recipients_v143(r.id,v_ciclo,v_key,p_forzar_ciclo_actual)
      loop
        v_generation_key:=p_club_id::text||':'||r.id::text||':'||x.socio_id::text||':'||v_key;
        if p_shadow then
          v_preview:=v_preview+1;
          v_total:=v_total+x.importe_final;
          if jsonb_array_length(v_preview_rows)<250 then
            v_preview_rows:=v_preview_rows||jsonb_build_array(jsonb_build_object(
              'regla_id',r.id,'socio_id',x.socio_id,'concepto',r.concepto,
              'categoria',r.categoria,'importe',x.importe_final,'periodo',v_ciclo,
              'vencimiento',v_due,'ciclo_clave',v_key,'excepcion',x.excepcion_aplicada
            ));
          end if;
          continue;
        end if;

        v_created_id:=null;
        insert into public.cuotas(
          club_id,socio_id,tarifa_id,periodo,concepto,concepto_publico,importe,vencimiento,estado,
          origen,regla_cobro_id,categoria_financiera,ciclo_clave,generacion_clave,
          generado_automaticamente,generado_por_ejecucion_id,snapshot_regla
        ) values (
          p_club_id,x.socio_id,r.tarifa_id,v_ciclo,r.concepto,r.concepto,x.importe_final,v_due,'pendiente',
          'cuota',r.id,r.categoria,v_key,v_generation_key,
          true,v_exec,jsonb_build_object(
            'regla_id',r.id,'nombre',r.nombre,'concepto',r.concepto,'categoria',r.categoria,
            'importe_base',r.importe,'periodicidad',r.periodicidad,'ciclo_clave',v_key,
            'zona_horaria',r.zona_horaria,'ejecutado_en',now()
          )
        )
        on conflict do nothing
        returning id into v_created_id;

        if v_created_id is null then
          v_existing:=v_existing+1;
        else
          v_inserted:=v_inserted+1;
          v_total:=v_total+x.importe_final;
        end if;
      end loop;
    exception when others then
      v_errors:=v_errors+1;
      v_error_rows:=v_error_rows||jsonb_build_array(jsonb_build_object(
        'regla_id',r.id,'sqlstate',sqlstate,'error',left(sqlerrm,500)
      ));
    end;
  end loop;

  if not p_shadow and v_inserted>0 then
    -- Reuse the existing notification/push pipeline. One notification per affected profile.
    insert into public.notificaciones(
      club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
    )
    select
      q.club_id,
      coalesce(s.perfil_id,t.tutor_perfil_id),
      'finance-v2-cargos-'||v_exec::text||'-'||coalesce(s.perfil_id,t.tutor_perfil_id)::text,
      'cuota',
      'Actualización de pagos',
      case when count(*)=1 then 'Tienes un nuevo cargo del club.'
           else 'Tienes '||count(*)::text||' nuevos cargos del club.' end,
      'fees',
      jsonb_build_object(
        'requiere_accion',true,
        'finance_v2',true,
        'ejecucion_id',v_exec,
        'cantidad',count(*),
        'cuota_ids',jsonb_agg(q.id)
      ),
      null
    from public.cuotas q
    join public.socios s on s.club_id=q.club_id and s.id=q.socio_id
    left join lateral (
      select ts.tutor_perfil_id
      from public.tutores_socios ts
      where ts.club_id=s.club_id and ts.socio_id=s.id and ts.contacto_principal
      order by ts.id limit 1
    ) t on true
    where q.generado_por_ejecucion_id=v_exec
      and coalesce(s.perfil_id,t.tutor_perfil_id) is not null
    group by q.club_id,coalesce(s.perfil_id,t.tutor_perfil_id)
    on conflict (club_id,perfil_id,clave)
      where clave is not null and perfil_id is not null
    do nothing;

    -- Treasury notification is role-scoped; the existing dispatcher resolves recipients.
    insert into public.notificaciones(
      club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por
    ) values (
      p_club_id,'economia','finance-v2-ejecucion-'||v_exec::text,'cuota',
      'Automatización financiera',
      'La automatización financiera ha generado '||v_inserted::text||' cargos.',
      'fees',
      jsonb_build_object('finance_v2',true,'ejecucion_id',v_exec,'cantidad',v_inserted,'requiere_accion',false),
      v_uid
    );
  end if;

  update public.reglas_cobro_ejecuciones
  set estado=case when v_errors>0 then 'parcial' else 'completada' end,
      finalizado_en=now(),
      estadisticas=jsonb_build_object(
        'reglas_procesadas',v_rules,
        'cargos_creados',v_inserted,
        'cargos_existentes',v_existing,
        'cargos_simulados',v_preview,
        'importe_total',v_total,
        'preview_truncado',v_preview>250
      ),
      errores=v_error_rows
  where id=v_exec;

  return jsonb_build_object(
    'ok',v_errors=0,
    'shadow',p_shadow,
    'club_id',p_club_id,
    'fecha',coalesce(p_fecha,current_date),
    'ejecucion_id',v_exec,
    'reglas_procesadas',v_rules,
    'cargos_creados',v_inserted,
    'cargos_existentes',v_existing,
    'cargos_simulados',v_preview,
    'importe_total',v_total,
    'errores',v_error_rows,
    'preview',v_preview_rows
  );
exception when others then
  if v_exec is not null then
    update public.reglas_cobro_ejecuciones
    set estado='error',finalizado_en=now(),
        errores=jsonb_build_array(jsonb_build_object('sqlstate',sqlstate,'error',left(sqlerrm,500)))
    where id=v_exec;
  end if;
  raise;
end
$$;
revoke all on function public.procesar_cargos_recurrentes(date,uuid,boolean,boolean) from public,anon;
grant execute on function public.procesar_cargos_recurrentes(date,uuid,boolean,boolean) to authenticated,service_role;

-- ---------------------------------------------------------------------------
-- 8) Preserve the single gateway / mutation-request contract.
-- Finance writes are routed through app_mutate_v160 and share request idempotency.
-- ---------------------------------------------------------------------------
create or replace function private.finance_mutate_v143(
  p_operation text,
  p_payload jsonb,
  p_club uuid,
  p_uid uuid
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_rule uuid;
  v_id uuid;
  v_result jsonb;
  v_target text;
begin
  if p_operation='finance.regla.guardar' then
    begin v_rule:=nullif(v_payload->>'id','')::uuid; exception when others then raise exception 'FINANCE_V2_RULE_ID_INVALID'; end;
    if v_rule is null then
      insert into public.reglas_cobro(
        club_id,tarifa_id,nombre,concepto,categoria,importe,periodicidad,fecha_inicio,fecha_fin,
        dia_generacion,dia_vencimiento,zona_horaria,activa,creada_por,actualizado_por
      ) values (
        p_club,nullif(v_payload->>'tarifa_id','')::uuid,trim(v_payload->>'nombre'),trim(v_payload->>'concepto'),
        coalesce(nullif(v_payload->>'categoria',''),'cuota'),coalesce((v_payload->>'importe')::numeric,0),
        coalesce(nullif(v_payload->>'periodicidad',''),'mensual'),(v_payload->>'fecha_inicio')::date,
        nullif(v_payload->>'fecha_fin','')::date,coalesce((v_payload->>'dia_generacion')::smallint,1),
        coalesce((v_payload->>'dia_vencimiento')::smallint,10),
        coalesce(nullif(v_payload->>'zona_horaria',''),'Europe/Madrid'),
        coalesce((v_payload->>'activa')::boolean,true),p_uid,p_uid
      ) returning id into v_rule;
    else
      update public.reglas_cobro r set
        tarifa_id=case when v_payload ? 'tarifa_id' then nullif(v_payload->>'tarifa_id','')::uuid else r.tarifa_id end,
        nombre=coalesce(nullif(trim(v_payload->>'nombre'),''),r.nombre),
        concepto=coalesce(nullif(trim(v_payload->>'concepto'),''),r.concepto),
        categoria=coalesce(nullif(v_payload->>'categoria',''),r.categoria),
        importe=coalesce((v_payload->>'importe')::numeric,r.importe),
        periodicidad=coalesce(nullif(v_payload->>'periodicidad',''),r.periodicidad),
        fecha_inicio=coalesce(nullif(v_payload->>'fecha_inicio','')::date,r.fecha_inicio),
        fecha_fin=case when v_payload ? 'fecha_fin' then nullif(v_payload->>'fecha_fin','')::date else r.fecha_fin end,
        dia_generacion=coalesce((v_payload->>'dia_generacion')::smallint,r.dia_generacion),
        dia_vencimiento=coalesce((v_payload->>'dia_vencimiento')::smallint,r.dia_vencimiento),
        zona_horaria=coalesce(nullif(v_payload->>'zona_horaria',''),r.zona_horaria),
        activa=coalesce((v_payload->>'activa')::boolean,r.activa),
        actualizado_por=p_uid,actualizado_en=now()
      where r.id=v_rule and r.club_id=p_club;
      if not found then raise exception 'FINANCE_V2_RULE_NOT_FOUND'; end if;
    end if;
    v_result:=jsonb_build_object('regla_id',v_rule);

  elsif p_operation='finance.destinatario.añadir' then
    begin v_rule:=(v_payload->>'regla_id')::uuid; exception when others then raise exception 'FINANCE_V2_RULE_ID_INVALID'; end;
    if not exists(select 1 from public.reglas_cobro where id=v_rule and club_id=p_club) then raise exception 'FINANCE_V2_RULE_NOT_FOUND'; end if;
    v_target:=v_payload->>'tipo';
    insert into public.reglas_cobro_destinatarios(
      club_id,regla_id,tipo,socio_id,grupo_id,disciplina_id,creado_por
    ) values (
      p_club,v_rule,v_target,
      case when v_target='socio' then nullif(v_payload->>'socio_id','')::uuid else null end,
      case when v_target='grupo' then nullif(v_payload->>'grupo_id','')::uuid else null end,
      case when v_target='disciplina' then nullif(v_payload->>'disciplina_id','')::uuid else null end,
      p_uid
    )
    on conflict do nothing
    returning id into v_id;
    v_result:=jsonb_build_object('regla_id',v_rule,'destinatario_id',v_id,'deduplicado',v_id is null);

  elsif p_operation='finance.destinatario.eliminar' then
    begin v_id:=(v_payload->>'destinatario_id')::uuid; exception when others then raise exception 'FINANCE_V2_TARGET_ID_INVALID'; end;
    delete from public.reglas_cobro_destinatarios where id=v_id and club_id=p_club returning regla_id into v_rule;
    if v_rule is null then raise exception 'FINANCE_V2_TARGET_NOT_FOUND'; end if;
    v_result:=jsonb_build_object('destinatario_id',v_id,'eliminado',true);

  elsif p_operation='finance.excepcion.guardar' then
    begin v_rule:=(v_payload->>'regla_id')::uuid; exception when others then raise exception 'FINANCE_V2_RULE_ID_INVALID'; end;
    begin v_id:=nullif(v_payload->>'id','')::uuid; exception when others then raise exception 'FINANCE_V2_EXCEPTION_ID_INVALID'; end;
    if not exists(select 1 from public.reglas_cobro where id=v_rule and club_id=p_club) then raise exception 'FINANCE_V2_RULE_NOT_FOUND'; end if;
    if v_id is null then
      insert into public.reglas_cobro_excepciones(
        club_id,regla_id,socio_id,tipo,fecha_inicio,fecha_fin,ciclo_clave,
        bonificacion_porcentaje,bonificacion_importe,importe_personalizado,motivo,creada_por,actualizado_por
      ) values (
        p_club,v_rule,(v_payload->>'socio_id')::uuid,v_payload->>'tipo',
        nullif(v_payload->>'fecha_inicio','')::date,nullif(v_payload->>'fecha_fin','')::date,
        nullif(v_payload->>'ciclo_clave',''),nullif(v_payload->>'bonificacion_porcentaje','')::numeric,
        nullif(v_payload->>'bonificacion_importe','')::numeric,nullif(v_payload->>'importe_personalizado','')::numeric,
        coalesce(nullif(trim(v_payload->>'motivo'),''),'Excepción financiera'),p_uid,p_uid
      ) returning id into v_id;
    else
      update public.reglas_cobro_excepciones e set
        tipo=coalesce(nullif(v_payload->>'tipo',''),e.tipo),
        fecha_inicio=case when v_payload ? 'fecha_inicio' then nullif(v_payload->>'fecha_inicio','')::date else e.fecha_inicio end,
        fecha_fin=case when v_payload ? 'fecha_fin' then nullif(v_payload->>'fecha_fin','')::date else e.fecha_fin end,
        ciclo_clave=case when v_payload ? 'ciclo_clave' then nullif(v_payload->>'ciclo_clave','') else e.ciclo_clave end,
        bonificacion_porcentaje=case when v_payload ? 'bonificacion_porcentaje' then nullif(v_payload->>'bonificacion_porcentaje','')::numeric else e.bonificacion_porcentaje end,
        bonificacion_importe=case when v_payload ? 'bonificacion_importe' then nullif(v_payload->>'bonificacion_importe','')::numeric else e.bonificacion_importe end,
        importe_personalizado=case when v_payload ? 'importe_personalizado' then nullif(v_payload->>'importe_personalizado','')::numeric else e.importe_personalizado end,
        motivo=coalesce(nullif(trim(v_payload->>'motivo'),''),e.motivo),
        activa=coalesce((v_payload->>'activa')::boolean,e.activa),
        actualizado_por=p_uid,actualizado_en=now()
      where e.id=v_id and e.club_id=p_club and e.regla_id=v_rule;
      if not found then raise exception 'FINANCE_V2_EXCEPTION_NOT_FOUND'; end if;
    end if;
    v_result:=jsonb_build_object('excepcion_id',v_id,'regla_id',v_rule);

  elsif p_operation='finance.excepcion.desactivar' then
    begin v_id:=(v_payload->>'excepcion_id')::uuid; exception when others then raise exception 'FINANCE_V2_EXCEPTION_ID_INVALID'; end;
    update public.reglas_cobro_excepciones set activa=false,actualizado_por=p_uid,actualizado_en=now()
    where id=v_id and club_id=p_club returning regla_id into v_rule;
    if v_rule is null then raise exception 'FINANCE_V2_EXCEPTION_NOT_FOUND'; end if;
    v_result:=jsonb_build_object('excepcion_id',v_id,'activa',false);

  elsif p_operation='finance.flag.establecer' then
    if not public.tiene_rol_club(p_club,'direccion') then raise exception 'FINANCE_V2_FLAG_FORBIDDEN'; end if;
    if (v_payload->>'clave') not in (
      'finance_v2_enabled','finance_dashboard_v2_enabled','finance_recurring_enabled','finance_reports_enabled'
    ) then raise exception 'FINANCE_V2_FLAG_INVALID'; end if;
    insert into public.config_club(club_id,clave,valor,descripcion,editable_por,actualizado_en,actualizado_por)
    values(p_club,v_payload->>'clave',to_jsonb(coalesce((v_payload->>'valor')::boolean,false)),
      'Finanzas Premium 2.0 feature flag','direccion',now(),p_uid)
    on conflict(club_id,clave) do update
      set valor=excluded.valor,actualizado_en=now(),actualizado_por=p_uid;
    v_result:=jsonb_build_object('clave',v_payload->>'clave','valor',coalesce((v_payload->>'valor')::boolean,false));

  elsif p_operation='finance.cargos.procesar' then
    v_result:=public.procesar_cargos_recurrentes(
      coalesce(nullif(v_payload->>'fecha','')::date,current_date),
      p_club,
      coalesce((v_payload->>'shadow')::boolean,true),
      coalesce((v_payload->>'forzar_ciclo_actual')::boolean,false)
    );

  else
    raise exception 'FINANCE_V2_OPERATION_NOT_SUPPORTED';
  end if;

  insert into public.auditoria(club_id,usuario_id,accion,entidad,registro_id,datos_nuevos)
  values(p_club,p_uid,'FINANCE_V2_MUTATE',p_operation,coalesce(v_rule,v_id)::text,
    jsonb_build_object('payload',v_payload - array['observaciones']));

  return coalesce(v_result,'{}'::jsonb);
end
$$;
revoke all on function private.finance_mutate_v143(text,jsonb,uuid,uuid) from public,anon,authenticated;

do $contract$
begin
  if to_regprocedure('public.app_runtime_contract_v160_pre_finance_143(uuid)') is null then
    if to_regprocedure('public.app_runtime_contract_v160(uuid)') is null then
      raise exception 'FINANCE_V2_143_RUNTIME_CONTRACT_MISSING';
    end if;
    alter function public.app_runtime_contract_v160(uuid)
      rename to app_runtime_contract_v160_pre_finance_143;
  end if;
end
$contract$;
revoke all on function public.app_runtime_contract_v160_pre_finance_143(uuid) from public,anon,authenticated;

create or replace function public.app_runtime_contract_v160(p_club_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_base jsonb;
begin
  v_base:=public.app_runtime_contract_v160_pre_finance_143(p_club_id);
  return jsonb_set(
    v_base,
    '{operations}',
    coalesce(v_base->'operations','[]'::jsonb)||jsonb_build_array(
      'finance.regla.guardar',
      'finance.destinatario.añadir',
      'finance.destinatario.eliminar',
      'finance.excepcion.guardar',
      'finance.excepcion.desactivar',
      'finance.flag.establecer',
      'finance.cargos.procesar'
    ),
    true
  );
end
$$;
revoke all on function public.app_runtime_contract_v160(uuid) from public,anon;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;

do $gateway$
begin
  if to_regprocedure('public.app_mutate_v160_pre_finance_143(text,jsonb,uuid)') is null then
    if to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is null then
      raise exception 'FINANCE_V2_143_MUTATION_GATEWAY_MISSING';
    end if;
    alter function public.app_mutate_v160(text,jsonb,uuid)
      rename to app_mutate_v160_pre_finance_143;
  end if;
end
$gateway$;
revoke all on function public.app_mutate_v160_pre_finance_143(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(
  p_operation text,
  p_payload jsonb,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_club uuid;
  v_existing public.app_mutation_requests;
  v_data jsonb;
  v_result jsonb;
  v_backend_version text;
begin
  if p_operation not in (
    'finance.regla.guardar','finance.destinatario.añadir','finance.destinatario.eliminar',
    'finance.excepcion.guardar','finance.excepcion.desactivar','finance.flag.establecer',
    'finance.cargos.procesar'
  ) then
    return public.app_mutate_v160_pre_finance_143(p_operation,p_payload,p_request_id);
  end if;

  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  begin v_club:=nullif(trim(coalesce(v_payload->>'club_id','')),'')::uuid;
  exception when others then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
  if v_club is null or not public.tiene_rol_club(v_club,'direccion','economia') then
    raise exception 'FINANCE_V2_MUTATION_FORBIDDEN';
  end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then
      raise exception 'MUTATION_REQUEST_ID_REUSED';
    end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
    values(p_request_id,v_uid,v_club,p_operation);
  end if;

  delete from public.app_mutation_requests
  where user_id=v_uid and created_at<now()-interval '30 days';

  v_data:=private.finance_mutate_v143(p_operation,v_payload,v_club,v_uid);
  select backend_version into v_backend_version from public.app_runtime_meta where singleton=true;
  v_result:=jsonb_build_object(
    'ok',true,'backend_version',coalesce(v_backend_version,'1.6.0'),'operation',p_operation,
    'request_id',p_request_id,'data',coalesce(v_data,'{}'::jsonb)
  );
  update public.app_mutation_requests
  set result=v_result,completed_at=now()
  where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests
  where request_id=p_request_id and result is null;
  raise;
end
$$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 9) Audit new financial configuration entities.
-- ---------------------------------------------------------------------------
drop trigger if exists audit_reglas_cobro_v143 on public.reglas_cobro;
create trigger audit_reglas_cobro_v143
after insert or update or delete on public.reglas_cobro
for each row execute function public.registrar_auditoria();

drop trigger if exists audit_reglas_cobro_dest_v143 on public.reglas_cobro_destinatarios;
create trigger audit_reglas_cobro_dest_v143
after insert or update or delete on public.reglas_cobro_destinatarios
for each row execute function public.registrar_auditoria();

drop trigger if exists audit_reglas_cobro_exc_v143 on public.reglas_cobro_excepciones;
create trigger audit_reglas_cobro_exc_v143
after insert or update or delete on public.reglas_cobro_excepciones
for each row execute function public.registrar_auditoria();

-- ---------------------------------------------------------------------------
-- 10) Migration self-audit
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.reglas_cobro') is null
     or to_regclass('public.reglas_cobro_destinatarios') is null
     or to_regclass('public.reglas_cobro_excepciones') is null
     or to_regclass('public.reglas_cobro_ejecuciones') is null then
    raise exception 'FINANCE_V2_143_TABLES_MISSING';
  end if;
  if to_regprocedure('public.procesar_cargos_recurrentes(date,uuid,boolean,boolean)') is null then
    raise exception 'FINANCE_V2_143_ENGINE_MISSING';
  end if;
  if not exists(select 1 from pg_indexes where schemaname='public' and indexname='uq_cuota_regla_socio_ciclo_v143') then
    raise exception 'FINANCE_V2_143_IDEMPOTENCY_INDEX_MISSING';
  end if;
  if exists(
    select 1 from public.config_club
    where clave in ('finance_v2_enabled','finance_dashboard_v2_enabled','finance_recurring_enabled','finance_reports_enabled')
      and lower(trim(both '"' from valor::text)) in ('true','1','si','sí','yes')
  ) then
    raise exception 'FINANCE_V2_143_FLAGS_MUST_START_DISABLED';
  end if;
end
$$;

notify pgrst,'reload schema';
commit;
