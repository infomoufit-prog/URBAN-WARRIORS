-- ============================================================================
-- URBAN WARRIORS · FASE 1.2
-- Cinco avisos de cobro, pausa administrativa, justificantes y trazabilidad.
-- Aplicar después de 002_access_payments_posts_notifications.sql.
-- ============================================================================

-- 1. Metadatos de la cuota (los estados se añadieron en 003).
alter table public.cuotas add column if not exists avisos_pausados boolean not null default false;
alter table public.cuotas add column if not exists avisos_pausados_hasta date;
alter table public.cuotas add column if not exists motivo_pausa_avisos text;
alter table public.cuotas add column if not exists avisos_pausados_por uuid references public.perfiles(id);
alter table public.cuotas add column if not exists avisos_pausados_en timestamptz;
alter table public.cuotas add column if not exists pago_comunicado_en timestamptz;

alter table public.pagos add column if not exists comunicado_por uuid references public.perfiles(id);
alter table public.pagos add column if not exists comunicado_en timestamptz;
alter table public.pagos add column if not exists motivo_rechazo text;
alter table public.pagos add column if not exists rechazado_en timestamptz;

alter table public.notificaciones add column if not exists push_enviado_en timestamptz;
alter table public.notificaciones add column if not exists push_intentos smallint not null default 0;
alter table public.notificaciones add column if not exists push_error text;

-- 2. Configuración de cinco avisos por club.
create table if not exists public.configuracion_avisos_cuota (
  club_id uuid primary key references public.clubes(id) on delete cascade,
  activo boolean not null default true,
  dias_aviso smallint[] not null default array[1,4,8,11,14]::smallint[],
  hora_envio time not null default '10:00',
  zona_horaria text not null default 'Europe/Madrid',
  canal_app boolean not null default true,
  canal_push boolean not null default true,
  canal_email boolean not null default false,
  agrupar_por_familia boolean not null default true,
  marcar_vencida_dia smallint not null default 15 check (marcar_vencida_dia between 1 and 28),
  actualizado_por uuid references public.perfiles(id),
  actualizado_en timestamptz not null default now(),
  check (cardinality(dias_aviso) = 5),
  check (0 < all(dias_aviso) and 29 > all(dias_aviso))
);

insert into public.configuracion_avisos_cuota(club_id)
select id from public.clubes
on conflict (club_id) do nothing;

create table if not exists public.historial_avisos_cuota (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete cascade,
  cuota_id uuid not null,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  aviso_numero smallint not null check (aviso_numero between 1 and 5),
  fecha_programada date not null,
  canal text not null default 'app' check (canal in ('app','push','email')),
  estado text not null default 'generado' check (estado in ('generado','enviado','leido','cancelado','error')),
  notificacion_id uuid references public.notificaciones(id) on delete set null,
  detalle_error text,
  generado_en timestamptz not null default now(),
  enviado_en timestamptz,
  foreign key (club_id, cuota_id) references public.cuotas(club_id,id) on delete cascade,
  unique (club_id, cuota_id, perfil_id, aviso_numero, canal)
);
create index if not exists idx_historial_avisos_club_fecha
  on public.historial_avisos_cuota(club_id,fecha_programada desc,aviso_numero);

-- 3. Acceso económico: solo el propio alumno, sus tutores o el equipo financiero.
create or replace function public.puede_aportar_pago_socio(p_socio_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists (
    select 1 from public.socios s
    where s.id=p_socio_id
      and (
        s.perfil_id=auth.uid()
        or exists (
          select 1 from public.tutores_socios ts
          where ts.club_id=s.club_id and ts.socio_id=s.id and ts.tutor_perfil_id=auth.uid()
        )
      )
  );
$$;

-- 4. Secretaría, tesorería y dirección pueden gestionar cobros.
drop policy if exists cuotas_lectura on public.cuotas;
drop policy if exists cuotas_gestion on public.cuotas;
drop policy if exists pagos_lectura on public.pagos;
drop policy if exists pagos_insertar on public.pagos;
drop policy if exists pagos_validar on public.pagos;

create policy cuotas_lectura on public.cuotas for select using (
  public.puede_aportar_pago_socio(socio_id)
  or public.tiene_rol_club(club_id,'direccion','secretaria','economia')
);
create policy cuotas_gestion on public.cuotas for all using (
  public.tiene_rol_club(club_id,'direccion','secretaria','economia')
) with check (
  public.tiene_rol_club(club_id,'direccion','secretaria','economia')
);
create policy pagos_lectura on public.pagos for select using (
  public.puede_aportar_pago_socio(socio_id)
  or public.tiene_rol_club(club_id,'direccion','secretaria','economia')
);
create policy pagos_insertar on public.pagos for insert with check (
  public.puede_aportar_pago_socio(socio_id)
  or public.tiene_rol_club(club_id,'direccion','secretaria','economia')
);
create policy pagos_validar on public.pagos for update using (
  public.tiene_rol_club(club_id,'direccion','secretaria','economia')
) with check (
  public.tiene_rol_club(club_id,'direccion','secretaria','economia')
);

alter table public.configuracion_avisos_cuota enable row level security;
alter table public.historial_avisos_cuota enable row level security;

create policy config_avisos_lectura on public.configuracion_avisos_cuota for select using (
  public.es_miembro_club(club_id)
);
create policy config_avisos_gestion on public.configuracion_avisos_cuota for all using (
  public.tiene_rol_club(club_id,'direccion','secretaria','economia')
) with check (
  public.tiene_rol_club(club_id,'direccion','secretaria','economia')
);
create policy historial_avisos_lectura on public.historial_avisos_cuota for select using (
  perfil_id = auth.uid()
  or public.tiene_rol_club(club_id,'direccion','secretaria','economia')
);

-- 5. Storage privado para justificantes: club/socio/archivo.
do $$ begin
  drop policy if exists "justificantes_subir_propios" on storage.objects;
  drop policy if exists "justificantes_leer_autorizados" on storage.objects;
  create policy "justificantes_subir_propios" on storage.objects
    for insert to authenticated with check (
      bucket_id = 'justificantes-pago'
      and array_length(storage.foldername(name),1) >= 2
      and (
        public.puede_aportar_pago_socio(((storage.foldername(name))[2])::uuid)
        or public.tiene_rol_club(((storage.foldername(name))[1])::uuid,'direccion','secretaria','economia')
      )
    );
  create policy "justificantes_leer_autorizados" on storage.objects
    for select to authenticated using (
      bucket_id = 'justificantes-pago'
      and array_length(storage.foldername(name),1) >= 2
      and (
        public.puede_aportar_pago_socio(((storage.foldername(name))[2])::uuid)
        or public.tiene_rol_club(((storage.foldername(name))[1])::uuid,'direccion','secretaria','economia')
      )
    );
exception when undefined_table then null; end $$;

-- 6. Funciones de gestión de avisos y cobros.
create or replace function public.pausar_avisos_cuota(
  p_cuota_id uuid,
  p_motivo text,
  p_hasta date default null
) returns public.cuotas
language plpgsql security definer set search_path=public,auth
as $$
declare v_cuota public.cuotas;
begin
  select * into v_cuota from public.cuotas where id=p_cuota_id;
  if v_cuota.id is null then raise exception 'Cuota no encontrada'; end if;
  if not public.tiene_rol_club(v_cuota.club_id,'direccion','secretaria','economia') then
    raise exception 'Sin permisos para pausar avisos';
  end if;
  if nullif(trim(p_motivo),'') is null then raise exception 'Indica el motivo de la pausa'; end if;
  update public.cuotas set
    avisos_pausados=true,
    avisos_pausados_hasta=p_hasta,
    motivo_pausa_avisos=p_motivo,
    avisos_pausados_por=auth.uid(),
    avisos_pausados_en=now(),
    actualizado_en=now()
  where id=p_cuota_id returning * into v_cuota;
  return v_cuota;
end;
$$;

create or replace function public.reactivar_avisos_cuota(p_cuota_id uuid)
returns public.cuotas
language plpgsql security definer set search_path=public,auth
as $$
declare v_cuota public.cuotas;
begin
  select * into v_cuota from public.cuotas where id=p_cuota_id;
  if v_cuota.id is null then raise exception 'Cuota no encontrada'; end if;
  if not public.tiene_rol_club(v_cuota.club_id,'direccion','secretaria','economia') then
    raise exception 'Sin permisos para reactivar avisos';
  end if;
  update public.cuotas set
    avisos_pausados=false,
    avisos_pausados_hasta=null,
    motivo_pausa_avisos=null,
    avisos_pausados_por=null,
    avisos_pausados_en=null,
    actualizado_en=now()
  where id=p_cuota_id returning * into v_cuota;
  return v_cuota;
end;
$$;

create or replace function public.registrar_cobro_cuota(
  p_cuota_id uuid,
  p_importe numeric,
  p_fecha date,
  p_metodo text,
  p_referencia text default null,
  p_observaciones text default null
) returns public.pagos
language plpgsql security definer set search_path=public,auth
as $$
declare v_cuota public.cuotas; v_pago public.pagos; v_pagado numeric;
begin
  select * into v_cuota from public.cuotas where id=p_cuota_id;
  if v_cuota.id is null then raise exception 'Cuota no encontrada'; end if;
  if not public.tiene_rol_club(v_cuota.club_id,'direccion','secretaria','economia') then
    raise exception 'Sin permisos para registrar cobros';
  end if;
  if p_importe <= 0 then raise exception 'El importe debe ser mayor que cero'; end if;
  insert into public.pagos(
    club_id,cuota_id,socio_id,importe,fecha,metodo,referencia,
    estado_validacion,validado_por,validado_en,observaciones,comunicado_por,comunicado_en
  ) values (
    v_cuota.club_id,v_cuota.id,v_cuota.socio_id,p_importe,coalesce(p_fecha,current_date),p_metodo,p_referencia,
    'validado',auth.uid(),now(),p_observaciones,auth.uid(),now()
  ) returning * into v_pago;
  select coalesce(sum(importe),0) into v_pagado from public.pagos
    where cuota_id=v_cuota.id and estado_validacion='validado';
  update public.cuotas set
    estado=case when v_pagado >= importe then 'pagada'::public.estado_cuota else 'parcialmente_pagada'::public.estado_cuota end,
    avisos_pausados=true,
    motivo_pausa_avisos='Cobro registrado',
    avisos_pausados_por=auth.uid(),
    avisos_pausados_en=now(),
    actualizado_en=now()
  where id=v_cuota.id;
  return v_pago;
end;
$$;

create or replace function public.comunicar_pago_cuota(
  p_cuota_id uuid,
  p_importe numeric,
  p_fecha date,
  p_metodo text,
  p_referencia text default null,
  p_justificante_path text default null,
  p_observaciones text default null
) returns public.pagos
language plpgsql security definer set search_path=public,auth
as $$
declare v_cuota public.cuotas; v_pago public.pagos;
begin
  select * into v_cuota from public.cuotas where id=p_cuota_id;
  if v_cuota.id is null then raise exception 'Cuota no encontrada'; end if;
  if not public.puede_aportar_pago_socio(v_cuota.socio_id) then raise exception 'Sin acceso a esta cuota'; end if;
  if v_cuota.estado in ('pagada','anulada','exenta') then raise exception 'La cuota ya no admite comunicación de pago'; end if;
  if p_importe <= 0 then raise exception 'El importe debe ser mayor que cero'; end if;
  insert into public.pagos(
    club_id,cuota_id,socio_id,importe,fecha,metodo,referencia,justificante_url,
    estado_validacion,observaciones,comunicado_por,comunicado_en
  ) values (
    v_cuota.club_id,v_cuota.id,v_cuota.socio_id,p_importe,coalesce(p_fecha,current_date),p_metodo,p_referencia,p_justificante_path,
    'pendiente',p_observaciones,auth.uid(),now()
  ) returning * into v_pago;
  update public.cuotas set
    estado='pendiente_validacion',
    pago_comunicado_en=now(),
    avisos_pausados=true,
    motivo_pausa_avisos='Pago comunicado por el usuario',
    avisos_pausados_por=auth.uid(),
    avisos_pausados_en=now(),
    actualizado_en=now()
  where id=v_cuota.id;
  insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos)
  select v_cuota.club_id,rol,
    'pago-pendiente-'||v_pago.id||'-'||rol::text,
    'cuota','Justificante pendiente de validar',
    'Un usuario ha comunicado el pago de una mensualidad.','fees',
    jsonb_build_object('cuota_id',v_cuota.id,'pago_id',v_pago.id)
  from unnest(array['direccion','secretaria','economia']::public.rol_club[]) rol;
  return v_pago;
end;
$$;

create or replace function public.validar_pago_cuota(
  p_pago_id uuid,
  p_decision text,
  p_motivo text default null
) returns public.pagos
language plpgsql security definer set search_path=public,auth
as $$
declare v_pago public.pagos; v_cuota public.cuotas; v_pagado numeric; v_perfil uuid; v_nombre text;
begin
  select * into v_pago from public.pagos where id=p_pago_id;
  if v_pago.id is null then raise exception 'Pago no encontrado'; end if;
  if not public.tiene_rol_club(v_pago.club_id,'direccion','secretaria','economia') then raise exception 'Sin permisos'; end if;
  if p_decision not in ('validado','rechazado') then raise exception 'Decisión no válida'; end if;
  if p_decision='rechazado' and nullif(trim(p_motivo),'') is null then raise exception 'Indica el motivo del rechazo'; end if;
  update public.pagos set
    estado_validacion=p_decision,
    validado_por=case when p_decision='validado' then auth.uid() else null end,
    validado_en=case when p_decision='validado' then now() else null end,
    motivo_rechazo=case when p_decision='rechazado' then p_motivo else null end,
    rechazado_en=case when p_decision='rechazado' then now() else null end
  where id=p_pago_id returning * into v_pago;

  select * into v_cuota from public.cuotas where id=v_pago.cuota_id;
  select coalesce(sum(importe),0) into v_pagado from public.pagos
    where cuota_id=v_cuota.id and estado_validacion='validado';
  update public.cuotas set
    estado=case
      when v_pagado >= importe then 'pagada'::public.estado_cuota
      when v_pagado > 0 then 'parcialmente_pagada'::public.estado_cuota
      else 'pendiente'::public.estado_cuota end,
    avisos_pausados=case when p_decision='validado' then true else false end,
    avisos_pausados_hasta=null,
    motivo_pausa_avisos=case when p_decision='validado' then 'Pago validado' else null end,
    avisos_pausados_por=case when p_decision='validado' then auth.uid() else null end,
    avisos_pausados_en=case when p_decision='validado' then now() else null end,
    actualizado_en=now()
  where id=v_cuota.id;

  select coalesce(s.perfil_id,t.tutor_perfil_id), concat_ws(' ',s.nombre,s.apellidos)
    into v_perfil,v_nombre
  from public.socios s
  left join lateral (
    select ts.tutor_perfil_id from public.tutores_socios ts
    where ts.club_id=s.club_id and ts.socio_id=s.id and ts.contacto_principal
    order by ts.id limit 1
  ) t on true
  where s.id=v_pago.socio_id and s.club_id=v_pago.club_id;
  if v_perfil is not null then
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos)
    values(v_pago.club_id,v_perfil,'pago-'||v_pago.id||'-'||p_decision,'cuota',
      case when p_decision='validado' then 'Pago validado' else 'Justificante no validado' end,
      case when p_decision='validado' then v_nombre||': el pago ha sido registrado correctamente.'
           else v_nombre||': no se ha podido validar el justificante. '||p_motivo end,
      'fees',jsonb_build_object('cuota_id',v_cuota.id,'pago_id',v_pago.id))
    on conflict (club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;
  end if;
  return v_pago;
end;
$$;

-- 7. Motor diario idempotente: avisos días 1,4,8,11,14 y vencimiento el 15.
create or replace function public.procesar_avisos_cobro(
  p_fecha date default current_date,
  p_club_id uuid default null
) returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_club record; v_numero smallint; v_generados integer := 0; v_vencidas integer := 0; v_generados_club integer := 0; v_vencidas_club integer := 0;
begin
  for v_club in
    select c.id,c.nombre,coalesce(cfg.dias_aviso,array[1,4,8,11,14]::smallint[]) dias_aviso,
           coalesce(cfg.activo,true) activo,coalesce(cfg.marcar_vencida_dia,15) dia_vencida,
           coalesce(cfg.agrupar_por_familia,true) agrupar_por_familia
    from public.clubes c
    left join public.configuracion_avisos_cuota cfg on cfg.club_id=c.id
    where c.activo and (p_club_id is null or c.id=p_club_id)
  loop
    if not v_club.activo then continue; end if;

    -- Una pausa con fecha final caduca automáticamente antes de procesar el día.
    update public.cuotas set
      avisos_pausados=false,
      avisos_pausados_hasta=null,
      motivo_pausa_avisos=null,
      avisos_pausados_por=null,
      avisos_pausados_en=null,
      actualizado_en=now()
    where club_id=v_club.id
      and avisos_pausados
      and avisos_pausados_hasta is not null
      and avisos_pausados_hasta < p_fecha
      and estado not in ('pagada','anulada','exenta');

    v_numero := array_position(v_club.dias_aviso,extract(day from p_fecha)::smallint);
    if v_numero is not null then
      with pendientes as (
        select q.id cuota_id,q.club_id,q.socio_id,q.importe,q.periodo,q.vencimiento,
               coalesce(s.perfil_id,t.tutor_perfil_id) perfil_id,
               concat_ws(' ',s.nombre,s.apellidos) alumno,
               case when v_club.agrupar_por_familia then coalesce(s.perfil_id,t.tutor_perfil_id)::text else q.id::text end grupo_clave,
               greatest(q.importe-coalesce((select sum(p.importe) from public.pagos p where p.cuota_id=q.id and p.estado_validacion='validado'),0),0) saldo
        from public.cuotas q
        join public.socios s on s.club_id=q.club_id and s.id=q.socio_id
        left join lateral (
          select ts.tutor_perfil_id from public.tutores_socios ts
          where ts.club_id=s.club_id and ts.socio_id=s.id and ts.contacto_principal
          order by ts.id limit 1
        ) t on true
        where q.club_id=v_club.id
          and date_trunc('month',q.periodo)=date_trunc('month',p_fecha)
          and q.estado in ('pendiente','parcialmente_pagada','vencida')
          and not q.avisos_pausados
          and (q.avisos_pausados_hasta is null or q.avisos_pausados_hasta < p_fecha)
      ), agrupadas as (
        select perfil_id,club_id,grupo_clave,sum(saldo) total,string_agg(alumno,', ' order by alumno) alumnos,array_agg(cuota_id) cuotas
        from pendientes where perfil_id is not null and saldo>0 group by perfil_id,club_id,grupo_clave
      ), notifs as (
        insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos)
        select club_id,perfil_id,
          'cobro-'||to_char(p_fecha,'YYYY-MM')||'-aviso-'||v_numero||'-'||perfil_id||'-'||grupo_clave,
          'cuota',
          case v_numero when 1 then 'Mensualidad disponible' when 2 then 'Recordatorio de mensualidad'
            when 3 then 'Mensualidad pendiente' when 4 then 'Regulariza antes del día 15'
            else 'Último recordatorio antes del día 15' end,
          case when cardinality(cuotas)>1 then
            'Tienes '||cardinality(cuotas)||' mensualidades pendientes ('||alumnos||') por un total de '||to_char(total,'FM999999990.00')||' €.'
          else alumnos||': mensualidad pendiente por '||to_char(total,'FM999999990.00')||' €.' end,
          'fees',jsonb_build_object('aviso_numero',v_numero,'cuotas',cuotas,'total',total)
        from agrupadas
        on conflict (club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing
        returning id,club_id,perfil_id,datos
      ), history as (
        insert into public.historial_avisos_cuota(club_id,cuota_id,perfil_id,aviso_numero,fecha_programada,canal,estado,notificacion_id,enviado_en)
        select n.club_id,(jsonb_array_elements_text(n.datos->'cuotas'))::uuid,n.perfil_id,v_numero,p_fecha,'app','enviado',n.id,now()
        from notifs n
        on conflict (club_id,cuota_id,perfil_id,aviso_numero,canal) do nothing
        returning 1
      ) select count(*) into v_generados_club from history;
      v_generados := v_generados + coalesce(v_generados_club,0);
    end if;

    if extract(day from p_fecha)::smallint >= v_club.dia_vencida then
      with upd as (
        update public.cuotas q set estado='vencida',actualizado_en=now()
        where q.club_id=v_club.id
          and date_trunc('month',q.periodo)=date_trunc('month',p_fecha)
          and q.estado in ('pendiente','parcialmente_pagada')
          and not q.avisos_pausados
        returning 1
      ) select count(*) into v_vencidas_club from upd;
      v_vencidas := v_vencidas + coalesce(v_vencidas_club,0);
      if v_vencidas_club>0 then
        insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos)
        select v_club.id,rol,
          'vencidas-'||to_char(p_fecha,'YYYY-MM')||'-'||rol::text,
          'cuota','Cuotas vencidas para revisar',
          v_vencidas_club||' cuota(s) han pasado a estado vencida.','fees',
          jsonb_build_object('cantidad',v_vencidas_club)
        from unnest(array['direccion','secretaria','economia']::public.rol_club[]) rol;
      end if;
    end if;
  end loop;
  return jsonb_build_object('fecha',p_fecha,'avisos_generados',v_generados,'cuotas_vencidas',v_vencidas);
end;
$$;

-- Wrapper manual para dirección/secretaría/tesorería.
create or replace function public.procesar_avisos_cobro_club(p_club_id uuid,p_fecha date default current_date)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
begin
  if not public.tiene_rol_club(p_club_id,'direccion','secretaria','economia') then raise exception 'Sin permisos'; end if;
  return public.procesar_avisos_cobro(p_fecha,p_club_id);
end;
$$;

revoke all on function public.procesar_avisos_cobro(date,uuid) from public,anon,authenticated;
grant execute on function public.procesar_avisos_cobro(date,uuid) to service_role;
grant execute on function public.procesar_avisos_cobro_club(uuid,date) to authenticated;
grant execute on function public.pausar_avisos_cuota(uuid,text,date) to authenticated;
grant execute on function public.reactivar_avisos_cuota(uuid) to authenticated;
grant execute on function public.registrar_cobro_cuota(uuid,numeric,date,text,text,text) to authenticated;
grant execute on function public.comunicar_pago_cuota(uuid,numeric,date,text,text,text,text) to authenticated;
grant execute on function public.validar_pago_cuota(uuid,text,text) to authenticated;
revoke all on function public.puede_aportar_pago_socio(uuid) from public,anon;
grant execute on function public.puede_aportar_pago_socio(uuid) to authenticated;

-- 8. Auditoría de las nuevas tablas.
drop trigger if exists audit_configuracion_avisos on public.configuracion_avisos_cuota;
create trigger audit_configuracion_avisos after insert or update or delete on public.configuracion_avisos_cuota
for each row execute function public.registrar_auditoria();
drop trigger if exists audit_historial_avisos on public.historial_avisos_cuota;
create trigger audit_historial_avisos after insert or update or delete on public.historial_avisos_cuota
for each row execute function public.registrar_auditoria();
