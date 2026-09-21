-- KOMBAX 20.101 R38 · Service-only AI context, ledger completion and cached extraction
create or replace function public.app_kombax_assist_turn_internal_v227(p_turn_id uuid)
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare v_turn kombax_ai_ops.assistance_turns%rowtype;v_ctx record;v_policy kombax_ai_ops.assistance_cost_policies%rowtype;v_messages jsonb;v_files jsonb;v_file_count integer;v_visual integer;v_bytes bigint;
begin
  select * into v_turn from kombax_ai_ops.assistance_turns t where t.turn_id=p_turn_id and t.status='RESERVED'; if not found then raise exception 'turn_not_reserved' using errcode='P0002'; end if;
  select * into v_ctx from kombax_ai_ops.resolve_context(v_turn.user_ref,v_turn.tenant_ref); select * into strict v_policy from kombax_ai_ops.assistance_cost_policies p where p.plan=v_ctx.plan;
  select coalesce(jsonb_agg(jsonb_build_object('turn_id',m.turn_id,'role',lower(m.role),'content',left(m.content_text,4000)) order by m.created_at),'[]'::jsonb) into v_messages
  from (select * from kombax_customer_ops.assist_chat_messages m where m.ticket_id=v_turn.ticket_id order by m.created_at desc limit 10) m;
  if v_turn.category='MIGRATION' then
    select coalesce(jsonb_agg(jsonb_build_object('file_id',x.file_id,'original_name',x.original_name,'mime_type',x.mime_type,'size_bytes',x.size_bytes,'storage_path',x.storage_path) order by x.created_at),'[]'::jsonb),count(*),count(*) filter(where x.mime_type like 'image/%'),coalesce(sum(x.size_bytes),0)
      into v_files,v_file_count,v_visual,v_bytes
    from (select f.* from kombax_customer_ops.migration_files f left join kombax_customer_ops.migration_file_analysis a on a.file_id=f.file_id
          where f.ticket_id=v_turn.ticket_id and f.user_ref=v_turn.user_ref and a.file_id is null and f.status in('STAGED','FAILED')
          order by f.created_at limit v_policy.max_files_per_batch) x;
  else v_files:='[]'::jsonb;v_file_count:=0;v_visual:=0;v_bytes:=0; end if;
  if v_visual>v_policy.max_visual_files_per_batch then
    select coalesce(jsonb_agg(z.item order by z.ord),'[]'::jsonb) into v_files from (select value item,ord from jsonb_array_elements(v_files) with ordinality a(value,ord) where ord<=v_policy.max_visual_files_per_batch) z;
    v_file_count:=jsonb_array_length(v_files);v_visual:=v_file_count;
  end if;
  if v_bytes::numeric/1048576>v_policy.max_batch_mb then
    select coalesce(jsonb_agg(z.item order by z.ord),'[]'::jsonb) into v_files from (select value item,ord,sum(coalesce((value->>'size_bytes')::bigint,0)) over(order by ord) running from jsonb_array_elements(v_files) with ordinality a(value,ord)) z where z.running<=v_policy.max_batch_mb*1048576;
    v_file_count:=jsonb_array_length(v_files);v_visual:=(select count(*) from jsonb_array_elements(v_files) e where e->>'mime_type' like 'image/%');
  end if;
  update kombax_ai_ops.assistance_turns set file_count=v_file_count,visual_file_count=v_visual where turn_id=p_turn_id;
  return jsonb_build_object('turn_id',v_turn.turn_id,'ticket_id',v_turn.ticket_id,'category',v_turn.category,'model_alias',v_policy.default_model,'max_output_tokens',v_policy.max_output_tokens,'image_detail',v_policy.image_detail,'messages',v_messages,'files',v_files);
end $$;

create or replace function public.app_kombax_assist_turn_complete_v227(p_turn_id uuid,p_assistant_text text,p_model_alias text,p_input_tokens integer,p_output_tokens integer,p_file_analysis jsonb default '[]'::jsonb)
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare v_turn kombax_ai_ops.assistance_turns%rowtype;v_rate kombax_ai_ops.model_cost_rates%rowtype;v_cost numeric(14,6);v_item jsonb;v_file uuid;v_summary text;v_preview jsonb;v_records integer;
begin
  select * into v_turn from kombax_ai_ops.assistance_turns t where t.turn_id=p_turn_id for update; if not found or v_turn.status<>'RESERVED' then raise exception 'turn_not_reserved'; end if;
  select * into strict v_rate from kombax_ai_ops.model_cost_rates r where r.model_alias=p_model_alias and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now());
  v_cost:=round((greatest(0,coalesce(p_input_tokens,0))::numeric*v_rate.input_per_million + greatest(0,coalesce(p_output_tokens,0))::numeric*v_rate.output_per_million)/1000000,6);
  update kombax_ai_ops.assistance_turns set status='COMPLETED',model_alias=p_model_alias,input_tokens=greatest(0,coalesce(p_input_tokens,0)),output_tokens=greatest(0,coalesce(p_output_tokens,0)),estimated_cost=v_cost,completed_at=now() where turn_id=p_turn_id;
  insert into kombax_customer_ops.assist_chat_messages(ticket_id,user_ref,turn_id,role,content_text) values(v_turn.ticket_id,v_turn.user_ref,p_turn_id,'ASSISTANT',left(coalesce(nullif(btrim(p_assistant_text),''),'He procesado la solicitud.'),12000));
  if jsonb_typeof(p_file_analysis)='array' then
    for v_item in select value from jsonb_array_elements(p_file_analysis) loop
      begin v_file:=(v_item->>'file_id')::uuid; exception when others then v_file:=null; end;
      if v_file is not null and exists(select 1 from kombax_customer_ops.migration_files f where f.file_id=v_file and f.ticket_id=v_turn.ticket_id and f.user_ref=v_turn.user_ref) then
        v_summary:=left(coalesce(v_item->>'summary','Archivo analizado'),4000);v_preview:=coalesce(v_item->'preview','{}'::jsonb);v_records:=greatest(0,coalesce((v_item->>'detected_records')::integer,0));
        insert into kombax_customer_ops.migration_file_analysis(file_id,ticket_id,user_ref,turn_id,summary,structured_preview,detected_records,confidence,needs_review,analyzed_at)
        values(v_file,v_turn.ticket_id,v_turn.user_ref,p_turn_id,v_summary,v_preview,v_records,least(1,greatest(0,coalesce((v_item->>'confidence')::numeric,0.7))),coalesce((v_item->>'needs_review')::boolean,true),now())
        on conflict(file_id) do update set turn_id=excluded.turn_id,summary=excluded.summary,structured_preview=excluded.structured_preview,detected_records=excluded.detected_records,confidence=excluded.confidence,needs_review=excluded.needs_review,analyzed_at=now();
        update kombax_customer_ops.migration_files set status=case when coalesce((v_item->>'needs_review')::boolean,true) then 'NEEDS_REVIEW' else 'READY_CONFIRM' end,updated_at=now() where file_id=v_file;
      end if;
    end loop;
  end if;
  update kombax_ai_ops.assistance_cases c set input_tokens=c.input_tokens+greatest(0,coalesce(p_input_tokens,0)),output_tokens=c.output_tokens+greatest(0,coalesce(p_output_tokens,0)),estimated_cost=c.estimated_cost+v_cost,model_alias=coalesce(c.model_alias,p_model_alias) where c.ticket_id=v_turn.ticket_id;
  insert into kombax_customer_ops.support_metrics_daily(metric_date,tenant_ref,input_tokens,output_tokens,estimated_cost)
  values(current_date,v_turn.tenant_ref,greatest(0,coalesce(p_input_tokens,0)),greatest(0,coalesce(p_output_tokens,0)),v_cost)
  on conflict(metric_date,tenant_ref) do update set input_tokens=kombax_customer_ops.support_metrics_daily.input_tokens+excluded.input_tokens,output_tokens=kombax_customer_ops.support_metrics_daily.output_tokens+excluded.output_tokens,estimated_cost=kombax_customer_ops.support_metrics_daily.estimated_cost+excluded.estimated_cost;
  update kombax_customer_ops.tickets set updated_at=now(),status=case when v_turn.category='MIGRATION' then 'WAITING_USER' else 'GUIDED_SESSION' end where ticket_id=v_turn.ticket_id;
  return jsonb_build_object('ok',true,'turn_id',p_turn_id);
end $$;

create or replace function public.app_kombax_assist_turn_fail_v227(p_turn_id uuid,p_error_code text default 'AI_ERROR')
returns jsonb language plpgsql volatile security definer set search_path=''
as $$ begin
  update kombax_ai_ops.assistance_turns set status='FAILED',error_code=left(coalesce(p_error_code,'AI_ERROR'),120),completed_at=now() where turn_id=p_turn_id and status='RESERVED';
  return jsonb_build_object('ok',true,'turn_id',p_turn_id);
end $$;

revoke all on function public.app_kombax_assist_turn_internal_v227(uuid) from public,anon,authenticated;
revoke all on function public.app_kombax_assist_turn_complete_v227(uuid,text,text,integer,integer,jsonb) from public,anon,authenticated;
revoke all on function public.app_kombax_assist_turn_fail_v227(uuid,text) from public,anon,authenticated;
grant execute on function public.app_kombax_assist_turn_internal_v227(uuid) to service_role;
grant execute on function public.app_kombax_assist_turn_complete_v227(uuid,text,text,integer,integer,jsonb) to service_role;
grant execute on function public.app_kombax_assist_turn_fail_v227(uuid,text) to service_role;
comment on table kombax_ai_ops.assistance_cost_policies is 'Private profitability guardrails for KOMBAX Assist. Never expose to customer UI.';
comment on table kombax_ai_ops.model_cost_rates is 'Private model pricing ledger used only to estimate KOMBAX AI operating cost.';
notify pgrst,'reload schema';
