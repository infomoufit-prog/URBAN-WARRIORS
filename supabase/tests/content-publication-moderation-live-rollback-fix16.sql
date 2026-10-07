begin;
insert into public.kombax_platform_admin_sessions(perfil_id,auth_session_id) values('23d246d2-7930-45b9-b09c-0086b9291166','QA_FIX16_ROLLBACK');
select set_config('request.jwt.claim.sub','369abf28-93d7-40a6-a589-cd10cae7ea67',true);
set local role authenticated;
do $qa$
declare club uuid:='4f5996fe-fe77-4f0b-b22c-06923b2e46a2'; social uuid:='a0c4b20a-5be7-46a5-8573-0515e89d6f7f'; brand uuid:='a19abed2-8c2a-4ca5-b3bc-de6da7ed560e'; category uuid:='5312db0c-f82b-4686-949a-5a0de9c24dd8'; owner_id uuid:='23d246d2-7930-45b9-b09c-0086b9291166'; actor uuid:='369abf28-93d7-40a6-a589-cd10cae7ea67'; out jsonb;post uuid;product uuid;event_id uuid;payload jsonb;stage text;feed_visible boolean;restricted_product uuid;blocked boolean:=false;
begin
stage:='social_publish';out:=public.app_kombax_social_mutate_v123('kombax.social.publicar',jsonb_build_object('club_id',club,'autor_perfil_id',social,'tipo','actualizacion','texto','QA_FIX16_SOCIAL_ROLLBACK','audiencia','publica','comentarios_estado','open'),gen_random_uuid());post:=(out#>>'{data,id}')::uuid;
if post is null then raise exception 'POST_NOT_CREATED';end if;
stage:='showcase_workspace';select x.id into brand from public.app_kombax_showcase_mis_espacios_v048(club) x where x.sujeto_tipo='club' and x.slug='club-sant-pedro-urban-warrios' limit 1;if brand is null then raise exception 'STORE_NOT_AVAILABLE';end if;
stage:='showcase_draft';out:=public.app_kombax_showcase_mutate_v067('kombax.showcase.elemento.guardar',jsonb_build_object('club_id',club,'marca_id',brand,'categoria_id',category,'slug','qa-fix16-camiseta-rollback','nombre','QA_FIX16_CAMISETA_ROLLBACK','descripcion','Camiseta de algodón; prueba revertida','galeria','[]'::jsonb,'precio_orientativo',20,'moneda','EUR'),gen_random_uuid());product:=(out#>>'{data,id}')::uuid;
if product is null then raise exception 'PRODUCT_NOT_CREATED';end if;
stage:='showcase_compliance';out:=public.app_showcase_product_compliance_mutate_r630(product,jsonb_build_object('category_code','general_goods','manufacturer_name','QA fabricante','manufacturer_postal_address','Calle QA 123 Girona','manufacturer_email','qa@example.invalid','manufacturer_country','ES','manufacturer_in_eu',true,'compliance_documents','[]'::jsonb),gen_random_uuid());if coalesce((out->>'commerce_ready')::boolean,false) is not true then raise exception 'PRODUCT_COMPLIANCE_NOT_READY: %',out;end if;
stage:='showcase_publish';out:=public.app_kombax_showcase_mutate_v067('kombax.showcase.elemento.estado',jsonb_build_object('club_id',club,'elemento_id',product,'estado','publicado'),gen_random_uuid());
if not exists(select 1 from public.app_kombax_showcase_list_v054('QA_FIX16_CAMISETA_ROLLBACK') x where x.id=product) then raise exception 'PUBLISHED_PRODUCT_NOT_PUBLIC';end if;
stage:='restricted_draft';out:=public.app_kombax_showcase_mutate_v067('kombax.showcase.elemento.guardar',jsonb_build_object('club_id',club,'marca_id',brand,'categoria_id',category,'slug','qa-fix16-restricted-rollback','nombre','QA_FIX16_RESTRICTED_ROLLBACK','descripcion','QA equipo protector revertido','galeria','[]'::jsonb,'precio_orientativo',20,'moneda','EUR'),gen_random_uuid());restricted_product:=(out#>>'{data,id}')::uuid;
out:=public.app_showcase_product_compliance_mutate_r630(restricted_product,jsonb_build_object('category_code','protective_equipment','manufacturer_name','QA fabricante','manufacturer_postal_address','Calle QA 123 Girona','manufacturer_email','qa@example.invalid','manufacturer_country','ES','manufacturer_in_eu',true,'safety_warnings','QA documento de prueba revertida','compliance_documents','[{"url":"https://example.invalid/qa.pdf"}]'::jsonb),gen_random_uuid());
if coalesce((out->>'commerce_ready')::boolean,false) then raise exception 'RESTRICTED_PRODUCT_AUTO_APPROVED';end if;
begin
perform public.app_kombax_showcase_mutate_v067('kombax.showcase.elemento.estado',jsonb_build_object('club_id',club,'elemento_id',restricted_product,'estado','publicado'),gen_random_uuid());
exception when others then if SQLERRM like '%SHOWCASE_PRODUCT_COMPLIANCE_REQUIRED%' then blocked:=true;else raise;end if;end;
if not blocked then raise exception 'RESTRICTED_PRODUCT_NOT_BLOCKED';end if;
begin perform public.app_kombax_compliance_owner_product_review_r630(restricted_product,'approve','QA review denied to seller',gen_random_uuid());raise exception 'SELLER_APPROVED_SELF';exception when others then if SQLERRM not like '%PLATFORM_ADMIN_REQUIRED%' then raise;end if;end;

stage:='event_draft';payload:=jsonb_build_object('workspace_club_id',club,'sujeto_tipo','club','sujeto_id',club,'nombre','QA_FIX16_EVENT_ROLLBACK','tipo','seminario','estado','borrador','fecha_inicio','2026-11-01T10:00:00Z','fecha_fin','2026-11-01T12:00:00Z','descripcion','Prueba revertida','pais','España','municipio','Girona');
out:=public.app_kombax_eventos_mutate_v253('event.save',payload,gen_random_uuid());event_id:=(out#>>'{data,id}')::uuid;
if event_id is null then raise exception 'EVENT_NOT_CREATED';end if;
stage:='event_publish';out:=public.app_kombax_eventos_mutate_v253('event.save',payload||jsonb_build_object('id',event_id,'estado','publicado'),gen_random_uuid());
if out#>>'{data,estado}' is distinct from 'publicado' then raise exception 'EVENT_NOT_PUBLISHED';end if;
stage:='owner_hide';perform set_config('request.jwt.claim.sub',owner_id::text,true);perform set_config('request.jwt.claims',jsonb_build_object('sub',owner_id,'aal','aal2','session_id','QA_FIX16_ROLLBACK')::text,true);
out:=public.app_kombax_compliance_owner_product_review_r630(restricted_product,'approve','QA manual review reverted',gen_random_uuid());if out#>>'{data,moderation_state}' is distinct from 'approved' then raise exception 'OWNER_REVIEW_FAILED';end if;
out:=public.app_kombax_content_action_r118('social',post,'hide','Prueba de moderación revertida', '{}'::jsonb,'');
if exists(select 1 from public.app_kombax_social_feed_v238(null,null,null,100) x where x.id=post) then raise exception 'HIDDEN_POST_STILL_PUBLIC';end if;
out:=public.app_kombax_content_action_r118('showcase',product,'hide','Prueba de moderación revertida','{}'::jsonb,'');
if exists(select 1 from public.app_kombax_showcase_list_v054('QA_FIX16_CAMISETA_ROLLBACK') x where x.id=product) then raise exception 'HIDDEN_PRODUCT_STILL_PUBLIC';end if;
stage:='owner_delete';out:=public.app_kombax_content_action_r118('social',post,'delete','Prueba de eliminación revertida','{}'::jsonb,'ELIMINAR');
if coalesce((out->>'permanently_deleted')::boolean,false) is not true then raise exception 'POST_NOT_PURGED';end if;
out:=public.app_kombax_content_action_r118('showcase',product,'delete','Prueba de eliminación revertida','{}'::jsonb,'ELIMINAR');
if exists(select 1 from public.app_kombax_showcase_list_v054('QA_FIX16_CAMISETA_ROLLBACK') x where x.id=product) then raise exception 'DELETED_PRODUCT_STILL_PUBLIC';end if;
out:=public.app_kombax_content_action_r118('showcase',restricted_product,'delete','Prueba de eliminación revertida','{}'::jsonb,'ELIMINAR');
perform set_config('kombax.qa_fix16_content',jsonb_build_object('ok',true,'role',current_user,'social_publish',true,'showcase_create_publish_public',true,'event_create_publish',true,'owner_hide_absent_from_public_feeds',true,'owner_delete_absent_from_public_feeds',true,'restricted_product_blocks_publication',true,'seller_cannot_self_approve',true,'owner_manual_product_review',true,'payments_executed',false)::text,true);
exception when others then raise exception 'QA_FIX16_STAGE_%: %',stage,SQLERRM;
end $qa$;
select current_setting('kombax.qa_fix16_content',true)::jsonb result;
rollback;
