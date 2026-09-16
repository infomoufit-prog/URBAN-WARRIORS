-- KOMBAX R73 / build 20124
-- Completes the R72 reputation/community layer without duplicating R72 structures.
-- Source of truth: schema contract verified against the live Supabase R73 migration.

begin;

alter table kombax_reputation.event_comments
  add column if not exists kind text not null default 'comment';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname='event_comments_kind_r73_check'
      and conrelid='kombax_reputation.event_comments'::regclass
  ) then
    alter table kombax_reputation.event_comments
      add constraint event_comments_kind_r73_check
      check (kind in ('comment','question'));
  end if;
end $$;

create index if not exists idx_r73_event_comments_kind
  on kombax_reputation.event_comments(event_id,kind,status,created_at desc);

create table if not exists kombax_reputation.event_reactions(
  event_id uuid not null references public.kombax_eventos_publicos(id) on delete cascade,
  user_id uuid not null references public.perfiles(id) on delete cascade,
  reaction text not null check(reaction in('like','fire','applause','support')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(event_id,user_id)
);
alter table kombax_reputation.event_reactions enable row level security;
revoke all on kombax_reputation.event_reactions from public,anon,authenticated;
grant select,insert,update,delete on kombax_reputation.event_reactions to service_role;
create index if not exists idx_r73_event_reactions_event on kombax_reputation.event_reactions(event_id,reaction,updated_at desc);
create index if not exists idx_r73_event_reactions_user on kombax_reputation.event_reactions(user_id,updated_at desc);

create or replace function public.app_kombax_showcase_reviews_r73(p_product_id uuid,p_filter text default 'recent',p_limit integer default 50)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_summary jsonb;v_reviews jsonb;v_product public.kombax_showcase_elementos;
begin
 select * into strict v_product from public.kombax_showcase_elementos where id=p_product_id;
 if v_product.estado<>'publicado' and not (v_uid is not null and public.app_kombax_showcase_puede_gestionar_v045(v_product.marca_id)) then raise exception 'SHOWCASE_PRODUCT_NOT_AVAILABLE';end if;
 select jsonb_build_object('average',coalesce(round(avg(x.rating)::numeric,2),0),'total',count(*),'verified_total',count(*) filter(where x.verified_purchase),'with_photos',count(*) filter(where x.with_photos),'distribution',jsonb_build_object('5',count(*) filter(where x.rating=5),'4',count(*) filter(where x.rating=4),'3',count(*) filter(where x.rating=3),'2',count(*) filter(where x.rating=2),'1',count(*) filter(where x.rating=1))) into v_summary
 from (select r.rating,(kombax_reputation.verified_purchase_order_r72(r.reviewer_user_id,r.product_id) is not null) verified_purchase,jsonb_array_length(r.media)>0 with_photos from kombax_reputation.product_reviews r where r.product_id=p_product_id and r.status in('active','reported')) x;
 select coalesce(jsonb_agg(to_jsonb(q) order by q.sort_a desc,q.created_at desc),'[]'::jsonb) into v_reviews from(
   select r.id,r.rating,r.body,r.media,(vp.order_id is not null) verified_purchase,r.created_at,r.updated_at,r.seller_response,r.seller_response_at,trim(concat_ws(' ',p.nombre,p.apellidos)) author_name,p.avatar_url,(r.reviewer_user_id=v_uid) own,
   case lower(coalesce(p_filter,'recent')) when 'best' then r.rating::bigint when 'worst' then (6-r.rating)::bigint when 'verified' then case when vp.order_id is not null then 10 else 0 end when 'photos' then case when jsonb_array_length(r.media)>0 then 10 else 0 end else extract(epoch from r.created_at)::bigint end sort_a
   from kombax_reputation.product_reviews r join public.perfiles p on p.id=r.reviewer_user_id left join lateral (select kombax_reputation.verified_purchase_order_r72(r.reviewer_user_id,r.product_id) order_id) vp on true
   where r.product_id=p_product_id and r.status in('active','reported') and (lower(coalesce(p_filter,'recent'))<>'verified' or vp.order_id is not null) and (lower(coalesce(p_filter,'recent'))<>'photos' or jsonb_array_length(r.media)>0)
   order by sort_a desc,r.created_at desc limit least(greatest(coalesce(p_limit,50),1),100)
 ) q;
 return jsonb_build_object('product_id',p_product_id,'summary',v_summary,'reviews',v_reviews,'can_review',v_uid is not null and v_product.estado='publicado' and v_product.commerce_enabled and v_product.listing_kind='product');
end $$;
revoke all on function public.app_kombax_showcase_reviews_r73(uuid,text,integer) from public;
grant execute on function public.app_kombax_showcase_reviews_r73(uuid,text,integer) to anon,authenticated;

create or replace function public.app_kombax_showcase_seller_reviews_r73(p_provider_id uuid,p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_reviews jsonb;v_summary jsonb;v_top jsonb;v_bottom jsonb;v_evolution jsonb;v_reports integer:=0;
begin
 if auth.uid() is null or not public.app_kombax_showcase_puede_gestionar_v045(p_provider_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED';end if;
 select jsonb_build_object('average',coalesce(round(avg(x.rating)::numeric,2),0),'total',count(*),'verified_total',count(*) filter(where x.verified_purchase),'verified_percent',case when count(*)=0 then 0 else round((100.0*count(*) filter(where x.verified_purchase)/count(*))::numeric,1) end,'unanswered',count(*) filter(where not x.responded),'responses',count(*) filter(where x.responded),'response_rate',case when count(*)=0 then 0 else round((100.0*count(*) filter(where x.responded)/count(*))::numeric,1) end) into v_summary
 from (select r.rating,(kombax_reputation.verified_purchase_order_r72(r.reviewer_user_id,r.product_id) is not null) verified_purchase,(r.seller_response is not null) responded from kombax_reputation.product_reviews r join public.kombax_showcase_elementos e on e.id=r.product_id where e.marca_id=p_provider_id and r.status in('active','reported')) x;
 select count(*) into v_reports from kombax_reputation.reputation_reports rr where rr.status in('pending','reviewing') and rr.target_type='product_review' and exists(select 1 from kombax_reputation.product_reviews r join public.kombax_showcase_elementos e on e.id=r.product_id where r.id=rr.target_id and e.marca_id=p_provider_id);
 v_summary:=v_summary||jsonb_build_object('pending_reports',v_reports);
 select coalesce(jsonb_agg(to_jsonb(t) order by t.average desc,t.total desc,t.product_name),'[]'::jsonb) into v_top from(select e.id product_id,e.nombre product_name,round(avg(r.rating)::numeric,2) average,count(*) total from kombax_reputation.product_reviews r join public.kombax_showcase_elementos e on e.id=r.product_id where e.marca_id=p_provider_id and r.status in('active','reported') group by e.id,e.nombre order by avg(r.rating) desc,count(*) desc,e.nombre limit 5)t;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.average asc,t.total desc,t.product_name),'[]'::jsonb) into v_bottom from(select e.id product_id,e.nombre product_name,round(avg(r.rating)::numeric,2) average,count(*) total from kombax_reputation.product_reviews r join public.kombax_showcase_elementos e on e.id=r.product_id where e.marca_id=p_provider_id and r.status in('active','reported') group by e.id,e.nombre order by avg(r.rating) asc,count(*) desc,e.nombre limit 5)t;
 select coalesce(jsonb_agg(jsonb_build_object('month',to_char(m.month_start,'YYYY-MM'),'average',coalesce(x.average,0),'total',coalesce(x.total,0)) order by m.month_start),'[]'::jsonb) into v_evolution from (select (date_trunc('month',now())-(g||' months')::interval)::date month_start from generate_series(5,0,-1) g)m left join lateral(select round(avg(r.rating)::numeric,2) average,count(*) total from kombax_reputation.product_reviews r join public.kombax_showcase_elementos e on e.id=r.product_id where e.marca_id=p_provider_id and r.status in('active','reported') and r.created_at>=m.month_start and r.created_at<(m.month_start+interval '1 month'))x on true;
 select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc),'[]'::jsonb) into v_reviews from(select r.id,r.product_id,e.nombre product_name,r.rating,r.body,r.media,(vp.order_id is not null) verified_purchase,r.seller_response,r.created_at,r.status,trim(concat_ws(' ',p.nombre,p.apellidos)) author_name from kombax_reputation.product_reviews r join public.kombax_showcase_elementos e on e.id=r.product_id join public.perfiles p on p.id=r.reviewer_user_id left join lateral(select kombax_reputation.verified_purchase_order_r72(r.reviewer_user_id,r.product_id) order_id)vp on true where e.marca_id=p_provider_id and r.status in('active','reported') order by r.created_at desc limit least(greatest(coalesce(p_limit,100),1),200))q;
 return jsonb_build_object('provider_id',p_provider_id,'summary',v_summary,'reviews',v_reviews,'top_products',v_top,'bottom_products',v_bottom,'evolution',v_evolution);
end $$;
revoke all on function public.app_kombax_showcase_seller_reviews_r73(uuid,integer) from public,anon;
grant execute on function public.app_kombax_showcase_seller_reviews_r73(uuid,integer) to authenticated;

create or replace function public.app_kombax_event_community_r73(p_event_id uuid,p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_comments jsonb;v_reviews jsonb;v_summary jsonb;v_exists boolean;v_reactions jsonb;v_my_reaction text;v_images integer:=0;v_videos integer:=0;
begin
 select exists(select 1 from public.kombax_eventos_publicos e where e.id=p_event_id and (e.estado in('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado') or (v_uid is not null and public.app_kombax_evento_puede_gestionar_v160(e.id)))) into v_exists;if not v_exists then raise exception 'EVENT_NOT_AVAILABLE';end if;
 select coalesce(sum(case when lower(coalesce(a.item->>'type','image'))='video' then 0 else 1 end),0),coalesce(sum(case when lower(coalesce(a.item->>'type','image'))='video' then 1 else 0 end),0) into v_images,v_videos from(select jsonb_array_elements(c.media) item from kombax_reputation.event_comments c where c.event_id=p_event_id and c.status in('active','reported') union all select jsonb_array_elements(r.media) item from kombax_reputation.event_reviews r where r.event_id=p_event_id and r.status in('active','reported'))a;
 select jsonb_build_object('average',coalesce(round(avg(r.rating)::numeric,2),0),'total',count(*),'verified_total',count(*) filter(where kombax_reputation.has_verified_attendance_r72(r.user_id,p_event_id)),'comments',(select count(*) from kombax_reputation.event_comments c where c.event_id=p_event_id and c.status in('active','reported')),'root_comments',(select count(*) from kombax_reputation.event_comments c where c.event_id=p_event_id and c.parent_id is null and c.kind='comment' and c.status in('active','reported')),'questions',(select count(*) from kombax_reputation.event_comments c where c.event_id=p_event_id and c.parent_id is null and c.kind='question' and c.status in('active','reported')),'replies',(select count(*) from kombax_reputation.event_comments c where c.event_id=p_event_id and c.parent_id is not null and c.status in('active','reported')),'images',v_images,'videos',v_videos,'reactions',(select count(*) from kombax_reputation.event_reactions x where x.event_id=p_event_id)) into v_summary from kombax_reputation.event_reviews r where r.event_id=p_event_id and r.status in('active','reported');
 select jsonb_build_object('like',count(*) filter(where reaction='like'),'fire',count(*) filter(where reaction='fire'),'applause',count(*) filter(where reaction='applause'),'support',count(*) filter(where reaction='support'),'total',count(*)) into v_reactions from kombax_reputation.event_reactions where event_id=p_event_id;
 if v_uid is not null then select reaction into v_my_reaction from kombax_reputation.event_reactions where event_id=p_event_id and user_id=v_uid;end if;
 select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at asc),'[]'::jsonb) into v_comments from(select c.id,c.parent_id,c.kind,c.body,c.media,(c.verified_attendance or kombax_reputation.has_verified_attendance_r72(c.user_id,p_event_id)) verified_attendance,c.created_at,trim(concat_ws(' ',p.nombre,p.apellidos)) author_name,p.avatar_url,(c.user_id=v_uid) own from kombax_reputation.event_comments c join public.perfiles p on p.id=c.user_id where c.event_id=p_event_id and c.status in('active','reported') order by c.created_at asc limit least(greatest(coalesce(p_limit,100),1),200))q;
 select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc),'[]'::jsonb) into v_reviews from(select r.id,r.rating,r.body,r.media,(r.verified_attendance or kombax_reputation.has_verified_attendance_r72(r.user_id,p_event_id)) verified_attendance,r.organizer_response,r.created_at,trim(concat_ws(' ',p.nombre,p.apellidos)) author_name,(r.user_id=v_uid) own from kombax_reputation.event_reviews r join public.perfiles p on p.id=r.user_id where r.event_id=p_event_id and r.status in('active','reported') order by r.created_at desc limit 50)q;
 return jsonb_build_object('event_id',p_event_id,'summary',v_summary,'comments',v_comments,'reviews',v_reviews,'reactions',v_reactions,'my_reaction',v_my_reaction,'authenticated',v_uid is not null,'verified_attendee',case when v_uid is null then false else kombax_reputation.has_verified_attendance_r72(v_uid,p_event_id) end);
end $$;
revoke all on function public.app_kombax_event_community_r73(uuid,integer) from public;
grant execute on function public.app_kombax_event_community_r73(uuid,integer) to anon,authenticated;

create or replace function public.app_kombax_event_comment_upsert_r73(p_event_id uuid,p_body text,p_parent_id uuid default null,p_media jsonb default '[]'::jsonb,p_kind text default 'comment')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_id uuid;v_verified boolean;v_parent_event uuid;v_kind text:=lower(trim(coalesce(p_kind,'comment')));v_recent integer;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
 if char_length(trim(coalesce(p_body,'')))<1 and jsonb_array_length(coalesce(p_media,'[]'::jsonb))=0 then raise exception 'COMMENT_EMPTY';end if;
 if char_length(trim(coalesce(p_body,'')))>3000 or jsonb_typeof(coalesce(p_media,'[]'::jsonb))<>'array' or jsonb_array_length(coalesce(p_media,'[]'::jsonb))>5 then raise exception 'COMMENT_CONTENT_INVALID';end if;
 if v_kind not in('comment','question') then raise exception 'EVENT_COMMUNITY_KIND_INVALID';end if;
 if not exists(select 1 from public.kombax_eventos_publicos e where e.id=p_event_id and (e.estado in('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado') or public.app_kombax_evento_puede_gestionar_v160(e.id))) then raise exception 'EVENT_NOT_AVAILABLE';end if;
 if p_parent_id is not null then select event_id into v_parent_event from kombax_reputation.event_comments where id=p_parent_id and status in('active','reported');if v_parent_event is distinct from p_event_id then raise exception 'COMMENT_PARENT_INVALID';end if;v_kind:='comment';end if;
 select count(*) into v_recent from kombax_reputation.event_comments where event_id=p_event_id and user_id=v_uid and created_at>now()-interval '60 seconds';if v_recent>=8 then raise exception 'EVENT_COMMUNITY_RATE_LIMIT';end if;
 v_verified:=kombax_reputation.has_verified_attendance_r72(v_uid,p_event_id);
 insert into kombax_reputation.event_comments(event_id,user_id,parent_id,body,media,verified_attendance,kind) values(p_event_id,v_uid,p_parent_id,trim(coalesce(p_body,'')),coalesce(p_media,'[]'::jsonb),v_verified,v_kind) returning id into v_id;
 return jsonb_build_object('ok',true,'comment_id',v_id,'kind',v_kind,'verified_attendance',v_verified);
end $$;
revoke all on function public.app_kombax_event_comment_upsert_r73(uuid,text,uuid,jsonb,text) from public,anon;
grant execute on function public.app_kombax_event_comment_upsert_r73(uuid,text,uuid,jsonb,text) to authenticated;

create or replace function public.app_kombax_event_reaction_set_r73(p_event_id uuid,p_reaction text default 'like')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_reaction text:=lower(trim(coalesce(p_reaction,'like')));
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
 if not exists(select 1 from public.kombax_eventos_publicos e where e.id=p_event_id and (e.estado in('publicado','inscripciones_abiertas','inscripciones_cerradas','proximo','en_curso','finalizado') or public.app_kombax_evento_puede_gestionar_v160(e.id))) then raise exception 'EVENT_NOT_AVAILABLE';end if;
 if v_reaction='none' then delete from kombax_reputation.event_reactions where event_id=p_event_id and user_id=v_uid;return jsonb_build_object('ok',true,'event_id',p_event_id,'reaction',null);end if;
 if v_reaction not in('like','fire','applause','support') then raise exception 'EVENT_REACTION_INVALID';end if;
 insert into kombax_reputation.event_reactions(event_id,user_id,reaction) values(p_event_id,v_uid,v_reaction) on conflict(event_id,user_id) do update set reaction=excluded.reaction,updated_at=now();
 return jsonb_build_object('ok',true,'event_id',p_event_id,'reaction',v_reaction);
end $$;
revoke all on function public.app_kombax_event_reaction_set_r73(uuid,text) from public,anon;
grant execute on function public.app_kombax_event_reaction_set_r73(uuid,text) to authenticated;

create or replace function public.app_kombax_event_community_manage_r73(p_event_id uuid,p_limit integer default 150)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_base jsonb;v_reports integer:=0;v_followers integer:=0;v_interactions integer:=0;
begin
 if auth.uid() is null or not public.app_kombax_evento_puede_gestionar_v160(p_event_id) then raise exception 'EVENT_MANAGE_REQUIRED';end if;
 v_base:=public.app_kombax_event_community_r73(p_event_id,p_limit);
 select count(*) into v_reports from kombax_reputation.reputation_reports rr where rr.status in('pending','reviewing') and ((rr.target_type='event_comment' and exists(select 1 from kombax_reputation.event_comments c where c.id=rr.target_id and c.event_id=p_event_id)) or (rr.target_type='event_review' and exists(select 1 from kombax_reputation.event_reviews r where r.id=rr.target_id and r.event_id=p_event_id)));
 select count(*) into v_followers from public.kombax_evento_interes i where i.evento_id=p_event_id and i.estado in('interesado','asistire');
 v_interactions:=coalesce((v_base#>>'{summary,comments}')::integer,0)+coalesce((v_base#>>'{summary,total}')::integer,0)+coalesce((v_base#>>'{summary,reactions}')::integer,0)+v_followers;
 return v_base||jsonb_build_object('pending_reports',v_reports,'followers',v_followers,'interaction_total',v_interactions);
end $$;
revoke all on function public.app_kombax_event_community_manage_r73(uuid,integer) from public,anon;
grant execute on function public.app_kombax_event_community_manage_r73(uuid,integer) to authenticated;

notify pgrst,'reload schema';
commit;
