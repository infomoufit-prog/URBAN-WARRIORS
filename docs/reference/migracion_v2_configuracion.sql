-- =====================================================================
-- MIGRACIÓN v2 — MÓDULO DE CONFIGURACIÓN
-- Todo el contenido del club (disciplinas, grados, tarifas, material,
-- horarios y textos legales) pasa a ser editable desde la app por la
-- junta. Cero datos maestros escritos en el código.
--
-- Aplicar DESPUÉS de esquema_club.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. DISCIPLINAS
-- ---------------------------------------------------------------------
create table disciplinas (
  id           bigserial primary key,
  nombre       text not null unique,       -- Muay Thai, Jiu-jitsu, Kickboxing...
  descripcion  text,
  color        text default '#334155',     -- identificación visual en la app
  imagen_url   text,
  edad_minima  smallint,
  activa       boolean not null default true,
  orden        smallint not null default 0,
  creado_en    timestamptz not null default now()
);

-- Escala de grados PROPIA de cada disciplina.
-- Muay Thai puede no tener ninguna; jiu-jitsu tendrá una decena.
create table grados (
  id             bigserial primary key,
  disciplina_id  bigint not null references disciplinas(id) on delete cascade,
  nombre         text not null,            -- 'Cinturón azul', 'Prajioud rojo'...
  orden          smallint not null,        -- 1 = inicial
  color          text,
  meses_minimos  smallint,                 -- permanencia orientativa
  activo         boolean not null default true,
  unique (disciplina_id, orden),
  unique (disciplina_id, nombre)
);

-- ---------------------------------------------------------------------
-- 2. SOCIO ↔ DISCIPLINA (muchos a muchos)
-- ---------------------------------------------------------------------
create table socio_disciplinas (
  id             bigserial primary key,
  socio_id       bigint not null references socios(id) on delete cascade,
  disciplina_id  bigint not null references disciplinas(id) on delete restrict,
  grado_id       bigint references grados(id),
  fecha_inicio   date not null default current_date,
  fecha_fin      date,
  activa         boolean not null default true,
  unique (socio_id, disciplina_id)
);

create index on socio_disciplinas (disciplina_id) where activa;

-- Historial de graduaciones: en un club de artes marciales esto es
-- patrimonio del socio, no un dato descartable.
create table graduaciones (
  id             bigserial primary key,
  socio_id       bigint not null references socios(id) on delete cascade,
  disciplina_id  bigint not null references disciplinas(id),
  grado_id       bigint not null references grados(id),
  fecha          date not null default current_date,
  examinador     text,
  nota           text,
  registrado_por uuid references perfiles(id)
);

create index on graduaciones (socio_id, fecha desc);

-- Al registrar una graduación, se actualiza el grado actual.
create or replace function actualizar_grado_actual()
returns trigger language plpgsql as $$
begin
  update socio_disciplinas
     set grado_id = new.grado_id
   where socio_id = new.socio_id
     and disciplina_id = new.disciplina_id;
  return new;
end;
$$;

create trigger trg_grado_actual
  after insert on graduaciones
  for each row execute function actualizar_grado_actual();

-- Sustituye los campos de texto libre de la v1.
alter table socios drop column if exists disciplina;
alter table socios drop column if exists grado;

-- ---------------------------------------------------------------------
-- 3. TARIFAS AMPLIADAS
-- ---------------------------------------------------------------------
alter table tarifas add column if not exists descripcion        text;
alter table tarifas add column if not exists dias_semana        smallint;
alter table tarifas add column if not exists num_disciplinas    smallint;
alter table tarifas add column if not exists disciplina_id      bigint references disciplinas(id);
alter table tarifas add column if not exists orden              smallint default 0;
alter table tarifas add column if not exists actualizada_en     timestamptz default now();
alter table tarifas add column if not exists actualizada_por    uuid references perfiles(id);

-- disciplina_id NULL = tarifa general (vale para cualquier disciplina).
-- num_disciplinas = tarifas combinadas ('2 disciplinas', 'ilimitado').

-- Historial de precios: si sube la cuota en septiembre, las cuotas ya
-- emitidas mantienen su importe y queda constancia del cambio.
create table historial_tarifas (
  id              bigserial primary key,
  tarifa_id       bigint not null references tarifas(id) on delete cascade,
  importe_anterior numeric(8,2),
  importe_nuevo    numeric(8,2) not null,
  motivo          text,
  cambiado_por    uuid references perfiles(id),
  cambiado_en     timestamptz not null default now()
);

create or replace function registrar_cambio_tarifa()
returns trigger language plpgsql as $$
begin
  if new.importe is distinct from old.importe then
    insert into historial_tarifas (tarifa_id, importe_anterior, importe_nuevo, cambiado_por)
    values (new.id, old.importe, new.importe, auth.uid());
    new.actualizada_en := now();
    new.actualizada_por := auth.uid();
  end if;
  return new;
end;
$$;

create trigger trg_historial_tarifa
  before update on tarifas
  for each row execute function registrar_cambio_tarifa();

-- ---------------------------------------------------------------------
-- 4. MATERIAL POR DISCIPLINA
-- ---------------------------------------------------------------------
alter table material_catalogo add column if not exists disciplina_id bigint references disciplinas(id);
alter table material_catalogo add column if not exists descripcion   text;
alter table material_catalogo add column if not exists imagen_url    text;
alter table material_catalogo add column if not exists obligatorio   boolean not null default false;
alter table material_catalogo add column if not exists orden         smallint default 0;

-- Tallas como variantes: un kimono no es un artículo por talla.
create table material_variantes (
  id           bigserial primary key,
  material_id  bigint not null references material_catalogo(id) on delete cascade,
  talla        text not null,
  stock        integer default 0,
  activa       boolean not null default true,
  unique (material_id, talla)
);

alter table material_entregas add column if not exists variante_id bigint references material_variantes(id);

-- ---------------------------------------------------------------------
-- 5. HORARIOS Y CLASES
-- ---------------------------------------------------------------------
create table clases (
  id             bigserial primary key,
  disciplina_id  bigint not null references disciplinas(id) on delete cascade,
  nombre         text not null,            -- 'Infantil', 'Adultos avanzado'
  dia_semana     smallint not null check (dia_semana between 1 and 7),
  hora_inicio    time not null,
  hora_fin       time not null,
  instructor     text,
  sala           text,
  edad_min       smallint,
  edad_max       smallint,
  plazas         integer,
  activa         boolean not null default true,
  check (hora_fin > hora_inicio)
);

create index on clases (disciplina_id, dia_semana);

-- ---------------------------------------------------------------------
-- 6. DATOS DEL CLUB Y TEXTOS LEGALES
-- ---------------------------------------------------------------------
-- Tabla de una sola fila, forzada por constraint.
create table config_club (
  id                 boolean primary key default true check (id),
  nombre             text not null default '',
  cif                text,
  direccion          text,
  telefono           text,
  email              text,
  web                text,
  logo_url           text,
  bizum_telefono     text,                 -- para instrucciones de pago manual
  iban               text,
  instrucciones_pago text,
  actualizado_en     timestamptz default now()
);

insert into config_club (id) values (true) on conflict do nothing;

-- Textos de consentimiento versionados y editables por secretaría.
-- Enlaza con consentimientos.version_texto de la v1.
create table textos_legales (
  id          bigserial primary key,
  tipo        tipo_consent not null,
  version     text not null,
  cuerpo      text not null,
  vigente     boolean not null default false,
  creado_por  uuid references perfiles(id),
  creado_en   timestamptz not null default now(),
  unique (tipo, version)
);

-- Sólo un texto vigente por tipo.
create unique index textos_vigente_unico
  on textos_legales (tipo) where vigente;

-- ---------------------------------------------------------------------
-- 7. RLS
-- ---------------------------------------------------------------------
-- Criterio: la CONFIGURACIÓN (catálogos, precios, disciplinas, horarios)
-- la edita cualquier miembro de la junta. Los DATOS ECONÓMICOS de cada
-- socio (marcar una cuota como pagada) siguen restringidos a tesorería.
-- Separar ambas cosas evita cuellos de botella sin perder trazabilidad.

alter table disciplinas         enable row level security;
alter table grados              enable row level security;
alter table socio_disciplinas   enable row level security;
alter table graduaciones        enable row level security;
alter table material_variantes  enable row level security;
alter table clases              enable row level security;
alter table config_club         enable row level security;
alter table textos_legales      enable row level security;
alter table historial_tarifas   enable row level security;

-- Catálogos: lectura para todos los autenticados, edición para la junta.
create policy disciplinas_lectura on disciplinas for select using (true);
create policy disciplinas_gestion on disciplinas for all
  using (es_junta()) with check (es_junta());

create policy grados_lectura on grados for select using (true);
create policy grados_gestion on grados for all
  using (es_junta()) with check (es_junta());

create policy clases_lectura on clases for select using (true);
create policy clases_gestion on clases for all
  using (es_junta()) with check (es_junta());

create policy variantes_lectura on material_variantes for select using (true);
create policy variantes_gestion on material_variantes for all
  using (es_junta()) with check (es_junta());

create policy config_lectura on config_club for select using (true);
create policy config_gestion on config_club for all
  using (es_junta()) with check (es_junta());

create policy textos_lectura on textos_legales for select using (true);
create policy textos_gestion on textos_legales for all
  using (es_junta()) with check (es_junta());

-- Matrícula del socio: la ve su titular; la modifica secretaría.
create policy sd_lectura on socio_disciplinas
  for select using (es_titular_de(socio_id) or es_junta());
create policy sd_gestion on socio_disciplinas for all
  using (tiene_area('secretaria')) with check (tiene_area('secretaria'));

-- Graduaciones: visibles para la familia, registrables por la junta.
create policy grad_lectura on graduaciones
  for select using (es_titular_de(socio_id) or es_junta());
create policy grad_gestion on graduaciones for all
  using (es_junta()) with check (es_junta());

-- Historial de tarifas: sólo lectura, y sólo para la junta.
create policy hist_lectura on historial_tarifas
  for select using (es_junta());

-- ---------------------------------------------------------------------
-- 8. VISTA DE APOYO
-- ---------------------------------------------------------------------
create or replace view v_socio_completo as
select s.id,
       s.nombre || ' ' || s.apellidos as socio,
       s.fecha_nacimiento,
       es_menor(s.id) as menor,
       s.estado,
       string_agg(d.nombre || coalesce(' (' || g.nombre || ')', ''), ', '
                  order by d.orden) as disciplinas,
       count(sd.id) as num_disciplinas
  from socios s
  left join socio_disciplinas sd on sd.socio_id = s.id and sd.activa
  left join disciplinas d on d.id = sd.disciplina_id
  left join grados g on g.id = sd.grado_id
 group by s.id, s.nombre, s.apellidos, s.fecha_nacimiento, s.estado;

-- =====================================================================
-- NOTA: este script NO inserta disciplinas, tarifas ni material.
-- La app arranca con un asistente de configuración inicial que guía a
-- la junta para darlos de alta. El club es dueño de sus datos maestros.
-- =====================================================================
