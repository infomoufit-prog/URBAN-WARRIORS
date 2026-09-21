-- ============================================================================
-- URBAN WARRIORS · FASE 1 COMPLETA
-- Esquema Supabase/PostgreSQL multi-club preparado para evolucionar a SaaS.
-- Consolida las ideas útiles de las dos propuestas V2 sin ejecutar ambas.
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 1. TIPOS
-- ---------------------------------------------------------------------------
do $$ begin
  create type public.rol_club as enum ('direccion','secretaria','economia','comunicacion','monitor','familia','alumno');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.estado_preinscripcion as enum ('borrador','enviada','en_revision','pendiente_documentacion','lista_espera','aprobada','rechazada','cancelada');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.estado_cuota as enum ('pendiente','parcialmente_pagada','pagada','vencida','anulada','exenta');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.estado_asistencia as enum ('pendiente','presente','ausente','ausencia_justificada','retraso','no_convocado');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.visibilidad_seguimiento as enum ('equipo','direccion_monitor','familia');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- 2. CLUBES, PERFILES Y PERTENENCIA
-- ---------------------------------------------------------------------------
create table if not exists public.clubes (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  slug text not null unique,
  lema text,
  cif text,
  telefono text,
  email text,
  direccion text,
  web text,
  logo_url text,
  portada_url text,
  color_primario text not null default '#ffffff',
  color_secundario text not null default '#050608',
  idioma text not null default 'es',
  zona_horaria text not null default 'Europe/Madrid',
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table if not exists public.perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre text,
  apellidos text,
  telefono text,
  avatar_url text,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table if not exists public.miembros_club (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  rol public.rol_club not null,
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  unique (club_id, perfil_id, rol)
);
create index if not exists idx_miembros_club_perfil on public.miembros_club(perfil_id, club_id) where activo;

create table if not exists public.config_club (
  club_id uuid not null references public.clubes(id) on delete cascade,
  clave text not null,
  valor jsonb not null,
  descripcion text,
  editable_por public.rol_club,
  actualizado_en timestamptz not null default now(),
  actualizado_por uuid references public.perfiles(id),
  primary key (club_id, clave)
);

-- ---------------------------------------------------------------------------
-- 3. CATÁLOGOS DEPORTIVOS
-- ---------------------------------------------------------------------------
create table if not exists public.disciplinas (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  nombre text not null,
  descripcion text,
  color text default '#ffffff',
  imagen_url text,
  edad_minima smallint,
  activa boolean not null default true,
  orden smallint not null default 0,
  creado_en timestamptz not null default now(),
  unique (club_id, nombre),
  unique (club_id, id)
);
create index if not exists idx_disciplinas_club on public.disciplinas(club_id, activa, orden);

create table if not exists public.grados (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  disciplina_id uuid not null,
  nombre text not null,
  orden smallint not null,
  color text,
  meses_minimos smallint,
  activo boolean not null default true,
  foreign key (club_id, disciplina_id) references public.disciplinas(club_id, id) on delete cascade,
  unique (club_id, disciplina_id, orden),
  unique (club_id, disciplina_id, nombre),
  unique (club_id, id)
);

create table if not exists public.grupos (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  disciplina_id uuid not null,
  nombre text not null,
  monitor_principal_id uuid references public.perfiles(id),
  monitor_nombre text,
  sala text,
  edad_min smallint,
  edad_max smallint,
  plazas integer check (plazas is null or plazas > 0),
  temporada_inicio date,
  temporada_fin date,
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  foreign key (club_id, disciplina_id) references public.disciplinas(club_id, id) on delete restrict,
  unique (club_id, nombre),
  unique (club_id, id)
);

create table if not exists public.horarios_grupo (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  grupo_id uuid not null,
  dia_semana smallint not null check (dia_semana between 1 and 7),
  hora_inicio time not null,
  hora_fin time not null,
  fecha_inicio date,
  fecha_fin date,
  foreign key (club_id, grupo_id) references public.grupos(club_id, id) on delete cascade,
  check (hora_fin > hora_inicio)
);
create index if not exists idx_horarios_club_grupo on public.horarios_grupo(club_id, grupo_id, dia_semana);

-- ---------------------------------------------------------------------------
-- 4. SOCIOS, FAMILIAS E INSCRIPCIONES
-- ---------------------------------------------------------------------------
create table if not exists public.socios (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  perfil_id uuid references public.perfiles(id) on delete set null,
  nombre text not null,
  apellidos text not null,
  fecha_nacimiento date,
  telefono text,
  email text,
  contacto_emergencia text,
  telefono_emergencia text,
  estado text not null default 'activo' check (estado in ('prealta','activo','baja','suspendido')),
  fecha_alta date not null default current_date,
  fecha_baja date,
  motivo_baja text,
  tarifa_id uuid,
  notas_internas text,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique (club_id, id)
);
create index if not exists idx_socios_club_estado on public.socios(club_id, estado);

create table if not exists public.tutores_socios (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  tutor_perfil_id uuid not null references public.perfiles(id) on delete cascade,
  socio_id uuid not null,
  parentesco text,
  contacto_principal boolean not null default false,
  autorizado_recogida boolean not null default true,
  foreign key (club_id, socio_id) references public.socios(club_id, id) on delete cascade,
  unique (club_id, tutor_perfil_id, socio_id)
);
create index if not exists idx_tutores_perfil on public.tutores_socios(tutor_perfil_id, club_id);

create table if not exists public.preinscripciones (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  nombre text not null,
  apellidos text not null,
  fecha_nacimiento date,
  edad smallint,
  tutor_nombre text,
  tutor_email text,
  telefono text not null,
  disciplina_id uuid,
  grupo_id uuid,
  tarifa_id uuid,
  estado public.estado_preinscripcion not null default 'enviada',
  observaciones text,
  revisada_por uuid references public.perfiles(id),
  revisada_en timestamptz,
  creado_en timestamptz not null default now(),
  foreign key (club_id, disciplina_id) references public.disciplinas(club_id, id) on delete set null,
  foreign key (club_id, grupo_id) references public.grupos(club_id, id) on delete set null
);
create index if not exists idx_preinscripciones_club_estado on public.preinscripciones(club_id, estado, creado_en desc);

create table if not exists public.socio_disciplinas (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  socio_id uuid not null,
  disciplina_id uuid not null,
  grupo_id uuid,
  grado_id uuid,
  fecha_inicio date not null default current_date,
  fecha_fin date,
  activa boolean not null default true,
  foreign key (club_id, socio_id) references public.socios(club_id, id) on delete cascade,
  foreign key (club_id, disciplina_id) references public.disciplinas(club_id, id) on delete restrict,
  foreign key (club_id, grupo_id) references public.grupos(club_id, id) on delete set null,
  foreign key (club_id, grado_id) references public.grados(club_id, id) on delete set null,
  unique (club_id, socio_id, disciplina_id)
);
create index if not exists idx_socio_disciplinas_club on public.socio_disciplinas(club_id, socio_id, activa);

create table if not exists public.graduaciones (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  socio_id uuid not null,
  disciplina_id uuid not null,
  grado_id uuid not null,
  grado_anterior_id uuid,
  fecha date not null default current_date,
  examinador text,
  nota text,
  certificado_url text,
  registrado_por uuid references public.perfiles(id),
  creado_en timestamptz not null default now(),
  foreign key (club_id, socio_id) references public.socios(club_id, id) on delete cascade,
  foreign key (club_id, disciplina_id) references public.disciplinas(club_id, id) on delete restrict,
  foreign key (club_id, grado_id) references public.grados(club_id, id) on delete restrict,
  foreign key (club_id, grado_anterior_id) references public.grados(club_id, id) on delete set null
);

-- ---------------------------------------------------------------------------
-- 5. TARIFAS, CUOTAS Y PAGOS
-- ---------------------------------------------------------------------------
create table if not exists public.tarifas (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  disciplina_id uuid,
  nombre text not null,
  descripcion text,
  importe numeric(10,2) not null check (importe >= 0),
  periodicidad text not null default 'mensual',
  matricula numeric(10,2) not null default 0,
  dias_semana smallint,
  num_disciplinas smallint,
  edad_min smallint,
  edad_max smallint,
  activa boolean not null default true,
  orden smallint not null default 0,
  actualizada_en timestamptz not null default now(),
  actualizada_por uuid references public.perfiles(id),
  foreign key (club_id, disciplina_id) references public.disciplinas(club_id, id) on delete set null,
  unique (club_id, nombre),
  unique (club_id, id)
);

alter table public.socios
  add constraint fk_socios_tarifa_club foreign key (club_id, tarifa_id)
  references public.tarifas(club_id, id) on delete set null;

create table if not exists public.historial_tarifas (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  tarifa_id uuid not null,
  importe_anterior numeric(10,2),
  importe_nuevo numeric(10,2) not null,
  motivo text,
  cambiado_por uuid references public.perfiles(id),
  cambiado_en timestamptz not null default now(),
  foreign key (club_id, tarifa_id) references public.tarifas(club_id, id) on delete restrict
);

create table if not exists public.descuentos (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  nombre text not null,
  porcentaje numeric(5,2),
  importe_fijo numeric(10,2),
  fecha_inicio date,
  fecha_fin date,
  activo boolean not null default true,
  check (coalesce(porcentaje,0) >= 0 and coalesce(importe_fijo,0) >= 0),
  unique (club_id, nombre),
  unique (club_id, id)
);

create table if not exists public.socio_descuentos (
  club_id uuid not null references public.clubes(id) on delete cascade,
  socio_id uuid not null,
  descuento_id uuid not null,
  primary key (club_id, socio_id, descuento_id),
  foreign key (club_id, socio_id) references public.socios(club_id, id) on delete cascade,
  foreign key (club_id, descuento_id) references public.descuentos(club_id, id) on delete cascade
);

create table if not exists public.cuotas (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  socio_id uuid not null,
  tarifa_id uuid,
  periodo date not null,
  concepto text not null,
  importe numeric(10,2) not null check (importe >= 0),
  vencimiento date not null,
  estado public.estado_cuota not null default 'pendiente',
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  foreign key (club_id, socio_id) references public.socios(club_id, id) on delete restrict,
  foreign key (club_id, tarifa_id) references public.tarifas(club_id, id) on delete set null,
  unique (club_id, socio_id, periodo, concepto),
  unique (club_id, id)
);
create index if not exists idx_cuotas_club_estado on public.cuotas(club_id, estado, vencimiento);

create table if not exists public.pagos (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  cuota_id uuid,
  socio_id uuid not null,
  importe numeric(10,2) not null check (importe > 0),
  fecha date not null default current_date,
  metodo text not null check (metodo in ('transferencia','bizum','efectivo','tarjeta','otro')),
  referencia text,
  justificante_url text,
  estado_validacion text not null default 'pendiente' check (estado_validacion in ('pendiente','validado','rechazado')),
  validado_por uuid references public.perfiles(id),
  validado_en timestamptz,
  observaciones text,
  creado_en timestamptz not null default now(),
  foreign key (club_id, cuota_id) references public.cuotas(club_id, id) on delete set null,
  foreign key (club_id, socio_id) references public.socios(club_id, id) on delete restrict
);

-- ---------------------------------------------------------------------------
-- 6. SESIONES, ASISTENCIA Y SEGUIMIENTO
-- ---------------------------------------------------------------------------
create table if not exists public.sesiones_entrenamiento (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  grupo_id uuid not null,
  fecha date not null,
  hora_inicio time not null,
  hora_fin time,
  monitor_id uuid references public.perfiles(id),
  monitor_nombre text,
  estado text not null default 'programada' check (estado in ('programada','en_curso','completada','cancelada')),
  observacion_general text,
  creado_en timestamptz not null default now(),
  foreign key (club_id, grupo_id) references public.grupos(club_id, id) on delete cascade,
  unique (club_id, grupo_id, fecha, hora_inicio),
  unique (club_id, id)
);

create table if not exists public.asistencias (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  sesion_id uuid not null,
  socio_id uuid not null,
  estado public.estado_asistencia not null default 'pendiente',
  observacion text,
  registrado_por uuid references public.perfiles(id),
  registrado_en timestamptz not null default now(),
  foreign key (club_id, sesion_id) references public.sesiones_entrenamiento(club_id, id) on delete cascade,
  foreign key (club_id, socio_id) references public.socios(club_id, id) on delete cascade,
  unique (club_id, sesion_id, socio_id)
);

create table if not exists public.seguimiento (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  socio_id uuid not null,
  tipo text not null,
  nota text not null,
  visibilidad public.visibilidad_seguimiento not null default 'equipo',
  registrado_por uuid references public.perfiles(id),
  fecha date not null default current_date,
  creado_en timestamptz not null default now(),
  foreign key (club_id, socio_id) references public.socios(club_id, id) on delete cascade
);

-- ---------------------------------------------------------------------------
-- 7. COMUNICACIONES, LEGALES Y MATERIAL
-- ---------------------------------------------------------------------------
create table if not exists public.comunicaciones (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  titulo text not null,
  cuerpo text not null,
  audiencia text not null default 'todos',
  disciplina_id uuid,
  grupo_id uuid,
  estado text not null default 'borrador' check (estado in ('borrador','programada','publicada','archivada')),
  programada_para timestamptz,
  publicada_en timestamptz,
  creada_por uuid references public.perfiles(id),
  creado_en timestamptz not null default now(),
  foreign key (club_id, disciplina_id) references public.disciplinas(club_id, id) on delete set null,
  foreign key (club_id, grupo_id) references public.grupos(club_id, id) on delete set null
);

create table if not exists public.textos_legales (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  tipo text not null,
  version text not null,
  cuerpo text not null,
  vigente boolean not null default false,
  creado_por uuid references public.perfiles(id),
  creado_en timestamptz not null default now(),
  unique (club_id, tipo, version),
  unique (club_id, id)
);
create unique index if not exists textos_legales_vigente_unico on public.textos_legales(club_id, tipo) where vigente;

create table if not exists public.consentimientos (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  socio_id uuid not null,
  texto_legal_id uuid not null,
  tutor_perfil_id uuid references public.perfiles(id),
  aceptado boolean not null,
  aceptado_en timestamptz not null default now(),
  revocado_en timestamptz,
  ip inet,
  user_agent text,
  foreign key (club_id, socio_id) references public.socios(club_id, id) on delete cascade,
  foreign key (club_id, texto_legal_id) references public.textos_legales(club_id, id) on delete restrict
);

create table if not exists public.material_catalogo (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  disciplina_id uuid,
  nombre text not null,
  categoria text,
  descripcion text,
  imagen_url text,
  precio numeric(10,2) not null default 0,
  obligatorio boolean not null default false,
  referencia text,
  orden smallint not null default 0,
  activo boolean not null default true,
  foreign key (club_id, disciplina_id) references public.disciplinas(club_id, id) on delete set null,
  unique (club_id, nombre),
  unique (club_id, id)
);

create table if not exists public.material_variantes (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  material_id uuid not null,
  talla text,
  color text,
  referencia text,
  stock integer not null default 0 check (stock >= 0),
  activa boolean not null default true,
  foreign key (club_id, material_id) references public.material_catalogo(club_id, id) on delete cascade,
  unique (club_id, material_id, talla, color)
);

create table if not exists public.material_entregas (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  socio_id uuid not null,
  variante_id uuid,
  material_id uuid not null,
  cantidad integer not null default 1 check (cantidad > 0),
  fecha date not null default current_date,
  estado text not null default 'entregado' check (estado in ('reservado','entregado','devuelto')),
  registrado_por uuid references public.perfiles(id),
  foreign key (club_id, socio_id) references public.socios(club_id, id) on delete restrict,
  foreign key (club_id, material_id) references public.material_catalogo(club_id, id) on delete restrict,
  foreign key (variante_id) references public.material_variantes(id) on delete set null
);

create table if not exists public.auditoria (
  id bigint generated always as identity primary key,
  club_id uuid,
  usuario_id uuid,
  accion text not null,
  entidad text not null,
  registro_id text,
  datos_anteriores jsonb,
  datos_nuevos jsonb,
  creado_en timestamptz not null default now()
);
create index if not exists idx_auditoria_club_fecha on public.auditoria(club_id, creado_en desc);

-- ---------------------------------------------------------------------------
-- 8. FUNCIONES DE SEGURIDAD
-- ---------------------------------------------------------------------------
create or replace function public.es_miembro_club(p_club_id uuid)
returns boolean language sql stable security definer set search_path = public, auth as $$
  select exists (
    select 1 from public.miembros_club m
    where m.club_id = p_club_id and m.perfil_id = auth.uid() and m.activo
  );
$$;

create or replace function public.tiene_rol_club(p_club_id uuid, variadic p_roles public.rol_club[])
returns boolean language sql stable security definer set search_path = public, auth as $$
  select exists (
    select 1 from public.miembros_club m
    where m.club_id = p_club_id and m.perfil_id = auth.uid() and m.activo and m.rol = any(p_roles)
  );
$$;

create or replace function public.puede_ver_socio(p_socio_id uuid)
returns boolean language sql stable security definer set search_path = public, auth as $$
  select exists (
    select 1 from public.socios s
    where s.id = p_socio_id and (
      s.perfil_id = auth.uid()
      or public.tiene_rol_club(s.club_id, 'direccion','secretaria','economia','monitor')
      or exists (select 1 from public.tutores_socios t where t.socio_id = s.id and t.tutor_perfil_id = auth.uid())
    )
  );
$$;

create or replace function public.puede_gestionar_socio(p_socio_id uuid)
returns boolean language sql stable security definer set search_path = public, auth as $$
  select exists (
    select 1 from public.socios s where s.id = p_socio_id
    and public.tiene_rol_club(s.club_id, 'direccion','secretaria')
  );
$$;

grant execute on function public.es_miembro_club(uuid) to authenticated, anon;
grant execute on function public.tiene_rol_club(uuid, public.rol_club[]) to authenticated;
grant execute on function public.puede_ver_socio(uuid) to authenticated;
grant execute on function public.puede_gestionar_socio(uuid) to authenticated;

-- Crear perfil automáticamente al registrarse.
create or replace function public.crear_perfil_usuario()
returns trigger language plpgsql security definer set search_path = public, auth as $$
begin
  insert into public.perfiles(id, nombre, apellidos)
  values (new.id, coalesce(new.raw_user_meta_data->>'nombre',''), coalesce(new.raw_user_meta_data->>'apellidos',''))
  on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists trg_crear_perfil_usuario on auth.users;
create trigger trg_crear_perfil_usuario after insert on auth.users for each row execute function public.crear_perfil_usuario();

-- Historial de cambios de tarifas.
create or replace function public.registrar_cambio_tarifa()
returns trigger language plpgsql security definer set search_path = public, auth as $$
begin
  if new.importe is distinct from old.importe then
    insert into public.historial_tarifas(club_id, tarifa_id, importe_anterior, importe_nuevo, cambiado_por)
    values(new.club_id, new.id, old.importe, new.importe, auth.uid());
    new.actualizada_en := now();
    new.actualizada_por := auth.uid();
  end if;
  return new;
end;
$$;
drop trigger if exists trg_historial_tarifa on public.tarifas;
create trigger trg_historial_tarifa before update on public.tarifas for each row execute function public.registrar_cambio_tarifa();

-- Actualizar grado actual y verificar coherencia.
create or replace function public.actualizar_grado_actual()
returns trigger language plpgsql security definer set search_path = public, auth as $$
begin
  if not exists (
    select 1 from public.grados g
    where g.id = new.grado_id and g.club_id = new.club_id and g.disciplina_id = new.disciplina_id
  ) then raise exception 'El grado no pertenece a la disciplina y club indicados'; end if;

  update public.socio_disciplinas
  set grado_id = new.grado_id
  where club_id = new.club_id and socio_id = new.socio_id and disciplina_id = new.disciplina_id and activa;

  if not found then raise exception 'El socio no tiene una inscripción activa en esa disciplina'; end if;
  return new;
end;
$$;
drop trigger if exists trg_grado_actual on public.graduaciones;
create trigger trg_grado_actual after insert on public.graduaciones for each row execute function public.actualizar_grado_actual();

-- Generación idempotente de cuotas por club.
create or replace function public.generar_cuotas_periodo(p_club_id uuid, p_periodo date default date_trunc('month', current_date)::date)
returns integer language plpgsql security definer set search_path = public, auth as $$
declare
  v_creadas integer;
  v_dia integer := 9;
begin
  if not public.tiene_rol_club(p_club_id, 'direccion','economia') then
    raise exception 'Sin permisos para generar cuotas';
  end if;

  select coalesce((valor #>> '{}')::integer, 9) into v_dia
  from public.config_club where club_id = p_club_id and clave = 'dia_vencimiento';
  v_dia := greatest(1, least(coalesce(v_dia,9), 28));

  with nuevas as (
    insert into public.cuotas(club_id, socio_id, tarifa_id, periodo, concepto, importe, vencimiento)
    select s.club_id, s.id, t.id, p_periodo,
           'Cuota ' || to_char(p_periodo,'MM/YYYY'), t.importe,
           (p_periodo + (v_dia - 1))::date
    from public.socios s
    join public.tarifas t on t.club_id=s.club_id and t.id=s.tarifa_id and t.activa
    where s.club_id=p_club_id and s.estado='activo'
    on conflict (club_id, socio_id, periodo, concepto) do nothing
    returning 1
  ) select count(*) into v_creadas from nuevas;
  return v_creadas;
end;
$$;
grant execute on function public.generar_cuotas_periodo(uuid,date) to authenticated;

-- Auditoría genérica de tablas sensibles.
create or replace function public.registrar_auditoria()
returns trigger language plpgsql security definer set search_path = public, auth as $$
declare
  old_data jsonb := case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end;
  new_data jsonb := case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else null end;
  v_club uuid := coalesce((new_data->>'club_id')::uuid, (old_data->>'club_id')::uuid);
  v_id text := coalesce(new_data->>'id', old_data->>'id');
begin
  insert into public.auditoria(club_id, usuario_id, accion, entidad, registro_id, datos_anteriores, datos_nuevos)
  values(v_club, auth.uid(), tg_op, tg_table_name, v_id, old_data - array['notas_internas'], new_data - array['notas_internas']);
  return coalesce(new, old);
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. RLS
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'clubes','perfiles','miembros_club','config_club','disciplinas','grados','grupos','horarios_grupo',
    'socios','tutores_socios','preinscripciones','socio_disciplinas','graduaciones','tarifas','historial_tarifas',
    'descuentos','socio_descuentos','cuotas','pagos','sesiones_entrenamiento','asistencias','seguimiento',
    'comunicaciones','textos_legales','consentimientos','material_catalogo','material_variantes','material_entregas','auditoria'
  ] loop execute format('alter table public.%I enable row level security', t); end loop;
end $$;

-- Clubes y perfiles.
create policy clubes_publicos on public.clubes for select using (activo or public.es_miembro_club(id));
create policy clubes_gestion on public.clubes for update using (public.tiene_rol_club(id,'direccion')) with check (public.tiene_rol_club(id,'direccion'));
create policy perfil_propio on public.perfiles for select using (id=auth.uid());
create policy perfil_actualizar on public.perfiles for update using (id=auth.uid()) with check (id=auth.uid());
create policy miembros_lectura on public.miembros_club for select using (perfil_id=auth.uid() or public.tiene_rol_club(club_id,'direccion','secretaria'));
create policy miembros_gestion on public.miembros_club for all using (public.tiene_rol_club(club_id,'direccion')) with check (public.tiene_rol_club(club_id,'direccion'));

-- Catálogos y configuración.
create policy config_lectura on public.config_club for select using (public.es_miembro_club(club_id));
create policy config_gestion on public.config_club for all using (public.tiene_rol_club(club_id,'direccion','secretaria','economia','comunicacion')) with check (public.tiene_rol_club(club_id,'direccion','secretaria','economia','comunicacion'));

create policy disciplinas_lectura on public.disciplinas for select using (public.es_miembro_club(club_id));
create policy disciplinas_gestion on public.disciplinas for all using (public.tiene_rol_club(club_id,'direccion','secretaria')) with check (public.tiene_rol_club(club_id,'direccion','secretaria'));
create policy grados_lectura on public.grados for select using (public.es_miembro_club(club_id));
create policy grados_gestion on public.grados for all using (public.tiene_rol_club(club_id,'direccion','secretaria','monitor')) with check (public.tiene_rol_club(club_id,'direccion','secretaria','monitor'));
create policy grupos_lectura on public.grupos for select using (public.es_miembro_club(club_id));
create policy grupos_gestion on public.grupos for all using (public.tiene_rol_club(club_id,'direccion','secretaria')) with check (public.tiene_rol_club(club_id,'direccion','secretaria'));
create policy horarios_lectura on public.horarios_grupo for select using (public.es_miembro_club(club_id));
create policy horarios_gestion on public.horarios_grupo for all using (public.tiene_rol_club(club_id,'direccion','secretaria')) with check (public.tiene_rol_club(club_id,'direccion','secretaria'));

-- Socios y familias.
create policy socios_lectura on public.socios for select using (public.puede_ver_socio(id));
create policy socios_gestion on public.socios for all using (public.tiene_rol_club(club_id,'direccion','secretaria')) with check (public.tiene_rol_club(club_id,'direccion','secretaria'));
create policy tutores_lectura on public.tutores_socios for select using (tutor_perfil_id=auth.uid() or public.tiene_rol_club(club_id,'direccion','secretaria'));
create policy tutores_gestion on public.tutores_socios for all using (public.tiene_rol_club(club_id,'direccion','secretaria')) with check (public.tiene_rol_club(club_id,'direccion','secretaria'));
create policy preinscripcion_publica on public.preinscripciones for insert with check (exists(select 1 from public.clubes c where c.id=club_id and c.activo));
create policy preinscripciones_lectura on public.preinscripciones for select using (public.tiene_rol_club(club_id,'direccion','secretaria'));
create policy preinscripciones_gestion on public.preinscripciones for update using (public.tiene_rol_club(club_id,'direccion','secretaria')) with check (public.tiene_rol_club(club_id,'direccion','secretaria'));
create policy socio_disc_lectura on public.socio_disciplinas for select using (public.puede_ver_socio(socio_id));
create policy socio_disc_gestion on public.socio_disciplinas for all using (public.tiene_rol_club(club_id,'direccion','secretaria')) with check (public.tiene_rol_club(club_id,'direccion','secretaria'));
create policy graduaciones_lectura on public.graduaciones for select using (public.puede_ver_socio(socio_id));
create policy graduaciones_gestion on public.graduaciones for insert with check (public.tiene_rol_club(club_id,'direccion','secretaria','monitor'));

-- Economía.
create policy tarifas_lectura on public.tarifas for select using (public.es_miembro_club(club_id));
create policy tarifas_gestion on public.tarifas for all using (public.tiene_rol_club(club_id,'direccion','economia')) with check (public.tiene_rol_club(club_id,'direccion','economia'));
create policy historial_tarifas_lectura on public.historial_tarifas for select using (public.tiene_rol_club(club_id,'direccion','economia'));
create policy descuentos_gestion on public.descuentos for all using (public.tiene_rol_club(club_id,'direccion','economia')) with check (public.tiene_rol_club(club_id,'direccion','economia'));
create policy socio_descuentos_gestion on public.socio_descuentos for all using (public.tiene_rol_club(club_id,'direccion','economia')) with check (public.tiene_rol_club(club_id,'direccion','economia'));
create policy cuotas_lectura on public.cuotas for select using (public.puede_ver_socio(socio_id) or public.tiene_rol_club(club_id,'direccion','economia'));
create policy cuotas_gestion on public.cuotas for all using (public.tiene_rol_club(club_id,'direccion','economia')) with check (public.tiene_rol_club(club_id,'direccion','economia'));
create policy pagos_lectura on public.pagos for select using (public.puede_ver_socio(socio_id) or public.tiene_rol_club(club_id,'direccion','economia'));
create policy pagos_insertar on public.pagos for insert with check (public.puede_ver_socio(socio_id));
create policy pagos_validar on public.pagos for update using (public.tiene_rol_club(club_id,'direccion','economia')) with check (public.tiene_rol_club(club_id,'direccion','economia'));

-- Actividad deportiva.
create policy sesiones_lectura on public.sesiones_entrenamiento for select using (public.es_miembro_club(club_id));
create policy sesiones_gestion on public.sesiones_entrenamiento for all using (public.tiene_rol_club(club_id,'direccion','secretaria','monitor')) with check (public.tiene_rol_club(club_id,'direccion','secretaria','monitor'));
create policy asistencia_lectura on public.asistencias for select using (public.puede_ver_socio(socio_id) or public.tiene_rol_club(club_id,'direccion','secretaria','monitor'));
create policy asistencia_gestion on public.asistencias for all using (public.tiene_rol_club(club_id,'direccion','monitor')) with check (public.tiene_rol_club(club_id,'direccion','monitor'));
create policy seguimiento_lectura on public.seguimiento for select using (
  public.tiene_rol_club(club_id,'direccion','secretaria','monitor') or
  (visibilidad='familia' and public.puede_ver_socio(socio_id))
);
create policy seguimiento_gestion on public.seguimiento for all using (public.tiene_rol_club(club_id,'direccion','monitor')) with check (public.tiene_rol_club(club_id,'direccion','monitor'));

-- Comunicación, legal, material y auditoría.
create policy comunicaciones_lectura on public.comunicaciones for select using (public.es_miembro_club(club_id) and estado in ('publicada','programada') or public.tiene_rol_club(club_id,'direccion','comunicacion'));
create policy comunicaciones_gestion on public.comunicaciones for all using (public.tiene_rol_club(club_id,'direccion','comunicacion')) with check (public.tiene_rol_club(club_id,'direccion','comunicacion'));
create policy legales_lectura on public.textos_legales for select using (public.es_miembro_club(club_id));
create policy legales_gestion on public.textos_legales for all using (public.tiene_rol_club(club_id,'direccion','secretaria')) with check (public.tiene_rol_club(club_id,'direccion','secretaria'));
create policy consentimientos_lectura on public.consentimientos for select using (public.puede_ver_socio(socio_id) or public.tiene_rol_club(club_id,'direccion','secretaria'));
create policy consentimientos_insertar on public.consentimientos for insert with check (public.puede_ver_socio(socio_id));
create policy material_lectura on public.material_catalogo for select using (public.es_miembro_club(club_id));
create policy material_gestion on public.material_catalogo for all using (public.tiene_rol_club(club_id,'direccion','economia','secretaria')) with check (public.tiene_rol_club(club_id,'direccion','economia','secretaria'));
create policy variantes_lectura on public.material_variantes for select using (public.es_miembro_club(club_id));
create policy variantes_gestion on public.material_variantes for all using (public.tiene_rol_club(club_id,'direccion','economia','secretaria')) with check (public.tiene_rol_club(club_id,'direccion','economia','secretaria'));
create policy entregas_lectura on public.material_entregas for select using (public.puede_ver_socio(socio_id) or public.tiene_rol_club(club_id,'direccion','economia','secretaria'));
create policy entregas_gestion on public.material_entregas for all using (public.tiene_rol_club(club_id,'direccion','economia','secretaria')) with check (public.tiene_rol_club(club_id,'direccion','economia','secretaria'));
create policy auditoria_lectura on public.auditoria for select using (public.tiene_rol_club(club_id,'direccion'));

-- Auditoría en tablas sensibles.
do $$
declare t text;
begin
  foreach t in array array['socios','preinscripciones','graduaciones','tarifas','cuotas','pagos','consentimientos','miembros_club','config_club'] loop
    execute format('drop trigger if exists trg_audit_%I on public.%I',t,t);
    execute format('create trigger trg_audit_%I after insert or update or delete on public.%I for each row execute function public.registrar_auditoria()',t,t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 10. VISTAS
-- ---------------------------------------------------------------------------
create or replace view public.v_socio_completo as
select s.club_id, s.id, s.nombre || ' ' || s.apellidos as socio, s.fecha_nacimiento,
       extract(year from age(s.fecha_nacimiento))::int as edad, s.estado,
       t.nombre as tarifa, t.importe as importe_tarifa,
       string_agg(d.nombre || coalesce(' (' || g.nombre || ')',''), ', ' order by d.orden) as disciplinas,
       count(sd.id) as num_disciplinas
from public.socios s
left join public.tarifas t on t.club_id=s.club_id and t.id=s.tarifa_id
left join public.socio_disciplinas sd on sd.club_id=s.club_id and sd.socio_id=s.id and sd.activa
left join public.disciplinas d on d.club_id=sd.club_id and d.id=sd.disciplina_id
left join public.grados g on g.club_id=sd.club_id and g.id=sd.grado_id
group by s.club_id,s.id,s.nombre,s.apellidos,s.fecha_nacimiento,s.estado,t.nombre,t.importe;

create or replace view public.v_ocupacion_grupo as
select g.club_id,g.id,d.nombre as disciplina,g.nombre as grupo,g.plazas,
       count(sd.id) as inscritos,
       case when g.plazas is null then null else g.plazas-count(sd.id) end as plazas_libres
from public.grupos g
join public.disciplinas d on d.club_id=g.club_id and d.id=g.disciplina_id
left join public.socio_disciplinas sd on sd.club_id=g.club_id and sd.grupo_id=g.id and sd.activa
where g.activo
group by g.club_id,g.id,d.nombre,g.nombre,g.plazas;

-- ---------------------------------------------------------------------------
-- 11. STORAGE PRIVADO (ignora si no existe el esquema storage)
-- ---------------------------------------------------------------------------
do $$ begin
  insert into storage.buckets(id,name,public) values('documentos-club','documentos-club',false)
  on conflict(id) do nothing;
  insert into storage.buckets(id,name,public) values('justificantes-pago','justificantes-pago',false)
  on conflict(id) do nothing;
exception when undefined_table then null; end $$;

-- No se insertan disciplinas, tarifas ni materiales de producción.
-- Utilizar 002_demo_seed.sql únicamente en entornos de prueba.

alter view public.v_socio_completo set (security_invoker = true);
alter view public.v_ocupacion_grupo set (security_invoker = true);
