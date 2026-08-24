-- KOMBAX RC13 build 20079 · Finanzas Premium 2.0 · GATE 2
-- Motor recurrente autoritativo, shadow mode, concurrencia e integración con
-- el centro de notificaciones existente. La escritura automática solo ocurre
-- si finance_v2_enabled Y finance_recurring_enabled están activados por club.

begin;

-- ---------------------------------------------------------------------------
-- 1. Cálculo determinista de ciclo, generación y vencimiento.
-- ---------------------------------------------------------------------------
create or replace function public.app_finance_v2_cycle_for_v144(
  p_periodicidad text,p_fecha_inicio date,p_fecha date
) returns date
language plpgsql immutable set search_path=public
as $$
declare v_month integer;
begin
  if p_periodicidad='unica' then return p_fecha_inicio; end if;
  if p_periodicidad='mensual' then return date_trunc('month',p_fecha)::date; end if;
  if p_periodicidad='trimestral' then
    v_month:=(((extract(month from p_fecha)::integer-1)/3)*3)+1;
    return make_date(extract(year from p_fecha)::integer,v_month,1);
  end if;
  if p_periodicidad='semestral' then
    v_month:=case when extract(month from p_fecha)::integer<=6 then 1 else 7 end;
    return make_date(extract(year from p_fecha)::integer,v_month,1);
  end if;
  if p_periodicidad='anual' then return make_date(extract(year from p_fecha)::integer,1,1); end if;
  raise exception 'FINANCE_V2_PERIODICIDAD_INVALIDA';
end $$;
revoke all on function public.app_finance_v2_cycle_for_v144(text,date,date) from public,anon,authenticated;
grant execute on function public.app_finance_v2_cycle_for_v144(text,date,date) to service_role,postgres;

create or replace function public.app_finance_v2_day_in_month_v144(p_month date,p_day integer)
returns date
language sql immutable set search_path=public
as $$
  select make_date(
    extract(year from p_month)::integer,
    extract(month from p_month)::integer,
    least(greatest(coalesce(p_day,1),1),extract(day from (date_trunc('month',p_month)+interval '1 month - 1 day'))::integer)
  );
$$;
revoke all on function public.app_finance_v2_day_in_month_v144(date,integer) from public,anon,authenticated;
grant execute on function public.app_finance_v2_day_in_month_v144(date,integer) to service_role,postgres;

-- ---------------------------------------------------------------------------
-- 2. Preview core. Resuelve destinatarios cada vez; no guarda fotografías de
--    grupos/disciplinas y deduplica un alumno alcanzado por varios scopes.
-- ---------------------------------------------------------------------------
create or replace function public.app_finance_v2_preview_core_v144(
  p_club_id uuid,p_regla_id uuid,p_fecha date,p_force_current boolean default false
) returns table(
  socio_id uuid,
  socio_nombre text,
  ciclo date,
  concepto text,
  categoria text,
  importe numeric(12,2),
  vencimiento date,
  decision text,
  excepcion text,
  cargo_existente_id uuid
)
language plpgsql stable security definer set search_path=public,auth
as $$
declare
  r public.reglas_cobro;
  v_cycle date;
  v_generation date;
  v_due_month date;
  v_due date;
begin
  select * into r from public.reglas_cobro where club_id=p_club_id and id=p_regla_id;
  if r.id is null then raise exception 'FINANCE_V2_REGLA_NO_ENCONTRADA'; end if;
  v_cycle:=public.app_finance_v2_cycle_for_v144(r.periodicidad,r.fecha_inicio,p_fecha);
  v_generation:=case when r.periodicidad='unica' then r.fecha_inicio else public.app_finance_v2_day_in_month_v144(v_cycle,r.dia_generacion) end;
  v_due_month:=case
    when r.periodicidad='unica' then date_trunc('month',r.fecha_inicio)::date
    when r.dia_vencimiento>=r.dia_generacion then v_cycle
    else (v_cycle+interval '1 month')::date
  end;
  v_due:=public.app_finance_v2_day_in_month_v144(v_due_month,r.dia_vencimiento);

  return query
  with source_candidates as (
    select s.id as socio_id,s.fecha_alta as scope_inicio
    from public.reglas_cobro_destinatarios d
    join public.socios s on s.club_id=d.club_id and s.id=d.socio_id and s.estado='activo'
    where d.club_id=p_club_id and d.regla_id=p_regla_id and d.tipo='socio'

    union all
    select s.id,greatest(s.fecha_alta,sd.fecha_inicio) as scope_inicio
    from public.reglas_cobro_destinatarios d
    join public.socio_disciplinas sd on sd.club_id=d.club_id and sd.grupo_id=d.grupo_id
      and sd.fecha_inicio<=p_fecha and (sd.fecha_fin is null or sd.fecha_fin>=p_fecha)
      and (sd.activa or sd.fecha_fin>=p_fecha)
    join public.socios s on s.club_id=sd.club_id and s.id=sd.socio_id and s.estado='activo'
    where d.club_id=p_club_id and d.regla_id=p_regla_id and d.tipo='grupo'

    union all
    select s.id,greatest(s.fecha_alta,sd.fecha_inicio) as scope_inicio
    from public.reglas_cobro_destinatarios d
    join public.socio_disciplinas sd on sd.club_id=d.club_id and sd.disciplina_id=d.disciplina_id
      and sd.fecha_inicio<=p_fecha and (sd.fecha_fin is null or sd.fecha_fin>=p_fecha)
      and (sd.activa or sd.fecha_fin>=p_fecha)
    join public.socios s on s.club_id=sd.club_id and s.id=sd.socio_id and s.estado='activo'
    where d.club_id=p_club_id and d.regla_id=p_regla_id and d.tipo='disciplina'

    union all
    select s.id,s.fecha_alta as scope_inicio
    from public.reglas_cobro_destinatarios d
    join public.socios s on s.club_id=d.club_id and s.estado='activo'
    where d.club_id=p_club_id and d.regla_id=p_regla_id and d.tipo='todos'
  ), candidates as (
    select sc.socio_id,min(sc.scope_inicio) as scope_inicio
    from source_candidates sc group by sc.socio_id
  )
  select
    s.id,
    trim(concat_ws(' ',s.nombre,s.apellidos)),
    v_cycle,
    coalesce(nullif(trim(r.concepto_personalizado),''),r.concepto),
    r.categoria,
    case
      when ex.tipo='importe_personalizado' then ex.importe_personalizado
      when ex.tipo='bonificacion' then round(greatest(r.importe*(1-coalesce(ex.porcentaje_bonificacion,0)/100),0),2)
      else r.importe
    end::numeric(12,2),
    v_due,
    case
      when existing.id is not null then 'existente'
      when not r.activa then 'regla_inactiva'
      when p_fecha<r.fecha_inicio or (r.fecha_fin is not null and p_fecha>r.fecha_fin) then 'fuera_vigencia'
      when p_fecha<v_generation then 'aun_no_corresponde'
      when r.periodicidad<>'unica' and not p_force_current and r.fecha_inicio>v_cycle then 'inicio_regla_siguiente_ciclo'
      when not p_force_current and c.scope_inicio>v_cycle then 'alta_siguiente_ciclo'
      when ex.tipo in ('excluido','exento','pausa','no_generar_ciclo') then 'excepcion_'||ex.tipo
      else 'generar'
    end,
    ex.tipo,
    existing.id
  from candidates c
  join public.socios s on s.club_id=p_club_id and s.id=c.socio_id
  left join lateral (
    select e.tipo,e.importe_personalizado,e.porcentaje_bonificacion
    from public.reglas_cobro_excepciones e
    where e.club_id=p_club_id and e.regla_id=p_regla_id and e.socio_id=s.id and e.activa
      and (e.fecha_inicio is null or e.fecha_inicio<=p_fecha)
      and (e.fecha_fin is null or e.fecha_fin>=p_fecha)
      and (e.tipo<>'no_generar_ciclo' or e.ciclo=v_cycle)
    order by case e.tipo
      when 'excluido' then 1 when 'exento' then 2 when 'no_generar_ciclo' then 3 when 'pausa' then 4
      when 'importe_personalizado' then 5 when 'bonificacion' then 6 else 20 end,
      e.creado_en desc,e.id desc
    limit 1
  ) ex on true
  left join public.cuotas existing on existing.club_id=p_club_id and existing.regla_cobro_id=p_regla_id
    and existing.socio_id=s.id and existing.ciclo_clave=v_cycle
  order by s.apellidos,s.nombre,s.id;
end $$;
revoke all on function public.app_finance_v2_preview_core_v144(uuid,uuid,date,boolean) from public,anon,authenticated;
grant execute on function public.app_finance_v2_preview_core_v144(uuid,uuid,date,boolean) to service_role,postgres;

create or replace function public.app_finance_v2_preview_v144(
  p_club_id uuid,p_regla_id uuid,p_fecha date default current_date,p_force_current boolean default false
) returns table(
  socio_id uuid,socio_nombre text,ciclo date,concepto text,categoria text,importe numeric(12,2),
  vencimiento date,decision text,excepcion text,cargo_existente_id uuid
)
language plpgsql stable security definer set search_path=public,auth
as $$
begin
  if not public.app_finance_v2_manage_v143(p_club_id) then raise exception 'FINANCE_V2_FORBIDDEN'; end if;
  return query select * from public.app_finance_v2_preview_core_v144(p_club_id,p_regla_id,p_fecha,p_force_current);
end $$;
revoke all on function public.app_finance_v2_preview_v144(uuid,uuid,date,boolean) from public,anon;
grant execute on function public.app_finance_v2_preview_v144(uuid,uuid,date,boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Núcleo de ejecución. Advisory lock + índice UNIQUE de 143 protegen doble
--    click, retry y workers concurrentes. Un fallo de inserción revierte el lote.
-- ---------------------------------------------------------------------------
create or replace function public.app_finance_v2_process_core_v144(
  p_club_id uuid,p_regla_id uuid,p_fecha date,p_shadow boolean,
  p_force_current boolean default false,p_source text default 'manual',p_request_id uuid default null
) returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  r public.reglas_cobro;
  v_cycle date;
  v_exec uuid;
  v_candidates integer:=0;
  v_created integer:=0;
  v_existing integer:=0;
  v_omitted integer:=0;
  v_lock boolean;
  v_error text;
begin
  select * into r from public.reglas_cobro where club_id=p_club_id and id=p_regla_id;
  if r.id is null then raise exception 'FINANCE_V2_REGLA_NO_ENCONTRADA'; end if;
  v_cycle:=public.app_finance_v2_cycle_for_v144(r.periodicidad,r.fecha_inicio,p_fecha);
  v_lock:=pg_try_advisory_xact_lock(hashtextextended('kombax-finance-v2:'||p_regla_id::text||':'||v_cycle::text,0));
  if not v_lock then
    return jsonb_build_object('ok',true,'estado','ocupada','regla_id',p_regla_id,'ciclo',v_cycle,'creados',0,'duplicados',0);
  end if;

  select count(*),count(*) filter(where decision='existente'),count(*) filter(where decision not in ('generar','existente'))
    into v_candidates,v_existing,v_omitted
  from public.app_finance_v2_preview_core_v144(p_club_id,p_regla_id,p_fecha,p_force_current);

  insert into public.finanzas_ejecuciones_regla(
    club_id,regla_id,ciclo,fecha_objetivo,shadow,estado,request_id,candidatos,existentes,omitidos,ejecutada_por,detalle
  ) values(
    p_club_id,p_regla_id,v_cycle,p_fecha,p_shadow,'iniciada',p_request_id,v_candidates,v_existing,v_omitted,auth.uid(),
    jsonb_build_object('source',p_source,'force_current',p_force_current,'rule_version',r.version)
  ) returning id into v_exec;

  if p_shadow then
    update public.finanzas_ejecuciones_regla set estado='completada',finalizada_en=now(),creados=0 where id=v_exec;
    return jsonb_build_object('ok',true,'estado','shadow','ejecucion_id',v_exec,'regla_id',p_regla_id,'ciclo',v_cycle,
      'candidatos',v_candidates,'creados',0,'existentes',v_existing,'omitidos',v_omitted);
  end if;

  begin
    insert into public.cuotas(
      club_id,socio_id,tarifa_id,periodo,concepto,concepto_publico,importe,vencimiento,estado,origen,
      categoria_financiera,regla_cobro_id,ciclo_clave,generacion_clave,regla_version,generada_automaticamente,datos_finance_v2
    )
    select
      p_club_id,p.socio_id,r.tarifa_id,p.ciclo,
      p.concepto||' ['||left(replace(p_regla_id::text,'-',''),8)||']',p.concepto,p.importe,p.vencimiento,'pendiente',
      case when p.categoria='cuota' then 'cuota' when p.categoria='material' then 'material' else 'otro' end,
      p.categoria,p_regla_id,p.ciclo,'regla:'||p_regla_id::text||':ciclo:'||p.ciclo::text,r.version,
      p_source='scheduler',jsonb_build_object('ejecucion_id',v_exec,'source',p_source,'regla_id',p_regla_id,'ciclo',p.ciclo)
    from public.app_finance_v2_preview_core_v144(p_club_id,p_regla_id,p_fecha,p_force_current) p
    where p.decision='generar'
    on conflict do nothing;
    get diagnostics v_created=row_count;

    -- Un único aviso agrupado por perfil/tutor para todos los cargos del lote.
    insert into public.notificaciones(club_id,perfil_id,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    select p_club_id,d.perfil_id,'finance-v2-cargos-'||v_exec::text||'-'||d.perfil_id::text,'aviso_cobro',
      case when count(*)=1 then 'Nuevo cargo disponible' else count(*)::text||' nuevos cargos disponibles' end,
      'Tienes una actualización de pagos en KOMBAX.','fees',
      jsonb_build_object(
        'finance_v2',true,'ejecucion_id',v_exec,'cantidad',count(*),'cuota_id',case when count(*)=1 then min(q.id)::text else null end,
        'deep_link','finance:cargos','requiere_accion',true
      ),auth.uid()
    from public.cuotas q
    join public.socios s on s.club_id=q.club_id and s.id=q.socio_id
    join lateral(
      select coalesce(s.perfil_id,(
        select ts.tutor_perfil_id from public.tutores_socios ts
        where ts.club_id=s.club_id and ts.socio_id=s.id
        order by ts.contacto_principal desc,ts.id limit 1
      )) as perfil_id
    ) d on d.perfil_id is not null
    where q.club_id=p_club_id and q.datos_finance_v2->>'ejecucion_id'=v_exec::text
    group by d.perfil_id
    on conflict(club_id,perfil_id,clave) where clave is not null and perfil_id is not null do nothing;

    -- La infraestructura push existente consumirá estas notificaciones; no se
    -- introduce ningún dispatcher paralelo.
    insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos,creada_por)
    select p_club_id,rol,'finance-v2-run-'||v_exec::text||'-'||rol::text,'sistema',
      'Automatización financiera ejecutada',
      case when v_created=1 then 'Se ha generado 1 cargo.' else 'Se han generado '||v_created||' cargos.' end,
      'fees',jsonb_build_object('finance_v2',true,'ejecucion_id',v_exec,'regla_id',p_regla_id,'creados',v_created,'deep_link','finance:automatizaciones'),auth.uid()
    from unnest(array['direccion','economia']::public.rol_club[]) rol
    on conflict(club_id,rol_destino,clave) where clave is not null and rol_destino is not null do nothing;

    perform public.app_finance_v2_audit_v143(
      p_club_id,'cargo.recurrente.generar','regla_cobro',p_regla_id,null,
      jsonb_build_object('ciclo',v_cycle,'creados',v_created,'existentes',v_existing,'omitidos',v_omitted),
      jsonb_build_object('ejecucion_id',v_exec,'source',p_source,'shadow',false,'request_id',p_request_id)
    );

    update public.finanzas_ejecuciones_regla set estado='completada',finalizada_en=now(),creados=v_created where id=v_exec;
  exception when others then
    v_error:=sqlstate||':'||sqlerrm;
    update public.finanzas_ejecuciones_regla set estado='error',finalizada_en=now(),error_codigo=left(v_error,500) where id=v_exec;
    raise;
  end;

  return jsonb_build_object('ok',true,'estado','completada','ejecucion_id',v_exec,'regla_id',p_regla_id,'ciclo',v_cycle,
    'candidatos',v_candidates,'creados',v_created,'existentes',v_existing,'omitidos',v_omitted);
end $$;
revoke all on function public.app_finance_v2_process_core_v144(uuid,uuid,date,boolean,boolean,text,uuid) from public,anon,authenticated;
grant execute on function public.app_finance_v2_process_core_v144(uuid,uuid,date,boolean,boolean,text,uuid) to service_role,postgres;

-- Preview autenticado para QA/shadow. Nunca escribe cargos.
create or replace function public.app_finance_v2_shadow_v144(
  p_club_id uuid,p_regla_id uuid,p_fecha date default current_date,p_force_current boolean default false
) returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
begin
  if not public.app_finance_v2_manage_v143(p_club_id) then raise exception 'FINANCE_V2_FORBIDDEN'; end if;
  return public.app_finance_v2_process_core_v144(p_club_id,p_regla_id,p_fecha,true,p_force_current,'shadow',gen_random_uuid());
end $$;
revoke all on function public.app_finance_v2_shadow_v144(uuid,uuid,date,boolean) from public,anon;
grant execute on function public.app_finance_v2_shadow_v144(uuid,uuid,date,boolean) to authenticated;

-- Scheduler: ejecución horaria para respetar zonas horarias. El motor sigue
-- siendo por ciclo y totalmente idempotente; no depende de abrir Finanzas.
create or replace function public.app_finance_v2_scheduler_v144(p_ahora timestamptz default now())
returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  r public.reglas_cobro;
  v_local_date date;
  v_cycle date;
  v_generation date;
  v_result jsonb;
  v_runs integer:=0;
  v_errors integer:=0;
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
      if exists(
        select 1 from public.finanzas_ejecuciones_regla e
        where e.club_id=r.club_id and e.regla_id=r.id and e.ciclo=v_cycle and not e.shadow and e.estado='completada'
          and e.detalle->>'source'='scheduler'
      ) then continue; end if;
      v_result:=public.app_finance_v2_process_core_v144(r.club_id,r.id,v_local_date,false,false,'scheduler',gen_random_uuid());
      v_runs:=v_runs+1;
    exception when others then
      v_errors:=v_errors+1;
      insert into public.notificaciones(club_id,rol_destino,clave,tipo,titulo,cuerpo,ruta,datos)
      select r.club_id,rol,'finance-v2-error-'||r.id::text||'-'||v_local_date::text||'-'||rol::text,'sistema',
        'Automatización financiera requiere revisión','Una automatización financiera no se ha podido completar.','fees',
        jsonb_build_object('finance_v2',true,'regla_id',r.id,'fecha',v_local_date,'deep_link','finance:automatizaciones','requiere_accion',true)
      from unnest(array['direccion','economia']::public.rol_club[]) rol
      on conflict(club_id,rol_destino,clave) where clave is not null and rol_destino is not null do nothing;
    end;
  end loop;
  return jsonb_build_object('ok',v_errors=0,'ejecutadas',v_runs,'errores',v_errors,'run_at',p_ahora);
end $$;
revoke all on function public.app_finance_v2_scheduler_v144(timestamptz) from public,anon,authenticated;
grant execute on function public.app_finance_v2_scheduler_v144(timestamptz) to service_role,postgres;

-- Scheduler in-database: sin secretos ni llamada de red.
do $$
declare v_job bigint;
begin
  if exists(select 1 from pg_extension where extname='pg_cron') then
    select jobid into v_job from cron.job where jobname='kombax-finance-v2-hourly-v144' limit 1;
    if v_job is not null then perform cron.unschedule(v_job); end if;
    perform cron.schedule('kombax-finance-v2-hourly-v144','17 * * * *',$cron$select public.app_finance_v2_scheduler_v144(now());$cron$);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Diagnóstico del motor. No modifica cargos.
-- ---------------------------------------------------------------------------
create or replace function public.app_finance_v2_recurring_audit_v144()
returns table(control text,ok boolean,detalle text)
language sql security definer set search_path=public,auth
as $$
  select 'unique regla+socio+ciclo',to_regclass('public.uq_cuotas_regla_socio_ciclo_v143') is not null,'integridad en PostgreSQL'
  union all select 'preview core',to_regprocedure('public.app_finance_v2_preview_core_v144(uuid,uuid,date,boolean)') is not null,'shadow determinista'
  union all select 'scheduler',to_regprocedure('public.app_finance_v2_scheduler_v144(timestamp with time zone)') is not null,'worker backend'
  union all select 'recurrencias opt-in',not exists(
    select 1 from public.config_club where clave='finance_recurring_enabled' and valor='true'::jsonb
  ),'ningún club activado automáticamente por la migración'
  union all select 'duplicados existentes',not exists(
    select 1 from public.cuotas where regla_cobro_id is not null and ciclo_clave is not null
    group by club_id,regla_cobro_id,socio_id,ciclo_clave having count(*)>1
  ),'0 duplicados esperados';
$$;
revoke all on function public.app_finance_v2_recurring_audit_v144() from public,anon,authenticated;
grant execute on function public.app_finance_v2_recurring_audit_v144() to service_role,postgres;

notify pgrst,'reload schema';
commit;
