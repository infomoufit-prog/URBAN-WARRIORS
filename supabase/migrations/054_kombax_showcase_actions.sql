-- KOMBAX build 20028 · 054 · Showcase accionable sin comercio transaccional.
begin;

alter table public.kombax_showcase_elementos
  add column if not exists cta_tipo text not null default 'info',
  add column if not exists cta_label text;
alter table public.kombax_showcase_elementos drop constraint if exists kombax_showcase_elementos_cta_tipo_check;
alter table public.kombax_showcase_elementos add constraint kombax_showcase_elementos_cta_tipo_check
  check(cta_tipo in ('info','contact','shop','web','where'));
alter table public.kombax_showcase_elementos drop constraint if exists kombax_showcase_elementos_cta_label_check;
alter table public.kombax_showcase_elementos add constraint kombax_showcase_elementos_cta_label_check
  check(char_length(coalesce(cta_label,''))<=80);

create table if not exists public.kombax_showcase_guardados(
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  elemento_id uuid not null references public.kombax_showcase_elementos(id) on delete cascade,
  creado_en timestamptz not null default now(),
  primary key(perfil_id,elemento_id)
);
create index if not exists idx_showcase_guardados_profile_v054 on public.kombax_showcase_guardados(perfil_id,creado_en desc);
alter table public.kombax_showcase_guardados enable row level security;
revoke all on public.kombax_showcase_guardados from public,anon,authenticated;

-- Subida de imágenes de Showcase: auth.uid()/showcase/marca_id/uuid.ext.
drop policy if exists kombax_showcase_media_insert_v054 on storage.objects;
create policy kombax_showcase_media_insert_v054 on storage.objects for insert to authenticated with check(
  bucket_id='kombax-public-media' and array_length(storage.foldername(name),1)>=4
  and (storage.foldername(name))[1]=auth.uid()::text and (storage.foldername(name))[2]='showcase'
  and public.app_kombax_showcase_puede_gestionar_v045(((storage.foldername(name))[3])::uuid)
);
drop policy if exists kombax_showcase_media_delete_v054 on storage.objects;
create policy kombax_showcase_media_delete_v054 on storage.objects for delete to authenticated using(
  bucket_id='kombax-public-media' and array_length(storage.foldername(name),1)>=4
  and (storage.foldername(name))[2]='showcase'
  and public.app_kombax_showcase_puede_gestionar_v045(((storage.foldername(name))[3])::uuid)
);

create or replace function public.app_kombax_showcase_list_v054(
  p_query text default '',p_categoria text default null,p_cursor timestamptz default null,p_cursor_id uuid default null,p_limit integer default 24
)
returns table(
  id uuid,slug text,nombre text,resumen text,descripcion text,imagen_url text,galeria jsonb,precio_orientativo numeric,moneda text,
  visitar_url text,donde_encontrar_url text,contacto_url text,destacado boolean,etiqueta_destacada text,publicado_en timestamptz,
  marca_id uuid,marca_slug text,marca_nombre text,marca_logo_url text,marca_verificada boolean,categoria_slug text,categoria_nombre text,
  cta_tipo text,cta_label text,guardado boolean,proveedor_social_id uuid,sujeto_tipo text
)
language sql stable security definer set search_path=public,auth as $$
  select e.id,e.slug,e.nombre,e.resumen,e.descripcion,e.imagen_url,e.galeria,e.precio_orientativo,e.moneda,
    e.visitar_url,e.donde_encontrar_url,e.contacto_url,e.destacado,e.etiqueta_destacada,e.publicado_en,
    m.id,m.slug,m.nombre,m.logo_url,m.verificada,c.slug,c.nombre,e.cta_tipo,e.cta_label,
    case when auth.uid() is null then false else exists(select 1 from public.kombax_showcase_guardados g where g.perfil_id=auth.uid() and g.elemento_id=e.id) end,
    case when m.sujeto_tipo='club' then (select sp.id from public.kombax_social_perfiles sp where sp.sujeto_tipo='club' and sp.club_id=m.club_id and sp.estado='activo' limit 1)
         else (select sp.id from public.kombax_social_perfiles sp where sp.sujeto_tipo='perfil_directo' and sp.perfil_directo_id=m.perfil_directo_id and sp.estado='activo' limit 1) end,
    m.sujeto_tipo
  from public.kombax_showcase_elementos e
  join public.kombax_showcase_marcas m on m.id=e.marca_id and m.estado='publicada'
  left join public.kombax_showcase_categorias c on c.id=e.categoria_id
  where e.estado='publicado'
    and (nullif(btrim(coalesce(p_query,'')),'') is null or e.nombre ilike '%'||btrim(p_query)||'%' or coalesce(e.resumen,'') ilike '%'||btrim(p_query)||'%' or m.nombre ilike '%'||btrim(p_query)||'%')
    and (p_categoria is null or c.slug=p_categoria)
    and (p_cursor is null or e.publicado_en<p_cursor or (e.publicado_en=p_cursor and e.id<p_cursor_id))
  order by e.destacado desc,e.publicado_en desc,e.id desc
  limit least(greatest(coalesce(p_limit,24),1),24);
$$;
revoke all on function public.app_kombax_showcase_list_v054(text,text,timestamptz,uuid,integer) from public;
grant execute on function public.app_kombax_showcase_list_v054(text,text,timestamptz,uuid,integer) to anon,authenticated;

create or replace function public.app_kombax_showcase_guardados_v054(p_limit integer default 100)
returns table(id uuid,nombre text,resumen text,imagen_url text,precio_orientativo numeric,moneda text,marca_nombre text,cta_tipo text,cta_label text,guardado_en timestamptz)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED';end if;
  return query
    select e.id,e.nombre,e.resumen,e.imagen_url,e.precio_orientativo,e.moneda,m.nombre,e.cta_tipo,e.cta_label,g.creado_en
    from public.kombax_showcase_guardados g join public.kombax_showcase_elementos e on e.id=g.elemento_id
    join public.kombax_showcase_marcas m on m.id=e.marca_id
    where g.perfil_id=auth.uid() and e.estado='publicado' and m.estado='publicada'
    order by g.creado_en desc limit least(greatest(coalesce(p_limit,100),1),200);
end $$;
revoke all on function public.app_kombax_showcase_guardados_v054(integer) from public,anon;
grant execute on function public.app_kombax_showcase_guardados_v054(integer) to authenticated;

create or replace function public.app_kombax_showcase_mis_elementos_v054(p_marca_id uuid)
returns table(
  id uuid,marca_id uuid,categoria_id uuid,slug text,nombre text,resumen text,descripcion text,imagen_url text,galeria jsonb,
  precio_orientativo numeric,moneda text,visitar_url text,donde_encontrar_url text,contacto_url text,estado text,destacado boolean,
  etiqueta_destacada text,publicado_en timestamptz,actualizado_en timestamptz,cta_tipo text,cta_label text
)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if auth.uid() is null or not public.app_kombax_showcase_puede_gestionar_v045(p_marca_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED';end if;
  return query
    select e.id,e.marca_id,e.categoria_id,e.slug,e.nombre,e.resumen,e.descripcion,e.imagen_url,e.galeria,e.precio_orientativo,e.moneda,
      e.visitar_url,e.donde_encontrar_url,e.contacto_url,e.estado,e.destacado,e.etiqueta_destacada,e.publicado_en,e.actualizado_en,e.cta_tipo,e.cta_label
    from public.kombax_showcase_elementos e
    where e.marca_id=p_marca_id
    order by e.actualizado_en desc,e.id;
end $$;
revoke all on function public.app_kombax_showcase_mis_elementos_v054(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_mis_elementos_v054(uuid) to authenticated;

create or replace function public.app_kombax_showcase_mutate_v054(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare
  v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_existing public.app_mutation_requests;v_result jsonb;v_old jsonb;
  v_item_id uuid;v_item public.kombax_showcase_elementos;v_active boolean;v_cta text;v_label text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED';end if;
  if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED';end if;

  if p_operation='kombax.showcase.elemento.guardar' then
    v_cta:=lower(coalesce(nullif(v_payload->>'cta_tipo',''),'info'));
    if v_cta not in ('info','contact','shop','web','where') then raise exception 'SHOWCASE_CTA_INVALID';end if;
    v_label:=left(nullif(btrim(v_payload->>'cta_label'),''),80);
    if v_cta='shop' and nullif(btrim(v_payload->>'visitar_url'),'') is null then raise exception 'SHOWCASE_SHOP_URL_REQUIRED';end if;
    if v_cta='web' and nullif(btrim(v_payload->>'visitar_url'),'') is null then raise exception 'SHOWCASE_WEB_URL_REQUIRED';end if;
    if v_cta='where' and nullif(btrim(v_payload->>'donde_encontrar_url'),'') is null then raise exception 'SHOWCASE_WHERE_URL_REQUIRED';end if;
    v_old:=public.app_kombax_showcase_mutate_v048(p_operation,v_payload,p_request_id);
    v_item_id:=nullif(v_old#>>'{data,id}','')::uuid;
    if v_item_id is not null then
      update public.kombax_showcase_elementos set cta_tipo=v_cta,cta_label=v_label,actualizado_en=now() where id=v_item_id returning * into v_item;
      insert into public.kombax_actor_audit(actor_perfil_id,club_id,accion,objeto_tipo,objeto_id,detalle)
      select v_uid,m.club_id,'showcase.item.save','showcase_item',v_item.id,jsonb_build_object('cta_tipo',v_cta)
      from public.kombax_showcase_marcas m where m.id=v_item.marca_id;
      v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',to_jsonb(v_item));
      update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
      return v_result;
    end if;
    return v_old;
  end if;

  if p_operation not in ('kombax.showcase.guardar','kombax.showcase.desguardar') then
    return public.app_kombax_showcase_mutate_v048(p_operation,p_payload,p_request_id);
  end if;

  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then
    if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;
    if v_existing.result is not null then return v_existing.result;end if;
  else
    insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,nullif(v_payload->>'club_id','')::uuid,p_operation);
  end if;

  begin v_item_id:=(v_payload->>'elemento_id')::uuid;exception when others then raise exception 'SHOWCASE_ITEM_INVALID';end;
  if not exists(select 1 from public.kombax_showcase_elementos e join public.kombax_showcase_marcas m on m.id=e.marca_id where e.id=v_item_id and e.estado='publicado' and m.estado='publicada') then raise exception 'SHOWCASE_ITEM_NOT_PUBLIC';end if;
  v_active:=p_operation='kombax.showcase.guardar';
  if v_active then insert into public.kombax_showcase_guardados(perfil_id,elemento_id) values(v_uid,v_item_id) on conflict do nothing;
  else delete from public.kombax_showcase_guardados where perfil_id=v_uid and elemento_id=v_item_id;end if;
  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',jsonb_build_object('elemento_id',v_item_id,'guardado',v_active));
  update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;
  return v_result;
exception when others then
  delete from public.app_mutation_requests where request_id=p_request_id and result is null;
  raise;
end $$;
revoke all on function public.app_kombax_showcase_mutate_v054(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_showcase_mutate_v054(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
