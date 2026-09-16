-- KOMBAX RC13 build 20087 · Finance stability hardening
-- Extends integrity findings and blocks rapid duplicate manual charge batches.

create or replace function public.app_finance_v2_integrity_v155(p_club_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $function$
declare v jsonb;
begin
  if auth.uid() is null or not public.tiene_rol_club(p_club_id,'direccion','secretaria','economia') then raise exception 'FINANCE_INTEGRITY_FORBIDDEN'; end if;
  with pay as (
    select p.club_id,p.cuota_id,
      coalesce(sum(p.importe) filter(where p.estado_validacion='validado'),0)::numeric(12,2) valid_sum,
      count(*) filter(where p.estado_validacion='pendiente')::int pending_count,
      coalesce(sum(p.importe) filter(where p.estado_validacion='pendiente'),0)::numeric(12,2) pending_sum,
      coalesce(max(p.importe) filter(where p.estado_validacion='pendiente'),0)::numeric(12,2) max_pending
    from public.pagos p where p.club_id=p_club_id group by p.club_id,p.cuota_id
  ), rec as (
    select club_id,cuota_id,count(*) filter(where anulado_en is null)::int active_receipts
    from public.recibos_cuota where club_id=p_club_id group by club_id,cuota_id
  ), q as (
    select c.id,c.concepto,c.importe,c.estado,c.vencimiento,
      coalesce(pay.valid_sum,0) valid_sum,coalesce(pay.pending_count,0) pending_count,
      coalesce(pay.pending_sum,0) pending_sum,coalesce(pay.max_pending,0) max_pending,
      coalesce(rec.active_receipts,0) active_receipts
    from public.cuotas c left join pay on pay.club_id=c.club_id and pay.cuota_id=c.id left join rec on rec.club_id=c.club_id and rec.cuota_id=c.id
    where c.club_id=p_club_id
  ), issues as (
    select 'OVERPAYMENT' code,id entity_id,'cuota' entity_type,'La suma validada supera el importe del cargo.' message,'critical' severity from q where valid_sum>importe
    union all select 'PAID_WITH_PENDING',id,'cuota','La cuota ya está pagada pero conserva pagos pendientes. Revísalos o recházalos.','warning' from q where valid_sum>=importe and pending_count>0
    union all select 'PENDING_EXCEEDS_REMAINING',id,'cuota','Existe un pago pendiente cuyo importe supera el saldo restante.','warning' from q where pending_count>0 and max_pending>greatest(importe-valid_sum,0)
    union all select 'PAID_WITHOUT_RECEIPT',id,'cuota','La cuota está completamente pagada pero no tiene recibo activo.','critical' from q where valid_sum>=importe and active_receipts=0 and estado not in ('anulada','exenta')
    union all select 'RECEIPT_TOO_EARLY',id,'cuota','Existe un recibo activo antes de completar el pago.','critical' from q where valid_sum<importe and active_receipts>0
    union all select 'STATE_MISMATCH',id,'cuota','El estado de la cuota no coincide con sus pagos validados.','warning' from q where ((valid_sum>=importe) <> (estado='pagada')) and estado not in ('anulada','exenta')
    union all select 'REPORT_PDF_PENDING',i.id,'informe','Existe un snapshot histórico cuyo PDF todavía no se ha generado.','warning' from public.informes_financieros i where i.club_id=p_club_id and i.archivo_path is null and coalesce((select l.estado from public.finance_document_lifecycle_v155 l where l.club_id=i.club_id and l.entity_type='informe' and l.entity_id=i.id),'active')<>'trash'
    union all select 'REPORT_FILE_MISSING',i.id,'informe','El informe registra un PDF que no existe en almacenamiento.','critical' from public.informes_financieros i where i.club_id=p_club_id and i.archivo_path is not null and not exists(select 1 from storage.objects o where o.bucket_id='finance-reports' and o.name=i.archivo_path)
  )
  select jsonb_build_object(
    'ok',not exists(select 1 from issues where severity='critical'),
    'blocking',count(*) filter(where severity='critical'),
    'warnings',count(*) filter(where severity='warning'),
    'issues',coalesce(jsonb_agg(jsonb_build_object('code',code,'entity_id',entity_id,'entity_type',entity_type,'message',message,'severity',severity) order by severity,code) filter(where code is not null),'[]'::jsonb)
  ) into v from issues;
  return coalesce(v,jsonb_build_object('ok',true,'blocking',0,'warnings',0,'issues','[]'::jsonb));
end $function$;

create or replace function public.app_mutate_v160(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $function$
declare
  v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_club uuid;v_pago public.pagos;v_cuota public.cuotas;
  v_valid numeric(12,2):=0;v_remaining numeric(12,2):=0;v_amount numeric(12,2):=0;v_decision text;v_entity_type text;v_entity_id uuid;v_state text;v_reason text;v_exists bool;v_result jsonb;
  v_concept text;v_period date;v_due date;v_category text;v_dest jsonb;v_dup_count int:=0;
begin
  if p_operation not in ('pago.validar','pago.registrar_admin','pago.comunicar','finance.documento.estado','finance.cargo.crear') then return public.app_mutate_v160_pre_finance_stability_155(p_operation,p_payload,p_request_id); end if;
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  begin v_club:=nullif(v_payload->>'club_id','')::uuid; exception when others then v_club:=null; end;
  if v_club is null or not public.tiene_rol_club(v_club,'direccion','secretaria','economia') then raise exception 'FINANCE_MUTATION_FORBIDDEN'; end if;

  if p_operation='finance.cargo.crear' then
    v_concept:=trim(coalesce(v_payload->>'concepto',''));v_category:=lower(trim(coalesce(v_payload->>'categoria','otro')));v_dest:=coalesce(v_payload->'destinatarios','[]'::jsonb);
    begin v_amount:=(v_payload->>'importe')::numeric;v_period:=nullif(v_payload->>'periodo','')::date;v_due:=nullif(v_payload->>'vencimiento','')::date; exception when others then raise exception 'FINANCE_V2_FILTER_INVALID'; end;
    select count(*) into v_dup_count
    from private.finance_manual_recipients_v144(v_club,v_dest) r
    where exists(
      select 1 from public.cuotas q
      where q.club_id=v_club and q.socio_id=r.socio_id and q.importe=v_amount and q.periodo=v_period and q.vencimiento=v_due
        and coalesce(q.concepto_publico,'')=v_concept and coalesce(q.categoria_financiera,'otro')=v_category
        and q.estado not in ('anulada','exenta') and q.creado_en>now()-interval '2 minutes'
    );
    if v_dup_count>0 then raise exception 'FINANCE_CHARGE_DUPLICATE: Ya existe un cargo prácticamente idéntico creado hace menos de 2 minutos para % destinatario(s). Revisa la lista antes de repetir el lote.',v_dup_count; end if;
    return public.app_mutate_v160_pre_finance_stability_155(p_operation,p_payload,p_request_id);
  end if;

  if p_operation='pago.validar' then
    begin select * into v_pago from public.pagos where id=(v_payload->>'pago_id')::uuid and club_id=v_club; exception when others then null; end;
    if v_pago.id is null then raise exception 'FINANCE_PAYMENT_NOT_FOUND'; end if;
    v_decision:=lower(trim(coalesce(v_payload->>'decision','')));
    if v_decision='validado' then
      if v_pago.estado_validacion<>'pendiente' then raise exception 'FINANCE_PAYMENT_ALREADY_REVIEWED: Este pago ya fue revisado.'; end if;
      select * into v_cuota from public.cuotas where id=v_pago.cuota_id and club_id=v_club;
      if v_cuota.estado in ('anulada','exenta') then raise exception 'FINANCE_PAYMENT_CHARGE_CLOSED: Esta cuota está anulada o exenta y no admite validaciones de pago.'; end if;
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
    if v_cuota.estado in ('anulada','exenta') then raise exception 'FINANCE_PAYMENT_CHARGE_CLOSED: Esta cuota está anulada o exenta y no admite nuevos pagos.'; end if;
    begin v_amount:=(v_payload->>'importe')::numeric; exception when others then v_amount:=0; end;
    select coalesce(sum(p.importe),0) into v_valid from public.pagos p where p.club_id=v_club and p.cuota_id=v_cuota.id and p.estado_validacion='validado';
    v_remaining:=greatest(v_cuota.importe-v_valid,0);
    if v_remaining<=0 then raise exception 'FINANCE_PAYMENT_ALREADY_COVERED: Esta cuota ya está completamente pagada. No se puede registrar otro cobro.'; end if;
    if v_amount<=0 then raise exception 'FINANCE_PAYMENT_AMOUNT_INVALID: El importe debe ser mayor que cero.'; end if;
    if v_amount>v_remaining then raise exception 'FINANCE_PAYMENT_EXCEEDS_REMAINING: El importe supera el saldo pendiente de la cuota (%).',v_remaining; end if;
    if exists(select 1 from public.pagos p where p.club_id=v_club and p.cuota_id=v_cuota.id and p.importe=v_amount and p.fecha=coalesce(nullif(v_payload->>'fecha','')::date,current_date) and p.metodo::text=coalesce(v_payload->>'metodo','') and p.estado_validacion<>'rechazado' and p.creado_en>now()-interval '2 minutes') then raise exception 'FINANCE_PAYMENT_DUPLICATE: Ya existe un pago prácticamente idéntico registrado hace menos de 2 minutos. Revisa la lista antes de repetirlo.'; end if;
    return public.app_mutate_v160_pre_finance_stability_155(p_operation,p_payload,p_request_id);
  end if;

  v_entity_type:=lower(trim(coalesce(v_payload->>'entity_type','')));v_state:=lower(trim(coalesce(v_payload->>'estado','active')));v_reason:=nullif(trim(coalesce(v_payload->>'motivo','')),'');
  begin v_entity_id:=(v_payload->>'entity_id')::uuid; exception when others then raise exception 'FINANCE_DOCUMENT_ID_INVALID'; end;
  if v_entity_type not in ('cuota','pago','recibo','informe') then raise exception 'FINANCE_DOCUMENT_TYPE_INVALID'; end if;
  if v_state not in ('active','archived','trash') then raise exception 'FINANCE_DOCUMENT_STATE_INVALID'; end if;
  if v_state in ('archived','trash') and v_reason is null then raise exception 'FINANCE_DOCUMENT_REASON_REQUIRED: Indica el motivo para archivar o enviar a papelera.'; end if;
  if v_entity_type='cuota' then select exists(select 1 from public.cuotas where id=v_entity_id and club_id=v_club) into v_exists; elsif v_entity_type='pago' then select exists(select 1 from public.pagos where id=v_entity_id and club_id=v_club) into v_exists; elsif v_entity_type='recibo' then select exists(select 1 from public.recibos_cuota where id=v_entity_id and club_id=v_club) into v_exists; else select exists(select 1 from public.informes_financieros where id=v_entity_id and club_id=v_club) into v_exists; end if;
  if not coalesce(v_exists,false) then raise exception 'FINANCE_DOCUMENT_NOT_FOUND'; end if;
  insert into public.finance_document_lifecycle_v155(club_id,entity_type,entity_id,estado,motivo,archived_at,trashed_at,updated_at,updated_by) values(v_club,v_entity_type,v_entity_id,v_state,v_reason,case when v_state='archived' then now() end,case when v_state='trash' then now() end,now(),v_uid)
  on conflict(club_id,entity_type,entity_id) do update set estado=excluded.estado,motivo=excluded.motivo,archived_at=excluded.archived_at,trashed_at=excluded.trashed_at,updated_at=now(),updated_by=v_uid;
  insert into public.auditoria(club_id,usuario_id,accion,entidad,registro_id,datos_nuevos) values(v_club,v_uid,'FINANCE_DOCUMENT_LIFECYCLE',v_entity_type,v_entity_id::text,jsonb_build_object('estado',v_state,'motivo',v_reason,'sensitive',true));
  v_result:=jsonb_build_object('ok',true,'entity_type',v_entity_type,'entity_id',v_entity_id,'estado',v_state,'motivo',v_reason);
  return jsonb_build_object('ok',true,'backend_version','1.6.0','operation',p_operation,'request_id',p_request_id,'data',v_result);
end $function$;
revoke all on function public.app_mutate_v160(text,jsonb,uuid) from public,anon;
grant execute on function public.app_mutate_v160(text,jsonb,uuid) to authenticated;
