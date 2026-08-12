begin;

-- Urban Warriors RC12+ · Comunidad escalable, historial financiero y materiales integrados.
-- Migración aditiva y compatible con el contrato 1.6.0 / schema epoch 160.

-- --------------------------------------------------------------------------
-- 1. COMUNIDAD: metadatos de preview y portada de vídeo
-- --------------------------------------------------------------------------
alter table public.publicaciones_comunidad
  add column if not exists portada_path text,
  add column if not exists media_ancho integer,
  add column if not exists media_alto integer;

create index if not exists publicaciones_comunidad_cursor_idx
  on public.publicaciones_comunidad(club_id,creado_en desc,id desc);

-- --------------------------------------------------------------------------
-- 2. FINANZAS: identificar el origen de cada cargo sin romper cuotas existentes
-- --------------------------------------------------------------------------
alter table public.cuotas
  add column if not exists origen text not null default 'cuota',
  add column if not exists referencia_id uuid;

do $$ begin
  alter table public.cuotas add constraint cuotas_origen_check
    check (origen in ('cuota','material','otro'));
exception when duplicate_object then null; end $$;
create index if not exists cuotas_club_socio_periodo_idx on public.cuotas(club_id,socio_id,periodo desc);
create index if not exists cuotas_club_origen_estado_idx on public.cuotas(club_id,origen,estado,vencimiento);

-- --------------------------------------------------------------------------
-- 3. MATERIAL: trazabilidad, validación y enlace con cargo financiero
-- --------------------------------------------------------------------------
alter table public.material_pedidos
  add column if not exists origen_registro text not null default 'club',
  add column if not exists validacion_estado text not null default 'pendiente',
  add column if not exists validado_por uuid references public.perfiles(id),
  add column if not exists validado_en timestamptz,
  add column if not exists cuota_id uuid,
  add column if not exists entrega_id uuid;

do $$ begin
  alter table public.material_pedidos add constraint material_pedidos_origen_check
    check (origen_registro in ('alumno','familia','club'));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.material_pedidos add constraint material_pedidos_validacion_check
    check (validacion_estado in ('pendiente','validado','rechazado'));
exception when duplicate_object then null; end $$;
create index if not exists material_pedidos_validacion_idx
  on public.material_pedidos(club_id,validacion_estado,creado_en desc);
update public.material_pedidos set validacion_estado='validado',validado_en=coalesce(validado_en,actualizado_en) where estado='entregado' and validacion_estado='pendiente';

-- Estado de cuenta enriquecido: una sola fuente para cuotas + material.
create or replace view public.v_estado_cuenta_socio with (security_invoker=true) as
select
  q.club_id,
  q.socio_id,
  q.id as cuota_id,
  q.periodo,
  q.concepto,
  q.importe,
  q.vencimiento,
  q.estado,
  q.origen,
  q.referencia_id,
  coalesce(pa.pagado_validado,0)::numeric(10,2) as pagado_validado,
  greatest(q.importe-coalesce(pa.pagado_validado,0),0)::numeric(10,2) as saldo,
  pa.ultima_fecha_pago,
  rc.recibo_id,
  rc.recibo_numero,
  rc.recibo_anulado_en
from public.cuotas q
left join lateral (
  select
    coalesce(sum(p.importe) filter(where p.estado_validacion='validado'),0)::numeric(10,2) as pagado_validado,
    max(p.fecha) filter(where p.estado_validacion='validado') as ultima_fecha_pago
  from public.pagos p
  where p.club_id=q.club_id and p.cuota_id=q.id
) pa on true
left join lateral (
  select r.id as recibo_id,r.numero as recibo_numero,r.anulado_en as recibo_anulado_en
  from public.recibos_cuota r
  where r.club_id=q.club_id and r.cuota_id=q.id
  limit 1
) rc on true;
grant select on public.v_estado_cuenta_socio to authenticated;

-- --------------------------------------------------------------------------
-- 4. AVISOS: cualquier cargo pendiente (cuota o material), no solo mensualidad.
--    Los saldos antiguos siguen entrando en los recordatorios del mes actual.
-- --------------------------------------------------------------------------
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

    update public.cuotas set avisos_pausados=false,avisos_pausados_hasta=null,motivo_pausa_avisos=null,
      avisos_pausados_por=null,avisos_pausados_en=null,actualizado_en=now()
    where club_id=v_club.id and avisos_pausados and avisos_pausados_hasta is not null
      and avisos_pausados_hasta < p_fecha and estado not in ('pagada','anulada','exenta');

    v_numero := array_position(v_club.dias_aviso,extract(day from p_fecha)::smallint);
    if v_numero is not null then
      with pendientes as (
        select q.id cuota_id,q.club_id,q.socio_id,q.importe,q.periodo,q.vencimiento,q.concepto,q.origen,
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
          and q.periodo <= date_trunc('month',p_fecha)::date
          and q.estado in ('pendiente','parcialmente_pagada','vencida')
          and not q.avisos_pausados
          and (q.avisos_pausados_hasta is null or q.avisos_pausados_hasta < p_fecha)
      ), agrupadas as (
        select perfil_id,club_id,grupo_clave,sum(saldo) total,
               string_agg(distinct alumno,', ' order by alumno) alumnos,
               string_agg(distinct concepto,' · ' order by concepto) conceptos,
               array_agg(cuota_id) cuotas
        from pendientes where perfil_id is not null and saldo>0 group by perfil_id,club_id,grupo_clave
      ), notifs as (
        insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos)
        select club_id,perfil_id,
          'cobro-'||to_char(p_fecha,'YYYY-MM')||'-aviso-'||v_numero||'-'||perfil_id||'-'||grupo_clave,
          'aviso_cobro','Pago pendiente en Urban Warriors',
          case when cardinality(cuotas)>1 then
            'Tienes '||cardinality(cuotas)||' conceptos pendientes por '||to_char(total,'FM999999990.00')||' €. '||left(conceptos,260)
          else left(conceptos,220)||' pendiente por '||to_char(total,'FM999999990.00')||' €.' end,
          'fees',jsonb_build_object('aviso_numero',v_numero,'cuotas',cuotas,'total',total,'conceptos',conceptos)
        from agrupadas
        on conflict (club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing
        returning id,club_id,perfil_id,datos
      ), history as (
        insert into public.historial_avisos_cuota(club_id,cuota_id,perfil_id,aviso_numero,fecha_programada,canal,estado,notificacion_id,enviado_en)
        select n.club_id,(jsonb_array_elements_text(n.datos->'cuotas'))::uuid,n.perfil_id,v_numero,p_fecha,'app','enviado',n.id,now()
        from notifs n on conflict (club_id,cuota_id,perfil_id,aviso_numero,canal) do nothing returning 1
      ) select count(*) into v_generados_club from history;
      v_generados := v_generados + coalesce(v_generados_club,0);
    end if;

    if extract(day from p_fecha)::smallint >= v_club.dia_vencida then
      with upd as (
        update public.cuotas q set estado='vencida',actualizado_en=now()
        where q.club_id=v_club.id and q.periodo<=date_trunc('month',p_fecha)::date
          and q.estado in ('pendiente','parcialmente_pagada') and not q.avisos_pausados
        returning 1
      ) select count(*) into v_vencidas_club from upd;
      v_vencidas := v_vencidas + coalesce(v_vencidas_club,0);
    end if;
  end loop;
  return jsonb_build_object('fecha',p_fecha,'avisos_generados',v_generados,'cargos_vencidos',v_vencidas);
end;
$$;
revoke all on function public.procesar_avisos_cobro(date,uuid) from public,anon,authenticated;
grant execute on function public.procesar_avisos_cobro(date,uuid) to service_role;

-- --------------------------------------------------------------------------
-- 5. Gateway: preserva RC10 y añade solo operaciones nuevas/interceptadas.
-- --------------------------------------------------------------------------
do $$ begin
  if to_regprocedure('public.app_mutate_v160_v166(text,jsonb,uuid)') is null
     and to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is not null then
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_v166;
  end if;
end $$;
revoke all on function public.app_mutate_v160_v166(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_runtime_contract_v160(p_club_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid(); v_roles jsonb; v_meta public.app_runtime_meta;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  if not public.es_miembro_club(p_club_id) then raise exception 'CLUB_MEMBERSHIP_REQUIRED: la cuenta no pertenece al club activo'; end if;
  select * into v_meta from public.app_runtime_meta where singleton=true;
  select coalesce(jsonb_agg(m.rol order by m.rol::text),'[]'::jsonb) into v_roles from public.miembros_club m where m.club_id=p_club_id and m.perfil_id=v_uid and m.activo;
  return jsonb_build_object('ok',true,'backend_version',v_meta.backend_version,'schema_epoch',v_meta.schema_epoch,'mutation_endpoint',v_meta.mutation_endpoint,'club_id',p_club_id,'user_id',v_uid,'roles',v_roles,'write_ready',true,
    'operations',jsonb_build_array(
      'cuenta.registrar','invitacion.aceptar','invitacion.crear','perfil.guardar','disciplina.guardar','grado.guardar','grupo.guardar','alumno.guardar','preinscripcion.crear','preinscripcion.aprobar','preinscripcion.espera','preinscripcion.rechazar','matricula.solicitar','matricula.desactivar','graduacion.registrar','tarifa.guardar','material.guardar','material.variante.guardar','material.solicitar','material.pedido.estado','material.validar_entrega','material.registrar_entrega','publicacion.guardar','sesion.guardar','asistencia.guardar','checkin.registrar','seguimiento.guardar','documento.registrar','notificacion.leer','pago.comunicar','pago.registrar_admin','pago.validar','cuota.pausar_avisos','cuota.reactivar_avisos','avisos.configurar','cuotas.generar','avisos.procesar','club.configurar','push.registrar','grupo.eliminar','alumno.archivar','alumno.eliminar','preinscripcion.cancelar','preinscripcion.eliminar','sesion.eliminar','disciplina.eliminar','grado.eliminar','tarifa.eliminar','material.eliminar','publicacion.eliminar','recibo.anular','documento.actualizar','documento.archivar','documento.eliminar','grupo.eliminar_forzado','alumno.eliminar_forzado','sesion.eliminar_forzado','disciplina.eliminar_forzado','grado.eliminar_forzado','tarifa.eliminar_forzado','material.eliminar_forzado','publicacion.limpiar_antiguas','sesion.reserva.confirmar','sesion.reserva.cancelar','notificacion.leer_grupo','notificacion.leer_todas','notificaciones.preferencias','sesion.serie.guardar','sesion.excepcion.guardar','sesion.serie.finalizar','sesiones.recurrentes.generar','comunidad.publicar','comunidad.eliminar','comunidad.moderar','perfil.avatar','legal.aceptar'
    ));
end $$;
revoke all on function public.app_runtime_contract_v160(uuid) from public,anon;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid(); v_payload jsonb:=coalesce(p_payload,'{}'::jsonb); v_club uuid; v_existing public.app_mutation_requests; v_result jsonb;
  v_id uuid; v_order public.material_pedidos; v_item public.material_catalogo; v_variant public.material_variantes; v_post public.publicaciones_comunidad;
  v_socio uuid; v_material uuid; v_variant_id uuid; v_qty integer; v_total numeric(10,2); v_source text; v_entrega uuid; v_cuota uuid; v_staff boolean;
begin
  if p_operation not in ('material.solicitar','material.pedido.estado','material.validar_entrega','material.registrar_entrega','comunidad.publicar','comunidad.eliminar') then
    return public.app_mutate_v160_v166(p_operation,p_payload,p_request_id);
  end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  begin v_club:=nullif(v_payload->>'club_id','')::uuid; exception when others then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
  if v_club is null or not public.es_miembro_club(v_club) then raise exception 'MUTATION_MEMBERSHIP_REQUIRED'; end if;
  select exists(select 1 from public.miembros_club m where m.club_id=v_club and m.perfil_id=v_uid and m.activo and (m.rol in ('direccion','secretaria','economia') or m.coordinacion=true)) into v_staff;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,v_club,p_operation); end if;

  if p_operation='material.solicitar' then
    v_socio:=(v_payload->>'socio_id')::uuid; v_material:=(v_payload->>'material_id')::uuid;
    v_variant_id:=nullif(v_payload->>'variante_id','')::uuid; v_qty:=greatest(coalesce(nullif(v_payload->>'cantidad','')::int,1),1);
    if not public.puede_ver_socio(v_socio) and not v_staff then raise exception 'No puedes registrar material para este alumno'; end if;
    select * into v_item from public.material_catalogo where club_id=v_club and id=v_material and activo;
    if v_item.id is null then raise exception 'Material no disponible'; end if;
    if v_variant_id is not null then select * into v_variant from public.material_variantes where club_id=v_club and id=v_variant_id and material_id=v_material and activa; if v_variant.id is null then raise exception 'Variante no disponible'; end if; end if;
    v_total:=round(v_item.precio*v_qty,2); v_source:=case when v_staff then 'club' when exists(select 1 from public.miembros_club where club_id=v_club and perfil_id=v_uid and rol='familia' and activo) then 'familia' else 'alumno' end;
    insert into public.material_pedidos(club_id,socio_id,material_id,variante_id,cantidad,importe_total,estado,observaciones,creado_por,origen_registro,validacion_estado)
    values(v_club,v_socio,v_material,v_variant_id,v_qty,v_total,'reservado',left(coalesce(v_payload->>'observaciones',''),800),v_uid,v_source,case when v_staff then 'validado' else 'pendiente' end)
    returning * into v_order;
    if not v_staff then
      insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
      select v_club,r,'material-validar-'||v_order.id||'-'||r::text,'material','Material pendiente de validación',v_item.nombre||' · '||v_qty||' ud.','material',jsonb_build_object('pedido_id',v_order.id),v_uid
      from unnest(array['direccion','secretaria']::public.rol_club[]) r on conflict do nothing;
    end if;
    v_result:=to_jsonb(v_order);

  elsif p_operation in ('material.validar_entrega','material.registrar_entrega') then
    if not v_staff then raise exception 'Solo coordinación, secretaría, economía o dirección pueden validar entregas'; end if;
    if p_operation='material.validar_entrega' then
      v_id:=(v_payload->>'pedido_id')::uuid;
      select * into v_order from public.material_pedidos where club_id=v_club and id=v_id for update;
      if v_order.id is null then raise exception 'Pedido no encontrado'; end if;
      if v_order.validacion_estado='validado' and v_order.cuota_id is not null then v_result:=to_jsonb(v_order); else
        v_socio:=v_order.socio_id; v_material:=v_order.material_id; v_variant_id:=v_order.variante_id; v_qty:=v_order.cantidad; v_total:=v_order.importe_total;
      end if;
    else
      v_socio:=(v_payload->>'socio_id')::uuid; v_material:=(v_payload->>'material_id')::uuid; v_variant_id:=nullif(v_payload->>'variante_id','')::uuid; v_qty:=greatest(coalesce(nullif(v_payload->>'cantidad','')::int,1),1);
      select * into v_item from public.material_catalogo where club_id=v_club and id=v_material and activo; if v_item.id is null then raise exception 'Material no disponible'; end if;
      v_total:=round(v_item.precio*v_qty,2);
      insert into public.material_pedidos(club_id,socio_id,material_id,variante_id,cantidad,importe_total,estado,observaciones,creado_por,origen_registro,validacion_estado)
      values(v_club,v_socio,v_material,v_variant_id,v_qty,v_total,'reservado',left(coalesce(v_payload->>'observaciones',''),800),v_uid,'club','pendiente') returning * into v_order;
    end if;
    if v_result is null then
      select * into v_item from public.material_catalogo where club_id=v_club and id=v_material;
      if v_item.id is null then raise exception 'Material no encontrado'; end if;
      if v_variant_id is not null then
        select * into v_variant from public.material_variantes where club_id=v_club and id=v_variant_id for update;
        if v_variant.id is null then raise exception 'Variante no encontrada'; end if;
        if v_variant.stock<v_qty then raise exception 'Stock insuficiente'; end if;
        update public.material_variantes set stock=stock-v_qty where id=v_variant.id;
      end if;
      insert into public.material_entregas(club_id,socio_id,variante_id,material_id,cantidad,fecha,estado,registrado_por)
      values(v_club,v_socio,v_variant_id,v_material,v_qty,current_date,'entregado',v_uid) returning id into v_entrega;
      insert into public.cuotas(club_id,socio_id,tarifa_id,periodo,concepto,importe,vencimiento,estado,origen,referencia_id)
      values(v_club,v_socio,null,date_trunc('month',current_date)::date,'Material: '||v_item.nombre||' · '||v_qty||' ud. · #'||substr(v_order.id::text,1,8),v_total,current_date,'pendiente','material',v_order.id)
      returning id into v_cuota;
      update public.material_pedidos set estado='entregado',validacion_estado='validado',validado_por=v_uid,validado_en=now(),cuota_id=v_cuota,entrega_id=v_entrega,actualizado_en=now() where id=v_order.id returning * into v_order;
      insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
      select v_club,coalesce(s.perfil_id,t.tutor_perfil_id),'material-cargo-'||v_order.id,'material','Material registrado',v_item.nombre||' · pendiente de pago: '||to_char(v_total,'FM999999990.00')||' €.','fees',jsonb_build_object('pedido_id',v_order.id,'cuota_id',v_cuota,'importe',v_total),v_uid
      from public.socios s left join lateral(select tutor_perfil_id from public.tutores_socios ts where ts.club_id=s.club_id and ts.socio_id=s.id and ts.contacto_principal order by ts.id limit 1)t on true
      where s.club_id=v_club and s.id=v_socio and coalesce(s.perfil_id,t.tutor_perfil_id) is not null on conflict do nothing;
      v_result:=to_jsonb(v_order);
    end if;

  elsif p_operation='material.pedido.estado' then
    v_id:=(v_payload->>'pedido_id')::uuid;
    if coalesce(v_payload->>'estado','')='entregado' then
      -- Para entregar siempre exigimos validación financiera y trazabilidad.
      v_result := public.app_mutate_v160('material.validar_entrega',jsonb_build_object('club_id',v_club,'pedido_id',v_id),gen_random_uuid())->'data';
    else
      return public.app_mutate_v160_v166(p_operation,p_payload,p_request_id);
    end if;

  elsif p_operation='comunidad.publicar' then
    -- La validación base sigue en RC10; añadimos portada y dimensiones al registro creado.
    delete from public.app_mutation_requests where request_id=p_request_id and result is null;
    v_result:=public.app_mutate_v160_v166(p_operation,p_payload,p_request_id);
    v_id:=nullif(v_result->'data'->>'id','')::uuid;
    if v_id is not null then
      update public.publicaciones_comunidad set portada_path=nullif(v_payload->>'portada_path',''),media_ancho=nullif(v_payload->>'media_ancho','')::int,media_alto=nullif(v_payload->>'media_alto','')::int where id=v_id and club_id=v_club returning * into v_post;
      v_result:=jsonb_set(v_result,'{data}',to_jsonb(v_post),true);
      update public.app_mutation_requests set result=v_result,completed_at=now(),club_id=v_club where request_id=p_request_id;
    end if;
    return v_result;

  elsif p_operation='comunidad.eliminar' then
    delete from public.app_mutation_requests where request_id=p_request_id and result is null;
    v_result:=public.app_mutate_v160_v166(p_operation,p_payload,p_request_id);
    -- El cliente recibe también la portada para eliminarla del bucket.
    return v_result;
  end if;

  v_result:=jsonb_build_object('ok',true,'backend_version','1.6.0','operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));
  update public.app_mutation_requests set result=v_result,completed_at=now(),club_id=v_club where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end $$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
