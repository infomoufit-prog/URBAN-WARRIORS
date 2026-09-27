-- R97 · Owner-only cohort analytics; no customer cost/model exposure.
begin;
create or replace function public.app_kombax_pilot_metrics_r97()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_rows jsonb;v_phase text;
begin
 if not public.app_kombax_es_platform_admin_v055() then raise exception 'platform_admin_required' using errcode='42501'; end if;
 v_phase:=kombax_commercial.program_phase_r97();
 select coalesce(jsonb_agg(jsonb_build_object(
  'subject_type',p.subject_type,'subject_id',p.subject_id,'name',coalesce(c.nombre,d.nombre_publico,'Organización'),
  'phase',case when v_phase='PILOT' then 'PILOT' else 'FOUNDER_PRELAUNCH' end,
  'available',coalesce(w.available,0),'reserved',coalesce(w.reserved,0),
  'granted',coalesce(g.granted,0),'used',coalesce(r.used,0),
  'assist_turns',coalesce(t.assist_turns,0),'migration_turns',coalesce(t.migration_turns,0),
  'api_cost',coalesce(t.api_cost,0),'imported_students',coalesce(i.students,0),
  'benefit',kombax_commercial.effective_benefit_r97(p.subject_type,p.subject_id,now())
 ) order by p.enrolled_at),'[]'::jsonb) into v_rows
 from kombax_commercial.pilot_entities_r97 p
 left join public.clubes c on p.subject_type='club' and c.id=p.subject_id
 left join public.perfiles_kombax_directos d on p.subject_type='direct_profile' and d.id=p.subject_id
 left join kombax_ai_ops.ai_wallets_r97 w on w.tenant_ref=p.tenant_ref
 left join lateral(select sum(total) granted from kombax_ai_ops.ai_credit_grants_r97 where tenant_ref=p.tenant_ref) g on true
 left join lateral(select sum(charged) used from kombax_ai_ops.ai_credit_reservations_r97 where tenant_ref=p.tenant_ref and status='SETTLED') r on true
 left join lateral(select count(*) filter(where category='MANAGEMENT' and status='COMPLETED') assist_turns,
    count(*) filter(where category='MIGRATION' and status='COMPLETED') migration_turns,
    coalesce(sum(estimated_cost) filter(where status='COMPLETED'),0) api_cost
    from kombax_ai_ops.assistance_turns where tenant_ref=p.tenant_ref) t on true
 left join lateral(select count(*) students from kombax_customer_ops.migration_imported_records_v271 m
    join kombax_customer_ops.tickets ticket on ticket.ticket_id=m.ticket_id
    where ticket.tenant_ref=p.tenant_ref and m.kind='student') i on true;
 return jsonb_build_object('phase',v_phase,'pilot_start_at',(select value from kombax_commercial.runtime_config_r64 where config_key='pilot_start_at'),
  'pilot_end_at',(select value from kombax_commercial.runtime_config_r64 where config_key='pilot_end_at'),
  'official_launch_at',(select value from kombax_commercial.runtime_config_r64 where config_key='official_launch_at'),
  'entities',v_rows,'enrolled_count',jsonb_array_length(v_rows),
  'api_cost_total',(select coalesce(sum((x->>'api_cost')::numeric),0) from jsonb_array_elements(v_rows) x),
  'credits_used_total',(select coalesce(sum((x->>'used')::integer),0) from jsonb_array_elements(v_rows) x));
end $$;
revoke all on function public.app_kombax_pilot_metrics_r97() from public,anon,service_role;
grant execute on function public.app_kombax_pilot_metrics_r97() to authenticated;
commit;
