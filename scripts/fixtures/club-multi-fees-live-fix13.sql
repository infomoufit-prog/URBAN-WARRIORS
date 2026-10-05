CREATE OR REPLACE FUNCTION public.comunicar_pago_cuota(p_cuota_id uuid, p_importe numeric, p_fecha date, p_metodo text, p_referencia text DEFAULT NULL::text, p_justificante_path text DEFAULT NULL::text, p_observaciones text DEFAULT NULL::text)
 RETURNS pagos
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare v_cuota public.cuotas; v_pago public.pagos; v_pagado numeric; v_restante numeric;
begin
  select * into v_cuota from public.cuotas where id=p_cuota_id for update;
  if v_cuota.id is null then raise exception 'Cuota no encontrada'; end if;
  if not public.puede_aportar_pago_socio(v_cuota.socio_id) then raise exception 'Sin acceso a esta cuota'; end if;
  if v_cuota.estado in ('pagada','anulada','exenta') then raise exception 'La cuota ya no admite comunicación de pago'; end if;
  if coalesce(p_importe,0)<=0 then raise exception 'El importe debe ser mayor que cero'; end if;
  if p_metodo not in ('transferencia','bizum','efectivo','tarjeta','otro') then raise exception 'Método de pago no válido'; end if;
  if exists(select 1 from public.pagos where cuota_id=v_cuota.id and estado_validacion='pendiente') then
    raise exception 'Ya existe un pago pendiente de validar para esta cuota';
  end if;
  select coalesce(sum(importe),0) into v_pagado from public.pagos where cuota_id=v_cuota.id and estado_validacion='validado';
  v_restante:=greatest(v_cuota.importe-v_pagado,0);
  if p_importe>v_restante+0.005 then raise exception 'El importe supera el saldo pendiente de la cuota'; end if;
  insert into public.pagos(club_id,cuota_id,socio_id,importe,fecha,metodo,referencia,justificante_url,estado_validacion,observaciones,comunicado_por,comunicado_en)
  values(v_cuota.club_id,v_cuota.id,v_cuota.socio_id,p_importe,coalesce(p_fecha,current_date),p_metodo,
    nullif(trim(coalesce(p_referencia,'')),''),nullif(trim(coalesce(p_justificante_path,'')),''),'pendiente',
    nullif(trim(coalesce(p_observaciones,'')),''),auth.uid(),now()) returning * into v_pago;
  update public.cuotas set estado='pendiente_validacion',pago_comunicado_en=now(),avisos_pausados=true,
    motivo_pausa_avisos='Pago comunicado por el usuario',avisos_pausados_hasta=null,avisos_pausados_por=auth.uid(),avisos_pausados_en=now(),actualizado_en=now()
  where id=v_cuota.id;
  insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
  select v_cuota.club_id,rol,'pago-pendiente-'||v_pago.id||'-'||rol::text,'cuota','Justificante pendiente de validar',
    'Un usuario ha comunicado el pago de una mensualidad.','fees',jsonb_build_object('cuota_id',v_cuota.id,'pago_id',v_pago.id),auth.uid()
  from unnest(array['direccion','secretaria','economia']::public.rol_club[]) rol
  on conflict(club_id,rol_destino,clave) where clave is not null and rol_destino is not null do nothing;
  return v_pago;
end; $function$;
CREATE OR REPLACE FUNCTION public.puede_aportar_pago_socio(p_socio_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
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
$function$;
CREATE OR REPLACE FUNCTION public.validar_pago_cuota(p_pago_id uuid, p_decision text, p_motivo text DEFAULT NULL::text)
 RETURNS pagos
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare v_pago public.pagos; v_cuota public.cuotas; v_pagado numeric; v_otros numeric; v_perfil uuid; v_nombre text; v_pagada boolean;
begin
  select * into v_pago from public.pagos where id=p_pago_id for update;
  if v_pago.id is null then raise exception 'Pago no encontrado'; end if;
  if not public.tiene_rol_club(v_pago.club_id,'direccion','secretaria','economia') then raise exception 'Sin permisos'; end if;
  if p_decision not in ('validado','rechazado') then raise exception 'Decisión no válida'; end if;
  if p_decision='rechazado' and nullif(trim(coalesce(p_motivo,'')),'') is null then raise exception 'Indica el motivo del rechazo'; end if;
  if v_pago.estado_validacion=p_decision then return v_pago; end if;
  if v_pago.estado_validacion='validado' and p_decision='rechazado' then raise exception 'Un pago validado no puede rechazarse desde esta operación'; end if;
  select * into v_cuota from public.cuotas where id=v_pago.cuota_id for update;
  if v_cuota.id is null then raise exception 'Cuota no encontrada'; end if;
  if p_decision='validado' then
    select coalesce(sum(importe),0) into v_otros from public.pagos where cuota_id=v_cuota.id and id<>v_pago.id and estado_validacion='validado';
    if v_otros+v_pago.importe>v_cuota.importe+0.005 then raise exception 'La validación superaría el importe total de la cuota'; end if;
  end if;
  update public.pagos set estado_validacion=p_decision,
    validado_por=case when p_decision='validado' then auth.uid() else null end,
    validado_en=case when p_decision='validado' then now() else null end,
    motivo_rechazo=case when p_decision='rechazado' then trim(p_motivo) else null end,
    rechazado_en=case when p_decision='rechazado' then now() else null end
  where id=p_pago_id returning * into v_pago;
  select coalesce(sum(importe),0) into v_pagado from public.pagos where cuota_id=v_cuota.id and estado_validacion='validado';
  v_pagada:=v_pagado>=v_cuota.importe-0.005;
  update public.cuotas set
    estado=case when v_pagada then 'pagada'::public.estado_cuota when v_pagado>0 then 'parcialmente_pagada'::public.estado_cuota else 'pendiente'::public.estado_cuota end,
    avisos_pausados=v_pagada,avisos_pausados_hasta=null,
    motivo_pausa_avisos=case when v_pagada then 'Pago validado' else null end,
    avisos_pausados_por=case when v_pagada then auth.uid() else null end,
    avisos_pausados_en=case when v_pagada then now() else null end,actualizado_en=now()
  where id=v_cuota.id;
  select coalesce(s.perfil_id,t.tutor_perfil_id),trim(s.nombre||' '||s.apellidos) into v_perfil,v_nombre
  from public.socios s
  left join lateral(select tutor_perfil_id from public.tutores_socios where club_id=s.club_id and socio_id=s.id and contacto_principal order by id limit 1)t on true
  where s.id=v_pago.socio_id and s.club_id=v_pago.club_id;
  if v_perfil is not null then
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    values(v_pago.club_id,v_perfil,'pago-'||v_pago.id||'-'||p_decision,'cuota',
      case when p_decision='validado' then 'Pago validado' else 'Justificante no validado' end,
      case when p_decision='validado' then v_nombre||': el pago ha sido registrado correctamente.' else v_nombre||': no se ha podido validar el justificante. '||trim(p_motivo) end,
      'fees',jsonb_build_object('cuota_id',v_cuota.id,'pago_id',v_pago.id),auth.uid())
    on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;
  end if;
  return v_pago;
end; $function$;
CREATE OR REPLACE FUNCTION private.finance_create_manual_charge_v144(p_payload jsonb, p_club uuid, p_uid uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_categoria text:=lower(trim(coalesce(p_payload->>'categoria','otro')));
  v_concepto text:=trim(coalesce(p_payload->>'concepto',''));
  v_importe numeric(10,2):=coalesce((p_payload->>'importe')::numeric,0);
  v_periodo date:=coalesce(nullif(p_payload->>'periodo','')::date,date_trunc('month',current_date)::date);
  v_vencimiento date:=nullif(p_payload->>'vencimiento','')::date;
  v_tarifa uuid:=nullif(p_payload->>'tarifa_id','')::uuid;
  v_dest jsonb:=coalesce(p_payload->'destinatarios','[]'::jsonb);
  v_lote uuid:=gen_random_uuid();
  v_origen text;
  v_count integer:=0;
  v_total numeric(14,2):=0;
  x record;
begin
  if v_categoria not in ('cuota','matricula','licencia','material','competicion','evento','desplazamiento','otro') then
    raise exception 'FINANCE_V2_CATEGORY_INVALID';
  end if;
  if v_concepto='' then raise exception 'FINANCE_V2_CONCEPT_REQUIRED'; end if;
  if v_importe<0 then raise exception 'FINANCE_V2_AMOUNT_INVALID'; end if;
  if v_vencimiento is null then raise exception 'FINANCE_V2_DUE_DATE_REQUIRED'; end if;
  if jsonb_array_length(v_dest)=0 then raise exception 'FINANCE_V2_RECIPIENTS_REQUIRED'; end if;
  v_origen:=case when v_categoria='cuota' then 'cuota' when v_categoria='material' then 'material' else 'otro' end;

  for x in select socio_id from private.finance_manual_recipients_v144(p_club,v_dest)
  loop
    insert into public.cuotas(
      club_id,socio_id,tarifa_id,periodo,concepto,concepto_publico,importe,vencimiento,estado,origen,
      categoria_financiera,generado_automaticamente,lote_cargo_id,snapshot_regla
    ) values (
      p_club,x.socio_id,v_tarifa,v_periodo,v_concepto||' ['||left(v_lote::text,8)||']',v_concepto,v_importe,v_vencimiento,'pendiente',v_origen,
      v_categoria,false,v_lote,jsonb_build_object(
        'tipo','cargo_manual','categoria',v_categoria,'concepto',v_concepto,'importe',v_importe,
        'periodo',v_periodo,'vencimiento',v_vencimiento,'creado_por',p_uid,'creado_en',now(),
        'observaciones',nullif(trim(p_payload->>'observaciones'),'')
      )
    );
    v_count:=v_count+1;
    v_total:=v_total+v_importe;
  end loop;

  if v_count=0 then raise exception 'FINANCE_V2_NO_ELIGIBLE_RECIPIENTS'; end if;

  -- Reuse the existing notification/push pipeline and group by receiving profile/family.
  insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
  select
    q.club_id,
    coalesce(s.perfil_id,t.tutor_perfil_id),
    'finance-v2-manual-'||v_lote::text||'-'||coalesce(s.perfil_id,t.tutor_perfil_id)::text,
    'cuota','Actualización de pagos',
    case when count(*)=1 then 'Tienes un nuevo cargo del club.' else 'Tienes '||count(*)::text||' nuevos cargos del club.' end,
    'fees',
    jsonb_build_object('finance_v2',true,'lote_cargo_id',v_lote,'cantidad',count(*),'cuota_ids',jsonb_agg(q.id),'requiere_accion',true),
    p_uid
  from public.cuotas q
  join public.socios s on s.club_id=q.club_id and s.id=q.socio_id
  left join lateral (
    select ts.tutor_perfil_id from public.tutores_socios ts
    where ts.club_id=s.club_id and ts.socio_id=s.id and ts.contacto_principal
    order by ts.id limit 1
  ) t on true
  where q.club_id=p_club and q.lote_cargo_id=v_lote
    and coalesce(s.perfil_id,t.tutor_perfil_id) is not null
  group by q.club_id,coalesce(s.perfil_id,t.tutor_perfil_id)
  on conflict (club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;

  insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
  values(
    p_club,'economia','finance-v2-manual-batch-'||v_lote::text,'cuota','Cargo masivo generado',
    'Se han creado '||v_count::text||' cargos financieros.','fees',
    jsonb_build_object('finance_v2',true,'lote_cargo_id',v_lote,'cantidad',v_count,'requiere_accion',false),p_uid
  ) on conflict (club_id,rol_destino,clave) where clave is not null and rol_destino is not null do nothing;

  return jsonb_build_object('lote_cargo_id',v_lote,'cargos_creados',v_count,'importe_total',v_total);
end
$function$;
CREATE OR REPLACE FUNCTION private.finance_manual_recipients_v144(p_club_id uuid, p_destinatarios jsonb)
 RETURNS TABLE(socio_id uuid)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
with raw as (
  select elem
  from jsonb_array_elements(coalesce(p_destinatarios,'[]'::jsonb)) elem
), scopes as (
  select
    lower(trim(elem->>'tipo')) as tipo,
    nullif(trim(elem->>'id'),'')::uuid as target_id
  from raw
), candidates as (
  select s.id as socio_id
  from scopes x
  join public.socios s on s.club_id=p_club_id and s.id=x.target_id
  where x.tipo='socio' and s.estado='activo'

  union all

  select sd.socio_id
  from scopes x
  join public.socio_disciplinas sd
    on sd.club_id=p_club_id and sd.grupo_id=x.target_id and sd.activa
  join public.socios s
    on s.club_id=sd.club_id and s.id=sd.socio_id and s.estado='activo'
  where x.tipo='grupo'

  union all

  select sd.socio_id
  from scopes x
  join public.socio_disciplinas sd
    on sd.club_id=p_club_id and sd.disciplina_id=x.target_id and sd.activa
  join public.socios s
    on s.club_id=sd.club_id and s.id=sd.socio_id and s.estado='activo'
  where x.tipo='disciplina'

  union all

  select s.id
  from scopes x
  join public.socios s on s.club_id=p_club_id and s.estado='activo'
  where x.tipo='todos_activos'
)
select distinct c.socio_id from candidates c;
$function$;
