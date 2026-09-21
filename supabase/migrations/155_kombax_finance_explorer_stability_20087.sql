-- KOMBAX RC13 build 20087 · Finance Explorer + stability guard
-- Non-destructive. Adds lifecycle overlays, paginated explorer, integrity audit and payment validation guards.

create table if not exists public.finance_document_lifecycle_v155(
  club_id uuid not null references public.clubes(id) on delete cascade,
  entity_type text not null check(entity_type in ('cuota','pago','recibo','informe')),
  entity_id uuid not null,
  estado text not null default 'active' check(estado in ('active','archived','trash')),
  motivo text,
  archived_at timestamptz,
  trashed_at timestamptz,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  primary key(club_id,entity_type,entity_id)
);
alter table public.finance_document_lifecycle_v155 enable row level security;
revoke all on table public.finance_document_lifecycle_v155 from public,anon,authenticated;

create index if not exists finance_doc_lifecycle_state_v155_idx
  on public.finance_document_lifecycle_v155(club_id,entity_type,estado,updated_at desc);
create index if not exists pagos_club_created_v155_idx on public.pagos(club_id,creado_en desc,id desc);
create index if not exists recibos_club_emitido_v155_idx on public.recibos_cuota(club_id,emitido_en desc,id desc);
create index if not exists informes_club_generado_v155_idx on public.informes_financieros(club_id,generado_en desc,id desc);
create index if not exists cuotas_club_created_v155_idx on public.cuotas(club_id,creado_en desc,id desc);

create or replace function public.app_finance_v2_integrity_v155(p_club_id uuid)
returns jsonb
language plpgsql stable security definer set search_path=''
as $function$
declare v jsonb;
begin
  if auth.uid() is null or not public.tiene_rol_club(p_club_id,'direccion','secretaria','economia') then
    raise exception 'FINANCE_INTEGRITY_FORBIDDEN';
  end if;
  with pay as (
    select p.club_id,p.cuota_id,
      coalesce(sum(p.importe) filter(where p.estado_validacion='validado'),0)::numeric(12,2) valid_sum,
      count(*) filter(where p.estado_validacion='pendiente')::int pending_count,
      coalesce(sum(p.importe) filter(where p.estado_validacion='pendiente'),0)::numeric(12,2) pending_sum
    from public.pagos p where p.club_id=p_club_id group by p.club_id,p.cuota_id
  ), rec as (
    select club_id,cuota_id,count(*) filter(where anulado_en is null)::int active_receipts
    from public.recibos_cuota where club_id=p_club_id group by club_id,cuota_id
  ), q as (
    select c.id,c.concepto,c.importe,c.estado,c.vencimiento,
      coalesce(pay.valid_sum,0) valid_sum,coalesce(pay.pending_count,0) pending_count,coalesce(pay.pending_sum,0) pending_sum,
      coalesce(rec.active_receipts,0) active_receipts
    from public.cuotas c left join pay on pay.club_id=c.club_id and pay.cuota_id=c.id left join rec on rec.club_id=c.club_id and rec.cuota_id=c.id
    where c.club_id=p_club_id
  ), issues as (
    select 'OVERPAYMENT' code,id entity_id,'cuota' entity_type,
      'La suma validada supera el importe del cargo.' message,'critical' severity
      from q where valid_sum>importe
    union all
    select 'PAID_WITH_PENDING',id,'cuota','La cuota ya está pagada pero conserva pagos pendientes. Revísalos o recházalos.','warning'
      from q where valid_sum>=importe and pending_count>0
    union all
    select 'PAID_WITHOUT_RECEIPT',id,'cuota','La cuota está completamente pagada pero no tiene recibo activo.','critical'
      from q where valid_sum>=importe and active_receipts=0 and estado not in ('anulada','exenta')
    union all
    select 'RECEIPT_TOO_EARLY',id,'cuota','Existe un recibo activo antes de completar el pago.','critical'
      from q where valid_sum<importe and active_receipts>0
    union all
    select 'STATE_MISMATCH',id,'cuota','El estado de la cuota no coincide con sus pagos validados.','warning'
      from q where ((valid_sum>=importe) <> (estado='pagada')) and estado not in ('anulada','exenta')
  )
  select jsonb_build_object(
    'ok',not exists(select 1 from issues where severity='critical'),
    'blocking',count(*) filter(where severity='critical'),
    'warnings',count(*) filter(where severity='warning'),
    'issues',coalesce(jsonb_agg(jsonb_build_object('code',code,'entity_id',entity_id,'entity_type',entity_type,'message',message,'severity',severity) order by severity,code) filter(where code is not null),'[]'::jsonb)
  ) into v from issues;
  return coalesce(v,jsonb_build_object('ok',true,'blocking',0,'warnings',0,'issues','[]'::jsonb));
end $function$;
revoke all on function public.app_finance_v2_integrity_v155(uuid) from public,anon;
grant execute on function public.app_finance_v2_integrity_v155(uuid) to authenticated;

create or replace function public.app_finance_v2_explorer_v155(
  p_club_id uuid,
  p_kind text,
  p_query text default null,
  p_status text default null,
  p_scope text default 'active',
  p_limit integer default 20,
  p_offset integer default 0
) returns jsonb
language plpgsql stable security definer set search_path=''
as $function$
declare
  v_kind text:=lower(trim(coalesce(p_kind,'')));
  v_scope text:=lower(trim(coalesce(p_scope,'active')));
  v_q text:=nullif(trim(coalesce(p_query,'')),'');
  v_status text:=nullif(trim(coalesce(p_status,'')),'');
  v_limit int:=least(50,greatest(5,coalesce(p_limit,20)));
  v_offset int:=greatest(0,coalesce(p_offset,0));
  v_rows jsonb:='[]'::jsonb;
  v_total int:=0;
begin
  if auth.uid() is null or not public.tiene_rol_club(p_club_id,'direccion','secretaria','economia') then raise exception 'FINANCE_EXPLORER_FORBIDDEN'; end if;
  if v_kind not in ('cuotas','pagos','recibos','informes') then raise exception 'FINANCE_EXPLORER_KIND_INVALID'; end if;
  if v_scope not in ('active','archived','trash','all') then raise exception 'FINANCE_EXPLORER_SCOPE_INVALID'; end if;

  if v_kind='pagos' then
    with base as (
      select p.*,s.nombre socio_nombre,s.apellidos socio_apellidos,q.concepto cuota_concepto,q.importe cuota_importe,q.estado cuota_estado,
        coalesce(x.valid_sum,0)::numeric(12,2) valid_sum,
        greatest(q.importe-coalesce(x.valid_sum,0),0)::numeric(12,2) saldo_restante,
        coalesce(l.estado,'active') lifecycle_estado,
        case
          when p.estado_validacion<>'pendiente' then false
          when coalesce(x.valid_sum,0)>=q.importe then false
          when p.importe>greatest(q.importe-coalesce(x.valid_sum,0),0) then false
          else true end can_validate,
        case
          when p.estado_validacion<>'pendiente' then null
          when coalesce(x.valid_sum,0)>=q.importe then 'La cuota ya está completamente pagada.'
          when p.importe>greatest(q.importe-coalesce(x.valid_sum,0),0) then 'El pago supera el saldo pendiente de la cuota.'
          else null end validation_block_reason
      from public.pagos p join public.cuotas q on q.club_id=p.club_id and q.id=p.cuota_id
      join public.socios s on s.club_id=p.club_id and s.id=p.socio_id
      left join lateral(select coalesce(sum(p2.importe) filter(where p2.estado_validacion='validado'),0) valid_sum from public.pagos p2 where p2.club_id=p.club_id and p2.cuota_id=p.cuota_id) x on true
      left join public.finance_document_lifecycle_v155 l on l.club_id=p.club_id and l.entity_type='pago' and l.entity_id=p.id
      where p.club_id=p_club_id
        and (v_scope='all' and coalesce(l.estado,'active')<>'trash' or v_scope<>'all' and coalesce(l.estado,'active')=v_scope)
        and (v_status is null or p.estado_validacion::text=v_status)
        and (v_q is null or concat_ws(' ',s.nombre,s.apellidos,p.metodo,p.referencia,q.concepto) ilike '%'||v_q||'%')
    )
    select count(*),coalesce((select jsonb_agg(to_jsonb(z) order by z.creado_en desc,z.id desc) from (select * from base order by creado_en desc,id desc limit v_limit offset v_offset) z),'[]'::jsonb)
      into v_total,v_rows from base;
  elsif v_kind='recibos' then
    with base as (
      select r.*,coalesce(l.estado,'active') lifecycle_estado
      from public.recibos_cuota r left join public.finance_document_lifecycle_v155 l on l.club_id=r.club_id and l.entity_type='recibo' and l.entity_id=r.id
      where r.club_id=p_club_id
        and (v_scope='all' and coalesce(l.estado,'active')<>'trash' or v_scope<>'all' and coalesce(l.estado,'active')=v_scope)
        and (v_status is null or (v_status='anulado' and r.anulado_en is not null) or (v_status='activo' and r.anulado_en is null))
        and (v_q is null or concat_ws(' ',r.numero,r.socio_nombre,r.concepto,r.periodo::text,r.metodo) ilike '%'||v_q||'%')
    )
    select count(*),coalesce((select jsonb_agg(to_jsonb(z) order by z.emitido_en desc,z.id desc) from (select * from base order by emitido_en desc,id desc limit v_limit offset v_offset) z),'[]'::jsonb)
      into v_total,v_rows from base;
  elsif v_kind='informes' then
    with base as (
      select i.*,coalesce(l.estado,'active') lifecycle_estado
      from public.informes_financieros i left join public.finance_document_lifecycle_v155 l on l.club_id=i.club_id and l.entity_type='informe' and l.entity_id=i.id
      where i.club_id=p_club_id
        and (v_scope='all' and coalesce(l.estado,'active')<>'trash' or v_scope<>'all' and coalesce(l.estado,'active')=v_scope)
        and (v_status is null or (v_status='pdf_ready' and i.archivo_path is not null) or (v_status='pdf_pending' and i.archivo_path is null) or i.tipo=v_status)
        and (v_q is null or concat_ws(' ',i.identificador,i.titulo,i.tipo) ilike '%'||v_q||'%')
    )
    select count(*),coalesce((select jsonb_agg(to_jsonb(z) order by z.generado_en desc,z.id desc) from (select * from base order by generado_en desc,id desc limit v_limit offset v_offset) z),'[]'::jsonb)
      into v_total,v_rows from base;
  else
    with base as (
      select q.*,s.nombre socio_nombre,s.apellidos socio_apellidos,
        coalesce(x.valid_sum,0)::numeric(12,2) pagado_validado,greatest(q.importe-coalesce(x.valid_sum,0),0)::numeric(12,2) saldo,
        coalesce(l.estado,'active') lifecycle_estado
      from public.cuotas q join public.socios s on s.club_id=q.club_id and s.id=q.socio_id
      left join lateral(select coalesce(sum(p.importe) filter(where p.estado_validacion='validado'),0) valid_sum from public.pagos p where p.club_id=q.club_id and p.cuota_id=q.id) x on true
      left join public.finance_document_lifecycle_v155 l on l.club_id=q.club_id and l.entity_type='cuota' and l.entity_id=q.id
      where q.club_id=p_club_id
        and (v_scope='all' and coalesce(l.estado,'active')<>'trash' or v_scope<>'all' and coalesce(l.estado,'active')=v_scope)
        and (v_status is null or q.estado::text=v_status)
        and (v_q is null or concat_ws(' ',s.nombre,s.apellidos,q.concepto,q.concepto_publico,q.periodo::text) ilike '%'||v_q||'%')
    )
    select count(*),coalesce((select jsonb_agg(to_jsonb(z) order by z.creado_en desc,z.id desc) from (select * from base order by creado_en desc,id desc limit v_limit offset v_offset) z),'[]'::jsonb)
      into v_total,v_rows from base;
  end if;
  return jsonb_build_object('kind',v_kind,'scope',v_scope,'query',coalesce(v_q,''),'status',coalesce(v_status,''),'limit',v_limit,'offset',v_offset,'total',v_total,'rows',v_rows,'has_more',v_offset+v_limit<v_total);
end $function$;
revoke all on function public.app_finance_v2_explorer_v155(uuid,text,text,text,text,integer,integer) from public,anon;
grant execute on function public.app_finance_v2_explorer_v155(uuid,text,text,text,text,integer,integer) to authenticated;

-- Preserve the current gateway and add finance-specific preflight guards/lifecycle mutations.
do $$ begin
  if to_regprocedure('public.app_mutate_v160_pre_finance_stability_155(text,jsonb,uuid)') is null then
    alter function public.app_mutate_v160(text,jsonb,uuid) rename to app_mutate_v160_pre_finance_stability_155;
  end if;
end $$;
revoke all on function public.app_mutate_v160_pre_finance_stability_155(text,jsonb,uuid) from public,anon,authenticated;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare
  v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_club uuid;v_pago public.pagos;v_cuota public.cuotas;
  v_valid numeric(12,2):=0;v_remaining numeric(12,2):=0;v_amount numeric(12,2):=0;v_decision text;v_entity_type text;v_entity_id uuid;v_state text;v_reason text;v_exists bool;v_result jsonb;
begin
  if p_operation not in ('pago.validar','pago.registrar_admin','pago.comunicar','finance.documento.estado') then
    return public.app_mutate_v160_pre_finance_stability_155(p_operation,p_payload,p_request_id);
  end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  begin v_club:=nullif(v_payload->>'club_id','')::uuid; exception when others then v_club:=null; end;
  if v_club is null or not public.tiene_rol_club(v_club,'direccion','secretaria','economia') then raise exception 'FINANCE_MUTATION_FORBIDDEN'; end if;

  if p_operation='pago.validar' then
    begin select * into v_pago from public.pagos where id=(v_payload->>'pago_id')::uuid and club_id=v_club; exception when others then null; end;
    if v_pago.id is null then raise exception 'FINANCE_PAYMENT_NOT_FOUND'; end if;
    v_decision:=lower(trim(coalesce(v_payload->>'decision','')));
    if v_decision='validado' then
      if v_pago.estado_validacion<>'pendiente' then raise exception 'FINANCE_PAYMENT_ALREADY_REVIEWED: Este pago ya fue revisado.'; end if;
      select * into v_cuota from public.cuotas where id=v_pago.cuota_id and club_id=v_club;
      select coalesce(sum(p.importe),0) into v_valid from public.pagos p where p.club_id=v_club and p.cuota_id=v_pago.cuota_id and p.estado_validacion='validado' and p.id<>v_pago.id;
      v_remaining:=greatest(v_cuota.importe-v_valid,0);
      if v_remaining<=0 then raise exception 'FINANCE_PAYMENT_ALREADY_COVERED: Esta cuota ya está completamente pagada. Revisa o rechaza el pago pendiente duplicado.'; end if;
      if v_pago.importe>v_remaining then raise exception 'FINANCE_PAYMENT_EXCEEDS_REMAINING: Este pago supera el saldo pendiente de la cuota (%).',v_remaining; end if;
    end if;
    return public.app_mutate_v160_pre_finance_stability_155(p_operation,p_payload,p_request_id);
  end if;

  if p_operation in ('pago.registrar_admin','pago.comunicar') then
    begin select * into v_cuota from public.cuotas where id=(v_payload->>'cuota_id')::uuid and club_id=v_club; exception when others then null; end;
    if v_cuota.id is null then raise exception 'FINANCE_CHARGE_NOT_FOUND'; end if;
    begin v_amount:=(v_payload->>'importe')::numeric; exception when others then v_amount:=0; end;
    select coalesce(sum(p.importe),0) into v_valid from public.pagos p where p.club_id=v_club and p.cuota_id=v_cuota.id and p.estado_validacion='validado';
    v_remaining:=greatest(v_cuota.importe-v_valid,0);
    if v_remaining<=0 then raise exception 'FINANCE_PAYMENT_ALREADY_COVERED: Esta cuota ya está completamente pagada. No se puede registrar otro cobro.'; end if;
    if v_amount<=0 then raise exception 'FINANCE_PAYMENT_AMOUNT_INVALID: El importe debe ser mayor que cero.'; end if;
    if v_amount>v_remaining then raise exception 'FINANCE_PAYMENT_EXCEEDS_REMAINING: El importe supera el saldo pendiente de la cuota (%).',v_remaining; end if;
    if exists(select 1 from public.pagos p where p.club_id=v_club and p.cuota_id=v_cuota.id and p.importe=v_amount and p.fecha=coalesce(nullif(v_payload->>'fecha','')::date,current_date) and p.metodo::text=coalesce(v_payload->>'metodo','') and p.estado_validacion<>'rechazado' and p.creado_en>now()-interval '2 minutes') then
      raise exception 'FINANCE_PAYMENT_DUPLICATE: Ya existe un pago prácticamente idéntico registrado hace menos de 2 minutos. Revisa la lista antes de repetirlo.';
    end if;
    return public.app_mutate_v160_pre_finance_stability_155(p_operation,p_payload,p_request_id);
  end if;

  -- Soft lifecycle overlay. Accounting rows are never silently destroyed here.
  v_entity_type:=lower(trim(coalesce(v_payload->>'entity_type','')));v_state:=lower(trim(coalesce(v_payload->>'estado','active')));v_reason:=nullif(trim(coalesce(v_payload->>'motivo','')),'');
  begin v_entity_id:=(v_payload->>'entity_id')::uuid; exception when others then raise exception 'FINANCE_DOCUMENT_ID_INVALID'; end;
  if v_entity_type not in ('cuota','pago','recibo','informe') then raise exception 'FINANCE_DOCUMENT_TYPE_INVALID'; end if;
  if v_state not in ('active','archived','trash') then raise exception 'FINANCE_DOCUMENT_STATE_INVALID'; end if;
  if v_state in ('archived','trash') and v_reason is null then raise exception 'FINANCE_DOCUMENT_REASON_REQUIRED: Indica el motivo para archivar o enviar a papelera.'; end if;
  if v_entity_type='cuota' then select exists(select 1 from public.cuotas where id=v_entity_id and club_id=v_club) into v_exists;
  elsif v_entity_type='pago' then select exists(select 1 from public.pagos where id=v_entity_id and club_id=v_club) into v_exists;
  elsif v_entity_type='recibo' then select exists(select 1 from public.recibos_cuota where id=v_entity_id and club_id=v_club) into v_exists;
  else select exists(select 1 from public.informes_financieros where id=v_entity_id and club_id=v_club) into v_exists; end if;
  if not coalesce(v_exists,false) then raise exception 'FINANCE_DOCUMENT_NOT_FOUND'; end if;
  insert into public.finance_document_lifecycle_v155(club_id,entity_type,entity_id,estado,motivo,archived_at,trashed_at,updated_at,updated_by)
  values(v_club,v_entity_type,v_entity_id,v_state,v_reason,case when v_state='archived' then now() end,case when v_state='trash' then now() end,now(),v_uid)
  on conflict(club_id,entity_type,entity_id) do update set estado=excluded.estado,motivo=excluded.motivo,archived_at=excluded.archived_at,trashed_at=excluded.trashed_at,updated_at=now(),updated_by=v_uid;
  insert into public.auditoria(club_id,usuario_id,accion,entidad,registro_id,datos_nuevos)
  values(v_club,v_uid,'FINANCE_DOCUMENT_LIFECYCLE',v_entity_type,v_entity_id::text,jsonb_build_object('estado',v_state,'motivo',v_reason,'sensitive',true));
  v_result:=jsonb_build_object('ok',true,'entity_type',v_entity_type,'entity_id',v_entity_id,'estado',v_state,'motivo',v_reason);
  return jsonb_build_object('ok',true,'backend_version','1.6.0','operation',p_operation,'request_id',p_request_id,'data',v_result);
end $function$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;

-- Fix the monthly period bug observed during report creation.
do $$
declare v_def text;
begin
  select pg_get_functiondef('private.finance_create_report_v145(jsonb,uuid,uuid)'::regprocedure) into v_def;
  if strpos(v_def,'''1 month-1 day''')>0 then
    v_def:=replace(v_def,$old$interval '1 month-1 day'$old$,$new$interval '1 month' - interval '1 day'$new$);
    execute v_def;
  end if;
end $$;
