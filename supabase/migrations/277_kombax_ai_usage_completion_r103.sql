-- R103: one Responses API usage record and one conversion path for every completed turn.
begin;
alter table kombax_ai_ops.ai_usage_runs_r103
  add column if not exists image_inputs integer not null default 0 check(image_inputs>=0),
  add column if not exists file_inputs integer not null default 0 check(file_inputs>=0);

create or replace function public.app_kombax_ai_turn_result_r103(p_turn_id uuid,p_user_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_turn kombax_ai_ops.assistance_turns%rowtype;v_text text;
begin
 select * into v_turn from kombax_ai_ops.assistance_turns where turn_id=p_turn_id and user_ref=p_user_id;
 if not found then return jsonb_build_object('status','NOT_FOUND'); end if;
 if v_turn.status='COMPLETED' then
  select content_text into v_text from kombax_customer_ops.assist_chat_messages
  where turn_id=p_turn_id and role='ASSISTANT' order by created_at desc limit 1;
 end if;
 return jsonb_build_object('status',v_turn.status,'message',v_text,'ticket_id',v_turn.ticket_id);
end $$;
revoke all on function public.app_kombax_ai_turn_result_r103(uuid,uuid) from public,anon,authenticated;
grant execute on function public.app_kombax_ai_turn_result_r103(uuid,uuid) to service_role;

create or replace function public.app_kombax_assist_turn_complete_v103(
 p_turn_id uuid,p_assistant_text text,p_model_alias text,p_usage jsonb,p_response_id text,
 p_tool_calls jsonb default '[]'::jsonb,p_file_analysis jsonb default '[]'::jsonb,
 p_image_inputs integer default 0,p_file_inputs integer default 0,p_usage_source text default 'OPENAI_RESPONSE')
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_turn kombax_ai_ops.assistance_turns%rowtype;v_meter jsonb;v_item jsonb;
 v_file uuid;v_summary text;v_preview jsonb;v_records integer;v_run_id text;
begin
 select * into v_turn from kombax_ai_ops.assistance_turns t where t.turn_id=p_turn_id for update;
 if not found or v_turn.status<>'RESERVED' then raise exception 'turn_not_reserved'; end if;
 if p_response_id is null or length(btrim(p_response_id))<5 then raise exception 'response_id_required'; end if;
 v_meter:=kombax_ai_ops.ai_usage_to_credits_r103(p_model_alias,p_usage,p_tool_calls);
 v_run_id:=left(p_response_id,200);
 insert into kombax_ai_ops.ai_usage_runs_r103(
  run_id,turn_id,tenant_ref,user_ref,conversation_id,agent,model_alias,
  input_tokens,cached_input_tokens,cache_write_tokens,output_tokens,reasoning_tokens,image_input_tokens,
  image_inputs,file_inputs,tool_calls,total_tokens,api_cost_usd,api_cost_eur,charged_credits,usage_source)
 values(v_run_id,p_turn_id,v_turn.tenant_ref,v_turn.user_ref,v_turn.ticket_id,
  case when v_turn.category='MIGRATION' then 'Migrations'
       when v_turn.category='MANAGEMENT' then 'Assist' else 'Guided Support' end,p_model_alias,
  (v_meter->>'input_tokens')::integer,(v_meter->>'cached_input_tokens')::integer,
  (v_meter->>'cache_write_tokens')::integer,(v_meter->>'output_tokens')::integer,
  (v_meter->>'reasoning_tokens')::integer,(v_meter->>'image_input_tokens')::integer,
  greatest(0,coalesce(p_image_inputs,0)),greatest(0,coalesce(p_file_inputs,0)),
  coalesce(p_tool_calls,'[]'::jsonb),(v_meter->>'total_tokens')::integer,
  (v_meter->>'api_cost_usd')::numeric,(v_meter->>'api_cost_eur')::numeric,
  (v_meter->>'credits')::numeric,p_usage_source);
 update kombax_ai_ops.assistance_turns set status='COMPLETED',model_alias=p_model_alias,
  input_tokens=(v_meter->>'input_tokens')::integer,output_tokens=(v_meter->>'output_tokens')::integer,
  estimated_cost=(v_meter->>'api_cost_eur')::numeric,completed_at=now() where turn_id=p_turn_id;
 insert into kombax_customer_ops.assist_chat_messages(ticket_id,user_ref,turn_id,role,content_text)
 values(v_turn.ticket_id,v_turn.user_ref,p_turn_id,'ASSISTANT',
  left(coalesce(nullif(btrim(p_assistant_text),''),'He procesado la solicitud.'),12000));
 if jsonb_typeof(p_file_analysis)='array' then
  for v_item in select value from jsonb_array_elements(p_file_analysis) loop
   begin v_file:=(v_item->>'file_id')::uuid; exception when others then v_file:=null; end;
   if v_file is not null and exists(select 1 from kombax_customer_ops.migration_files f
      where f.file_id=v_file and f.ticket_id=v_turn.ticket_id and f.user_ref=v_turn.user_ref) then
    v_summary:=left(coalesce(v_item->>'summary','Archivo analizado'),4000);
    v_preview:=coalesce(v_item->'preview','{}'::jsonb);
    v_records:=greatest(0,coalesce((v_item->>'detected_records')::integer,0));
    insert into kombax_customer_ops.migration_file_analysis(file_id,ticket_id,user_ref,turn_id,summary,
      structured_preview,detected_records,confidence,needs_review,analyzed_at)
    values(v_file,v_turn.ticket_id,v_turn.user_ref,p_turn_id,v_summary,v_preview,v_records,
      least(1,greatest(0,coalesce((v_item->>'confidence')::numeric,0.7))),
      coalesce((v_item->>'needs_review')::boolean,true),now())
    on conflict(file_id) do update set turn_id=excluded.turn_id,summary=excluded.summary,
      structured_preview=excluded.structured_preview,detected_records=excluded.detected_records,
      confidence=excluded.confidence,needs_review=excluded.needs_review,analyzed_at=now();
    update kombax_customer_ops.migration_files
      set status=case when coalesce((v_item->>'needs_review')::boolean,true)
        then 'NEEDS_REVIEW' else 'READY_CONFIRM' end,updated_at=now() where file_id=v_file;
   end if;
  end loop;
 end if;
 update kombax_ai_ops.assistance_cases c
 set input_tokens=c.input_tokens+(v_meter->>'input_tokens')::integer,
     output_tokens=c.output_tokens+(v_meter->>'output_tokens')::integer,
     estimated_cost=c.estimated_cost+(v_meter->>'api_cost_eur')::numeric,
     model_alias=coalesce(c.model_alias,p_model_alias) where c.ticket_id=v_turn.ticket_id;
 insert into kombax_customer_ops.support_metrics_daily(metric_date,tenant_ref,input_tokens,output_tokens,estimated_cost)
 values(current_date,v_turn.tenant_ref,(v_meter->>'input_tokens')::integer,
  (v_meter->>'output_tokens')::integer,(v_meter->>'api_cost_eur')::numeric)
 on conflict(metric_date,tenant_ref) do update
 set input_tokens=kombax_customer_ops.support_metrics_daily.input_tokens+excluded.input_tokens,
     output_tokens=kombax_customer_ops.support_metrics_daily.output_tokens+excluded.output_tokens,
     estimated_cost=kombax_customer_ops.support_metrics_daily.estimated_cost+excluded.estimated_cost;
 update kombax_customer_ops.tickets set updated_at=now(),
  status=case when v_turn.category='MIGRATION' then 'WAITING_USER' else 'GUIDED_SESSION' end
 where ticket_id=v_turn.ticket_id;
 return jsonb_build_object('ok',true,'turn_id',p_turn_id);
end $$;
revoke all on function public.app_kombax_assist_turn_complete_v103(uuid,text,text,jsonb,text,jsonb,jsonb,integer,integer,text)
  from public,anon,authenticated;
grant execute on function public.app_kombax_assist_turn_complete_v103(uuid,text,text,jsonb,text,jsonb,jsonb,integer,integer,text)
  to service_role;

-- Legacy callers retain the signature, but never implement another pricing formula.
create or replace function public.app_kombax_assist_turn_complete_v227(
 p_turn_id uuid,p_assistant_text text,p_model_alias text,p_input_tokens integer,p_output_tokens integer,
 p_file_analysis jsonb default '[]'::jsonb)
returns jsonb language sql volatile security definer set search_path='' as $$
 select public.app_kombax_assist_turn_complete_v103(p_turn_id,p_assistant_text,p_model_alias,
  jsonb_build_object('input_tokens',greatest(0,coalesce(p_input_tokens,0)),
    'output_tokens',greatest(0,coalesce(p_output_tokens,0))),
  'legacy:'||p_turn_id::text,'[]'::jsonb,p_file_analysis,0,0,'LEGACY_COUNTS');
$$;
revoke all on function public.app_kombax_assist_turn_complete_v227(uuid,text,text,integer,integer,jsonb)
  from public,anon,authenticated;
grant execute on function public.app_kombax_assist_turn_complete_v227(uuid,text,text,integer,integer,jsonb)
  to service_role;
commit;
