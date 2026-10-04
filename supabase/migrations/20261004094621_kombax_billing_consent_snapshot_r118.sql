begin;
alter table kombax_billing.requests add column price_id text,add column amount_minor integer,add column currency text,add column livemode boolean;
update kombax_billing.requests r set price_id=p.stripe_price_id,amount_minor=p.amount_minor,currency=p.currency,livemode=p.livemode from kombax_billing.plans p where p.code=r.plan_code;
alter table kombax_billing.requests alter column price_id set not null,alter column amount_minor set not null,alter column currency set not null,alter column livemode set not null;
create or replace function public.app_kombax_billing_prepare_r118(p_subject_type text,p_subject_id uuid,p_plan_code text,p_terms_version text,p_consent boolean) returns jsonb language plpgsql security definer set search_path='' as $$
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
  insert into kombax_billing.requests(actor_id,subject_type,subject_id,plan_code,trial_days,terms_version,price_id,amount_minor,currency,livemode) values(auth.uid(),p_subject_type,p_subject_id,p_plan_code,days,plan.terms_version,plan.stripe_price_id,plan.amount_minor,plan.currency,plan.livemode) returning * into req;
 end if;
 return jsonb_build_object('request_id',req.id,'price_id',req.price_id,'amount_minor',req.amount_minor,'currency',req.currency,'livemode',req.livemode,'trial_days',req.trial_days,'session_id',req.stripe_session_id,'expires_at',req.expires_at);
end $$;
create or replace function public.app_kombax_billing_sync_internal_r118(p_request_id uuid,p_subscription jsonb,p_event_id text,p_event_type text,p_sync_at timestamptz) returns jsonb language plpgsql security definer set search_path='' as $$
declare req kombax_billing.requests;plan kombax_billing.plans;prior kombax_billing.subscriptions;status text;period_end timestamptz;trial_start timestamptz;trial_end timestamptz;start_at timestamptz;local_id uuid;public_before boolean;enabled boolean;gate jsonb;
begin
 select * into req from kombax_billing.requests where id=p_request_id;
 if not found then raise exception 'UNKNOWN_BILLING_REQUEST';end if;
 perform pg_advisory_xact_lock(hashtextextended(req.subject_type||':'||req.subject_id::text,0));
 select * into plan from kombax_billing.plans where code=req.plan_code;
 if p_subscription->>'id' !~ '^sub_[A-Za-z0-9]+$' or p_subscription->>'customer' !~ '^cus_[A-Za-z0-9]+$' or p_subscription#>>'{items,data,0,price,id}' is distinct from req.price_id or (p_subscription->>'livemode')::boolean is distinct from req.livemode then raise exception 'SUBSCRIPTION_MISMATCH';end if;
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
create function public.app_kombax_billing_mine_r118() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';end if;
 return coalesce((select jsonb_agg(jsonb_build_object('subject_type',s.subject_type,'subject_id',s.subject_id,'plan_code',s.plan_code,'status',s.status,'trial_end',s.trial_end,'period_end',s.period_end,'cancel_at_period_end',s.cancel_at_period_end) order by s.sync_at desc) from kombax_billing.subscriptions s where s.actor_id=auth.uid()),'[]'::jsonb);
end $$;
revoke all on function public.app_kombax_billing_mine_r118() from public,anon;
grant execute on function public.app_kombax_billing_mine_r118() to authenticated;
commit;
