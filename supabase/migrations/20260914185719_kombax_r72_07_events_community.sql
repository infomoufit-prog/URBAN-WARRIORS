-- KOMBAX R72 / build 20123 live section 07
begin;
-- 7. Events community + ratings.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_event_community_r72(p_event_id uuid,p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_comments jsonb;v_reviews jsonb;v_summary jsonb;v_exists boolean;
begin
 select exists(select 1 from public.kombax_eventos_publicos e where e.id=p_event_id and (e.estado in('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado') or (v_uid is not null and public.app_kombax_evento_puede_gestionar_v160(e.id)))) into v_exists;
 if not v_exists then raise exception 'EVENT_NOT_AVAILABLE';end if;
 select jsonb_build_object('average',coalesce(round(avg(r.rating)::numeric,2),0),'total',count(*),'verified_total',count(*) filter(where r.verified_attendance),'comments',(select count(*) from kombax_reputation.event_comments c where c.event_id=p_event_id and c.status in('active','reported'))) into v_summary from kombax_reputation.event_reviews r where r.event_id=p_event_id and r.status in('active','reported');
 select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'parent_id',c.parent_id,'body',c.body,'media',c.media,'verified_attendance',c.verified_attendance,'created_at',c.created_at,'author_name',trim(concat_ws(' ',p.nombre,p.apellidos)),'avatar_url',p.avatar_url,'own',c.user_id=v_uid) order by c.created_at asc),'[]'::jsonb) into v_comments from kombax_reputation.event_comments c join public.perfiles p on p.id=c.user_id where c.event_id=p_event_id and c.status in('active','reported') limit least(greatest(coalesce(p_limit,100),1),200);
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'rating',r.rating,'body',r.body,'media',r.media,'verified_attendance',r.verified_attendance,'organizer_response',r.organizer_response,'created_at',r.created_at,'author_name',trim(concat_ws(' ',p.nombre,p.apellidos)),'own',r.user_id=v_uid) order by r.created_at desc),'[]'::jsonb) into v_reviews from kombax_reputation.event_reviews r join public.perfiles p on p.id=r.user_id where r.event_id=p_event_id and r.status in('active','reported') limit 50;
 return jsonb_build_object('event_id',p_event_id,'summary',v_summary,'comments',v_comments,'reviews',v_reviews,'authenticated',v_uid is not null,'verified_attendee',case when v_uid is null then false else kombax_reputation.has_verified_attendance_r72(v_uid,p_event_id) end);
end $$;
revoke all on function public.app_kombax_event_community_r72(uuid,integer) from public;
grant execute on function public.app_kombax_event_community_r72(uuid,integer) to anon,authenticated;

create or replace function public.app_kombax_event_comment_upsert_r72(p_event_id uuid,p_body text,p_parent_id uuid default null,p_media jsonb default '[]'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_id uuid;v_verified boolean;v_parent_event uuid;
begin if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if char_length(trim(coalesce(p_body,'')))<1 and jsonb_array_length(coalesce(p_media,'[]'::jsonb))=0 then raise exception 'COMMENT_EMPTY';end if;if char_length(trim(coalesce(p_body,'')))>3000 or jsonb_typeof(coalesce(p_media,'[]'::jsonb))<>'array' or jsonb_array_length(coalesce(p_media,'[]'::jsonb))>5 then raise exception 'COMMENT_CONTENT_INVALID';end if;
 if not exists(select 1 from public.kombax_eventos_publicos e where e.id=p_event_id and (e.estado in('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado') or public.app_kombax_evento_puede_gestionar_v160(e.id))) then raise exception 'EVENT_NOT_AVAILABLE';end if;
 if p_parent_id is not null then select event_id into v_parent_event from kombax_reputation.event_comments where id=p_parent_id and status in('active','reported');if v_parent_event is distinct from p_event_id then raise exception 'COMMENT_PARENT_INVALID';end if;end if;
 v_verified:=kombax_reputation.has_verified_attendance_r72(v_uid,p_event_id);
 insert into kombax_reputation.event_comments(event_id,user_id,parent_id,body,media,verified_attendance) values(p_event_id,v_uid,p_parent_id,trim(coalesce(p_body,'')),coalesce(p_media,'[]'::jsonb),v_verified) returning id into v_id;
 return jsonb_build_object('ok',true,'comment_id',v_id,'verified_attendance',v_verified);end $$;
revoke all on function public.app_kombax_event_comment_upsert_r72(uuid,text,uuid,jsonb) from public,anon;
grant execute on function public.app_kombax_event_comment_upsert_r72(uuid,text,uuid,jsonb) to authenticated;

create or replace function public.app_kombax_event_comment_withdraw_r72(p_comment_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid;begin if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;update kombax_reputation.event_comments set status='deleted_by_user',body='',media='[]'::jsonb,updated_at=now() where id=p_comment_id and user_id=auth.uid() returning id into v_id;if v_id is null then raise exception 'COMMENT_OWNER_REQUIRED';end if;return jsonb_build_object('ok',true,'comment_id',v_id);end $$;
revoke all on function public.app_kombax_event_comment_withdraw_r72(uuid) from public,anon;
grant execute on function public.app_kombax_event_comment_withdraw_r72(uuid) to authenticated;

create or replace function public.app_kombax_event_review_upsert_r72(p_event_id uuid,p_rating integer,p_body text default '',p_media jsonb default '[]'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_id uuid;v_verified boolean;
begin if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if p_rating not between 1 and 5 then raise exception 'REVIEW_RATING_INVALID';end if;if char_length(trim(coalesce(p_body,'')))>4000 or jsonb_typeof(coalesce(p_media,'[]'::jsonb))<>'array' or jsonb_array_length(coalesce(p_media,'[]'::jsonb))>5 then raise exception 'REVIEW_CONTENT_INVALID';end if;
 if not exists(select 1 from public.kombax_eventos_publicos e where e.id=p_event_id and (e.estado in('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado') or public.app_kombax_evento_puede_gestionar_v160(e.id))) then raise exception 'EVENT_NOT_AVAILABLE';end if;
 v_verified:=kombax_reputation.has_verified_attendance_r72(v_uid,p_event_id);
 insert into kombax_reputation.event_reviews(event_id,user_id,rating,body,media,verified_attendance,status) values(p_event_id,v_uid,p_rating,trim(coalesce(p_body,'')),coalesce(p_media,'[]'::jsonb),v_verified,'active')
 on conflict(event_id,user_id) do update set rating=excluded.rating,body=excluded.body,media=excluded.media,verified_attendance=excluded.verified_attendance,status='active',updated_at=now() returning id into v_id;
 return jsonb_build_object('ok',true,'review_id',v_id,'verified_attendance',v_verified);end $$;
revoke all on function public.app_kombax_event_review_upsert_r72(uuid,integer,text,jsonb) from public,anon;
grant execute on function public.app_kombax_event_review_upsert_r72(uuid,integer,text,jsonb) to authenticated;

create or replace function public.app_kombax_event_review_withdraw_r72(p_review_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid;begin if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;update kombax_reputation.event_reviews set status='deleted_by_user',body='',media='[]'::jsonb,updated_at=now() where id=p_review_id and user_id=auth.uid() returning id into v_id;if v_id is null then raise exception 'REVIEW_OWNER_REQUIRED';end if;return jsonb_build_object('ok',true,'review_id',v_id);end $$;
revoke all on function public.app_kombax_event_review_withdraw_r72(uuid) from public,anon;
grant execute on function public.app_kombax_event_review_withdraw_r72(uuid) to authenticated;

create or replace function public.app_kombax_event_review_respond_r72(p_review_id uuid,p_response text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_event uuid;begin if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;if char_length(trim(coalesce(p_response,'')))>3000 then raise exception 'REVIEW_RESPONSE_TOO_LONG';end if;select event_id into v_event from kombax_reputation.event_reviews where id=p_review_id;if v_event is null or not public.app_kombax_evento_puede_gestionar_v160(v_event) then raise exception 'EVENT_MANAGE_REQUIRED';end if;update kombax_reputation.event_reviews set organizer_response=nullif(trim(p_response),''),organizer_response_by=case when trim(coalesce(p_response,''))='' then null else auth.uid() end,organizer_response_at=case when trim(coalesce(p_response,''))='' then null else now() end,updated_at=now() where id=p_review_id;return jsonb_build_object('ok',true,'review_id',p_review_id);end $$;
revoke all on function public.app_kombax_event_review_respond_r72(uuid,text) from public,anon;
grant execute on function public.app_kombax_event_review_respond_r72(uuid,text) to authenticated;

-- Reports are shared by Showcase and Events. Sellers/organizers report; platform moderates.
create or replace function public.app_kombax_reputation_report_r72(p_target_type text,p_target_id uuid,p_reason text,p_detail text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_id uuid;v_type text:=lower(trim(p_target_type));
begin if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if v_type not in('product_review','event_comment','event_review') or char_length(trim(coalesce(p_reason,'')))<2 then raise exception 'REPORT_INVALID';end if;
 if (v_type='product_review' and not exists(select 1 from kombax_reputation.product_reviews where id=p_target_id)) or (v_type='event_comment' and not exists(select 1 from kombax_reputation.event_comments where id=p_target_id)) or (v_type='event_review' and not exists(select 1 from kombax_reputation.event_reviews where id=p_target_id)) then raise exception 'REPORT_TARGET_NOT_FOUND';end if;
 insert into kombax_reputation.reputation_reports(reporter_user_id,target_type,target_id,reason,detail) values(v_uid,v_type,p_target_id,left(trim(p_reason),80),left(trim(coalesce(p_detail,'')),1500)) on conflict do nothing returning id into v_id;
 if v_id is null then select id into v_id from kombax_reputation.reputation_reports where reporter_user_id=v_uid and target_type=v_type and target_id=p_target_id and status in('pending','reviewing') order by created_at desc limit 1;end if;
 return jsonb_build_object('ok',true,'report_id',v_id,'status','pending');end $$;
revoke all on function public.app_kombax_reputation_report_r72(text,uuid,text,text) from public,anon;
grant execute on function public.app_kombax_reputation_report_r72(text,uuid,text,text) to authenticated;

create or replace function public.app_kombax_event_community_manage_r72(p_event_id uuid,p_limit integer default 150)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_base jsonb;v_reports integer;
begin if auth.uid() is null or not public.app_kombax_evento_puede_gestionar_v160(p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED';end if;v_base:=public.app_kombax_event_community_r72(p_event_id,p_limit);select count(*) into v_reports from kombax_reputation.reputation_reports rr where rr.status in('pending','reviewing') and ((rr.target_type='event_comment' and exists(select 1 from kombax_reputation.event_comments c where c.id=rr.target_id and c.event_id=p_event_id)) or (rr.target_type='event_review' and exists(select 1 from kombax_reputation.event_reviews r where r.id=rr.target_id and r.event_id=p_event_id)));return v_base||jsonb_build_object('pending_reports',v_reports);end $$;
revoke all on function public.app_kombax_event_community_manage_r72(uuid,integer) from public,anon;
grant execute on function public.app_kombax_event_community_manage_r72(uuid,integer) to authenticated;

-- ---------------------------------------------------------------------------
commit;
