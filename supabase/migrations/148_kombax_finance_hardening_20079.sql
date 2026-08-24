-- KOMBAX RC13 build 20079 · Finanzas Premium 2.0 · HARDENING
-- Refuerza filtros compartidos, observabilidad del scheduler y obliga a shadow
-- por versión de regla antes de cualquier automatización real.

begin;

-- ---------------------------------------------------------------------------
-- 1. Cross-filtering real: KPI/gráficos/tabla/informes comparten el mismo focus.
-- ---------------------------------------------------------------------------
create or replace function public.app_finance_v2_filtered_core_v146(p_club_id uuid,p_filters jsonb default '{}'::jsonb)
returns setof public.v_finanzas_detalle_v2
language sql stable security definer set search_path=public,auth
as $$
  select v.*
  from public.v_finanzas_detalle_v2 v
  where v.club_id=p_club_id
    and (nullif(p_filters->>'year','') is null or v.anio=(p_filters->>'year')::integer)
    and (nullif(p_filters->>'month','') is null or v.mes=(p_filters->>'month')::integer)
    and (nullif(p_filters->>'date_from','') is null or v.periodo>=(p_filters->>'date_from')::date)
    and (nullif(p_filters->>'date_to','') is null or v.periodo<=(p_filters->>'date_to')::date)
    and (nullif(p_filters->>'socio_id','') is null or v.socio_id=(p_filters->>'socio_id')::uuid)
    and (nullif(p_filters->>'grupo_id','') is null or (p_filters->>'grupo_id')::uuid=any(v.grupo_ids))
    and (nullif(p_filters->>'disciplina_id','') is null or (p_filters->>'disciplina_id')::uuid=any(v.disciplina_ids))
    and (nullif(p_filters->>'categoria','') is null or v.categoria=p_filters->>'categoria')
    and (nullif(p_filters->>'estado','') is null or v.estado::text=p_filters->>'estado')
    and (nullif(p_filters->>'tarifa_id','') is null or v.tarifa_id=(p_filters->>'tarifa_id')::uuid)
    and (nullif(p_filters->>'regla_id','') is null or v.regla_cobro_id=(p_filters->>'regla_id')::uuid)
    and (nullif(p_filters->>'vencimiento_desde','') is null or v.vencimiento>=(p_filters->>'vencimiento_desde')::date)
    and (nullif(p_filters->>'vencimiento_hasta','') is null or v.vencimiento<=(p_filters->>'vencimiento_hasta')::date)
    and (nullif(p_filters->>'aging','') is null or v.antiguedad_deuda=p_filters->>'aging')
    and (
      nullif(p_filters->>'metodo','') is null or exists(
        select 1 from public.pagos p
        where p.club_id=v.club_id and p.cuota_id=v.cuota_id and p.estado_validacion='validado' and p.metodo=p_filters->>'metodo'
      )
    )
    and (
      nullif(p_filters->>'focus','') is null or p_filters->>'focus' in ('all','generado')
      or (p_filters->>'focus'='cobrado' and v.estado::text not in ('anulada','exenta') and v.saldo<=0)
      or (p_filters->>'focus'='pendiente' and v.estado::text not in ('pagada','anulada','exenta') and v.saldo>0)
      or (p_filters->>'focus'='vencido' and v.estado::text not in ('pagada','anulada','exenta') and v.saldo>0 and v.vencimiento<current_date)
      or (p_filters->>'focus'='avisos_pausados' and exists(select 1 from public.cuotas q where q.club_id=v.club_id and q.id=v.cuota_id and coalesce(q.avisos_pausados,false)))
    );
$$;
revoke all on function public.app_finance_v2_filtered_core_v146(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.app_finance_v2_filtered_core_v146(uuid,jsonb) to service_role,postgres;

-- ---------------------------------------------------------------------------
-- 2. Shadow por versión: modificar una regla invalida la simulación anterior.
-- ---------------------------------------------------------------------------
create or replace function public.app_finance_v2_shadow_ready_v148(p_club_id uuid,p_regla_id uuid,p_fecha date default current_date)
returns boolean
language plpgsql stable security definer set search_path=public,auth
as $$
declare r public.reglas_cobro;v_cycle date;
begin
  select * into r from public.reglas_cobro where club_id=p_club_id and id=p_regla_id;
  if r.id is null then return false; end if;
  v_cycle:=public.app_finance_v2_cycle_for_v144(r.periodicidad,r.fecha_inicio,p_fecha);
  return exists(
    select 1 from public.finanzas_ejecuciones_regla e
    where e.club_id=p_club_id and e.regla_id=p_regla_id and e.shadow and e.estado='completada'
      and e.ciclo=v_cycle and coalesce((e.detalle->>'rule_version')::integer,0)=r.version
  );
end $$;
revoke all on function public.app_finance_v2_shadow_ready_v148(uuid,uuid,date) from public,anon,authenticated;
grant execute on function public.app_finance_v2_shadow_ready_v148(uuid,uuid,date) to service_role,postgres;

-- Scheduler robusto: si falta shadow de la versión vigente, no escribe y crea
-- un único aviso accionable. Los errores sí quedan registrados fuera del lote.
create or replace function public.app_finance_v2_scheduler_v144(p_ahora timestamptz default now())
returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  r public.reglas_cobro;v_local_date date;v_cycle date;v_generation date;v_result jsonb;
  v_runs integer:=0;v_errors integer:=0;v_skipped integer:=0;v_error text;
begin
  for r in
    select rc.* from public.reglas_cobro rc
    where rc.activa
      and public.app_finance_v2_flag_value_v143(rc.club_id,'finance_v2_enabled')
      and public.app_finance_v2_flag_value_v143(rc.club_id,'finance_recurring_enabled')
    order by rc.club_id,rc.id
  loop
    begin
      v_local_date:=(p_ahora at time zone r.zona_horaria)::date;
      if v_local_date<r.fecha_inicio or (r.fecha_fin is not null and v_local_date>r.fecha_fin) then continue; end if;
      v_cycle:=public.app_finance_v2_cycle_for_v144(r.periodicidad,r.fecha_inicio,v_local_date);
      v_generation:=case when r.periodicidad='unica' then r.fecha_inicio else public.app_finance_v2_day_in_month_v144(v_cycle,r.dia_generacion) end;
      if v_local_date<v_generation then continue; end if;
      if exists(select 1 from public.finanzas_ejecuciones_regla e where e.club_id=r.club_id and e.regla_id=r.id and e.ciclo=v_cycle and not e.shadow and e.estado='completada' and e.detalle->>'source'='scheduler') then continue; end if;
      if not public.app_finance_v2_shadow_ready_v148(r.club_id,r.id,v_local_date) then
        v_skipped:=v_skipped+1;
        insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos)
        select r.club_id,rol,'finance-v2-shadow-required-'||r.id::text||'-v'||r.version::text||'-'||rol::text,'sistema',
          'Automatización pendiente de simulación','Una regla financiera ha cambiado o aún no se ha validado en modo simulación.','fees',
          jsonb_build_object('finance_v2',true,'regla_id',r.id,'finance_target','automation','entity_id',r.id,'deep_link','finance:automation','requiere_accion',true)
        from unnest(array['direccion','economia']::public.rol_club[]) rol
        on conflict(club_id,rol_destino,clave) where clave is not null and rol_destino is not null do nothing;
        continue;
      end if;
      v_result:=public.app_finance_v2_process_core_v144(r.club_id,r.id,v_local_date,false,false,'scheduler',gen_random_uuid());
      v_runs:=v_runs+1;
    exception when others then
      v_errors:=v_errors+1;v_error:=left(sqlstate||':'||sqlerrm,500);
      insert into public.finanzas_ejecuciones_regla(club_id,regla_id,ciclo,fecha_objetivo,shadow,estado,candidatos,creados,existentes,omitidos,detalle,error_codigo,finalizada_en)
      values(r.club_id,r.id,v_cycle,coalesce(v_local_date,current_date),false,'error',0,0,0,0,jsonb_build_object('source','scheduler','rule_version',r.version),v_error,now());
      insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos)
      select r.club_id,rol,'finance-v2-error-'||r.id::text||'-'||coalesce(v_cycle,current_date)::text||'-'||rol::text,'sistema',
        'Automatización financiera requiere revisión','Una automatización financiera no se ha podido completar.','fees',
        jsonb_build_object('finance_v2',true,'regla_id',r.id,'finance_target','automation','entity_id',r.id,'deep_link','finance:automation','requiere_accion',true)
      from unnest(array['direccion','economia']::public.rol_club[]) rol
      on conflict(club_id,rol_destino,clave) where clave is not null and rol_destino is not null do nothing;
    end;
  end loop;
  return jsonb_build_object('ok',v_errors=0,'ejecutadas',v_runs,'omitidas_shadow',v_skipped,'errores',v_errors,'run_at',p_ahora);
end $$;
revoke all on function public.app_finance_v2_scheduler_v144(timestamptz) from public,anon,authenticated;
grant execute on function public.app_finance_v2_scheduler_v144(timestamptz) to service_role,postgres;

-- ---------------------------------------------------------------------------
-- 3. Helpers de escritura corregidos para actualizaciones de reglas/excepciones.
-- Evitan cualquier ambigüedad de asignación de registros PL/pgSQL.
-- ---------------------------------------------------------------------------
create or replace function public.app_finance_v2_rule_save_core_v148(p_club_id uuid,p_payload jsonb)
returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare v_uid uuid:=auth.uid();v_id uuid;v_old public.reglas_cobro;v_new public.reglas_cobro;v_action text;
begin
  if not public.app_finance_v2_manage_v143(p_club_id) then raise exception 'FINANCE_V2_FORBIDDEN'; end if;
  begin v_id:=nullif(p_payload->>'id','')::uuid; exception when others then raise exception 'FINANCE_V2_REGLA_ID_INVALIDA'; end;
  if coalesce(nullif(trim(p_payload->>'nombre'),''),'')='' or coalesce(nullif(trim(p_payload->>'concepto'),''),'')='' then raise exception 'FINANCE_V2_REGLA_DATOS_REQUIRED'; end if;
  if lower(coalesce(p_payload->>'categoria','')) not in ('cuota','matricula','licencia','material','competicion','evento','desplazamiento','otro') then raise exception 'FINANCE_V2_CATEGORIA_INVALIDA'; end if;
  if lower(coalesce(p_payload->>'periodicidad','')) not in ('mensual','trimestral','semestral','anual','unica') then raise exception 'FINANCE_V2_PERIODICIDAD_INVALIDA'; end if;
  if (p_payload->>'importe')::numeric<0 then raise exception 'FINANCE_V2_IMPORTE_INVALIDO'; end if;
  if v_id is null then
    insert into public.reglas_cobro(club_id,tarifa_id,nombre,concepto,categoria,concepto_personalizado,importe,periodicidad,fecha_inicio,fecha_fin,dia_generacion,dia_vencimiento,zona_horaria,politica_alta,activa,observaciones,creada_por,actualizado_por)
    values(p_club_id,nullif(p_payload->>'tarifa_id','')::uuid,trim(p_payload->>'nombre'),trim(p_payload->>'concepto'),lower(p_payload->>'categoria'),nullif(trim(p_payload->>'concepto_personalizado'),''),(p_payload->>'importe')::numeric(12,2),lower(p_payload->>'periodicidad'),coalesce(nullif(p_payload->>'fecha_inicio','')::date,current_date),nullif(p_payload->>'fecha_fin','')::date,coalesce(nullif(p_payload->>'dia_generacion','')::smallint,1),coalesce(nullif(p_payload->>'dia_vencimiento','')::smallint,10),coalesce(nullif(p_payload->>'zona_horaria',''),'Europe/Madrid'),coalesce(nullif(p_payload->>'politica_alta',''),'siguiente_ciclo'),coalesce((p_payload->>'activa')::boolean,true),nullif(p_payload->>'observaciones',''),v_uid,v_uid)
    returning * into v_new;v_action:='regla.crear';
  else
    select * into v_old from public.reglas_cobro where club_id=p_club_id and id=v_id for update;
    if v_old.id is null then raise exception 'FINANCE_V2_REGLA_NO_ENCONTRADA'; end if;
    update public.reglas_cobro set tarifa_id=nullif(p_payload->>'tarifa_id','')::uuid,nombre=trim(p_payload->>'nombre'),concepto=trim(p_payload->>'concepto'),categoria=lower(p_payload->>'categoria'),concepto_personalizado=nullif(trim(p_payload->>'concepto_personalizado'),''),importe=(p_payload->>'importe')::numeric(12,2),periodicidad=lower(p_payload->>'periodicidad'),fecha_inicio=coalesce(nullif(p_payload->>'fecha_inicio','')::date,fecha_inicio),fecha_fin=case when p_payload ? 'fecha_fin' then nullif(p_payload->>'fecha_fin','')::date else fecha_fin end,dia_generacion=coalesce(nullif(p_payload->>'dia_generacion','')::smallint,dia_generacion),dia_vencimiento=coalesce(nullif(p_payload->>'dia_vencimiento','')::smallint,dia_vencimiento),zona_horaria=coalesce(nullif(p_payload->>'zona_horaria',''),zona_horaria),politica_alta=coalesce(nullif(p_payload->>'politica_alta',''),politica_alta),activa=coalesce((p_payload->>'activa')::boolean,activa),observaciones=case when p_payload ? 'observaciones' then nullif(p_payload->>'observaciones','') else observaciones end,version=version+1,actualizado_por=v_uid,actualizado_en=now()
    where club_id=p_club_id and id=v_id returning * into v_new;v_action:='regla.actualizar';
  end if;
  perform public.app_finance_v2_audit_v143(p_club_id,v_action,'regla_cobro',v_new.id,case when v_old.id is null then null else to_jsonb(v_old) end,to_jsonb(v_new),jsonb_build_object('version',v_new.version));
  return to_jsonb(v_new);
end $$;
revoke all on function public.app_finance_v2_rule_save_core_v148(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.app_finance_v2_rule_save_core_v148(uuid,jsonb) to service_role,postgres;

create or replace function public.app_finance_v2_exception_save_core_v148(p_club_id uuid,p_payload jsonb)
returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare v_uid uuid:=auth.uid();v_id uuid;v_old public.reglas_cobro_excepciones;v_new public.reglas_cobro_excepciones;v_action text;
begin
  if not public.app_finance_v2_manage_v143(p_club_id) then raise exception 'FINANCE_V2_FORBIDDEN'; end if;
  begin v_id:=nullif(p_payload->>'id','')::uuid; exception when others then raise exception 'FINANCE_V2_EXCEPTION_ID_INVALID'; end;
  if lower(coalesce(p_payload->>'tipo','')) not in ('excluido','exento','pausa','bonificacion','importe_personalizado','no_generar_ciclo') then raise exception 'FINANCE_V2_EXCEPTION_TYPE_INVALID'; end if;
  if v_id is null then
    insert into public.reglas_cobro_excepciones(club_id,regla_id,socio_id,tipo,importe_personalizado,porcentaje_bonificacion,ciclo,fecha_inicio,fecha_fin,motivo,activa,creada_por,actualizado_por)
    values(p_club_id,(p_payload->>'regla_id')::uuid,(p_payload->>'socio_id')::uuid,lower(p_payload->>'tipo'),nullif(p_payload->>'importe_personalizado','')::numeric(12,2),nullif(p_payload->>'porcentaje_bonificacion','')::numeric(5,2),nullif(p_payload->>'ciclo','')::date,nullif(p_payload->>'fecha_inicio','')::date,nullif(p_payload->>'fecha_fin','')::date,coalesce(nullif(trim(p_payload->>'motivo'),''),'Sin motivo indicado'),coalesce((p_payload->>'activa')::boolean,true),v_uid,v_uid)
    returning * into v_new;v_action:='excepcion.crear';
  else
    select * into v_old from public.reglas_cobro_excepciones where club_id=p_club_id and id=v_id for update;
    if v_old.id is null then raise exception 'FINANCE_V2_EXCEPTION_NOT_FOUND'; end if;
    update public.reglas_cobro_excepciones set tipo=lower(p_payload->>'tipo'),importe_personalizado=case when p_payload ? 'importe_personalizado' then nullif(p_payload->>'importe_personalizado','')::numeric(12,2) else importe_personalizado end,porcentaje_bonificacion=case when p_payload ? 'porcentaje_bonificacion' then nullif(p_payload->>'porcentaje_bonificacion','')::numeric(5,2) else porcentaje_bonificacion end,ciclo=case when p_payload ? 'ciclo' then nullif(p_payload->>'ciclo','')::date else ciclo end,fecha_inicio=case when p_payload ? 'fecha_inicio' then nullif(p_payload->>'fecha_inicio','')::date else fecha_inicio end,fecha_fin=case when p_payload ? 'fecha_fin' then nullif(p_payload->>'fecha_fin','')::date else fecha_fin end,motivo=coalesce(nullif(trim(p_payload->>'motivo'),''),motivo),activa=coalesce((p_payload->>'activa')::boolean,activa),actualizado_por=v_uid,actualizado_en=now()
    where club_id=p_club_id and id=v_id returning * into v_new;v_action:='excepcion.actualizar';
  end if;
  perform public.app_finance_v2_audit_v143(p_club_id,v_action,'regla_excepcion',v_new.id,case when v_old.id is null then null else to_jsonb(v_old) end,to_jsonb(v_new),jsonb_build_object());
  return to_jsonb(v_new);
end $$;
revoke all on function public.app_finance_v2_exception_save_core_v148(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.app_finance_v2_exception_save_core_v148(uuid,jsonb) to service_role,postgres;

-- ---------------------------------------------------------------------------
-- 4. Gateway final de hardening. Intercepta solo paths reforzados y delega el
-- resto a toda la cadena 146→145→legacy.
-- ---------------------------------------------------------------------------
do $gateway$
begin
  if to_regprocedure('public.app_mutate_v160_pre_finance_hardening_148(text,jsonb,uuid)') is null then
    if to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is null then raise exception '148: falta app_mutate_v160'; end if;
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_finance_hardening_148;
  end if;
end $gateway$;
revoke all on function public.app_mutate_v160_pre_finance_hardening_148(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_club uuid;
  v_existing public.app_mutation_requests;v_data jsonb;v_result jsonb;v_rule public.reglas_cobro;v_shadow_missing integer;
begin
  if p_operation not in ('finance.v2.rule.save','finance.v2.exception.save') then
    if p_operation='finance.v2.feature.set' and coalesce(p_payload->>'key','')='finance_recurring_enabled' and coalesce((p_payload->>'enabled')::boolean,false) then
      begin v_club:=nullif(p_payload->>'club_id','')::uuid; exception when others then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
      if not public.app_finance_v2_direction_v143(v_club) then raise exception 'FINANCE_V2_DIRECTION_REQUIRED'; end if;
      select count(*) into v_shadow_missing from public.reglas_cobro r where r.club_id=v_club and r.activa and not public.app_finance_v2_shadow_ready_v148(v_club,r.id,current_date);
      if v_shadow_missing>0 then raise exception 'FINANCE_V2_SHADOW_REQUIRED:% regla(s) activas sin simulación válida',v_shadow_missing; end if;
    end if;
    if p_operation='finance.v2.rule.generate_now' then
      begin v_club:=nullif(p_payload->>'club_id','')::uuid; exception when others then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
      select * into v_rule from public.reglas_cobro where club_id=v_club and id=(p_payload->>'regla_id')::uuid;
      if v_rule.id is null then raise exception 'FINANCE_V2_REGLA_NO_ENCONTRADA'; end if;
      if not public.app_finance_v2_shadow_ready_v148(v_club,v_rule.id,coalesce(nullif(p_payload->>'fecha','')::date,current_date)) then raise exception 'FINANCE_V2_SHADOW_REQUIRED'; end if;
    end if;
    v_result:=public.app_mutate_v160_pre_finance_hardening_148(p_operation,p_payload,p_request_id);
    if p_operation='finance.v2.charge.create' and nullif(p_payload->>'observaciones','') is not null then
      update public.cuotas set datos_finance_v2=coalesce(datos_finance_v2,'{}'::jsonb)||jsonb_build_object('observaciones',p_payload->>'observaciones')
      where club_id=(p_payload->>'club_id')::uuid and lote_id=p_request_id;
    end if;
    return v_result;
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

  if p_operation='finance.v2.rule.save' then v_data:=public.app_finance_v2_rule_save_core_v148(v_club,v_payload);
  else v_data:=public.app_finance_v2_exception_save_core_v148(v_club,v_payload);end if;

  v_result:=jsonb_build_object('ok',true,'backend_version','1.6.0','operation',p_operation,'request_id',p_request_id,'data',coalesce(v_data,'{}'::jsonb));
  update public.app_mutation_requests set result=v_result,completed_at=now(),club_id=v_club where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end $$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

create or replace function public.app_finance_v2_hardening_audit_v148()
returns table(control text,ok boolean,detalle text)
language sql security definer set search_path=public,auth
as $$
  select 'focus compartido',pg_get_functiondef('public.app_finance_v2_filtered_core_v146(uuid,jsonb)'::regprocedure) like '%focus%','KPI/gráfico/tabla/informe'
  union all select 'shadow por versión',to_regprocedure('public.app_finance_v2_shadow_ready_v148(uuid,uuid,date)') is not null,'cambio de regla invalida simulación'
  union all select 'scheduler observa errores',pg_get_functiondef('public.app_finance_v2_scheduler_v144(timestamp with time zone)'::regprocedure) like '%finanzas_ejecuciones_regla%error%','errores persistentes'
  union all select 'gateway legacy preservado',to_regprocedure('public.app_mutate_v160_pre_finance_hardening_148(text,jsonb,uuid)') is not null,'delegación completa';
$$;
revoke all on function public.app_finance_v2_hardening_audit_v148() from public,anon,authenticated;
grant execute on function public.app_finance_v2_hardening_audit_v148() to service_role,postgres;

notify pgrst,'reload schema';
commit;
