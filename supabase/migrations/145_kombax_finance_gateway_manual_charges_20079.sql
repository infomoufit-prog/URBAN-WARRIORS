-- KOMBAX RC13 build 20079 · Finanzas Premium 2.0 · GATE 1/2
-- Gateway versionado para reglas, flags, excepciones y cargos puntuales/masivos.
-- Mantiene intactas todas las operaciones financieras legacy y exige preview
-- autoritativo antes de crear un lote de cargos manuales.

begin;

-- ---------------------------------------------------------------------------
-- 1. Resolver destinatarios de un cargo puntual/masivo.
-- Payload.destinatarios = [{"tipo":"socio","id":"..."},
--                          {"tipo":"grupo","id":"..."},
--                          {"tipo":"disciplina","id":"..."},
--                          {"tipo":"todos"}]
-- La UNION final deduplica al mismo alumno alcanzado por varios scopes.
-- ---------------------------------------------------------------------------
create or replace function public.app_finance_v2_charge_candidates_core_v145(
  p_club_id uuid,p_payload jsonb
) returns table(socio_id uuid,socio_nombre text)
language sql stable security definer set search_path=public,auth
as $$
  with scopes as (
    select lower(coalesce(x->>'tipo','')) tipo,nullif(x->>'id','') id
    from jsonb_array_elements(coalesce(p_payload->'destinatarios','[]'::jsonb)) x
  ), ids as (
    select s.id
    from scopes x
    join public.socios s on x.tipo='socio' and x.id=s.id::text
      and s.club_id=p_club_id and s.estado='activo'

    union
    select s.id
    from scopes x
    join public.socio_disciplinas sd on x.tipo='grupo' and x.id=sd.grupo_id::text
      and sd.club_id=p_club_id and sd.activa
    join public.socios s on s.club_id=sd.club_id and s.id=sd.socio_id and s.estado='activo'

    union
    select s.id
    from scopes x
    join public.socio_disciplinas sd on x.tipo='disciplina' and x.id=sd.disciplina_id::text
      and sd.club_id=p_club_id and sd.activa
    join public.socios s on s.club_id=sd.club_id and s.id=sd.socio_id and s.estado='activo'

    union
    select s.id
    from scopes x
    join public.socios s on x.tipo='todos' and s.club_id=p_club_id and s.estado='activo'
  )
  select s.id,trim(concat_ws(' ',s.nombre,s.apellidos))
  from ids i join public.socios s on s.club_id=p_club_id and s.id=i.id
  order by s.apellidos,s.nombre,s.id;
$$;
revoke all on function public.app_finance_v2_charge_candidates_core_v145(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.app_finance_v2_charge_candidates_core_v145(uuid,jsonb) to service_role,postgres;

create or replace function public.app_finance_v2_charge_preview_core_v145(
  p_club_id uuid,p_payload jsonb
) returns jsonb
language plpgsql stable security definer set search_path=public,auth
as $$
declare
  v_categoria text:=lower(coalesce(nullif(trim(p_payload->>'categoria'),''),'otro'));
  v_concepto text:=trim(coalesce(p_payload->>'concepto',''));
  v_importe numeric(12,2);
  v_periodo date;
  v_vencimiento date;
  v_count integer;
  v_ids text;
  v_rows jsonb;
  v_hash text;
begin
  if v_categoria not in ('cuota','matricula','licencia','material','competicion','evento','desplazamiento','otro') then
    raise exception 'FINANCE_V2_CATEGORIA_INVALIDA';
  end if;
  if nullif(v_concepto,'') is null then raise exception 'FINANCE_V2_CONCEPTO_REQUIRED'; end if;
  begin v_importe:=(p_payload->>'importe')::numeric(12,2); exception when others then raise exception 'FINANCE_V2_IMPORTE_INVALIDO'; end;
  if v_importe is null or v_importe<0 then raise exception 'FINANCE_V2_IMPORTE_INVALIDO'; end if;
  begin v_periodo:=coalesce(nullif(p_payload->>'periodo','')::date,date_trunc('month',current_date)::date); exception when others then raise exception 'FINANCE_V2_PERIODO_INVALIDO'; end;
  begin v_vencimiento:=coalesce(nullif(p_payload->>'vencimiento','')::date,v_periodo); exception when others then raise exception 'FINANCE_V2_VENCIMIENTO_INVALIDO'; end;
  if jsonb_array_length(coalesce(p_payload->'destinatarios','[]'::jsonb))=0 then raise exception 'FINANCE_V2_DESTINATARIOS_REQUIRED'; end if;

  select count(*),coalesce(string_agg(c.socio_id::text,',' order by c.socio_id::text),''),
    coalesce(jsonb_agg(jsonb_build_object('socio_id',c.socio_id,'nombre',c.socio_nombre) order by c.socio_nombre,c.socio_id),'[]'::jsonb)
  into v_count,v_ids,v_rows
  from public.app_finance_v2_charge_candidates_core_v145(p_club_id,p_payload) c;
  if v_count=0 then raise exception 'FINANCE_V2_DESTINATARIOS_SIN_ALUMNOS'; end if;

  v_hash:=encode(digest(
    concat_ws('|','KOMBAX-FINANCE-V2-145',p_club_id::text,v_categoria,v_concepto,
      to_char(v_importe,'FM999999999990.00'),v_periodo::text,v_vencimiento::text,v_ids),
    'sha256'),'hex');

  return jsonb_build_object(
    'ok',true,'preview_hash',v_hash,'categoria',v_categoria,'concepto',v_concepto,
    'importe_individual',v_importe,'periodo',v_periodo,'vencimiento',v_vencimiento,
    'cantidad',v_count,'total',(v_importe*v_count)::numeric(14,2),'destinatarios',v_rows
  );
end $$;
revoke all on function public.app_finance_v2_charge_preview_core_v145(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.app_finance_v2_charge_preview_core_v145(uuid,jsonb) to service_role,postgres;

create or replace function public.app_finance_v2_charge_preview_v145(
  p_club_id uuid,p_payload jsonb
) returns jsonb
language plpgsql stable security definer set search_path=public,auth
as $$
begin
  if not public.app_finance_v2_manage_v143(p_club_id) then raise exception 'FINANCE_V2_FORBIDDEN'; end if;
  return public.app_finance_v2_charge_preview_core_v145(p_club_id,p_payload);
end $$;
revoke all on function public.app_finance_v2_charge_preview_v145(uuid,jsonb) from public,anon;
grant execute on function public.app_finance_v2_charge_preview_v145(uuid,jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Creación manual/masiva autoritativa. El request_id del gateway se usa
-- como lote_id, por lo que retries del mismo request no duplican cargos.
-- ---------------------------------------------------------------------------
create or replace function public.app_finance_v2_create_charge_batch_v145(
  p_club_id uuid,p_payload jsonb,p_request_id uuid
) returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_preview jsonb;
  v_expected text:=coalesce(p_payload->>'preview_hash','');
  v_categoria text;
  v_concepto text;
  v_importe numeric(12,2);
  v_periodo date;
  v_vencimiento date;
  v_created integer:=0;
  v_count integer:=0;
begin
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  if not public.app_finance_v2_manage_v143(p_club_id) then raise exception 'FINANCE_V2_FORBIDDEN'; end if;
  if not public.app_finance_v2_flag_value_v143(p_club_id,'finance_v2_enabled') then raise exception 'FINANCE_V2_DISABLED'; end if;

  v_preview:=public.app_finance_v2_charge_preview_core_v145(p_club_id,p_payload);
  if nullif(v_expected,'') is null then raise exception 'FINANCE_V2_PREVIEW_REQUIRED'; end if;
  if v_expected<>v_preview->>'preview_hash' then raise exception 'FINANCE_V2_PREVIEW_CHANGED'; end if;
  v_categoria:=v_preview->>'categoria';
  v_concepto:=v_preview->>'concepto';
  v_importe:=(v_preview->>'importe_individual')::numeric(12,2);
  v_periodo:=(v_preview->>'periodo')::date;
  v_vencimiento:=(v_preview->>'vencimiento')::date;
  v_count:=(v_preview->>'cantidad')::integer;

  insert into public.cuotas(
    club_id,socio_id,tarifa_id,periodo,concepto,concepto_publico,importe,vencimiento,estado,origen,origen_id,
    categoria_financiera,lote_id,generada_automaticamente,datos_finance_v2
  )
  select p_club_id,c.socio_id,null,v_periodo,
    v_concepto||' ['||left(replace(p_request_id::text,'-',''),8)||']',v_concepto,v_importe,v_vencimiento,'pendiente',
    case when v_categoria='cuota' then 'cuota' when v_categoria='material' then 'material' else 'otro' end,
    p_request_id,v_categoria,p_request_id,false,
    jsonb_build_object('source','manual_batch','request_id',p_request_id,'categoria',v_categoria)
  from public.app_finance_v2_charge_candidates_core_v145(p_club_id,p_payload) c
  on conflict do nothing;
  get diagnostics v_created=row_count;

  -- Push/centro de notificaciones existentes: un aviso agrupado por perfil/tutor.
  insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
  select p_club_id,d.perfil_id,'finance-v2-manual-'||p_request_id::text||'-'||d.perfil_id::text,'aviso_cobro',
    case when count(*)=1 then 'Nuevo cargo disponible' else count(*)::text||' nuevos cargos disponibles' end,
    'Tienes una actualización de pagos en KOMBAX.','fees',
    jsonb_build_object(
      'finance_v2',true,'lote_id',p_request_id,'cantidad',count(*),'deep_link','finance:cargos','requiere_accion',true,
      'cuota_id',case when count(*)=1 then (array_agg(q.id order by q.id::text))[1]::text else null end
    ),auth.uid()
  from public.cuotas q
  join public.socios s on s.club_id=q.club_id and s.id=q.socio_id
  join lateral(
    select coalesce(s.perfil_id,(
      select ts.tutor_perfil_id from public.tutores_socios ts
      where ts.club_id=s.club_id and ts.socio_id=s.id
      order by ts.contacto_principal desc,ts.id limit 1
    )) perfil_id
  ) d on d.perfil_id is not null
  where q.club_id=p_club_id and q.lote_id=p_request_id
  group by d.perfil_id
  on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;

  perform public.app_finance_v2_audit_v143(
    p_club_id,'cargo.masivo.crear','lote_cargo',p_request_id,null,
    jsonb_build_object('categoria',v_categoria,'concepto',v_concepto,'importe',v_importe,'periodo',v_periodo,'vencimiento',v_vencimiento,'esperados',v_count,'creados',v_created),
    jsonb_build_object('preview_hash',v_expected,'request_id',p_request_id)
  );

  return jsonb_build_object('lote_id',p_request_id,'esperados',v_count,'creados',v_created,'preview_hash',v_expected);
end $$;
revoke all on function public.app_finance_v2_create_charge_batch_v145(uuid,jsonb,uuid) from public,anon,authenticated;
grant execute on function public.app_finance_v2_create_charge_batch_v145(uuid,jsonb,uuid) to service_role,postgres;

-- ---------------------------------------------------------------------------
-- 3. Helper de lectura de configuración premium para UI.
-- ---------------------------------------------------------------------------
create or replace function public.app_finance_v2_context_v145(p_club_id uuid)
returns jsonb
language plpgsql stable security definer set search_path=public,auth
as $$
declare v_flags jsonb;v_manage boolean;v_direction boolean;v_pending integer;v_rules integer;
begin
  if auth.uid() is null or not public.es_miembro_club(p_club_id) then raise exception 'FINANCE_V2_MEMBERSHIP_REQUIRED'; end if;
  v_flags:=public.app_finance_v2_flags_v143(p_club_id);
  v_manage:=public.app_finance_v2_manage_v143(p_club_id);
  v_direction:=public.app_finance_v2_direction_v143(p_club_id);
  select count(*) into v_pending from public.pagos where club_id=p_club_id and estado_validacion='pendiente'
    and v_manage;
  select count(*) into v_rules from public.reglas_cobro where club_id=p_club_id and activa and v_manage;
  return v_flags||jsonb_build_object('can_manage',v_manage,'can_direction',v_direction,'pagos_por_validar',v_pending,'reglas_activas',v_rules);
end $$;
revoke all on function public.app_finance_v2_context_v145(uuid) from public,anon;
grant execute on function public.app_finance_v2_context_v145(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Extensión aditiva del contrato y del gateway v160. Toda operación legacy
-- desconocida se delega sin modificar su semántica.
-- ---------------------------------------------------------------------------
do $contract$
begin
  if to_regprocedure('public.app_runtime_contract_v160_pre_finance_v2_145(uuid)') is null then
    if to_regprocedure('public.app_runtime_contract_v160(uuid)') is null then raise exception '145: falta app_runtime_contract_v160'; end if;
    alter function public.app_runtime_contract_v160(uuid) rename to app_runtime_contract_v160_pre_finance_v2_145;
  end if;
end
$contract$;
revoke all on function public.app_runtime_contract_v160_pre_finance_v2_145(uuid) from public,anon,authenticated;

create or replace function public.app_runtime_contract_v160(p_club_id uuid)
returns jsonb
language plpgsql stable security definer set search_path=public,auth
as $$
declare v_base jsonb;v_ops jsonb;
begin
  v_base:=public.app_runtime_contract_v160_pre_finance_v2_145(p_club_id);
  v_ops:=jsonb_build_array(
    'finance.v2.feature.set','finance.v2.rule.save','finance.v2.rule.scopes.replace','finance.v2.exception.save',
    'finance.v2.rule.shadow','finance.v2.rule.generate_now','finance.v2.charge.create'
  );
  return jsonb_set(v_base,'{operations}',coalesce(v_base->'operations','[]'::jsonb)||v_ops,true);
end $$;
revoke all on function public.app_runtime_contract_v160(uuid) from public,anon;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;

do $gateway$
begin
  if to_regprocedure('public.app_mutate_v160_pre_finance_v2_145(text,jsonb,uuid)') is null then
    if to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is null then raise exception '145: falta app_mutate_v160'; end if;
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_finance_v2_145;
  end if;
end
$gateway$;
revoke all on function public.app_mutate_v160_pre_finance_v2_145(text,jsonb,uuid) from public,anon,authenticated;

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
  v_id uuid;
  v_key text;
  v_enabled boolean;
  v_rule public.reglas_cobro;
  v_before jsonb;
  v_scope jsonb;
  v_scope_type text;
  v_scope_id uuid;
  v_exception public.reglas_cobro_excepciones;
begin
  if p_operation not in (
    'finance.v2.feature.set','finance.v2.rule.save','finance.v2.rule.scopes.replace','finance.v2.exception.save',
    'finance.v2.rule.shadow','finance.v2.rule.generate_now','finance.v2.charge.create'
  ) then
    return public.app_mutate_v160_pre_finance_v2_145(p_operation,p_payload,p_request_id);
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
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
    values(p_request_id,v_uid,v_club,p_operation);
  end if;

  if p_operation='finance.v2.feature.set' then
    if not public.app_finance_v2_direction_v143(v_club) then raise exception 'FINANCE_V2_DIRECTION_REQUIRED'; end if;
    v_key:=coalesce(v_payload->>'key','');
    if v_key not in ('finance_v2_enabled','finance_dashboard_v2_enabled','finance_recurring_enabled','finance_reports_enabled') then
      raise exception 'FINANCE_V2_FLAG_INVALID';
    end if;
    begin v_enabled:=coalesce((v_payload->>'enabled')::boolean,false); exception when others then raise exception 'FINANCE_V2_FLAG_VALUE_INVALID'; end;
    if v_enabled and v_key<>'finance_v2_enabled' and not public.app_finance_v2_flag_value_v143(v_club,'finance_v2_enabled') then
      raise exception 'FINANCE_V2_CORE_REQUIRED';
    end if;
    if not v_enabled and v_key='finance_v2_enabled' then
      update public.config_club set valor='false'::jsonb,actualizado_en=now(),actualizado_por=v_uid
      where club_id=v_club and clave in ('finance_dashboard_v2_enabled','finance_recurring_enabled','finance_reports_enabled');
    end if;
    insert into public.config_club(club_id,clave,valor,descripcion,editable_por,actualizado_en,actualizado_por)
    values(v_club,v_key,to_jsonb(v_enabled),'Finanzas Premium 2.0','direccion',now(),v_uid)
    on conflict(club_id,clave) do update set valor=excluded.valor,actualizado_en=now(),actualizado_por=v_uid;
    perform public.app_finance_v2_audit_v143(v_club,'feature.set','config_club',null,null,jsonb_build_object('key',v_key,'enabled',v_enabled),jsonb_build_object('request_id',p_request_id));
    v_data:=public.app_finance_v2_flags_v143(v_club);

  elsif p_operation='finance.v2.rule.save' then
    if not public.app_finance_v2_manage_v143(v_club) then raise exception 'FINANCE_V2_FORBIDDEN'; end if;
    begin v_id:=nullif(v_payload->>'id','')::uuid; exception when others then raise exception 'FINANCE_V2_REGLA_ID_INVALIDA'; end;
    if v_id is not null then select to_jsonb(r),r.* into v_before,v_rule from public.reglas_cobro r where r.club_id=v_club and r.id=v_id for update; end if;
    if v_id is not null and v_rule.id is null then raise exception 'FINANCE_V2_REGLA_NO_ENCONTRADA'; end if;
    if coalesce(nullif(trim(v_payload->>'nombre'),''),'')='' or coalesce(nullif(trim(v_payload->>'concepto'),''),'')='' then raise exception 'FINANCE_V2_REGLA_DATOS_REQUIRED'; end if;
    if lower(coalesce(v_payload->>'categoria','')) not in ('cuota','matricula','licencia','material','competicion','evento','desplazamiento','otro') then raise exception 'FINANCE_V2_CATEGORIA_INVALIDA'; end if;
    if lower(coalesce(v_payload->>'periodicidad','')) not in ('mensual','trimestral','semestral','anual','unica') then raise exception 'FINANCE_V2_PERIODICIDAD_INVALIDA'; end if;
    if v_id is null then
      insert into public.reglas_cobro(
        club_id,tarifa_id,nombre,concepto,categoria,concepto_personalizado,importe,periodicidad,fecha_inicio,fecha_fin,
        dia_generacion,dia_vencimiento,zona_horaria,politica_alta,activa,observaciones,creada_por,actualizado_por
      ) values(
        v_club,nullif(v_payload->>'tarifa_id','')::uuid,trim(v_payload->>'nombre'),trim(v_payload->>'concepto'),lower(v_payload->>'categoria'),nullif(trim(v_payload->>'concepto_personalizado'),''),
        (v_payload->>'importe')::numeric(12,2),lower(v_payload->>'periodicidad'),coalesce(nullif(v_payload->>'fecha_inicio','')::date,current_date),nullif(v_payload->>'fecha_fin','')::date,
        coalesce(nullif(v_payload->>'dia_generacion','')::smallint,1),coalesce(nullif(v_payload->>'dia_vencimiento','')::smallint,10),coalesce(nullif(v_payload->>'zona_horaria',''),'Europe/Madrid'),
        coalesce(nullif(v_payload->>'politica_alta',''),'siguiente_ciclo'),coalesce((v_payload->>'activa')::boolean,true),nullif(v_payload->>'observaciones',''),v_uid,v_uid
      ) returning * into v_rule;
    else
      update public.reglas_cobro set
        tarifa_id=nullif(v_payload->>'tarifa_id','')::uuid,nombre=trim(v_payload->>'nombre'),concepto=trim(v_payload->>'concepto'),categoria=lower(v_payload->>'categoria'),
        concepto_personalizado=nullif(trim(v_payload->>'concepto_personalizado'),''),importe=(v_payload->>'importe')::numeric(12,2),periodicidad=lower(v_payload->>'periodicidad'),
        fecha_inicio=coalesce(nullif(v_payload->>'fecha_inicio','')::date,fecha_inicio),fecha_fin=nullif(v_payload->>'fecha_fin','')::date,
        dia_generacion=coalesce(nullif(v_payload->>'dia_generacion','')::smallint,dia_generacion),dia_vencimiento=coalesce(nullif(v_payload->>'dia_vencimiento','')::smallint,dia_vencimiento),
        zona_horaria=coalesce(nullif(v_payload->>'zona_horaria',''),zona_horaria),politica_alta=coalesce(nullif(v_payload->>'politica_alta',''),politica_alta),
        activa=coalesce((v_payload->>'activa')::boolean,activa),observaciones=nullif(v_payload->>'observaciones',''),version=version+1,actualizado_por=v_uid,actualizado_en=now()
      where club_id=v_club and id=v_id returning * into v_rule;
    end if;
    perform public.app_finance_v2_audit_v143(v_club,case when v_id is null then 'regla.crear' else 'regla.actualizar' end,'regla_cobro',v_rule.id,v_before,to_jsonb(v_rule),jsonb_build_object('request_id',p_request_id));
    v_data:=to_jsonb(v_rule);

  elsif p_operation='finance.v2.rule.scopes.replace' then
    if not public.app_finance_v2_manage_v143(v_club) then raise exception 'FINANCE_V2_FORBIDDEN'; end if;
    begin v_id:=(v_payload->>'regla_id')::uuid; exception when others then raise exception 'FINANCE_V2_REGLA_ID_INVALIDA'; end;
    if not exists(select 1 from public.reglas_cobro where club_id=v_club and id=v_id) then raise exception 'FINANCE_V2_REGLA_NO_ENCONTRADA'; end if;
    if jsonb_array_length(coalesce(v_payload->'destinatarios','[]'::jsonb))=0 then raise exception 'FINANCE_V2_DESTINATARIOS_REQUIRED'; end if;
    select coalesce(jsonb_agg(to_jsonb(d)),'[]'::jsonb) into v_before from public.reglas_cobro_destinatarios d where d.club_id=v_club and d.regla_id=v_id;
    delete from public.reglas_cobro_destinatarios where club_id=v_club and regla_id=v_id;
    for v_scope in select * from jsonb_array_elements(v_payload->'destinatarios') loop
      v_scope_type:=lower(coalesce(v_scope->>'tipo',''));
      if v_scope_type not in ('socio','grupo','disciplina','todos') then raise exception 'FINANCE_V2_SCOPE_INVALID'; end if;
      begin v_scope_id:=nullif(v_scope->>'id','')::uuid; exception when others then raise exception 'FINANCE_V2_SCOPE_ID_INVALID'; end;
      if v_scope_type='socio' and not exists(select 1 from public.socios where club_id=v_club and id=v_scope_id) then raise exception 'FINANCE_V2_SOCIO_INVALID'; end if;
      if v_scope_type='grupo' and not exists(select 1 from public.grupos where club_id=v_club and id=v_scope_id) then raise exception 'FINANCE_V2_GRUPO_INVALID'; end if;
      if v_scope_type='disciplina' and not exists(select 1 from public.disciplinas where club_id=v_club and id=v_scope_id) then raise exception 'FINANCE_V2_DISCIPLINA_INVALID'; end if;
      insert into public.reglas_cobro_destinatarios(club_id,regla_id,tipo,socio_id,grupo_id,disciplina_id,creado_por)
      values(v_club,v_id,v_scope_type,
        case when v_scope_type='socio' then v_scope_id end,
        case when v_scope_type='grupo' then v_scope_id end,
        case when v_scope_type='disciplina' then v_scope_id end,v_uid)
      on conflict do nothing;
    end loop;
    update public.reglas_cobro set version=version+1,actualizado_por=v_uid,actualizado_en=now() where club_id=v_club and id=v_id;
    perform public.app_finance_v2_audit_v143(v_club,'regla.destinatarios.reemplazar','regla_cobro',v_id,v_before,
      (select coalesce(jsonb_agg(to_jsonb(d)),'[]'::jsonb) from public.reglas_cobro_destinatarios d where d.club_id=v_club and d.regla_id=v_id),jsonb_build_object('request_id',p_request_id));
    v_data:=jsonb_build_object('regla_id',v_id,'destinatarios',(select count(*) from public.reglas_cobro_destinatarios where club_id=v_club and regla_id=v_id));

  elsif p_operation='finance.v2.exception.save' then
    if not public.app_finance_v2_manage_v143(v_club) then raise exception 'FINANCE_V2_FORBIDDEN'; end if;
    begin v_id:=nullif(v_payload->>'id','')::uuid; exception when others then raise exception 'FINANCE_V2_EXCEPTION_ID_INVALID'; end;
    if v_id is not null then select to_jsonb(e),e.* into v_before,v_exception from public.reglas_cobro_excepciones e where e.club_id=v_club and e.id=v_id for update; end if;
    if v_id is not null and v_exception.id is null then raise exception 'FINANCE_V2_EXCEPTION_NOT_FOUND'; end if;
    if lower(coalesce(v_payload->>'tipo','')) not in ('excluido','exento','pausa','bonificacion','importe_personalizado','no_generar_ciclo') then raise exception 'FINANCE_V2_EXCEPTION_TYPE_INVALID'; end if;
    if v_id is null then
      insert into public.reglas_cobro_excepciones(club_id,regla_id,socio_id,tipo,importe_personalizado,porcentaje_bonificacion,ciclo,fecha_inicio,fecha_fin,motivo,activa,creada_por,actualizado_por)
      values(v_club,(v_payload->>'regla_id')::uuid,(v_payload->>'socio_id')::uuid,lower(v_payload->>'tipo'),nullif(v_payload->>'importe_personalizado','')::numeric(12,2),
        nullif(v_payload->>'porcentaje_bonificacion','')::numeric(5,2),nullif(v_payload->>'ciclo','')::date,nullif(v_payload->>'fecha_inicio','')::date,nullif(v_payload->>'fecha_fin','')::date,
        coalesce(nullif(trim(v_payload->>'motivo'),''),'Sin motivo indicado'),coalesce((v_payload->>'activa')::boolean,true),v_uid,v_uid)
      returning * into v_exception;
    else
      update public.reglas_cobro_excepciones set tipo=lower(v_payload->>'tipo'),importe_personalizado=nullif(v_payload->>'importe_personalizado','')::numeric(12,2),
        porcentaje_bonificacion=nullif(v_payload->>'porcentaje_bonificacion','')::numeric(5,2),ciclo=nullif(v_payload->>'ciclo','')::date,
        fecha_inicio=nullif(v_payload->>'fecha_inicio','')::date,fecha_fin=nullif(v_payload->>'fecha_fin','')::date,motivo=coalesce(nullif(trim(v_payload->>'motivo'),''),motivo),
        activa=coalesce((v_payload->>'activa')::boolean,activa),actualizado_por=v_uid,actualizado_en=now()
      where club_id=v_club and id=v_id returning * into v_exception;
    end if;
    perform public.app_finance_v2_audit_v143(v_club,case when v_id is null then 'excepcion.crear' else 'excepcion.actualizar' end,'regla_excepcion',v_exception.id,v_before,to_jsonb(v_exception),jsonb_build_object('request_id',p_request_id));
    v_data:=to_jsonb(v_exception);

  elsif p_operation='finance.v2.rule.shadow' then
    if not public.app_finance_v2_manage_v143(v_club) then raise exception 'FINANCE_V2_FORBIDDEN'; end if;
    v_data:=public.app_finance_v2_process_core_v144(v_club,(v_payload->>'regla_id')::uuid,
      coalesce(nullif(v_payload->>'fecha','')::date,current_date),true,coalesce((v_payload->>'force_current')::boolean,false),'shadow',p_request_id);

  elsif p_operation='finance.v2.rule.generate_now' then
    if not public.app_finance_v2_manage_v143(v_club) then raise exception 'FINANCE_V2_FORBIDDEN'; end if;
    if not public.app_finance_v2_flag_value_v143(v_club,'finance_v2_enabled') then raise exception 'FINANCE_V2_DISABLED'; end if;
    v_data:=public.app_finance_v2_process_core_v144(v_club,(v_payload->>'regla_id')::uuid,
      coalesce(nullif(v_payload->>'fecha','')::date,current_date),false,coalesce((v_payload->>'force_current')::boolean,false),'manual',p_request_id);

  else
    v_data:=public.app_finance_v2_create_charge_batch_v145(v_club,v_payload,p_request_id);
  end if;

  v_result:=jsonb_build_object('ok',true,'backend_version','1.6.0','operation',p_operation,'request_id',p_request_id,'data',coalesce(v_data,'{}'::jsonb));
  update public.app_mutation_requests set result=v_result,completed_at=now(),club_id=v_club where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end $$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Verificaciones aditivas de contrato/gateway.
-- ---------------------------------------------------------------------------
create or replace function public.app_finance_v2_gateway_audit_v145()
returns table(control text,ok boolean,detalle text)
language sql security definer set search_path=public,auth
as $$
  select 'gateway anterior preservado',to_regprocedure('public.app_mutate_v160_pre_finance_v2_145(text,jsonb,uuid)') is not null,'legacy delegable'
  union all select 'contrato anterior preservado',to_regprocedure('public.app_runtime_contract_v160_pre_finance_v2_145(uuid)') is not null,'contrato delegable'
  union all select 'preview cargo',to_regprocedure('public.app_finance_v2_charge_preview_v145(uuid,jsonb)') is not null,'preview obligatorio'
  union all select 'batch protegido',to_regclass('public.uq_cuotas_lote_socio_v143') is not null,'request/lote idempotente'
  union all select 'sin activación global',not exists(select 1 from public.config_club where clave='finance_recurring_enabled' and valor='true'::jsonb),'recurrencias opt-in';
$$;
revoke all on function public.app_finance_v2_gateway_audit_v145() from public,anon,authenticated;
grant execute on function public.app_finance_v2_gateway_audit_v145() to service_role,postgres;

notify pgrst,'reload schema';
commit;
