begin;

-- R31 runtime reconciliation: migration 202 was applied live as schema-only.
-- Extend the existing notification center with an optional global subject without
-- changing legacy Club rows or requiring a fake club_id.
alter table public.notificaciones alter column club_id drop not null;
alter table public.notificaciones add column if not exists subject_type text;
alter table public.notificaciones add column if not exists subject_id uuid;

do $$ begin
  if not exists(select 1 from pg_constraint where conname='notificaciones_subject_scope_v199') then
    alter table public.notificaciones add constraint notificaciones_subject_scope_v199 check (
      club_id is not null or (subject_type='direct_profile' and subject_id is not null)
    );
  end if;
end $$;

create index if not exists idx_notificaciones_direct_subject_v199
  on public.notificaciones(subject_type,subject_id,ciclo_estado,creado_en desc)
  where subject_type='direct_profile' and subject_id is not null;
create unique index if not exists uq_notificaciones_direct_active_key_v199
  on public.notificaciones(subject_type,subject_id,clave)
  where subject_type='direct_profile' and subject_id is not null and clave is not null and ciclo_estado='activo';

drop policy if exists notificaciones_direct_profile_read_v199 on public.notificaciones;
create policy notificaciones_direct_profile_read_v199 on public.notificaciones
for select to authenticated
using(subject_type='direct_profile' and subject_id is not null and public.app_kombax_puede_gestionar_perfil_v070(subject_id,'read'));

create or replace function public.app_kombax_professional_charge_restate_v199(p_charge_id uuid)
returns text language plpgsql security definer set search_path=public as $$
declare v_amount numeric(12,2);v_paid numeric(12,2);v_state text;v_current text;
begin
 select c.importe,c.estado into v_amount,v_current from public.kombax_professional_charges_v199 c where c.id=p_charge_id for update;
 if v_amount is null then raise exception 'KOMBAX_FINANCE_CHARGE_NOT_FOUND';end if;
 if v_current='anulado' then return v_current;end if;
 select coalesce(sum(p.importe),0) into v_paid from public.kombax_professional_payments_v199 p where p.charge_id=p_charge_id;
 if v_paid>v_amount then raise exception 'KOMBAX_FINANCE_OVERPAYMENT_INVALID';end if;
 v_state:=case when v_paid=0 then 'pendiente' when v_paid<v_amount then 'parcial' else 'pagado' end;
 update public.kombax_professional_charges_v199 set estado=v_state,actualizado_en=now() where id=p_charge_id;
 return v_state;
end $$;
revoke all on function public.app_kombax_professional_charge_restate_v199(uuid) from public,anon,authenticated;

create or replace function public.app_kombax_professional_finance_notifications_v199(p_profile_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
 if p_profile_id is null then raise exception 'KOMBAX_PROFILE_REQUIRED';end if;
 if not public.app_kombax_puede_gestionar_perfil_v070(p_profile_id,'read') then raise exception 'KOMBAX_PROFILE_NOT_MANAGED';end if;
 if not exists(select 1 from public.perfiles_kombax_directos d where d.id=p_profile_id and d.tipo='profesional') then raise exception 'KOMBAX_PROFESSIONAL_PROFILE_REQUIRED';end if;
 if not exists(select 1 from public.app_kombax_profile_capabilities_v196(p_profile_id)c where c.capacidad_clave in ('professional.finance.manage','professional.finance.reports')) then raise exception 'KOMBAX_CAPABILITY_REQUIRED:professional.finance.reports';end if;

 -- Resolve stale notices instead of deleting history.
 update public.notificaciones n
 set ciclo_estado='archivado',archivado_en=now(),archivado_por=v_uid
 where n.subject_type='direct_profile' and n.subject_id=p_profile_id
   and n.tipo='finanzas_profesionales' and n.ciclo_estado='activo'
   and n.clave like 'professional_finance_overdue:%'
   and not exists(
     select 1 from public.kombax_professional_charges_v199 c
     left join lateral (select coalesce(sum(p.importe),0) paid from public.kombax_professional_payments_v199 p where p.charge_id=c.id) px on true
     where c.professional_profile_id=p_profile_id
       and c.id::text=split_part(n.clave,':',2)
       and c.estado in ('pendiente','parcial') and c.vence_el is not null and c.vence_el<current_date and px.paid<c.importe
   );

 insert into public.notificaciones(club_id,perfil_id,audiencia,clave,tipo,titulo,cuerpo,ruta,datos,creada_por,subject_type,subject_id)
 select null,null,'gestores',
        'professional_finance_overdue:'||c.id::text,
        'finanzas_profesionales','Cargo vencido',
        c.concepto||' · saldo '||to_char(greatest(c.importe-px.paid,0),'FM999999990D00')||' '||c.moneda,
        'professional-finance',
        jsonb_build_object('professional_profile_id',p_profile_id,'charge_id',c.id,'vence_el',c.vence_el,'saldo',greatest(c.importe-px.paid,0),'requiere_accion',true),
        v_uid,'direct_profile',p_profile_id
 from public.kombax_professional_charges_v199 c
 left join lateral (select coalesce(sum(p.importe),0) paid from public.kombax_professional_payments_v199 p where p.charge_id=c.id) px on true
 where c.professional_profile_id=p_profile_id and c.estado in ('pendiente','parcial')
   and c.vence_el is not null and c.vence_el<current_date and px.paid<c.importe
 on conflict (subject_type,subject_id,clave) where subject_type='direct_profile' and subject_id is not null and clave is not null and ciclo_estado='activo'
 do update set cuerpo=excluded.cuerpo,datos=excluded.datos,creado_en=now();

 return coalesce((select jsonb_agg(jsonb_build_object(
   'id',n.id,'clave',n.clave,'tipo',n.tipo,'titulo',n.titulo,'cuerpo',n.cuerpo,'ruta',n.ruta,'datos',n.datos,
   'leida',n.leida,'creado_en',n.creado_en,'requiere_accion',coalesce((n.datos->>'requiere_accion')::boolean,false)
 ) order by n.creado_en desc)
 from public.notificaciones n
 where n.subject_type='direct_profile' and n.subject_id=p_profile_id and n.ciclo_estado='activo'),'[]'::jsonb);
end $$;
revoke all on function public.app_kombax_professional_finance_notifications_v199(uuid) from public,anon;
grant execute on function public.app_kombax_professional_finance_notifications_v199(uuid) to authenticated;

create or replace function public.app_kombax_professional_finance_v199(p_profile_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_caps text[]:='{}'::text[];v_generated numeric:=0;v_collected numeric:=0;v_pending numeric:=0;v_expenses numeric:=0;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
 if p_profile_id is null then raise exception 'KOMBAX_PROFILE_REQUIRED';end if;
 if not public.app_kombax_puede_gestionar_perfil_v070(p_profile_id,'read') then raise exception 'KOMBAX_PROFILE_NOT_MANAGED';end if;
 if not exists(select 1 from public.perfiles_kombax_directos d where d.id=p_profile_id and d.tipo='profesional') then raise exception 'KOMBAX_PROFESSIONAL_PROFILE_REQUIRED';end if;
 select coalesce(array_agg(c.capacidad_clave),'{}'::text[]) into v_caps from public.app_kombax_profile_capabilities_v196(p_profile_id)c;
 if not ('professional.finance.manage'=any(v_caps) or 'professional.finance.reports'=any(v_caps)) then raise exception 'KOMBAX_CAPABILITY_REQUIRED:professional.finance.reports';end if;
 select coalesce(sum(c.importe),0) into v_generated from public.kombax_professional_charges_v199 c where c.professional_profile_id=p_profile_id and c.estado<>'anulado';
 select coalesce(sum(p.importe),0) into v_collected from public.kombax_professional_payments_v199 p where p.professional_profile_id=p_profile_id;
 v_pending:=greatest(v_generated-v_collected,0);
 select coalesce(sum(e.importe),0) into v_expenses from public.kombax_professional_expenses_v199 e where e.professional_profile_id=p_profile_id;
 return jsonb_build_object(
   'profile_id',p_profile_id,
   'version','r31-v199',
   'capabilities',to_jsonb(v_caps),
   'flags',jsonb_build_object('processes_money',false,'fiscal_invoicing',false,'fake_club',false,'global_notifications_subject_ready',true),
   'kpis',jsonb_build_object('generated',v_generated,'collected',v_collected,'pending',v_pending,'expenses',v_expenses,'net',v_collected-v_expenses),
   'services',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'nombre',s.nombre,'descripcion',s.descripcion,'tarifa_referencia',s.tarifa_referencia,'moneda',s.moneda,'estado',s.estado) order by s.actualizado_en desc) from public.kombax_professional_services_v199 s where s.professional_profile_id=p_profile_id and s.estado='activo'),'[]'::jsonb),
   'charges',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'client_id',c.client_id,'service_id',c.service_id,'represented_profile_id',c.represented_profile_id,'assignment_id',c.assignment_id,'concepto',c.concepto,'importe',c.importe,'moneda',c.moneda,'vence_el',c.vence_el,'estado',c.estado,'pagado',coalesce(px.paid,0),'saldo',greatest(c.importe-coalesce(px.paid,0),0),'notas',c.notas,'creado_en',c.creado_en) order by c.creado_en desc) from public.kombax_professional_charges_v199 c left join lateral (select sum(p.importe) paid from public.kombax_professional_payments_v199 p where p.charge_id=c.id) px on true where c.professional_profile_id=p_profile_id),'[]'::jsonb),
   'payments',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'charge_id',p.charge_id,'importe',p.importe,'registrado_el',p.registrado_el,'metodo',p.metodo,'referencia',p.referencia,'notas',p.notas,'creado_en',p.creado_en) order by p.registrado_el desc,p.creado_en desc) from public.kombax_professional_payments_v199 p where p.professional_profile_id=p_profile_id),'[]'::jsonb),
   'expenses',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'concepto',e.concepto,'importe',e.importe,'moneda',e.moneda,'ocurrido_el',e.ocurrido_el,'categoria',e.categoria,'notas',e.notas) order by e.ocurrido_el desc,e.creado_en desc) from public.kombax_professional_expenses_v199 e where e.professional_profile_id=p_profile_id),'[]'::jsonb),
   'reminders',coalesce((select jsonb_agg(jsonb_build_object('charge_id',c.id,'concepto',c.concepto,'vence_el',c.vence_el,'saldo',greatest(c.importe-coalesce(px.paid,0),0),'severity',case when c.vence_el<current_date-30 then 'high' when c.vence_el<current_date-7 then 'medium' else 'low' end) order by c.vence_el) from public.kombax_professional_charges_v199 c left join lateral (select sum(p.importe) paid from public.kombax_professional_payments_v199 p where p.charge_id=c.id) px on true where c.professional_profile_id=p_profile_id and c.estado in ('pendiente','parcial') and c.vence_el is not null and c.vence_el<current_date and coalesce(px.paid,0)<c.importe),'[]'::jsonb),
   'monthly',coalesce((
      select jsonb_agg(jsonb_build_object('month',to_char(m.month,'YYYY-MM'),'generated',coalesce(c.generated,0),'collected',coalesce(p.collected,0),'expenses',coalesce(e.expenses,0),'net',coalesce(p.collected,0)-coalesce(e.expenses,0)) order by m.month)
      from generate_series(date_trunc('month',current_date)-interval '11 months',date_trunc('month',current_date),interval '1 month') m(month)
      left join lateral (select sum(x.importe) generated from public.kombax_professional_charges_v199 x where x.professional_profile_id=p_profile_id and x.estado<>'anulado' and date_trunc('month',x.creado_en)=m.month) c on true
      left join lateral (select sum(x.importe) collected from public.kombax_professional_payments_v199 x where x.professional_profile_id=p_profile_id and date_trunc('month',x.registrado_el::timestamp)=m.month) p on true
      left join lateral (select sum(x.importe) expenses from public.kombax_professional_expenses_v199 x where x.professional_profile_id=p_profile_id and date_trunc('month',x.ocurrido_el::timestamp)=m.month) e on true
   ),'[]'::jsonb)
 );
end $$;
revoke all on function public.app_kombax_professional_finance_v199(uuid) from public,anon;
grant execute on function public.app_kombax_professional_finance_v199(uuid) to authenticated;

create or replace function public.app_kombax_professional_finance_mutate_v199(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
 v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;
 v_profile uuid;v_id uuid;v_client uuid;v_service uuid;v_rep uuid;v_assignment uuid;v_charge uuid;
 v_amount numeric(12,2);v_existing_paid numeric(12,2);v_paid numeric(12,2);v_state text;v_result jsonb;v_currency text;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
 if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
 delete from public.app_mutation_requests where user_id=v_uid and created_at<now()-interval '30 days';
 select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
 if v_existing.request_id is not null then
   if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;
   if v_existing.result is not null then return v_existing.result;end if;
 else
   insert into public.app_mutation_requests(request_id,user_id,operation) values(p_request_id,v_uid,p_operation);
 end if;

 v_profile=public.app_kombax_uuid_or_null_v070(v_payload->>'professional_profile_id');
 if v_profile is null or not public.app_kombax_puede_gestionar_perfil_v070(v_profile,'edit') then raise exception 'KOMBAX_PROFESSIONAL_PROFILE_NOT_MANAGED';end if;
 if not exists(select 1 from public.perfiles_kombax_directos d where d.id=v_profile and d.tipo='profesional') then raise exception 'KOMBAX_PROFESSIONAL_PROFILE_REQUIRED';end if;
 if not exists(select 1 from public.app_kombax_profile_capabilities_v196(v_profile)c where c.capacidad_clave='professional.finance.manage') then raise exception 'KOMBAX_CAPABILITY_REQUIRED:professional.finance.manage';end if;

 if p_operation='finance.service.save' then
   v_id=public.app_kombax_uuid_or_null_v070(v_payload->>'id');v_currency=upper(coalesce(nullif(btrim(v_payload->>'moneda'),''),'EUR'));
   if v_id is null then
     insert into public.kombax_professional_services_v199(professional_profile_id,nombre,descripcion,tarifa_referencia,moneda,creado_por)
     values(v_profile,btrim(v_payload->>'nombre'),left(coalesce(v_payload->>'descripcion',''),2000),greatest(coalesce(nullif(v_payload->>'tarifa_referencia','')::numeric,0),0),v_currency,v_uid) returning id into v_id;
   else
     update public.kombax_professional_services_v199 set nombre=btrim(v_payload->>'nombre'),descripcion=left(coalesce(v_payload->>'descripcion',''),2000),tarifa_referencia=greatest(coalesce(nullif(v_payload->>'tarifa_referencia','')::numeric,0),0),moneda=v_currency,estado=coalesce(nullif(v_payload->>'estado',''),'activo'),actualizado_en=now() where id=v_id and professional_profile_id=v_profile;
     if not found then raise exception 'KOMBAX_FINANCE_SERVICE_NOT_FOUND';end if;
   end if;
   v_result=jsonb_build_object('id',v_id);
   insert into public.kombax_professional_finance_audit_v199(professional_profile_id,actor_profile_id,action,entity_type,entity_id) values(v_profile,v_uid,'service.save','service',v_id);

 elsif p_operation='finance.charge.save' then
   v_id=public.app_kombax_uuid_or_null_v070(v_payload->>'id');
   v_client=public.app_kombax_uuid_or_null_v070(v_payload->>'client_id');
   v_service=public.app_kombax_uuid_or_null_v070(v_payload->>'service_id');
   v_rep=public.app_kombax_uuid_or_null_v070(v_payload->>'represented_profile_id');
   v_assignment=public.app_kombax_uuid_or_null_v070(v_payload->>'assignment_id');
   v_amount=nullif(v_payload->>'importe','')::numeric;v_currency=upper(coalesce(nullif(btrim(v_payload->>'moneda'),''),'EUR'));
   if v_amount is null or v_amount<=0 then raise exception 'KOMBAX_FINANCE_AMOUNT_INVALID';end if;
   if v_client is not null and not exists(select 1 from public.kombax_professional_clients_v198 c where c.id=v_client and c.professional_profile_id=v_profile) then raise exception 'KOMBAX_FINANCE_CLIENT_SCOPE_INVALID';end if;
   if v_service is not null and not exists(select 1 from public.kombax_professional_services_v199 s where s.id=v_service and s.professional_profile_id=v_profile) then raise exception 'KOMBAX_FINANCE_SERVICE_SCOPE_INVALID';end if;
   if v_assignment is not null and not exists(select 1 from public.kombax_professional_assignments_v198 a where a.id=v_assignment and a.professional_profile_id=v_profile) then raise exception 'KOMBAX_FINANCE_ASSIGNMENT_SCOPE_INVALID';end if;
   if v_rep is not null then
     if not exists(select 1 from public.app_kombax_profile_capabilities_v196(v_profile)c where c.capacidad_clave='professional.represented.manage') then raise exception 'KOMBAX_CAPABILITY_REQUIRED:professional.represented.manage';end if;
     if not exists(select 1 from public.kombax_professional_delegations_v198 d where d.professional_profile_id=v_profile and d.target_profile_id=v_rep and d.status='accepted' and coalesce(d.starts_at,d.accepted_at,d.requested_at)<=now() and (d.expires_at is null or d.expires_at>now()) and d.revoked_at is null) then raise exception 'KOMBAX_FINANCE_REPRESENTATION_NOT_ACTIVE';end if;
   end if;
   if v_id is null then
     insert into public.kombax_professional_charges_v199(professional_profile_id,client_id,service_id,represented_profile_id,assignment_id,concepto,importe,moneda,vence_el,notas,creado_por)
     values(v_profile,v_client,v_service,v_rep,v_assignment,btrim(v_payload->>'concepto'),v_amount,v_currency,nullif(v_payload->>'vence_el','')::date,left(coalesce(v_payload->>'notas',''),2000),v_uid) returning id into v_id;
   else
     select coalesce(sum(p.importe),0) into v_existing_paid from public.kombax_professional_payments_v199 p where p.charge_id=v_id;
     if v_amount<v_existing_paid then raise exception 'KOMBAX_FINANCE_AMOUNT_BELOW_REGISTERED_PAYMENTS';end if;
     update public.kombax_professional_charges_v199 set client_id=v_client,service_id=v_service,represented_profile_id=v_rep,assignment_id=v_assignment,concepto=btrim(v_payload->>'concepto'),importe=v_amount,moneda=v_currency,vence_el=nullif(v_payload->>'vence_el','')::date,notas=left(coalesce(v_payload->>'notas',''),2000),actualizado_en=now() where id=v_id and professional_profile_id=v_profile and estado<>'anulado';
     if not found then raise exception 'KOMBAX_FINANCE_CHARGE_NOT_FOUND_OR_CANCELLED';end if;
     perform public.app_kombax_professional_charge_restate_v199(v_id);
   end if;
   v_result=jsonb_build_object('id',v_id,'status',(select estado from public.kombax_professional_charges_v199 where id=v_id));
   insert into public.kombax_professional_finance_audit_v199(professional_profile_id,actor_profile_id,action,entity_type,entity_id,detail) values(v_profile,v_uid,'charge.save','charge',v_id,jsonb_build_object('amount',v_amount,'represented_profile_id',v_rep,'assignment_id',v_assignment));

 elsif p_operation='finance.payment.register' then
   v_charge=public.app_kombax_uuid_or_null_v070(v_payload->>'charge_id');v_amount=nullif(v_payload->>'importe','')::numeric;
   if v_amount is null or v_amount<=0 then raise exception 'KOMBAX_FINANCE_PAYMENT_AMOUNT_INVALID';end if;
   select c.importe,c.estado into v_existing_paid,v_state from public.kombax_professional_charges_v199 c where c.id=v_charge and c.professional_profile_id=v_profile for update;
   if v_existing_paid is null or v_state='anulado' then raise exception 'KOMBAX_FINANCE_CHARGE_NOT_PAYABLE';end if;
   select coalesce(sum(p.importe),0) into v_paid from public.kombax_professional_payments_v199 p where p.charge_id=v_charge;
   if (v_paid+v_amount)>v_existing_paid then raise exception 'KOMBAX_FINANCE_OVERPAYMENT_INVALID';end if;
   insert into public.kombax_professional_payments_v199(professional_profile_id,charge_id,importe,registrado_el,metodo,referencia,notas,creado_por)
   values(v_profile,v_charge,v_amount,coalesce(nullif(v_payload->>'registrado_el','')::date,current_date),coalesce(nullif(v_payload->>'metodo',''),'otro'),left(coalesce(v_payload->>'referencia',''),240),left(coalesce(v_payload->>'notas',''),1200),v_uid) returning id into v_id;
   v_state=public.app_kombax_professional_charge_restate_v199(v_charge);
   v_result=jsonb_build_object('id',v_id,'charge_id',v_charge,'charge_status',v_state,'document_label','Comprobante interno');
   insert into public.kombax_professional_finance_audit_v199(professional_profile_id,actor_profile_id,action,entity_type,entity_id,detail) values(v_profile,v_uid,'payment.register','payment',v_id,jsonb_build_object('charge_id',v_charge,'amount',v_amount));

 elsif p_operation='finance.expense.save' then
   v_id=public.app_kombax_uuid_or_null_v070(v_payload->>'id');v_amount=nullif(v_payload->>'importe','')::numeric;v_currency=upper(coalesce(nullif(btrim(v_payload->>'moneda'),''),'EUR'));
   if v_amount is null or v_amount<=0 then raise exception 'KOMBAX_FINANCE_EXPENSE_AMOUNT_INVALID';end if;
   if v_id is null then
     insert into public.kombax_professional_expenses_v199(professional_profile_id,concepto,importe,moneda,ocurrido_el,categoria,notas,creado_por)
     values(v_profile,btrim(v_payload->>'concepto'),v_amount,v_currency,coalesce(nullif(v_payload->>'ocurrido_el','')::date,current_date),left(coalesce(nullif(v_payload->>'categoria',''),'otro'),80),left(coalesce(v_payload->>'notas',''),1600),v_uid) returning id into v_id;
   else
     update public.kombax_professional_expenses_v199 set concepto=btrim(v_payload->>'concepto'),importe=v_amount,moneda=v_currency,ocurrido_el=coalesce(nullif(v_payload->>'ocurrido_el','')::date,current_date),categoria=left(coalesce(nullif(v_payload->>'categoria',''),'otro'),80),notas=left(coalesce(v_payload->>'notas',''),1600),actualizado_en=now() where id=v_id and professional_profile_id=v_profile;
     if not found then raise exception 'KOMBAX_FINANCE_EXPENSE_NOT_FOUND';end if;
   end if;
   v_result=jsonb_build_object('id',v_id);
   insert into public.kombax_professional_finance_audit_v199(professional_profile_id,actor_profile_id,action,entity_type,entity_id) values(v_profile,v_uid,'expense.save','expense',v_id);

 elsif p_operation='finance.charge.cancel' then
   v_charge=public.app_kombax_uuid_or_null_v070(v_payload->>'charge_id');
   if exists(select 1 from public.kombax_professional_payments_v199 p where p.charge_id=v_charge) then raise exception 'KOMBAX_FINANCE_CHARGE_WITH_PAYMENTS_CANNOT_CANCEL';end if;
   update public.kombax_professional_charges_v199 set estado='anulado',actualizado_en=now() where id=v_charge and professional_profile_id=v_profile and estado<>'anulado';
   if not found then raise exception 'KOMBAX_FINANCE_CHARGE_NOT_FOUND';end if;
   v_result=jsonb_build_object('id',v_charge,'status','anulado');
   insert into public.kombax_professional_finance_audit_v199(professional_profile_id,actor_profile_id,action,entity_type,entity_id) values(v_profile,v_uid,'charge.cancel','charge',v_charge);
 else
   raise exception 'KOMBAX_PROFESSIONAL_FINANCE_OPERATION_NOT_ALLOWED';
 end if;

 v_result=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));
 update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
 return v_result;
exception when others then
 delete from public.app_mutation_requests where request_id=p_request_id and result is null;
 raise;
end $$;
revoke all on function public.app_kombax_professional_finance_mutate_v199(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_professional_finance_mutate_v199(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
