-- R103: internal economics and old-counter comparison for platform administration.
begin;
create or replace function public.app_kombax_ai_admin_metrics_r103()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_period timestamptz;v_next timestamptz;v_entities jsonb;v_models jsonb;
 v_total_eur numeric;v_total_usd numeric;v_credits numeric;v_failed integer;
begin
 if not public.app_kombax_es_platform_admin_v055() then
  raise exception 'platform_admin_required' using errcode='42501'; end if;
 v_period:=date_trunc('month',now() at time zone 'Europe/Madrid') at time zone 'Europe/Madrid';
 v_next:=((v_period at time zone 'Europe/Madrid')+interval '1 month') at time zone 'Europe/Madrid';
 select coalesce(jsonb_agg(jsonb_build_object(
  'tenant_ref',w.tenant_ref,'plan',coalesce(p.plan,'CLUB_BASIC'),
  'available',w.available,'reserved',w.reserved,'granted',coalesce(g.granted,0),
  'expired',coalesce(g.expired,0),'purchased',coalesce(g.purchased,0),
  'promotional',coalesce(g.promotional,0),'credits_used',coalesce(r.used,0),
  'old_usage_count',coalesce(t.old_count,0),'ai_credit_usage',coalesce(r.turn_count,0),
  'assist_turns',coalesce(t.assist_count,0),'migration_turns',coalesce(t.migration_count,0),
  'assist_cost_eur',coalesce(u.assist_cost,0),'migration_cost_eur',coalesce(u.migration_cost,0),
  'api_cost_eur',coalesce(u.cost_eur,0),'api_cost_usd',coalesce(u.cost_usd,0),
  'shortfall',coalesce(r.shortfall,0),'migration_jobs',coalesce(t.migration_jobs,0)
 ) order by coalesce(r.used,0) desc),'[]'::jsonb) into v_entities
 from kombax_ai_ops.ai_wallets_r97 w
 left join lateral(select plan from kombax_ai_ops.assistance_periods
   where tenant_ref=w.tenant_ref order by period_start desc limit 1) p on true
 left join lateral(select coalesce(sum(total) filter(where created_at>=v_period and created_at<v_next),0) granted,
   coalesce(sum(total) filter(where grant_type='purchased' and created_at>=v_period and created_at<v_next),0) purchased,
   coalesce(sum(total) filter(where grant_type='promotional' and created_at>=v_period and created_at<v_next),0) promotional,
   coalesce(sum(total-remaining) filter(where expires_at>=v_period and expires_at<v_next),0) expired
   from kombax_ai_ops.ai_credit_grants_r97 where tenant_ref=w.tenant_ref) g on true
 left join lateral(select coalesce(sum(charged),0) used,
   count(*) filter(where status='SETTLED') turn_count,coalesce(sum(shortfall),0) shortfall
   from kombax_ai_ops.ai_credit_reservations_r97
   where tenant_ref=w.tenant_ref and created_at>=v_period and created_at<v_next) r on true
 left join lateral(select count(*) old_count,
   count(*) filter(where category='MANAGEMENT') assist_count,
   count(*) filter(where category='MIGRATION') migration_count,
   count(distinct ticket_id) filter(where category='MIGRATION') migration_jobs
   from kombax_ai_ops.assistance_turns where tenant_ref=w.tenant_ref
    and requested_at>=v_period and requested_at<v_next) t on true
 left join lateral(select coalesce(sum(api_cost_eur),0) cost_eur,coalesce(sum(api_cost_usd),0) cost_usd,
   coalesce(sum(api_cost_eur) filter(where agent='Assist'),0) assist_cost,
   coalesce(sum(api_cost_eur) filter(where agent='Migrations'),0) migration_cost
   from kombax_ai_ops.ai_usage_runs_r103 where tenant_ref=w.tenant_ref
    and created_at>=v_period and created_at<v_next) u on true;
 select coalesce(jsonb_agg(jsonb_build_object('model',model_alias,'agent',agent,'runs',n,
   'cost_eur',cost_eur,'cost_usd',cost_usd,'credits',credits,
   'cached_input_tokens',cached_input_tokens,'reasoning_tokens',reasoning_tokens,
   'image_inputs',image_inputs,'tool_calls',tool_calls) order by cost_eur desc),'[]'::jsonb)
 into v_models from (
   select model_alias,agent,count(*) n,sum(api_cost_eur) cost_eur,sum(api_cost_usd) cost_usd,
     sum(charged_credits) credits,sum(cached_input_tokens) cached_input_tokens,
     sum(reasoning_tokens) reasoning_tokens,sum(image_inputs) image_inputs,
     sum(jsonb_array_length(tool_calls)) tool_calls
   from kombax_ai_ops.ai_usage_runs_r103 where created_at>=v_period and created_at<v_next
   group by model_alias,agent
 ) x;
 select coalesce(sum(api_cost_eur),0),coalesce(sum(api_cost_usd),0),coalesce(sum(charged_credits),0)
 into v_total_eur,v_total_usd,v_credits from kombax_ai_ops.ai_usage_runs_r103
 where created_at>=v_period and created_at<v_next;
 select count(*) into v_failed from kombax_ai_ops.assistance_turns
 where status='FAILED' and requested_at>=v_period and requested_at<v_next;
 return jsonb_build_object('period_start',v_period,'period_end',v_next,
   'cost_eur',v_total_eur,'cost_usd',v_total_usd,'credits',v_credits,
   'failed_turns',v_failed,'entities',v_entities,'models',v_models);
end $$;
revoke all on function public.app_kombax_ai_admin_metrics_r103() from public,anon,service_role;
grant execute on function public.app_kombax_ai_admin_metrics_r103() to authenticated;
commit;
