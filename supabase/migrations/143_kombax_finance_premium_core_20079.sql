-- KOMBAX RC13 build 20079 · Finanzas Premium 2.0 · GATE 1
-- Modelo aditivo, flags por club, RLS, índices y trazabilidad.
-- No elimina ni reinterpreta importes históricos. No activa recurrencias.

begin;

-- ---------------------------------------------------------------------------
-- 0. Capacidades internas y feature flags. config_club ya es el registro
--    multi-club de configuración; se reutiliza en lugar de crear otro sistema.
-- ---------------------------------------------------------------------------
create or replace function public.app_finance_v2_manage_v143(p_club_id uuid)
returns boolean
language sql stable security definer set search_path=public,auth
as $$
  select auth.uid() is not null and exists(
    select 1
    from public.miembros_club m
    where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo
      and (m.rol in ('direccion','economia','secretaria') or coalesce(m.coordinacion,false))
  );
$$;
revoke all on function public.app_finance_v2_manage_v143(uuid) from public,anon;
grant execute on function public.app_finance_v2_manage_v143(uuid) to authenticated;

create or replace function public.app_finance_v2_direction_v143(p_club_id uuid)
returns boolean
language sql stable security definer set search_path=public,auth
as $$
  select auth.uid() is not null and exists(
    select 1
    from public.miembros_club m
    where m.club_id=p_club_id and m.perfil_id=auth.uid() and m.activo and m.rol='direccion'
  );
$$;
revoke all on function public.app_finance_v2_direction_v143(uuid) from public,anon;
grant execute on function public.app_finance_v2_direction_v143(uuid) to authenticated;

insert into public.config_club(club_id,clave,valor,descripcion,editable_por)
select c.id,x.clave,'false'::jsonb,x.descripcion,'direccion'::public.rol_club
from public.clubes c
cross join (values
  ('finance_v2_enabled','Activa el núcleo aditivo de Finanzas Premium 2.0.'),
  ('finance_dashboard_v2_enabled','Activa la experiencia visual premium de Finanzas.'),
  ('finance_recurring_enabled','Permite escritura automática del motor recurrente. Desactivado por defecto.'),
  ('finance_reports_enabled','Activa generación y archivo de informes financieros v2.')
) as x(clave,descripcion)
on conflict(club_id,clave) do nothing;

create or replace function public.app_finance_v2_flag_value_v143(p_club_id uuid,p_key text)
returns boolean
language sql stable security definer set search_path=public,auth
as $$
  select coalesce((select case
    when jsonb_typeof(c.valor)='boolean' then (c.valor::text)::boolean
    when lower(trim(both '"' from c.valor::text)) in ('true','1','si','sí','on') then true
    else false end
  from public.config_club c where c.club_id=p_club_id and c.clave=p_key),false);
$$;
revoke all on function public.app_finance_v2_flag_value_v143(uuid,text) from public,anon,authenticated;
grant execute on function public.app_finance_v2_flag_value_v143(uuid,text) to service_role,postgres;

create or replace function public.app_finance_v2_flags_v143(p_club_id uuid)
returns jsonb
language plpgsql stable security definer set search_path=public,auth
as $$
begin
  if auth.uid() is null or not public.es_miembro_club(p_club_id) then raise exception 'FINANCE_V2_MEMBERSHIP_REQUIRED'; end if;
  return jsonb_build_object(
    'finance_v2_enabled',public.app_finance_v2_flag_value_v143(p_club_id,'finance_v2_enabled'),
    'finance_dashboard_v2_enabled',public.app_finance_v2_flag_value_v143(p_club_id,'finance_dashboard_v2_enabled'),
    'finance_recurring_enabled',public.app_finance_v2_flag_value_v143(p_club_id,'finance_recurring_enabled'),
    'finance_reports_enabled',public.app_finance_v2_flag_value_v143(p_club_id,'finance_reports_enabled')
  );
end $$;
revoke all on function public.app_finance_v2_flags_v143(uuid) from public,anon;
grant execute on function public.app_finance_v2_flags_v143(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 1. Reglas de cobro: automatización separada de tarifa y de cargo concreto.
-- ---------------------------------------------------------------------------
create table if not exists public.reglas_cobro (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete restrict,
  tarifa_id uuid,
  nombre text not null,
  concepto text not null,
  categoria text not null default 'cuota'
    check(categoria in ('cuota','matricula','licencia','material','competicion','evento','desplazamiento','otro')),
  concepto_personalizado text,
  importe numeric(12,2) not null check(importe>=0),
  periodicidad text not null default 'mensual'
    check(periodicidad in ('mensual','trimestral','semestral','anual','unica')),
  fecha_inicio date not null default current_date,
  fecha_fin date,
  dia_generacion smallint not null default 1 check(dia_generacion between 1 and 31),
  dia_vencimiento smallint not null default 10 check(dia_vencimiento between 1 and 31),
  zona_horaria text not null default 'Europe/Madrid',
  politica_alta text not null default 'siguiente_ciclo'
    check(politica_alta in ('siguiente_ciclo','ciclo_actual_completo_manual')),
  activa boolean not null default true,
  version integer not null default 1 check(version>0),
  observaciones text,
  creada_por uuid references public.perfiles(id),
  creado_en timestamptz not null default now(),
  actualizado_por uuid references public.perfiles(id),
  actualizado_en timestamptz not null default now(),
  foreign key(club_id,tarifa_id) references public.tarifas(club_id,id) on delete set null,
  unique(club_id,id),
  check(fecha_fin is null or fecha_fin>=fecha_inicio),
  check(categoria<>'otro' or nullif(trim(coalesce(concepto_personalizado,concepto,'')),'') is not null)
);
create index if not exists idx_reglas_cobro_club_activa_v143
  on public.reglas_cobro(club_id,activa,fecha_inicio,fecha_fin);
create index if not exists idx_reglas_cobro_club_tarifa_v143
  on public.reglas_cobro(club_id,tarifa_id) where tarifa_id is not null;

create table if not exists public.reglas_cobro_destinatarios (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete restrict,
  regla_id uuid not null,
  tipo text not null check(tipo in ('socio','grupo','disciplina','todos')),
  socio_id uuid,
  grupo_id uuid,
  disciplina_id uuid,
  creado_por uuid references public.perfiles(id),
  creado_en timestamptz not null default now(),
  foreign key(club_id,regla_id) references public.reglas_cobro(club_id,id) on delete restrict,
  foreign key(club_id,socio_id) references public.socios(club_id,id) on delete restrict,
  foreign key(club_id,grupo_id) references public.grupos(club_id,id) on delete restrict,
  foreign key(club_id,disciplina_id) references public.disciplinas(club_id,id) on delete restrict,
  check(
    (tipo='socio' and socio_id is not null and grupo_id is null and disciplina_id is null) or
    (tipo='grupo' and socio_id is null and grupo_id is not null and disciplina_id is null) or
    (tipo='disciplina' and socio_id is null and grupo_id is null and disciplina_id is not null) or
    (tipo='todos' and socio_id is null and grupo_id is null and disciplina_id is null)
  )
);
create unique index if not exists uq_reglas_dest_socio_v143 on public.reglas_cobro_destinatarios(regla_id,socio_id) where tipo='socio';
create unique index if not exists uq_reglas_dest_grupo_v143 on public.reglas_cobro_destinatarios(regla_id,grupo_id) where tipo='grupo';
create unique index if not exists uq_reglas_dest_disciplina_v143 on public.reglas_cobro_destinatarios(regla_id,disciplina_id) where tipo='disciplina';
create unique index if not exists uq_reglas_dest_todos_v143 on public.reglas_cobro_destinatarios(regla_id) where tipo='todos';
create index if not exists idx_reglas_dest_club_regla_v143 on public.reglas_cobro_destinatarios(club_id,regla_id,tipo);

create table if not exists public.reglas_cobro_excepciones (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete restrict,
  regla_id uuid not null,
  socio_id uuid not null,
  tipo text not null check(tipo in ('excluido','exento','pausa','bonificacion','importe_personalizado','no_generar_ciclo')),
  importe_personalizado numeric(12,2) check(importe_personalizado is null or importe_personalizado>=0),
  porcentaje_bonificacion numeric(5,2) check(porcentaje_bonificacion is null or porcentaje_bonificacion between 0 and 100),
  ciclo date,
  fecha_inicio date,
  fecha_fin date,
  motivo text not null,
  activa boolean not null default true,
  creada_por uuid references public.perfiles(id),
  creado_en timestamptz not null default now(),
  actualizado_por uuid references public.perfiles(id),
  actualizado_en timestamptz not null default now(),
  foreign key(club_id,regla_id) references public.reglas_cobro(club_id,id) on delete restrict,
  foreign key(club_id,socio_id) references public.socios(club_id,id) on delete restrict,
  check(fecha_fin is null or fecha_inicio is null or fecha_fin>=fecha_inicio),
  check(tipo<>'importe_personalizado' or importe_personalizado is not null),
  check(tipo<>'bonificacion' or porcentaje_bonificacion is not null),
  check(tipo<>'no_generar_ciclo' or ciclo is not null)
);
create index if not exists idx_reglas_excepciones_resolver_v143
  on public.reglas_cobro_excepciones(club_id,regla_id,socio_id,activa,fecha_inicio,fecha_fin);
create unique index if not exists uq_reglas_excepcion_ciclo_v143
  on public.reglas_cobro_excepciones(regla_id,socio_id,tipo,ciclo)
  where tipo='no_generar_ciclo' and activa;

-- ---------------------------------------------------------------------------
-- 2. Extensión aditiva de cargos legacy. La columna origen sigue intacta para
--    consumidores antiguos; categoria_financiera aporta la taxonomía completa.
-- ---------------------------------------------------------------------------
alter table public.cuotas
  add column if not exists categoria_financiera text,
  add column if not exists regla_cobro_id uuid,
  add column if not exists ciclo_clave date,
  add column if not exists generacion_clave text,
  add column if not exists regla_version integer,
  add column if not exists lote_id uuid,
  add column if not exists generada_automaticamente boolean not null default false,
  add column if not exists datos_finance_v2 jsonb not null default '{}'::jsonb;

update public.cuotas
set categoria_financiera=case coalesce(origen,'cuota') when 'material' then 'material' when 'cuota' then 'cuota' else 'otro' end
where categoria_financiera is null;

alter table public.cuotas alter column categoria_financiera set default 'cuota';
alter table public.cuotas alter column categoria_financiera set not null;

do $$ begin
  if not exists(select 1 from pg_constraint where conname='cuotas_categoria_financiera_v143' and conrelid='public.cuotas'::regclass) then
    alter table public.cuotas add constraint cuotas_categoria_financiera_v143
      check(categoria_financiera in ('cuota','matricula','licencia','material','competicion','evento','desplazamiento','otro')) not valid;
    alter table public.cuotas validate constraint cuotas_categoria_financiera_v143;
  end if;
  if not exists(select 1 from pg_constraint where conname='cuotas_regla_cobro_fk_v143' and conrelid='public.cuotas'::regclass) then
    alter table public.cuotas add constraint cuotas_regla_cobro_fk_v143
      foreign key(club_id,regla_cobro_id) references public.reglas_cobro(club_id,id) on delete restrict;
  end if;
end $$;

-- Invariante sagrado: una regla solo puede generar un cargo por alumno y ciclo.
create unique index if not exists uq_cuotas_regla_socio_ciclo_v143
  on public.cuotas(club_id,regla_cobro_id,socio_id,ciclo_clave)
  where regla_cobro_id is not null and ciclo_clave is not null;

-- Idempotencia de lotes manuales/masivos mediante request/lote estable.
create unique index if not exists uq_cuotas_lote_socio_v143
  on public.cuotas(club_id,lote_id,socio_id)
  where lote_id is not null;

create index if not exists idx_cuotas_finance_v2_dashboard_v143
  on public.cuotas(club_id,categoria_financiera,estado,periodo desc,vencimiento);
create index if not exists idx_cuotas_finance_v2_regla_v143
  on public.cuotas(club_id,regla_cobro_id,periodo desc) where regla_cobro_id is not null;
create index if not exists idx_cuotas_finance_v2_socio_v143
  on public.cuotas(club_id,socio_id,estado,vencimiento);

-- ---------------------------------------------------------------------------
-- 3. Ejecuciones, informes snapshot y auditoría propia de la evolución v2.
-- ---------------------------------------------------------------------------
create table if not exists public.finanzas_ejecuciones_regla (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete restrict,
  regla_id uuid not null,
  ciclo date,
  fecha_objetivo date not null,
  shadow boolean not null default true,
  estado text not null default 'iniciada' check(estado in ('iniciada','completada','omitida','error')),
  request_id uuid,
  candidatos integer not null default 0,
  creados integer not null default 0,
  existentes integer not null default 0,
  omitidos integer not null default 0,
  detalle jsonb not null default '{}'::jsonb,
  error_codigo text,
  iniciada_en timestamptz not null default now(),
  finalizada_en timestamptz,
  ejecutada_por uuid references public.perfiles(id),
  foreign key(club_id,regla_id) references public.reglas_cobro(club_id,id) on delete restrict
);
create index if not exists idx_finanzas_ejecuciones_club_v143
  on public.finanzas_ejecuciones_regla(club_id,iniciada_en desc,estado);
create index if not exists idx_finanzas_ejecuciones_regla_v143
  on public.finanzas_ejecuciones_regla(regla_id,ciclo desc,iniciada_en desc);

create table if not exists public.finanzas_informes (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete restrict,
  identificador text not null,
  tipo text not null,
  titulo text not null,
  filtros jsonb not null default '{}'::jsonb,
  resumen jsonb not null default '{}'::jsonb,
  dataset jsonb not null default '[]'::jsonb,
  version integer not null default 1 check(version>0),
  storage_path text,
  storage_sha256 text,
  generado_por uuid references public.perfiles(id),
  generado_en timestamptz not null default now(),
  notas text,
  unique(club_id,identificador,version)
);
create index if not exists idx_finanzas_informes_club_v143
  on public.finanzas_informes(club_id,generado_en desc,tipo);

create table if not exists public.finanzas_auditoria_v2 (
  id bigserial primary key,
  club_id uuid not null references public.clubes(id) on delete restrict,
  actor_id uuid references public.perfiles(id),
  accion text not null,
  entidad text not null,
  entidad_id uuid,
  antes jsonb,
  despues jsonb,
  metadata jsonb not null default '{}'::jsonb,
  creado_en timestamptz not null default now()
);
create index if not exists idx_finanzas_auditoria_club_v143
  on public.finanzas_auditoria_v2(club_id,creado_en desc,accion);

create or replace function public.app_finance_v2_audit_v143(
  p_club_id uuid,p_accion text,p_entidad text,p_entidad_id uuid,
  p_antes jsonb default null,p_despues jsonb default null,p_metadata jsonb default '{}'::jsonb
) returns void
language plpgsql security definer set search_path=public,auth
as $$
begin
  insert into public.finanzas_auditoria_v2(club_id,actor_id,accion,entidad,entidad_id,antes,despues,metadata)
  values(p_club_id,auth.uid(),p_accion,p_entidad,p_entidad_id,p_antes,p_despues,coalesce(p_metadata,'{}'::jsonb));
end $$;
revoke all on function public.app_finance_v2_audit_v143(uuid,text,text,uuid,jsonb,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.app_finance_v2_audit_v143(uuid,text,text,uuid,jsonb,jsonb,jsonb) to service_role,postgres;

-- ---------------------------------------------------------------------------
-- 4. RLS: ninguna tabla nueva se activa sin aislamiento multi-club.
--    Escrituras de cliente siempre por RPC/gateway; tablas solo lectura.
-- ---------------------------------------------------------------------------
alter table public.reglas_cobro enable row level security;
alter table public.reglas_cobro_destinatarios enable row level security;
alter table public.reglas_cobro_excepciones enable row level security;
alter table public.finanzas_ejecuciones_regla enable row level security;
alter table public.finanzas_informes enable row level security;
alter table public.finanzas_auditoria_v2 enable row level security;

drop policy if exists reglas_cobro_select_v143 on public.reglas_cobro;
create policy reglas_cobro_select_v143 on public.reglas_cobro for select to authenticated
  using(public.app_finance_v2_manage_v143(club_id));
drop policy if exists reglas_cobro_dest_select_v143 on public.reglas_cobro_destinatarios;
create policy reglas_cobro_dest_select_v143 on public.reglas_cobro_destinatarios for select to authenticated
  using(public.app_finance_v2_manage_v143(club_id));
drop policy if exists reglas_cobro_exc_select_v143 on public.reglas_cobro_excepciones;
create policy reglas_cobro_exc_select_v143 on public.reglas_cobro_excepciones for select to authenticated
  using(public.app_finance_v2_manage_v143(club_id));
drop policy if exists finanzas_ejecuciones_select_v143 on public.finanzas_ejecuciones_regla;
create policy finanzas_ejecuciones_select_v143 on public.finanzas_ejecuciones_regla for select to authenticated
  using(public.app_finance_v2_manage_v143(club_id));
drop policy if exists finanzas_informes_select_v143 on public.finanzas_informes;
create policy finanzas_informes_select_v143 on public.finanzas_informes for select to authenticated
  using(public.app_finance_v2_manage_v143(club_id));
drop policy if exists finanzas_auditoria_select_v143 on public.finanzas_auditoria_v2;
create policy finanzas_auditoria_select_v143 on public.finanzas_auditoria_v2 for select to authenticated
  using(public.app_finance_v2_manage_v143(club_id));

revoke all on public.reglas_cobro,public.reglas_cobro_destinatarios,public.reglas_cobro_excepciones,
  public.finanzas_ejecuciones_regla,public.finanzas_informes,public.finanzas_auditoria_v2
  from public,anon,authenticated;
grant select on public.reglas_cobro,public.reglas_cobro_destinatarios,public.reglas_cobro_excepciones,
  public.finanzas_ejecuciones_regla,public.finanzas_informes,public.finanzas_auditoria_v2
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Auditoría estática de GATE 1. Solo servicio/postgres.
-- ---------------------------------------------------------------------------
create or replace function public.app_finance_v2_schema_audit_v143()
returns table(control text,ok boolean,detalle text)
language sql security definer set search_path=public,auth
as $$
  select 'reglas_cobro',to_regclass('public.reglas_cobro') is not null,'modelo de automatización'
  union all select 'destinatarios',to_regclass('public.reglas_cobro_destinatarios') is not null,'scopes dinámicos'
  union all select 'excepciones',to_regclass('public.reglas_cobro_excepciones') is not null,'exclusiones/pausas/bonificaciones'
  union all select 'unique regla+socio+ciclo',to_regclass('public.uq_cuotas_regla_socio_ciclo_v143') is not null,'protección PostgreSQL contra duplicados'
  union all select 'rls reglas',(select relrowsecurity from pg_class where oid='public.reglas_cobro'::regclass),'RLS activa'
  union all select 'rls destinatarios',(select relrowsecurity from pg_class where oid='public.reglas_cobro_destinatarios'::regclass),'RLS activa'
  union all select 'rls excepciones',(select relrowsecurity from pg_class where oid='public.reglas_cobro_excepciones'::regclass),'RLS activa'
  union all select 'flags desactivados por defecto',not exists(
    select 1 from public.config_club where clave in ('finance_recurring_enabled') and valor='true'::jsonb
  ),'ningún club recibe deudas automáticas al desplegar';
$$;
revoke all on function public.app_finance_v2_schema_audit_v143() from public,anon,authenticated;
grant execute on function public.app_finance_v2_schema_audit_v143() to service_role,postgres;

notify pgrst,'reload schema';
commit;
