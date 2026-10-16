-- Preserve live guards/grants: repair only the decimal aggregation expression.
do $repair$
declare v_definition text;
begin
 select pg_get_functiondef('public.app_kombax_pilot_metrics_r97()'::regprocedure) into v_definition;
 if position('(x->>''used'')::integer' in v_definition)>0 then
  execute replace(v_definition,'(x->>''used'')::integer','(x->>''used'')::numeric');
 elsif position('(x->>''used'')::numeric' in v_definition)=0 then
  raise exception 'PILOT_METRICS_UNEXPECTED_DEFINITION';
 end if;
end $repair$;

-- Existing club/profile/moderation scope remains. Only recipient-bound Owner
-- agent and verification notifications are added; no policy/grant is loosened.
alter table public.notificaciones drop constraint notificaciones_subject_scope_v199;
alter table public.notificaciones add constraint notificaciones_subject_scope_v199 check (
 club_id is not null
 or (subject_type='direct_profile' and subject_id is not null)
 or (subject_type='moderation' and subject_id is not null and perfil_id is not null)
 or (subject_type='owner_agent_turn' and subject_id is not null and perfil_id is not null and tipo='owner_agent')
 or (subject_type='verification' and subject_id is not null and perfil_id is not null and tipo='owner_action')
);

create or replace function kombax_owner_ai.metric_r278(p_schema text,p_table text,p_date text,p_status text,p_type text,p_days integer)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_total bigint;v_period bigint;v_states jsonb:='[]';v_types jsonb:='[]';v_relation text:=format('%I.%I',p_schema,p_table);
begin
 if v_relation not in ('public.perfiles','public.perfiles_kombax_directos','public.kombax_solicitudes_alta','public.kombax_social_publicaciones','public.kombax_eventos_publicos','kombax_customer_ops.tickets','kombax_ai_ops.assistance_turns','kombax_ai_ops.usage_help_turns_r274','kombax_owner_ai.agent_turns') then raise exception 'METRIC_SOURCE_NOT_ALLOWED';end if;
 if to_regclass(v_relation) is null then return jsonb_build_object('available',false,'source',v_relation,'reason','source_unavailable');end if;
 execute format('select count(*),count(*) filter(where %I>=now()-make_interval(days=>$1)) from %s',p_date,v_relation) into v_total,v_period using least(365,greatest(7,p_days));
 if p_status is not null then
  execute format('select coalesce(jsonb_agg(x order by x.total desc),''[]''::jsonb) from (select coalesce(%I::text,''unknown'') as label,count(*) total from %s where %I>=now()-make_interval(days=>$1) group by 1 limit 25) x',p_status,v_relation,p_date) into v_states using least(365,greatest(7,p_days));
 end if;
 if p_type is not null then
  execute format('select coalesce(jsonb_agg(x order by x.total desc),''[]''::jsonb) from (select coalesce(%I::text,''unknown'') as label,count(*) total from %s where %I>=now()-make_interval(days=>$1) group by 1 limit 25) x',p_type,v_relation,p_date) into v_types using least(365,greatest(7,p_days));
 end if;
 return jsonb_build_object('available',true,'source',v_relation,'total',v_total,'period',v_period,'by_status',v_states,'by_type',v_types);
exception when undefined_column or undefined_table then
 return jsonb_build_object('available',false,'source',v_relation,'reason','schema_unavailable');
end $$;
revoke all on function kombax_owner_ai.metric_r278(text,text,text,text,text,integer) from public,anon,authenticated,service_role;

create or replace function public.app_kombax_owner_insights_r278(p_days integer default 90)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_days int:=least(365,greatest(7,coalesce(p_days,90)));v_cohorts jsonb;v_publishing jsonb;v_knowledge jsonb;
begin
 if (select auth.uid()) is null or not public.app_kombax_es_platform_admin_v055() then raise exception 'PLATFORM_ADMIN_REQUIRED';end if;
 select coalesce(jsonb_agg(x order by x.week),'[]'::jsonb) into v_cohorts from (
  select to_char(date_trunc('week',p.creado_en),'YYYY-MM-DD') as week,count(*) as accounts,
   count(*) filter(where exists(select 1 from public.perfiles_kombax_directos d where d.perfil_id=p.id)) as accounts_with_identity
  from public.perfiles p where p.creado_en>=now()-make_interval(days=>v_days) group by 1
 ) x;
 select jsonb_build_object('available',true,'total',count(*),'visible',count(*) filter(where visible),
  'verified',count(*) filter(where verificado),'publishing_enabled',count(*) filter(where publicar_habilitado)) into v_publishing from public.kombax_social_perfiles;
 select jsonb_build_object('available',true,'pending',count(*) filter(where review_state='pending'),'reviewed',count(*) filter(where review_state='reviewed')) into v_knowledge from kombax_help_knowledge.observations_r277;
 return jsonb_build_object('ok',true,'version','r278','generated_at',now(),'days',v_days,'scope','platform_aggregates_owner_only',
 'accounts',kombax_owner_ai.metric_r278('public','perfiles','creado_en',null,null,v_days),
 'identities',kombax_owner_ai.metric_r278('public','perfiles_kombax_directos','creado_en','estado','tipo',v_days),
 'verifications',kombax_owner_ai.metric_r278('public','kombax_solicitudes_alta','creado_en','estado','tipo',v_days),
 'social',kombax_owner_ai.metric_r278('public','kombax_social_publicaciones','creado_en','estado','tipo',v_days),
 'events',kombax_owner_ai.metric_r278('public','kombax_eventos_publicos','creado_en','estado','tipo',v_days),
 'support',kombax_owner_ai.metric_r278('kombax_customer_ops','tickets','opened_at','status','category',v_days),
 'ai_paid',kombax_owner_ai.metric_r278('kombax_ai_ops','assistance_turns','requested_at','status','category',v_days),
 'ai_free',kombax_owner_ai.metric_r278('kombax_ai_ops','usage_help_turns_r274','reserved_at','status',null,v_days),
 'owner_agents',kombax_owner_ai.metric_r278('kombax_owner_ai','agent_turns','created_at','status','agent',v_days),
 'public_profiles',v_publishing,'knowledge',v_knowledge,
 'marketing',jsonb_build_object('cohorts',v_cohorts,'contact_export_enabled',false,'consent_register_available',false,
  'limits',jsonb_build_array('Cohortes por fecha de alta; no representan retención ni atribución de campañas.','No hay medición confirmada de clics, CAC, LTV o ROI en este informe.','Los contactos y el consentimiento para campañas requieren un flujo separado.')));
end $$;
revoke all on function public.app_kombax_owner_insights_r278(integer) from public,anon;
grant execute on function public.app_kombax_owner_insights_r278(integer) to authenticated;
