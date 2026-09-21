-- KOMBAX R72 / build 20123 live section 06
begin;
-- 6. Showcase reviews.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_showcase_reviews_r72(p_product_id uuid,p_filter text default 'recent',p_limit integer default 50)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_summary jsonb;v_reviews jsonb;v_product public.kombax_showcase_elementos;
begin
 select * into strict v_product from public.kombax_showcase_elementos where id=p_product_id;
 if v_product.estado<>'publicado' and not (v_uid is not null and public.app_kombax_showcase_puede_gestionar_v045(v_product.marca_id)) then raise exception 'SHOWCASE_PRODUCT_NOT_AVAILABLE'; end if;
 select jsonb_build_object('average',coalesce(round(avg(r.rating)::numeric,2),0),'total',count(*),'verified_total',count(*) filter(where r.verified_purchase),'with_photos',count(*) filter(where jsonb_array_length(r.media)>0),
  'distribution',jsonb_build_object('5',count(*) filter(where rating=5),'4',count(*) filter(where rating=4),'3',count(*) filter(where rating=3),'2',count(*) filter(where rating=2),'1',count(*) filter(where rating=1))) into v_summary
 from kombax_reputation.product_reviews r where r.product_id=p_product_id and r.status in('active','reported');
 select coalesce(jsonb_agg(to_jsonb(q) order by q.sort_a desc,q.created_at desc),'[]'::jsonb) into v_reviews from(
   select r.id,r.rating,r.body,r.media,r.verified_purchase,r.created_at,r.updated_at,r.seller_response,r.seller_response_at,
    trim(concat_ws(' ',p.nombre,p.apellidos)) as author_name,p.avatar_url,(r.reviewer_user_id=v_uid) as own,
    case lower(coalesce(p_filter,'recent')) when 'best' then r.rating::bigint when 'worst' then (6-r.rating)::bigint when 'verified' then case when r.verified_purchase then 10 else 0 end when 'photos' then case when jsonb_array_length(r.media)>0 then 10 else 0 end else extract(epoch from r.created_at)::bigint end as sort_a
   from kombax_reputation.product_reviews r join public.perfiles p on p.id=r.reviewer_user_id
   where r.product_id=p_product_id and r.status in('active','reported')
    and (lower(coalesce(p_filter,'recent'))<>'verified' or r.verified_purchase)
    and (lower(coalesce(p_filter,'recent'))<>'photos' or jsonb_array_length(r.media)>0)
   limit least(greatest(coalesce(p_limit,50),1),100)
 )q;
 return jsonb_build_object('product_id',p_product_id,'summary',v_summary,'reviews',v_reviews,'can_review',v_uid is not null and v_product.estado='publicado' and v_product.commerce_enabled and v_product.listing_kind='product');
end $$;
revoke all on function public.app_kombax_showcase_reviews_r72(uuid,text,integer) from public;
grant execute on function public.app_kombax_showcase_reviews_r72(uuid,text,integer) to anon,authenticated;

create or replace function public.app_kombax_showcase_review_upsert_r72(p_product_id uuid,p_rating integer,p_body text default '',p_media jsonb default '[]'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_product public.kombax_showcase_elementos;v_order uuid;v_id uuid;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 select * into strict v_product from public.kombax_showcase_elementos where id=p_product_id;
 if not v_product.commerce_enabled or v_product.listing_kind<>'product' then raise exception 'REVIEW_COMMERCE_PRODUCT_REQUIRED'; end if;
 if p_rating not between 1 and 5 then raise exception 'REVIEW_RATING_INVALID'; end if;
 if char_length(trim(coalesce(p_body,'')))>4000 or jsonb_typeof(coalesce(p_media,'[]'::jsonb))<>'array' or jsonb_array_length(coalesce(p_media,'[]'::jsonb))>5 then raise exception 'REVIEW_CONTENT_INVALID'; end if;
 v_order:=kombax_reputation.verified_purchase_order_r72(v_uid,p_product_id);
 insert into kombax_reputation.product_reviews(product_id,reviewer_user_id,rating,body,media,verified_purchase,verified_order_id,status)
 values(p_product_id,v_uid,p_rating,trim(coalesce(p_body,'')),coalesce(p_media,'[]'::jsonb),v_order is not null,v_order,'active')
 on conflict(product_id,reviewer_user_id) do update set rating=excluded.rating,body=excluded.body,media=excluded.media,verified_purchase=excluded.verified_purchase,verified_order_id=excluded.verified_order_id,status='active',updated_at=now()
 returning id into v_id;
 return jsonb_build_object('ok',true,'review_id',v_id,'verified_purchase',v_order is not null,'verified_order_id',v_order);
end $$;
revoke all on function public.app_kombax_showcase_review_upsert_r72(uuid,integer,text,jsonb) from public,anon;
grant execute on function public.app_kombax_showcase_review_upsert_r72(uuid,integer,text,jsonb) to authenticated;

create or replace function public.app_kombax_showcase_review_withdraw_r72(p_review_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_id uuid;
begin if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
 update kombax_reputation.product_reviews set status='deleted_by_user',body='',media='[]'::jsonb,updated_at=now() where id=p_review_id and reviewer_user_id=v_uid returning id into v_id;
 if v_id is null then raise exception 'REVIEW_OWNER_REQUIRED';end if;return jsonb_build_object('ok',true,'review_id',v_id,'withdrawn',true);end $$;
revoke all on function public.app_kombax_showcase_review_withdraw_r72(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_review_withdraw_r72(uuid) to authenticated;

create or replace function public.app_kombax_showcase_review_respond_r72(p_review_id uuid,p_response text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_product uuid;v_provider uuid;
begin if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if char_length(trim(coalesce(p_response,'')))>3000 then raise exception 'REVIEW_RESPONSE_TOO_LONG';end if;
 select r.product_id,e.marca_id into v_product,v_provider from kombax_reputation.product_reviews r join public.kombax_showcase_elementos e on e.id=r.product_id where r.id=p_review_id;
 if v_product is null or not public.app_kombax_showcase_puede_gestionar_v045(v_provider) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED';end if;
 update kombax_reputation.product_reviews set seller_response=nullif(trim(p_response),''),seller_response_by=case when trim(coalesce(p_response,''))='' then null else v_uid end,seller_response_at=case when trim(coalesce(p_response,''))='' then null else now() end,updated_at=now() where id=p_review_id;
 return jsonb_build_object('ok',true,'review_id',p_review_id);end $$;
revoke all on function public.app_kombax_showcase_review_respond_r72(uuid,text) from public,anon;
grant execute on function public.app_kombax_showcase_review_respond_r72(uuid,text) to authenticated;

create or replace function public.app_kombax_showcase_seller_reviews_r72(p_provider_id uuid,p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_reviews jsonb;v_summary jsonb;
begin if auth.uid() is null or not public.app_kombax_showcase_puede_gestionar_v045(p_provider_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED';end if;
 select jsonb_build_object('average',coalesce(round(avg(r.rating)::numeric,2),0),'total',count(*),'verified_total',count(*) filter(where r.verified_purchase),'unanswered',count(*) filter(where r.seller_response is null)) into v_summary from kombax_reputation.product_reviews r join public.kombax_showcase_elementos e on e.id=r.product_id where e.marca_id=p_provider_id and r.status in('active','reported');
 select coalesce(jsonb_agg(jsonb_build_object('id',r.id,'product_id',e.id,'product_name',e.nombre,'rating',r.rating,'body',r.body,'media',r.media,'verified_purchase',r.verified_purchase,'seller_response',r.seller_response,'created_at',r.created_at,'author_name',trim(concat_ws(' ',p.nombre,p.apellidos))) order by r.created_at desc),'[]'::jsonb) into v_reviews from kombax_reputation.product_reviews r join public.kombax_showcase_elementos e on e.id=r.product_id join public.perfiles p on p.id=r.reviewer_user_id where e.marca_id=p_provider_id and r.status in('active','reported') limit least(greatest(coalesce(p_limit,100),1),200);
 return jsonb_build_object('provider_id',p_provider_id,'summary',v_summary,'reviews',v_reviews);end $$;
revoke all on function public.app_kombax_showcase_seller_reviews_r72(uuid,integer) from public,anon;
grant execute on function public.app_kombax_showcase_seller_reviews_r72(uuid,integer) to authenticated;

-- ---------------------------------------------------------------------------
commit;
