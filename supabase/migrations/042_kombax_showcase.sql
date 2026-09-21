-- KOMBAX RC13 build 20025 · Showcase informativo global.
-- No procesa compras, operaciones de venta ni logística.

begin;

create table if not exists public.kombax_showcase_marcas(
  id uuid primary key default gen_random_uuid(),
  perfil_directo_id uuid unique references public.perfiles_kombax_directos(id) on delete set null,
  slug text not null unique check(slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  nombre text not null check(char_length(nombre) between 1 and 160),
  descripcion text check(char_length(coalesce(descripcion,''))<=1600),
  logo_url text,
  banner_url text,
  web_url text,
  contacto_url text,
  verificada boolean not null default false,
  estado text not null default 'borrador' check(estado in ('borrador','publicada','suspendida','cerrada')),
  creada_por uuid not null references public.perfiles(id) on delete restrict,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);
create index if not exists idx_showcase_marcas_estado_v042 on public.kombax_showcase_marcas(estado,verificada,nombre);

create table if not exists public.kombax_showcase_gestores(
  marca_id uuid not null references public.kombax_showcase_marcas(id) on delete cascade,
  perfil_id uuid not null references public.perfiles(id) on delete cascade,
  rol text not null default 'editor' check(rol in ('responsable','editor')),
  activo boolean not null default true,
  asignado_por uuid not null references public.perfiles(id) on delete restrict,
  creado_en timestamptz not null default now(),
  primary key(marca_id,perfil_id)
);

create table if not exists public.kombax_showcase_categorias(
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check(slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  nombre text not null unique check(char_length(nombre) between 1 and 100),
  descripcion text check(char_length(coalesce(descripcion,''))<=500),
  orden integer not null default 0,
  activa boolean not null default true
);
insert into public.kombax_showcase_categorias(slug,nombre,descripcion,orden) values
  ('equipamiento','Equipamiento','Material de entrenamiento y competición',10),
  ('protecciones','Protecciones','Protección deportiva para disciplinas de contacto',20),
  ('textil','Textil','Ropa técnica y de representación',30),
  ('nutricion','Nutrición deportiva','Información de productos especializados',40),
  ('tecnologia','Tecnología','Herramientas y tecnología aplicada al entrenamiento',50),
  ('servicios','Servicios profesionales','Servicios vinculados al ecosistema deportivo',60)
on conflict(slug) do update set nombre=excluded.nombre,descripcion=excluded.descripcion,orden=excluded.orden;

create table if not exists public.kombax_showcase_elementos(
  id uuid primary key default gen_random_uuid(),
  marca_id uuid not null references public.kombax_showcase_marcas(id) on delete cascade,
  categoria_id uuid references public.kombax_showcase_categorias(id) on delete set null,
  slug text not null check(slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  nombre text not null check(char_length(nombre) between 1 and 180),
  resumen text check(char_length(coalesce(resumen,''))<=320),
  descripcion text check(char_length(coalesce(descripcion,''))<=3000),
  imagen_url text,
  galeria jsonb not null default '[]'::jsonb check(jsonb_typeof(galeria)='array' and jsonb_array_length(galeria)<=8),
  precio_orientativo numeric(12,2) check(precio_orientativo is null or precio_orientativo>=0),
  moneda text not null default 'EUR' check(moneda ~ '^[A-Z]{3}$'),
  visitar_url text,
  donde_encontrar_url text,
  contacto_url text,
  estado text not null default 'borrador' check(estado in ('borrador','publicado','archivado','oculto')),
  destacado boolean not null default false,
  etiqueta_destacada text check(char_length(coalesce(etiqueta_destacada,''))<=80),
  publicado_en timestamptz,
  creado_por uuid not null references public.perfiles(id) on delete restrict,
  actualizado_por uuid references public.perfiles(id) on delete set null,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique(marca_id,slug)
);
create index if not exists idx_showcase_elementos_feed_v042 on public.kombax_showcase_elementos(estado,destacado desc,publicado_en desc,id desc);
create index if not exists idx_showcase_elementos_marca_v042 on public.kombax_showcase_elementos(marca_id,estado,actualizado_en desc);
create index if not exists idx_showcase_elementos_categoria_v042 on public.kombax_showcase_elementos(categoria_id,estado,publicado_en desc);

alter table public.kombax_showcase_marcas enable row level security;
alter table public.kombax_showcase_gestores enable row level security;
alter table public.kombax_showcase_categorias enable row level security;
alter table public.kombax_showcase_elementos enable row level security;
revoke all on public.kombax_showcase_marcas,public.kombax_showcase_gestores,public.kombax_showcase_categorias,public.kombax_showcase_elementos from public,anon,authenticated;

create or replace function public.app_kombax_showcase_url_v042(p_url text)
returns boolean language sql immutable set search_path=public as $$
  select nullif(btrim(coalesce(p_url,'')),'') is null or btrim(p_url) ~* '^https://[^[:space:]]+$';
$$;
revoke all on function public.app_kombax_showcase_url_v042(text) from public,anon,authenticated;

create or replace function public.app_kombax_showcase_validar_marca_v042()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.perfil_directo_id is not null and not exists(select 1 from public.perfiles_kombax_directos d where d.id=new.perfil_directo_id and d.tipo='marca') then raise exception 'SHOWCASE_BRAND_PROFILE_REQUIRED'; end if;
  if not public.app_kombax_showcase_url_v042(new.logo_url) or not public.app_kombax_showcase_url_v042(new.banner_url) or not public.app_kombax_showcase_url_v042(new.web_url) or not public.app_kombax_showcase_url_v042(new.contacto_url) then raise exception 'SHOWCASE_HTTPS_URL_REQUIRED'; end if;
  new.actualizado_en:=now();return new;
end $$;
revoke all on function public.app_kombax_showcase_validar_marca_v042() from public,anon,authenticated;
drop trigger if exists showcase_validar_marca_v042 on public.kombax_showcase_marcas;
create trigger showcase_validar_marca_v042 before insert or update on public.kombax_showcase_marcas for each row execute function public.app_kombax_showcase_validar_marca_v042();

create or replace function public.app_kombax_showcase_validar_elemento_v042()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_item text;
begin
  if not public.app_kombax_showcase_url_v042(new.imagen_url) or not public.app_kombax_showcase_url_v042(new.visitar_url) or not public.app_kombax_showcase_url_v042(new.donde_encontrar_url) or not public.app_kombax_showcase_url_v042(new.contacto_url) then raise exception 'SHOWCASE_HTTPS_URL_REQUIRED'; end if;
  for v_item in select jsonb_array_elements_text(new.galeria) loop if not public.app_kombax_showcase_url_v042(v_item) then raise exception 'SHOWCASE_GALLERY_HTTPS_REQUIRED'; end if;end loop;
  new.actualizado_en:=now();return new;
end $$;
revoke all on function public.app_kombax_showcase_validar_elemento_v042() from public,anon,authenticated;
drop trigger if exists showcase_validar_elemento_v042 on public.kombax_showcase_elementos;
create trigger showcase_validar_elemento_v042 before insert or update on public.kombax_showcase_elementos for each row execute function public.app_kombax_showcase_validar_elemento_v042();

create or replace function public.app_kombax_showcase_puede_gestionar_v042(p_marca_id uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.app_kombax_es_moderador_v041()
    or exists(select 1 from public.kombax_showcase_gestores g where g.marca_id=p_marca_id and g.perfil_id=auth.uid() and g.activo)
    or exists(select 1 from public.kombax_showcase_marcas m join public.perfiles_kombax_directos d on d.id=m.perfil_directo_id join public.kombax_entitlements e on e.sujeto_tipo='perfil_directo' and e.sujeto_id=d.id and e.capacidad_clave='showcase.publish' and e.activa and e.inicia_en<=now() and (e.termina_en is null or e.termina_en>now()) where m.id=p_marca_id and d.perfil_id=auth.uid() and d.tipo='marca' and d.estado='activo' and d.verificacion_estado='verificado');
$$;
revoke all on function public.app_kombax_showcase_puede_gestionar_v042(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_puede_gestionar_v042(uuid) to authenticated;

create or replace function public.app_kombax_showcase_categorias_v042()
returns table(id uuid,slug text,nombre text,descripcion text,orden integer)
language sql stable security definer set search_path=public as $$
  select c.id,c.slug,c.nombre,c.descripcion,c.orden from public.kombax_showcase_categorias c where c.activa order by c.orden,c.nombre;
$$;
revoke all on function public.app_kombax_showcase_categorias_v042() from public;
grant execute on function public.app_kombax_showcase_categorias_v042() to anon,authenticated;

create or replace function public.app_kombax_showcase_list_v042(p_query text default '',p_categoria text default null,p_cursor timestamptz default null,p_cursor_id uuid default null,p_limit integer default 24)
returns table(id uuid,slug text,nombre text,resumen text,descripcion text,imagen_url text,galeria jsonb,precio_orientativo numeric,moneda text,visitar_url text,donde_encontrar_url text,contacto_url text,destacado boolean,etiqueta_destacada text,publicado_en timestamptz,marca_id uuid,marca_slug text,marca_nombre text,marca_logo_url text,marca_verificada boolean,categoria_slug text,categoria_nombre text)
language plpgsql stable security definer set search_path=public as $$
declare v_q text:=lower(btrim(coalesce(p_query,'')));v_category text:=nullif(lower(btrim(coalesce(p_categoria,''))), '');
begin
  return query select e.id,e.slug,e.nombre,e.resumen,e.descripcion,e.imagen_url,e.galeria,e.precio_orientativo,e.moneda,e.visitar_url,e.donde_encontrar_url,e.contacto_url,e.destacado,e.etiqueta_destacada,e.publicado_en,m.id,m.slug,m.nombre,m.logo_url,m.verificada,c.slug,c.nombre
  from public.kombax_showcase_elementos e join public.kombax_showcase_marcas m on m.id=e.marca_id left join public.kombax_showcase_categorias c on c.id=e.categoria_id
  where e.estado='publicado' and m.estado='publicada' and (v_category is null or c.slug=v_category)
    and (v_q='' or lower(e.nombre) like '%'||v_q||'%' or lower(coalesce(e.resumen,'')) like '%'||v_q||'%' or lower(m.nombre) like '%'||v_q||'%' or lower(coalesce(c.nombre,'')) like '%'||v_q||'%')
    and (p_cursor is null or p_cursor_id is null or (coalesce(e.publicado_en,e.creado_en),e.id)<(p_cursor,p_cursor_id))
  order by e.destacado desc,coalesce(e.publicado_en,e.creado_en) desc,e.id desc limit least(greatest(coalesce(p_limit,24),1),24);
end $$;
revoke all on function public.app_kombax_showcase_list_v042(text,text,timestamptz,uuid,integer) from public;
grant execute on function public.app_kombax_showcase_list_v042(text,text,timestamptz,uuid,integer) to anon,authenticated;

create or replace function public.app_kombax_showcase_mis_marcas_v042()
returns table(id uuid,slug text,nombre text,descripcion text,logo_url text,banner_url text,web_url text,contacto_url text,verificada boolean,estado text)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  return query select m.id,m.slug,m.nombre,m.descripcion,m.logo_url,m.banner_url,m.web_url,m.contacto_url,m.verificada,m.estado from public.kombax_showcase_marcas m where public.app_kombax_showcase_puede_gestionar_v042(m.id) order by m.nombre;
end $$;
revoke all on function public.app_kombax_showcase_mis_marcas_v042() from public,anon;
grant execute on function public.app_kombax_showcase_mis_marcas_v042() to authenticated;

create or replace function public.app_kombax_showcase_mis_elementos_v042(p_marca_id uuid)
returns table(id uuid,marca_id uuid,categoria_id uuid,slug text,nombre text,resumen text,descripcion text,imagen_url text,galeria jsonb,precio_orientativo numeric,moneda text,visitar_url text,donde_encontrar_url text,contacto_url text,estado text,destacado boolean,etiqueta_destacada text,publicado_en timestamptz,actualizado_en timestamptz)
language plpgsql stable security definer set search_path=public,auth as $$
begin
  if auth.uid() is null or not public.app_kombax_showcase_puede_gestionar_v042(p_marca_id) then raise exception 'SHOWCASE_MANAGEMENT_REQUIRED';end if;
  return query select e.id,e.marca_id,e.categoria_id,e.slug,e.nombre,e.resumen,e.descripcion,e.imagen_url,e.galeria,e.precio_orientativo,e.moneda,e.visitar_url,e.donde_encontrar_url,e.contacto_url,e.estado,e.destacado,e.etiqueta_destacada,e.publicado_en,e.actualizado_en from public.kombax_showcase_elementos e where e.marca_id=p_marca_id order by e.actualizado_en desc,e.id;
end $$;
revoke all on function public.app_kombax_showcase_mis_elementos_v042(uuid) from public,anon;
grant execute on function public.app_kombax_showcase_mis_elementos_v042(uuid) to authenticated;

create or replace function public.app_kombax_showcase_mutate_v042(p_operation text,p_payload jsonb,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth as $$
declare v_uid uuid:=auth.uid();v_payload jsonb:=coalesce(p_payload,'{}'::jsonb);v_club uuid;v_existing public.app_mutation_requests;v_result jsonb;v_brand public.kombax_showcase_marcas;v_element public.kombax_showcase_elementos;v_brand_id uuid;v_id uuid;v_category uuid;v_profile uuid;v_state text;v_gallery jsonb;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;if p_request_id is null then raise exception 'MUTATION_REQUEST_ID_REQUIRED'; end if;
  begin v_club:=nullif(v_payload->>'club_id','')::uuid;exception when others then raise exception 'MUTATION_INVALID_CLUB_ID';end;
  if v_club is null or not public.es_miembro_club(v_club) then raise exception 'MUTATION_MEMBERSHIP_REQUIRED'; end if;
  select * into v_existing from public.app_mutation_requests where request_id=p_request_id;
  if v_existing.request_id is not null then if v_existing.user_id<>v_uid or v_existing.operation<>p_operation then raise exception 'MUTATION_REQUEST_ID_REUSED';end if;if v_existing.result is not null then return v_existing.result;end if;
  else insert into public.app_mutation_requests(request_id,user_id,club_id,operation) values(p_request_id,v_uid,v_club,p_operation);end if;

  if p_operation='kombax.showcase.marca.guardar' then
    begin v_id:=nullif(v_payload->>'id','')::uuid;v_profile:=nullif(v_payload->>'perfil_directo_id','')::uuid;exception when others then raise exception 'Marca no válida';end;
    if v_id is null and not public.app_kombax_es_moderador_v041() then raise exception 'Solo moderación global puede dar de alta una marca';end if;
    if v_id is not null and not public.app_kombax_showcase_puede_gestionar_v042(v_id) then raise exception 'No puedes editar esta marca';end if;
    if v_id is null then
      insert into public.kombax_showcase_marcas(perfil_directo_id,slug,nombre,descripcion,logo_url,banner_url,web_url,contacto_url,estado,creada_por)
      values(v_profile,lower(btrim(v_payload->>'slug')),btrim(v_payload->>'nombre'),nullif(btrim(v_payload->>'descripcion'),''),nullif(btrim(v_payload->>'logo_url'),''),nullif(btrim(v_payload->>'banner_url'),''),nullif(btrim(v_payload->>'web_url'),''),nullif(btrim(v_payload->>'contacto_url'),''),'borrador',v_uid) returning * into v_brand;
      insert into public.kombax_showcase_gestores(marca_id,perfil_id,rol,asignado_por) values(v_brand.id,v_uid,'responsable',v_uid) on conflict do nothing;
    else
      update public.kombax_showcase_marcas set nombre=btrim(v_payload->>'nombre'),descripcion=nullif(btrim(v_payload->>'descripcion'),''),logo_url=nullif(btrim(v_payload->>'logo_url'),''),banner_url=nullif(btrim(v_payload->>'banner_url'),''),web_url=nullif(btrim(v_payload->>'web_url'),''),contacto_url=nullif(btrim(v_payload->>'contacto_url'),''),actualizado_en=now() where id=v_id returning * into v_brand;
    end if;
    v_result:=to_jsonb(v_brand);

  elsif p_operation='kombax.showcase.marca.estado' then
    if not public.app_kombax_es_moderador_v041() then raise exception 'Moderación global requerida';end if;
    begin v_id:=(v_payload->>'marca_id')::uuid;exception when others then raise exception 'Marca no válida';end;
    v_state:=lower(coalesce(v_payload->>'estado',''));if v_state not in ('borrador','publicada','suspendida','cerrada') then raise exception 'Estado de marca no válido';end if;
    update public.kombax_showcase_marcas set estado=v_state,verificada=coalesce((v_payload->>'verificada')::boolean,verificada),actualizado_en=now() where id=v_id returning * into v_brand;
    if v_brand.id is null then raise exception 'Marca no encontrada';end if;
    v_result:=jsonb_build_object('id',v_brand.id,'estado',v_brand.estado,'verificada',v_brand.verificada);

  elsif p_operation='kombax.showcase.elemento.guardar' then
    begin v_id:=nullif(v_payload->>'id','')::uuid;v_brand_id:=(v_payload->>'marca_id')::uuid;v_category:=nullif(v_payload->>'categoria_id','')::uuid;exception when others then raise exception 'Marca, elemento o categoría no válidos';end;
    if not public.app_kombax_showcase_puede_gestionar_v042(v_brand_id) then raise exception 'No puedes publicar para esta marca';end if;
    v_gallery:=coalesce(v_payload->'galeria','[]'::jsonb);if jsonb_typeof(v_gallery)<>'array' or jsonb_array_length(v_gallery)>8 then raise exception 'Galería no válida';end if;
    if v_id is null then
      insert into public.kombax_showcase_elementos(marca_id,categoria_id,slug,nombre,resumen,descripcion,imagen_url,galeria,precio_orientativo,moneda,visitar_url,donde_encontrar_url,contacto_url,creado_por,actualizado_por)
      values(v_brand_id,v_category,lower(btrim(v_payload->>'slug')),btrim(v_payload->>'nombre'),nullif(btrim(v_payload->>'resumen'),''),nullif(btrim(v_payload->>'descripcion'),''),nullif(btrim(v_payload->>'imagen_url'),''),v_gallery,nullif(v_payload->>'precio_orientativo','')::numeric,upper(coalesce(nullif(v_payload->>'moneda',''),'EUR')),nullif(btrim(v_payload->>'visitar_url'),''),nullif(btrim(v_payload->>'donde_encontrar_url'),''),nullif(btrim(v_payload->>'contacto_url'),''),v_uid,v_uid) returning * into v_element;
    else
      select * into v_element from public.kombax_showcase_elementos where id=v_id and marca_id=v_brand_id for update;if v_element.id is null then raise exception 'Elemento no encontrado';end if;
      update public.kombax_showcase_elementos set categoria_id=v_category,nombre=btrim(v_payload->>'nombre'),resumen=nullif(btrim(v_payload->>'resumen'),''),descripcion=nullif(btrim(v_payload->>'descripcion'),''),imagen_url=nullif(btrim(v_payload->>'imagen_url'),''),galeria=v_gallery,precio_orientativo=nullif(v_payload->>'precio_orientativo','')::numeric,moneda=upper(coalesce(nullif(v_payload->>'moneda',''),'EUR')),visitar_url=nullif(btrim(v_payload->>'visitar_url'),''),donde_encontrar_url=nullif(btrim(v_payload->>'donde_encontrar_url'),''),contacto_url=nullif(btrim(v_payload->>'contacto_url'),''),actualizado_por=v_uid,actualizado_en=now() where id=v_id returning * into v_element;
    end if;
    v_result:=to_jsonb(v_element);

  elsif p_operation='kombax.showcase.elemento.estado' then
    begin v_id:=(v_payload->>'elemento_id')::uuid;exception when others then raise exception 'Elemento no válido';end;
    select * into v_element from public.kombax_showcase_elementos where id=v_id for update;if v_element.id is null or not public.app_kombax_showcase_puede_gestionar_v042(v_element.marca_id) then raise exception 'No puedes gestionar este elemento';end if;
    v_state:=lower(coalesce(v_payload->>'estado',''));if v_state not in ('borrador','publicado','archivado') then raise exception 'Estado no válido';end if;
    update public.kombax_showcase_elementos set estado=v_state,publicado_en=case when v_state='publicado' then coalesce(publicado_en,now()) else publicado_en end,destacado=case when public.app_kombax_es_moderador_v041() then coalesce((v_payload->>'destacado')::boolean,destacado) else false end,etiqueta_destacada=case when public.app_kombax_es_moderador_v041() then left(nullif(btrim(v_payload->>'etiqueta_destacada'),''),80) else null end,actualizado_por=v_uid,actualizado_en=now() where id=v_id returning * into v_element;
    v_result:=jsonb_build_object('id',v_element.id,'estado',v_element.estado,'destacado',v_element.destacado);

  elsif p_operation='kombax.showcase.gestor.guardar' then
    if not public.app_kombax_es_moderador_v041() then raise exception 'Moderación global requerida';end if;
    begin v_brand_id:=(v_payload->>'marca_id')::uuid;v_profile:=(v_payload->>'perfil_id')::uuid;exception when others then raise exception 'Marca o perfil no válidos';end;
    insert into public.kombax_showcase_gestores(marca_id,perfil_id,rol,activo,asignado_por) values(v_brand_id,v_profile,case when v_payload->>'rol'='responsable' then 'responsable' else 'editor' end,coalesce((v_payload->>'activo')::boolean,true),v_uid)
    on conflict(marca_id,perfil_id) do update set rol=excluded.rol,activo=excluded.activo,asignado_por=v_uid;
    v_result:=jsonb_build_object('marca_id',v_brand_id,'perfil_id',v_profile,'activo',coalesce((v_payload->>'activo')::boolean,true));
  else raise exception 'Operación KOMBAX Showcase no permitida';end if;

  v_result:=jsonb_build_object('ok',true,'operation',p_operation,'request_id',p_request_id,'data',coalesce(v_result,'{}'::jsonb));update public.app_mutation_requests set result=v_result,completed_at=now() where request_id=p_request_id;return v_result;
exception when others then delete from public.app_mutation_requests where request_id=p_request_id and result is null;raise;
end $$;
revoke all on function public.app_kombax_showcase_mutate_v042(text,jsonb,uuid) from public,anon;
grant execute on function public.app_kombax_showcase_mutate_v042(text,jsonb,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
