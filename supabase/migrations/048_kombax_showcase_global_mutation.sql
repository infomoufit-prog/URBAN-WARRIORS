begin;

-- KOMBAX 048 · Showcase global: una Marca verificada no depende de pertenecer a un Club.
create or replace function public.app_kombax_showcase_ensure_brand_v048(p_perfil_directo_id uuid)
returns uuid language plpgsql security definer set search_path=public,auth as $$
declare v_id uuid;v_d public.perfiles_kombax_directos;
begin
  select * into v_d from public.perfiles_kombax_directos where id=p_perfil_directo_id;
  if v_d.id is null or v_d.tipo<>'marca' or v_d.estado<>'activo' or v_d.verificacion_estado<>'verificado' then raise exception 'SHOWCASE_VERIFIED_BRAND_REQUIRED';end if;
  if v_d.perfil_id<>auth.uid() and not public.app_kombax_es_moderador_v041() then raise exception 'SHOWCASE_BRAND_OWNERSHIP_REQUIRED';end if;
  select id into v_id from public.kombax_showcase_marcas where sujeto_tipo='marca' and perfil_directo_id=v_d.id;
  if v_id is null then
    insert into public.kombax_showcase_marcas(sujeto_tipo,perfil_directo_id,slug,nombre,descripcion,logo_url,banner_url,web_url,contacto_url,verificada,estado,creada_por)
    values('marca',v_d.id,v_d.slug,v_d.nombre_publico,v_d.descripcion,
      null,
      null,
      v_d.web_publica,v_d.web_publica,true,'publicada',auth.uid()) returning id into v_id;
    insert into public.kombax_showcase_gestores(marca_id,perfil_id,rol,asignado_por) values(v_id,v_d.perfil_id,'responsable',auth.uid()) on conflict do nothing;
  end if;
  return v_id;
end $$;
revoke all on function public.app_kombax_showcase_ensure_brand_v048(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_ensure_brand_v048(uuid) to authenticated;

create or replace function public.app_kombax_showcase_mis_espacios_v048(p_club_id uuid default null)
returns table(id uuid,sujeto_tipo text,slug text,nombre text,descripcion text,logo_url text,banner_url text,web_url text,contacto_url text,verificada boolean,estado text,limite_visible integer,publicados integer)
language plpgsql security definer set search_path=public,auth as $$
declare r record;v_id uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  if p_club_id is not null and public.app_puede_gestionar_perfil_club_v035(p_club_id) then v_id:=public.app_kombax_showcase_ensure_club_v045(p_club_id);end if;
  for r in select d.id from public.perfiles_kombax_directos d where d.perfil_id=auth.uid() and d.tipo='marca' and d.estado='activo' and d.verificacion_estado='verificado' loop
    v_id:=public.app_kombax_showcase_ensure_brand_v048(r.id);
  end loop;
  return query select m.id,m.sujeto_tipo,m.slug,m.nombre,m.descripcion,m.logo_url,m.banner_url,m.web_url,m.contacto_url,m.verificada,m.estado,
    case m.sujeto_tipo when 'club' then 15 else 30 end,
    (select count(*)::integer from public.kombax_showcase_elementos e where e.marca_id=m.id and e.estado='publicado')
  from public.kombax_showcase_marcas m where public.app_kombax_showcase_puede_gestionar_v045(m.id) order by case m.sujeto_tipo when 'club' then 0 else 1 end,m.nombre;
end $$;
revoke all on function public.app_kombax_showcase_mis_espacios_v048(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_mis_espacios_v048(uuid) to authenticated;

create or replace function public.app_kombax_showcase_mutate_v048(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;v_brand public.kombax_showcase_marcas;v_element public.kombax_showcase_elementos;v_brand_id uuid;v_id uuid;v_category uuid;v_profile uuid;v_state text;v_gallery jsonb;v_club uuid;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;
  begin v_club:=nullif(v_payload->>'club_id','')::uuid;exception when others then raise exception 'MUTATION_INVALID_CLUB_ID';end;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;if v_existing.result is not null then return v_existing.result;end if;
  else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,v_club,p_operation);end if;

  if p_operation='kombax.showcase.marca.guardar' then
    begin v_id:=nullif(v_payload->>'id','')::uuid;v_profile:=nullif(v_payload->>'perfil_directo_id','')::uuid;exception when others then raise exception 'SHOWCASE_BRAND_INVALID';end;
    if v_id is null then v_id:=public.app_kombax_showcase_ensure_brand_v048(v_profile);end if;
    if not public.app_kombax_showcase_puede_gestionar_v045(v_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED';end if;
    update public.kombax_showcase_marcas set nombre=coalesce(nullif(btrim(v_payload->>'nombre'),''),nombre),descripcion=nullif(btrim(v_payload->>'descripcion'),''),logo_url=nullif(btrim(v_payload->>'logo_url'),''),banner_url=nullif(btrim(v_payload->>'banner_url'),''),web_url=nullif(btrim(v_payload->>'web_url'),''),contacto_url=nullif(btrim(v_payload->>'contacto_url'),''),actualizado_en=now() where id=v_id returning * into v_brand;v_result:=to_jsonb(v_brand);
  elsif p_operation='kombax.showcase.marca.estado' then
    if not public.app_kombax_es_moderador_v041() then raise exception 'KOMBAX_MODERATOR_REQUIRED';end if;
    begin v_id:=(v_payload->>'marca_id')::uuid;exception when others then raise exception 'SHOWCASE_PROVIDER_INVALID';end;
    v_state:=lower(coalesce(v_payload->>'estado',''));if v_state not in ('borrador','publicada','suspendida','cerrada') then raise exception 'SHOWCASE_PROVIDER_STATE_INVALID';end if;
    update public.kombax_showcase_marcas set estado=v_state,verificada=coalesce((v_payload->>'verificada')::boolean,verificada),actualizado_en=now() where id=v_id returning * into v_brand;
    if v_brand.id is null then raise exception 'SHOWCASE_PROVIDER_NOT_FOUND';end if;v_result:=jsonb_build_object('id',v_brand.id,'estado',v_brand.estado,'verificada',v_brand.verificada);
  elsif p_operation='kombax.showcase.elemento.guardar' then
    begin v_id:=nullif(v_payload->>'id','')::uuid;v_brand_id:=(v_payload->>'marca_id')::uuid;v_category:=nullif(v_payload->>'categoria_id','')::uuid;exception when others then raise exception 'SHOWCASE_ITEM_INVALID';end;
    if not public.app_kombax_showcase_puede_gestionar_v045(v_brand_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED';end if;
    v_gallery:=coalesce(v_payload->'galeria','[]'::jsonb);if jsonb_typeof(v_gallery)<>'array' or jsonb_array_length(v_gallery)>3 then raise exception 'SHOWCASE_GALLERY_MAX_3_ADDITIONAL';end if;
    if v_id is null then
      insert into public.kombax_showcase_elementos(marca_id,categoria_id,slug,nombre,resumen,descripcion,imagen_url,galeria,precio_orientativo,moneda,visitar_url,donde_encontrar_url,contacto_url,creado_por,actualizado_por)
      values(v_brand_id,v_category,lower(btrim(v_payload->>'slug')),btrim(v_payload->>'nombre'),nullif(btrim(v_payload->>'resumen'),''),nullif(btrim(v_payload->>'descripcion'),''),nullif(btrim(v_payload->>'imagen_url'),''),v_gallery,nullif(v_payload->>'precio_orientativo','')::numeric,upper(coalesce(nullif(v_payload->>'moneda',''),'EUR')),nullif(btrim(v_payload->>'visitar_url'),''),nullif(btrim(v_payload->>'donde_encontrar_url'),''),nullif(btrim(v_payload->>'contacto_url'),''),v_uid,v_uid) returning * into v_element;
    else
      select * into v_element from public.kombax_showcase_elementos where id=v_id and marca_id=v_brand_id for update;if v_element.id is null then raise exception 'SHOWCASE_ITEM_NOT_FOUND';end if;
      update public.kombax_showcase_elementos set categoria_id=v_category,nombre=btrim(v_payload->>'nombre'),resumen=nullif(btrim(v_payload->>'resumen'),''),descripcion=nullif(btrim(v_payload->>'descripcion'),''),imagen_url=nullif(btrim(v_payload->>'imagen_url'),''),galeria=v_gallery,precio_orientativo=nullif(v_payload->>'precio_orientativo','')::numeric,moneda=upper(coalesce(nullif(v_payload->>'moneda',''),'EUR')),visitar_url=nullif(btrim(v_payload->>'visitar_url'),''),donde_encontrar_url=nullif(btrim(v_payload->>'donde_encontrar_url'),''),contacto_url=nullif(btrim(v_payload->>'contacto_url'),''),actualizado_por=v_uid,actualizado_en=now() where id=v_id returning * into v_element;
    end if;v_result:=to_jsonb(v_element);
  elsif p_operation='kombax.showcase.elemento.estado' then
    begin v_id:=(v_payload->>'elemento_id')::uuid;exception when others then raise exception 'SHOWCASE_ITEM_INVALID';end;
    select * into v_element from public.kombax_showcase_elementos where id=v_id for update;if v_element.id is null or not public.app_kombax_showcase_puede_gestionar_v045(v_element.marca_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED';end if;
    v_state:=lower(coalesce(v_payload->>'estado',''));if v_state not in ('borrador','publicado','archivado') then raise exception 'SHOWCASE_ITEM_STATE_INVALID';end if;
    update public.kombax_showcase_elementos set estado=v_state,publicado_en=case when v_state='publicado' then coalesce(publicado_en,now()) else publicado_en end,destacado=case when public.app_kombax_es_moderador_v041() then coalesce((v_payload->>'destacado')::boolean,destacado) else false end,etiqueta_destacada=case when public.app_kombax_es_moderador_v041() then left(nullif(btrim(v_payload->>'etiqueta_destacada'),''),80) else null end,actualizado_por=v_uid,actualizado_en=now() where id=v_id returning * into v_element;v_result:=jsonb_build_object('id',v_element.id,'estado',v_element.estado,'destacado',v_element.destacado);
  else raise exception 'SHOWCASE_OPERATION_NOT_ALLOWED';end if;
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;return v_result;
exception when others then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;
end $$;
revoke all on function public.app_kombax_showcase_mutate_v048(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_showcase_mutate_v048(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
