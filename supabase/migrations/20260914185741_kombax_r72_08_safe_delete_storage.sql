-- KOMBAX R72 / build 20123 live section 08
begin;
-- 8. Safe delete: hard-delete only when history is absent; otherwise retire.
-- ---------------------------------------------------------------------------
create or replace function public.app_kombax_showcase_mutate_v067(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;v_item_id uuid;v_item public.kombax_showcase_elementos;v_brand public.kombax_showcase_marcas;v_has_history boolean:=false;
begin
 if p_operation<>'kombax.showcase.elemento.eliminar' then return public.app_kombax_showcase_mutate_v054(p_operation,p_payload,p_request_id);end if;
 if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
 select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
 if v_existing.request_id is not null then if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;if v_existing.result is not null then return v_existing.result;end if;
 else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,nullif(v_payload->>'club_id','')::uuid,p_operation);end if;
 begin v_item_id:=(v_payload->>'elemento_id')::uuid;exception when others then raise exception 'SHOWCASE_ITEM_INVALID';end;
 select * into v_item from public.kombax_showcase_elementos where id=v_item_id for update;if v_item.id is null or not public.app_kombax_showcase_puede_gestionar_v045(v_item.marca_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED';end if;select * into v_brand from public.kombax_showcase_marcas where id=v_item.marca_id;
 v_has_history:=exists(select 1 from kombax_payments.showcase_order_items where product_id=v_item.id) or exists(select 1 from kombax_reputation.product_reviews where product_id=v_item.id);
 if v_has_history then
   update public.kombax_showcase_elementos set estado='retirado',commerce_enabled=false,destacado=false,actualizado_en=now(),actualizado_por=v_uid where id=v_item.id;
   insert into public.kombax_actor_audit(actor_perfil_id,club_id,accion,objeto_tipo,objeto_id,detalle) values(v_uid,v_brand.club_id,'showcase.item.retire','showcase_item',v_item.id,jsonb_build_object('marca_id',v_item.marca_id,'history_preserved',true));
   v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('id',v_item.id,'deleted',false,'retired',true,'history_preserved',true));
 else
   delete from public.kombax_showcase_elementos where id=v_item.id;
   insert into public.kombax_actor_audit(actor_perfil_id,club_id,accion,objeto_tipo,objeto_id,detalle) values(v_uid,v_brand.club_id,'showcase.item.delete','showcase_item',v_item.id,jsonb_build_object('marca_id',v_item.marca_id,'history_preserved',false));
   v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('id',v_item.id,'deleted',true,'retired',false,'history_preserved',false,'imagen_url',v_item.imagen_url,'galeria',v_item.galeria));
 end if;
 update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;return v_result;
exception when others then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;end $$;
revoke all on function public.app_kombax_showcase_mutate_v067(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_showcase_mutate_v067(text,jsonb,uuid) to authenticated;

-- UGC review/community media uses a user-owned public path.
drop policy if exists kombax_reputation_media_insert_r72 on storage.objects;
create policy kombax_reputation_media_insert_r72 on storage.objects for insert to authenticated with check(
 bucket_id='kombax-public-media' and array_length(storage.foldername(name),1)>=4
 and (storage.foldername(name))[1]=auth.uid()::text and (storage.foldername(name))[2]='reputation'
);
drop policy if exists kombax_reputation_media_delete_r72 on storage.objects;
create policy kombax_reputation_media_delete_r72 on storage.objects for delete to authenticated using(
 bucket_id='kombax-public-media' and array_length(storage.foldername(name),1)>=4
 and (storage.foldername(name))[1]=auth.uid()::text and (storage.foldername(name))[2]='reputation'
);


-- ---------------------------------------------------------------------------
commit;
