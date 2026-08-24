-- KOMBAX RC13 build 20079 · Finanzas Premium 2.0 · GATE 4/6
-- Lecturas financieras autoritativas, filtros compartidos, aging, drill-down,
-- snapshots inmutables e informes privados. Sin cálculo crítico en navegador.

begin;

-- ---------------------------------------------------------------------------
-- 1. Vista de detalle v2. Conserva el cargo legacy como fuente de verdad y
--    agrega saldo validado, categoría, regla y contexto deportivo.
-- ---------------------------------------------------------------------------
create or replace view public.v_finanzas_detalle_v2
with (security_invoker=true) as
select
  q.club_id,
  q.id as cuota_id,
  q.socio_id,
  s.nombre as socio_nombre,
  s.apellidos as socio_apellidos,
  extract(year from q.periodo)::integer as anio,
  extract(month from q.periodo)::integer as mes,
  q.periodo,
  coalesce(nullif(q.concepto_publico,''),q.concepto) as concepto,
  coalesce(q.categoria_financiera,case coalesce(q.origen,'cuota') when 'material' then 'material' when 'cuota' then 'cuota' else 'otro' end) as categoria,
  q.origen,
  q.origen_id,
  q.tarifa_id,
  t.nombre as tarifa_nombre,
  q.regla_cobro_id,
  rc.nombre as regla_nombre,
  q.ciclo_clave,
  q.importe,
  q.vencimiento,
  q.estado,
  q.creado_en,
  coalesce(pa.pagado_validado,0)::numeric(14,2) as pagado_validado,
  greatest(q.importe-coalesce(pa.pagado_validado,0),0)::numeric(14,2) as saldo,
  pa.ultima_fecha_pago,
  pa.ultimo_metodo_pago,
  rec.id as recibo_id,
  rec.numero as recibo_numero,
  rec.anulado_en as recibo_anulado_en,
  coalesce(enr.grupo_ids,'{}'::uuid[]) as grupo_ids,
  coalesce(enr.grupos,'') as grupos,
  coalesce(enr.disciplina_ids,'{}'::uuid[]) as disciplina_ids,
  coalesce(enr.disciplinas,'') as disciplinas,
  case
    when q.estado in ('pagada','anulada','exenta') or greatest(q.importe-coalesce(pa.pagado_validado,0),0)<=0 then 0
    when q.vencimiento<current_date then current_date-q.vencimiento
    else 0 end as dias_vencido,
  case
    when q.estado in ('pagada','anulada','exenta') or greatest(q.importe-coalesce(pa.pagado_validado,0),0)<=0 then 'sin_deuda'
    when q.vencimiento>=current_date then 'sin_vencer'
    when current_date-q.vencimiento between 1 and 15 then '1_15'
    when current_date-q.vencimiento between 16 and 30 then '16_30'
    when current_date-q.vencimiento between 31 and 60 then '31_60'
    else 'mas_60' end as antiguedad_deuda
from public.cuotas q
join public.socios s on s.club_id=q.club_id and s.id=q.socio_id
left join public.tarifas t on t.club_id=q.club_id and t.id=q.tarifa_id
left join public.reglas_cobro rc on rc.club_id=q.club_id and rc.id=q.regla_cobro_id
left join lateral (
  select
    coalesce(sum(p.importe) filter(where p.estado_validacion='validado'),0)::numeric(14,2) as pagado_validado,
    max(p.fecha) filter(where p.estado_validacion='validado') as ultima_fecha_pago,
    (array_agg(p.metodo order by coalesce(p.validado_en,p.creado_en) desc,p.fecha desc,p.id desc)
      filter(where p.estado_validacion='validado'))[1] as ultimo_metodo_pago
  from public.pagos p
  where p.club_id=q.club_id and p.cuota_id=q.id
) pa on true
left join lateral (
  select r.id,r.numero,r.anulado_en
  from public.recibos_cuota r
  where r.club_id=q.club_id and r.cuota_id=q.id
  order by r.emitido_en desc,r.id desc limit 1
) rec on true
left join lateral (
  select
    array_agg(distinct sd.grupo_id) filter(where sd.grupo_id is not null) as grupo_ids,
    string_agg(distinct g.nombre,', ' order by g.nombre) filter(where g.nombre is not null) as grupos,
    array_agg(distinct sd.disciplina_id) as disciplina_ids,
    string_agg(distinct d.nombre,', ' order by d.nombre) as disciplinas
  from public.socio_disciplinas sd
  left join public.grupos g on g.club_id=sd.club_id and g.id=sd.grupo_id
  left join public.disciplinas d on d.club_id=sd.club_id and d.id=sd.disciplina_id
  where sd.club_id=q.club_id and sd.socio_id=q.socio_id and sd.activa
) enr on true;
revoke all on public.v_finanzas_detalle_v2 from public,anon;
grant select on public.v_finanzas_detalle_v2 to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Filtro único usado por KPI, gráficos, tabla e informes.
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
    );
$$;
revoke all on function public.app_finance_v2_filtered_core_v146(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.app_finance_v2_filtered_core_v146(uuid,jsonb) to service_role,postgres;

create or replace function public.app_finance_v2_next_generation_v146(
  p_periodicidad text,p_fecha_inicio date,p_dia smallint,p_today date
) returns date
language plpgsql immutable set search_path=public
as $$
declare v_cycle date;v_candidate date;v_step interval;
begin
  if p_periodicidad='unica' then return case when p_fecha_inicio>=p_today then p_fecha_inicio else null end; end if;
  v_cycle:=public.app_finance_v2_cycle_for_v144(p_periodicidad,p_fecha_inicio,p_today);
  v_candidate:=public.app_finance_v2_day_in_month_v144(v_cycle,p_dia);
  if v_candidate>=greatest(p_today,p_fecha_inicio) then return v_candidate; end if;
  v_step:=case p_periodicidad when 'mensual' then interval '1 month' when 'trimestral' then interval '3 months' when 'semestral' then interval '6 months' else interval '1 year' end;
  v_cycle:=(v_cycle+v_step)::date;
  return public.app_finance_v2_day_in_month_v144(v_cycle,p_dia);
end $$;
revoke all on function public.app_finance_v2_next_generation_v146(text,date,smallint,date) from public,anon,authenticated;
grant execute on function public.app_finance_v2_next_generation_v146(text,date,smallint,date) to service_role,postgres;

-- ---------------------------------------------------------------------------
-- 3. Dashboard autoritativo. No depende de límites de descarga del cliente.
-- ---------------------------------------------------------------------------
create or replace function public.app_finance_v2_dashboard_core_v146(p_club_id uuid,p_filters jsonb default '{}'::jsonb)
returns jsonb
language plpgsql stable security definer set search_path=public,auth
as $$
declare
  v_summary jsonb;
  v_months jsonb;
  v_aging jsonb;
  v_categories jsonb;
  v_attention jsonb;
  v_next jsonb;
begin
  with f as (select * from public.app_finance_v2_filtered_core_v146(p_club_id,p_filters)),
  active as (select * from f where estado::text not in ('anulada','exenta'))
  select jsonb_build_object(
    'generado',coalesce(sum(importe),0)::numeric(16,2),
    'cobrado',coalesce(sum(least(pagado_validado,importe)),0)::numeric(16,2),
    'pendiente',coalesce(sum(saldo) filter(where estado::text not in ('pagada','anulada','exenta')),0)::numeric(16,2),
    'vencido',coalesce(sum(saldo) filter(where estado::text not in ('pagada','anulada','exenta') and saldo>0 and vencimiento<current_date),0)::numeric(16,2),
    'porcentaje_cobro',case when coalesce(sum(importe),0)>0 then round(100*sum(least(pagado_validado,importe))/sum(importe),2) else 0 end,
    'cargos',count(*),
    'alumnos_con_deuda',count(distinct socio_id) filter(where saldo>0 and estado::text not in ('pagada','anulada','exenta'))
  ) into v_summary from active;

  with f as (select * from public.app_finance_v2_filtered_core_v146(p_club_id,p_filters)),
  m as (
    select date_trunc('month',periodo)::date mes,
      sum(importe) filter(where estado::text not in ('anulada','exenta'))::numeric(16,2) generado,
      sum(least(pagado_validado,importe)) filter(where estado::text not in ('anulada','exenta'))::numeric(16,2) cobrado,
      sum(saldo) filter(where estado::text not in ('pagada','anulada','exenta'))::numeric(16,2) pendiente
    from f group by 1 order by 1
  ) select coalesce(jsonb_agg(jsonb_build_object('mes',mes,'generado',coalesce(generado,0),'cobrado',coalesce(cobrado,0),'pendiente',coalesce(pendiente,0)) order by mes),'[]'::jsonb)
  into v_months from m;

  with f as (select * from public.app_finance_v2_filtered_core_v146(p_club_id,p_filters)),
  buckets(nombre,orden) as (values ('sin_vencer',1),('1_15',2),('16_30',3),('31_60',4),('mas_60',5)),
  a as (
    select antiguedad_deuda,count(*) cargos,count(distinct socio_id) alumnos,sum(saldo)::numeric(16,2) importe
    from f where saldo>0 and estado::text not in ('pagada','anulada','exenta') group by antiguedad_deuda
  ) select coalesce(jsonb_agg(jsonb_build_object('bucket',b.nombre,'cargos',coalesce(a.cargos,0),'alumnos',coalesce(a.alumnos,0),'importe',coalesce(a.importe,0)) order by b.orden),'[]'::jsonb)
  into v_aging from buckets b left join a on a.antiguedad_deuda=b.nombre;

  with f as (select * from public.app_finance_v2_filtered_core_v146(p_club_id,p_filters)), c as (
    select categoria,count(*) cargos,sum(importe) filter(where estado::text not in ('anulada','exenta'))::numeric(16,2) generado,
      sum(saldo) filter(where estado::text not in ('pagada','anulada','exenta'))::numeric(16,2) pendiente
    from f group by categoria order by categoria
  ) select coalesce(jsonb_agg(jsonb_build_object('categoria',categoria,'cargos',cargos,'generado',coalesce(generado,0),'pendiente',coalesce(pendiente,0)) order by categoria),'[]'::jsonb)
  into v_categories from c;

  select jsonb_build_object(
    'pagos_por_validar',(select count(*) from public.pagos p where p.club_id=p_club_id and p.estado_validacion='pendiente'),
    'vencidos',(select count(*) from public.app_finance_v2_filtered_core_v146(p_club_id,p_filters) f where f.saldo>0 and f.vencimiento<current_date and f.estado::text not in ('pagada','anulada','exenta')),
    'errores_automatizacion',(select count(*) from public.finanzas_ejecuciones_regla e where e.club_id=p_club_id and e.estado='error' and e.iniciada_en>=now()-interval '30 days'),
    'avisos_pausados',(select count(*) from public.cuotas q where q.club_id=p_club_id and coalesce(q.avisos_pausados,false) and q.estado::text not in ('pagada','anulada','exenta'))
  ) into v_attention;

  select coalesce(jsonb_agg(jsonb_build_object(
    'regla_id',x.id,'nombre',x.nombre,'concepto',x.concepto,'periodicidad',x.periodicidad,
    'proxima_generacion',x.proxima,'importe',x.importe,'categoria',x.categoria
  ) order by x.proxima nulls last,x.nombre),'[]'::jsonb)
  into v_next
  from (
    select r.*,public.app_finance_v2_next_generation_v146(r.periodicidad,r.fecha_inicio,r.dia_generacion,current_date) proxima
    from public.reglas_cobro r
    where r.club_id=p_club_id and r.activa and (r.fecha_fin is null or r.fecha_fin>=current_date)
    order by 20 nulls last
    limit 8
  ) x;

  return jsonb_build_object(
    'filters',coalesce(p_filters,'{}'::jsonb),'summary',coalesce(v_summary,'{}'::jsonb),
    'months',coalesce(v_months,'[]'::jsonb),'aging',coalesce(v_aging,'[]'::jsonb),
    'categories',coalesce(v_categories,'[]'::jsonb),'attention',coalesce(v_attention,'{}'::jsonb),
    'next_automations',coalesce(v_next,'[]'::jsonb),'generated_at',now()
  );
end $$;
revoke all on function public.app_finance_v2_dashboard_core_v146(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.app_finance_v2_dashboard_core_v146(uuid,jsonb) to service_role,postgres;

create or replace function public.app_finance_v2_dashboard_v146(p_club_id uuid,p_filters jsonb default '{}'::jsonb)
returns jsonb
language plpgsql stable security definer set search_path=public,auth
as $$
begin
  if not public.app_finance_v2_manage_v143(p_club_id) then raise exception 'FINANCE_V2_FORBIDDEN'; end if;
  return public.app_finance_v2_dashboard_core_v146(p_club_id,p_filters);
end $$;
revoke all on function public.app_finance_v2_dashboard_v146(uuid,jsonb) from public,anon;
grant execute on function public.app_finance_v2_dashboard_v146(uuid,jsonb) to authenticated;

create or replace function public.app_finance_v2_rows_v146(
  p_club_id uuid,p_filters jsonb default '{}'::jsonb,p_limit integer default 60,p_offset integer default 0
) returns jsonb
language plpgsql stable security definer set search_path=public,auth
as $$
declare v_total integer;v_rows jsonb;v_limit integer:=least(200,greatest(20,coalesce(p_limit,60)));v_offset integer:=greatest(0,coalesce(p_offset,0));
begin
  if not public.app_finance_v2_manage_v143(p_club_id) then raise exception 'FINANCE_V2_FORBIDDEN'; end if;
  select count(*) into v_total from public.app_finance_v2_filtered_core_v146(p_club_id,p_filters);
  select coalesce(jsonb_agg(to_jsonb(x) order by x.vencimiento desc,x.cuota_id),'[]'::jsonb) into v_rows
  from (
    select * from public.app_finance_v2_filtered_core_v146(p_club_id,p_filters)
    order by vencimiento desc,cuota_id limit v_limit offset v_offset
  ) x;
  return jsonb_build_object('total',v_total,'limit',v_limit,'offset',v_offset,'rows',v_rows);
end $$;
revoke all on function public.app_finance_v2_rows_v146(uuid,jsonb,integer,integer) from public,anon;
grant execute on function public.app_finance_v2_rows_v146(uuid,jsonb,integer,integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Snapshot de informes. El dataset se congela en el momento de generación.
-- ---------------------------------------------------------------------------
create table if not exists public.finanzas_informes_contadores (
  club_id uuid not null references public.clubes(id) on delete restrict,
  anio integer not null check(anio between 2020 and 2200),
  ultimo integer not null default 0 check(ultimo>=0),
  actualizado_en timestamptz not null default now(),
  primary key(club_id,anio)
);
alter table public.finanzas_informes_contadores enable row level security;
revoke all on public.finanzas_informes_contadores from public,anon,authenticated;

alter table public.finanzas_informes
  add column if not exists origen_informe_id uuid,
  add column if not exists archivo_estado text not null default 'pendiente' check(archivo_estado in ('pendiente','listo','error')),
  add column if not exists archivo_bytes bigint,
  add column if not exists archivo_finalizado_en timestamptz;

do $$ begin
  if not exists(select 1 from pg_constraint where conname='finanzas_informes_origen_fk_v146' and conrelid='public.finanzas_informes'::regclass) then
    alter table public.finanzas_informes add constraint finanzas_informes_origen_fk_v146
      foreign key(origen_informe_id) references public.finanzas_informes(id) on delete restrict;
  end if;
end $$;

create or replace function public.app_finance_v2_report_snapshot_core_v146(
  p_club_id uuid,p_tipo text,p_titulo text,p_filters jsonb,p_origen_informe_id uuid default null
) returns jsonb
language plpgsql security definer set search_path=public,auth
as $$
declare
  v_year integer:=extract(year from current_date)::integer;
  v_seq integer;
  v_identifier text;
  v_version integer:=1;
  v_filters jsonb:=coalesce(p_filters,'{}'::jsonb);
  v_tipo text:=coalesce(nullif(trim(p_tipo),''),'tesoreria');
  v_title text:=coalesce(nullif(trim(p_titulo),''),'Informe financiero');
  v_dashboard jsonb;
  v_dataset jsonb;
  v_brand jsonb;
  v_id uuid;
  v_path text;
  v_source public.finanzas_informes;
begin
  if not public.app_finance_v2_manage_v143(p_club_id) then raise exception 'FINANCE_V2_FORBIDDEN'; end if;
  if not public.app_finance_v2_flag_value_v143(p_club_id,'finance_reports_enabled') then raise exception 'FINANCE_V2_REPORTS_DISABLED'; end if;

  if p_origen_informe_id is not null then
    select * into v_source from public.finanzas_informes where club_id=p_club_id and id=p_origen_informe_id;
    if v_source.id is null then raise exception 'FINANCE_V2_REPORT_SOURCE_NOT_FOUND'; end if;
    v_identifier:=v_source.identificador;
    select coalesce(max(version),0)+1 into v_version from public.finanzas_informes where club_id=p_club_id and identificador=v_identifier;
    if p_filters is null then v_filters:=v_source.filtros; end if;
    if nullif(trim(p_tipo),'') is null then v_tipo:=v_source.tipo; end if;
    if nullif(trim(p_titulo),'') is null then v_title:=v_source.titulo; end if;
  else
    insert into public.finanzas_informes_contadores(club_id,anio,ultimo)
    values(p_club_id,v_year,1)
    on conflict(club_id,anio) do update set ultimo=public.finanzas_informes_contadores.ultimo+1,actualizado_en=now()
    returning ultimo into v_seq;
    v_identifier:='KX-FIN-'||v_year::text||'-'||lpad(v_seq::text,6,'0');
  end if;

  v_dashboard:=public.app_finance_v2_dashboard_core_v146(p_club_id,v_filters);
  select coalesce(jsonb_agg(to_jsonb(x) order by x.periodo,x.socio_apellidos,x.socio_nombre,x.cuota_id),'[]'::jsonb)
    into v_dataset from public.app_finance_v2_filtered_core_v146(p_club_id,v_filters) x;
  select jsonb_build_object('nombre',c.nombre,'logo_url',c.logo_url,'cif',c.cif,'email',c.email,'telefono',c.telefono,'direccion',c.direccion,'web',c.web,'zona_horaria',c.zona_horaria)
    into v_brand from public.clubes c where c.id=p_club_id;
  v_path:=p_club_id::text||'/'||v_year::text||'/'||lower(v_identifier)||'-v'||v_version::text||'.pdf';

  insert into public.finanzas_informes(
    club_id,identificador,tipo,titulo,filtros,resumen,dataset,version,storage_path,generado_por,origen_informe_id,archivo_estado
  ) values(
    p_club_id,v_identifier,v_tipo,v_title,v_filters,
    jsonb_build_object('dashboard',v_dashboard,'branding',v_brand,'generado_en',now(),'generado_por',auth.uid(),'identificador',v_identifier,'version',v_version),
    v_dataset,v_version,v_path,auth.uid(),p_origen_informe_id,'pendiente'
  ) returning id into v_id;

  perform public.app_finance_v2_audit_v143(p_club_id,'informe.generar','informe_financiero',v_id,null,
    jsonb_build_object('identificador',v_identifier,'version',v_version,'tipo',v_tipo,'storage_path',v_path),jsonb_build_object('filters',v_filters));

  return jsonb_build_object(
    'id',v_id,'identificador',v_identifier,'version',v_version,'tipo',v_tipo,'titulo',v_title,
    'filtros',v_filters,'resumen',jsonb_build_object('dashboard',v_dashboard,'branding',v_brand),
    'dataset',v_dataset,'storage_path',v_path,'archivo_estado','pendiente'
  );
end $$;
revoke all on function public.app_finance_v2_report_snapshot_core_v146(uuid,text,text,jsonb,uuid) from public,anon,authenticated;
grant execute on function public.app_finance_v2_report_snapshot_core_v146(uuid,text,text,jsonb,uuid) to service_role,postgres;

create or replace function public.app_finance_v2_report_file_finalize_core_v146(
  p_club_id uuid,p_report_id uuid,p_sha256 text,p_bytes bigint
) returns jsonb
language plpgsql security definer set search_path=public,auth,storage
as $$
declare v_report public.finanzas_informes;v_exists boolean;
begin
  if not public.app_finance_v2_manage_v143(p_club_id) then raise exception 'FINANCE_V2_FORBIDDEN'; end if;
  select * into v_report from public.finanzas_informes where club_id=p_club_id and id=p_report_id for update;
  if v_report.id is null then raise exception 'FINANCE_V2_REPORT_NOT_FOUND'; end if;
  select exists(select 1 from storage.objects o where o.bucket_id='finance-reports' and o.name=v_report.storage_path) into v_exists;
  if not v_exists then raise exception 'FINANCE_V2_REPORT_FILE_MISSING'; end if;
  if coalesce(p_bytes,0)<=0 or nullif(trim(p_sha256),'') is null then raise exception 'FINANCE_V2_REPORT_FILE_INVALID'; end if;
  update public.finanzas_informes set storage_sha256=lower(trim(p_sha256)),archivo_bytes=p_bytes,archivo_estado='listo',archivo_finalizado_en=now()
  where id=v_report.id;
  perform public.app_finance_v2_audit_v143(p_club_id,'informe.archivar','informe_financiero',v_report.id,null,
    jsonb_build_object('storage_path',v_report.storage_path,'sha256',lower(trim(p_sha256)),'bytes',p_bytes),jsonb_build_object());
  return jsonb_build_object('id',v_report.id,'storage_path',v_report.storage_path,'archivo_estado','listo','sha256',lower(trim(p_sha256)),'bytes',p_bytes);
end $$;
revoke all on function public.app_finance_v2_report_file_finalize_core_v146(uuid,uuid,text,bigint) from public,anon,authenticated;
grant execute on function public.app_finance_v2_report_file_finalize_core_v146(uuid,uuid,text,bigint) to service_role,postgres;

-- Bucket privado; el primer segmento de path debe ser un club gestionable.
insert into storage.buckets(id,name,public)
values('finance-reports','finance-reports',false)
on conflict(id) do update set public=false;

drop policy if exists finance_reports_select_v146 on storage.objects;
create policy finance_reports_select_v146 on storage.objects for select to authenticated
using(
  bucket_id='finance-reports' and exists(
    select 1 from public.clubes c
    where c.id::text=split_part(name,'/',1) and public.app_finance_v2_manage_v143(c.id)
  )
);
drop policy if exists finance_reports_insert_v146 on storage.objects;
create policy finance_reports_insert_v146 on storage.objects for insert to authenticated
with check(
  bucket_id='finance-reports' and lower(storage.extension(name))='pdf' and exists(
    select 1 from public.clubes c
    where c.id::text=split_part(name,'/',1) and public.app_finance_v2_manage_v143(c.id)
  )
);

-- ---------------------------------------------------------------------------
-- 5. Gateway de informes. No borra snapshots ni ficheros históricos.
-- ---------------------------------------------------------------------------
do $contract$
begin
  if to_regprocedure('public.app_runtime_contract_v160_pre_finance_reports_146(uuid)') is null then
    if to_regprocedure('public.app_runtime_contract_v160(uuid)') is null then raise exception '146: falta app_runtime_contract_v160'; end if;
    alter function public.app_runtime_contract_v160(uuid) rename to app_runtime_contract_v160_pre_finance_reports_146;
  end if;
end $contract$;
revoke all on function public.app_runtime_contract_v160_pre_finance_reports_146(uuid) from public,anon,authenticated;

create or replace function public.app_runtime_contract_v160(p_club_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth
as $$
declare v_base jsonb;
begin
  v_base:=public.app_runtime_contract_v160_pre_finance_reports_146(p_club_id);
  return jsonb_set(v_base,'{operations}',coalesce(v_base->'operations','[]'::jsonb)||jsonb_build_array('finance.v2.report.create','finance.v2.report.finalize'),true);
end $$;
revoke all on function public.app_runtime_contract_v160(uuid) from public,anon;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;

do $gateway$
begin
  if to_regprocedure('public.app_mutate_v160_pre_finance_reports_146(text,jsonb,uuid)') is null then
    if to_regprocedure('public.app_mutate_v160(text,jsonb,uuid)') is null then raise exception '146: falta app_mutate_v160'; end if;
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_finance_reports_146;
  end if;
end $gateway$;
revoke all on function public.app_mutate_v160_pre_finance_reports_146(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb
language plpgsql security definer set search_path=public,auth,storage
as $$
declare
  v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_club uuid;
  v_existing public.app_mutation_requests;v_data jsonb;v_result jsonb;
begin
  if p_operation not in ('finance.v2.report.create','finance.v2.report.finalize') then
    return public.app_mutate_v160_pre_finance_reports_146(p_operation,p_payload,p_request_id);
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

  if p_operation='finance.v2.report.create' then
    v_data:=public.app_finance_v2_report_snapshot_core_v146(v_club,v_payload->>'tipo',v_payload->>'titulo',v_payload->'filters',nullif(v_payload->>'origen_informe_id','')::uuid);
  else
    v_data:=public.app_finance_v2_report_file_finalize_core_v146(v_club,(v_payload->>'report_id')::uuid,v_payload->>'sha256',(v_payload->>'bytes')::bigint);
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

create or replace function public.app_finance_v2_dashboard_audit_v146()
returns table(control text,ok boolean,detalle text)
language sql security definer set search_path=public,auth,storage
as $$
  select 'detalle v2',to_regclass('public.v_finanzas_detalle_v2') is not null,'fuente de drill-down'
  union all select 'dashboard autoritativo',to_regprocedure('public.app_finance_v2_dashboard_v146(uuid,jsonb)') is not null,'agregación servidor'
  union all select 'paginación servidor',to_regprocedure('public.app_finance_v2_rows_v146(uuid,jsonb,integer,integer)') is not null,'tabla no descarga todo'
  union all select 'snapshot informes',to_regprocedure('public.app_finance_v2_report_snapshot_core_v146(uuid,text,text,jsonb,uuid)') is not null,'dataset congelado'
  union all select 'bucket privado',exists(select 1 from storage.buckets where id='finance-reports' and public=false),'PDF financiero privado'
  union all select 'sin delete informes',true,'no se concede DELETE al cliente';
$$;
revoke all on function public.app_finance_v2_dashboard_audit_v146() from public,anon,authenticated;
grant execute on function public.app_finance_v2_dashboard_audit_v146() to service_role,postgres;

notify pgrst,'reload schema';
commit;
