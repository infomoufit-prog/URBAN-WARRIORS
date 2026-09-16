-- KOMBAX R62.5.2 · Event ticket visual identity, QR access control and staffing
-- Incremental, non-destructive. Keeps R62.5 Stripe/direct-charge model unchanged.
begin;

alter table public.kombax_eventos_publicos
  add column if not exists ticket_contact_email text,
  add column if not exists ticket_contact_phone text;

alter table public.kombax_eventos_publicos drop constraint if exists kombax_event_ticket_contact_email_r6252;
alter table public.kombax_eventos_publicos add constraint kombax_event_ticket_contact_email_r6252
  check(ticket_contact_email is null or ticket_contact_email ~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$');
alter table public.kombax_eventos_publicos drop constraint if exists kombax_event_ticket_contact_phone_r6252;
alter table public.kombax_eventos_publicos add constraint kombax_event_ticket_contact_phone_r6252
  check(ticket_contact_phone is null or char_length(ticket_contact_phone) between 6 and 40);

alter table kombax_payments.event_tickets
  add column if not exists used_by uuid references public.perfiles(id) on delete restrict;
create index if not exists idx_event_tickets_used_by_r6252 on kombax_payments.event_tickets(used_by) where used_by is not null;

create table if not exists kombax_payments.event_ticket_access_staff(
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.kombax_eventos_publicos(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  role_code text not null check(role_code in('ticketing_manager','access_control','box_office')),
  status text not null default 'active' check(status in('active','revoked')),
  granted_by uuid not null references public.perfiles(id) on delete restrict,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique(event_id,perfil_id)
);
create index if not exists idx_event_ticket_access_staff_event_r6252 on kombax_payments.event_ticket_access_staff(event_id,status,role_code);
create index if not exists idx_event_ticket_access_staff_profile_r6252 on kombax_payments.event_ticket_access_staff(perfil_id,status,event_id);
alter table kombax_payments.event_ticket_access_staff enable row level security;
revoke all on kombax_payments.event_ticket_access_staff from public,anon,authenticated;
grant all on kombax_payments.event_ticket_access_staff to service_role;

create table if not exists kombax_payments.event_ticket_checkin_audit(
  id bigint generated always as identity primary key,
  event_id uuid not null references public.kombax_eventos_publicos(id) on delete restrict,
  ticket_id uuid references kombax_payments.event_tickets(id) on delete restrict,
  actor_user_id uuid not null references public.perfiles(id) on delete restrict,
  outcome text not null check(outcome in('valid','already_used','refunded','cancelled','wrong_event','invalid')),
  scan_fingerprint text not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_event_ticket_checkin_audit_event_r6252 on kombax_payments.event_ticket_checkin_audit(event_id,created_at desc);
create index if not exists idx_event_ticket_checkin_audit_ticket_r6252 on kombax_payments.event_ticket_checkin_audit(ticket_id,created_at desc) where ticket_id is not null;
alter table kombax_payments.event_ticket_checkin_audit enable row level security;
revoke all on kombax_payments.event_ticket_checkin_audit from public,anon,authenticated;
grant all on kombax_payments.event_ticket_checkin_audit to service_role;

create or replace function kombax_payments.can_event_ticket_action_r6252(p_event_id uuid,p_actor uuid,p_action text)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_action text:=lower(coalesce(p_action,''));v_role text;
begin
  if p_event_id is null or p_actor is null then return false; end if;
  if p_actor=auth.uid() and public.app_kombax_evento_puede_gestionar_v160(p_event_id) then return true; end if;
  if exists(select 1 from public.kombax_platform_admins a where a.perfil_id=p_actor and a.activo) then return true; end if;
  select s.role_code into v_role from kombax_payments.event_ticket_access_staff s
    where s.event_id=p_event_id and s.perfil_id=p_actor and s.status='active' limit 1;
  if v_role is null then return false; end if;
  if v_action in('read','dashboard','checkin') then return true; end if;
  if v_action='sales' then return v_role in('ticketing_manager','box_office'); end if;
  return false;
end $$;
revoke all on function kombax_payments.can_event_ticket_action_r6252(uuid,uuid,text) from public,anon,authenticated;
grant execute on function kombax_payments.can_event_ticket_action_r6252(uuid,uuid,text) to service_role;

create or replace function public.app_kombax_event_ticket_access_status_r6252(p_event_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_role text;v_manage boolean:=false;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  v_manage:=public.app_kombax_evento_puede_gestionar_v160(p_event_id);
  select s.role_code into v_role from kombax_payments.event_ticket_access_staff s where s.event_id=p_event_id and s.perfil_id=v_uid and s.status='active' limit 1;
  return jsonb_build_object('event_id',p_event_id,'can_manage',v_manage,'role_code',coalesce(v_role,case when v_manage then 'event_manager' end),
    'can_dashboard',v_manage or v_role is not null,
    'can_sales',v_manage or v_role in('ticketing_manager','box_office'),
    'can_checkin',v_manage or v_role is not null,
    'can_manage_staff',v_manage);
end $$;
revoke all on function public.app_kombax_event_ticket_access_status_r6252(uuid) from public,anon;
grant execute on function public.app_kombax_event_ticket_access_status_r6252(uuid) to authenticated;

create or replace function public.app_kombax_event_ticket_staff_r6252(p_event_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_rows jsonb;
begin
  if auth.uid() is null or not public.app_kombax_evento_puede_gestionar_v160(p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('perfil_id',s.perfil_id,'role_code',s.role_code,'status',s.status,
    'name',trim(concat_ws(' ',p.nombre,p.apellidos)),'email',u.email,'granted_at',s.granted_at) order by s.status,s.granted_at desc),'[]'::jsonb)
  into v_rows from kombax_payments.event_ticket_access_staff s
  join public.perfiles p on p.id=s.perfil_id left join auth.users u on u.id=s.perfil_id where s.event_id=p_event_id;
  return v_rows;
end $$;
revoke all on function public.app_kombax_event_ticket_staff_r6252(uuid) from public,anon;
grant execute on function public.app_kombax_event_ticket_staff_r6252(uuid) to authenticated;

create or replace function public.app_kombax_event_ticket_staff_mutate_r6252(p_event_id uuid,p_email text,p_role_code text,p_active boolean default true)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_target uuid;v_role text:=lower(coalesce(p_role_code,''));v_email text:=lower(trim(coalesce(p_email,'')));
begin
  if v_uid is null or not public.app_kombax_evento_puede_gestionar_v160(p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  if v_role not in('ticketing_manager','access_control','box_office') then raise exception 'EVENT_TICKET_ROLE_INVALID'; end if;
  select u.id into v_target from auth.users u where lower(u.email)=v_email limit 1;
  if v_target is null or not exists(select 1 from public.perfiles p where p.id=v_target) then raise exception 'KOMBAX_USER_NOT_FOUND'; end if;
  if p_active then
    insert into kombax_payments.event_ticket_access_staff(event_id,perfil_id,role_code,status,granted_by)
    values(p_event_id,v_target,v_role,'active',v_uid)
    on conflict(event_id,perfil_id) do update set role_code=excluded.role_code,status='active',granted_by=v_uid,granted_at=now(),revoked_at=null;
  else
    update kombax_payments.event_ticket_access_staff set status='revoked',revoked_at=now() where event_id=p_event_id and perfil_id=v_target;
  end if;
  return jsonb_build_object('ok',true,'event_id',p_event_id,'perfil_id',v_target,'role_code',v_role,'status',case when p_active then 'active' else 'revoked' end);
end $$;
revoke all on function public.app_kombax_event_ticket_staff_mutate_r6252(uuid,text,text,boolean) from public,anon;
grant execute on function public.app_kombax_event_ticket_staff_mutate_r6252(uuid,text,text,boolean) to authenticated;

create or replace function public.app_kombax_event_ticket_dashboard_r6252(p_event_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();e public.kombax_eventos_publicos;v_paid int:=0;v_reserved int:=0;v_used int:=0;v_refunded int:=0;v_cancelled int:=0;v_revenue bigint:=0;v_refunded_amount bigint:=0;
begin
  if v_uid is null or not kombax_payments.can_event_ticket_action_r6252(p_event_id,v_uid,'dashboard') then raise exception 'EVENT_TICKET_ACCESS_REQUIRED'; end if;
  select * into strict e from public.kombax_eventos_publicos where id=p_event_id;
  select coalesce(sum(quantity),0)::int,coalesce(sum(amount_total_minor),0)::bigint into v_paid,v_revenue from kombax_payments.event_ticket_orders where event_id=p_event_id and status='paid';
  select coalesce(sum(quantity),0)::int into v_reserved from kombax_payments.event_ticket_orders where event_id=p_event_id and status='pending_payment' and expires_at>now();
  select count(*)::int into v_used from kombax_payments.event_tickets where event_id=p_event_id and status='used';
  select count(*)::int into v_refunded from kombax_payments.event_tickets where event_id=p_event_id and status='refunded';
  select count(*)::int into v_cancelled from kombax_payments.event_tickets where event_id=p_event_id and status='cancelled';
  select coalesce(sum(amount_total_minor),0)::bigint into v_refunded_amount from kombax_payments.event_ticket_orders where event_id=p_event_id and status='refunded';
  return jsonb_build_object('event_id',p_event_id,'capacity',e.ticket_capacity,'paid',v_paid,'reserved',v_reserved,'used',v_used,
    'pending_access',greatest(0,v_paid-v_used),'refunded',v_refunded,'cancelled',v_cancelled,
    'available',case when e.ticket_capacity is null then null else greatest(0,e.ticket_capacity-v_paid-v_reserved) end,
    'revenue_confirmed',v_revenue/100.0,'revenue_refunded',v_refunded_amount/100.0,'currency',e.ticket_currency);
end $$;
revoke all on function public.app_kombax_event_ticket_dashboard_r6252(uuid) from public,anon;
grant execute on function public.app_kombax_event_ticket_dashboard_r6252(uuid) to authenticated;

create or replace function public.app_kombax_event_ticket_checkin_r6252(p_event_id uuid,p_code text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_raw text:=trim(coalesce(p_code,''));v_token text;v_ticket kombax_payments.event_tickets;v_outcome text;v_fp text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not kombax_payments.can_event_ticket_action_r6252(p_event_id,v_uid,'checkin') then raise exception 'EVENT_TICKET_CHECKIN_REQUIRED'; end if;
  if v_raw='' or char_length(v_raw)>160 then raise exception 'EVENT_TICKET_CODE_INVALID'; end if;
  v_token:=regexp_replace(v_raw,'^KXEVT:','','i');v_fp:=encode(extensions.digest(v_raw,'sha256'),'hex');
  begin
    select * into v_ticket from kombax_payments.event_tickets t
      where t.ticket_token::text=v_token or upper(t.ticket_code)=upper(v_raw) for update;
  exception when invalid_text_representation then
    select * into v_ticket from kombax_payments.event_tickets t where upper(t.ticket_code)=upper(v_raw) for update;
  end;
  if v_ticket.id is null then
    insert into kombax_payments.event_ticket_checkin_audit(event_id,actor_user_id,outcome,scan_fingerprint) values(p_event_id,v_uid,'invalid',v_fp);
    return jsonb_build_object('ok',false,'outcome','invalid','message','Entrada no válida.');
  end if;
  if v_ticket.event_id<>p_event_id then
    insert into kombax_payments.event_ticket_checkin_audit(event_id,ticket_id,actor_user_id,outcome,scan_fingerprint) values(p_event_id,v_ticket.id,v_uid,'wrong_event',v_fp);
    return jsonb_build_object('ok',false,'outcome','wrong_event','message','Esta entrada pertenece a otro evento.');
  end if;
  if v_ticket.status='active' then
    update kombax_payments.event_tickets set status='used',used_at=now(),used_by=v_uid,updated_at=now() where id=v_ticket.id returning * into v_ticket;
    v_outcome:='valid';
  elsif v_ticket.status='used' then v_outcome:='already_used';
  elsif v_ticket.status='refunded' then v_outcome:='refunded';
  else v_outcome:='cancelled'; end if;
  insert into kombax_payments.event_ticket_checkin_audit(event_id,ticket_id,actor_user_id,outcome,scan_fingerprint,used_at)
    values(p_event_id,v_ticket.id,v_uid,v_outcome,v_fp,v_ticket.used_at);
  return jsonb_build_object('ok',v_outcome='valid','outcome',v_outcome,'ticket_id',v_ticket.id,'ticket_code',v_ticket.ticket_code,
    'status',v_ticket.status,'used_at',v_ticket.used_at,'message',case v_outcome when 'valid' then 'Entrada válida. Acceso registrado.' when 'already_used' then 'Esta entrada ya fue utilizada.' when 'refunded' then 'Entrada reembolsada.' else 'Entrada anulada.' end);
end $$;
revoke all on function public.app_kombax_event_ticket_checkin_r6252(uuid,text) from public,anon;
grant execute on function public.app_kombax_event_ticket_checkin_r6252(uuid,text) to authenticated;

create or replace function public.app_kombax_my_event_tickets_r6252(p_limit integer default 100)
returns jsonb language sql stable security definer set search_path='' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'order_id',o.id,'order_number',o.order_number,'event_id',o.event_id,'event_name',e.nombre,'event_slug',e.slug,'event_date',e.fecha_inicio,'event_end',e.fecha_fin,
    'venue',e.lugar_nombre,'municipio',e.municipio,'province',e.provincia,'country',e.pais,'banner_url',e.banner_url,'poster_url',e.cartel_url,
    'organizer_name',coalesce(nullif(e.organizador_nombre,''),o.seller_name),'organizer_contact_email',e.ticket_contact_email,'organizer_contact_phone',e.ticket_contact_phone,
    'quantity',o.quantity,'unit_amount',o.unit_amount_minor/100.0,'amount_total',o.amount_total_minor/100.0,'currency',o.currency,
    'status',case when o.status='pending_payment' and o.expires_at<=now() then 'cancelled' else o.status end,'seller_name',o.seller_name,'created_at',o.created_at,'paid_at',o.paid_at,
    'tickets',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'ticket_code',t.ticket_code,'ticket_token',t.ticket_token,'status',t.status,'ticket_index',t.ticket_index,'used_at',t.used_at) order by t.ticket_index) from kombax_payments.event_tickets t where t.order_id=o.id),'[]'::jsonb)
  ) order by o.created_at desc),'[]'::jsonb)
  from (select * from kombax_payments.event_ticket_orders where buyer_user_id=auth.uid() order by created_at desc limit least(greatest(p_limit,1),200)) o
  join public.kombax_eventos_publicos e on e.id=o.event_id;
$$;
revoke all on function public.app_kombax_my_event_tickets_r6252(integer) from public,anon;
grant execute on function public.app_kombax_my_event_tickets_r6252(integer) to authenticated;

create or replace function public.app_kombax_event_ticket_sales_r6252(p_event_id uuid,p_limit integer default 200)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_orders jsonb;v_dashboard jsonb;
begin
  if v_uid is null or not kombax_payments.can_event_ticket_action_r6252(p_event_id,v_uid,'sales') then raise exception 'EVENT_TICKET_SALES_REQUIRED'; end if;
  v_dashboard:=public.app_kombax_event_ticket_dashboard_r6252(p_event_id);
  select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'order_number',o.order_number,'quantity',o.quantity,'amount_total',o.amount_total_minor/100.0,'currency',o.currency,
    'status',case when o.status='pending_payment' and o.expires_at<=now() then 'cancelled' else o.status end,'buyer_email',o.buyer_email,'created_at',o.created_at,'paid_at',o.paid_at,
    'tickets',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'ticket_code',t.ticket_code,'status',t.status,'used_at',t.used_at) order by t.ticket_index) from kombax_payments.event_tickets t where t.order_id=o.id),'[]'::jsonb)
  ) order by o.created_at desc),'[]'::jsonb) into v_orders
  from (select * from kombax_payments.event_ticket_orders where event_id=p_event_id order by created_at desc limit least(greatest(p_limit,1),500)) o;
  return v_dashboard||jsonb_build_object('orders',v_orders);
end $$;
revoke all on function public.app_kombax_event_ticket_sales_r6252(uuid,integer) from public,anon;
grant execute on function public.app_kombax_event_ticket_sales_r6252(uuid,integer) to authenticated;

create or replace function public.app_kombax_event_ticketing_manage_status_r6252(p_event_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_base jsonb; e public.kombax_eventos_publicos;
begin
  if auth.uid() is null or not public.app_kombax_evento_puede_gestionar_v160(p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  v_base:=public.app_kombax_event_ticketing_manage_status_r625(p_event_id);
  select * into strict e from public.kombax_eventos_publicos where id=p_event_id;
  return v_base||jsonb_build_object('ticket_contact_email',e.ticket_contact_email,'ticket_contact_phone',e.ticket_contact_phone);
end $$;
revoke all on function public.app_kombax_event_ticketing_manage_status_r6252(uuid) from public,anon;
grant execute on function public.app_kombax_event_ticketing_manage_status_r6252(uuid) to authenticated;

create or replace function public.app_kombax_event_ticketing_mutate_r6252(p_event_id uuid,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_result jsonb;v_email text:=nullif(lower(trim(coalesce(p_payload->>'contact_email',''))),'');v_phone text:=nullif(left(trim(coalesce(p_payload->>'contact_phone','')),40),'');
begin
  if auth.uid() is null or not public.app_kombax_evento_puede_gestionar_v160(p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED'; end if;
  v_result:=public.app_kombax_event_ticketing_mutate_r625(p_event_id,p_payload,p_request_id);
  update public.kombax_eventos_publicos set ticket_contact_email=v_email,ticket_contact_phone=v_phone,actualizado_en=now() where id=p_event_id;
  return v_result||jsonb_build_object('contact_email',v_email,'contact_phone',v_phone);
end $$;
revoke all on function public.app_kombax_event_ticketing_mutate_r6252(uuid,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_event_ticketing_mutate_r6252(uuid,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
