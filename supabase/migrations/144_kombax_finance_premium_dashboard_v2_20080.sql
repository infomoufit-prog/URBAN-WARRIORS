-- KOMBAX RC13 build 20080 · Finanzas Premium 2.0 · dashboard + manual charge
-- Depends on 143_kombax_finance_premium_v2_20079.sql.
-- Additive and feature-flagged. No historical payment or receipt row is rewritten.

begin;

do $$
begin
  if to_regclass('public.reglas_cobro') is null
     or to_regprocedure('public.app_finance_v2_flags_v143(uuid)') is null
     or to_regprocedure('private.finance_mutate_v143(text,jsonb,uuid,uuid)') is null then
    raise exception 'FINANCE_V2_144_REQUIRES_143';
  end if;
end
$$;

-- Trace manual batches without changing historical rows.
alter table public.cuotas add column if not exists lote_cargo_id uuid;
create index if not exists idx_cuotas_lote_cargo_v144
  on public.cuotas(club_id,lote_cargo_id) where lote_cargo_id is not null;

-- ---------------------------------------------------------------------------
-- 1) Resolve manual recipients on the server and deduplicate overlapping scopes.
-- Payload format: [{"tipo":"socio|grupo|disciplina|todos_activos","id":"uuid?"}, ...]
-- ---------------------------------------------------------------------------
create or replace function private.finance_manual_recipients_v144(
  p_club_id uuid,
  p_destinatarios jsonb
)
returns table(socio_id uuid)
language sql
stable
security definer
set search_path=''
as $$
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
$$;
revoke all on function private.finance_manual_recipients_v144(uuid,jsonb) from public,anon,authenticated;

-- ---------------------------------------------------------------------------
-- 2) Mandatory preview for + Nuevo cargo.
-- ---------------------------------------------------------------------------
create or replace function public.app_finance_v2_preview_cargo_v144(
  p_club_id uuid,
  p_destinatarios jsonb,
  p_categoria text,
  p_concepto text,
  p_importe numeric,
  p_periodo date,
  p_vencimiento date
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_rows jsonb:='[]'::jsonb;
  v_count integer:=0;
  v_total numeric(14,2):=0;
  v_categoria text:=lower(trim(coalesce(p_categoria,'')));
  v_concepto text:=trim(coalesce(p_concepto,''));
begin
  if auth.uid() is null or not public.tiene_rol_club(p_club_id,'direccion','secretaria','economia') then
    raise exception 'FINANCE_V2_PREVIEW_FORBIDDEN';
  end if;
  if v_categoria not in ('cuota','matricula','licencia','material','competicion','evento','desplazamiento','otro') then
    raise exception 'FINANCE_V2_CATEGORY_INVALID';
  end if;
  if v_concepto='' then raise exception 'FINANCE_V2_CONCEPT_REQUIRED'; end if;
  if coalesce(p_importe,-1)<0 then raise exception 'FINANCE_V2_AMOUNT_INVALID'; end if;
  if p_periodo is null or p_vencimiento is null then raise exception 'FINANCE_V2_DATES_REQUIRED'; end if;

  select count(*),coalesce(sum(p_importe),0),coalesce(jsonb_agg(jsonb_build_object(
      'socio_id',s.id,
      'nombre',trim(concat_ws(' ',s.nombre,s.apellidos)),
      'categoria',v_categoria,
      'concepto',v_concepto,
      'importe',p_importe,
      'periodo',p_periodo,
      'vencimiento',p_vencimiento
    ) order by s.apellidos,s.nombre,s.id),'[]'::jsonb)
  into v_count,v_total,v_rows
  from private.finance_manual_recipients_v144(p_club_id,p_destinatarios) x
  join public.socios s on s.club_id=p_club_id and s.id=x.socio_id;

  return jsonb_build_object(
    'ok',true,
    'shadow',true,
    'club_id',p_club_id,
    'categoria',v_categoria,
    'concepto',v_concepto,
    'importe_individual',p_importe,
    'periodo',p_periodo,
    'vencimiento',p_vencimiento,
    'cargos',v_count,
    'total',v_total,
    'destinatarios',v_rows
  );
end
$$;
revoke all on function public.app_finance_v2_preview_cargo_v144(uuid,jsonb,text,text,numeric,date,date) from public,anon;
grant execute on function public.app_finance_v2_preview_cargo_v144(uuid,jsonb,text,text,numeric,date,date) to authenticated;

-- ---------------------------------------------------------------------------
-- 3) Premium dashboard read API. All widgets derive from this same filtered CTE.
-- Group/discipline filters intentionally use current active membership in 20080;
-- the charge itself remains historically immutable. Future snapshots can extend this.
-- ---------------------------------------------------------------------------
create or replace function public.app_finance_v2_dashboard_v144(
  p_club_id uuid,
  p_anio integer default null,
  p_mes integer default null,
  p_socio_id uuid default null,
  p_grupo_id uuid default null,
  p_disciplina_id uuid default null,
  p_categoria text default null,
  p_estado text default null,
  p_regla_id uuid default null,
  p_metodo text default null,
  p_antiguedad text default null,
  p_limit integer default 250,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_summary jsonb;
  v_months jsonb;
  v_aging jsonb;
  v_rows jsonb;
  v_total_rows integer:=0;
  v_pending_validation integer:=0;
  v_payments jsonb:='[]'::jsonb;
  v_receipts jsonb:='[]'::jsonb;
  v_today date:=current_date;
begin
  if auth.uid() is null or not public.tiene_rol_club(p_club_id,'direccion','secretaria','economia') then
    raise exception 'FINANCE_V2_DASHBOARD_FORBIDDEN';
  end if;
  if p_mes is not null and (p_mes<1 or p_mes>12) then raise exception 'FINANCE_V2_MONTH_INVALID'; end if;
  if p_antiguedad is not null and p_antiguedad not in ('sin_vencer','1_15','16_30','31_60','60_plus') then
    raise exception 'FINANCE_V2_AGING_INVALID';
  end if;

  with base as (
    select
      q.club_id,q.id as cuota_id,q.socio_id,
      s.nombre as socio_nombre,s.apellidos as socio_apellidos,
      q.periodo,q.concepto,coalesce(q.categoria_financiera,
        case when q.origen='material' then 'material' when q.origen='cuota' then 'cuota' else 'otro' end) as categoria,
      q.importe,q.vencimiento,q.estado,q.creado_en,q.avisos_pausados,
      q.regla_cobro_id,q.generado_automaticamente,q.lote_cargo_id,
      r.nombre as regla_nombre,
      coalesce(pa.pagado_validado,0)::numeric(12,2) as pagado_validado,
      greatest(q.importe-coalesce(pa.pagado_validado,0),0)::numeric(12,2) as saldo,
      pa.ultima_fecha_pago,pa.ultimo_metodo_pago,
      rc.id as recibo_id,rc.numero as recibo_numero,rc.anulado_en as recibo_anulado_en,
      greatest(v_today-q.vencimiento,0) as dias_vencido,
      case
        when q.estado in ('anulada','exenta','pagada') or greatest(q.importe-coalesce(pa.pagado_validado,0),0)<=0 then 'cerrado'
        when q.vencimiento>=v_today then 'sin_vencer'
        when v_today-q.vencimiento between 1 and 15 then '1_15'
        when v_today-q.vencimiento between 16 and 30 then '16_30'
        when v_today-q.vencimiento between 31 and 60 then '31_60'
        else '60_plus' end as antiguedad,
      coalesce((select string_agg(distinct g.nombre,', ' order by g.nombre)
        from public.socio_disciplinas sd join public.grupos g on g.club_id=sd.club_id and g.id=sd.grupo_id
        where sd.club_id=q.club_id and sd.socio_id=q.socio_id and sd.activa),'') as grupos,
      coalesce((select string_agg(distinct d.nombre,', ' order by d.nombre)
        from public.socio_disciplinas sd join public.disciplinas d on d.club_id=sd.club_id and d.id=sd.disciplina_id
        where sd.club_id=q.club_id and sd.socio_id=q.socio_id and sd.activa),'') as disciplinas
    from public.cuotas q
    join public.socios s on s.club_id=q.club_id and s.id=q.socio_id
    left join public.reglas_cobro r on r.club_id=q.club_id and r.id=q.regla_cobro_id
    left join lateral (
      select
        coalesce(sum(p.importe) filter(where p.estado_validacion='validado'),0) as pagado_validado,
        max(p.fecha) filter(where p.estado_validacion='validado') as ultima_fecha_pago,
        (array_agg(p.metodo order by p.fecha desc,p.creado_en desc) filter(where p.estado_validacion='validado'))[1] as ultimo_metodo_pago
      from public.pagos p where p.club_id=q.club_id and p.cuota_id=q.id
    ) pa on true
    left join public.recibos_cuota rc on rc.club_id=q.club_id and rc.cuota_id=q.id
    where q.club_id=p_club_id
      and (p_anio is null or extract(year from q.periodo)::int=p_anio)
      and (p_mes is null or extract(month from q.periodo)::int=p_mes)
      and (p_socio_id is null or q.socio_id=p_socio_id)
      and (p_categoria is null or coalesce(q.categoria_financiera,case when q.origen='material' then 'material' when q.origen='cuota' then 'cuota' else 'otro' end)=p_categoria)
      and (p_estado is null
        or q.estado::text=p_estado
        or (p_estado='pendiente_abierto' and q.estado::text not in ('pagada','anulada','exenta') and greatest(q.importe-coalesce(pa.pagado_validado,0),0)>0)
        or (p_estado='vencido_abierto' and q.estado::text not in ('pagada','anulada','exenta') and q.vencimiento<v_today and greatest(q.importe-coalesce(pa.pagado_validado,0),0)>0)
        or (p_estado='cobrado' and greatest(q.importe-coalesce(pa.pagado_validado,0),0)<=0)
      )
      and (p_regla_id is null or q.regla_cobro_id=p_regla_id)
      and (p_metodo is null or pa.ultimo_metodo_pago=p_metodo)
      and (p_grupo_id is null or exists(select 1 from public.socio_disciplinas sd where sd.club_id=q.club_id and sd.socio_id=q.socio_id and sd.grupo_id=p_grupo_id and sd.activa))
      and (p_disciplina_id is null or exists(select 1 from public.socio_disciplinas sd where sd.club_id=q.club_id and sd.socio_id=q.socio_id and sd.disciplina_id=p_disciplina_id and sd.activa))
  ), filtered as (
    select * from base where p_antiguedad is null or antiguedad=p_antiguedad
  ), valid as (
    select * from filtered where estado::text not in ('anulada','exenta')
  ), summary as (
    select
      coalesce(sum(importe),0)::numeric(14,2) as generado,
      coalesce(sum(least(importe,pagado_validado)),0)::numeric(14,2) as cobrado,
      coalesce(sum(saldo),0)::numeric(14,2) as pendiente,
      coalesce(sum(case when saldo>0 and vencimiento<v_today then saldo else 0 end),0)::numeric(14,2) as vencido,
      count(distinct socio_id) filter(where saldo>0) as alumnos_con_deuda
    from valid
  ), monthly as (
    select date_trunc('month',periodo)::date as mes_fecha,
      coalesce(sum(importe),0)::numeric(14,2) as generado,
      coalesce(sum(least(importe,pagado_validado)),0)::numeric(14,2) as cobrado,
      coalesce(sum(saldo),0)::numeric(14,2) as pendiente
    from valid group by 1 order by 1
  ), aging as (
    select bucket,coalesce(sum(saldo),0)::numeric(14,2) as total,count(*)::int as cargos
    from (
      select antiguedad as bucket,saldo from valid where saldo>0 and antiguedad<>'cerrado'
    ) a group by bucket
  )
  select
    (select jsonb_build_object(
      'generado',s.generado,'cobrado',s.cobrado,'pendiente',s.pendiente,'vencido',s.vencido,
      'porcentaje_cobro',case when s.generado>0 then round((s.cobrado/s.generado)*100,2) else 0 end,
      'alumnos_con_deuda',s.alumnos_con_deuda
    ) from summary s),
    coalesce((select jsonb_agg(jsonb_build_object('mes',m.mes_fecha,'generado',m.generado,'cobrado',m.cobrado,'pendiente',m.pendiente) order by m.mes_fecha) from monthly m),'[]'::jsonb),
    coalesce((select jsonb_agg(jsonb_build_object('bucket',a.bucket,'total',a.total,'cargos',a.cargos) order by case a.bucket when 'sin_vencer' then 1 when '1_15' then 2 when '16_30' then 3 when '31_60' then 4 else 5 end) from aging a),'[]'::jsonb),
    (select count(*) from filtered),
    coalesce((select jsonb_agg(to_jsonb(z) order by z.periodo desc,z.vencimiento desc,z.socio_apellidos,z.socio_nombre)
      from (select * from filtered order by periodo desc,vencimiento desc,socio_apellidos,socio_nombre limit least(greatest(coalesce(p_limit,250),25),500) offset greatest(coalesce(p_offset,0),0)) z),'[]'::jsonb),
    (select count(*) from public.pagos p join filtered f on f.club_id=p.club_id and f.cuota_id=p.cuota_id where p.estado_validacion='pendiente'),
    coalesce((select jsonb_agg(to_jsonb(z) order by z.fecha desc,z.creado_en desc) from (
      select p.id,p.club_id,p.cuota_id,p.socio_id,p.importe,p.fecha,p.metodo,p.referencia,p.justificante_url,
             p.estado_validacion,p.validado_por,p.validado_en,p.observaciones,p.creado_en,p.comunicado_por,p.comunicado_en,p.motivo_rechazo,p.rechazado_en,
             f.socio_nombre,f.socio_apellidos,f.concepto,f.categoria,f.periodo
      from public.pagos p join filtered f on f.club_id=p.club_id and f.cuota_id=p.cuota_id
      order by p.fecha desc,p.creado_en desc limit 500
    ) z),'[]'::jsonb),
    coalesce((select jsonb_agg(to_jsonb(z) order by z.periodo desc,z.numero desc) from (
      select rc.* from public.recibos_cuota rc join filtered f on f.club_id=rc.club_id and f.cuota_id=rc.cuota_id
      order by rc.periodo desc,rc.numero desc limit 500
    ) z),'[]'::jsonb)
  into v_summary,v_months,v_aging,v_total_rows,v_rows,v_pending_validation,v_payments,v_receipts;

  return jsonb_build_object(
    'ok',true,
    'club_id',p_club_id,
    'summary',coalesce(v_summary,'{}'::jsonb),
    'months',coalesce(v_months,'[]'::jsonb),
    'aging',coalesce(v_aging,'[]'::jsonb),
    'pending_validation',v_pending_validation,
    'total_rows',v_total_rows,
    'rows',coalesce(v_rows,'[]'::jsonb),
    'payments',coalesce(v_payments,'[]'::jsonb),
    'receipts',coalesce(v_receipts,'[]'::jsonb),
    'limit',least(greatest(coalesce(p_limit,250),25),500),
    'offset',greatest(coalesce(p_offset,0),0),
    'group_discipline_scope','current_active_membership'
  );
end
$$;
revoke all on function public.app_finance_v2_dashboard_v144(uuid,integer,integer,uuid,uuid,uuid,text,text,uuid,text,text,integer,integer) from public,anon;
grant execute on function public.app_finance_v2_dashboard_v144(uuid,integer,integer,uuid,uuid,uuid,text,text,uuid,text,text,integer,integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 4) Manual bulk charge write through the same idempotent mutation gateway.
-- ---------------------------------------------------------------------------
create or replace function private.finance_create_manual_charge_v144(
  p_payload jsonb,
  p_club uuid,
  p_uid uuid
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
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
$$;
revoke all on function private.finance_create_manual_charge_v144(jsonb,uuid,uuid) from public,anon,authenticated;

-- Preserve 143 gateway as a fallback, but intercept every Finance V2 operation so
-- response.backend_version always matches the active RC13 runtime contract.
do $gateway$
begin
  if to_regprocedure('public.app_mutate_v160_pre_finance_144(text,jsonb,uuid)') is null then
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_finance_144;
  end if;
end
$gateway$;
revoke all on function public.app_mutate_v160_pre_finance_144(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(
  p_operation text,
  p_payload jsonb,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid:=auth.uid();
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_club uuid;
  v_existing public.app_mutation_requests;
  v_data jsonb;
  v_result jsonb;
  v_backend_version text;
begin
  if p_operation not in (
    'finance.regla.guardar','finance.destinatario.añadir','finance.destinatario.eliminar',
    'finance.excepcion.guardar','finance.excepcion.desactivar','finance.flag.establecer',
    'finance.cargos.procesar','finance.cargo.crear'
  ) then
    return public.app_mutate_v160_pre_finance_144(p_operation,p_payload,p_request_id);
  end if;

  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  begin v_club:=nullif(trim(coalesce(v_payload->>'club_id','')),'')::uuid;
  exception when others then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
  if v_club is null or not public.tiene_rol_club(v_club,'direccion','secretaria','economia') then
    raise exception 'FINANCE_V2_MUTATION_FORBIDDEN';
  end if;
  if p_operation='finance.cargo.crear' and not private.finance_flag_v143(v_club,'finance_v2_enabled') then
    raise exception 'FINANCE_V2_DISABLED';
  end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
    values(p_request_id,v_uid,v_club,p_operation);
  end if;

  delete from public.app_mutation_requests where user_id=v_uid and created_at<now()-interval '30 days';

  if p_operation='finance.cargo.crear' then
    v_data:=private.finance_create_manual_charge_v144(v_payload,v_club,v_uid);
    insert into public.auditoria(club_id,usuario_id,accion,entidad,registro_id,datos_nuevos)
    values(v_club,v_uid,'FINANCE_V2_MUTATE','finance.cargo.crear',v_data->>'lote_cargo_id',jsonb_build_object(
      'categoria',v_payload->>'categoria','concepto',v_payload->>'concepto','importe',v_payload->>'importe',
      'periodo',v_payload->>'periodo','vencimiento',v_payload->>'vencimiento','cargos_creados',v_data->'cargos_creados'
    ));
  else
    v_data:=private.finance_mutate_v143(p_operation,v_payload,v_club,v_uid);
  end if;

  select backend_version into v_backend_version from public.app_runtime_meta where singleton=true;
  v_result:=jsonb_build_object(
    'ok',true,'backend_version',coalesce(v_backend_version,'1.6.0'),'operation',p_operation,
    'request_id',p_request_id,'data',coalesce(v_data,'{}'::jsonb)
  );
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end
$$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

-- Extend the runtime contract with the manual bulk charge operation without changing
-- the base backend version/schema epoch expected by the existing application.
do $contract$
begin
  if to_regprocedure('public.app_runtime_contract_v160_pre_finance_144(uuid)') is null then
    alter function public.app_runtime_contract_v160(uuid) rename to app_runtime_contract_v160_pre_finance_144;
  end if;
end
$contract$;
revoke all on function public.app_runtime_contract_v160_pre_finance_144(uuid) from public,anon,authenticated;

create or replace function public.app_runtime_contract_v160(p_club_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_base jsonb;
begin
  v_base:=public.app_runtime_contract_v160_pre_finance_144(p_club_id);
  if not (coalesce(v_base->'operations','[]'::jsonb) @> '["finance.cargo.crear"]'::jsonb) then
    v_base:=jsonb_set(v_base,'{operations}',coalesce(v_base->'operations','[]'::jsonb)||jsonb_build_array('finance.cargo.crear'),true);
  end if;
  return v_base;
end
$$;
revoke all on function public.app_runtime_contract_v160(uuid) from public,anon;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5) Self-audit: contract version must remain the RC13 version and write path must exist.
-- ---------------------------------------------------------------------------
do $$
declare v_version text;
begin
  select backend_version into v_version from public.app_runtime_meta where singleton=true;
  if v_version is null then raise exception 'FINANCE_V2_144_BACKEND_VERSION_MISSING'; end if;
  if to_regprocedure('public.app_finance_v2_dashboard_v144(uuid,integer,integer,uuid,uuid,uuid,text,text,uuid,text,text,integer,integer)') is null then
    raise exception 'FINANCE_V2_144_DASHBOARD_MISSING';
  end if;
  if to_regprocedure('public.app_finance_v2_preview_cargo_v144(uuid,jsonb,text,text,numeric,date,date)') is null then
    raise exception 'FINANCE_V2_144_PREVIEW_MISSING';
  end if;
  if to_regprocedure('private.finance_create_manual_charge_v144(jsonb,uuid,uuid)') is null then
    raise exception 'FINANCE_V2_144_MANUAL_WRITE_MISSING';
  end if;
end
$$;

notify pgrst,'reload schema';
commit;
