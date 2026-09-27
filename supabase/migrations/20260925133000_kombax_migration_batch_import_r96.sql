-- KOMBAX Migrations R100 · reviewed, idempotent club record import
create table if not exists kombax_customer_ops.migration_import_requests_v271(
  ticket_id text not null references kombax_customer_ops.tickets(ticket_id) on delete cascade,
  request_id uuid not null,
  user_ref uuid not null references auth.users(id) on delete restrict,
  payload_hash text not null,
  imported_count integer not null default 0,
  result jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  primary key(ticket_id,request_id)
);
create table if not exists kombax_customer_ops.migration_imported_records_v271(
  ticket_id text not null references kombax_customer_ops.tickets(ticket_id) on delete cascade,
  source_ref text not null,
  kind text not null check(kind in('student','charge','payment')),
  result_id uuid not null,
  user_ref uuid not null references auth.users(id) on delete restrict,
  imported_at timestamptz not null default now(),
  primary key(ticket_id,source_ref)
);
alter table kombax_customer_ops.migration_import_requests_v271 enable row level security;
alter table kombax_customer_ops.migration_imported_records_v271 enable row level security;
revoke all on kombax_customer_ops.migration_import_requests_v271 from public,anon,authenticated,service_role;
revoke all on kombax_customer_ops.migration_imported_records_v271 from public,anon,authenticated,service_role;

create or replace function public.app_kombax_migration_records_v271(p_ticket_id text)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_uid uuid:=auth.uid(); v_rows jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
  if not exists(select 1 from kombax_customer_ops.tickets t where t.ticket_id=p_ticket_id and t.user_ref=v_uid and t.category='MIGRATION') then raise exception 'KOMBAX_MIGRATION_TICKET_REQUIRED'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('file_id',a.file_id,'file_name',f.original_name,'summary',a.summary,'needs_review',a.needs_review,'records',coalesce(a.structured_preview->'records','[]'::jsonb)) order by f.created_at),'[]'::jsonb)
  into v_rows from kombax_customer_ops.migration_file_analysis a join kombax_customer_ops.migration_files f on f.file_id=a.file_id
  where a.ticket_id=p_ticket_id and a.user_ref=v_uid;
  return jsonb_build_object('ticket_id',p_ticket_id,'files',v_rows,'max_records',200);
end $$;

create or replace function public.app_kombax_migration_import_v271(p_ticket_id text,p_request_id uuid,p_records jsonb)
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_uid uuid:=auth.uid(); v_ticket kombax_customer_ops.tickets%rowtype; v_club uuid; v_role text;
  v_payload_hash text; v_prev kombax_customer_ops.migration_import_requests_v271%rowtype;
  v_row jsonb; v_f jsonb; v_kind text; v_source text; v_id uuid; v_quota uuid; v_socio uuid;
  v_count integer:=0; v_students integer:=0; v_charges integer:=0; v_payments integer:=0; v_skipped integer:=0; v_map jsonb:='{}'::jsonb;v_old_id uuid;v_new boolean;
  v_name text; v_surname text; v_period date; v_due date; v_amount numeric; v_remaining numeric; v_method text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
  if p_request_id is null or jsonb_typeof(p_records)<>'array' or jsonb_array_length(p_records)<1 or jsonb_array_length(p_records)>200 then raise exception 'MIGRATION_IMPORT_INPUT_INVALID' using errcode='22023'; end if;
  select * into v_ticket from kombax_customer_ops.tickets t where t.ticket_id=p_ticket_id and t.user_ref=v_uid and t.category='MIGRATION' for update;
  if not found then raise exception 'KOMBAX_MIGRATION_TICKET_REQUIRED'; end if;
  if v_ticket.tenant_ref !~ '^club:[0-9a-fA-F-]{36}$' then raise exception 'MIGRATION_CLUB_IMPORT_ONLY'; end if;
  v_club:=split_part(v_ticket.tenant_ref,':',2)::uuid;
  if not public.tiene_rol_club(v_club,'direccion','secretaria','economia') then raise exception 'MIGRATION_IMPORT_ROLE_REQUIRED' using errcode='42501'; end if;
  if not kombax_ai_ops.migration_access_allowed(v_uid,v_ticket.tenant_ref) then raise exception 'KOMBAX_MIGRATION_ACCESS_REQUIRED' using errcode='42501'; end if;
  if exists(select 1 from jsonb_array_elements(p_records) x where coalesce(x->>'source_ref','')='' or coalesce(x->>'kind','') not in ('student','charge','payment')) then raise exception 'MIGRATION_IMPORT_ROW_INVALID' using errcode='22023'; end if;
  if (select count(*) from jsonb_array_elements(p_records))<>(select count(distinct x->>'source_ref') from jsonb_array_elements(p_records) x) then raise exception 'MIGRATION_IMPORT_SOURCE_DUPLICATE'; end if;
  v_payload_hash:=md5(p_records::text);
  select * into v_prev from kombax_customer_ops.migration_import_requests_v271 r where r.ticket_id=p_ticket_id and r.request_id=p_request_id;
  if found then
    if v_prev.user_ref<>v_uid or v_prev.payload_hash<>v_payload_hash then raise exception 'MIGRATION_IMPORT_REQUEST_REUSED'; end if;
    return v_prev.result||jsonb_build_object('reused',true);
  end if;
  insert into kombax_customer_ops.migration_import_requests_v271(ticket_id,request_id,user_ref,payload_hash) values(p_ticket_id,p_request_id,v_uid,v_payload_hash);
  for v_row in select e.value from jsonb_array_elements(p_records) with ordinality e(value,ord) order by case e.value->>'kind' when 'student' then 1 when 'charge' then 2 else 3 end,e.ord loop
    v_kind:=v_row->>'kind';v_source:=left(v_row->>'source_ref',160);v_f:=coalesce(v_row->'fields','{}'::jsonb);v_id:=null;v_new:=true;
    if coalesce((v_row->>'selected')::boolean,true)=false then continue; end if;
    if not exists(select 1 from kombax_customer_ops.migration_file_analysis a cross join lateral jsonb_array_elements(coalesce(a.structured_preview->'records','[]'::jsonb)) r where a.ticket_id=p_ticket_id and a.user_ref=v_uid and r->>'source_ref'=v_source and r->>'kind'=v_kind) then raise exception 'MIGRATION_SOURCE_ROW_NOT_FOUND:%',v_source; end if;
    if coalesce((v_row->>'needs_review')::boolean,false) then raise exception 'MIGRATION_ROW_NEEDS_REVIEW:%',v_source; end if;
    select result_id into v_old_id from kombax_customer_ops.migration_imported_records_v271 where ticket_id=p_ticket_id and source_ref=v_source and user_ref=v_uid;
    if found then v_map:=v_map||jsonb_build_object(v_source,v_old_id);v_skipped:=v_skipped+1;continue;end if;
    if v_kind='student' then
      if not public.tiene_rol_club(v_club,'direccion','secretaria') then raise exception 'MIGRATION_STUDENT_ROLE_REQUIRED' using errcode='42501'; end if;
      v_name:=btrim(coalesce(v_f->>'name',''));v_surname:=btrim(coalesce(v_f->>'surname',''));
      if v_name='' or v_surname='' then raise exception 'MIGRATION_STUDENT_NAME_REQUIRED:%',v_source; end if;
      v_id:=public.app_guardar_socio(v_club,null,v_name,v_surname,nullif(v_f->>'birth_date','')::date,v_f->>'phone',v_f->>'email',v_f->>'guardian_name',nullif(v_f->>'discipline_id','')::uuid,nullif(v_f->>'group_id','')::uuid,null,null,nullif(v_f->>'tariff_id','')::uuid,'prealta',null,null,'Alta importada; verificar ficha antes de activar.');
      v_map:=v_map||jsonb_build_object(v_source,v_id);v_students:=v_students+1;
    elsif v_kind='charge' then
      if not public.tiene_rol_club(v_club,'direccion','economia') then raise exception 'MIGRATION_FINANCE_ROLE_REQUIRED' using errcode='42501'; end if;
      v_socio:=coalesce(nullif(v_f->>'socio_id','')::uuid,nullif(v_map->>coalesce(v_f->>'student_source_ref',''),'')::uuid);
      if v_socio is null or not exists(select 1 from public.socios s where s.id=v_socio and s.club_id=v_club) then raise exception 'MIGRATION_CHARGE_STUDENT_REQUIRED:%',v_source; end if;
      v_period:=nullif(v_f->>'period','')::date;v_due:=nullif(v_f->>'due_date','')::date;v_amount:=nullif(v_f->>'amount','')::numeric;
      if v_period is null or v_due is null or v_amount is null or v_amount<0 then raise exception 'MIGRATION_CHARGE_FIELDS_REQUIRED:%',v_source; end if;
      insert into public.cuotas(club_id,socio_id,periodo,concepto,importe,vencimiento,estado,origen,categoria_financiera,avisos_pausados,motivo_pausa_avisos,avisos_pausados_por,avisos_pausados_en)
      values(v_club,v_socio,v_period,left(coalesce(nullif(v_f->>'concept',''),'Cargo histórico importado'),120),v_amount,v_due,'pendiente','cuota','cuota',true,'Importación KOMBAX Migrations pendiente de conciliación',v_uid,now())
      on conflict(club_id,socio_id,periodo,concepto) do nothing returning id into v_id;
      if v_id is null then select q.id into v_id from public.cuotas q where q.club_id=v_club and q.socio_id=v_socio and q.periodo=v_period and q.concepto=left(coalesce(nullif(v_f->>'concept',''),'Cargo histórico importado'),120);v_skipped:=v_skipped+1;v_new:=false;else v_charges:=v_charges+1;end if;
      v_map:=v_map||jsonb_build_object(v_source,v_id);
    elsif v_kind='payment' then
      if not public.tiene_rol_club(v_club,'direccion','economia') then raise exception 'MIGRATION_FINANCE_ROLE_REQUIRED' using errcode='42501'; end if;
      v_quota:=coalesce(nullif(v_f->>'quota_id','')::uuid,nullif(v_map->>coalesce(v_f->>'charge_source_ref',''),'')::uuid);
      v_amount:=nullif(v_f->>'amount','')::numeric;v_method:=coalesce(nullif(v_f->>'method',''),'otro');
      select q.socio_id,q.importe-coalesce(sum(p.importe) filter(where p.estado_validacion in('validado','pendiente')),0) into v_socio,v_remaining from public.cuotas q left join public.pagos p on p.cuota_id=q.id and p.club_id=q.club_id where q.id=v_quota and q.club_id=v_club group by q.socio_id,q.importe;
      if v_socio is null or v_amount is null or v_amount<=0 or v_amount>v_remaining or v_method not in ('transferencia','bizum','efectivo','tarjeta','sepa','terminal','otro') then raise exception 'MIGRATION_PAYMENT_FIELDS_REQUIRED_OR_EXCEEDS_BALANCE:%',v_source; end if;
      insert into public.pagos(club_id,cuota_id,socio_id,importe,fecha,metodo,referencia,estado_validacion,comunicado_por,comunicado_en,observaciones)
      values(v_club,v_quota,v_socio,v_amount,coalesce(nullif(v_f->>'date','')::date,current_date),v_method,left(v_f->>'reference',160),'pendiente',v_uid,now(),'Pago importado desde KOMBAX Migrations; requiere conciliación humana') returning id into v_id;
      update public.cuotas set estado='pendiente_validacion',avisos_pausados=true,motivo_pausa_avisos='Pago importado pendiente de revisión humana',avisos_pausados_por=v_uid,avisos_pausados_en=now(),pago_comunicado_en=now(),actualizado_en=now() where id=v_quota and club_id=v_club;
      v_map:=v_map||jsonb_build_object(v_source,v_id);v_payments:=v_payments+1;
    end if;
    insert into kombax_customer_ops.migration_imported_records_v271(ticket_id,source_ref,kind,result_id,user_ref) values(p_ticket_id,v_source,v_kind,v_id,v_uid) on conflict(ticket_id,source_ref) do nothing;
    if v_new then v_count:=v_count+1;end if;
  end loop;
  update kombax_customer_ops.migration_import_requests_v271 set imported_count=v_count,result=jsonb_build_object('ok',true,'created',v_count,'students',v_students,'charges',v_charges,'payments_pending_review',v_payments,'skipped_duplicates',v_skipped,'source_map',v_map,'human_review_required',v_payments>0) where ticket_id=p_ticket_id and request_id=p_request_id;
  return jsonb_build_object('ok',true,'created',v_count,'students',v_students,'charges',v_charges,'payments_pending_review',v_payments,'skipped_duplicates',v_skipped,'source_map',v_map,'human_review_required',v_payments>0,'reused',false);
end $$;

revoke all on function public.app_kombax_migration_records_v271(text) from public,anon,service_role;
revoke all on function public.app_kombax_migration_import_v271(text,uuid,jsonb) from public,anon,service_role;
grant execute on function public.app_kombax_migration_records_v271(text) to authenticated;
grant execute on function public.app_kombax_migration_import_v271(text,uuid,jsonb) to authenticated;
comment on function public.app_kombax_migration_import_v271(text,uuid,jsonb) is 'Human-confirmed, idempotent club migration import. New students remain prealta; imported charges remain unpaid with reminders paused; imported payments require human validation.';
notify pgrst,'reload schema';
