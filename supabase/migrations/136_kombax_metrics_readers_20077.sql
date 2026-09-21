begin;

create or replace function public.app_kombax_metrics_backfill_v133(p_days integer default 90)
returns jsonb language plpgsql security definer set search_path=public,auth,storage as $$
declare v_d date;v_days int:=least(greatest(coalesce(p_days,90),1),730);v_count int:=0;
begin
  for v_d in select generate_series(current_date-(v_days-1),current_date,interval '1 day')::date loop
    perform public.app_kombax_metrics_collect_date_v133(v_d);v_count:=v_count+1;
  end loop;
  return jsonb_build_object('ok',true,'days',v_count,'from',current_date-(v_days-1),'to',current_date);
end $$;
revoke all on function public.app_kombax_metrics_backfill_v133(integer) from public,anon,authenticated;
grant execute on function public.app_kombax_metrics_backfill_v133(integer) to service_role;

create or replace function public.app_kombax_metrics_platform_v133(p_days integer default 90)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_days int:=least(greatest(coalesce(p_days,90),7),365);v_latest record;v_daily jsonb;v_top jsonb;v_policy jsonb;
begin
  if not public.app_kombax_es_platform_admin_v055() then raise exception 'KOMBAX_PLATFORM_ADMIN_MFA_REQUIRED'; end if;
  select * into v_latest from public.kombax_metrics_platform_daily_v133 order by metric_date desc limit 1;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.metric_date),'[]'::jsonb) into v_daily from (
    select * from public.kombax_metrics_platform_daily_v133 where metric_date>=current_date-(v_days-1) order by metric_date
  ) x;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.activity_score desc),'[]'::jsonb) into v_top from (
    select c.id as club_id,c.nombre,
      max(m.active_students) as active_students,sum(m.sessions_scheduled) as sessions,sum(m.attendance_records) as attendance,
      sum(m.payments_validated) as payments,round(sum(m.payments_amount)::numeric,2) as payment_amount,
      sum(m.community_posts+m.social_posts) as posts,sum(m.social_messages) as messages,sum(m.showcase_leads) as showcase_leads,
      max(m.storage_bytes) as storage_bytes,
      (sum(m.sessions_scheduled)+sum(m.attendance_records)+sum(m.payments_validated)+sum(m.community_posts+m.social_posts)+sum(m.social_messages)+sum(m.showcase_leads))::bigint as activity_score
    from public.clubes c join public.kombax_metrics_club_daily_v133 m on m.club_id=c.id
    where m.metric_date>=current_date-(v_days-1) group by c.id,c.nombre order by activity_score desc limit 25
  ) x;
  select to_jsonb(p) into v_policy from public.kombax_retention_policy_v133 p where singleton;
  return jsonb_build_object('ok',true,'days',v_days,'latest',to_jsonb(v_latest),'daily',v_daily,'top_clubs',v_top,'retention',v_policy,
    'period_totals',(select jsonb_build_object(
      'new_accounts',coalesce(sum(new_accounts),0),'sessions',coalesce(sum(sessions),0),'attendance',coalesce(sum(attendance_records),0),
      'payments',coalesce(sum(payments_validated),0),'payment_amount',coalesce(sum(payments_amount),0),'community_posts',coalesce(sum(community_posts),0),
      'social_posts',coalesce(sum(social_posts),0),'social_comments',coalesce(sum(social_comments),0),'social_likes',coalesce(sum(social_likes),0),
      'social_messages',coalesce(sum(social_messages),0),'showcase_leads',coalesce(sum(showcase_leads),0),'notifications',coalesce(sum(notifications_created),0),
      'push_sent',coalesce(sum(push_sent),0),'invitations',coalesce(sum(invitations_created),0)
    ) from public.kombax_metrics_platform_daily_v133 where metric_date>=current_date-(v_days-1)));
end $$;
revoke all on function public.app_kombax_metrics_platform_v133(integer) from public,anon;
grant execute on function public.app_kombax_metrics_platform_v133(integer) to authenticated;

create or replace function public.app_kombax_metrics_club_v133(p_club_id uuid,p_days integer default 90)
returns jsonb language plpgsql stable security definer set search_path=public,auth as $$
declare v_days int:=least(greatest(coalesce(p_days,90),7),365);v_ok boolean;v_daily jsonb;
begin
  v_ok:=public.app_kombax_es_platform_admin_v055() or public.app_puede_gestionar_ciclo_v038(p_club_id);
  if not v_ok then raise exception 'KOMBAX_METRICS_FORBIDDEN'; end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.metric_date),'[]'::jsonb) into v_daily from (
    select * from public.kombax_metrics_club_daily_v133 where club_id=p_club_id and metric_date>=current_date-(v_days-1) order by metric_date
  ) x;
  return jsonb_build_object('ok',true,'club_id',p_club_id,'days',v_days,'daily',v_daily,
    'totals',(select jsonb_build_object('sessions',coalesce(sum(sessions_scheduled),0),'attendance',coalesce(sum(attendance_records),0),
      'payments',coalesce(sum(payments_validated),0),'payment_amount',coalesce(sum(payments_amount),0),'posts',coalesce(sum(community_posts+social_posts),0),
      'messages',coalesce(sum(social_messages),0),'showcase_leads',coalesce(sum(showcase_leads),0)) from public.kombax_metrics_club_daily_v133 where club_id=p_club_id and metric_date>=current_date-(v_days-1)));
end $$;
revoke all on function public.app_kombax_metrics_club_v133(uuid,integer) from public,anon;
grant execute on function public.app_kombax_metrics_club_v133(uuid,integer) to authenticated;




notify pgrst,'reload schema';
commit;
