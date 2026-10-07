-- Historical membership and ledger entries. No external payment is executed.
begin;
alter function public.app_kombax_member_batch_mutate_r120(text,jsonb,uuid) rename to app_kombax_member_batch_pre_history_fix20;
revoke all on function public.app_kombax_member_batch_pre_history_fix20(text,jsonb,uuid) from public,anon,authenticated;
create function public.app_kombax_member_batch_mutate_r120(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; joined date; born date; club uuid; sid uuid; replay boolean;
begin
 if auth.uid() is null or p_request_id is null then raise exception 'AUTH_REQUIRED';end if;
 club:=(p_payload->>'club_id')::uuid;
 if p_operation='member.save.batch' and nullif(p_payload->'member'->>'fecha_alta','') is not null then
  if not public.tiene_rol_club(club,'direccion','secretaria') then raise exception 'MEMBER_ADMIN_REQUIRED';end if;
  joined:=(p_payload->'member'->>'fecha_alta')::date;
  born:=nullif(p_payload->'member'->>'fecha_nacimiento','')::date;
  if born is null then select fecha_nacimiento into born from public.socios where id=nullif(p_payload->'member'->>'id','')::uuid and club_id=club;end if;
  if joined>current_date or (born is not null and joined<born) then raise exception 'MEMBER_JOIN_DATE_INVALID';end if;
 end if;
 perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,121));
 replay:=exists(select 1 from public.kombax_member_batch_requests_r120 where request_id=p_request_id);
 result:=public.app_kombax_member_batch_pre_history_fix20(p_operation,p_payload,p_request_id);
 if joined is not null and not replay then
  sid:=(result->'data'->>'socio_id')::uuid;
  update public.socios set fecha_alta=joined,actualizado_en=now() where id=sid and club_id=club;
 end if;
 return result;
end $$;
revoke all on function public.app_kombax_member_batch_mutate_r120(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_member_batch_mutate_r120(text,jsonb,uuid) to authenticated;

create table public.kombax_historical_finance_requests_fix20(
 request_id uuid primary key,actor_id uuid not null,club_id uuid not null,
 payload jsonb not null,response jsonb not null,created_at timestamptz not null default now()
);
alter table public.kombax_historical_finance_requests_fix20 enable row level security;
revoke all on public.kombax_historical_finance_requests_fix20 from public,anon,authenticated;
create function public.app_kombax_historical_finance_fix20(p_club_id uuid,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare sid uuid; mode text; concept text; amount numeric; period date; due date; paid date;
 method text; fee uuid; payment public.pagos; result jsonb; old public.kombax_historical_finance_requests_fix20%rowtype;
begin
 if auth.uid() is null or p_request_id is null then raise exception 'AUTH_REQUIRED';end if;
 if not public.tiene_rol_club(p_club_id,'direccion','secretaria','economia') then raise exception 'FINANCE_ADMIN_REQUIRED';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,220));
 select * into old from public.kombax_historical_finance_requests_fix20 where request_id=p_request_id;
 if found then
  if old.actor_id<>auth.uid() or old.club_id<>p_club_id or old.payload<>p_payload then raise exception 'REQUEST_ID_REUSED';end if;
  return old.response;
 end if;
 sid:=(p_payload->>'socio_id')::uuid;mode:=p_payload->>'estado';concept:=btrim(p_payload->>'concepto');
 amount:=(p_payload->>'importe')::numeric;period:=(p_payload->>'periodo')::date;due:=(p_payload->>'vencimiento')::date;
 if not exists(select 1 from public.socios where id=sid and club_id=p_club_id) then raise exception 'MEMBER_CONTEXT_MISMATCH';end if;
 if mode is null or mode not in ('pendiente','pagado') or concept is null or length(concept) not between 1 and 200
  or amount is null or amount::text in ('NaN','Infinity','-Infinity') or amount<=0 or amount>99999999.99 or round(amount,2)<>amount
  or period is null or due is null or period>current_date or due>current_date then raise exception 'HISTORY_INVALID';end if;
 if mode='pagado' then
  paid:=(p_payload->>'fecha_pago')::date;method:=p_payload->>'metodo';
  if paid is null or paid>current_date or method is null or method not in ('transferencia','bizum','efectivo','tarjeta','otro') then raise exception 'HISTORY_PAYMENT_INVALID';end if;
 end if;
 insert into public.cuotas(club_id,socio_id,periodo,concepto,concepto_publico,importe,vencimiento,estado,origen,
  categoria_financiera,generado_automaticamente,lote_cargo_id,snapshot_regla,avisos_pausados,motivo_pausa_avisos)
 values(p_club_id,sid,date_trunc('month',period)::date,concept||' ['||p_request_id::text||']',concept,amount,due,'pendiente','cuota',
  'cuota',false,p_request_id,jsonb_build_object('tipo','historico_manual','registrado_por',auth.uid(),'registrado_en',now(),
   'observaciones',left(p_payload->>'observaciones',2000)),true,'Histórico registrado manualmente') returning id into fee;
 if mode='pagado' then
  payment:=public.registrar_cobro_cuota(fee,amount,paid,method,left(p_payload->>'referencia',200),left(p_payload->>'observaciones',2000));
 end if;
 result:=jsonb_build_object('cuota_id',fee,'pago_id',payment.id,'estado',mode);
 insert into public.kombax_historical_finance_requests_fix20(request_id,actor_id,club_id,payload,response)
 values(p_request_id,auth.uid(),p_club_id,p_payload,result);
 return result;
end $$;
revoke all on function public.app_kombax_historical_finance_fix20(uuid,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_historical_finance_fix20(uuid,jsonb,uuid) to authenticated;
commit;
