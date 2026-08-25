begin;

-- KOMBAX RC13 build 20081 · Finance Premium 2.0 · Informes históricos
-- Additive only: snapshots are immutable, PDFs live in private storage and the
-- existing finance/payment/receipt contracts remain authoritative.

-- ---------------------------------------------------------------------------
-- 1) Historical report registry + private storage
-- ---------------------------------------------------------------------------
create table if not exists public.informes_financieros (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubes(id) on delete restrict,
  serie_id uuid not null,
  version integer not null default 1 check (version >= 1),
  source_report_id uuid null references public.informes_financieros(id) on delete restrict,
  identificador text not null,
  tipo text not null check (tipo in (
    'vista_actual','tesoreria_mensual','tesoreria_anual','cobros','pendientes','vencidos',
    'por_grupo','por_disciplina','por_categoria','por_metodo_pago','licencias',
    'competiciones','eventos','estado_cuenta'
  )),
  titulo text not null,
  socio_id uuid null,
  periodo_desde date null,
  periodo_hasta date null,
  filtros jsonb not null default '{}'::jsonb,
  snapshot jsonb not null,
  totales jsonb not null default '{}'::jsonb,
  dataset_rows integer not null default 0 check (dataset_rows >= 0),
  generado_por uuid not null,
  generado_en timestamptz not null default now(),
  archivo_path text null,
  archivo_mime text null,
  archivo_bytes bigint null check (archivo_bytes is null or archivo_bytes >= 0),
  archivo_sha256 text null,
  archivo_generado_en timestamptz null,
  constraint uq_informes_financieros_identificador_v145 unique (club_id,identificador),
  constraint uq_informes_financieros_serie_version_v145 unique (club_id,serie_id,version)
);

create index if not exists idx_informes_financieros_club_fecha_v145
  on public.informes_financieros(club_id,generado_en desc,id desc);
create index if not exists idx_informes_financieros_socio_v145
  on public.informes_financieros(club_id,socio_id,generado_en desc) where socio_id is not null;

alter table public.informes_financieros enable row level security;
drop policy if exists informes_financieros_read_v145 on public.informes_financieros;
create policy informes_financieros_read_v145 on public.informes_financieros
  for select to authenticated
  using (public.tiene_rol_club(club_id,'direccion','secretaria','economia'));
revoke all on table public.informes_financieros from public,anon;
grant select on table public.informes_financieros to authenticated;

create table if not exists private.informes_financieros_secuencia_v145 (
  club_id uuid primary key references public.clubes(id) on delete cascade,
  siguiente bigint not null default 1 check (siguiente >= 1)
);
revoke all on table private.informes_financieros_secuencia_v145 from public,anon,authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('finance-reports','finance-reports',false,20971520,array['application/pdf'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists finance_reports_read_v145 on storage.objects;
create policy finance_reports_read_v145 on storage.objects
  for select to authenticated
  using (
    bucket_id='finance-reports'
    and array_length(storage.foldername(name),1)>=3
    and public.tiene_rol_club(((storage.foldername(name))[1])::uuid,'direccion','secretaria','economia')
  );

-- No authenticated INSERT/UPDATE/DELETE policy is created for finance-reports.
-- The PDF edge worker writes with service_role only after an authenticated RPC
-- proves the caller may read the immutable report snapshot.

-- Only file metadata may be attached after the snapshot exists. The financial
-- snapshot, filters, totals, actor, identifier and lineage never change.
create or replace function private.finance_report_immutable_v145()
returns trigger
language plpgsql
set search_path=''
as $$
begin
  if old.archivo_path is not null and (
       new.archivo_path is distinct from old.archivo_path
       or new.archivo_mime is distinct from old.archivo_mime
       or new.archivo_bytes is distinct from old.archivo_bytes
       or new.archivo_sha256 is distinct from old.archivo_sha256
       or new.archivo_generado_en is distinct from old.archivo_generado_en
     ) then raise exception 'FINANCE_REPORT_FILE_IMMUTABLE'; end if;
  if new.club_id is distinct from old.club_id
     or new.serie_id is distinct from old.serie_id
     or new.version is distinct from old.version
     or new.source_report_id is distinct from old.source_report_id
     or new.identificador is distinct from old.identificador
     or new.tipo is distinct from old.tipo
     or new.titulo is distinct from old.titulo
     or new.socio_id is distinct from old.socio_id
     or new.periodo_desde is distinct from old.periodo_desde
     or new.periodo_hasta is distinct from old.periodo_hasta
     or new.filtros is distinct from old.filtros
     or new.snapshot is distinct from old.snapshot
     or new.totales is distinct from old.totales
     or new.dataset_rows is distinct from old.dataset_rows
     or new.generado_por is distinct from old.generado_por
     or new.generado_en is distinct from old.generado_en then
    raise exception 'FINANCE_REPORT_SNAPSHOT_IMMUTABLE';
  end if;
  return new;
end
$$;
revoke all on function private.finance_report_immutable_v145() from public,anon,authenticated;

drop trigger if exists trg_finance_report_immutable_v145 on public.informes_financieros;
create trigger trg_finance_report_immutable_v145
before update on public.informes_financieros
for each row execute function private.finance_report_immutable_v145();

-- ---------------------------------------------------------------------------
-- 2) Snapshot builder. It reuses dashboard v144 page-by-page so the exact same
--    filter semantics drive KPI, charts, table and report datasets.
-- ---------------------------------------------------------------------------
create or replace function private.finance_create_report_v145(
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
  v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);
  v_filters jsonb:=coalesce(v_payload->'filtros','{}'::jsonb);
  v_type text:=lower(trim(coalesce(v_payload->>'tipo','vista_actual')));
  v_title text;
  v_source uuid;
  v_source_row public.informes_financieros;
  v_series uuid:=gen_random_uuid();
  v_version integer:=1;
  v_seq bigint;
  v_identifier text;
  v_report_id uuid:=gen_random_uuid();
  v_year integer;
  v_month integer;
  v_socio uuid;
  v_group uuid;
  v_disc uuid;
  v_rule uuid;
  v_category text;
  v_state text;
  v_method text;
  v_aging text;
  v_dash jsonb;
  v_page jsonb;
  v_rows jsonb:='[]'::jsonb;
  v_total integer:=0;
  v_offset integer:=0;
  v_summary jsonb:='{}'::jsonb;
  v_months jsonb:='[]'::jsonb;
  v_aging_data jsonb:='[]'::jsonb;
  v_club_row public.clubes;
  v_actor public.perfiles;
  v_labels jsonb:='{}'::jsonb;
  v_snapshot jsonb;
  v_from date;
  v_to date;
  v_generated timestamptz:=now();
begin
  if p_uid is null or p_club is null then raise exception 'FINANCE_REPORT_AUTH_REQUIRED'; end if;
  if not public.tiene_rol_club(p_club,'direccion','secretaria','economia') then raise exception 'FINANCE_REPORT_FORBIDDEN'; end if;
  if not private.finance_flag_v143(p_club,'finance_v2_enabled') or not private.finance_flag_v143(p_club,'finance_reports_enabled') then
    raise exception 'FINANCE_REPORTS_DISABLED';
  end if;

  begin v_source:=nullif(trim(coalesce(v_payload->>'source_report_id','')),'')::uuid;
  exception when others then raise exception 'FINANCE_REPORT_SOURCE_INVALID'; end;

  if v_source is not null then
    select * into v_source_row from public.informes_financieros where id=v_source and club_id=p_club;
    if v_source_row.id is null then raise exception 'FINANCE_REPORT_SOURCE_NOT_FOUND'; end if;
    v_type:=v_source_row.tipo;
    v_filters:=v_source_row.filtros;
    v_series:=v_source_row.serie_id;
    select coalesce(max(version),0)+1 into v_version from public.informes_financieros where club_id=p_club and serie_id=v_series;
  end if;

  if v_type not in (
    'vista_actual','tesoreria_mensual','tesoreria_anual','cobros','pendientes','vencidos',
    'por_grupo','por_disciplina','por_categoria','por_metodo_pago','licencias',
    'competiciones','eventos','estado_cuenta'
  ) then raise exception 'FINANCE_REPORT_TYPE_INVALID'; end if;

  -- Type-specific semantic filters. `vista_actual` remains byte-for-byte the
  -- same logical filter set the dashboard sends.
  if v_type='cobros' then v_filters:=jsonb_set(v_filters,'{estado}','"cobrado"'::jsonb,true); end if;
  if v_type='pendientes' then v_filters:=jsonb_set(v_filters,'{estado}','"pendiente_abierto"'::jsonb,true); end if;
  if v_type='vencidos' then v_filters:=jsonb_set(v_filters,'{estado}','"vencido_abierto"'::jsonb,true); end if;
  if v_type='licencias' then v_filters:=jsonb_set(v_filters,'{categoria}','"licencia"'::jsonb,true); end if;
  if v_type='competiciones' then v_filters:=jsonb_set(v_filters,'{categoria}','"competicion"'::jsonb,true); end if;
  if v_type='eventos' then v_filters:=jsonb_set(v_filters,'{categoria}','"evento"'::jsonb,true); end if;
  if v_type='tesoreria_anual' then
    if nullif(v_filters->>'year','') is null then v_filters:=jsonb_set(v_filters,'{year}',to_jsonb(extract(year from current_date)::int),true); end if;
    v_filters:=jsonb_set(v_filters,'{month}','""'::jsonb,true);
  end if;
  if v_type='tesoreria_mensual' then
    if nullif(v_filters->>'year','') is null then v_filters:=jsonb_set(v_filters,'{year}',to_jsonb(extract(year from current_date)::int),true); end if;
    if nullif(v_filters->>'month','') is null then v_filters:=jsonb_set(v_filters,'{month}',to_jsonb(extract(month from current_date)::int),true); end if;
  end if;

  begin
    v_year:=nullif(v_filters->>'year','')::integer;
    v_month:=nullif(v_filters->>'month','')::integer;
    v_socio:=nullif(v_filters->>'socio','')::uuid;
    v_group:=nullif(v_filters->>'grupo','')::uuid;
    v_disc:=nullif(v_filters->>'disciplina','')::uuid;
    v_rule:=nullif(v_filters->>'regla','')::uuid;
  exception when others then raise exception 'FINANCE_REPORT_FILTER_INVALID'; end;
  v_category:=nullif(v_filters->>'categoria','');
  v_state:=nullif(v_filters->>'estado','');
  v_method:=nullif(v_filters->>'metodo','');
  v_aging:=nullif(v_filters->>'aging','');

  if v_type='estado_cuenta' and v_socio is null then raise exception 'FINANCE_REPORT_ACCOUNT_REQUIRES_MEMBER'; end if;
  if v_month is not null and (v_month<1 or v_month>12) then raise exception 'FINANCE_REPORT_MONTH_INVALID'; end if;

  v_dash:=public.app_finance_v2_dashboard_v144(
    p_club,v_year,v_month,v_socio,v_group,v_disc,v_category,v_state,v_rule,v_method,v_aging,500,0
  );
  v_total:=coalesce((v_dash->>'total_rows')::integer,0);
  if v_total>5000 then raise exception 'FINANCE_REPORT_TOO_LARGE: aplica filtros antes de generar el informe'; end if;
  v_rows:=coalesce(v_dash->'rows','[]'::jsonb);
  v_summary:=coalesce(v_dash->'summary','{}'::jsonb);
  v_months:=coalesce(v_dash->'months','[]'::jsonb);
  v_aging_data:=coalesce(v_dash->'aging','[]'::jsonb);

  if v_total>500 then
    v_offset:=500;
    while v_offset<v_total loop
      v_page:=public.app_finance_v2_dashboard_v144(
        p_club,v_year,v_month,v_socio,v_group,v_disc,v_category,v_state,v_rule,v_method,v_aging,500,v_offset
      );
      v_rows:=v_rows||coalesce(v_page->'rows','[]'::jsonb);
      v_offset:=v_offset+500;
    end loop;
  end if;

  select * into v_club_row from public.clubes where id=p_club;
  select * into v_actor from public.perfiles where id=p_uid;

  select jsonb_build_object(
    'socio',coalesce((select trim(concat_ws(' ',s.nombre,s.apellidos)) from public.socios s where s.club_id=p_club and s.id=v_socio),''),
    'grupo',coalesce((select g.nombre from public.grupos g where g.club_id=p_club and g.id=v_group),''),
    'disciplina',coalesce((select d.nombre from public.disciplinas d where d.club_id=p_club and d.id=v_disc),''),
    'regla',coalesce((select r.nombre from public.reglas_cobro r where r.club_id=p_club and r.id=v_rule),''),
    'categoria',coalesce(v_category,''),'estado',coalesce(v_state,''),'metodo',coalesce(v_method,''),'aging',coalesce(v_aging,'')
  ) into v_labels;

  if v_year is not null and v_month is not null then
    v_from:=make_date(v_year,v_month,1);
    v_to:=(v_from+interval '1 month-1 day')::date;
  elsif v_year is not null then
    v_from:=make_date(v_year,1,1);v_to:=make_date(v_year,12,31);
  else
    select min((x->>'periodo')::date),max((x->>'periodo')::date) into v_from,v_to from jsonb_array_elements(v_rows) x;
  end if;

  v_title:=nullif(trim(coalesce(v_payload->>'titulo','')),'');
  if v_title is null or v_source is not null then
    v_title:=case v_type
      when 'vista_actual' then 'Informe de la vista financiera'
      when 'tesoreria_mensual' then 'Tesorería mensual'
      when 'tesoreria_anual' then 'Tesorería anual'
      when 'cobros' then 'Informe de cobros'
      when 'pendientes' then 'Informe de pendientes'
      when 'vencidos' then 'Informe de vencidos'
      when 'por_grupo' then 'Informe por grupo'
      when 'por_disciplina' then 'Informe por disciplina'
      when 'por_categoria' then 'Informe por categoría'
      when 'por_metodo_pago' then 'Informe por método de pago'
      when 'licencias' then 'Informe de licencias'
      when 'competiciones' then 'Informe de competiciones'
      when 'eventos' then 'Informe de eventos'
      when 'estado_cuenta' then 'Estado de cuenta individual'
      else 'Informe financiero' end;
  end if;

  insert into private.informes_financieros_secuencia_v145(club_id,siguiente)
  values(p_club,2)
  on conflict(club_id) do update set siguiente=private.informes_financieros_secuencia_v145.siguiente+1
  returning siguiente-1 into v_seq;
  v_identifier:='KX-FIN-'||to_char(v_generated at time zone coalesce(v_club_row.zona_horaria,'Europe/Madrid'),'YYYY')||'-'||lpad(v_seq::text,6,'0');

  v_snapshot:=jsonb_build_object(
    'schema_version','finance-report-v145',
    'identificador',v_identifier,
    'tipo',v_type,
    'titulo',v_title,
    'version',v_version,
    'generado_en',v_generated,
    'generado_por',jsonb_build_object('id',p_uid,'nombre',coalesce(v_actor.nombre,''),'apellidos',coalesce(v_actor.apellidos,'')),
    'club',jsonb_build_object(
      'id',v_club_row.id,'nombre',v_club_row.nombre,'cif',v_club_row.cif,'email',v_club_row.email,
      'telefono',v_club_row.telefono,'direccion',v_club_row.direccion,'web',v_club_row.web,
      'logo_url',v_club_row.logo_url,'color_primario',v_club_row.color_primario,'color_secundario',v_club_row.color_secundario,
      'branding_version',v_club_row.branding_version,'zona_horaria',v_club_row.zona_horaria
    ),
    'periodo',jsonb_build_object('desde',v_from,'hasta',v_to),
    'filtros',v_filters,
    'filtros_etiquetas',v_labels,
    'totales',v_summary,
    'meses',v_months,
    'antiguedad',v_aging_data,
    'dataset_rows',jsonb_array_length(v_rows),
    'rows',v_rows,
    'group_discipline_scope','snapshot_at_report_generation',
    'nota_historica','Este informe es un snapshot inmutable. Los cambios financieros posteriores no modifican este documento.'
  );

  insert into public.informes_financieros(
    id,club_id,serie_id,version,source_report_id,identificador,tipo,titulo,socio_id,
    periodo_desde,periodo_hasta,filtros,snapshot,totales,dataset_rows,generado_por,generado_en
  ) values(
    v_report_id,p_club,v_series,v_version,v_source,v_identifier,v_type,v_title,v_socio,
    v_from,v_to,v_filters,v_snapshot,v_summary,jsonb_array_length(v_rows),p_uid,v_generated
  );

  return jsonb_build_object(
    'report_id',v_report_id,'identificador',v_identifier,'tipo',v_type,'titulo',v_title,
    'version',v_version,'dataset_rows',jsonb_array_length(v_rows),'totales',v_summary,'archivo_listo',false
  );
end
$$;
revoke all on function private.finance_create_report_v145(jsonb,uuid,uuid) from public,anon,authenticated;

-- ---------------------------------------------------------------------------
-- 3) Read APIs for the premium UI and the authenticated PDF worker
-- ---------------------------------------------------------------------------
create or replace function public.app_finance_v2_reports_v145(
  p_club_id uuid,
  p_limit integer default 100
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if auth.uid() is null or not public.tiene_rol_club(p_club_id,'direccion','secretaria','economia') then
    raise exception 'FINANCE_REPORTS_FORBIDDEN';
  end if;
  if not private.finance_flag_v143(p_club_id,'finance_reports_enabled') then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',r.id,'club_id',r.club_id,'serie_id',r.serie_id,'version',r.version,'source_report_id',r.source_report_id,
      'identificador',r.identificador,'tipo',r.tipo,'titulo',r.titulo,'socio_id',r.socio_id,
      'periodo_desde',r.periodo_desde,'periodo_hasta',r.periodo_hasta,'filtros',r.filtros,
      'totales',r.totales,'dataset_rows',r.dataset_rows,'generado_por',r.generado_por,'generado_en',r.generado_en,
      'archivo_path',r.archivo_path,'archivo_mime',r.archivo_mime,'archivo_bytes',r.archivo_bytes,
      'archivo_sha256',r.archivo_sha256,'archivo_generado_en',r.archivo_generado_en
    ) order by r.generado_en desc,r.id desc)
    from (select * from public.informes_financieros where club_id=p_club_id order by generado_en desc,id desc limit least(greatest(coalesce(p_limit,100),10),300)) r
  ),'[]'::jsonb);
end
$$;
revoke all on function public.app_finance_v2_reports_v145(uuid,integer) from public,anon;
grant execute on function public.app_finance_v2_reports_v145(uuid,integer) to authenticated;

create or replace function public.app_finance_v2_report_payload_v145(p_report_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare r public.informes_financieros;
begin
  select * into r from public.informes_financieros where id=p_report_id;
  if r.id is null then raise exception 'FINANCE_REPORT_NOT_FOUND'; end if;
  if auth.uid() is null or not public.tiene_rol_club(r.club_id,'direccion','secretaria','economia') then
    raise exception 'FINANCE_REPORT_FORBIDDEN';
  end if;
  return jsonb_build_object(
    'id',r.id,'club_id',r.club_id,'identificador',r.identificador,'tipo',r.tipo,'titulo',r.titulo,
    'version',r.version,'snapshot',r.snapshot,'dataset_rows',r.dataset_rows,'generado_en',r.generado_en,
    'archivo_path',r.archivo_path,'archivo_mime',r.archivo_mime,'archivo_bytes',r.archivo_bytes,
    'archivo_sha256',r.archivo_sha256,'archivo_generado_en',r.archivo_generado_en
  );
end
$$;
revoke all on function public.app_finance_v2_report_payload_v145(uuid) from public,anon;
grant execute on function public.app_finance_v2_report_payload_v145(uuid) to authenticated;

-- Service-only atomic attachment of the generated file plus audit trail.
create or replace function public.app_finance_v2_report_file_attach_v145(
  p_report_id uuid,
  p_path text,
  p_bytes bigint,
  p_sha256 text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare r public.informes_financieros;v_was_ready boolean;
begin
  if coalesce(auth.role(),'')<>'service_role' then raise exception 'FINANCE_REPORT_FILE_ATTACH_FORBIDDEN'; end if;
  select * into r from public.informes_financieros where id=p_report_id for update;
  if r.id is null then raise exception 'FINANCE_REPORT_NOT_FOUND'; end if;
  if nullif(trim(coalesce(p_path,'')),'') is null or p_path not like r.club_id::text||'/%/'||r.identificador||'.pdf' then
    raise exception 'FINANCE_REPORT_FILE_PATH_INVALID';
  end if;
  if coalesce(p_bytes,0)<=0 or coalesce(p_bytes,0)>20971520 then raise exception 'FINANCE_REPORT_FILE_SIZE_INVALID'; end if;
  if p_sha256 is null or p_sha256 !~ '^[0-9a-f]{64}$' then raise exception 'FINANCE_REPORT_FILE_HASH_INVALID'; end if;
  v_was_ready:=r.archivo_path is not null;
  update public.informes_financieros set
    archivo_path=coalesce(archivo_path,p_path),
    archivo_mime=coalesce(archivo_mime,'application/pdf'),
    archivo_bytes=coalesce(archivo_bytes,p_bytes),
    archivo_sha256=coalesce(archivo_sha256,p_sha256),
    archivo_generado_en=coalesce(archivo_generado_en,now())
  where id=r.id;
  if not v_was_ready then
    insert into public.auditoria(club_id,usuario_id,accion,entidad,registro_id,datos_nuevos)
    values(r.club_id,r.generado_por,'FINANCE_REPORT_PDF','informe_financiero',r.id::text,jsonb_build_object(
      'identificador',r.identificador,'path',p_path,'bytes',p_bytes,'sha256',p_sha256
    ));
  end if;
  return jsonb_build_object('ok',true,'report_id',r.id,'archivo_path',coalesce(r.archivo_path,p_path));
end
$$;
revoke all on function public.app_finance_v2_report_file_attach_v145(uuid,text,bigint,text) from public,anon,authenticated;
grant execute on function public.app_finance_v2_report_file_attach_v145(uuid,text,bigint,text) to service_role;

-- ---------------------------------------------------------------------------
-- 4) Gateway: report creation remains inside app_mutate_v160 + request_id
-- ---------------------------------------------------------------------------
do $gateway$
begin
  if to_regprocedure('public.app_mutate_v160_pre_finance_reports_145(text,jsonb,uuid)') is null then
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_finance_reports_145;
  end if;
end
$gateway$;
revoke all on function public.app_mutate_v160_pre_finance_reports_145(text,jsonb,uuid) from public,anon,authenticated;

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
  if p_operation<>'finance.informe.crear' then
    return public.app_mutate_v160_pre_finance_reports_145(p_operation,p_payload,p_request_id);
  end if;

  if v_uid is null then raise exception 'AUTH_REQUIRED: inicia sesión de nuevo'; end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  begin v_club:=nullif(trim(coalesce(v_payload->>'club_id','')),'')::uuid;
  exception when others then raise exception 'MUTATION_INVALID_CLUB_ID'; end;
  if v_club is null or not public.tiene_rol_club(v_club,'direccion','secretaria','economia') then
    raise exception 'FINANCE_REPORT_MUTATION_FORBIDDEN';
  end if;
  if not private.finance_flag_v143(v_club,'finance_reports_enabled') then raise exception 'FINANCE_REPORTS_DISABLED'; end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED'; end if;
    if v_existing.result is not null then return v_existing.result; end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation)
    values(p_request_id,v_uid,v_club,p_operation);
  end if;

  delete from public.app_mutation_requests where user_id=v_uid and created_at<now()-interval '30 days';
  v_data:=private.finance_create_report_v145(v_payload,v_club,v_uid);

  insert into public.auditoria(club_id,usuario_id,accion,entidad,registro_id,datos_nuevos)
  values(v_club,v_uid,'FINANCE_REPORT_SNAPSHOT','finance.informe.crear',v_data->>'report_id',jsonb_build_object(
    'identificador',v_data->>'identificador','tipo',v_data->>'tipo','version',v_data->'version',
    'dataset_rows',v_data->'dataset_rows','totales',v_data->'totales'
  ));

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

-- Contract extension without changing RC13 backendVersion/schemaEpoch.
do $contract$
begin
  if to_regprocedure('public.app_runtime_contract_v160_pre_finance_reports_145(uuid)') is null then
    alter function public.app_runtime_contract_v160(uuid) rename to app_runtime_contract_v160_pre_finance_reports_145;
  end if;
end
$contract$;
revoke all on function public.app_runtime_contract_v160_pre_finance_reports_145(uuid) from public,anon,authenticated;

create or replace function public.app_runtime_contract_v160(p_club_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare v_base jsonb;
begin
  v_base:=public.app_runtime_contract_v160_pre_finance_reports_145(p_club_id);
  if not (coalesce(v_base->'operations','[]'::jsonb) @> '["finance.informe.crear"]'::jsonb) then
    v_base:=jsonb_set(v_base,'{operations}',coalesce(v_base->'operations','[]'::jsonb)||jsonb_build_array('finance.informe.crear'),true);
  end if;
  return v_base;
end
$$;
revoke all on function public.app_runtime_contract_v160(uuid) from public,anon;
grant execute on function public.app_runtime_contract_v160(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5) Self-audit
-- ---------------------------------------------------------------------------
do $$
declare v_version text;
begin
  select backend_version into v_version from public.app_runtime_meta where singleton=true;
  if v_version is null then raise exception 'FINANCE_REPORT_145_BACKEND_VERSION_MISSING'; end if;
  if to_regclass('public.informes_financieros') is null then raise exception 'FINANCE_REPORT_145_TABLE_MISSING'; end if;
  if to_regprocedure('private.finance_create_report_v145(jsonb,uuid,uuid)') is null then raise exception 'FINANCE_REPORT_145_SNAPSHOT_BUILDER_MISSING'; end if;
  if to_regprocedure('public.app_finance_v2_reports_v145(uuid,integer)') is null then raise exception 'FINANCE_REPORT_145_LIST_API_MISSING'; end if;
  if to_regprocedure('public.app_finance_v2_report_payload_v145(uuid)') is null then raise exception 'FINANCE_REPORT_145_PAYLOAD_API_MISSING'; end if;
  if to_regprocedure('public.app_finance_v2_report_file_attach_v145(uuid,text,bigint,text)') is null then raise exception 'FINANCE_REPORT_145_FILE_ATTACH_MISSING'; end if;
end
$$;

notify pgrst,'reload schema';
commit;
