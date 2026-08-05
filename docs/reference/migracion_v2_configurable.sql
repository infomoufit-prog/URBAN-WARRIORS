-- =====================================================================
-- MIGRACIÓN V2 — Catálogos configurables desde la app
-- Aditiva sobre esquema_club.sql. No destruye nada existente.
-- Principio: ni una disciplina, precio o material escrito en código.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. CONFIGURACIÓN GENERAL DEL CLUB
-- ---------------------------------------------------------------------
-- Clave/valor para que la entidad personalice la app sin desplegar nada:
-- nombre, logo, colores, día de vencimiento, textos legales.
create table config_club (
  clave          text primary key,
  valor          jsonb not null,
  descripcion    text,
  editable_por   area_junta,          -- null = cualquier miembro de junta
  actualizado_en timestamptz not null default now(),
  actualizado_por uuid references perfiles(id)
);

insert into config_club (clave, valor, descripcion, editable_por) values
 ('nombre_club',        '"Club Deportivo"'::jsonb, 'Nombre visible en la app',        'secretaria'),
 ('logo_url',           'null'::jsonb,             'Logotipo (Storage)',              'comunicacion'),
 ('color_primario',     '"#1a3a5c"'::jsonb,        'Color principal de la interfaz',  'comunicacion'),
 ('cif',                'null'::jsonb,             'CIF de la entidad',               'secretaria'),
 ('telefono_contacto',  'null'::jsonb,             'Teléfono del club',               'secretaria'),
 ('bizum_numero',       'null'::jsonb,             'Nº para pagos Bizum (informativo)','economia'),
 ('dia_vencimiento',    '9'::jsonb,                'Día del mes en que vencen cuotas','economia'),
 ('dia_generacion',     '1'::jsonb,                'Día de generación de cuotas',     'economia'),
 ('version_privacidad', '"1.0"'::jsonb,            'Versión del texto de privacidad', 'secretaria'),
 ('texto_privacidad',   '""'::jsonb,               'Política de protección de datos', 'secretaria'),
 ('texto_imagen',       '""'::jsonb,               'Cláusula de derechos de imagen',  'secretaria');

-- ---------------------------------------------------------------------
-- 2. DISCIPLINAS
-- ---------------------------------------------------------------------
create table disciplinas (
  id           bigserial primary key,
  nombre       text not null unique,       -- Muay Thai, Jiu-jitsu, Kickboxing...
  descripcion  text,
  color        text,                       -- para diferenciar en horarios
  icono        text,
  orden        smallint not null default 0,
  activa       boolean not null default true,
  creado_en    timestamptz not null default now()
);

-- Sistema de grados PROPIO de cada disciplina: los cinturones de
-- Jiu-jitsu no equivalen a los de Muay Thai ni al mismo orden.
create table grados (
  id            bigserial primary key,
  disciplina_id bigint not null references disciplinas(id) on delete cascade,
  nombre        text not null,             -- Blanco, Azul, Prajioud rojo...
  nivel         smallint not null,         -- orden de progresión
  color_hex     text,
  activo        boolean not null default true,
  unique (disciplina_id, nivel)
);

-- Grupos / horarios de entrenamiento
create table grupos (
  id            bigserial primary key,
  disciplina_id bigint not null references disciplinas(id) on delete restrict,
  nombre        text not null,             -- Infantil A, Adultos noche...
  monitor       text,
  edad_min      smallint,
  edad_max      smallint,
  plazas        integer,
  activo        boolean not null default true
);

create table horarios_grupo (
  id         bigserial primary key,
  grupo_id   bigint not null references grupos(id) on delete cascade,
  dia_semana smallint not null check (dia_semana between 1 and 7),
  hora_inicio time not null,
  hora_fin    time not null
);

-- ---------------------------------------------------------------------
-- 3. SOCIO ↔ DISCIPLINA (N:N)
-- ---------------------------------------------------------------------
-- Un alumno puede practicar varias artes marciales simultáneamente.
create table socio_disciplinas (
  id            bigserial primary key,
  socio_id      bigint not null references socios(id) on delete cascade,
  disciplina_id bigint not null references disciplinas(id) on delete restrict,
  grupo_id      bigint references grupos(id) on delete set null,
  grado_id      bigint references grados(id) on delete set null,
  fecha_inicio  date not null default current_date,
  fecha_fin     date,
  activa        boolean not null default true,
  unique (socio_id, disciplina_id)
);

create index on socio_disciplinas (disciplina_id, activa);
create index on socio_disciplinas (socio_id);

-- Histórico de graduaciones: los exámenes de cinturón son un dato
-- que el club querrá consultar años después.
create table graduaciones (
  id            bigserial primary key,
  socio_id      bigint not null references socios(id) on delete cascade,
  disciplina_id bigint not null references disciplinas(id),
  grado_id      bigint not null references grados(id),
  fecha         date not null default current_date,
  examinador    text,
  nota          text,
  registrado_por uuid references perfiles(id)
);

-- Los campos antiguos quedan como legado; la fuente de verdad pasa a ser
-- socio_disciplinas. No se borran para no romper datos ya introducidos.
comment on column socios.disciplina is 'OBSOLETO: usar socio_disciplinas';
comment on column socios.grado      is 'OBSOLETO: usar socio_disciplinas.grado_id';

-- ---------------------------------------------------------------------
-- 4. TARIFAS AMPLIADAS
-- ---------------------------------------------------------------------
-- La tarifa es el PLAN contratado, no la disciplina. Así un alumno con
-- dos actividades no rompe la generación de cuotas.
alter table tarifas add column descripcion       text;
alter table tarifas add column num_disciplinas   smallint;   -- null = ilimitado
alter table tarifas add column dias_semana       smallint;
alter table tarifas add column disciplina_id     bigint references disciplinas(id);
alter table tarifas add column edad_min          smallint;
alter table tarifas add column edad_max          smallint;
alter table tarifas add column matricula         numeric(8,2) default 0;
alter table tarifas add column orden             smallint default 0;

-- ---------------------------------------------------------------------
-- 5. MATERIAL POR DISCIPLINA
-- ---------------------------------------------------------------------
-- Guantes y espinilleras para Muay Thai, gi para Jiu-jitsu: el catálogo
-- se filtra por lo que practica cada alumno.
alter table material_catalogo add column disciplina_id bigint references disciplinas(id);
alter table material_catalogo add column categoria     text;   -- equipación, protección, licencia
alter table material_catalogo add column descripcion   text;
alter table material_catalogo add column imagen_url    text;
alter table material_catalogo add column obligatorio   boolean not null default false;
alter table material_catalogo add column referencia    text;
alter table material_catalogo add column orden         smallint default 0;

-- Tallas como catálogo propio: cada material tiene las suyas.
create table material_tallas (
  id          bigserial primary key,
  material_id bigint not null references material_catalogo(id) on delete cascade,
  talla       text not null,
  stock       integer,
  unique (material_id, talla)
);

alter table material_entregas add column talla text;

-- ---------------------------------------------------------------------
-- 6. GENERACIÓN DE CUOTAS RESPETANDO LA CONFIGURACIÓN
-- ---------------------------------------------------------------------
create or replace function generar_cuotas_periodo(p_periodo date default date_trunc('month', current_date)::date)
returns integer language plpgsql security definer as $$
declare
  v_creadas integer;
  v_dia_venc integer;
begin
  select (valor::text)::integer into v_dia_venc
    from config_club where clave = 'dia_vencimiento';
  v_dia_venc := coalesce(v_dia_venc, 9);

  with nuevas as (
    insert into cuotas (socio_id, periodo, concepto, importe, vencimiento)
    select s.id,
           p_periodo,
           'Cuota ' || to_char(p_periodo, 'MM/YYYY'),
           greatest(round(
             t.importe
             - coalesce(t.importe * d.porcentaje / 100, 0)
             - coalesce(d.importe_fijo, 0)
           , 2), 0),
           p_periodo + ((v_dia_venc - 1) || ' days')::interval
      from socios s
      join tarifas t on t.id = s.tarifa_id and t.activa
      left join descuentos d on d.id = s.descuento_id and d.activo
     where s.estado = 'activo'
    on conflict (socio_id, periodo, concepto) do nothing
    returning 1
  )
  select count(*) into v_creadas from nuevas;
  return v_creadas;
end;
$$;

-- ---------------------------------------------------------------------
-- 7. INTEGRIDAD: NUNCA BORRAR, DESACTIVAR
-- ---------------------------------------------------------------------
-- Si una disciplina tiene alumnos o histórico, se desactiva. Borrarla
-- destruiría graduaciones y cuotas pasadas.
create or replace function impedir_borrado_disciplina()
returns trigger language plpgsql as $$
begin
  if exists (select 1 from socio_disciplinas where disciplina_id = old.id)
     or exists (select 1 from graduaciones where disciplina_id = old.id) then
    raise exception 'La disciplina "%" tiene histórico asociado. Desactívala en lugar de borrarla.', old.nombre;
  end if;
  return old;
end;
$$;

create trigger trg_no_borrar_disciplina
  before delete on disciplinas
  for each row execute function impedir_borrado_disciplina();

-- ---------------------------------------------------------------------
-- 8. VISTAS DE APOYO
-- ---------------------------------------------------------------------
create or replace view v_socio_completo as
select s.id,
       s.nombre || ' ' || s.apellidos as socio,
       s.fecha_nacimiento,
       extract(year from age(s.fecha_nacimiento))::int as edad,
       es_menor(s.id) as menor,
       s.estado,
       t.nombre as tarifa,
       t.importe as importe_tarifa,
       string_agg(d.nombre, ', ' order by d.orden) as disciplinas,
       count(sd.id) as num_disciplinas
  from socios s
  left join tarifas t on t.id = s.tarifa_id
  left join socio_disciplinas sd on sd.socio_id = s.id and sd.activa
  left join disciplinas d on d.id = sd.disciplina_id
 group by s.id, t.nombre, t.importe;

create or replace view v_ocupacion_grupo as
select g.id, d.nombre as disciplina, g.nombre as grupo, g.monitor, g.plazas,
       count(sd.id) as inscritos,
       g.plazas - count(sd.id) as plazas_libres
  from grupos g
  join disciplinas d on d.id = g.disciplina_id
  left join socio_disciplinas sd on sd.grupo_id = g.id and sd.activa
 where g.activo
 group by g.id, d.nombre, g.nombre, g.monitor, g.plazas;

-- ---------------------------------------------------------------------
-- 9. RLS DE LOS CATÁLOGOS
-- ---------------------------------------------------------------------
-- Configuración de la actividad: tesorería y secretaría la editan.
-- Presidencia debe tener asignadas ambas áreas si quiere editar.
create or replace function puede_configurar()
returns boolean language sql stable security definer as $$
  select tiene_area('economia') or tiene_area('secretaria');
$$;

alter table config_club        enable row level security;
alter table disciplinas        enable row level security;
alter table grados             enable row level security;
alter table grupos             enable row level security;
alter table horarios_grupo     enable row level security;
alter table socio_disciplinas  enable row level security;
alter table graduaciones       enable row level security;
alter table material_tallas    enable row level security;

create policy config_lectura on config_club for select using (true);
create policy config_gestion on config_club for all
  using (es_junta() and (editable_por is null or tiene_area(editable_por)))
  with check (es_junta() and (editable_por is null or tiene_area(editable_por)));

create policy disc_lectura on disciplinas for select using (true);
create policy disc_gestion on disciplinas for all
  using (puede_configurar()) with check (puede_configurar());

create policy grados_lectura on grados for select using (true);
create policy grados_gestion on grados for all
  using (puede_configurar()) with check (puede_configurar());

create policy grupos_lectura on grupos for select using (true);
create policy grupos_gestion on grupos for all
  using (puede_configurar()) with check (puede_configurar());

create policy horarios_lectura on horarios_grupo for select using (true);
create policy horarios_gestion on horarios_grupo for all
  using (puede_configurar()) with check (puede_configurar());

create policy tallas_lectura on material_tallas for select using (true);
create policy tallas_gestion on material_tallas for all
  using (tiene_area('economia')) with check (tiene_area('economia'));

-- El titular ve las disciplinas de sus socios; secretaría las gestiona.
create policy sd_lectura on socio_disciplinas
  for select using (es_titular_de(socio_id) or es_junta());
create policy sd_gestion on socio_disciplinas for all
  using (tiene_area('secretaria')) with check (tiene_area('secretaria'));

create policy grad_lectura on graduaciones
  for select using (es_titular_de(socio_id) or es_junta());
create policy grad_gestion on graduaciones for all
  using (puede_configurar()) with check (puede_configurar());

-- ---------------------------------------------------------------------
-- 10. SEMILLA DE EJEMPLO (BORRAR ANTES DE ENTREGAR AL CLUB)
-- ---------------------------------------------------------------------
-- Sirve para desarrollo. El club introduce sus datos reales desde el
-- asistente de configuración inicial de la app.
insert into disciplinas (nombre, color, orden) values
 ('Muay Thai',  '#c1272d', 1),
 ('Jiu-jitsu',  '#1a5c8a', 2),
 ('Kickboxing', '#d4820a', 3);

insert into tarifas (nombre, importe, periodicidad, num_disciplinas, orden) values
 ('1 disciplina',   35.00, 'mensual', 1, 1),
 ('2 disciplinas',  50.00, 'mensual', 2, 2),
 ('Ilimitado',      60.00, 'mensual', null, 3);
