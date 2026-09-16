-- KOMBAX R72 / build 20123 live section 09
begin;
-- 9. Platform moderation API for reputation/community reports.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_reputation_moderation_queue_r72(p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_rows jsonb;
begin
 if auth.uid() is null or not kombax_commercial.is_platform_admin() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
 select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at asc),'[]'::jsonb) into v_rows from(
   select rr.id,rr.target_type,rr.target_id,rr.reason,rr.detail,rr.status,rr.created_at,
     trim(concat_ws(' ',p.nombre,p.apellidos)) reporter_name
   from kombax_reputation.reputation_reports rr left join public.perfiles p on p.id=rr.reporter_user_id
   where rr.status in('pending','reviewing') order by rr.created_at asc limit least(greatest(coalesce(p_limit,100),1),200)
 )q;
 return jsonb_build_object('reports',v_rows,'total',jsonb_array_length(v_rows));
end $$;
revoke all on function public.app_kombax_reputation_moderation_queue_r72(integer) from public,anon;
grant execute on function public.app_kombax_reputation_moderation_queue_r72(integer) to authenticated;

create or replace function public.app_kombax_reputation_moderation_decide_r72(p_report_id uuid,p_decision text,p_resolution text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_report kombax_reputation.reputation_reports;v_decision text:=lower(trim(coalesce(p_decision,'')));
begin
 if v_uid is null or not kombax_commercial.is_platform_admin() then raise exception 'PLATFORM_ADMIN_REQUIRED'; end if;
 if v_decision not in('dismiss','hide','restore') then raise exception 'MODERATION_DECISION_INVALID'; end if;
 select * into strict v_report from kombax_reputation.reputation_reports where id=p_report_id for update;
 if v_decision='hide' then
   if v_report.target_type='product_review' then update kombax_reputation.product_reviews set status='hidden',updated_at=now() where id=v_report.target_id;
   elsif v_report.target_type='event_comment' then update kombax_reputation.event_comments set status='hidden',updated_at=now() where id=v_report.target_id;
   elsif v_report.target_type='event_review' then update kombax_reputation.event_reviews set status='hidden',updated_at=now() where id=v_report.target_id;
   end if;
 elsif v_decision='restore' then
   if v_report.target_type='product_review' then update kombax_reputation.product_reviews set status='active',updated_at=now() where id=v_report.target_id and status in('hidden','reported');
   elsif v_report.target_type='event_comment' then update kombax_reputation.event_comments set status='active',updated_at=now() where id=v_report.target_id and status in('hidden','reported');
   elsif v_report.target_type='event_review' then update kombax_reputation.event_reviews set status='active',updated_at=now() where id=v_report.target_id and status in('hidden','reported');
   end if;
 end if;
 update kombax_reputation.reputation_reports set status=case when v_decision='dismiss' then 'dismissed' else 'actioned' end,resolution=left(trim(coalesce(p_resolution,'')),2000),resolved_by=v_uid,resolved_at=now(),updated_at=now() where id=v_report.id;
 return jsonb_build_object('ok',true,'report_id',v_report.id,'decision',v_decision,'target_type',v_report.target_type,'target_id',v_report.target_id);
end $$;
revoke all on function public.app_kombax_reputation_moderation_decide_r72(uuid,text,text) from public,anon;
grant execute on function public.app_kombax_reputation_moderation_decide_r72(uuid,text,text) to authenticated;

-- ---------------------------------------------------------------------------
commit;
