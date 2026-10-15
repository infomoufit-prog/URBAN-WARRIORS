create table kombax_ai_ops.usage_help_turns_r274(
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 request_id uuid not null, question_hash text not null, period_start date not null,
 status text not null check(status in ('RESERVED','COMPLETED','FAILED')),
 reserved_at timestamptz not null default now(),completed_at timestamptz,
 input_tokens integer not null default 0 check(input_tokens>=0),output_tokens integer not null default 0 check(output_tokens>=0),
 answer text, unique(user_id,request_id)
);
alter table kombax_ai_ops.usage_help_turns_r274 enable row level security;
revoke all on kombax_ai_ops.usage_help_turns_r274 from public,anon,authenticated;
create index usage_help_period_r274 on kombax_ai_ops.usage_help_turns_r274(period_start,status);
create index usage_help_user_period_r274 on kombax_ai_ops.usage_help_turns_r274(user_id,period_start);

create function public.app_usage_help_status_r274() returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_month date:=date_trunc('month',now() at time zone 'Europe/Madrid')::date;v_used integer;
begin
 if v_uid is null then raise exception 'authentication_required' using errcode='42501';end if;
 select count(*) into v_used from kombax_ai_ops.usage_help_turns_r274 where user_id=v_uid and period_start=v_month
 and (status='COMPLETED' or (status='RESERVED' and reserved_at>now()-interval '10 minutes'));
 return jsonb_build_object('remaining',greatest(0,5-v_used),'limit',5);
end $$;

create function public.app_usage_help_reserve_r274(p_request_id uuid,p_question text) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_month date:=date_trunc('month',now() at time zone 'Europe/Madrid')::date;
 v_prior kombax_ai_ops.usage_help_turns_r274%rowtype;v_used integer;v_total bigint;v_id uuid;
begin
 if v_uid is null then raise exception 'authentication_required' using errcode='42501';end if;
 if p_request_id is null or length(btrim(coalesce(p_question,''))) not between 1 and 1500 then raise exception 'invalid_request';end if;
 perform pg_advisory_xact_lock(hashtextextended('usage-user:'||v_uid::text,0));
 select * into v_prior from kombax_ai_ops.usage_help_turns_r274 where user_id=v_uid and request_id=p_request_id;
 if found then
  if v_prior.question_hash<>md5(p_question) then return jsonb_build_object('ok',false,'reason','request_conflict');end if;
  return jsonb_build_object('ok',v_prior.status='COMPLETED','reused',true,'answer',case when v_prior.status='COMPLETED' then v_prior.answer end,'reason',case when v_prior.status='RESERVED' then 'in_progress' else 'retry_new_request' end);
 end if;
 select count(*) into v_used from kombax_ai_ops.usage_help_turns_r274 where user_id=v_uid and period_start=v_month
 and (status='COMPLETED' or (status='RESERVED' and reserved_at>now()-interval '10 minutes'));
 if v_used>=5 then return jsonb_build_object('ok',false,'reason','monthly_limit');end if;
 perform pg_advisory_xact_lock(hashtextextended('usage-global:'||v_month::text,0));
 select coalesce(sum(case when status='COMPLETED' then input_tokens+output_tokens else 20000 end),0) into v_total
 from kombax_ai_ops.usage_help_turns_r274 where period_start=v_month
 ;
 if v_total+20000>2000000 then return jsonb_build_object('ok',false,'reason','platform_limit');end if;
 insert into kombax_ai_ops.usage_help_turns_r274(user_id,request_id,question_hash,period_start,status)
 values(v_uid,p_request_id,md5(p_question),v_month,'RESERVED') returning id into v_id;
 return jsonb_build_object('ok',true,'turn_id',v_id);
end $$;

create function public.app_usage_help_finish_r274(p_turn_id uuid,p_answer text,p_input_tokens integer,p_output_tokens integer,p_success boolean)
returns boolean language plpgsql security definer set search_path='' as $$
begin
 if p_success and (length(btrim(coalesce(p_answer,'')))=0 or length(p_answer)>12000 or p_input_tokens is null or p_output_tokens is null or p_input_tokens<0 or p_output_tokens<0) then raise exception 'invalid_measurement';end if;
 update kombax_ai_ops.usage_help_turns_r274 set status=case when p_success then 'COMPLETED' else 'FAILED' end,
 answer=case when p_success then p_answer end,input_tokens=case when p_success then p_input_tokens else 0 end,
 output_tokens=case when p_success then p_output_tokens else 0 end,completed_at=now()
 where id=p_turn_id and status='RESERVED';return found;
end $$;

revoke all on function public.app_usage_help_status_r274(),public.app_usage_help_reserve_r274(uuid,text),public.app_usage_help_finish_r274(uuid,text,integer,integer,boolean) from public,anon,authenticated;
grant execute on function public.app_usage_help_status_r274(),public.app_usage_help_reserve_r274(uuid,text) to authenticated;
grant execute on function public.app_usage_help_finish_r274(uuid,text,integer,integer,boolean) to service_role;

-- Resolve the active audience on the server. Caller-supplied role/type/plan are never trusted.
create function public.app_usage_help_audience_r274(p_tenant_ref text default null,p_ticket_id text default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_ref text:=btrim(coalesce(p_tenant_ref,''));v_id uuid;v_type text;v_role text;v_verified boolean:=false;v_paid boolean:=false;v_premium boolean:=false;v_out jsonb;
begin
 if v_uid is null then raise exception 'authentication_required' using errcode='42501';end if;
 v_out:=jsonb_build_object('kind','public','userId',v_uid,'paid',false,'premium',false,'verified',false);
 if nullif(p_ticket_id,'') is not null then
  select tenant_ref into v_ref from kombax_customer_ops.tickets where ticket_id=p_ticket_id and user_ref=v_uid and category='MANAGEMENT';
  if not found then return v_out;end if;
 end if;
 if v_ref='' then return v_out;end if;
 begin v_id:=split_part(v_ref,':',2)::uuid;exception when invalid_text_representation then return v_out;end;
 if v_ref like 'club:%' then
  select mc.rol::text into v_role from public.miembros_club mc join public.clubes c on c.id=mc.club_id and c.activo
   where mc.club_id=v_id and mc.perfil_id=v_uid and mc.activo limit 1;
  if not found then return v_out;end if;
  v_type:='club';v_verified:=true;
 elsif v_ref like 'profile:%' then
  select d.tipo,(d.verificado_en is not null) into v_type,v_verified from public.perfiles_kombax_directos d
   where d.id=v_id and d.estado not in ('suspendido','cerrado') and
   (d.perfil_id=v_uid or kombax_ai_ops.org_assist_access_allowed(v_uid,v_ref));
  if not found then return v_out;end if;
  v_role:='todos';
 else return v_out;end if;
 v_paid:=coalesce((public.app_kombax_usage_help_access_r272(v_ref,null)->>'ai_allowed')::boolean,false);
 if v_paid then
  select exists(select 1 from kombax_commercial.pilot_entities_r97 where tenant_ref=v_ref and kombax_commercial.program_phase_r97()<>'PREPARATION')
   or exists(select 1 from public.kombax_suscripciones s where s.sujeto_id=v_id and s.sujeto_tipo=case when v_type='club' then 'club' else 'perfil_directo' end
    and s.estado in ('activa','prueba') and s.modalidad::text in ('premium','enterprise','club_premium','brand_growth','brand_enterprise','federacion_institucional')
    and (s.inicia_en is null or s.inicia_en<=now()) and (s.termina_en is null or s.termina_en>now())) into v_premium;
 end if;
 return jsonb_build_object('kind',case when v_type='club' then 'club' else 'profile' end,'type',v_type,'role',v_role,'userId',v_uid,'paid',v_paid,'premium',v_premium,'verified',v_verified);
end $$;
revoke all on function public.app_usage_help_audience_r274(text,text) from public,anon;
grant execute on function public.app_usage_help_audience_r274(text,text) to authenticated;
