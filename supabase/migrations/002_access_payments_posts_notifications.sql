-- ============================================================================
-- URBAN WARRIORS · FASE 1.1
-- Acceso general, cuentas de adultos/tutores, check-in, publicaciones,
-- pedidos de material y notificaciones. Aplicar después de 001_phase1_complete.
-- ============================================================================

-- 1. Registro y preinscripción vinculados a una cuenta autenticada.
alter table public.preinscripciones add column if not exists solicitante_perfil_id uuid references public.perfiles(id) on delete set null;
alter table public.preinscripciones add column if not exists tipo_solicitud text check (tipo_solicitud in ('adulto','menor'));
alter table public.preinscripciones add column if not exists parentesco text;
create index if not exists idx_preinscripciones_solicitante on public.preinscripciones(solicitante_perfil_id, club_id);

-- El solicitante puede consultar sus propias solicitudes.
create policy preinscripciones_solicitante_lectura on public.preinscripciones
  for select using (solicitante_perfil_id = auth.uid());

-- Catálogos no sensibles visibles antes del registro para construir el formulario.
create policy clubes_publico_registro on public.clubes for select using (activo);
create policy disciplinas_publico_registro on public.disciplinas for select
  using (activa and exists(select 1 from public.clubes c where c.id = club_id and c.activo));
create policy grupos_publico_registro on public.grupos for select
  using (activo and exists(select 1 from public.clubes c where c.id = club_id and c.activo));
create policy horarios_publico_registro on public.horarios_grupo for select
  using (exists(select 1 from public.clubes c where c.id = club_id and c.activo));
create policy tarifas_publico_registro on public.tarifas for select
  using (activa and exists(select 1 from public.clubes c where c.id = club_id and c.activo));

-- Crea la pertenencia básica y una solicitud. No permite asignarse roles internos.
create or replace function public.registrar_cuenta_club(
  p_club_slug text,
  p_tipo_cuenta text,
  p_adulto_nombre text,
  p_adulto_apellidos text,
  p_telefono text,
  p_fecha_nacimiento_adulto date default null,
  p_menor_nombre text default null,
  p_menor_apellidos text default null,
  p_fecha_nacimiento_menor date default null,
  p_disciplina_id uuid default null,
  p_grupo_id uuid default null,
  p_tarifa_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_club_id uuid;
  v_socio_id uuid;
  v_rol public.rol_club;
  v_nombre text;
  v_apellidos text;
  v_fecha date;
  v_email text := coalesce(auth.jwt() ->> 'email', '');
begin
  if v_uid is null then raise exception 'Debes autenticarte antes de completar el registro'; end if;
  if p_tipo_cuenta not in ('adulto','tutor') then raise exception 'Tipo de cuenta no permitido'; end if;

  select id into v_club_id from public.clubes where slug = p_club_slug and activo limit 1;
  if v_club_id is null then raise exception 'Club no disponible'; end if;

  if p_disciplina_id is not null and not exists (
    select 1 from public.disciplinas where id = p_disciplina_id and club_id = v_club_id and activa
  ) then raise exception 'Disciplina no válida para este club'; end if;
  if p_grupo_id is not null and not exists (
    select 1 from public.grupos where id = p_grupo_id and club_id = v_club_id and activo
  ) then raise exception 'Grupo no válido para este club'; end if;
  if p_tarifa_id is not null and not exists (
    select 1 from public.tarifas where id = p_tarifa_id and club_id = v_club_id and activa
  ) then raise exception 'Tarifa no válida para este club'; end if;

  insert into public.perfiles(id, nombre, apellidos, telefono)
  values (v_uid, p_adulto_nombre, p_adulto_apellidos, p_telefono)
  on conflict (id) do update set
    nombre = excluded.nombre, apellidos = excluded.apellidos,
    telefono = excluded.telefono, actualizado_en = now();

  v_rol := case when p_tipo_cuenta = 'adulto' then 'alumno'::public.rol_club else 'familia'::public.rol_club end;
  insert into public.miembros_club(club_id, perfil_id, rol, activo)
  values (v_club_id, v_uid, v_rol, true)
  on conflict (club_id, perfil_id, rol) do update set activo = true;

  if p_tipo_cuenta = 'adulto' then
    v_nombre := p_adulto_nombre; v_apellidos := p_adulto_apellidos; v_fecha := p_fecha_nacimiento_adulto;
    insert into public.socios(club_id, perfil_id, nombre, apellidos, fecha_nacimiento, telefono, email, estado, tarifa_id)
    values (v_club_id, v_uid, v_nombre, v_apellidos, v_fecha, p_telefono, v_email, 'prealta', p_tarifa_id)
    returning id into v_socio_id;
  else
    if nullif(trim(p_menor_nombre), '') is null or nullif(trim(p_menor_apellidos), '') is null then
      raise exception 'Faltan los datos del menor';
    end if;
    v_nombre := p_menor_nombre; v_apellidos := p_menor_apellidos; v_fecha := p_fecha_nacimiento_menor;
    insert into public.socios(club_id, nombre, apellidos, fecha_nacimiento, estado, tarifa_id)
    values (v_club_id, v_nombre, v_apellidos, v_fecha, 'prealta', p_tarifa_id)
    returning id into v_socio_id;
    insert into public.tutores_socios(club_id, tutor_perfil_id, socio_id, parentesco, contacto_principal)
    values (v_club_id, v_uid, v_socio_id, 'Tutor/a responsable', true);
  end if;

  if p_disciplina_id is not null then
    insert into public.socio_disciplinas(club_id, socio_id, disciplina_id, grupo_id, activa)
    values (v_club_id, v_socio_id, p_disciplina_id, p_grupo_id, true);
  end if;

  insert into public.preinscripciones(
    club_id, solicitante_perfil_id, tipo_solicitud, nombre, apellidos,
    fecha_nacimiento, tutor_nombre, tutor_email, telefono,
    disciplina_id, grupo_id, tarifa_id, estado
  ) values (
    v_club_id, v_uid, case when p_tipo_cuenta='adulto' then 'adulto' else 'menor' end,
    v_nombre, v_apellidos, v_fecha,
    case when p_tipo_cuenta='tutor' then concat_ws(' ',p_adulto_nombre,p_adulto_apellidos) else null end,
    v_email, p_telefono, p_disciplina_id, p_grupo_id, p_tarifa_id, 'enviada'
  );

  return jsonb_build_object('club_id',v_club_id,'socio_id',v_socio_id,'rol',v_rol,'estado','enviada');
end;
$$;
revoke all on function public.registrar_cuenta_club(text,text,text,text,text,date,text,text,date,uuid,uuid,uuid) from public;
grant execute on function public.registrar_cuenta_club(text,text,text,text,text,date,text,text,date,uuid,uuid,uuid) to authenticated;

-- 2. Publicaciones con imágenes, carteles y eventos.
alter table public.comunicaciones add column if not exists tipo text not null default 'noticia'
  check (tipo in ('noticia','evento','clase','cartel'));
alter table public.comunicaciones add column if not exists imagen_url text;
alter table public.comunicaciones add column if not exists evento_fecha timestamptz;
alter table public.comunicaciones add column if not exists ubicacion text;
alter table public.comunicaciones add column if not exists destacado boolean not null default false;

-- 3. Registro de acceso/check-in a sesiones.
alter table public.sesiones_entrenamiento add column if not exists codigo_acceso text;
create unique index if not exists sesiones_codigo_club_unico
  on public.sesiones_entrenamiento(club_id, codigo_acceso) where codigo_acceso is not null;

create table if not exists public.registros_acceso_clase (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  sesion_id uuid not null,
  socio_id uuid not null,
  metodo text not null default 'codigo' check (metodo in ('codigo','qr','manual','nfc')),
  resultado text not null default 'permitido' check (resultado in ('permitido','denegado')),
  registrado_en timestamptz not null default now(),
  dispositivo text,
  registrado_por uuid references public.perfiles(id),
  foreign key (club_id, sesion_id) references public.sesiones_entrenamiento(club_id,id) on delete cascade,
  foreign key (club_id, socio_id) references public.socios(club_id,id) on delete cascade,
  unique (club_id, sesion_id, socio_id)
);
create index if not exists idx_accesos_club_fecha on public.registros_acceso_clase(club_id, registrado_en desc);
alter table public.registros_acceso_clase enable row level security;
create policy accesos_lectura on public.registros_acceso_clase for select using (
  public.puede_ver_socio(socio_id) or public.tiene_rol_club(club_id,'direccion','secretaria','monitor')
);
create policy accesos_registro_usuario on public.registros_acceso_clase for insert with check (
  public.puede_ver_socio(socio_id) and exists (
    select 1 from public.sesiones_entrenamiento s
    where s.id = sesion_id and s.club_id = club_id and s.fecha = current_date and s.estado <> 'cancelada'
  )
);
create policy accesos_gestion_equipo on public.registros_acceso_clase for all using (
  public.tiene_rol_club(club_id,'direccion','secretaria','monitor')
) with check (public.tiene_rol_club(club_id,'direccion','secretaria','monitor'));

-- 4. Pedidos de material.
create table if not exists public.material_pedidos (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  socio_id uuid not null,
  material_id uuid not null,
  variante_id uuid,
  cantidad integer not null default 1 check (cantidad > 0),
  importe_total numeric(10,2) not null check (importe_total >= 0),
  estado text not null default 'reservado' check (estado in ('reservado','preparado','entregado','cancelado')),
  observaciones text,
  creado_por uuid references public.perfiles(id),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  foreign key (club_id, socio_id) references public.socios(club_id,id) on delete restrict,
  foreign key (club_id, material_id) references public.material_catalogo(club_id,id) on delete restrict,
  foreign key (variante_id) references public.material_variantes(id) on delete set null
);
create index if not exists idx_material_pedidos_club_estado on public.material_pedidos(club_id,estado,creado_en desc);
alter table public.material_pedidos enable row level security;
create policy material_pedidos_lectura on public.material_pedidos for select using (
  public.puede_ver_socio(socio_id) or public.tiene_rol_club(club_id,'direccion','secretaria','economia')
);
create policy material_pedidos_solicitar on public.material_pedidos for insert with check (public.puede_ver_socio(socio_id));
create policy material_pedidos_gestion on public.material_pedidos for update using (
  public.tiene_rol_club(club_id,'direccion','secretaria','economia')
) with check (public.tiene_rol_club(club_id,'direccion','secretaria','economia'));

-- 5. Centro de notificaciones y preparación de push.
create table if not exists public.notificaciones (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  perfil_id uuid references public.perfiles(id) on delete cascade,
  rol_destino public.rol_club,
  audiencia text,
  clave text,
  tipo text not null default 'sistema',
  titulo text not null,
  cuerpo text not null,
  ruta text,
  datos jsonb not null default '{}'::jsonb,
  leida boolean not null default false,
  leida_en timestamptz,
  programada_para timestamptz,
  creada_por uuid references public.perfiles(id),
  creado_en timestamptz not null default now()
);
create index if not exists idx_notificaciones_perfil on public.notificaciones(perfil_id,leida,creado_en desc);
create unique index if not exists notificaciones_clave_perfil_unica
  on public.notificaciones(club_id,perfil_id,clave) where clave is not null and perfil_id is not null;
alter table public.notificaciones enable row level security;
create policy notificaciones_propias on public.notificaciones for select using (
  perfil_id = auth.uid()
  or (rol_destino is not null and public.tiene_rol_club(club_id,rol_destino))
  or (audiencia='todos' and public.es_miembro_club(club_id))
);
create policy notificaciones_marcar on public.notificaciones for update using (perfil_id=auth.uid())
  with check (perfil_id=auth.uid());
create policy notificaciones_gestion on public.notificaciones for all using (
  public.tiene_rol_club(club_id,'direccion','secretaria','economia','comunicacion')
) with check (public.tiene_rol_club(club_id,'direccion','secretaria','economia','comunicacion'));

create table if not exists public.dispositivos_push (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  plataforma text not null check (plataforma in ('web','android','ios')),
  token text not null,
  activo boolean not null default true,
  ultimo_uso timestamptz not null default now(),
  creado_en timestamptz not null default now(),
  unique (club_id,perfil_id,token)
);
alter table public.dispositivos_push enable row level security;
create policy dispositivos_propios on public.dispositivos_push for all using (perfil_id=auth.uid()) with check (perfil_id=auth.uid());

-- Generación idempotente de alertas de vencimiento. Puede ejecutarse por cron diario.
create or replace function public.generar_alertas_cuotas(p_club_id uuid, p_dias integer default 5)
returns integer
language plpgsql
security definer
set search_path = public, auth
as $$
declare v_insertadas integer;
begin
  if not public.tiene_rol_club(p_club_id,'direccion','economia') then
    raise exception 'Sin permisos para generar alertas';
  end if;
  with destinatarios as (
    select c.id cuota_id, c.club_id, c.socio_id, c.importe, c.vencimiento,
           coalesce(s.perfil_id,t.tutor_perfil_id) perfil_id,
           s.nombre
    from public.cuotas c
    join public.socios s on s.club_id=c.club_id and s.id=c.socio_id
    left join lateral (
      select ts.tutor_perfil_id from public.tutores_socios ts
      where ts.club_id=s.club_id and ts.socio_id=s.id and ts.contacto_principal
      order by ts.id limit 1
    ) t on true
    where c.club_id=p_club_id and c.estado in ('pendiente','parcialmente_pagada','vencida')
      and c.vencimiento <= current_date + greatest(p_dias,0)
  ), nuevas as (
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta)
    select club_id,perfil_id,'cuota-'||cuota_id,'cuota',
           case when vencimiento < current_date then 'Mensualidad vencida' else 'Próximo vencimiento' end,
           nombre||': '||to_char(importe,'FM999999990.00')||' € · vence '||to_char(vencimiento,'DD/MM/YYYY'),
           'fees'
    from destinatarios where perfil_id is not null
    on conflict (club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing
    returning 1
  ) select count(*) into v_insertadas from nuevas;
  return v_insertadas;
end;
$$;

-- Notificar automáticamente cuando economía valida un pago.
create or replace function public.notificar_pago_validado()
returns trigger language plpgsql security definer set search_path=public,auth as $$
declare v_perfil uuid; v_nombre text;
begin
  if new.estado_validacion='validado' and old.estado_validacion is distinct from new.estado_validacion then
    select coalesce(s.perfil_id,t.tutor_perfil_id),s.nombre into v_perfil,v_nombre
    from public.socios s
    left join lateral (
      select ts.tutor_perfil_id from public.tutores_socios ts
      where ts.club_id=s.club_id and ts.socio_id=s.id and ts.contacto_principal limit 1
    ) t on true
    where s.club_id=new.club_id and s.id=new.socio_id;
    if v_perfil is not null then
      insert into public.notificaciones(club_id,perfil_id,tipo,titulo,cuerpo,ruta)
      values(new.club_id,v_perfil,'cuota','Pago validado',v_nombre||': pago de '||to_char(new.importe,'FM999999990.00')||' € validado.','fees');
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists trg_notificar_pago_validado on public.pagos;
create trigger trg_notificar_pago_validado after update of estado_validacion on public.pagos
for each row execute function public.notificar_pago_validado();

-- Auditoría adicional.
drop trigger if exists audit_material_pedidos on public.material_pedidos;
create trigger audit_material_pedidos after insert or update or delete on public.material_pedidos
for each row execute function public.registrar_auditoria();
drop trigger if exists audit_registros_acceso on public.registros_acceso_clase;
create trigger audit_registros_acceso after insert or update or delete on public.registros_acceso_clase
for each row execute function public.registrar_auditoria();
