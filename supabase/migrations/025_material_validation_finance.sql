-- 025_material_validation_finance.sql
-- Retirada pendiente, validación atómica, stock, entrega y cargo financiero.

begin;

alter table public.cuotas add column if not exists concepto_publico text;

alter table public.material_pedidos
  add column if not exists precio_unitario numeric(10,2),
  add column if not exists validado_por uuid references public.perfiles(id),
  add column if not exists validado_en timestamptz,
  add column if not exists cuota_id uuid;

alter table public.material_entregas
  add column if not exists pedido_id uuid,
  add column if not exists importe_unitario numeric(10,2),
  add column if not exists importe_total numeric(10,2),
  add column if not exists validado_por uuid references public.perfiles(id),
  add column if not exists validado_en timestamptz;

do $migration$
begin
  if not exists(select 1 from pg_constraint where conname='material_pedidos_cuota_fk' and conrelid='public.material_pedidos'::regclass) then
    alter table public.material_pedidos add constraint material_pedidos_cuota_fk
      foreign key(club_id,cuota_id) references public.cuotas(club_id,id) on delete restrict;
  end if;
  if not exists(select 1 from pg_constraint where conname='material_entregas_pedido_fk' and conrelid='public.material_entregas'::regclass) then
    alter table public.material_entregas add constraint material_entregas_pedido_fk
      foreign key(pedido_id) references public.material_pedidos(id) on delete restrict;
  end if;
end
$migration$;

alter table public.material_pedidos drop constraint if exists material_pedidos_estado_check;
alter table public.material_pedidos add constraint material_pedidos_estado_check
  check(estado in ('reservado','pendiente_validacion','preparado','validado','entregado','cancelado'));

create unique index if not exists uq_material_pedidos_cuota
  on public.material_pedidos(cuota_id) where cuota_id is not null;
create unique index if not exists uq_material_entregas_pedido
  on public.material_entregas(pedido_id) where pedido_id is not null;
create unique index if not exists uq_cuotas_origen_material
  on public.cuotas(club_id,origen,origen_id) where origen='material' and origen_id is not null;
create index if not exists idx_material_pedidos_club_validacion
  on public.material_pedidos(club_id,estado,creado_en desc);

-- La escritura se mantiene exclusivamente detrás del gateway versionado.
revoke insert,update,delete on public.material_pedidos,public.material_entregas from authenticated;
grant select on public.material_pedidos,public.material_entregas to authenticated;

create or replace function public.app_validar_retirada_material_v025(p_pedido_id uuid)
returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_pedido public.material_pedidos;
  v_material public.material_catalogo;
  v_variante public.material_variantes;
  v_cuota uuid;
  v_entrega uuid;
  v_perfil uuid;
  v_alumno text;
  v_concepto text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  select * into v_pedido from public.material_pedidos where id=p_pedido_id for update;
  if v_pedido.id is null then raise exception 'Pedido no encontrado'; end if;
  if not public.tiene_rol_club(v_pedido.club_id,'direccion','secretaria','economia') then
    raise exception 'Solo el equipo autorizado puede validar una retirada';
  end if;
  if v_pedido.estado in ('validado','entregado') and v_pedido.cuota_id is not null then
    return jsonb_build_object('pedido_id',v_pedido.id,'cuota_id',v_pedido.cuota_id,'estado','validado','repetida',true);
  end if;
  if v_pedido.estado not in ('reservado','pendiente_validacion','preparado') then
    raise exception 'El pedido no está pendiente de validación';
  end if;

  select * into v_material from public.material_catalogo
    where club_id=v_pedido.club_id and id=v_pedido.material_id for update;
  if v_material.id is null then raise exception 'Material no encontrado'; end if;

  if v_pedido.variante_id is not null then
    select * into v_variante from public.material_variantes
      where club_id=v_pedido.club_id and id=v_pedido.variante_id and material_id=v_pedido.material_id for update;
    if v_variante.id is null or not v_variante.activa then raise exception 'Variante no disponible'; end if;
    if v_variante.stock<v_pedido.cantidad then raise exception 'Stock insuficiente para validar la retirada'; end if;
    update public.material_variantes set stock=stock-v_pedido.cantidad where id=v_variante.id;
  else
    if v_material.stock<v_pedido.cantidad then raise exception 'Stock insuficiente para validar la retirada'; end if;
    update public.material_catalogo set stock=stock-v_pedido.cantidad where id=v_material.id;
  end if;

  insert into public.material_entregas(
    club_id,socio_id,variante_id,material_id,cantidad,fecha,estado,registrado_por,
    pedido_id,importe_unitario,importe_total,validado_por,validado_en
  ) values(
    v_pedido.club_id,v_pedido.socio_id,v_pedido.variante_id,v_pedido.material_id,v_pedido.cantidad,
    current_date,'entregado',v_uid,v_pedido.id,coalesce(v_pedido.precio_unitario,v_material.precio),
    v_pedido.importe_total,v_uid,now()
  ) returning id into v_entrega;

  v_concepto:='Material: '||v_material.nombre;
  insert into public.cuotas(
    club_id,socio_id,periodo,concepto,concepto_publico,importe,vencimiento,estado,origen,origen_id
  ) values(
    v_pedido.club_id,v_pedido.socio_id,date_trunc('month',current_date)::date,
    v_concepto||' ['||left(v_pedido.id::text,8)||']',v_concepto,v_pedido.importe_total,current_date,
    'pendiente','material',v_pedido.id
  ) returning id into v_cuota;

  update public.material_pedidos set
    estado='validado',validado_por=v_uid,validado_en=now(),cuota_id=v_cuota,actualizado_en=now()
  where id=v_pedido.id;

  select coalesce(s.perfil_id,t.tutor_perfil_id),trim(concat_ws(' ',s.nombre,s.apellidos))
    into v_perfil,v_alumno
  from public.socios s
  left join lateral(
    select ts.tutor_perfil_id from public.tutores_socios ts
    where ts.club_id=s.club_id and ts.socio_id=s.id and ts.contacto_principal
    order by ts.id limit 1
  ) t on true
  where s.club_id=v_pedido.club_id and s.id=v_pedido.socio_id;

  if v_perfil is not null then
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    values(
      v_pedido.club_id,v_perfil,'material-cargo-'||v_pedido.id,'aviso_cobro','Material pendiente',
      'Material pendiente: '||v_material.nombre||' — '||to_char(v_pedido.importe_total,'FM999999990.00')||' €.',
      'fees',jsonb_build_object('pedido_id',v_pedido.id,'cuota_id',v_cuota,'origen','material'),v_uid
    ) on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;
  end if;

  return jsonb_build_object('pedido_id',v_pedido.id,'entrega_id',v_entrega,'cuota_id',v_cuota,'estado','validado');
end
$$;
revoke all on function public.app_validar_retirada_material_v025(uuid) from public,anon,authenticated;

create or replace function public.app_solicitar_material_v025(
  p_club_id uuid,p_socio_id uuid,p_material_id uuid,p_variante_id uuid,
  p_cantidad integer default 1,p_observaciones text default null,p_validar_ahora boolean default false
) returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_socio public.socios;
  v_material public.material_catalogo;
  v_id uuid;
  v_staff boolean;
  v_result jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  select * into v_socio from public.socios where club_id=p_club_id and id=p_socio_id;
  if v_socio.id is null then raise exception 'Alumno no encontrado'; end if;
  v_staff:=public.tiene_rol_club(p_club_id,'direccion','secretaria','economia');
  if not v_staff and not public.puede_aportar_pago_socio(p_socio_id) then raise exception 'No tienes acceso al alumno'; end if;
  if p_validar_ahora and not v_staff then raise exception 'El alumno no puede validar su propia retirada'; end if;
  if coalesce(p_cantidad,0)<=0 then raise exception 'La cantidad debe ser mayor que cero'; end if;
  select * into v_material from public.material_catalogo where club_id=p_club_id and id=p_material_id and activo;
  if v_material.id is null then raise exception 'Material no disponible'; end if;
  if p_variante_id is not null and not exists(
    select 1 from public.material_variantes where club_id=p_club_id and id=p_variante_id and material_id=p_material_id and activa
  ) then raise exception 'Variante no disponible'; end if;

  insert into public.material_pedidos(
    club_id,socio_id,material_id,variante_id,cantidad,precio_unitario,importe_total,estado,observaciones,creado_por
  ) values(
    p_club_id,p_socio_id,p_material_id,p_variante_id,p_cantidad,v_material.precio,
    v_material.precio*p_cantidad,'pendiente_validacion',nullif(trim(coalesce(p_observaciones,'')),''),v_uid
  ) returning id into v_id;

  if p_validar_ahora then
    v_result:=public.app_validar_retirada_material_v025(v_id);
  else
    insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    select p_club_id,rol,'material-validar-'||v_id||'-'||rol::text,'material','Material pendiente de validar',
      trim(concat_ws(' ',v_socio.nombre,v_socio.apellidos))||' ha registrado '||p_cantidad||' × '||v_material.nombre||'.',
      'materials',jsonb_build_object('pedido_id',v_id,'estado','pendiente_validacion'),v_uid
    from unnest(array['direccion','secretaria','economia']::public.rol_club[]) rol;
    v_result:=jsonb_build_object('pedido_id',v_id,'estado','pendiente_validacion');
  end if;
  return v_result;
end
$$;
revoke all on function public.app_solicitar_material_v025(uuid,uuid,uuid,uuid,integer,text,boolean) from public,anon,authenticated;

create or replace function public.app_actualizar_pedido_material_v025(p_pedido_id uuid,p_estado text)
returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_pedido public.material_pedidos;
  v_perfil uuid;
  v_nombre text;
begin
  if p_estado in ('validado','entregado') then return public.app_validar_retirada_material_v025(p_pedido_id); end if;
  select * into v_pedido from public.material_pedidos where id=p_pedido_id for update;
  if v_pedido.id is null then raise exception 'Pedido no encontrado'; end if;
  if not public.tiene_rol_club(v_pedido.club_id,'direccion','secretaria','economia') then raise exception 'No tienes permiso'; end if;
  if v_pedido.estado in ('validado','entregado') then raise exception 'Una retirada validada no puede cambiarse desde pedidos'; end if;
  if p_estado not in ('pendiente_validacion','preparado','cancelado') then raise exception 'Estado no válido'; end if;
  update public.material_pedidos set estado=p_estado,actualizado_en=now() where id=v_pedido.id;

  select coalesce(s.perfil_id,t.tutor_perfil_id),trim(concat_ws(' ',s.nombre,s.apellidos)) into v_perfil,v_nombre
  from public.socios s left join lateral(
    select ts.tutor_perfil_id from public.tutores_socios ts where ts.club_id=s.club_id and ts.socio_id=s.id and ts.contacto_principal order by ts.id limit 1
  ) t on true where s.id=v_pedido.socio_id;
  if v_perfil is not null then
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    values(v_pedido.club_id,v_perfil,'pedido-material-'||v_pedido.id||'-'||p_estado,'material','Pedido '||replace(p_estado,'_',' '),
      v_nombre||': el estado de tu material ha cambiado.','materials',jsonb_build_object('pedido_id',v_pedido.id,'estado',p_estado),v_uid)
    on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;
  end if;
  return jsonb_build_object('pedido_id',v_pedido.id,'estado',p_estado);
end
$$;
revoke all on function public.app_actualizar_pedido_material_v025(uuid,text) from public,anon,authenticated;

-- No se reemplazan vistas financieras en 025. Producción puede conservar
-- columnas compatibles adicionales y 024 ya instaló la capa financiera anual.
-- El nombre limpio queda en concepto_publico y la interfaz oculta el sufijo
-- técnico usado para mantener la unicidad de cargos repetidos del mismo material.

-- Wrapper: conserva las 74 operaciones RC10 e intercepta solo las dos de material.
do $migration$
begin
  if to_regprocedure('public.app_mutate_v160_pre_material_025(text,jsonb,uuid)') is null then
    if to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is null then raise exception '025: falta app_mutate_v160'; end if;
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_material_025;
  end if;
end
$migration$;
revoke all on function public.app_mutate_v160_pre_material_025(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_club uuid;
  v_existing public.app_mutation_requests;
  v_data jsonb;
  v_result jsonb;
begin
  if p_operation not in ('material.solicitar','material.pedido.estado') then
    return public.app_mutate_v160_pre_material_025(p_operation,p_payload,p_request_id);
  end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  begin v_club:=nullif(v_payload->>'club_id','')::uuid; exception when others then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
  if v_club is null or not public.es_miembro_club(v_club) then raise exception 'MUTATION_MEMBERSHIP_REQUIRED'; end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,v_club,p_operation);
  end if;

  if p_operation='material.solicitar' then
    v_data:=public.app_solicitar_material_v025(
      v_club,(v_payload->>'socio_id')::uuid,(v_payload->>'material_id')::uuid,
      nullif(v_payload->>'variante_id','')::uuid,coalesce(nullif(v_payload->>'cantidad','')::integer,1),
      nullif(v_payload->>'observaciones',''),coalesce((v_payload->>'validar_ahora')::boolean,false)
    );
  else
    v_data:=public.app_actualizar_pedido_material_v025((v_payload->>'pedido_id')::uuid,v_payload->>'estado');
  end if;
  v_result:=jsonb_build_object('ok',true,'backend_version','1.6.0','operation',p_operation,'request_id',p_request_id,'data',coalesce(v_data,'{}'::jsonb));
  update public.app_mutation_requests set result=v_result,completed_at=now(),club_id=v_club where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end
$$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;

select
  to_regprocedure('public.app_validar_retirada_material_v025(uuid)') is not null as validacion_ok,
  to_regprocedure('public.app_mutate_v160_pre_material_025(text,jsonb,uuid)') is not null as rollback_ok;
