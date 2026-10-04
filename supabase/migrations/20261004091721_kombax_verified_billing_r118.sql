begin;
create schema if not exists kombax_billing;
revoke all on schema kombax_billing from public,anon,authenticated;
create table kombax_billing.plans(
 code text primary key references public.kombax_planes(codigo),audience text not null check(audience in('club','brand','federation')),
 stripe_price_id text check(stripe_price_id ~ '^price_[A-Za-z0-9]+$'),amount_minor integer check(amount_minor>0),currency text not null default 'eur',
 published boolean not null default false,livemode boolean not null default false,tax_ready boolean not null default false,
 terms_version text not null default 'billing-r118-v1',trial_days integer not null default 30 check(trial_days=30)
);
insert into kombax_billing.plans(code,audience) values('club','club'),('premium','club'),('brand_start','brand'),('brand_growth','brand'),('brand_enterprise','brand'),('federation','federation');
create table kombax_billing.requests(
 id uuid primary key default gen_random_uuid(),actor_id uuid not null,subject_type text not null,subject_id uuid not null,plan_code text not null references kombax_billing.plans(code),
 trial_days integer not null,consent_at timestamptz not null default now(),terms_version text not null,
 stripe_session_id text,status text not null default 'pending',created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '30 minutes'
);
create table kombax_billing.subscriptions(
 subject_type text not null,subject_id uuid not null,stripe_subscription_id text unique not null,customer_id text not null,
 actor_id uuid not null,plan_code text not null,local_id uuid not null default gen_random_uuid(),status text not null,
 trial_start timestamptz,trial_end timestamptz,period_end timestamptz,cancel_at_period_end boolean not null default false,
 sync_at timestamptz not null,last_event_id text,primary key(subject_type,subject_id)
);
create table kombax_billing.events(id text primary key,type text not null,received_at timestamptz not null default now());
alter table kombax_billing.plans enable row level security;
alter table kombax_billing.requests enable row level security;
alter table kombax_billing.subscriptions enable row level security;
alter table kombax_billing.events enable row level security;

create function kombax_billing.subject(p_actor uuid,p_type text,p_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare kind text;verified boolean;
begin
 if p_actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';end if;
 if p_type='club' then
  if not exists(select 1 from public.miembros_club m where m.club_id=p_id and m.perfil_id=p_actor and m.activo and (m.rol='direccion' or coalesce(m.coordinacion,false))) then raise exception 'OWNER_REQUIRED' using errcode='42501';end if;
  kind:='club';select exists(select 1 from public.kombax_solicitudes_alta a where a.club_id=p_id and a.tipo='club' and a.estado='verified') into verified;
 elsif p_type='direct_profile' then
  select case d.tipo when 'marca' then 'brand' when 'federacion' then 'federation' end,d.verificacion_estado='verificado' and d.workflow_estado in('verified','limited') into kind,verified
   from public.perfiles_kombax_directos d where d.id=p_id and d.perfil_id=p_actor and d.estado='activo';
  if kind is null then raise exception 'ORGANIZATION_OWNER_REQUIRED' using errcode='42501';end if;
 else raise exception 'INVALID_SUBJECT';end if;
 return jsonb_build_object('audience',kind,'verified',coalesce(verified,false),'pilot',exists(select 1 from kombax_commercial.pilot_entities_r97 p where p.subject_type=p_type and p.subject_id=p_id));
end $$;

create function public.app_kombax_billing_context_r118(p_subject_type text,p_subject_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare gate jsonb;plans jsonb;sub kombax_billing.subscriptions;
begin
 select * into sub from kombax_billing.subscriptions where subject_type=p_subject_type and subject_id=p_subject_id;
 begin gate:=kombax_billing.subject(auth.uid(),p_subject_type,p_subject_id);exception when insufficient_privilege then if sub.actor_id is distinct from auth.uid() or auth.uid() is null then raise;end if;gate:=jsonb_build_object('verified',false,'pilot',false,'audience',null);end;
 select * into sub from kombax_billing.subscriptions where subject_type=p_subject_type and subject_id=p_subject_id;
 select coalesce(jsonb_agg(jsonb_build_object('code',p.code,'amount_minor',p.amount_minor,'currency',p.currency,'available',p.published and p.tax_ready and p.stripe_price_id is not null,'trial_days',p.trial_days,'terms_version',p.terms_version) order by p.code),'[]'::jsonb) into plans from kombax_billing.plans p where p.audience=gate->>'audience';
 return gate||jsonb_build_object('plans',plans,'subscription',case when sub.subject_id is null then null else jsonb_build_object('status',sub.status,'trial_end',sub.trial_end,'period_end',sub.period_end,'cancel_at_period_end',sub.cancel_at_period_end) end);
end $$;

create function public.app_kombax_billing_prepare_r118(p_subject_type text,p_subject_id uuid,p_plan_code text,p_terms_version text,p_consent boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare gate jsonb;plan kombax_billing.plans;req kombax_billing.requests;days integer;
begin
 perform pg_advisory_xact_lock(hashtextextended(p_subject_type||':'||p_subject_id::text,0));
 gate:=kombax_billing.subject(auth.uid(),p_subject_type,p_subject_id);
 if (gate->>'pilot')::boolean then raise exception 'PILOT_BILLING_EXCLUDED';end if;
 if not (gate->>'verified')::boolean then raise exception 'VERIFICATION_REQUIRED';end if;
 select * into plan from kombax_billing.plans where code=p_plan_code and audience=gate->>'audience' and published and tax_ready and stripe_price_id is not null and amount_minor>0;
 if not found then raise exception 'PLAN_NOT_CONFIGURED';end if;
 if not coalesce(p_consent,false) or p_terms_version is distinct from plan.terms_version then raise exception 'RENEWAL_CONSENT_REQUIRED';end if;
 if exists(select 1 from kombax_billing.subscriptions where subject_type=p_subject_type and subject_id=p_subject_id and status in('trialing','active','past_due','incomplete','unpaid','paused')) then raise exception 'SUBSCRIPTION_EXISTS_USE_PORTAL';end if;
 if kombax_commercial.active_plan_r64(p_subject_type,p_subject_id) is not null then raise exception 'EXISTING_SERVICE_USE_SUPPORT';end if;
 select * into req from kombax_billing.requests where subject_type=p_subject_type and subject_id=p_subject_id and status='pending' order by created_at desc limit 1;
 if found and (req.actor_id<>auth.uid() or req.plan_code<>p_plan_code) then raise exception 'CHECKOUT_ALREADY_PENDING';end if;
 if not found then
  days:=case when exists(select 1 from kombax_commercial.space_trials_r118 where subject_type=p_subject_type and subject_id=p_subject_id) or exists(select 1 from kombax_billing.subscriptions where subject_type=p_subject_type and subject_id=p_subject_id) then 0 else 30 end;
  insert into kombax_billing.requests(actor_id,subject_type,subject_id,plan_code,trial_days,terms_version) values(auth.uid(),p_subject_type,p_subject_id,p_plan_code,days,plan.terms_version) returning * into req;
 end if;
 return jsonb_build_object('request_id',req.id,'price_id',plan.stripe_price_id,'amount_minor',plan.amount_minor,'currency',plan.currency,'livemode',plan.livemode,'trial_days',req.trial_days,'session_id',req.stripe_session_id,'expires_at',req.expires_at);
end $$;

create function public.app_kombax_billing_session_internal_r118(p_request_id uuid,p_session_id text) returns void language plpgsql security definer set search_path='' as $$
begin
 if p_session_id !~ '^cs_[A-Za-z0-9_]+$' then raise exception 'INVALID_SESSION';end if;
 update kombax_billing.requests set stripe_session_id=p_session_id where id=p_request_id and (stripe_session_id is null or stripe_session_id=p_session_id);
 if not found then raise exception 'CHECKOUT_REQUEST_NOT_FOUND';end if;
end $$;

create function public.app_kombax_billing_portal_r118(p_subject_type text,p_subject_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare gate jsonb;sub kombax_billing.subscriptions;
begin
 select * into sub from kombax_billing.subscriptions where subject_type=p_subject_type and subject_id=p_subject_id;
 begin gate:=kombax_billing.subject(auth.uid(),p_subject_type,p_subject_id);exception when insufficient_privilege then if sub.actor_id is distinct from auth.uid() or auth.uid() is null then raise;end if;gate:=jsonb_build_object('pilot',false);end;
 if (gate->>'pilot')::boolean then raise exception 'PILOT_BILLING_EXCLUDED';end if;
 select * into sub from kombax_billing.subscriptions where subject_type=p_subject_type and subject_id=p_subject_id;
 if not found then raise exception 'SUBSCRIPTION_NOT_FOUND';end if;
 return jsonb_build_object('customer_id',sub.customer_id);
end $$;

create function public.app_kombax_billing_sync_internal_r118(p_request_id uuid,p_subscription jsonb,p_event_id text,p_event_type text,p_sync_at timestamptz) returns jsonb language plpgsql security definer set search_path='' as $$
declare req kombax_billing.requests;plan kombax_billing.plans;prior kombax_billing.subscriptions;status text;period_end timestamptz;trial_start timestamptz;trial_end timestamptz;start_at timestamptz;local_id uuid;public_before boolean;enabled boolean;gate jsonb;
begin
 select * into req from kombax_billing.requests where id=p_request_id;
 if not found then raise exception 'UNKNOWN_BILLING_REQUEST';end if;
 perform pg_advisory_xact_lock(hashtextextended(req.subject_type||':'||req.subject_id::text,0));
 select * into plan from kombax_billing.plans where code=req.plan_code;
 if p_subscription->>'id' !~ '^sub_[A-Za-z0-9]+$' or p_subscription->>'customer' !~ '^cus_[A-Za-z0-9]+$' or p_subscription#>>'{items,data,0,price,id}' is distinct from plan.stripe_price_id or (p_subscription->>'livemode')::boolean is distinct from plan.livemode then raise exception 'SUBSCRIPTION_MISMATCH';end if;
 if exists(select 1 from kombax_billing.events where id=p_event_id) then return jsonb_build_object('ok',true,'duplicate',true);end if;
 select * into prior from kombax_billing.subscriptions where subject_type=req.subject_type and subject_id=req.subject_id for update;
 if prior.subject_id is not null and prior.stripe_subscription_id<>p_subscription->>'id' and prior.status not in('canceled','incomplete_expired') then raise exception 'SUBSCRIPTION_ALREADY_BOUND';end if;
 if prior.subject_id is not null and prior.sync_at>p_sync_at then return jsonb_build_object('ok',true,'stale',true);end if;
 status:=p_subscription->>'status';
 if status not in('trialing','active','past_due','canceled','unpaid','incomplete','incomplete_expired','paused') then raise exception 'INVALID_SUBSCRIPTION_STATUS';end if;
 period_end:=to_timestamp(coalesce(nullif(p_subscription->>'current_period_end','')::numeric,nullif(p_subscription#>>'{items,data,0,current_period_end}','')::numeric));
 trial_start:=to_timestamp(nullif(p_subscription->>'trial_start','')::numeric);trial_end:=to_timestamp(nullif(p_subscription->>'trial_end','')::numeric);
 start_at:=coalesce(trial_start,to_timestamp(nullif(p_subscription->>'start_date','')::numeric),now());
 enabled:=status in('trialing','active') and (status<>'active' or p_subscription#>>'{latest_invoice,status}'='paid') and period_end>now() and (status<>'trialing' or (trial_end>now() and nullif(p_subscription->>'default_payment_method','') is not null));
 begin gate:=kombax_billing.subject(req.actor_id,req.subject_type,req.subject_id);exception when insufficient_privilege then gate:=jsonb_build_object('verified',false,'pilot',false);end;
 enabled:=enabled and (gate->>'verified')::boolean and not (gate->>'pilot')::boolean;
 local_id:=coalesce(prior.local_id,gen_random_uuid());
 insert into kombax_billing.subscriptions(subject_type,subject_id,stripe_subscription_id,customer_id,actor_id,plan_code,local_id,status,trial_start,trial_end,period_end,cancel_at_period_end,sync_at,last_event_id)
 values(req.subject_type,req.subject_id,p_subscription->>'id',p_subscription->>'customer',req.actor_id,req.plan_code,local_id,status,trial_start,trial_end,period_end,coalesce((p_subscription->>'cancel_at_period_end')::boolean,false),p_sync_at,p_event_id)
 on conflict(subject_type,subject_id) do update set stripe_subscription_id=excluded.stripe_subscription_id,customer_id=excluded.customer_id,actor_id=excluded.actor_id,plan_code=excluded.plan_code,status=excluded.status,trial_start=excluded.trial_start,trial_end=excluded.trial_end,period_end=excluded.period_end,cancel_at_period_end=excluded.cancel_at_period_end,sync_at=excluded.sync_at,last_event_id=excluded.last_event_id;
 if trial_start is not null and trial_end>trial_start then
  insert into kombax_commercial.space_trials_r118(subject_type,subject_id,started_at,ends_at,created_by) values(req.subject_type,req.subject_id,trial_start,trial_end,req.actor_id) on conflict do nothing;
 end if;
 insert into public.kombax_suscripciones(id,sujeto_tipo,sujeto_id,estado,modalidad,proveedor,referencia_externa,inicia_en,termina_en)
 values(local_id,case when req.subject_type='direct_profile' then 'perfil_directo' else 'club' end,req.subject_id,case when enabled then case when status='trialing' then 'prueba' else 'activa' end when status in('canceled','incomplete_expired') then 'cancelada' else 'pausada' end,req.plan_code,'stripe_billing_r118',p_subscription->>'id',start_at,case when enabled then least(period_end,case when status='trialing' then trial_end else period_end end) else null end)
 on conflict(id) do update set estado=excluded.estado,modalidad=excluded.modalidad,referencia_externa=excluded.referencia_externa,inicia_en=excluded.inicia_en,termina_en=excluded.termina_en,actualizado_en=now();
 if req.subject_type='direct_profile' then
  select publico into public_before from public.perfiles_kombax_directos where id=req.subject_id;
  perform public.app_kombax_reconcile_entitlements_v071(req.subject_id,req.actor_id);
  update public.perfiles_kombax_directos set publico=public_before where id=req.subject_id;
  update public.kombax_entitlements set termina_en=least(period_end,case when status='trialing' then trial_end else period_end end) where sujeto_tipo='perfil_directo' and sujeto_id=req.subject_id and origen='suscripcion' and activa;
 end if;
 update kombax_billing.requests set status='completed' where id=req.id;
 insert into kombax_billing.events(id,type) values(p_event_id,p_event_type);
 if p_event_type in('customer.subscription.trial_will_end','invoice.payment_failed','invoice.payment_action_required','customer.subscription.deleted') then
  insert into public.notificaciones(club_id,perfil_id,subject_type,subject_id,tipo,titulo,cuerpo,ruta,datos)
  values(case when req.subject_type='club' then req.subject_id end,req.actor_id,case when req.subject_type='direct_profile' then 'direct_profile' end,case when req.subject_type='direct_profile' then req.subject_id end,'sistema','Suscripción KOMBAX',case p_event_type when 'customer.subscription.trial_will_end' then 'Tu prueba termina pronto. Revisa el precio y la fecha de renovación o cancela desde Mis servicios.' when 'customer.subscription.deleted' then 'Tu suscripción ha finalizado. Tu perfil público se conserva.' else 'Tu pago requiere atención. Actualiza el método de pago desde Mis servicios.' end,'workspace',jsonb_build_object('billing',true,'event',p_event_type));
 end if;
 return jsonb_build_object('ok',true,'status',status,'services_enabled',enabled);
end $$;

create function public.app_kombax_billing_expire_internal_r118(p_request_id uuid) returns void language sql security definer set search_path='' as $$
 update kombax_billing.requests set status='expired' where id=p_request_id and status='pending';
$$;
revoke all on function public.app_kombax_billing_expire_internal_r118(uuid) from public,anon,authenticated;
grant execute on function public.app_kombax_billing_expire_internal_r118(uuid) to service_role;

-- Preserve existing pilot/legacy trials but prevent new cardless commercial activation.
alter function public.app_kombax_space_trial_r118(text,uuid,boolean) rename to app_kombax_space_trial_legacy_r118;
revoke all on function public.app_kombax_space_trial_legacy_r118(text,uuid,boolean) from public,anon,authenticated;
create function public.app_kombax_space_trial_r118(p_subject_type text,p_subject_id uuid,p_activate boolean default false) returns jsonb language plpgsql security definer set search_path='' as $$
declare gate jsonb;result jsonb;
begin
 gate:=kombax_billing.subject(auth.uid(),p_subject_type,p_subject_id);
 if (gate->>'pilot')::boolean then return jsonb_build_object('ok',true,'status','pilot','activation_allowed',false);end if;
 if coalesce(p_activate,false) then raise exception 'STRIPE_CHECKOUT_REQUIRED';end if;
 if gate->>'audience' in('club','federation') then result:=public.app_kombax_space_trial_legacy_r118(p_subject_type,p_subject_id,false);else result:=jsonb_build_object('ok',true,'status','available');end if;
 return result||jsonb_build_object('activation_allowed',false,'checkout_required',true,'verified',(gate->>'verified')::boolean);
end $$;
revoke all on all functions in schema kombax_billing from public,anon,authenticated;
revoke all on function public.app_kombax_billing_context_r118(text,uuid),public.app_kombax_billing_prepare_r118(text,uuid,text,text,boolean),public.app_kombax_billing_portal_r118(text,uuid),public.app_kombax_space_trial_r118(text,uuid,boolean) from public,anon;
grant execute on function public.app_kombax_billing_context_r118(text,uuid),public.app_kombax_billing_prepare_r118(text,uuid,text,text,boolean),public.app_kombax_billing_portal_r118(text,uuid),public.app_kombax_space_trial_r118(text,uuid,boolean) to authenticated;
revoke all on function public.app_kombax_billing_session_internal_r118(uuid,text),public.app_kombax_billing_sync_internal_r118(uuid,jsonb,text,text,timestamptz) from public,anon,authenticated;
grant execute on function public.app_kombax_billing_session_internal_r118(uuid,text),public.app_kombax_billing_sync_internal_r118(uuid,jsonb,text,text,timestamptz) to service_role;
commit;
